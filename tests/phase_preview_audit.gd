extends "res://tests/map_chrome_audit.gd"
var preview_text=[]
var preview_rings=[]
var in_preview=false
var draw_times=[]
func _draw() -> void:
	var begin=Time.get_ticks_usec()
	super._draw()
	draw_times.append((Time.get_ticks_usec()-begin)/1000.0)
func _draw_preview() -> void:
	preview_text=[]
	preview_rings=[]
	in_preview=true
	super._draw_preview()
	in_preview=false
func _text(text: String,position_px: Vector2,font_size: int,color: Color=WHITE,typeface: Font=null) -> void:
	if in_preview:
		preview_text.append({"text":text,"position":position_px})
	super._text(text,position_px,font_size,color,typeface)
	drawn_text[-1].font_size=font_size
	drawn_text[-1].typeface=font if typeface==null else typeface
func _ring(canvas: CanvasItem,center: Vector2,radius: float,u: Dictionary,active: bool=false) -> void:
	if in_preview:
		preview_rings.append({"center":center,"radius":radius,"unit":u.duplicate(true)})
	super._ring(canvas,center,radius,u,active)
