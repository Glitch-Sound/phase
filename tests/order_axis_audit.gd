extends "res://tests/map_orbit_audit.gd"
var in_axis=false
var axis_centers=[]
func _draw_timeline() -> void:
	axis_centers=[]
	in_axis=true
	super._draw_timeline()
	in_axis=false
func _center(text: String,position_px: Vector2,font_size: int,color: Color=WHITE,typeface: Font=null) -> void:
	if in_axis:
		axis_centers.append({"text":text,"position":position_px})
	super._center(text,position_px,font_size,color,typeface)
