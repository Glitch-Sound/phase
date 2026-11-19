extends "res://ui/main.gd"
var draw_times=[]
var displayed_rings=[]
var displayed_text=[]
var drawn_route_segments=[]
var auditing_draw=false
func _draw() -> void:
	var begin=Time.get_ticks_usec()
	displayed_rings=[]
	displayed_text=[]
	drawn_route_segments=[]
	auditing_draw=true
	super._draw()
	auditing_draw=false
	draw_times.append((Time.get_ticks_usec()-begin)/1000.0)
func _ring(canvas: CanvasItem,center: Vector2,radius: float,u: Dictionary,active: bool=false) -> void:
	displayed_rings.append({"center":center,"unit":u.duplicate(true)})
	super._ring(canvas,center,radius,u,active)
func _text(text: String,position_px: Vector2,font_size: int,color: Color=WHITE,typeface: Font=null) -> void:
	displayed_text.append(text)
	super._text(text,position_px,font_size,color,typeface)
func _route_segments() -> Array:
	var segments=super._route_segments()
	if auditing_draw:drawn_route_segments.append_array(segments.duplicate(true))
	return segments
