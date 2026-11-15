extends "res://ui/main.gd"
var drawn_text=[]
var drawn_rings=0
func _draw() -> void:
	drawn_text=[]
	drawn_rings=0
	super._draw()
func _text(text: String,position_px: Vector2,font_size: int,color: Color=WHITE,typeface: Font=null) -> void:
	drawn_text.append(text)
	super._text(text,position_px,font_size,color,typeface)
func _center(text: String,position_px: Vector2,font_size: int,color: Color=WHITE,typeface: Font=null) -> void:
	drawn_text.append(text)
	super._center(text,position_px,font_size,color,typeface)
func _ring(canvas: CanvasItem,center: Vector2,radius: float,u: Dictionary,active: bool=false) -> void:
	drawn_rings+=1
	super._ring(canvas,center,radius,u,active)
