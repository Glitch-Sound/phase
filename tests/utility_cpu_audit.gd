extends "res://game/cpu_policy.gd"
var valid_commands=[]
func _simulate(b,plan: Dictionary):
	var after=super._simulate(b,plan)
	if after!=null:
		valid_commands.append(plan.duplicate(true))
	return after
