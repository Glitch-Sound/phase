## 取得済みの追加スキルを使う検証専用の通常操作。保存は行わない。
extends "res://tests/cpu_manual_audit.gd"
func _ready() -> void:
	super._ready()
	collection.skills=C.SKILLS.keys()
	collection.builds[0].skills=[C.DAMAGE_DIAGONAL,C.DAMAGE_ORTHOGONAL_TWO,C.HEAL_DIAGONAL_TWO]
	collection.builds[1].skills=[C.DAMAGE,C.DAMAGE_DIAGONAL_TWO,C.HEAL_ORTHOGONAL_TWO]
	cpu_enabled=true
	_build()
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode==KEY_F12:
			_capture.call_deferred()
			return
		if event.keycode in [KEY_F9,KEY_F10,KEY_F11]:
			get_window().size={KEY_F9:Vector2i(1152,648),KEY_F10:Vector2i(1920,1080),KEY_F11:Vector2i(2560,1440)}[event.keycode]
			return
	super._unhandled_input(event)
func _capture() -> void:
	await RenderingServer.frame_post_draw
	var path="res://artifacts/runtime/PHASE-target-skills-%d.png" % Time.get_unix_time_from_system()
	get_viewport().get_texture().get_image().save_png(path)
	print("SKILL CAPTURE ",ProjectSettings.globalize_path(path))
