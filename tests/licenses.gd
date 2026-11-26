extends SceneTree
var checks=0
var failures=0
const PATHS=["res://assets/godot/LICENSE.txt","res://assets/godot/COPYRIGHT.txt","res://assets/godot/NOTICE.md","res://assets/lucide/LICENSE","res://assets/lucide/NOTICE.md","res://assets/fonts/OFL.txt","res://assets/fonts/NOTICE.md","res://assets/licenses/NOTICE.md","res://assets/licenses/MIT.txt"]
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	var path="res://ui/license_dialog.gd"
	_check(ResourceLoader.exists(path),"license viewer component exists")
	if ResourceLoader.exists(path):await _viewer(load(path))
	await _entry()
	print("LICENSES: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
## REQ-063-S01
func _viewer(script: Script) -> void:
	var dialog=script.new();root.add_child(dialog)
	dialog.configure("en");await process_frame
	_check(dialog.documents.map(func(row):return row.path)==PATHS,"exactly nine declared documents are available")
	for i in range(PATHS.size()):
		dialog.select_document(i)
		_check(FileAccess.file_exists(PATHS[i]) and dialog.body.text==FileAccess.get_file_as_string(PATHS[i]) and not dialog.body.text.is_empty(),"document is complete and exact: "+PATHS[i])
	var original=dialog.body.text;var english=dialog.guidance.text
	dialog.configure("ja");dialog.select_document(PATHS.size()-1)
	_check(dialog.body.text==original and dialog.guidance.text!=english and dialog.guidance.text.contains("原文"),"only guidance changes language")
	_check(not dialog.body.editable and dialog.body.wrap_mode==TextEdit.LINE_WRAPPING_BOUNDARY,"read-only wrapping content remains scrollable")
	dialog.queue_free();await process_frame
## REQ-063-S02
func _entry() -> void:
	var game=load("res://main.tscn").instantiate();game.profile_startup=false
	game.settings_path="res://artifacts/runtime/license-tests-"+str(Time.get_ticks_usec())+"/unused.json";game.save_path=game.settings_path+".save"
	root.add_child(game);await process_frame;game.set_process(false);game._settings();await process_frame
	var buttons=game.auxiliary.find_children("*","Button",true,false).filter(func(b):return b.text=="LICENSES")
	_check(buttons.size()==1,"SETTINGS has one LICENSES button")
	if buttons.size()==1:
		var layer=game.auxiliary;var picker=game.palette_pickers[0];picker.color=Color("aabbcc");var builds=game.collection.builds.duplicate(true)
		buttons[0].pressed.emit();await process_frame
		_check(is_instance_valid(game.license_dialog),"SETTINGS opens the shared viewer")
		if is_instance_valid(game.license_dialog):game.license_dialog.closed.emit();await process_frame
		_check(game.auxiliary==layer and picker.is_visible_in_tree() and picker.color==Color("aabbcc") and game.collection.builds==builds and not FileAccess.file_exists(game.settings_path),"return keeps unsaved settings and builds without writes")
	game._close_aux();game.queue_free();await process_frame
func _check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",note)
