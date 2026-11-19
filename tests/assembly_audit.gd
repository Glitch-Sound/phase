extends "res://tests/movement_audit.gd"
var displayed_assemblies=[]
var ownership_marks=[]
func _draw() -> void:
	displayed_assemblies=[];ownership_marks=[];super._draw()
func _assembly_emblem(canvas: CanvasItem,center: Vector2,radius: float,profile: Dictionary,camp: String) -> void:
	displayed_assemblies.append({"center":center,"radius":radius,"profile":profile.duplicate(true),"camp":camp})
	super._assembly_emblem(canvas,center,radius,profile,camp)
func _ownership_marker(center: Vector2,u: Dictionary) -> void:
	if A.owns(u,view_camp):ownership_marks.append({"center":center+T.OWNER_MARK_OFFSET,"unit":u.duplicate(true)})
	super._ownership_marker(center,u)
