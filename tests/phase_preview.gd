extends SceneTree
const V=preload("res://ui/visuals.gd")
const C=preload("res://game/catalog.gd")
const P=preload("res://ui/palette.gd")
const T=preload("res://game/tuning.gd")
var checks=0
var failures=0
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var visual=V.new()
	if visual.has_method("phase_field") and visual.has_method("phase_contours"):
		_test_fields(visual)
		_test_contours(visual)
	else:
		_check(false,"actual phase field and closed contours exist")
	await _test_ui()
	await _test_board()
	print("PHASE PREVIEW: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
## REQ-033-S01
func _test_fields(visual) -> void:
	var u=C.unit("01","PLAYER",Vector2i.ZERO,C.default_build())
	var colors=P.PRESETS.DEFAULT.slice(1)
	var before=u.duplicate(true)
	var aligned: Dictionary=visual.phase_field(u,36.0,colors)
	_check(aligned.roles==[0,0,0] and aligned.profiles==[1.0,1.0,1.0],"same VIT centers have exact three profiles")
	_check(is_equal_approx(aligned.clarity,1.0) and aligned.color==colors[0],"full same-status overlap is clear VIT")
	_check(is_equal_approx(aligned.height,1.0),"fully matched sector centers reach full radial amplitude")
	var aligned_curves: Array=visual.phase_contours(u,colors)
	var center_index=int(T.new().get("PREVIEW_SAMPLES")/10)
	for r in range(4):
		var curve=aligned_curves[r]
		var base=T.new().get("PREVIEW_RADII")[r]
		var amplitude=T.new().get("PREVIEW_AMPLITUDES")[r]
		_check(curve.points[0].is_equal_approx(Vector2(0,-base)) and is_equal_approx(curve.points[center_index].length(),base+amplitude),"boundary valley and sector-center peak follow actual angular distribution: "+curve.role)
		var expected=Color(colors[0],T.new().get("PREVIEW_CLEAR_ALPHA") if r<3 else T.new().get("PREVIEW_RESULT_CLEAR_ALPHA"))
		_check(curve.colors[center_index].is_equal_approx(expected),"matched contours use exact VIT RGB and clear opacity: "+curve.role)
	u.arms_angle=72.0
	var pair: Dictionary=visual.phase_field(u,36.0,colors)
	_check(pair.roles==[0,0,4] and is_equal_approx(pair.clarity,1.0/6.0),"single pair has independently calculated local weight")
	_check(is_equal_approx(pair.height,1.0/6.0),"pair height uses actual sector profiles")
	u.gear_angle=72.0
	u.arms_angle=144.0
	var none: Dictionary=visual.phase_field(u,36.0,colors)
	_check(none.roles==[0,4,3] and none.clarity==0.0,"three distinct statuses have no overlap")
	_check(none.height==0.0,"no same-status overlap has no result displacement")
	_check(aligned.clarity>pair.clarity and pair.clarity>none.clarity,"clarity is ordered by actual overlap")
	u.gear_angle=0.0
	u.arms_angle=0.0
	_check(u==before,"field evaluation leaves input untouched")
## REQ-033-S02
func _test_contours(visual) -> void:
	var u=C.unit("02","PLAYER",Vector2i.ZERO,C.default_build())
	var colors=P.PRESETS.ICE.slice(1)
	u.class_name="REVERSE"
	u.core=[1,96,1,1,1]
	u.gear_mutation="LSRIV"
	u.gear_angle=359.0
	u.arms_angle=73.5
	var before=u.duplicate(true)
	var curves: Array=visual.phase_contours(u,colors)
	_check(curves.size()==4 and curves.map(func(c):return c.role)==["CORE","GEAR","ARMS","RESULT"],"exactly the requested four contours")
	for curve in curves:
		_check(curve.points.size()==T.new().get("PREVIEW_SAMPLES")+1 and curve.colors.size()==curve.points.size(),"bounded samples and per-vertex colors: "+curve.role)
		_check(curve.points[0].is_equal_approx(curve.points[-1]) and curve.colors[0]==curve.colors[-1],"closed seam including color: "+curve.role)
		_check(Array(curve.points).all(func(point):return is_finite(point.x) and is_finite(point.y)),"finite points at small sectors: "+curve.role)
	_check(curves==visual.phase_contours(u,colors) and u==before,"repeat evaluation is exact and pure")
	var field: Dictionary=visual.phase_field(u,0.8,colors)
	_check(field.roles[0]==0,"small 1 percent reversed CORE sector retains VIT")
	field=visual.phase_field(u,20.0,colors)
	_check(field.roles[0]==1,"reversed CORE order follows actual INF sector")
	var custom=colors.duplicate()
	custom[0]=P.PRESETS.DEFAULT[1]
	_check(visual.phase_contours(u,custom)!=curves and u==before,"new custom color updates output without mutation")
	u.gear_angle=80.0
	_check(visual.phase_contours(u,colors)!=curves,"rotation updates the contour")
## REQ-033-S02、REQ-019-S01
func _test_ui() -> void:
	var game=load("res://tests/phase_preview_audit.gd").new()
	game.settings_path="res://artifacts/runtime/preview-no-settings-"+str(Time.get_ticks_usec())+".json"
	root.add_child(game)
	await process_frame
	game._start_battle()
	await create_timer(0.08).timeout
	var texts=game.preview_text.map(func(t):return t.text)
	_check(not texts.any(func(s):return s.begins_with("G ") or s.begins_with("A ") or s in ["0°","180°","360°","INF SYNC","RES SYNC","SINGULARITY ×5"]),"obsolete angles and wide resonance labels removed")
	_check(not game.drawn_text.any(func(t):return t.text=="ROUTE → PHASE → EFFECT"),"bottom route phase effect removed")
	_check(texts.has("INF 200.0%") and texts.has("RES 200.0%"),"compact final factors use original model")
	var curves=game.get("preview_contours")
	if curves==null:
		_check(false,"preview connects and caches the actual contours")
	else:
		_check(curves.size()==4,"preview draws all four contours")
		var generation=game.preview_generation
		game.selected=2
		game.queue_redraw()
		await create_timer(0.08).timeout
		_check(game.preview_generation==generation,"inspecting another unit does not rebuild acting preview")
		game._cell_input(Vector2i(4,4))
		await create_timer(0.08).timeout
		_check(game.preview_generation==generation+1 and game.preview_contours!=curves,"route updates exactly once")
		# (4,4)はLOCKなのでGEARは0度、ARMSだけ30度進む。
		_check(game.preview_rings.size()==1 and game.preview_rings[0].unit.id=="01" and game.preview_rings[0].unit.gear_angle==0.0 and game.preview_rings[0].unit.arms_angle==30.0,"3 rings still use acting route preview through LOCK")
		var units=game.battle.units.duplicate(true)
		game.palette_colors=game.P.PRESETS.AMBER.duplicate()
		game._set_theme()
		await create_timer(0.08).timeout
		_check(game.preview_generation==generation+2 and game.battle.units==units and game.battle.path==[Vector2i(4,4)],"palette updates once without changing battle or route")
		var actual: Color=game.preview_contours[0].colors[0]
		var expected: Color=P.PRESETS.AMBER[1]
		_check(is_equal_approx(actual.r,expected.r) and is_equal_approx(actual.g,expected.g) and is_equal_approx(actual.b,expected.b),"orbit connects base status RGB independently of vivid ring palette")
		game.queue_redraw()
		await create_timer(0.08).timeout
		_check(game.preview_generation==generation+2,"time does not change or recompute orbit")
	game._help()
	await process_frame
	var guide=game.auxiliary.find_children("*","Label",true,false).filter(func(label):return label.text.contains("外側") and label.text.contains("重なり"))
	_check(guide.size()==1,"HELP explains ordered contours and overlap")
	if guide.size()==1:
		var label=guide[0]
		var next=game.auxiliary.find_children("*","Label",true,false).filter(func(item):return item.text.begins_with("終点をダブルクリック"))[0]
		_check(Array(label.text.split("\n")).all(func(line):return label.position.x+game.font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x<next.position.x),"orbit guide does not cross into next HELP column")
	game.queue_free()
	await process_frame
## NREQ-001-S02、REQ-027-S01
func _test_board() -> void:
	var game=load("res://main.tscn").instantiate()
	game.settings_path="res://artifacts/runtime/preview-map-no-settings.json"
	root.add_child(game)
	await process_frame
	game._start_battle()
	var cell_size=game.get("CELL")
	if cell_size==null:
		_check(false,"drawing and input use shared enlarged board geometry")
	else:
		_check(cell_size>70 and game.BOARD.x>520 and game.BOARD.x+10*cell_size<1300,"map is larger without touching side panels")
		var bounds=Rect2(game.BOARD,Vector2.ONE*10*cell_size)
		var cases=[{"p":bounds.position+Vector2.ONE*0.1,"cell":Vector2i(0,0)},{"p":bounds.end-Vector2.ONE*0.1,"cell":Vector2i(9,9)},{"p":bounds.position-Vector2.ONE*0.1,"cell":Vector2i(-1,-1)},{"p":bounds.end,"cell":Vector2i(-1,-1)}]
		for item in cases:
			var event=InputEventMouseMotion.new()
			event.position=item.p
			game._unhandled_input(event)
			_check(game.hover_cell==item.cell,"map boundaries use displayed extent: "+str(item.p))
		for dimensions in [Vector2i(1152,648),Vector2i(1600,1200),Vector2i(2560,1080),Vector2i(1200,1600),Vector2i(1920,1080)]:
			root.size=dimensions
			await process_frame
			game._start_battle()
			var event=InputEventMouseButton.new()
			event.button_index=MOUSE_BUTTON_LEFT
			event.pressed=true
			event.position=root.get_final_transform()*(game.BOARD+(Vector2(4,4)+Vector2.ONE/2)*cell_size)
			root.push_input(event,false)
			_check(game.battle.path==[Vector2i(4,4)],"actual scaled click reaches enlarged cell: "+str(dimensions))
	game.queue_free()
	await process_frame
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
