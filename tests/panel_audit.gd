extends "res://ui/main.gd"
func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal=Control.GROW_DIRECTION_BOTH
	grow_vertical=Control.GROW_DIRECTION_BOTH
	mouse_filter=Control.MOUSE_FILTER_IGNORE
var drawn_text=[]
var drawn_icons=[]
var drawn_brackets=[]
var full_focus=[]
func _draw() -> void:
	drawn_text=[]
	drawn_icons=[]
	drawn_brackets=[]
	full_focus=[]
	super._draw()
func _text(text: String,position_px: Vector2,font_size: int,color: Color=WHITE,typeface: Font=null) -> void:
	drawn_text.append({"text":text,"position":position_px})
	super._text(text,position_px,font_size,color,typeface)
func _draw_panel_icon(kind: String,rect: Rect2,color: Color) -> void:
	drawn_icons.append({"kind":kind,"rect":rect,"color":color,"texture":ICONS[PANEL_VIEWS[kind].icon].resource_path})
	super._draw_panel_icon(kind,rect,color)
func _brackets(rect: Rect2,color: Color) -> void:
	drawn_brackets.append({"rect":rect,"color":color})
	super._brackets(rect,color)
func _draw_cell_focus(rect: Rect2,color: Color,full_outline: bool=false,line_width: float=2.0) -> void:
	if full_outline:
		full_focus.append({"rect":rect,"color":color,"width":line_width})
	super._draw_cell_focus(rect,color,full_outline,line_width)
