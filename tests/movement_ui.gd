extends SceneTree
var checks=0
var failures=0
var game
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	root.size=Vector2i(1920,1080)
	game=load("res://tests/movement_audit.gd").new()
	game.settings_path="res://artifacts/runtime/movement-no-settings.json"
	game.save_path="res://artifacts/runtime/movement-no-save.json"
	root.add_child(game);await process_frame;game.set_process(false)
	_check(game.get("movement")!=null,"UI owns shared movement presentation")
	if failures==0:
		await _manual()
		await _cpu()
		await _clouds()
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
	_check(not game.movement.active and is_instance_valid(game.overlay) and game.planning.phase=="CHOICE" and game.battle.units==before and game.battle.history.is_empty() and not game.drawn_route_segments.is_empty(),"endpoint opens planning with the existing route, without moving or committing")
	var expected=game.planning.projected.units[0].duplicate(true)
	game._choose_battle_skill(game.C.DAMAGE)
	await _draw_frame()
	_check(game.planning.phase=="TARGET" and game.battle.units==before and not game.drawn_route_segments.is_empty(),"target planning retains the route while real units stay put")
	game._cell_input(game.battle.units[3].pos)
	await _draw_frame()
	_check(game.planning.phase=="READY" and not game.movement.active and game.battle.history.is_empty() and not game.drawn_route_segments.is_empty(),"final confirmation retains the planned route without committing")
	game._plan_back();game._plan_back();game._reselect_path()
	_check(not game.planning.active() and game.battle.units==before and game.battle.path==[Vector2i(4,4)] and game.battle.history.is_empty(),"BACK discards only plans and retains editable route")
	game._cell_input(Vector2i(4,4),true);game._choose_battle_skill(game.C.DAMAGE);game._cell_input(game.battle.units[3].pos)
	var hp=game.battle.units[3].hp
	game._confirm_plan();game._confirm_plan()
	_check(game.movement.active and game.battle.history.size()==1 and game.battle.units[3].hp==hp and not is_instance_valid(game.overlay),"final confirmation commits once, starts travel and delays only the action")
	game._cell_input(game.battle.units[3].pos)
	var key=InputEventKey.new();key.keycode=KEY_ESCAPE;key.pressed=true;root.push_input(key,false)
	_check(game.selected==-1 and game.battle.history.size()==1,"repeated input and Esc cannot alter playback")
	game._movement_tick(game.movement.duration/2);game.selected=3;await _draw_frame()
	_check(game.drawn_route_segments.is_empty(),"manual execution draws no route line")
	var display=game.movement.unit()
	for center in [game.T.PREVIEW_CENTER,game.T.BATTLE_INFO_RING]:
		var ring=game.displayed_rings.filter(func(r):return r.center==center)
		_check(ring.size()==1 and ring[0].unit==display and display.gear_angle!=before[0].gear_angle and display.gear_angle!=expected.gear_angle,"both actual side rings change with the moving unit")
	var card=game._timeline_view().cards.filter(func(c):return c.index==game.movement.actor)[0]
	var width=game.mono.get_string_size("I:000% R:000%",HORIZONTAL_ALIGNMENT_LEFT,-1,game.T.TIMELINE_FACTOR_FONT).x
	var step=game.mono.get_string_size("I:000% ",HORIZONTAL_ALIGNMENT_LEFT,-1,game.T.TIMELINE_FACTOR_FONT).x+game.T.TIMELINE_FACTOR_EXTRA_GAP
	var origin=card.center+Vector2(-width/2,56)
	var records=game.text_records.filter(func(r):return r.position in [origin,origin+Vector2(step,0)])
	_check(records.map(func(r):return r.text)==["I:%3d%%" % roundi(game.M.sync(display,1).factor*100),"R:%3d%%" % roundi(game.M.sync(display,2).factor*100)] and records.map(func(r):return r.color)==[game.status_colors[1],game.status_colors[2]],"existing derived values and colors follow the same moving state")
	var elapsed=game.movement.elapsed
	game._window_focus_exited();game._movement_tick(100)
	_check(game.movement.elapsed==elapsed,"focus loss pauses movement")
	game._window_focus_entered();game._help();game._movement_tick(100)
	_check(game.movement.elapsed==elapsed,"HELP pauses without consuming movement time")
	game._close_aux();game._movement_tick(game.movement.duration-game.movement.elapsed);await _draw_frame()
	_check(game.movement.active and game.movement.get("landed")==true and game.battle.units[3].hp==hp and game.battle.history.size()==1 and not is_instance_valid(game.overlay),"landing shows a short automatic beat before damage without another menu")
	game._movement_tick(game.T.get_script_constant_map().get("MOVEMENT_ATTACK_BEAT_SECONDS",0))
	_check(not game.movement.active and not is_instance_valid(game.overlay) and game.battle.history.size()==2 and game.battle.turn==2 and game.battle.last_effect.target==3,"the automatic beat executes the selected attack without another menu")
	game._movement_tick(100);game._confirm_plan()
	_check(game.battle.history.size()==2,"no queued final confirmation can replay the action")
	game._start_battle();_commit();game._wait_action();game._confirm_plan();game._restart();game._movement_tick(100)
	_check(game.build_open and not game.movement.active and game.playback_command.is_empty() and not game.planning.active(),"restart discards pending action and arrival")
	game._start_battle();_commit();game._wait_action();game._confirm_plan();game._movement_tick(game.movement.duration)
	_check(not game.movement.active and game.battle.turn==2,"normal WAIT gains no post-move beat")
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
	game._cpu_tick(1);await _draw_frame()
	_check(not game.movement.active and not game.drawn_route_segments.is_empty(),"CPU route announcement retains the existing route line")
	for i in range(20):
		game._cpu_tick(1)
		if game.movement.active:break
	_check(game.movement.active,"CPU commit enters the same movement phase")
	await _draw_frame()
	_check(game.displayed_text.has("CPU / MOVING") and game.displayed_text.has("DAMAGE / ADJACENT") and game.drawn_route_segments.is_empty(),"CPU shows its chosen action and target during travel without a route line")
	var hp=game.battle.units[0].hp
	game._cpu_tick(100)
	_check(game.battle.units[0].hp==hp,"CPU cannot attack during travel")
	game._movement_tick(game.movement.duration);await _draw_frame()
	_check(game.movement.active and game.movement.get("landed")==true and game.battle.units[0].hp==hp and game.displayed_text.has("CPU / AIMING"),"CPU landing keeps the actor and prepares the attack")
	game.cpu_paused=true;game._movement_tick(100)
	_check(game.battle.units[0].hp==hp and game.movement.active,"CPU pause also freezes the attack beat")
	game.cpu_paused=false;game.cpu_fast=true
	game._movement_tick(game.T.get_script_constant_map().get("MOVEMENT_ATTACK_BEAT_SECONDS",0)/game.T.CPU_FAST_SPEED+0.000001)
	game.cpu_fast=false
	_check(game.battle.turn==2 and game.battle.history.size()==2 and game.cpu_turn.phase=="RESULT" and game.battle.last_effect.kind=="DAMAGE","CPU executes after the automatic beat without ACTION or TARGET waits")
	game._start_battle();game.battle.actor=3
	game.battle.units[3].pos=Vector2i.ZERO;game.battle.units[0].pos=Vector2i(1,0);game.battle.units[1].pos=Vector2i(0,1)
	game.cpu_turn.begin(game.battle,{"path":[],"skill":"","target":-1})
	game._cpu_tick(1);game._cpu_tick(1)
	_check(not game.movement.active and game.battle.turn==2 and game.battle.history==["A WAIT"],"trapped zero-step CPU action adds no movement or extra commit")
	game.cpu_enabled=false
