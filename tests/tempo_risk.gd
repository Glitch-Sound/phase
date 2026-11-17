extends "res://tests/cpu_policy.gd"
## REQ-035-S05
func _run()->void:
	policy=load("res://game/cpu_policy.gd").new()
	var t=load("res://game/tuning.gd")
	var b=B.new()
	b.start(0,C.player_builds(),1)
	b.actor=2
	b.units[1].hp=0
	b.units[3].hp=0
	b.units[2].hp=1
	b.units[2].pos=Vector2i(4,4)
	b.units[2].next_time=200
	b.units[0].pos=Vector2i(2,4)
	b.units[0].next_time=100
	var projected=b.units[0].duplicate(true)
	projected.pos=Vector2i(3,4)
	var threat=[{"index":0,"path":[Vector2i(3,4)],"unit":projected}]
	var before=_state(b)
	var risk=policy._danger(b,2,threat)
	_check(risk<t.CPU_TERMINAL_SCORE*0.5,"possible lethal retaliation is finite tactical loss, not a terminal certainty")
	var constants=t.get_script_constant_map()
	_check(constants.has("CPU_CRITICAL_RISK_WEIGHT"),"critical forecast has its own tunable weight")
	if constants.has("CPU_CRITICAL_RISK_WEIGHT"):
		_check(risk==t.CPU_KILL_BONUS*constants.CPU_CRITICAL_RISK_WEIGHT,"last-unit forecast uses the configured loss floor")
	_check(before==_state(b),"risk evaluation never mutates actual units")
	b.start(2,C.player_builds(),1)
	b.actor=2
	b.units[2].pos=Vector2i(8,1)
	b.units[0].pos=Vector2i(8,0)
	b.units[0].next_time=0
	b.units[2].next_time=200
	projected=b.units[0].duplicate(true)
	projected.pos=Vector2i(9,0)
	threat=[{"index":0,"path":[Vector2i(9,0)],"unit":projected}]
	_check(policy._danger(b,2,threat)>=t.CPU_TERMINAL_SCORE*0.5,"actual reachable objective still has terminal priority")
	print("TEMPO RISK: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
