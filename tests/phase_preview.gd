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
		_test_gradient(visual)
		_test_strength(visual)
		_test_smooth_strength(visual)
	else:
		_check(false,"actual phase field and closed contours exist")
	await _test_ui()
	await _test_board()
	await _test_notifications()
	await _test_compact_layout()
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
	_check(not texts.any(func(text):return text.begins_with("INF ") or text.begins_with("RES ")),"final numerical factors have no replacement")
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
		# (4,4)はRESETでCOREは開始角0度へ戻り、両装備は通常の1歩分を回転する。
		_check(game.preview_rings.size()==1 and game.preview_rings[0].unit.id=="01" and game.preview_rings[0].unit.gear_angle==330.0 and game.preview_rings[0].unit.arms_angle==30.0 and game.preview_rings[0].unit.get("core_angle",0)==0.0,"3 rings still use acting route preview through RESET")
		var units=game.battle.units.duplicate(true)
		game.palette_colors=game.P.PRESETS.AMBER.duplicate()
		game._set_theme()
		await create_timer(0.08).timeout
		_check(game.preview_generation==generation+2 and game.battle.units==units and game.battle.path==[Vector2i(4,4)],"palette updates once without changing battle or route")
		var actual: Color=game.preview_contours[0].colors[0]
		var expected: Color=P.PRESETS.AMBER[5].lerp(P.PRESETS.AMBER[1],0.5)
		_check(is_equal_approx(actual.r,expected.r) and is_equal_approx(actual.g,expected.g) and is_equal_approx(actual.b,expected.b),"orbit blends actual boundary colors independently of vivid ring palette")
		game.queue_redraw()
		await create_timer(0.08).timeout
		_check(game.preview_generation==generation+2,"time does not change or recompute orbit")
	game._help()
	await process_frame
	var guide=game.auxiliary.find_children("*","Label",true,false).filter(func(label):return label.text=="4輪郭はCORE、GEAR、ARMSと全体。\n実位相の一致を示し、境界色を補間。")
	_check(guide.size()==1,"HELP explains overlapping roles and interpolation without an inner-to-outer order")
	if guide.size()==1:
		var label=guide[0]
		var next=game.auxiliary.find_children("*","Label",true,false).filter(func(item):return item.text.begins_with("終点をダブルクリック"))[0]
		_check(Array(label.text.split("\n")).all(func(line):return label.position.x+game.font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x<next.position.x),"orbit guide does not cross into next HELP column")
	game.queue_free()
	await process_frame
## NREQ-001-S02、REQ-027-S01
func _test_board() -> void:
	var game=load("res://tests/fixture_main.gd").new()
	game.settings_path="res://artifacts/runtime/preview-map-no-settings.json"
	root.add_child(game)
	await process_frame
	game._start_battle()
	var cell_size=game.get("CELL")
	if cell_size==null:
		_check(false,"drawing and input use shared enlarged board geometry")
	else:
		_check(cell_size>70 and game.BOARD.x>0 and game.BOARD.x+10*cell_size<1920,"map is larger without touching side panels")
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
## REQ-033-S03、NREQ-001-S01
func _test_notifications() -> void:
	var game=load("res://tests/phase_preview_audit.gd").new()
	game.settings_path="res://artifacts/runtime/notification-no-settings-"+str(Time.get_ticks_usec())+".json"
	root.add_child(game)
	await process_frame
	for state in ["start","invalid-move","invalid-target"]:
		game._start_battle()
		await process_frame
		var expected="UNIT 1 / PLAYER — Click adjacent empty cells, then double-click the endpoint."
		if state=="invalid-move":
			game._cell_input(Vector2i(0,9))
			expected="Add an empty adjacent cell. No revisits. Maximum %d steps." % T.BASE_MOVE
		elif state=="invalid-target":
			game._cell_input(Vector2i(4,4))
			game._cell_input(Vector2i(5,4))
			game._cell_input(Vector2i(5,4),true)
			await process_frame
			game.battle.choose_skill(game.C.DAMAGE)
			game._clear_overlay()
			game._hud()
			game._cell_input(Vector2i(0,0))
			expected="Choose a highlighted adjacent target. BACK keeps your movement."
		await create_timer(0.08).timeout
		var messages=game.drawn_text.filter(func(item):return item.text==expected)
		_check(game.message==expected and game.message_time>0 and messages.size()==1,"real notification is visible: "+state)
		if messages.size()!=1:
			continue
		var bounds=_text_bounds(messages[0])
		var metrics=game.drawn_text.filter(func(item):return item.text.begins_with("INF ") or item.text.begins_with("RES "))
		_check(metrics.is_empty(),"removed sync text stays absent during notifications: "+state)
		_check(not bounds.intersects(game.T.PREVIEW_PANEL) and not bounds.intersects(Rect2(game.BOARD,Vector2.ONE*game.CELL*10)),"notification is separate from rings and map: "+state)
		var buttons=game.hud.find_children("*","Button",true,false)
		_check(buttons.all(func(button):return not bounds.intersects(button.get_global_rect())),"notification does not obscure actions or footer: "+state)
		if state=="start":
			for dimensions in [Vector2i(1152,648),Vector2i(1440,810),Vector2i(1200,1600),Vector2i(1920,1080)]:
				root.size=dimensions
				await process_frame
				var transform=root.get_final_transform()
				var visible=Rect2(Vector2.ZERO,Vector2(dimensions))
				_check(visible.encloses(transform*bounds),"longest notification stays visible at "+str(dimensions))
	game._process(8.0)
	await create_timer(0.08).timeout
	_check(not game.drawn_text.any(func(item):return item.text==game.message),"expired notification no longer draws")
	game.queue_free()
	await process_frame
