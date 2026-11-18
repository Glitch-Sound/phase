extends "res://tests/side_info_audit.gd"
var target_frames=[]
func _draw_board() -> void:
	target_frames=[]
	super._draw_board()
func _draw_cell_focus(rect: Rect2,color: Color,full_outline: bool=false,line_width: float=2.0) -> void:
	if full_outline and battle.mode=="TARGET":
		var cell=Vector2i((rect.position-BOARD)/CELL)
		if not target_frames.has(cell): target_frames.append(cell)
	super._draw_cell_focus(rect,color,full_outline,line_width)
func _center(text: String,position_px: Vector2,font_size: int,color: Color=WHITE,typeface: Font=null) -> void:
	if in_board: drawn_text.append({"text":text,"position":position_px})
	super._center(text,position_px,font_size,color,typeface)
