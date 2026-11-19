extends "res://ui/main.gd"
var displayed_rings=[]
var displayed_text=[]
func _draw() -> void:
	displayed_rings=[]
	displayed_text=[]
	super._draw()
func _ring(canvas: CanvasItem,center: Vector2,radius: float,u: Dictionary,active: bool=false) -> void:
	displayed_rings.append({"center":center,"unit":u.duplicate(true)})
	super._ring(canvas,center,radius,u,active)
func _text(text: String,position_px: Vector2,font_size: int,color: Color=WHITE,typeface: Font=null) -> void:
	displayed_text.append(text)
	super._text(text,position_px,font_size,color,typeface)
