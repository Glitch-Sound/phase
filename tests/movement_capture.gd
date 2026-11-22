extends SceneTree
var game
var checks=0
var failures=0
var observations=[]
func _initialize() -> void:_run.call_deferred()
func _check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",note)
func _settle(count: int=2) -> void:
	for i in range(count):
		await process_frame
		await RenderingServer.frame_post_draw
func _click(point: Vector2,double: bool=false) -> void:
	for pressed in [true,false]:
		var e=InputEventMouseButton.new();e.position=root.get_final_transform()*point;e.global_position=e.position;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;e.double_click=double and pressed;root.push_input(e,false)
func _cell(cell: Vector2i,double: bool=false) -> void:
	_click(game._cell_rect(cell).get_center(),double)
func _shot(name: String) -> void:
	root.get_texture().get_image().save_png("res://artifacts/runtime/arrival-"+name+".png")
## REQ-046-S04
func _run() -> void:
	game=load("res://tests/movement_audit.gd").new()
	game.save_path="res://artifacts/runtime/arrival-gpu-no-save.json"
	game.settings_path="res://artifacts/runtime/arrival-gpu-no-settings.json"
	root.add_child(game);await _settle()
	var normal=game.collection.snapshot()
	_check(game._toggle_debug(true),"isolated actual debug entry")
	game.collection.builds[0].skills=[game.C.DAMAGE,game.C.HEAL,game.C.FIELD_SLOW]
	game.panel_seed_override=128
	for dimensions in [Vector2i(1152,648),Vector2i(1920,1080)]:
		root.size=dimensions;root.grab_focus();await _settle(3)
		for attempt in range(60):
			if root.has_focus() and game.window_focused:break
			root.grab_focus();await _settle()
		_check(root.has_focus() and game.window_focused,"actual GPU focus "+str(dimensions))
		game._start_battle();await _settle()
		root.grab_focus();await _settle(3)
		_check(root.has_focus() and game.window_focused,"battle input focus "+str(dimensions))
		var source=game.battle.units[0].duplicate(true)
		for cell in [Vector2i(4,4),Vector2i(4,5)]:_cell(cell)
		var predicted=game.battle.preview()
		await _settle()
		_check(not game.drawn_route_segments.is_empty(),"route planning visibly retains the line")
		_shot("planning-"+str(dimensions.x))
		_cell(Vector2i(4,5),true);await create_timer(game.T.ACTION_INPUT_GUARD_SECONDS).timeout;await _settle()
		_check(game.planning.active() and game.battle.units[0]==source and not game.movement.active and not game.drawn_route_segments.is_empty(),"scaled planning keeps the original unit "+str(dimensions))
		if not game.planning.active():
			game._restart();game._toggle_debug(false);quit(1);return
		var back=game.overlay.find_children("*","Button",true,false).filter(func(b):return b.text=="BACK")[0]
		_click(back.get_global_rect().get_center());await _settle()
		_check(not game.planning.active() and game.battle.units[0]==source and game.battle.path==[Vector2i(4,4),Vector2i(4,5)] and game.battle.history.is_empty(),"scaled BACK changes only the plan")
		_cell(Vector2i(4,5),true);await create_timer(game.T.ACTION_INPUT_GUARD_SECONDS).timeout;await _settle()
		var wait=game.overlay.find_children("*","Button",true,false).filter(func(b):return b.text=="WAIT")[0]
		_click(wait.get_global_rect().get_center());await _settle()
		_check(game.movement.active and not is_instance_valid(game.overlay),"scaled WAIT selection begins travel after the closed frame "+str(dimensions))
		var history=game.battle.history.duplicate()
		_cell(game.battle.units[3].pos)
		var key=InputEventKey.new();key.keycode=KEY_ESCAPE;key.pressed=true;root.push_input(key,false)
		_check(game.selected==-1 and game.battle.history==history,"GPU inspection and Esc cannot interrupt committed travel")
		await _observe("manual-"+str(dimensions.x))
		_check(not is_instance_valid(game.overlay) and game.battle.turn==2 and game.battle.history.size()==2,"arrival directly executes chosen WAIT")
		_check(_same_landing(game.battle.units[0],predicted),"real landing equals planned panels and aura")
		_shot("landing-"+str(dimensions.x))
		game._start_battle();_cell(Vector2i(4,4));_cell(Vector2i(4,4),true);game._wait_action();await _settle(3)
		game._restart();await _settle(15)
		_check(game.build_open and not game.movement.active and game.playback_command.is_empty(),"restart during travel discards old arrival and action")
	root.size=Vector2i(1920,1080);await _settle()
	await _cpu()
	await _terminal()
	game._restart();_check(game._toggle_debug(false) and game.collection.snapshot()==normal,"normal BUILD and exact original collection restored")
	await _settle()
	var f=FileAccess.open("res://artifacts/runtime/arrival-gpu.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations,"draw_ms":game.draw_times},"\t"));f.close()
	print("ARRIVAL GPU: %d checks / %d failures / normal BUILD restored" % [checks,failures])
	quit(0 if failures==0 else 1)
func _same_landing(actual: Dictionary,predicted: Dictionary) -> bool:
	for key in ["pos","core_angle","gear_angle","arms_angle","class_name","gear_mutation","arms_mutation"]:
		if actual[key]!=predicted[key]:return false
	return true
func _observe(tag: String) -> void:
	var frames=[];var snapped=false;var held=false
	var should_hold=game.movement.beat_duration>0
	for i in range(40):
		if not game.movement.active:break
		await _settle(1)
		if not game.movement.active:break
		var cell=game.movement.position()
		for cloud in game.displayed_clouds:
			if cloud.id!=game.movement.source.id or cloud.camp!=game.movement.source.camp:
				_check(cloud.opacity==1,"stationary cloud remains visible "+tag)
			elif game.movement.elapsed>0 and not game.movement.landed:
				_check(cloud.opacity==0,"moving cloud is completely hidden "+tag)
		var expected=game.BOARD+(cell+Vector2.ONE*0.5)*game.CELL
		var rings=game.displayed_rings.filter(func(r):return r.unit.id==game.movement.source.id and Rect2(game.BOARD,Vector2.ONE*game.CELL*10).has_point(r.center))
		_check(rings.size()==1 and rings[0].center.distance_to(expected)<0.001,"single actual moving glyph at continuous route position "+tag)
		_check(game.drawn_route_segments.is_empty(),"no route line is drawn during actual movement "+tag)
		for center in [game.T.PREVIEW_CENTER,game.T.BATTLE_INFO_RING]:
			var side=game.displayed_rings.filter(func(r):return r.center==center)
			_check(side.size()==1 and side[0].unit==game.movement.unit(),"actual side glyph remains the same changing moving rings "+tag)
		frames.append({"elapsed":game.movement.elapsed,"position":str(cell),"center":str(expected),"angles":[game.movement.unit().core_angle,game.movement.unit().gear_angle,game.movement.unit().arms_angle],"drawn_route_segments":game.drawn_route_segments.size(),"landed":game.movement.landed,"beat_elapsed":game.movement.beat_elapsed})
		if game.movement.landed and not held:
			_check(game.battle.history.size()==1 and not is_instance_valid(game.overlay),"landed attack beat retains the actor without another menu")
			_shot("landed-beat-"+tag);held=true
		elif not snapped:
			_shot("mid-"+tag);snapped=true
	_check(not game.movement.active and frames.size()>0,"travel visibly completes without a stuck frame "+tag)
	if should_hold:_check(held,"actual GPU frames include the landed attack beat "+tag)
	observations.append({"tag":tag,"frames":frames})
func _cpu() -> void:
	game.cpu_enabled=true;game._start_battle();await _settle()
	game.cpu_paused=true;game.battle.actor=3;game._follow_turn()
	game.cpu_turn.begin(game.battle,{"path":[Vector2i(5,4),Vector2i(4,4)],"skill":game.C.DAMAGE,"target":0})
	game.cpu_paused=false
	var saw_route=false
	for i in range(60):
		await _settle(1)
		if not game.movement.active and not game.drawn_route_segments.is_empty():saw_route=true
		if game.movement.active:break
	_check(game.movement.active and saw_route,"CPU announces the route before actual travel")
	var elapsed=game.movement.elapsed;var hp=game.battle.units[0].hp
	game._help();await _settle(12)
	_check(game.movement.elapsed==elapsed and game.battle.units[0].hp==hp,"GPU HELP freezes CPU travel and action")
	game._close_aux();game.selected=0
	await _observe("cpu-1920")
	for i in range(60):
		await _settle(1)
		if game.battle.turn==2:break
	_check(game.battle.turn==2 and game.battle.history.size()==2,"CPU attack follows arrival once")
	game._restart();game.cpu_enabled=false
func _terminal() -> void:
	game.collection.stage_index=2;game._start_battle();await _settle()
	# 移動で終局する境界だけの明示fixture。製品の通常配置と動画には使わない。
	game.battle.actor=0;game.battle.units[0].pos=Vector2i(8,0);game.battle.units[3].pos=Vector2i.ZERO;game._follow_turn()
	_cell(Vector2i(9,0));_cell(Vector2i(9,0),true);await _settle(3)
	_check(game.movement.active and game.battle.result=="VICTORY" and not is_instance_valid(game.overlay),"movement terminal waits for landing display")
	await _observe("terminal-1920")
	_check(is_instance_valid(game.overlay) and game.result_awarded and game.battle.history.size()==1 and game.battle.turn==1,"landing opens only one terminal result without extra action")
	var result=game.overlay;await _settle(10)
	_check(game.overlay==result,"terminal result is not recreated")
	_shot("terminal-1920")
