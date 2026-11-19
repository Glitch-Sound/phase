extends SceneTree
var checks=0
var failures=0
var game
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	game=load("res://ui/main.gd").new()
	game.save_path="res://artifacts/runtime/build-dialog-test-save.json"
	game.settings_path="res://artifacts/runtime/build-dialog-test-settings.json"
	root.add_child(game)
	await process_frame
	_check(game.has_method("_open_build_choice"),"shared BUILD selection entry exists")
	if game.has_method("_open_build_choice"):
		await _dialogs()
		await _keyboard()
		await _presentation()
	game.queue_free()
	await process_frame
	print("BUILD DIALOGS: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
## REQ-042-S01、REQ-014-S02、REQ-024-S01
func _dialogs() -> void:
	var before=game.collection.snapshot()
	var choice=game.C.serial("ARMS",[20,30,10,20,20])
	var origin=game.overlay.find_children("*","Button",true,false).filter(func(b):return b.get_meta("build_choice","")=="arms")[0]
	origin.grab_focus()
	game._open_build_choice("arms")
	await process_frame
	var dialog=game.build_dialog
	dialog.scroll.scroll_vertical=500
	dialog._filter(1)
	await process_frame
	await process_frame
	_check(dialog.scroll.scroll_vertical==0,"filter restarts at the highest matching stat")
	_check(dialog.filter_buttons[2].get_theme_stylebox("normal").border_width_bottom>0 and dialog.filter_buttons[0].get_theme_stylebox("normal").border_width_bottom==0,"filter underline follows selected stat")
	_check(dialog.select_candidate(choice) and game.collection.snapshot()==before and dialog.candidate_build.arms==[20,30,10,20,20],"selection previews actual build without committing")
	dialog.cancel()
	await process_frame
	_check(game.collection.snapshot()==before and not is_instance_valid(game.auxiliary) and game.get_viewport().gui_get_focus_owner()==origin,"cancel discards preview and returns focus")
	game._open_build_choice("arms")
	await process_frame
	game.build_dialog.select_candidate(choice)
	game.build_dialog.confirm()
	await process_frame
	_check(game.collection.builds[0].arms==[20,30,10,20,20] and not is_instance_valid(game.auxiliary),"APPLY commits and closes")
	var focused=game.get_viewport().gui_get_focus_owner()
	_check(is_instance_valid(focused) and focused.get_meta("build_choice","")=="arms","APPLY returns focus to the rebuilt originating control")
	_check(game._equipment_values([25,15,20,30,10],[20,20,20,20,20])==["25","15","20","30","10"],"readout contains values without bracket deltas")
	for kind in ["class_name","gear","arms_mutation","gear_mutation","skill","operation"]:
		game._open_build_choice(kind,2 if kind=="skill" else 0)
		await process_frame
		_check(is_instance_valid(game.build_dialog) and game.build_dialog.kind==kind and game.build_dialog.rows.size()>0,"common dialog is connected: "+kind)
		game.build_dialog.cancel()
		await process_frame
## REQ-042-S05
func _keyboard() -> void:
	game._open_build_choice("arms")
	await process_frame
	var dialog=game.build_dialog
	var before=game.collection.snapshot()
	var key=InputEventKey.new();key.keycode=KEY_END;key.pressed=true
	dialog.navigate(key)
	_check(dialog.selected_id==dialog.rows.filter(func(r):return r.selectable)[-1].id and game.collection.snapshot()==before,"End reaches final available candidate without committing")
	var esc=InputEventKey.new();esc.keycode=KEY_ESCAPE;esc.pressed=true
	game._unhandled_input(esc)
	await process_frame
	_check(not is_instance_valid(game.auxiliary) and game.collection.snapshot()==before,"Esc closes dialog without mutation")
## REQ-041-S01、REQ-044-S01、REQ-019-S14
func _presentation() -> void:
	var toggles=game.overlay.find_children("*","CheckButton",true,false)
	_check(toggles.map(func(c):return c.text).has("UNLOCK ALL") and toggles.map(func(c):return c.text).has("ENEMY CPU"),"unlock and CPU share toggle control")
	var start=game.overlay.find_children("*","Button",true,false).filter(func(b):return b.text=="START")[0]
	_check(start.alignment==HORIZONTAL_ALIGNMENT_CENTER,"START label is centered")
	_check(start.icon==null or start.icon_alignment!=HORIZONTAL_ALIGNMENT_CENTER,"START icon does not overlap the centered label")
	var content_width=start.get_theme_font("font").get_string_size(start.text,HORIZONTAL_ALIGNMENT_LEFT,-1,start.get_theme_font_size("font_size")).x+start.get_theme_constant("icon_max_width")+start.get_theme_constant("h_separation")
	for state in ["normal","hover","pressed","focus","disabled"]:
		var style=start.get_theme_stylebox(state)
		_check(is_equal_approx(style.content_margin_left,style.content_margin_right) and absf(2*style.content_margin_left+content_width-start.size.x)<1.0,"START icon and text share a centered content area: "+state)
	var cpu=toggles.filter(func(c):return c.text=="ENEMY CPU")[0]
	var unlock=toggles.filter(func(c):return c.text=="UNLOCK ALL")[0]
	var unit_end=game.overlay.find_children("*","Button",true,false).filter(func(b):return b.text=="UNIT 3")[0].get_global_rect().end.x
	var group_gap=cpu.global_position.x-unlock.get_global_rect().end.x
	_check(group_gap>0 and unlock.global_position.x-unit_end>group_gap and is_equal_approx(cpu.get_global_rect().end.x,start.get_global_rect().end.x),"right-aligned toggles form a closer group than the unit selection gap")
	var cpu_rect=cpu.get_global_rect()
	game.debug_session.allowed=false
	game._build()
	await process_frame
	var release_toggles=game.overlay.find_children("*","CheckButton",true,false)
	_check(release_toggles.size()==1 and release_toggles[0].text=="ENEMY CPU" and release_toggles[0].get_global_rect()==cpu_rect,"without debug entry CPU stays right-aligned and no empty control remains")
	game.debug_session.allowed=true
	game._build()
	await process_frame
	var text=FileAccess.get_file_as_string("res://ui/main.gd")
	_check(text.contains('_text("PREVIEW",'),"PREVIEW heading is drawn")
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
