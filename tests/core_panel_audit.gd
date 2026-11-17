extends "res://tests/panel_audit.gd"
var ring_records=[]
func _draw() -> void:
	ring_records=[]
	super._draw()
func _ring(canvas: CanvasItem,center: Vector2,radius: float,u: Dictionary,active: bool=false) -> void:
	ring_records.append({"center":center,"radius":radius,"unit":u.duplicate(true)})
	super._ring(canvas,center,radius,u,active)
