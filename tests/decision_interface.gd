extends SceneTree
var checks=0
var failures=0
var game
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	game=load("res://tests/fixture_squad_main.gd").new()
	game.settings_path="res://artifacts/runtime/decisions-no-settings.json"
	game.save_path="res://artifacts/runtime/decisions-no-save.json"
	root.add_child(game)
	await process_frame
	game.set_process(false)
	await _entry_points()
	await _stationary_wait()
	_focus()
	game._restart()
	_check(game.build_open,"interface verification returns BUILD")
	game.queue_free()
	print("TACTICAL DECISIONS UI: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
## REQ-010-S03、REQ-010-S04、REQ-018-S01
func _entry_points() -> void:
	for via_keyboard in [false,true]:
		game._start_battle()
		await process_frame
		var source=game.battle.units[0].pos
		game._cell_input(Vector2i(4,4))
		game._cell_input(Vector2i(4,4),true)
		game._movement_tick(game.T.MOVEMENT_MAX_SECONDS)
		await process_frame
		var panel=game.overlay.get_child(1)
		var buttons=panel.find_children("*","Button",true,false)
		var back=buttons.filter(func(b):return b.text=="BACK")
		_check(back.size()==1,"ACTION exposes BACK as a real operation")
		var names=buttons.map(func(b):return b.text)
		names.sort()
		_check(names==["BACK","DAMAGE / ADJACENT","HEAL / ADJACENT","WAIT"],"exact ACTION choices preserve skills and WAIT with the authorized BACK addition")
		if via_keyboard:
			var key=InputEventKey.new()
			key.keycode=KEY_ESCAPE
			key.pressed=true
			root.push_input(key,false)
		elif back.size()==1:
			back[0].pressed.emit()
		await process_frame
		_check(game.battle.mode=="MOVE" and game.battle.units[0].pos==source and game.battle.path==[Vector2i(4,4)] and not is_instance_valid(game.overlay),"actual BACK/Esc entry returns editable prediction at the original position")
	game.cpu_enabled=true
	game._start_battle()
	await process_frame
	game.battle.actor=3
	game.battle.path_click(Vector2i(5,4))
	game.battle.commit_path()
	var before=[game.battle.units.duplicate(true),game.battle.history.duplicate(),game.battle.mode]
	_check(game.has_method("_reselect_path"),"UI has one protected reselection entry")
	if game.has_method("_reselect_path"):
		game._reselect_path()
	_check(before==[game.battle.units,game.battle.history,game.battle.mode],"human cannot invoke reselection on an enemy CPU turn")
	game.cpu_enabled=false
## REQ-012-S04
func _stationary_wait() -> void:
	for blocked in [false,true]:
		game._start_battle();game.set_process(false)
		var b=game.battle
		b.units[0].pos=Vector2i(4,4)
		if blocked:
			for i in range(4):b.units[i+1].pos=Vector2i(4,4)+b.DIRS[i]
		else:b.path=[Vector2i(5,4)]
		b.units[0].core_angle=57.0;b.panels[b.units[0].pos]="RESET"
		game._hud();await process_frame
		var original=game.planning._state(b)
		var waits=game.hud.find_children("*","Button",true,false).filter(func(button):return button.text=="WAIT")
		_check(waits.size()==1,"permanent WAIT is available with or without free cells")
		if waits.size()!=1:continue
		waits[0].pressed.emit();await process_frame
		_check(game.planning.phase=="READY" and game.planning.route.is_empty() and game.planning._state(b)==original and game._visible_route().is_empty(),"WAIT goes straight to stationary confirmation without moving or showing the old route")
		var labels=game.overlay.find_children("*","Label",true,false).map(func(label):return label.text)
		_check(labels.has("WAIT / NO MOVE"),"stationary summary explicitly identifies no movement")
		if blocked:
			var key=InputEventKey.new();key.keycode=KEY_ESCAPE;key.pressed=true;root.push_input(key,false)
		else:
			for button in game.overlay.find_children("*","Button",true,false):
				if button.text=="BACK":button.pressed.emit();break
		await process_frame
		_check(not game.planning.active() and game.planning._state(b)==original,"BACK/Esc restores the unchanged original route without another menu")
		var sounds=[]
		var listener=func(kind):sounds.append(kind)
		game.sfx.played.connect(listener)
		game._wait_action();game._confirm_plan();game._confirm_plan();game._movement_tick(10.0)
		await process_frame
		_check(b.turn==original[2]+1 and not game.movement.active and sounds.filter(func(kind):return kind.begins_with("ring_rotate")).is_empty(),"confirmed WAIT ends one turn with no movement animation or movement sound")
		game.sfx.played.disconnect(listener)
## REQ-018-S02、REQ-018-S04、REQ-018-S05
func _focus() -> void:
	_check(not game.has_method("_acting_marker"),"obsolete triangle drawing is removed")
	_check(game.has_method("_turn_focus_cell"),"default actor uses an existing-cell focus description")
	if not game.has_method("_turn_focus_cell"):
		return
	game._start_battle()
	for actor in range(game.battle.units.size()):
		game.battle.actor=actor
		game.selected=-1
		game.timeline_hover=(actor+1)%game.battle.units.size()
		_check(game._turn_focus_cell()==game.battle.units[actor].pos,"default focus follows actor independently of hover")
		game.selected=(actor+1)%game.battle.units.size()
		_check(game._turn_focus_cell()==Vector2i(-1,-1),"explicit inspection takes priority over automatic focus")
	game.selected=-1
	game.battle.path=[Vector2i(5,4)]
	_check(game._turn_focus_cell()==Vector2i(-1,-1),"existing route endpoint focus takes priority")
	game.battle.path=[]
	for size_px in [Vector2i(1152,648),Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size=size_px
		game.battle.actor=0
		for endpoint in [Vector2i(0,0),Vector2i(9,9)]:
			game.battle.units[0].pos=endpoint
			_check(game._turn_focus_cell()==endpoint and game._cell_rect(endpoint).end.x<=game.BOARD.x+10*game.CELL,"same existing focus rectangle stays within board edges "+str(size_px))
	game.battle.result="VICTORY"
	_check(game._turn_focus_cell()==Vector2i(-1,-1),"terminal view has no actor focus")
	game.battle.result=""
	game.battle.units[0].hp=0
	_check(game._turn_focus_cell()==Vector2i(-1,-1),"defeated actor has no focus")
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
