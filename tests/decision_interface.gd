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
	await _direct_selection()
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
## REQ-010-S05、REQ-010-S01、REQ-010-S03
func _direct_selection() -> void:
	game._start_battle();game.set_process(false)
	game.hud.find_children("*","Button",true,false).filter(func(b):return b.text=="WAIT")[0].grab_focus()
	game._cell_input(Vector2i(4,4));game._cell_input(Vector2i(5,4));game._cell_input(Vector2i(5,4),true)
	var buttons=game.overlay.find_children("*","Button",true,false)
	_check(buttons.all(func(b):return b.disabled) and root.gui_get_focus_owner()==null,"new ACTION disables its buttons and releases old HUD focus")
	_check(not game.has_method("_confirm_dialog"),"battle has no final CONFIRM dialog")
	if game.get("plan_pending")==null or not game.has_method("_advance_action_gate"):
		_check(false,"screen owns an explicit frame-gated pending action");game._restart();return
	Input.action_press("ui_accept");game._advance_action_gate(game.T.ACTION_INPUT_GUARD_SECONDS*2)
	_check(buttons.all(func(b):return b.disabled),"held accept cannot arm or activate the new ACTION")
	Input.action_release("ui_accept");game._advance_action_gate(0)
	_check(not buttons.filter(func(b):return b.text=="WAIT")[0].disabled and buttons.filter(func(b):return b.text=="HEAL / ADJACENT")[0].disabled,"release restores legal buttons and retains invalid targets")
	var before=game.planning._state(game.battle)
	game._choose_battle_skill(game.C.DAMAGE);game._cell_input(Vector2i(0,0))
	_check(game.planning.phase=="TARGET" and game.planning._state(game.battle)==before and not game.plan_pending,"invalid target cannot commit or mutate")
	game._plan_back();game._reselect_path()
	_check(game.planning._state(game.battle)==before and not game.planning.active(),"BACK before final target preserves the original route and combat")
	game._cell_input(Vector2i(5,4),true);game._choose_battle_skill(game.C.DAMAGE);game._cell_input(game.battle.units[3].pos)
	_check(game.plan_pending and not is_instance_valid(game.overlay) and not game.movement.active and game.battle.history.is_empty(),"target accepts once and hides dialog before any commit or movement")
	game._confirm_plan();game._cell_input(game.battle.units[3].pos);game._pending_plan_tick()
	_check(game.battle.history.is_empty(),"repeats and a tick before the closed frame cannot begin execution")
	game._help();await process_frame;await process_frame;game._pending_plan_tick()
	_check(game.plan_pending and game.battle.history.is_empty(),"HELP pauses an accepted command before its first movement")
	game._close_aux();game._pending_plan_tick()
	_check(game.battle.history.is_empty(),"closing HELP also requires a newly presented bare frame")
	await _present()
	_check(game.movement.active and game.battle.history.size()==1,"closed frame starts one planned movement without another dialog")
	game._movement_tick(game.movement.duration+game.T.MOVEMENT_ATTACK_BEAT_SECONDS);var history=game.battle.history.duplicate();game._confirm_plan();game._pending_plan_tick();game._movement_tick(100)
	_check(game.battle.history==history and game.battle.turn==2,"one target executes once and never repeats in the next turn")
	game._start_battle();game.battle.units[0].skills=[game.C.GUARD];game._cell_input(Vector2i(4,4));game._cell_input(Vector2i(4,4),true);game._choose_battle_skill(game.C.GUARD)
	_check(game.plan_pending and not is_instance_valid(game.overlay),"implicit self target commits from GUARD's action button")
	await _present();game._movement_tick(game.movement.duration)
	_check(game.battle.last_effect.kind=="GUARD" and game.battle.turn==2,"implicit target executes after movement")
	game._start_battle();game._wait_action();game._restart();await _present()
	_check(game.build_open and not game.plan_pending and not game.movement.active and game.battle.history.is_empty(),"restart invalidates a command before its closed frame")
func _present() -> void:
	await process_frame;await process_frame
	game._pending_plan_tick()
## REQ-012-S04
func _stationary_wait() -> void:
	if game.get("plan_pending")==null:return
	for blocked in [false,true]:
		game._start_battle();game.set_process(false)
		var b=game.battle;b.units[0].pos=Vector2i(4,4)
		if blocked:
			for i in range(4):b.units[i+1].pos=Vector2i(4,4)+b.DIRS[i]
		else:b.path=[Vector2i(5,4)]
		b.units[0].core_angle=57.0;b.panels[b.units[0].pos]="RESET";game._hud();await process_frame
		var original=game.planning._state(b);var sounds=[];var listener=func(kind):sounds.append(kind)
		game.sfx.played.connect(listener)
		var waits=game.hud.find_children("*","Button",true,false).filter(func(button):return button.text=="WAIT")
		_check(waits.size()==1,"permanent WAIT is available with or without free cells")
		waits[0].pressed.emit();game._wait_action();game._confirm_plan()
		_check(game.plan_pending and not is_instance_valid(game.overlay) and b.history.is_empty(),"WAIT accepts once without a final dialog or early action")
		await _present()
		_check(b.turn==original[2]+1 and ["pos","hp","core_angle","initial_core_angle","gear_angle","arms_angle"].all(func(k):return b.units[0][k]==original[0][0][k]) and not game.movement.active and sounds.filter(func(kind):return kind.begins_with("ring_rotate")).is_empty(),"stationary WAIT advances once without rings, panels, movement or movement sound")
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
