extends SceneTree
const V=preload("res://ui/visuals.gd")
const C=preload("res://game/catalog.gd")
const T=preload("res://game/tuning.gd")
const P=preload("res://ui/palette.gd")
var checks=0
var failures=0
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var visual=V.new()
	if visual.has_method("glyph") and visual.has_method("unit_name"):
		_test_glyph(visual)
		_test_names(visual)
	else:
		_check(false,"common glyph geometry and presentation-only names are implemented")
	await _test_screens()
	print("UNIT GLYPHS: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
## REQ-030-S01、REQ-030-S02
func _test_glyph(visual) -> void:
	var u=C.unit("01","PLAYER",Vector2i.ZERO,C.default_build())
	var before=u.duplicate(true)
	var glyph: Dictionary=visual.glyph(24.0,u,false,P.PRESETS.DEFAULT.slice(1),P.PRESETS.DEFAULT[0])
	_check(glyph.name=="1","glyph contains centered presentation name")
	_check(glyph.arcs.size()==16,"exactly fifteen sectors and HP; no outer frame or track")
	for r in range(3):
		for s in range(5):
			var arc=glyph.arcs[r*5+s]
			_check(arc.role==["CORE","GEAR","ARMS"][r] and arc.color==P.PRESETS.DEFAULT[s+1],"layer and palette mapping %d/%d" % [r,s])
			_check(arc.start>deg_to_rad(s*72.0-90) and arc.end<deg_to_rad((s+1)*72.0-90),"each sector has a real boundary gap %d/%d" % [r,s])
			_check(is_equal_approx(arc.radius,24.0*T.new().get("UNIT_RING_RADII")[r]) and is_equal_approx(arc.width,maxf(T.new().get("UNIT_MIN_LINE"),24.0*T.new().get("UNIT_RING_WIDTH"))),"single-source thin geometry %d/%d" % [r,s])
	_check(glyph.arcs[15].role=="HP" and glyph.arcs[15].color==P.TEXT,"HP is white independently of palette")
	_check(glyph.arcs[15].radius+glyph.arcs[15].width/2<glyph.arcs[0].radius-glyph.arcs[0].width/2,"HP is entirely inside CORE")
	_check(u==before,"render description does not mutate the model")
	for hp in [0,50,89,100]:
		u.hp=hp
		var g: Dictionary=visual.glyph(24.0,u,false,P.PRESETS.AMBER.slice(1),P.PRESETS.AMBER[0])
		var health=g.arcs.filter(func(a):return a.role=="HP")
		_check(health.size()==(0 if hp==0 else 1),"HP zero has no white arc; otherwise exactly one: "+str(hp))
		if hp>0:
			_check(is_equal_approx(health[0].start,-PI/2) and is_equal_approx(health[0].end-health[0].start,TAU*hp/100.0),"independent HP ratio "+str(hp))
	var rotated=u.duplicate(true)
	rotated.gear_angle=90.0
	rotated.arms_angle=180.0
	var g: Dictionary=visual.glyph(24.0,rotated,true,P.PRESETS.AMBER.slice(1),P.PRESETS.AMBER[0])
	_check(is_equal_approx(g.arcs[5].start-glyph.arcs[5].start,PI/2) and is_equal_approx(g.arcs[10].start-glyph.arcs[10].start,PI),"rings retain actual independent phase angles")
	_check(g.tick.color==P.PRESETS.AMBER[0] and glyph.tick.color==P.TEXT,"active marker changes without circular frame")
	u.core=[1,96,1,1,1]
	g=visual.glyph(22.0,u,false,P.PRESETS.DEFAULT.slice(1),P.PRESETS.DEFAULT[0])
	_check(g.arcs[0].end>g.arcs[0].start and g.arcs[1].end>g.arcs[1].start,"smallest valid sectors survive the gap")
## REQ-031-S01
func _test_names(visual) -> void:
	var ids=["01","02","A","B"]
	var expected=["1","2","A","B"]
	for i in range(4):
		var u=C.unit(ids[i],"PLAYER" if i<2 else "ENEMY",Vector2i.ZERO,C.default_build())
		_check(visual.unit_name(u)==expected[i] and u.id==ids[i],"display mapping preserves internal identity: "+ids[i])
## REQ-031-S02、REQ-030-S01
func _test_screens() -> void:
	var game=load("res://tests/unit_glyph_audit.gd").new()
	game.settings_path="res://artifacts/runtime/unit-test-no-settings.json"
	root.add_child(game)
	await process_frame
	var buttons=game.overlay.find_children("*","Button",true,false).map(func(b):return b.text)
	_check(buttons.has("UNIT 1") and buttons.has("UNIT 2") and not buttons.has("UNIT 01"),"BUILD presents unpadded unit names")
	game.collection.stage_index=2
	game._build()
	await process_frame
	var texts=game.overlay.find_children("*","Label",true,false).map(func(l):return l.text)
	_check(texts.has("1 REACH (9,0) / KEEP 1 ALIVE / STOP B (0,9)"),"BUILD objective uses display names")
	_check(texts.has("Lose if 1 falls. A guards the exit; 2 can intercept B."),"BUILD hint uses display names")
	var stages=game.overlay.find_children("*","OptionButton",true,false)
	_check(stages.any(func(o):return o.get_item_text(0)=="01 / INTERFERENCE" and o.get_item_text(1)=="02 / SEVERANCE"),"stage numbering remains unchanged")
	game._help()
	await process_frame
	texts=game.auxiliary.find_children("*","Label",true,false).map(func(l):return l.text)
	_check(texts.any(func(s):return s.begins_with("1と2を編集し")),"HELP refers to 1 and 2")
	game._close_aux()
	game.collection.stage_index=0
	game._start_battle()
	game.message_time=0
	await create_timer(0.08).timeout
	var contexts=game.rings.map(func(r):return r.center)
	_check(contexts.has(Vector2(223,374)) and contexts.has(Vector2(805,407)) and contexts.has(Vector2(1535,245)) and contexts.has(Vector2(225,947)),"timeline, board, details, preview share the glyph")
	game._cell_input(Vector2i(4,4))
	game._cell_input(Vector2i(5,4))
	game._cell_input(Vector2i(5,4),true)
	await process_frame
	texts=game.overlay.find_children("*","Label",true,false).map(func(l):return l.text)
	_check(texts.has("UNIT 1 / ACTION") and not texts.has("UNIT 01 / ACTION"),"ACTION uses presentation name")
	_check(game.battle.units.map(func(u):return u.id)==["01","02","A","B"],"all screen transitions preserve internal IDs")
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
