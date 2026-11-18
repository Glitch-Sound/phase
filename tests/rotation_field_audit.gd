extends "res://tests/skill_pattern_audit.gd"
var field_clouds=[]
var field_draw_times=[]
func _draw_board() -> void:
	field_clouds=[]
	var begin=Time.get_ticks_usec()
	super._draw_board()
	field_draw_times.append((Time.get_ticks_usec()-begin)/1000.0)
	if field_draw_times.size()>300:field_draw_times.pop_front()
func _field_cloud(source: Dictionary,preview: bool,phase: float) -> void:
	field_clouds.append({"source":source.duplicate(true),"preview":preview,"phase":phase})
	super._field_cloud(source,preview,phase)
