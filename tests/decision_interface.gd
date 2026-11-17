extends SceneTree
var checks=0
var failures=0
var game
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	game=load("res://ui/main.gd").new()
	game.settings_path="res://artifacts/runtime/decisions-no-settings.json"
	game.save_path="res://artifacts/runtime/decisions-no-save.json"
	root.add_child(game)
	await process_frame
	game.set_process(false)
	await _entry_points()
	_marker()
	_route_geometry()
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
	game.battle.actor=2
	game.battle.path_click(Vector2i(5,4))
	game.battle.commit_path()
	var before=[game.battle.units.duplicate(true),game.battle.history.duplicate(),game.battle.mode]
	_check(game.has_method("_reselect_path"),"UI has one protected reselection entry")
	if game.has_method("_reselect_path"):
		game._reselect_path()
	_check(before==[game.battle.units,game.battle.history,game.battle.mode],"human cannot invoke reselection on an enemy CPU turn")
	game.cpu_enabled=false
## REQ-018-S02、REQ-018-S04、REQ-018-S05
func _marker() -> void:
	_check(game.has_method("_acting_marker"),"map describes exactly one current-turn shape")
	if not game.has_method("_acting_marker"):
		return
	game._start_battle()
	for actor in range(4):
		game.battle.actor=actor
		game.selected=(actor+1)%4
		game.timeline_hover=(actor+2)%4
		var marker=game._acting_marker()
		_check(marker.index==actor and marker.cell==game.battle.units[actor].pos and marker.points.size()==3,"marker follows the real actor instead of inspection or camp")
		var cell=game._cell_rect(marker.cell)
		var center=game._board_point(marker.cell)+game.T.UNIT_BOARD_CENTER*game.BOARD_SCALE
		var extent=game.T.UNIT_BOARD_RADIUS*game.BOARD_SCALE*(game.T.UNIT_RING_RADII[-1]+game.T.UNIT_RING_WIDTH/2)
		var icon=Rect2(game._board_point(marker.cell)+game.T.PANEL_ICON_OFFSET*game.BOARD_SCALE,Vector2.ONE*game.T.PANEL_ICON_SIZE*game.BOARD_SCALE)
		for p in marker.points:
			_check(cell.grow(-2).has_point(p) and p.distance_to(center)>extent and not icon.has_point(p),"shape stays inside the cell, outside rings, icon and boundary focus")
	for size_px in [Vector2i(1152,648),Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size=size_px
		game.battle.actor=0
		for endpoint in [Vector2i(0,0),Vector2i(9,9)]:
			game.battle.units[0].pos=endpoint
			var marker=game._acting_marker()
			_check(marker.cell==endpoint and Array(marker.points).all(func(p):return game._cell_rect(endpoint).has_point(p)),"edge marker remains inside enlarged map "+str(size_px))
	game.battle.result="VICTORY"
	_check(game._acting_marker().is_empty(),"terminal view has no current-turn marker")
	game.battle.result=""
	game.battle.units[0].hp=0
	_check(game._acting_marker().is_empty(),"defeated actor is never marked")
## REQ-018-S02、REQ-018-S04、REQ-018-S05
func _route_geometry() -> void:
	game._start_battle()
	for delta in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
		game.battle.path=[game.battle.units[0].pos+delta]
		var marker=game._acting_marker()
		for segment in game._route_segments():
			for edge in range(3):
				var a=marker.points[edge]
				var b=marker.points[(edge+1)%3]
				_check(Geometry2D.segment_intersects_segment(a,b,segment[0],segment[1])==null,"current-turn shape never intersects an orthogonal route")
				var closest=Geometry2D.get_closest_point_to_segment(a,segment[0],segment[1])
				_check(a.distance_to(closest)>game.T.ROUTE_LINE_WIDTH*game.BOARD_SCALE,"route stroke is separate from marker edge")
	game.cpu_enabled=true
	game.battle.actor=2
	game.cpu_turn.begin(game.battle,{"path":[Vector2i(5,4)],"skill":"","target":-1})
	game.cpu_turn.phase="RESULT"
	game.battle.actor=3
	_check(game._acting_marker().index==3,"CPU result hold marks the same next actor as the actual timeline")
	game.cpu_turn.reset()
	game.cpu_enabled=false
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
