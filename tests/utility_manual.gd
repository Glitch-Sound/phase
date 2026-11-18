## 新4品をメモリー内だけで取得した、通常操作の検証専用シーン。
extends "res://tests/cpu_manual_audit.gd"
func _ready() -> void:
	super._ready()
	collection.skills=C.SKILLS.keys()
	collection.builds[0].skills=[C.SWAP,C.GUARD,C.IGNORE_PANEL]
	collection.builds[1].skills=[C.PUSH,C.DAMAGE_DIAGONAL_TWO,C.HEAL]
	cpu_enabled=true
	_build()
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode==KEY_F12:
		_capture.call_deferred()
		return
	super._unhandled_input(event)
func _capture() -> void:
	await RenderingServer.frame_post_draw
	var path="res://artifacts/runtime/PHASE-utility-%d-%d.png" % [Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	get_viewport().get_texture().get_image().save_png(path)
	print("UTILITY CAPTURE ",ProjectSettings.globalize_path(path))
