extends SceneTree
const V=preload("res://ui/visuals.gd")
const T=preload("res://game/tuning.gd")
const C=preload("res://game/catalog.gd")
const P=preload("res://ui/palette.gd")
var checks=0
var failures=0
func _initialize() -> void:
	_run.call_deferred()
## REQ-018-S02
func _run() -> void:
	var visual=V.new()
	_check(visual.has_method("route_segment") and visual.has_method("route_unit_clearance"),"route uses explicit glyph clearance")
	if visual.has_method("route_segment") and visual.has_method("route_unit_clearance"):
		_test_geometry(visual)
		await _test_connection()
	print("ROUTE CLEARANCE: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
## REQ-018-S02
func _test_geometry(visual) -> void:
	var radius=T.UNIT_BOARD_RADIUS*T.BATTLE_CELL/70.0
	var width=T.ROUTE_LINE_WIDTH*T.BATTLE_CELL/70.0
	var unit=C.unit("01","PLAYER",Vector2i.ZERO,C.default_build())
	for scale in [0.6,1.0,2.4]:
		var clear: float=visual.route_unit_clearance(radius,width,scale)
		# 円弧の半径、物理下限と目盛りを独立して評価する。
		var glyph=V.glyph(radius,unit,true,P.PRESETS.DEFAULT.slice(1),P.PRESETS.DEFAULT[0])
		var outer=0.0
		for arc in glyph.arcs:
			var floor_px=T.UNIT_HP_PIXEL_MIN if arc.role=="HP" else T.UNIT_COLOR_PIXEL_MIN
			outer=maxf(outer,arc.radius+maxf(arc.width,floor_px/scale)/2)
		outer=maxf(outer,glyph.tick.to.length()+glyph.tick.width/2)
		_check(is_equal_approx(clear,outer+width/2+T.new().get("ROUTE_RING_GAP_PIXELS")/scale),"clearance includes glyph stroke, route half width and physical gap "+str(scale))
		for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
			for ends in [Vector2(clear,0),Vector2(0,clear),Vector2(clear,clear)]:
				var segment=visual.route_segment(Vector2.ZERO,direction*T.BATTLE_CELL,ends.x,ends.y)
				_check(segment.size()==2 and segment[0].is_equal_approx(direction*ends.x) and segment[1].is_equal_approx(direction*(T.BATTLE_CELL-ends.y)),"both ends independently clip in "+str(direction)+" / "+str(ends))
				_check(segment[0].distance_to(Vector2.ZERO)-width/2>outer if ends.x>0 else true,"start line does not touch glyph")
				_check(segment[1].distance_to(direction*T.BATTLE_CELL)-width/2>outer if ends.y>0 else true,"end line does not touch glyph")
	_check(visual.route_segment(Vector2.ZERO,Vector2.ZERO,0,0).is_empty(),"zero-length interval omitted")
	_check(visual.route_segment(Vector2.ZERO,Vector2(40,0),20,20).is_empty(),"no line when clearances meet")
	_check(visual.route_segment(Vector2.ZERO,Vector2(39,0),20,20).is_empty(),"no reversed line when clearances exceed length")
	_check(visual.route_segment(Vector2.ZERO,Vector2(100,0),0,0)==PackedVector2Array([Vector2.ZERO,Vector2(100,0)]),"no units leaves the original segment")
## REQ-018-S02
func _test_connection() -> void:
	root.size=Vector2i(1920,1080)
	await process_frame
	var game=load("res://tests/fixture_main.gd").new()
	game.settings_path="res://artifacts/runtime/clearance-lab-"+str(Time.get_ticks_usec())+".json"
	root.add_child(game)
	await process_frame
	game._start_battle()
	_check(game.has_method("_route_segments"),"board connects route projection")
	if game.has_method("_route_segments"):
		for start in [Vector2i(0,0),Vector2i(5,5),Vector2i(9,9)]:
			game.battle.units[0].pos=start
			var step=Vector2i.RIGHT if start.x<9 else Vector2i.LEFT
			game.battle.path=[start+step,start+step*2]
			var units=game.battle.units.duplicate(true)
			var path=game.battle.path.duplicate()
			var parts=game._route_segments()
			_check(parts.size()==2,"start and intermediate segments kept at "+str(start))
			if parts.size()==2:
				var center=game.BOARD+(Vector2(start)+Vector2.ONE/2)*game.CELL
				_check(parts[0][0].distance_to(center)>T.UNIT_BOARD_RADIUS*game.BOARD_SCALE*T.UNIT_RING_RADII.max(),"actual board clips before the outer ring")
			_check(game.battle.units==units and game.battle.path==path,"projection leaves model and route unchanged")
		game.battle.units[0].pos=Vector2i(4,4)
		game.battle.units[1].pos=Vector2i(5,4)
		# 表示fixtureで終点にもユニットを置き、合法性を緩めず描画だけの境界を確認する。
		game.battle.path=[Vector2i(5,4)]
		var parts=game._route_segments()
		var end=game.BOARD+Vector2(5.5,4.5)*game.CELL
		_check(parts.size()==1 and parts[0][1].distance_to(end)>T.UNIT_BOARD_RADIUS*game.BOARD_SCALE*T.UNIT_RING_RADII.max(),"occupied endpoint is clipped too")
	game.queue_free()
	await process_frame
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
