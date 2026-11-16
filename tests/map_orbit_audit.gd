extends "res://tests/phase_preview_audit.gd"
var drawn_bars=[]
var in_board=false
func _draw() -> void:
	drawn_bars=[]
	super._draw()
func _draw_board() -> void:
	in_board=true
	super._draw_board()
	in_board=false
func _bar(rect: Rect2,ratio: float,color: Color) -> void:
	drawn_bars.append({"rect":rect,"ratio":ratio,"color":color})
	super._bar(rect,ratio,color)
func _text(text: String,position_px: Vector2,font_size: int,color: Color=WHITE,typeface: Font=null) -> void:
	super._text(text,position_px,font_size,color,typeface)
	drawn_text[-1].in_board=in_board
