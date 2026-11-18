extends "res://tests/cpu_policy.gd"
## REQ-035-S06
func _run() -> void:
	policy=load("res://game/cpu_policy.gd").new()
	var b=_battle()
	b.panels={}
	b.units[2].skills=[C.DAMAGE_DIAGONAL_TWO]
	b.units[2].pos=Vector2i(1,1)
	b.units[0].pos=Vector2i(4,4)
	b.units[0].hp=1
	var before=_state(b)
	var plan=policy.choose(b,[])
	_check(plan.skill==C.DAMAGE_DIAGONAL_TWO and plan.target==0,"new diagonal damage is a CPU candidate")
	_check(_state(b)==before and plan==policy.choose(b,[]),"new skill planning is read-only and deterministic")
	_check(_execute(b,plan) and b.mode=="RESULT","new single-target CPU command uses the battle API")
	b=_battle()
	b.panels={}
	b.units[0].pos=Vector2i(0,0)
	b.units[2].pos=Vector2i(4,4)
	b.units[2].skills=[C.HEAL_DIAGONAL_TWO]
	b.units[3].hp=1
	b.units[3].pos=Vector2i(7,6)
	plan=policy.choose(b,[])
	_check(plan.skill==C.HEAL_DIAGONAL_TWO and plan.target==3,"new diagonal heal restores a wounded ally")
	var old_memory=[{"actor":2,"pos":Vector2i(9,9),"skill":C.HEAL,"target":3}]
	var new_memory=[{"actor":2,"pos":Vector2i(9,9),"skill":C.HEAL_DIAGONAL_TWO,"target":3}]
	_check(policy.choose(b,old_memory)==policy.choose(b,new_memory),"heal repetition applies equally across range IDs")
	_check(_execute(b,plan) and b.units[3].hp>1 and b.units[3].hp<=b.units[3].max_hp,"new CPU heal executes once within HP bounds")
	b=_battle()
	b.panels={}
	b.units[2].pos=Vector2i(4,4)
	b.units[0].skills=[C.DAMAGE_DIAGONAL_TWO,C.DAMAGE_ORTHOGONAL_TWO]
	b.units[0].pos=Vector2i(0,0)
	b.units[0].next_time=0
	b.units[2].next_time=100
	var first=b.units[0].duplicate(true)
	first.pos=Vector2i(2,2)
	var second=first.duplicate(true)
	second.pos=Vector2i(2,4)
	var threats=[{"index":0,"path":[first.pos],"unit":first}]
	var risk=policy._danger(b,2,threats)
	_check(risk>0,"new diagonal range contributes counterattack risk")
	threats.append({"index":0,"path":[second.pos],"unit":second})
	_check(policy._danger(b,2,threats)==risk,"alternative patterns from one attacker do not double-count damage")
	b.units[0].skills=[C.DAMAGE_ORTHOGONAL_TWO]
	_check(policy._danger(b,2,threats.slice(0,1))==0,"wrong geometry creates no counterattack")
	print("SKILL PATTERN CPU: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
