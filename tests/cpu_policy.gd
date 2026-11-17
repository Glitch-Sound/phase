extends SceneTree
const B=preload("res://game/battle.gd")
const C=preload("res://game/catalog.gd")
var checks=0
var failures=0
var policy
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	_check(ResourceLoader.exists("res://game/cpu_policy.gd"),"CPU policy is implemented")
	if failures:
		_finish()
		return
	policy=load("res://game/cpu_policy.gd").new()
	_legal()
	_tactics()
	_finish()
## REQ-035-S02、REQ-035-S04
func _legal() -> void:
	var b=_battle()
	var before=_state(b)
	var plan=policy.choose(b,[])
	_check(_state(b)==before,"planning never mutates the battle")
	_check(plan==policy.choose(b,[]),"same state and memory gives the exact same plan")
	_check(_execute(b,plan),"chosen plan is legal through the actual battle API")
	_check(b.turn==2 or not b.result.is_empty(),"one planned action completes exactly once")
	b=_battle()
	b.units[2].skills=[]
	plan=policy.choose(b,[])
	_check(plan.skill=="" and not plan.path.is_empty(),"empty skill loadout moves then waits")
	_check(_execute(b,plan),"no unequipped active is used")
	b=_battle()
	b.units[2].pos=Vector2i(0,0)
	b.units[0].pos=Vector2i(1,0)
	b.units[1].hp=100
	b.units[1].pos=Vector2i(0,1)
	plan=policy.choose(b,[])
	_check(plan.path.is_empty() and plan.skill=="" and _execute(b,plan),"trapped actor uses only the legal unmoved WAIT")
	for seed_value in [1,128,729]:
		b=_battle(seed_value)
		b.units[2].skills=[C.DAMAGE,C.HEAL,C.MOVE]
		b.units[2].gear_mutation="LSRIV"
		plan=policy.choose(b,[])
		_check(plan.path.size()<=b.movement(b.units[2]) and _execute(b,plan),"panels, mutation and passive stay legal seed "+str(seed_value))
	b.result="VICTORY"
	b.mode="RESULT"
	_check(policy.choose(b,[]).is_empty(),"finished battle has no CPU plan")
## REQ-035-S03、REQ-035-S04
func _tactics() -> void:
	var b=_battle()
	b.units[0].hp=1
	var plan=policy.choose(b,[])
	_check(plan.skill==C.DAMAGE and plan.target==0 and _execute(b,plan) and b.result=="DEFEAT","CPU takes a real immediate elimination win")
	b=_battle()
	b.units[2].hp=1
	plan=policy.choose(b,[])
	_check(_distance(plan.path.back(),b.units[0].pos)>b.movement(b.units[0])+1,"last survivor avoids a reachable lethal counterattack when a safe route exists")
	b=_battle()
	b.units[0].pos=Vector2i(0,0)
	b.units[3].hp=1
	b.units[3].pos=Vector2i(6,4)
	b.units[2].pos=Vector2i(4,4)
	plan=policy.choose(b,[])
	_check(plan.skill==C.HEAL and plan.target==3,"heal restores an actually wounded ally")
	b.units[3].hp=b.units[3].max_hp
	_check(policy.choose(b,[]).skill!=C.HEAL,"full HP is never healed")
	b=B.new()
	b.start(2,C.player_builds(),128)
	b.actor=3
	b.units[3].pos=Vector2i(0,8)
	plan=policy.choose(b,[])
	_check(_execute(b,plan) and b.result=="DEFEAT","BREACH CPU reaches its own goal and stops before an extra action")
	b=B.new()
	b.start(3,C.player_builds(),128)
	b.actor=3
	b.units[3].pos=Vector2i(0,8)
	plan=policy.choose(b,[])
	_check(_execute(b,plan) and b.result=="DEFEAT","ANCHOR CPU ends its turn on the counter objective")
	b=B.new()
	b.start(1,C.player_builds(),128)
	b.actor=2
	b.units[0].pos=Vector2i(5,2)
	b.units[0].hp=1
	b.units[2].pos=Vector2i(7,2)
	plan=policy.choose(b,[])
	_check(plan.target==0 and _execute(b,plan) and b.result=="DEFEAT","SEVERANCE targets the actual protected PLAYER")
	b=B.new()
	b.start(2,C.player_builds(),1)
	b.actor=2
	b.units[0].pos=Vector2i(8,0)
	b.units[1].hp=0
	b.units[2].pos=Vector2i(7,1)
	b.units[3].pos=Vector2i(3,3)
	plan=policy.choose(b,[])
	_check(plan.path.back()==Vector2i(9,0) and _execute(b,plan) and b.result.is_empty(),"A occupies the threatened PLAYER goal instead of allowing next-turn BREACH")
	b=_battle()
	plan=policy.choose(b,[])
	var memory=[]
	for i in range(4):
		memory.append({"actor":2,"pos":plan.path.back(),"skill":plan.skill,"target":plan.target})
	var alternate=policy.choose(b,memory)
	_check(alternate.path!=plan.path or alternate.skill!=plan.skill or alternate.target!=plan.target,"recent identical decisions are penalized")
func _battle(layout_seed: int=128):
	var b=B.new()
	b.start(0,C.player_builds(),layout_seed)
	b.actor=2
	b.units[0].pos=Vector2i(4,4)
	b.units[1].hp=0
	b.units[2].pos=Vector2i(2,4)
	b.units[3].hp=0
	return b
func _execute(b,plan: Dictionary) -> bool:
	if plan.is_empty():
		return false
	for cell in plan.path:
		if not b.path_click(cell):
			return false
	if not plan.path.is_empty() and not b.commit_path():
		return false
	if not b.result.is_empty():
		return true
	return b.wait_turn() if plan.skill=="" else (b.choose_skill(plan.skill) and b.act(plan.target))
func _state(b) -> Array:
	return [b.units.duplicate(true),b.panels.duplicate(),b.path.duplicate(),b.actor,b.mode,b.turn,b.history.duplicate()]
func _distance(a: Vector2i,b: Vector2i) -> int:
	return absi(a.x-b.x)+absi(a.y-b.y)
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
func _finish() -> void:
	print("CPU POLICY: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
