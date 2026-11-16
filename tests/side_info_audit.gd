extends "res://tests/order_axis_audit.gd"
var info_text=[]
var info_rings=[]
var info_bars=[]
var in_info=false
func _draw_info() -> void:
	info_text=[]
	info_rings=[]
	info_bars=[]
	in_info=true
	super._draw_info()
	in_info=false
func _text(text: String,position_px: Vector2,font_size: int,color: Color=WHITE,typeface: Font=null) -> void:
	if in_info:
		info_text.append(text)
	super._text(text,position_px,font_size,color,typeface)
func _ring(canvas: CanvasItem,center: Vector2,radius: float,u: Dictionary,active: bool=false) -> void:
	if in_info:
		info_rings.append({"center":center,"unit":u.duplicate(true)})
	super._ring(canvas,center,radius,u,active)
func _bar(rect: Rect2,ratio: float,color: Color) -> void:
	if in_info:
		info_bars.append(rect)
	super._bar(rect,ratio,color)
