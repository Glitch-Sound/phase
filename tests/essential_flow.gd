extends SceneTree
const MAX_TEXT_RATIO=0.5
const MAX_LUMINANCE_RATIO=0.5
var failures=0
var checks=0
func _initialize() -> void:
	_run.call_deferred()
## REQ-019-S01、REQ-019-S02、NREQ-002-S04、NREQ-002-S05
func _run() -> void:
	var game=load("res://tests/frame_audit.gd").new()
	game.settings_path="res://artifacts/runtime/essential-no-settings.json"
	root.add_child(game)
	await process_frame
	game._start_battle()
	game._cell_input(Vector2i(4,4))
	game._cell_input(Vector2i(5,4))
	game._cell_input(Vector2i(5,4),true)
	game.battle.choose_skill(game.C.DAMAGE)
	game._clear_overlay()
	game._cell_input(Vector2i(6,4))
	game._cell_input(Vector2i(4,6))
	game._cell_input(Vector2i(5,6))
	game.message_time=0
	game.toasts=[]
	await create_timer(0.1).timeout
	var chars=0
	for text in game.drawn_text:
		chars+=text.length()
	for control in game.hud.find_children("*","Control",true,false):
		if control.is_visible_in_tree() and (control is Label or control is Button):
			chars+=control.text.length()
	var audit={"chars":chars,"rings":game.drawn_rings,"texts":game.drawn_text}
	var baseline_path="res://artifacts/runtime/essential-baseline.json"
	if "--baseline" in OS.get_cmdline_user_args():
		if not FileAccess.file_exists(baseline_path):
			var file=FileAccess.open(baseline_path,FileAccess.WRITE)
			file.store_string(JSON.stringify(audit,"\t"))
		print("BASELINE AUDIT: ",audit)
		quit()
		return
	var baseline=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/essential-baseline.json"))
	_check(chars<=baseline.chars*MAX_TEXT_RATIO,"default text at most half of previous frame")
	_check(game.drawn_rings==1,"one predicted ring group")
	_check(game.get("info_open")==false and game.get("phase_open")==false,"details closed initially")
	var units=game.battle.units.duplicate(true)
	var path=game.battle.path.duplicate()
	if game.has_method("_toggle_info"):
		game._toggle_info()
		game._toggle_phase()
		game._order()
		await process_frame
		_check(game.info_open and game.phase_open and is_instance_valid(game.auxiliary),"strategic disclosures reachable")
		game._close_aux()
		game._objective()
		game._close_aux()
		_check(game.battle.units==units and game.battle.path==path and game.battle.actor==1,"disclosures preserve actor and route")
		game._cell_input(Vector2i(6,4))
		_check(game.selected==2 and game.battle.preview().id=="02","inspection does not redirect prediction")
	else:
		_check(false,"disclosure controls available")
	for page in ["CORE","EQUIP","SKILLS"]:
		game.set("build_page",page)
		game._build()
		await process_frame
		var options=game.overlay.find_children("*","OptionButton",true,false)
		_check(options.size()=={"CORE":2,"EQUIP":3,"SKILLS":4}[page],"only purpose-specific editors: "+page)
		_check(game.core_controls.size()==(5 if page=="CORE" else 0),"core values only on CORE")
		if page=="CORE":
			for i in range(4):
				_check(game.core_controls[i].get_global_rect().end.x<=game.core_controls[i+1].global_position.x,"core editor arrows do not overlap the next value")
		_check(game.equipment_views.size()==(2 if page=="EQUIP" else 0),"equipment comparisons only on EQUIP")
	var retired=game.overlay
	game._build()
	_check(not retired.is_inside_tree(),"retired modal detaches before replacement receives input")
	game._help()
	retired=game.auxiliary
	game._settings()
	_check(not retired.is_inside_tree(),"retired auxiliary detaches before replacement")
	game._close_aux()
	await _test_disclosure_input(game)
	print("ESSENTIAL AUDIT: ",JSON.stringify(audit))
	print("ESSENTIAL FLOW: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)

## REQ-019-S02、NREQ-002-S05
func _test_disclosure_input(game) -> void:
	game._start_battle()
	game._cell_input(Vector2i(4,4))
	game._cell_input(Vector2i(5,4))
	game._cell_input(Vector2i(5,4),true)
	await process_frame
	for key in [KEY_I,KEY_P]:
		var event=InputEventKey.new()
		event.keycode=key
		event.pressed=true
		game._unhandled_input(event)
	await process_frame
	_check(game.info_open and game.phase_open and game.battle.mode=="CHOICE","keyboard disclosures preserve CHOICE")
	var selectors=[]
	for button in game.overlay.find_children("*","Button",true,false):
		if button.text in ["01","02","A","B"]:
			selectors.append(button.text)
			if button.text=="B":
				button.pressed.emit()
	_check(selectors==["01","02","A","B"],"every unit can be inspected inside ACTION")
	_check(game.selected==3 and game.battle.preview().id=="01" and game.battle.mode=="CHOICE","inspection during ACTION preserves acting prediction")
	_check(game.overlay.get_child(1).position.y>=700,"expanded info stays above action panel")
	game.battle.choose_skill(game.C.DAMAGE)
	game._clear_overlay()
	game._hud()
	var units=game.battle.units.duplicate(true)
	game._menu()
	await process_frame
	var labels=[]
	for button in game.auxiliary.find_children("*","Button",true,false):
		labels.append(button.text)
	_check(labels==["HELP","SETTINGS","RESTART","QUIT","CLOSE / ESC"],"all battle system actions reachable in MENU")
	game._close_aux()
	for page in ["PLAY","PHASE","BUILD"]:
		game._help(page)
		await process_frame
		var content=[]
		for label in game.auxiliary.find_children("*","Label",true,false):
			content.append(label.text)
		_check(content.size()<=5 and content.size()>=3,"one help purpose at a time: "+page)
	game._settings("DISPLAY")
	await process_frame
	_check(game.palette_pickers.is_empty(),"display page excludes color editors")
	game._settings("COLOR")
	await process_frame
	_check(game.palette_pickers.size()==6,"all six color editors reachable")
	game._close_aux()
	_check(game.battle.mode=="TARGET" and game.battle.selected_skill==game.C.DAMAGE and game.battle.units==units,"pages preserve target and model")
	game._cell_input(Vector2i(6,4))
	_check(game.battle.actor==1 and game.battle.units[2].hp==89,"target can execute after disclosures")
	game._cell_input(Vector2i(4,6))
	game._cell_input(Vector2i(5,6))
	game._cell_input(Vector2i(5,6),true)
	game.battle.choose_skill(game.C.DAMAGE)
	game._clear_overlay()
	game._cell_input(Vector2i(6,6))
	_check(game.battle.actor==2 and game.battle.units[3].hp<100,"enemy faction receives following turn")
	game._cell_input(Vector2i(5,4))
	_check(game.selected==0 and game.battle.actor==2,"enemy turn inspects player independently")
