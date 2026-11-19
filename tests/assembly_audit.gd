extends "res://tests/movement_audit.gd"
var displayed_assemblies=[]
var ownership_marks=[]
var assembly_bars=[]
func _draw() -> void:
	displayed_assemblies=[];ownership_marks=[];assembly_bars=[];super._draw()
func _assembly_emblem(canvas: CanvasItem,center: Vector2,radius: float,profile: Dictionary,camp: String) -> void:
	displayed_assemblies.append({"center":center,"radius":radius,"profile":profile.duplicate(true),"camp":camp})
	super._assembly_emblem(canvas,center,radius,profile,camp)
func _ownership_marker(center: Vector2,u: Dictionary) -> void:
	if A.owns(u,view_camp):ownership_marks.append({"center":center+T.OWNER_MARK_OFFSET,"unit":u.duplicate(true)})
	super._ownership_marker(center,u)
func _text(text: String,position_px: Vector2,font_size: int,color: Color=WHITE,typeface: Font=null) -> void:
	super._text(text,position_px,font_size,color,typeface)
	text_records.back().font_size=font_size

func _bar(rect: Rect2,ratio: float,color: Color) -> void:
	assembly_bars.append({"rect":rect,"ratio":ratio,"color":color})
	super._bar(rect,ratio,color)
