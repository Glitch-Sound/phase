extends SceneTree
const P=preload("res://ui/palette.gd")
var checks=0
var failures=0
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var palette=P.new()
	_check(palette.has_method("ring_colors"),"ring-only presentation palette exists")
	if palette.has_method("ring_colors"):
		_test_presets(palette)
		_test_custom(palette)
	await _test_connection()
	print("RING PALETTE: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
## REQ-032-S01
func _test_presets(palette) -> void:
	for name in P.PRESETS:
		var input=P.PRESETS[name].duplicate()
		var before=input.duplicate()
		var rings=palette.ring_colors(input)
		_check(rings.size()==5,"exactly five ring colors: "+name)
		_check(input==before,"base preset is unchanged: "+name)
		for i in range(5):
			var original: Color=input[i+1]
			var actual: Color=rings[i]
			_check(absf(wrapf(actual.h-original.h,-0.5,0.5))<0.00001 and is_equal_approx(actual.v,original.v),"same hue and HSV value: "+name+"/"+str(i))
			_check(actual.s>original.s and actual.a==1.0,"more vivid and opaque: "+name+"/"+str(i))
		var rendered=[input[0]]
		rendered.append_array(rings)
		_check(P.validate(rendered).is_empty(),"derived palette remains readable and distinct: "+name)
## REQ-032-S02
func _test_custom(palette) -> void:
	var custom=P.PRESETS.DEFAULT.duplicate()
	custom[0]=P.PRESETS.AMBER[0]
	var before=custom.duplicate()
	_check(palette.ring_colors(custom)==custom.slice(1),"accent-only customization preserves all exact status RGBs")
	_check(custom==before,"custom input is not mutated")
	custom[2]=Color("f4adb5")
	_check(palette.ring_colors(custom)==custom.slice(1),"custom status RGB remains exact")
## REQ-032-S02、REQ-032-S03
func _test_connection() -> void:
	var stamp=str(Time.get_unix_time_from_system()).replace(".","-")
	var path="res://artifacts/runtime/ring-palette-"+stamp+".json"
	var custom=P.PRESETS.DEFAULT.duplicate()
	custom[0]=P.PRESETS.AMBER[0]
	var expected=custom.map(func(c):return c.to_html(false))
	var content=JSON.stringify(expected)
	var file=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(content)
	file.close()
	var game=load("res://tests/fixture_main.gd").new()
	game.settings_path=path
	root.add_child(game)
	await process_frame
	_check(game.palette_colors==custom and game.get("ring_colors")==custom.slice(1),"existing custom colors load exactly")
	_check(FileAccess.get_file_as_string(path)==content,"load and draw do not rewrite existing settings")
	game._start_battle()
	game._cell_input(Vector2i(4,4))
	var units=game.battle.units.duplicate(true)
	var route=game.battle.path.duplicate()
	game._settings()
	await process_frame
	var labels=game.auxiliary.find_children("*","Label",true,false).map(func(l):return l.text)
	_check(labels.has("RINGS: VIVID PRESETS / CUSTOM COLORS AS CHOSEN"),"color settings explains the presentation relationship")
	for i in range(6):
		game.palette_pickers[i].color=P.PRESETS.DEFAULT[i]
	game._apply_colors()
	await process_frame
	_check(game.palette_colors==P.PRESETS.DEFAULT and game.status_colors==P.PRESETS.DEFAULT.slice(1) and game.CYAN==P.PRESETS.DEFAULT[0],"other UI retains the original base palette")
	_check(game.get("ring_colors")!=game.status_colors and game.get("ring_colors")!=null,"preset ring presentation is connected")
	_check(JSON.parse_string(FileAccess.get_file_as_string(path))==P.PRESETS.DEFAULT.map(func(c):return c.to_html(false)),"explicit preset save stores base colors, not derived colors")
	for i in range(6):
		game.palette_pickers[i].color=custom[i]
	game._apply_colors()
	await process_frame
	_check(game.get("ring_colors")==custom.slice(1),"switching to custom restores exact chosen colors")
	_check(JSON.parse_string(FileAccess.get_file_as_string(path))==expected,"explicit custom save remains exact")
	_check(game.battle.units==units and game.battle.path==route,"palette changes preserve battle and pending route")
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
