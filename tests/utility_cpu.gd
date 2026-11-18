extends "res://tests/cpu_policy.gd"
## REQ-035-S07
func _run() -> void:
	policy=load("res://tests/utility_cpu_audit.gd").new()
	var b=_battle()
	b.units[1].hp=b.units[1].max_hp
	b.units[1].pos=Vector2i.ZERO
	b.units[0].pos=Vector2i(6,4)
	b.units[2].pos=Vector2i(4,4)
	b.units[2].skills=[C.SWAP,C.PUSH,C.GUARD]
	b.units[3].hp=b.units[3].max_hp
	b.units[3].pos=Vector2i(5,5)
	b.panels={}
	var before=_state(b)
	var plan=policy.choose(b,[])
	_check(_state(b)==before and plan==policy.choose(b,[]),"utility planning is read-only and deterministic")
	for skill in [C.SWAP,C.PUSH,C.GUARD]:
		_check(policy.valid_commands.any(func(command):return command.skill==skill),"CPU considers legal utility "+skill)
	_check(_execute(b,plan) and (b.turn==2 or not b.result.is_empty()),"chosen utility or ordinary plan completes through the battle API")
	b=_battle()
	b.units[2].skills=[C.IGNORE_PANEL]
	b.units[2].core_angle=90.0
	b.panels={Vector2i(3,4):"CLOCKWISE"}
	var projected=policy._project(b,2,[Vector2i(3,4)])
	_check(projected.core_angle==90.0 and b.units[2].core_angle==90.0 and projected.gear_angle==330.0,"CPU route prediction obeys panel ignore and ordinary equipment rotation")
	_field_prediction()
	print("UTILITY CPU: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)

## REQ-035-S08
func _field_prediction() -> void:
	var b=_battle()
	b.units[1].pos=Vector2i(4,3)
	b.units[1].hp=b.units[1].max_hp
	b.units[1].skills=["PASSIVE_FIELD_SLOW_ADJACENT"]
	b.panels={}
	var projected=policy._project(b,2,[Vector2i(3,4)])
	_check(projected.gear_angle==345.0 and projected.arms_angle==15.0,"CPU projects actual neighboring fields at each landing")
	var cache={}
	var near=policy._threats_for(b,0,cache).filter(func(entry):return entry.index==2 and entry.path==[Vector2i(3,4)])
	b.units[1].pos=Vector2i(9,9)
	var far=policy._threats_for(b,0,cache).filter(func(entry):return entry.index==2 and entry.path==[Vector2i(3,4)])
	_check(near.size()==1 and far.size()==1 and near[0].unit.gear_angle==345.0 and far[0].unit.gear_angle==330.0,"threat reuse never carries a field from the emitter's old position")
	b.units[1].pos=Vector2i(4,3)
	var before=_state(b)
	var plan=policy.choose(b,[])
	_check(_state(b)==before and plan==policy.choose(b,[]),"field-aware planning remains read-only and deterministic")
	_check(_execute(b,plan) and (b.turn==2 or not b.result.is_empty()),"field-aware plan executes through ordinary legal operations")
