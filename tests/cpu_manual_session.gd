extends SceneTree
func _initialize() -> void:
	var game=load("res://tests/cpu_manual_audit.gd").new()
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child.call_deferred(game)