## REQ-033-S04
func _test_gradient(visual) -> void:
	var u=C.unit("01","PLAYER",Vector2i.ZERO,C.default_build())
	for key in ["core","gear","arms"]:
		u[key]=[20,20,20,20,20]
	var colors=P.PRESETS.ICE.slice(1)
	var curves: Array=visual.phase_contours(u,colors)
	var index=int(T.PREVIEW_SAMPLES/5)
	var mix=colors[0].lerp(colors[1],0.5)
	var radii=T.PREVIEW_RADII
	_check(radii.max()-radii.min()<T.PREVIEW_AMPLITUDES.min(),"four contours share an overlapping radial band")
	for curve in curves:
		var actual: Color=curve.colors[index]
		_check(Vector3(actual.r,actual.g,actual.b).is_equal_approx(Vector3(mix.r,mix.g,mix.b)),"true VIT-INF boundary is the exact adjacent-color midpoint: "+curve.role)
		var a: Color=curve.colors[index-1]
		var b: Color=curve.colors[index+1]
		var span=Vector3(colors[0].r-colors[1].r,colors[0].g-colors[1].g,colors[0].b-colors[1].b).length()
		_check(Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length()<span/4,"boundary color connects smoothly: "+curve.role)
	var aligned_alpha=curves[3].colors[int(T.PREVIEW_SAMPLES/10)].a
	u.gear_angle=72.0
	u.arms_angle=144.0
	var apart: Array=visual.phase_contours(u,colors)
	_check(aligned_alpha>apart[3].colors[int(T.PREVIEW_SAMPLES/10)].a,"result clarity still distinguishes actual agreement")
## REQ-033-S01、REQ-033-S03、REQ-033-S04
func _test_strength(visual) -> void:
	var u=C.unit("01","PLAYER",Vector2i.ZERO,C.default_build())
	var colors=P.PRESETS.DEFAULT.slice(1)
	var states=[]
	for angles in [[0.0,72.0,144.0],[0.0,0.0,72.0],[0.0,0.0,0.0]]:
		u.core_angle=angles[0]
		u.gear_angle=angles[1]
		u.arms_angle=angles[2]
		states.append(visual.phase_contours(u,colors))
	var middle=int(T.PREVIEW_SAMPLES/10)
	for r in range(4):
		var low=states[0][r]
		var medium=states[1][r]
		var high=states[2][r]
		_check(low.points[middle].length()<medium.points[middle].length() and medium.points[middle].length()<high.points[middle].length(),"low pair and full agreement have strictly increasing radial size "+high.role)
		_check(low.width<medium.width and medium.width<high.width,"low pair and full agreement have strictly increasing line clarity "+high.role)
		_check(low.colors[middle].a<medium.colors[middle].a and medium.colors[middle].a<high.colors[middle].a,"low pair and full agreement have strictly increasing brightness "+high.role)
		for status in range(5):
			var color: Color=high.colors[int((status+0.5)*T.PREVIEW_SAMPLES/5)]
			_check(Vector3(color.r,color.g,color.b).is_equal_approx(Vector3(colors[status].r,colors[status].g,colors[status].b)),"strength preserves exact status RGB "+high.role+" / "+str(status))
		_check(Array(high.points).all(func(point):return point.length()-high.width/2>T.PREVIEW_RADIUS and point.length()<=T.PREVIEW_RADII[r]+T.PREVIEW_AMPLITUDES[r]+0.001),"all strong contour points stay outside inner rings and inside the configured envelope")
## REQ-033-S04
func _test_smooth_strength(visual) -> void:
	var u=C.unit("01","PLAYER",Vector2i.ZERO,C.default_build())
	u.core=[20,20,15,30,15]
	u.core_angle=45.0
	u.gear_angle=90.0
	u.arms_angle=270.0
	var curves=visual.phase_contours(u,P.PRESETS.DEFAULT.slice(1))
	for r in range(3):
		var curve=curves[r]
		var bound=2*(T.PREVIEW_RADII[r]+T.PREVIEW_AMPLITUDES[r])*TAU/T.PREVIEW_SAMPLES
		var worst=0.0
		for i in range(curve.points.size()-1):
			worst=maxf(worst,curve.points[i].distance_to(curve.points[i+1]))
		_check(worst<bound,"partial agreement has no radial jump at role boundaries "+curve.role+" / "+str(worst))
