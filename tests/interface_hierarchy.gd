extends SceneTree
var checks=0
var failures=0
var game
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	game=load("res://tests/fixture_main.gd").new()
	var stamp=str(Time.get_ticks_usec())
	game.settings_path="res://artifacts/runtime/hierarchy-settings-"+stamp+".json"
	root.add_child(game)
	await process_frame
	await _build_inventory()
	await _stages()
	await _editing_and_save(stamp)
	await _surfaces()
	game.queue_free()
	await process_frame
	print("INTERFACE HIERARCHY: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
## REQ-014-S02、REQ-041-S01
func _build_inventory() -> void:
	game._build()
	await process_frame
	var panel=game.overlay.get_child(1)
	var options=panel.find_children("*","Button",true,false).filter(func(c):return c.has_meta("build_choice"))
	var spins=panel.find_children("*","SpinBox",true,false)
	var labels=panel.find_children("*","Label",true,false).map(func(c):return c.text)
	var buttons=panel.find_children("*","Button",true,false).filter(func(c):return not c.has_meta("build_choice")).map(func(c):return c.text)
	_check(options.size()==9 and spins.size()==5,"class, two equipment, two mutation, three skills and stage remain editable")
	buttons.sort()
	var expected_buttons=["ENEMY CPU","HELP","LOAD","QUIT","SAVE","SETTINGS","START","SLOT 1","SLOT 2","SLOT 3"]
	if OS.is_debug_build():expected_buttons.append("UNLOCK ALL")
	expected_buttons.sort()
	_check(buttons==expected_buttons,"complete exact BUILD operation set includes CPU and the debug-only choice")
	_check(["CLASS","CORE / TOTAL 100","ARMS","GEAR","MUTATION","SKILLS / 3 SLOTS","OPERATION"].all(func(s):return labels.has(s)),"necessary build labels remain visible")
	_check(labels.any(func(s):return s.contains("MIN 1") and s.contains("AUTOMATIC REDISTRIBUTION")) and labels.any(func(s):return s.contains("SHARED ARCHIVE") and s.contains("BOTH SIDES: HUMAN")),"allocation and shared archive rules remain available")
	_check(game.equipment_views.size()==2 and is_instance_valid(game.build_preview),"five equipment values, differences and resulting build preview remain connected")
	_check(game.has_method("_equipment_values"),"build equipment readout exposes all five exact values and comparison")
	if game.has_method("_equipment_values"):
		_check(game._equipment_values([25,15,20,30,10],[20,20,20,20,20])==["25","15","20","30","10"],"all five build values without bracket deltas are exact")
		_check(game._equipment_values([96.0,1.0,1.0,1.0,1.0],[1.0,96.0,1.0,1.0,1.0])==["96","1","1","1","1"],"JSON-loaded integral equipment values keep the same compact exact readout")
	_check(game.core_controls[0].get_global_rect().end.x<game.equipment_views.arms.global_position.x and game.equipment_views.arms.get_global_rect().end.x<options[5].global_position.x,"build reads from CORE and result to equipment to skills and deployment")
	var interactive=panel.find_children("*","Control",true,false).filter(func(c):return c is BaseButton or c is SpinBox)
	# SpinBox内のLineEditは親の操作領域の一部である。
	for i in range(interactive.size()):
		_check(panel.get_global_rect().encloses(interactive[i].get_global_rect()),"BUILD interaction stays inside layout "+str(i))
		for j in range(i+1,interactive.size()):
			_check(not interactive[i].get_global_rect().intersects(interactive[j].get_global_rect()),"BUILD interaction regions do not overlap: "+str(interactive[i].get_global_rect())+" / "+str(interactive[j].get_global_rect()))
## REQ-014-S02
func _stages() -> void:
	for i in range(4):
		game.collection.stage_index=i
		game._build()
		await process_frame
		var options=game.overlay.get_child(1).find_children("*","Button",true,false).filter(func(c):return c.has_meta("build_choice"))
		var texts=game.overlay.find_children("*","Label",true,false).map(func(c):return c.text)
		var stage=game.C.stages()[i]
		_check(options[-1].text==stage.name and texts.has(game._unit_references(stage.brief)) and texts.has(game._unit_references(stage.hint)),"complete stage identity, victory condition and hint remain "+str(i))
		var hint=game.overlay.find_children("*","Label",true,false).filter(func(c):return c.text==game._unit_references(stage.hint))[0]
		_check(hint.get_global_rect().end.x<=options[-1].get_global_rect().end.x,"stage hint wraps within the deployment column "+str(i))
	game.collection.stage_index=0
	_check(game.mono.get_string_size("96",HORIZONTAL_ALIGNMENT_LEFT,-1,game.T.BUILD_EQUIPMENT_VALUE_FONT).x<game.T.BUILD_EQUIPMENT_STAT_STEP,"largest legal equipment delta fits its fixed column")
## REQ-014-S01、REQ-014-S02、REQ-016-S01、REQ-028-S01
func _editing_and_save(stamp: String) -> void:
	game.collection.mutations=["NORMAL","IVRSL","LSRIV"]
	game.collection.skills=game.C.SKILLS.keys()
	game._build()
	await process_frame

	var options=game.overlay.get_child(1).find_children("*","Button",true,false).filter(func(c):return c.has_meta("build_choice"))
	game._open_build_choice("class_name")
	game.build_dialog.select_candidate("VLSRI")
	game.build_dialog.confirm()
	await process_frame
	game.core_controls[0].value=80
	_check(game.collection.builds[0].class_name=="VLSRI" and game.collection.builds[0].core.reduce(func(a,b):return a+b,0)==100,"class and core callbacks preserve valid redistribution")
	game._open_build_choice("arms")
	game.build_dialog.select_candidate("ARMS-141E0A1414")
	game.build_dialog.confirm()
	await process_frame
	_check(game.collection.builds[0].arms==[20,30,10,20,20],"equipment dialog confirmation remains connected")
	_check(game._equipment_comparison([20,30,10,20,20],[20,20,20,20,20])=="CURRENT / VIT 20   INF 20   RES 20   SPD 20   LUK 20\nCANDIDATE / VIT 20   INF 30   RES 10   SPD 20   LUK 20","current and candidate values compare without bracket deltas")
	game._open_build_choice("arms_mutation")
	game.build_dialog.select_candidate("IVRSL")
	game.build_dialog.confirm()
	await process_frame
	_check(game.collection.builds[0].arms_mutation=="IVRSL","mutation selection remains connected")
	game._skill_change(2,game.C.MOVE)
	await process_frame
	_check(game.collection.builds[0].skills==[game.C.DAMAGE,game.C.HEAL,game.C.MOVE],"third unlocked skill remains configurable")
	_check(game.get("save_path") is String,"UI save destination can be isolated from real user data")
	if game.get("save_path") is String:
		var path="res://artifacts/runtime/hierarchy-save-"+stamp+".json"
		game.save_path=path
		var builds=game.collection.builds.duplicate(true)
		game._save()
		game.collection.builds[0].class_name="STANDARD"
		game._load()
		await process_frame
		_check(game.collection.builds==JSON.parse_string(JSON.stringify(builds)) and FileAccess.file_exists(path),"actual SAVE and LOAD callbacks round-trip edited build in isolated storage: "+str(builds)+" / "+str(game.collection.builds))
		game._save()
		_check(not game.collection.last_backup.is_empty() and FileAccess.file_exists(game.collection.last_backup),"second explicit save backs up isolated previous file")
	game._settings()
	await process_frame
	for i in range(6):
		game.palette_pickers[i].color=game.P.PRESETS.AMBER[i]
	game._apply_colors()
	await process_frame
	_check(game.P.load_from(game.settings_path)==game.P.PRESETS.AMBER,"color apply uses isolated settings file")
	game._close_aux()
	await process_frame
## NREQ-002-S06、NREQ-002-S03
func _surfaces() -> void:
	var popup_style=game.get_theme_stylebox("panel","PopupMenu")
	_check(popup_style.bg_color.a==1.0 and popup_style.bg_color==game.PANEL,"popup lists have an opaque black surface so background text cannot leak through")
	game.collection.builds=game.C.player_builds()
	game._build()
	await process_frame
	_check_surface(game.overlay,"BUILD")
	var panel=game.overlay.get_child(1)
	var selected=panel.find_children("*","Button",true,false).filter(func(b):return b.text=="SLOT 1")[0]
	var style=selected.get_theme_stylebox("normal")
	_check(style.border_width_bottom>0 and style.border_width_left==0 and style.border_width_right==0 and style.border_width_top==0,"selected unit uses an underline, never an enclosing frame")
	game._help()
	await process_frame
	_check_surface(game.auxiliary,"HELP")
	game._close_aux()
	game._settings()
	await process_frame
	_check_surface(game.auxiliary,"SETTINGS")
	game._close_aux()
	game._start_battle()
	game._cell_input(Vector2i(4,4))
	game._cell_input(Vector2i(4,4),true)
	game._movement_tick(game.T.MOVEMENT_MAX_SECONDS)
	await process_frame
	_check_surface(game.overlay,"ACTION")
	var active=game.overlay.find_children("*","Button",true,false).filter(func(b):return not b.disabled)
	for button in active:
		var normal=button.get_theme_stylebox("normal")
		var focus=button.get_theme_stylebox("focus")
		var hover=button.get_theme_stylebox("hover")
		_check(normal.border_width_left==0 and normal.border_width_top==0 and normal.border_width_right==0 and normal.border_width_bottom==0,"action button has no idle enclosing frame")
		_check(focus.border_color==game.WHITE and focus.border_width_bottom>0 and focus.border_width_left==0 and focus.border_width_top==0 and focus.border_width_right==0,"keyboard focus is a white underline")
		_check(hover.bg_color!=normal.bg_color,"hover remains visible")
	game.battle.mode="RESULT"
	game.battle.result="VICTORY"
	game._result()
	await process_frame
	_check_surface(game.overlay,"RESULT")
func _check_surface(layer: Control,title: String) -> void:
	var panel=layer.get_child(1)
	var style=panel.get_theme_stylebox("panel")
	_check(style.bg_color==game.BG and style.border_width_left==0 and style.border_width_right==0 and style.border_width_top==0 and style.border_width_bottom==0,title+" uses unframed black surface")
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
