extends "res://tests/skill_pattern_audit.gd"
var field_clouds=[]
func _draw_board() -> void:
	field_clouds=[]
	super._draw_board()
func _field_cloud(rect: Rect2,preview: bool) -> void:
	field_clouds.append({"rect":rect,"preview":preview})
	super._field_cloud(rect,preview)
