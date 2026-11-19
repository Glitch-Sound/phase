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
## REQ-010-S01、REQ-010-S03、REQ-046-S01、REQ-046-S03
func _manual() -> void:
	game._start_battle();await process_frame
	_check(game.get("planning")!=null,"UI owns an independent plan")
	if game.get("planning")==null:return
	game.battle.units[3].pos=Vector2i(5,4)
	var before=game.battle.units.duplicate(true)
	_commit();await _draw_frame()
	_check(not game.movement.active and is_instance_valid(game.overlay) and game.planning.phase=="CHOICE" and game.battle.units==before and game.battle.history.is_empty(),"endpoint opens planning without moving or committing")
	var expected=game.planning.projected.units[0].duplicate(true)
	game._choose_battle_skill(game.C.DAMAGE)
	_check(game.planning.phase=="TARGET" and game.battle.units==before,"choose action from landing while real units stay put")
	game._cell_input(game.battle.units[3].pos)
	_check(game.planning.phase=="READY" and not game.movement.active and game.battle.history.is_empty(),"target selection still requires explicit CONFIRM")
	game._plan_back();game._plan_back();game._reselect_path()
	_check(not game.planning.active() and game.battle.units==before and game.battle.path==[Vector2i(4,4)] and game.battle.history.is_empty(),"BACK discards only plans and retains editable route")
	game._cell_input(Vector2i(4,4),true);game._choose_battle_skill(game.C.DAMAGE);game._cell_input(game.battle.units[3].pos)
	var hp=game.battle.units[3].hp
	game._confirm_plan();game._confirm_plan()
	_check(game.movement.active and game.battle.history.size()==1 and game.battle.units[3].hp==hp and not is_instance_valid(game.overlay),"final confirmation commits once, starts travel and delays only the action")
	game._cell_input(game.battle.units[3].pos)
	var key=InputEventKey.new();key.keycode=KEY_ESCAPE;key.pressed=true;root.push_input(key,false)
	_check(game.selected==-1 and game.battle.history.size()==1,"repeated input and Esc cannot alter playback")
	game._movement_tick(game.movement.duration/2);await _draw_frame()
	var display=game.movement.unit()
	for center in [game.T.PREVIEW_CENTER,game.T.BATTLE_INFO_RING]:
		var ring=game.displayed_rings.filter(func(r):return r.center==center)
		_check(ring.size()==1 and ring[0].unit==display and display.gear_angle!=before[0].gear_angle and display.gear_angle!=expected.gear_angle,"both actual side rings change with the moving unit")
	var elapsed=game.movement.elapsed
	game._window_focus_exited();game._movement_tick(100)
	_check(game.movement.elapsed==elapsed,"focus loss pauses movement")
	game._window_focus_entered();game._help();game._movement_tick(100)
	_check(game.movement.elapsed==elapsed,"HELP pauses without consuming movement time")
	game._close_aux();game._movement_tick(100)
	_check(not game.movement.active and not is_instance_valid(game.overlay) and game.battle.history.size()==2 and game.battle.turn==2 and game.battle.last_effect.target==3,"landing immediately executes the selected attack without another menu")
	game._movement_tick(100);game._confirm_plan()
	_check(game.battle.history.size()==2,"no queued final confirmation can replay the action")
	game._start_battle();_commit();game._wait_action();game._confirm_plan();game._restart();game._movement_tick(100)
	_check(game.build_open and not game.movement.active and game.playback_command.is_empty() and not game.planning.active(),"restart discards pending action and arrival")
	game.reduced_motion=true;game._start_battle();_commit();game._wait_action();game._confirm_plan()
	_check(not game.movement.active and not is_instance_valid(game.overlay) and game.battle.turn==2,"reduced motion commits and acts immediately once")
	game.reduced_motion=false
	game._start_battle();_commit();game._wait_action();game._confirm_plan()
	game.battle.turn+=1;var history=game.battle.history.duplicate()
	game._movement_tick(100)
	_check(game.playback_command.is_empty() and game.battle.history==history and not game.movement.active,"invalidated owner turn discards the pending action")
## REQ-046-S02
func _cpu() -> void:
	if game.get("planning")==null:return
	game.cpu_enabled=true;game._start_battle();await process_frame
	game.battle.actor=3;game._follow_turn()
	game.cpu_turn.begin(game.battle,{"path":[Vector2i(5,4),Vector2i(4,4)],"skill":game.C.DAMAGE,"target":0})
	for i in range(20):
		game._cpu_tick(1)
		if game.movement.active:break
	_check(game.movement.active,"CPU commit enters the same movement phase")
	await _draw_frame()
	_check(game.displayed_text.has("CPU A / MOVING") and game.displayed_text.has("DAMAGE / ADJACENT → 1"),"CPU shows its already chosen action and target during travel")
	var hp=game.battle.units[0].hp
	game._cpu_tick(100)
	_check(game.battle.units[0].hp==hp,"CPU cannot attack during travel")
	game._movement_tick(100)
	_check(game.battle.turn==2 and game.battle.history.size()==2 and game.cpu_turn.phase=="RESULT" and game.battle.last_effect.kind=="DAMAGE","CPU executes the action at arrival without ACTION or TARGET waits")
	game._start_battle();game.battle.actor=3
	game.battle.units[3].pos=Vector2i.ZERO;game.battle.units[0].pos=Vector2i(1,0);game.battle.units[1].pos=Vector2i(0,1)
	game.cpu_turn.begin(game.battle,{"path":[],"skill":"","target":-1})
	game._cpu_tick(1);game._cpu_tick(1)
	_check(not game.movement.active and game.battle.turn==2 and game.battle.history==["A WAIT"],"trapped zero-step CPU action adds no movement or extra commit")
	game.cpu_enabled=false
func _check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",note)
