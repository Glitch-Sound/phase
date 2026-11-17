extends "res://tests/order_axis_audit.gd"
var info_text=[]
var info_records=[]
var info_rings=[]
var info_bars=[]
var in_info=false
# 実戦値では生じない書式境界を表示だけで確認するfixture。
var factor_inputs=[]
var factor_input_index=0
func _draw_timeline() -> void:
	factor_input_index=0
	super._draw_timeline()
func _factor_field(value: float) -> String:
	var displayed=value
	if not factor_inputs.is_empty():
		displayed=factor_inputs[factor_input_index%factor_inputs.size()]
		factor_input_index+=1
	return super._factor_field(displayed)
func _draw_info() -> void:
	info_text=[]
	info_records=[]
	info_rings=[]
	info_bars=[]
	in_info=true
	super._draw_info()
	in_info=false
func _text(text: String,position_px: Vector2,font_size: int,color: Color=WHITE,typeface: Font=null) -> void:
	if in_info:
		info_text.append(text)
		info_records.append({"text":text,"position":position_px,"font_size":font_size,"color":color,"typeface":font if typeface==null else typeface})
	super._text(text,position_px,font_size,color,typeface)
func _ring(canvas: CanvasItem,center: Vector2,radius: float,u: Dictionary,active: bool=false) -> void:
	if in_info:
		info_rings.append({"center":center,"unit":u.duplicate(true)})
	super._ring(canvas,center,radius,u,active)
func _bar(rect: Rect2,ratio: float,color: Color) -> void:
	if in_info:
		info_bars.append(rect)
	super._bar(rect,ratio,color)
