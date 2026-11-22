## 既存UIの経路と作用を、明示した固定6枠で検証する。
extends "res://ui/main.gd"
func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal=Control.GROW_DIRECTION_BOTH;grow_vertical=Control.GROW_DIRECTION_BOTH;mouse_filter=Control.MOUSE_FILTER_IGNORE
	battle=preload("res://tests/fixture_squad_battle.gd").new()
