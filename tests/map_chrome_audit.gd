extends "res://ui/main.gd"
var drawn_text=[]
func _draw() -> void:
	drawn_text=[]
	super._draw()
func _text(text: String,position_px: Vector2,font_size: int,color: Color=WHITE,typeface: Font=null) -> void:
	drawn_text.append({"text":text,"position":position_px})
	super._text(text,position_px,font_size,color,typeface)
