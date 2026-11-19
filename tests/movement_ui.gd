extends SceneTree
var checks=0
var failures=0
var game
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	game=load("res://tests/movement_audit.gd").new()
	game.settings_path="res://artifacts/runtime/movement-no-settings.json"
	game.save_path="res://artifacts/runtime/movement-no-save.json"
	root.add_child(game);await process_frame;game.set_process(false)
	_check(game.get("movement")!=null,"UI owns shared movement presentation")
	if failures==0:
		await _manual()
		await _cpu()
	game._restart();game.queue_free();await process_frame
	print("MOVEMENT UI: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
func _commit() -> void:
	game._cell_input(Vector2i(4,4));game._cell_input(Vector2i(4,4),true)
func _draw_frame() -> void:
	game.queue_redraw();await process_frame;await create_timer(0.02).timeout
## REQ-046-S01、REQ-046-S03
func _manual() -> void:
	game._start_battle();await process_frame
	var before=game.battle.units[0].duplicate(true)
	_commit();await _draw_frame()
	_check(game.movement.active and not is_instance_valid(game.overlay),"confirmation starts moving before action dialog")
	var expected=game.battle.units[0].duplicate(true)
	var history=game.battle.history.duplicate()
	for center in [game.T.PREVIEW_CENTER,game.T.BATTLE_INFO_RING]:
		var ring=game.displayed_rings.filter(func(r):return r.center==center)
		_check(ring.size()==1 and ring[0].unit==before,"both drawn rings show the moving actor before landing")
	game._cell_input(game.battle.units[3].pos)
	var key=InputEventKey.new();key.keycode=KEY_ESCAPE;key.pressed=true;root.push_input(key,false)
	_commit()
	_check(game.selected==-1 and game.battle.history==history and game.movement.active,"selection, Esc and repeat confirmation cannot affect the committed action")
	game._window_focus_exited();game._movement_tick(100)
	_check(game.movement.elapsed==0,"focus loss pauses movement")
	game._window_focus_entered();game._help();game._movement_tick(100)
	_check(game.movement.elapsed==0,"HELP pauses without consuming movement time")
	game._close_aux();game._movement_tick(100);await _draw_frame()
	_check(not game.movement.active and is_instance_valid(game.overlay) and game.battle.units[0]==expected,"landing opens ACTION at exact committed state")
	for center in [game.T.PREVIEW_CENTER,game.T.BATTLE_INFO_RING]:
		var ring=game.displayed_rings.filter(func(r):return r.center==center)
		_check(ring.size()==1 and ring[0].unit==expected,"both drawn rings update together to landing actor")
	var stale_buttons=game.overlay.find_children("*","Button",true,false).filter(func(b):return b.text in ["WAIT","DAMAGE / ADJACENT"])
	game._reselect_path()
	_check(game.battle.units[0]==before and game.battle.path==[Vector2i(4,4)] and game.battle.history.is_empty(),"BACK restores original position, angles and prediction")
	game._cell_input(Vector2i(4,4),true)
	for button in stale_buttons:button.pressed.emit()
	_check(game.movement.active and game.battle.mode=="CHOICE" and game.battle.turn==1 and game.battle.history.size()==1,"queued old buttons cannot act during a new movement")
	game._restart();var build=game.overlay
	game._movement_tick(100)
	_check(game.build_open and game.overlay==build and not game.movement.active,"exit discards movement without opening an old action dialog")
	game.reduced_motion=true;game._start_battle();_commit()
	_check(not game.movement.active and is_instance_valid(game.overlay),"reduced motion reaches ACTION immediately")
	game.reduced_motion=false
## REQ-046-S02
func _cpu() -> void:
	game.cpu_enabled=true;game._start_battle();await process_frame
	game.battle.actor=3;game._follow_turn()
	game.cpu_turn.begin(game.battle,{"path":[Vector2i(5,4),Vector2i(4,4)],"skill":game.C.DAMAGE,"target":0})
	for i in range(20):
		game._cpu_tick(1)
		if game.movement.active:break
	_check(game.movement.active and game.cpu_turn.phase=="ACTION","CPU commit enters the same movement phase")
	await _draw_frame()
	_check(game.displayed_text.has("CPU A / MOVING") and not game.displayed_text.has("DAMAGE / ADJACENT → 1"),"CPU shows travel rather than its next action before landing")
	var hp=game.battle.units[0].hp
	game._cpu_tick(100)
	_check(game.battle.units[0].hp==hp and game.cpu_turn.phase=="ACTION","CPU cannot attack during travel")
	game._movement_tick(100);game._cpu_tick(1);game._cpu_tick(1)
	_check(game.battle.turn==2 and game.battle.history.size()==2 and game.battle.last_effect.kind=="DAMAGE" and game.battle.last_effect.target==0 and game.battle.units[0].hp<=hp,"CPU resumes one actual action after arrival")
	game._start_battle();game.battle.actor=3
	game.battle.units[3].pos=Vector2i.ZERO;game.battle.units[0].pos=Vector2i(1,0);game.battle.units[1].pos=Vector2i(0,1)
	game.cpu_turn.begin(game.battle,{"path":[],"skill":"","target":-1})
	game._cpu_tick(1);game._cpu_tick(1)
	_check(not game.movement.active and game.battle.turn==2 and game.battle.history==["A WAIT"],"trapped zero-step CPU action adds no movement or extra commit")
	game.cpu_enabled=false
func _check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",note)
