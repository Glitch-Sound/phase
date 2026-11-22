extends SceneTree
var checks=0
var failures=0
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	if not ResourceLoader.exists("res://ui/palette.gd"):
		_check(false,"palette component is available")
		_finish()
		return
	var palette=load("res://ui/palette.gd")
	_test_palette(palette)
	var game=load("res://tests/fixture_main.gd").new()
	game.settings_path="res://artifacts/runtime/design-test-settings.json"
	palette.save_to(game.settings_path,palette.PRESETS.DEFAULT)
	root.add_child(game)
	await process_frame
	await _test_apply(game,palette)
	_test_icons(game)
	await _test_help_terms(game)
	await _test_action_context(game,palette)
	await _test_focus_scope(game)
	await _test_settings_state()
	game.queue_free()
	await process_frame
	_finish()

## REQ-028-S01、REQ-028-S02
func _test_palette(palette) -> void:
	for name in palette.PRESETS:
		_check(palette.validate(palette.PRESETS[name]).is_empty(),"readable preset "+name)
	var colors=palette.PRESETS.DEFAULT.duplicate()
	colors[0]=Color("08090b")
	_check(not palette.validate(colors).is_empty(),"reject dark accent")
	colors=palette.PRESETS.DEFAULT.duplicate()
	colors[2]=colors[3]
	_check(not palette.validate(colors).is_empty(),"reject identical status colors")
	colors=palette.PRESETS.DEFAULT.duplicate()
	colors[1].a=0.1
	_check(not palette.validate(colors).is_empty(),"reject transparent text")
	_check(not palette.validate([Color.WHITE]).is_empty(),"reject incomplete palette")
	colors=palette.PRESETS.DEFAULT.duplicate()
	colors[0]=Color("858585")
	_check(palette.validate(colors).is_empty(),"accept readable boundary accent")
	colors[0]=Color("7b7b7b")
	_check(not palette.validate(colors).is_empty(),"reject below contrast boundary")
	colors[0]=Color(NAN,1,1)
	_check(not palette.validate(colors).is_empty(),"reject nonfinite color")
	var path="res://artifacts/runtime/design-palette-test.json"
	_check(palette.save_to(path,palette.PRESETS.AMBER).is_empty(),"explicit palette save")
	_check(palette.load_from(path)==palette.PRESETS.AMBER,"palette round trip")
	var file=FileAccess.open(path,FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	_check(palette.load_from(path)==palette.PRESETS.DEFAULT,"invalid stored palette falls back")

## REQ-028-S01、REQ-028-S03
func _test_apply(game,palette) -> void:
	game._start_battle()
	await process_frame
	game._cell_input(Vector2i(4,4))
	var before=game.battle.units.duplicate(true)
	game._settings()
	await process_frame
	game.palette_pickers[0].color=Color("08090b")
	game._close_aux()
	await process_frame
	_check(game.palette_colors==palette.PRESETS.DEFAULT,"cancel preserves current palette")
	_check(game.battle.path==[Vector2i(4,4)] and game.battle.units==before,"cancel preserves route and model")
	game._settings()
	await process_frame
	for i in range(6):
		game.palette_pickers[i].color=palette.PRESETS.AMBER[i]
	game._apply_colors()
	await process_frame
	_check(game.palette_colors==palette.PRESETS.AMBER,"apply all six colors")
	_check(game.CYAN==palette.PRESETS.AMBER[0] and game.status_colors==palette.PRESETS.AMBER.slice(1),"drawing colors connected")
	_check(game.battle.path==[Vector2i(4,4)] and game.battle.units==before,"apply preserves route and model")
	for i in range(6):
		game.palette_pickers[i].color=Color.BLACK
	game._apply_colors()
	_check(game.palette_colors==palette.PRESETS.AMBER,"invalid apply leaves current palette")
	_check(not game.palette_error.text.is_empty(),"invalid apply explains reason")
	game._close_aux()
	await process_frame
	game._cell_input(Vector2i(5,4))
	game._cell_input(Vector2i(5,4),true)
	await process_frame
	_check(game._decision_battle().mode=="CHOICE","action overlay after palette apply")
	game._settings()
	await process_frame
	for i in range(6):
		game.palette_pickers[i].color=palette.PRESETS.DEFAULT[i]
	game._apply_colors()
	await process_frame
	_check(game._decision_battle().mode=="CHOICE" and is_instance_valid(game.overlay),"apply keeps action selection")
	game._close_aux()
	game._choose_battle_skill(game.C.DAMAGE)
	game._clear_overlay()
	game._settings()
	await process_frame
	game._close_aux()
	_check(game._decision_battle().mode=="TARGET" and game._decision_battle().selected_skill==game.C.DAMAGE,"cancel preserves target mode")
	game._settings()
	await process_frame
	for i in range(6):
		game.palette_pickers[i].color=palette.PRESETS.ICE[i]
	game._apply_colors()
	await process_frame
	_check(game._decision_battle().mode=="TARGET" and game._decision_battle().selected_skill==game.C.DAMAGE,"apply preserves target mode")
	game._close_aux()
	game.battle.mode="RESULT"
	game.battle.result="VICTORY"
	game._result()
	var drops=game.drops.duplicate(true)
	var rng=game.loot_rng.state
	game._settings()
	await process_frame
	game._apply_colors()
	await process_frame
	_check(game.battle.result=="VICTORY" and game.drops==drops and game.loot_rng.state==rng,"result repaint does not reroll loot")
	game._close_aux()
	await process_frame

## NREQ-002-S02
func _test_icons(game) -> void:
	for name in ["help","settings","restart","quit","play","save","load","wait","attack","heal","close","back","check"]:
		_check(game.ICONS.has(name) and game.ICONS[name] is Texture2D,"bundled Lucide texture "+name)
	var license=FileAccess.get_file_as_string("res://assets/lucide/LICENSE")
	_check(license.contains("ISC License") and license.contains("The MIT License (MIT)") and license.contains("Cole Bemis") and license.contains("Lucide Icons and Contributors"),"ISC and Feather MIT notices bundled")
	_check(FileAccess.file_exists("res://assets/lucide/NOTICE.md"),"provenance bundled")
	game._build()
	var buttons=game.overlay.find_children("*","Button",true,false)
	var found=false
	for button in buttons:
		if button.text=="START":
			found=button.icon!=null and not button.tooltip_text.is_empty()
	_check(found,"start icon has meaningful label and tooltip")

func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
func _finish() -> void:
	print("DESIGN FLOW: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)

## REQ-020-S01
func _test_help_terms(game) -> void:
	game._help()
	await process_frame
	var guides=[]
	for label in game.auxiliary.find_children("*","Label",true,false):
		if label.text.contains("INF powers damage and healing; RES resists damage."):
			guides.append(label.text)
	_check(guides==["Minus = damage; plus = healing.\nINF powers damage and healing; RES resists damage."],"short HELP separates effect signs from INF and RES mechanics")
	game._close_aux()
	game._settings()
	await process_frame
	var captions=[]
	for label in game.auxiliary.find_children("*","Label",true,false):
		if label.text.begins_with("INF") or label.text.begins_with("RES"):
			captions.append(label.text)
	_check(captions==["INF","RES"],"color labels do not imply that healing depends on RES")
	game._close_aux()
	await process_frame

## NREQ-002-S01
func _test_action_context(game,palette) -> void:
	game._start_battle()
	game._cell_input(Vector2i(4,4))
	game._cell_input(Vector2i(4,4),true)
	game._movement_tick(game.T.MOVEMENT_MAX_SECONDS)
	await process_frame
	var dim: Color=game.overlay.get_child(0).color
	var colors=palette.PRESETS.DEFAULT.duplicate()
	colors.append_array([palette.TEXT,palette.MUTED,Color("858585")])
	var minimum=100.0
	for color in colors:
		minimum=minf(minimum,_contrast(_under_dim(color,dim),_under_dim(palette.INTERACTIVE,dim)))
	_check(minimum>=palette.MIN_CONTRAST,"ACTION preserves readable HP, skill, and sync text behind its scrim")
	_check(_contrast(palette.TEXT,game.overlay.get_child(1).get_theme_stylebox("panel").bg_color)>=palette.MIN_CONTRAST,"ACTION panel text remains readable")
	game._settings()
	await process_frame
	_check(game.auxiliary.get_child(0).color.a>dim.a,"SETTINGS keeps its own scrim")
	game._close_aux()
	game.battle.mode="RESULT"
	game.battle.result="VICTORY"
	game._result()
	await process_frame
	_check(game.overlay.get_child(0).color.a>dim.a,"RESULT keeps its own scrim")
	game._build()
	await process_frame
	_check(game.overlay.get_child(0).color.a>dim.a,"BUILD keeps its own scrim")
	game._help()
	await process_frame
	_check(game.auxiliary.get_child(0).color.a>dim.a,"HELP keeps its own scrim")
	game._close_aux()
	await process_frame

func _under_dim(color: Color,dim: Color) -> Color:
	return color*(1.0-dim.a)+Color(dim.r,dim.g,dim.b,1.0)*dim.a

func _contrast(a: Color,b: Color) -> float:
	var luminances=[]
	for color in [a,b]:
		var luminance=0.0
		for channel in range(3):
			var value: float=color[channel]
			luminance+=[0.2126,0.7152,0.0722][channel]*(value/12.92 if value<=0.04045 else pow((value+0.055)/1.055,2.4))
		luminances.append(luminance)
	return (maxf(luminances[0],luminances[1])+0.05)/(minf(luminances[0],luminances[1])+0.05)

## NREQ-002-S03
func _test_focus_scope(game) -> void:
	game._build()
	await process_frame
	await _tab_cycle(game,game.overlay,"BUILD")
	var original=root.gui_get_focus_owner()
	game._help()
	await process_frame
	await _tab_cycle(game,game.auxiliary,"HELP")
	game._close_aux()
	await process_frame
	_check(root.gui_get_focus_owner()==original,"close restores prior focus")
	game._settings()
	await process_frame
	await _tab_cycle(game,game.auxiliary,"SETTINGS")
	game._close_aux()
	game._start_battle()
	game._cell_input(Vector2i(4,4))
	game._cell_input(Vector2i(4,4),true)
	game._movement_tick(game.T.MOVEMENT_MAX_SECONDS)
	await process_frame
	await _tab_cycle(game,game.overlay,"ACTION")
	game.battle.mode="RESULT"
	game.battle.result="VICTORY"
	game._result()
	await process_frame
	await _tab_cycle(game,game.overlay,"RESULT")

func _tab_cycle(_game,layer: Control,title: String) -> void:
	root.focus_exited.emit()
	root.focus_entered.emit()
	await process_frame
	var resumed=root.gui_get_focus_owner()
	_check(is_instance_valid(resumed) and layer.is_ancestor_of(resumed),title+" restores modal focus after reactivation")
	for backwards in [false,true]:
		for i in range(8):
			for down in [true,false]:
				var event=InputEventKey.new()
				event.keycode=KEY_TAB
				event.physical_keycode=KEY_TAB
				event.shift_pressed=backwards
				event.pressed=down
				root.push_input(event,false)
			await process_frame
			var focus=root.gui_get_focus_owner()
			_check(is_instance_valid(focus) and layer.is_ancestor_of(focus) and not (focus is BaseButton and focus.disabled),title+" keeps focus on enabled modal controls")

## REQ-020-S01、REQ-033-S06
func _test_settings_state() -> void:
	var folder="res://artifacts/runtime/settings-state-"+str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	for value in [null,false,true]:
		var path=folder+"/"+str(value)+".json"
		var old={"language":"ja"}
		if value!=null:old["reduced_motion"]=value;old["motion"]=value
		var f=FileAccess.open(path+".language.json",FileAccess.WRITE);f.store_string(JSON.stringify(old));f.close()
		var bytes=FileAccess.get_file_as_bytes(path+".language.json")
		var ui=load("res://tests/fixture_main.gd").new();ui.settings_path=path;root.add_child(ui);await process_frame
		var start=ui.clock;ui._process(0.1)
		_check(ui.clock>start and ui.get_property_list().all(func(row):return row.name!="reduced_motion"),"legacy motion flag never controls normal animation: "+str(value))
		ui._settings();await process_frame
		var buttons=ui.auxiliary.find_children("*","Button",true,false).filter(func(b):return b.text in ["WINDOWED","FULLSCREEN"])
		ui.get_viewport().gui_release_focus()
		var active=buttons.filter(func(b):return b.get_theme_stylebox("normal").get_border_width(SIDE_BOTTOM)>0)
		_check(active.size()==1 and active[0].text==("FULLSCREEN" if DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN,DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN] else "WINDOWED"),"DISPLAY retains only its actual selection without focus")
		_check(not ui.auxiliary.find_children("*","BaseButton",true,false).any(func(b):return b.text=="REDUCED MOTION"),"removed motion setting has no English or Japanese control")
		_check(FileAccess.get_file_as_bytes(path+".language.json")==bytes and not FileAccess.file_exists(path),"legacy and unrelated settings remain unchanged")
		ui.queue_free();await process_frame
