extends "res://tests/fixture_main.gd"
var rings=[]
func _draw() -> void:
	rings=[]
	super._draw()
func _ring(canvas: CanvasItem,center: Vector2,radius: float,u: Dictionary,active: bool=false) -> void:
	rings.append({"center":center,"radius":radius,"id":u.id,"active":active})
	super._ring(canvas,center,radius,u,active)