## REQ-019-S05、NREQ-001-S04
func _test_compact_layout() -> void:
	var game=load("res://tests/map_orbit_audit.gd").new()
	game.settings_path="res://artifacts/runtime/map-layout-no-settings-"+str(Time.get_ticks_usec())+".json"
	root.add_child(game)
	await process_frame
	game._start_battle()
	await create_timer(0.08).timeout
	var board=Rect2(game.BOARD,Vector2.ONE*game.CELL*10)
	var buttons=game.hud.find_children("*","Button",true,false)
	_check(buttons.map(func(b):return b.get_rect().end.y).max()==board.end.y and buttons.all(func(b):return b.position.x>board.end.x),"square map retains height with menu aligned on right")
	_check(game.drawn_text.filter(func(t):return not t.in_board).all(func(t):return not _text_bounds(t).intersects(board)),"all peripheral text stays outside the expanded map")
	_check(not game.T.PREVIEW_PANEL.intersects(board) and buttons.all(func(b):return not b.get_global_rect().intersects(board)),"preview and system buttons stay outside map")
	for i in range(2):
		var label=game.drawn_text.filter(func(t):return t.text==["PLAYER","ENEMY"][i])[0]
		var value=game.drawn_text.filter(func(t):return t.text=="200 / 200")[i]
		var bar=game.drawn_bars[i].rect
		_check(label.position.y==value.position.y and _text_bounds(value).position.y<=bar.get_center().y and bar.get_center().y<=_text_bounds(value).end.y,"camp, HP value and bar share one row: "+str(i))
		_check(_text_bounds(label).end.x<_text_bounds(value).position.x and _text_bounds(value).end.x<bar.position.x and bar.end.x<board.position.x,"one-row HP fields do not overlap: "+str(i))
	var original=game.battle.units.duplicate(true)
	# VIT96の3係数から各11059.2、陣営合計22118.4となる表示境界を確認する。
	for i in range(2):
		game.battle.units[i].max_hp=T.BASE_HP*pow(96.0/20.0,3)
		game.battle.units[i].hp=game.battle.units[i].max_hp
	for empty in [false,true]:
		if empty:
			game.battle.units[0].hp=0
			game.battle.units[1].hp=0
		game.queue_redraw()
		await create_timer(0.08).timeout
		var expected="0 / 22118.4" if empty else "22118.4 / 22118.4"
		var value=game.drawn_text.filter(func(t):return t.text==expected)[0]
		var bar=game.drawn_bars[0]
		_check(_text_bounds(value).end.x<bar.rect.position.x and bar.rect.size.x>0 and bar.rect.end.x<board.position.x and value.font_size==T.BATTLE_HP_FONT_SIZE and bar.ratio==(0.0 if empty else 1.0),"maximum valid HP digits remain readable with a valid proportional bar: "+str(empty))
	for dimensions in [Vector2i(1152,648),Vector2i(1440,810),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(1200,1600)]:
		root.size=dimensions
		await process_frame
		var transform=root.get_final_transform()
		var visible=Rect2(Vector2.ZERO,Vector2(dimensions))
		_check(game.drawn_text.all(func(t):return visible.encloses(transform*_text_bounds(t))) and visible.encloses(transform*board),"map and all text fit at "+str(dimensions))
	game.battle.units=original
	# 新しい手番位置もウィンドウ座標から入力経路を通す。
	for row in [2,0]:
		var event=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=true
		event.position=root.get_final_transform()*(game._timeline_view().cards[row].center)
		root.push_input(event,false)
		_check(game.selected==row,"scaled current state selects its original unit: "+str(row))
	game._cell_input(Vector2i(4,4))
	game._cell_input(Vector2i(5,4))
	game._cell_input(Vector2i(5,4),true)
	await process_frame
	game.battle.choose_skill(game.C.DAMAGE)
	game._clear_overlay()
	game._hud()
	await process_frame
	var back=game.hud.find_children("*","Button",true,false).filter(func(b):return b.text=="BACK")[0]
	_check(not back.get_global_rect().intersects(board),"target BACK remains outside enlarged map")
	game.queue_free()
	await process_frame
func _text_bounds(item: Dictionary) -> Rect2:
	var font: Font=item.typeface
	var size: int=item.font_size
	return Rect2(item.position-Vector2(0,font.get_ascent(size)),Vector2(font.get_string_size(item.text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x,font.get_ascent(size)+font.get_descent(size)))
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
