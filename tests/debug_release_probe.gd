## 検証専用のリリース書き出しでだけ起動する。
extends Node
var failures=0
var checks=0
## REQ-041-S01
func _ready() -> void:
	_check(not OS.is_debug_build(),"actual executable is a release build")
	var session=load("res://game/debug_session.gd").new()
	var normal=load("res://game/collection.gd").new()
	var before=normal.snapshot()
	session.allowed=true
	_check(not session.available() and session.begin(normal)==null and normal.snapshot()==before,"release refuses backend entry even when allowed is true")
	var game=load("res://ui/main.gd").new()
	game.save_path="res://no-save.json"
	game.settings_path="res://no-settings.json"
	add_child(game)
	await get_tree().process_frame
	_check(game.overlay.find_children("*","Button",true,false).all(func(button):return button.text!="UNLOCK ALL" and button.text!="EXIT DEBUG"),"release BUILD has no debug entrance")
	var original=game.collection
	_check(not game._toggle_debug(true) and game.collection==original and not game.debug_notice.visible,"release UI direct call cannot activate temporary mode")
	game.queue_free()
	await get_tree().process_frame
	print("ACTUAL RELEASE UNLOCK: %d checks / %d failures" % [checks,failures])
	get_tree().quit(0 if failures==0 else 1)
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
