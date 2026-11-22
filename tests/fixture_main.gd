## 既存の位相とUI検査の固定条件を本番から分離する。
extends "res://ui/main.gd"
func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal=Control.GROW_DIRECTION_BOTH
	grow_vertical=Control.GROW_DIRECTION_BOTH
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	battle=preload("res://tests/fixture_battle.gd").new()

var embedded_window=false
func _display_embedded() -> bool:
	return embedded_window or super._display_embedded()