## REQ-018-S08、REQ-046-S01、REQ-046-S03
func _clouds() -> void:
	game.cpu_enabled=false;game._start_battle()
	game.battle.units[0].skills=[game.C.FIELD_SLOW]
	game.battle.units[3].skills=[game.C.FIELD_FAST]
	_commit();game._wait_action();game._confirm_plan()
	game._movement_tick(game.T.MOVEMENT_CLOUD_OUT_SECONDS/2);await _draw_frame()
	var own=game.displayed_clouds.filter(func(c):return c.id=="01")[0]
	var other=game.displayed_clouds.filter(func(c):return c.id=="A")[0]
	_check(own.opacity>0 and own.opacity<1 and other.opacity==1 and game.movement.elapsed==0,"only moving emitter fades at departure while stationary emitters remain visible")
	game._movement_tick(game.T.MOVEMENT_CLOUD_OUT_SECONDS/2+game.movement.duration/2);await _draw_frame()
	_check(game.displayed_clouds.filter(func(c):return c.id=="01")[0].opacity==0 and game.displayed_clouds.filter(func(c):return c.id=="A")[0].opacity==1,"travel hides only the moving cloud without hiding stationary effects")
	game._movement_tick(game.movement.duration);game._movement_tick(game.T.MOVEMENT_CLOUD_IN_SECONDS);await _draw_frame()
	_check(not game.movement.active and game.battle.turn==2 and game.displayed_clouds.all(func(c):return c.opacity==1),"WAIT proceeds immediately and cloud reveal cannot remain stuck")
	game._restart();game._start_battle();await _draw_frame()
	_check(game.movement.source.is_empty() and game.displayed_clouds.all(func(c):return c.opacity==1),"restart clears all old cloud visibility")
func _check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",note)
