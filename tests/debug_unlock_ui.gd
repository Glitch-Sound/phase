extends SceneTree
var checks=0
var failures=0
func _initialize() -> void:_run.call_deferred()
## REQ-041-S01、REQ-041-S03、REQ-041-S04、REQ-041-S05
func _run() -> void:
	var game=load("res://ui/main.gd").new()
	game.save_path="res://artifacts/runtime/unlock-ui-no-save.json"
	game.settings_path="res://artifacts/runtime/unlock-ui-no-settings.json"
	root.add_child(game)
	await process_frame
	_check(game.has_method("_toggle_debug"),"BUILD has the isolated debug entry")
	if game.has_method("_toggle_debug"):
		var original=game.collection
		var before=original.snapshot()
		var palette=game.palette_colors.duplicate()
		var rng_state=game.loot_rng.state
		game.debug_session.allowed=false
		game._build()
		await process_frame
		_check(_buttons(game.overlay,"UNLOCK ALL").is_empty() and not game._toggle_debug(true) and game.collection==original,"unavailable runtime has no entry and refuses direct execution")
		game.debug_session.allowed=true
		game._build()
		await process_frame
		if OS.is_debug_build():
			_check(_buttons(game.overlay,"UNLOCK ALL").size()==1 and game._toggle_debug(true),"debug BUILD enters explicitly")
			await process_frame
			_check(game.collection.temporary and game.debug_notice.visible and game.debug_notice.text=="DEBUG / NOT SAVED","debug badge identifies the temporary data")
			_check(_buttons(game.overlay,"SAVE")[0].disabled and _buttons(game.overlay,"LOAD")[0].disabled,"normal save and load controls are disabled")
			game._save();game._load()
			_check(not FileAccess.file_exists(game.save_path) and game.collection.temporary and original.snapshot()==before,"direct save/load cannot escape the sandbox")
			game._settings()
			for i in range(6):game.palette_pickers[i].color=game.P.PRESETS.AMBER[i]
			game._apply_colors()
			_check(not FileAccess.file_exists(game.settings_path) and game.palette_colors==game.P.PRESETS.AMBER,"debug colors apply only in memory")
			game._close_aux()
			game._start_battle()
			game.battle.result="VICTORY";game.battle.mode="RESULT"
			game._result()
			_check(game.drops==[] and game.loot_rng.state==rng_state and original.snapshot()==before,"debug battle result cannot award normal loot")
			game._restart()
			_check(game.build_open and game.collection.temporary,"restart preserves debug mode")
			_check(game._toggle_debug(false) and game.collection==original and original.snapshot()==before and game.palette_colors==palette and game.notice.get_theme_color("font_color")==game.CYAN,"exit restores the exact normal data and display settings")
			await process_frame
			_check(not game.debug_notice.visible and not _buttons(game.overlay,"SAVE")[0].disabled and not _buttons(game.overlay,"LOAD")[0].disabled,"normal BUILD and save/load controls are restored")
	game.queue_free()
	await process_frame
	print("DEBUG UNLOCK UI: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
func _buttons(parent: Node,text: String) -> Array:
	return parent.find_children("*","Button",true,false).filter(func(button):return button.text==text)
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
