## 公開された現在の戦闘状態から、決定的な経路と行動を選ぶ。
extends RefCounted
const B=preload("res://game/battle.gd")
const C=preload("res://game/catalog.gd")
const M=preload("res://game/phase_math.gd")
const T=preload("res://game/tuning.gd")
const F=preload("res://game/rotation_field.gd")

## CPUの候補を選ぶ。battleは現在の戦闘、memoryは過去の選択。戻り値はpath、skill、target、scoreの辞書、終了時は空。原本と乱数を変えない。
func choose(battle: RefCounted, memory: Array=[]) -> Dictionary:
	if battle.mode!="MOVE" or not battle.result.is_empty() or battle.actor<0:
		return {}
	var actor: int=battle.actor
	var source: Dictionary=battle.units[actor]
	var routes=_routes(battle,actor)
	if routes.is_empty():
		return {"path":[],"skill":"","target":-1,"score":0.0}
	var field_context=F.has_fields(battle.units)
	var threat_cache={}
	var threats=[] if field_context else _threats(battle,actor)
	var best={"score":-INF}
	for route in routes:
		var moved=_project(battle,actor,route)
		var options=[{"skill":"","target":-1}]
		for skill in source.skills:
			if C.SKILLS.get(skill,{}).get("type","")!="ACTIVE":
				continue
			for i in range(battle.units.size()):
				var target: Dictionary=moved if i==actor else battle.units[i]
				if C.target_matches(skill,moved,target):
					options.append({"skill":skill,"target":i})
		for action in options:
			var plan={"path":route,"skill":action.skill,"target":action.target}
			var after=_simulate(battle,plan)
			if after==null:
				continue
			var own_win="DEFEAT" if source.camp=="ENEMY" else "VICTORY"
			var score=0.0
			if not after.result.is_empty():
				score=T.CPU_TERMINAL_SCORE if after.result==own_win else -T.CPU_TERMINAL_SCORE
			else:
				score=_position_score(after,actor)
				if action.target>=0:
					var old: Dictionary=battle.units[action.target]
					var now: Dictionary=after.units[action.target]
					if C.SKILLS[action.skill].effect=="DAMAGE":
						score+=(old.hp-now.hp)*T.CPU_DAMAGE_WEIGHT
						if now.hp<=0:
							score+=T.CPU_KILL_BONUS
					elif C.SKILLS[action.skill].effect=="HEAL":
						var weight=T.CPU_HEAL_WEIGHT
						for recent in memory.slice(-2):
							if recent.actor==actor and C.SKILLS.get(recent.skill,{}).get("effect","")=="HEAL":
								weight*=0.5
						score+=(now.hp-old.hp)*weight
				var kind=C.SKILLS.get(action.skill,{}).get("effect","")
				score+=_utility_score(battle,after,actor,kind)
				score-=_danger(after,actor,_threats_for(after,actor,threat_cache) if field_context or kind=="PUSH" else threats)
				for recent in memory:
					if recent.actor==actor and recent.pos==moved.pos:
						score-=T.CPU_REPEAT_PENALTY
				score+=M.sync(moved,2).factor*0.05-route.size()*0.001
			if score>best.score:
				plan.score=score
				best=plan
	return best

func _threats_for(b, actor: int, cache: Dictionary) -> Array:
	# このchoose内では装備と配分は不変。位置、生存と反撃側の角度で区別する。
	var state=[]
	for u in b.units:
		state.append([u.pos,u.hp>0])
		if u.camp!=b.units[actor].camp:
			state.append([u.core_angle,u.gear_angle,u.arms_angle])
	var key=var_to_str(state)
	if not cache.has(key):cache[key]=_threats(b,actor)
	return cache[key]

func _threats(b, actor: int) -> Array:
	var result=[]
	for i in range(b.units.size()):
		if b.units[i].hp>0 and b.units[i].camp!=b.units[actor].camp:
			for route in _routes(b,i,actor):
				result.append({"index":i,"path":route,"unit":_project(b,i,route)})
	return result

func _utility_score(before, after, actor: int, kind: String) -> float:
	if kind not in ["SWAP","PUSH"]:
		return 0.0
	var camp: String=after.units[actor].camp
	return (_pressure(after,camp)-_pressure(before,camp))*T.CPU_UTILITY_PRESSURE_WEIGHT

func _pressure(b, camp: String) -> float:
	var value=0.0
	for u in b.units:
		if u.hp<=0 or u.camp!=camp:
			continue
		var hit=0
		for target in b.units:
			for skill in u.skills:
				if C.SKILLS.get(skill,{}).get("effect","")=="DAMAGE" and C.target_matches(skill,u,target):
					hit=maxi(hit,mini(M.effect(u,target,"DAMAGE"),ceili(target.hp)))
		value+=hit
	return value

func _position_score(b, actor: int) -> float:
	var u: Dictionary=b.units[actor]
	var nearest=100
	for target in b.units:
		if target.hp>0 and target.camp!=u.camp:
			nearest=mini(nearest,_distance(u.pos,target.pos))
	var score=-float(nearest)*3.0
	return score

func _danger(after, actor: int, threats: Array) -> float:
	var u: Dictionary=after.units[actor]
	var risk=0.0
	var max_hits={}
	for entry in threats:
		var i: int=entry.index
		var attacker: Dictionary=after.units[i]
		if attacker.hp<=0 or attacker.next_time>u.next_time+B.TIME_EPS:
			continue
		var blocked=false
		for cell in entry.path:
			if after.at(cell)>=0:
				blocked=true
				break
		if blocked:
			continue
		for j in range(after.units.size()):
			var victim: Dictionary=after.units[j]
			if victim.camp!=u.camp:
				continue
			var reachable=false
			for skill in attacker.skills:
				if C.SKILLS.get(skill,{}).get("effect","")=="DAMAGE" and C.target_matches(skill,entry.unit,victim):
					reachable=true
			if not reachable:
				continue
			var hit=M.effect(entry.unit,victim,"DAMAGE")
			var key=Vector2i(i,j)
			max_hits[key]=maxi(max_hits.get(key,0),hit)
	for key in max_hits:
		var victim: Dictionary=after.units[key.y]
		var hit: float=max_hits[key]
		if key.y==actor:
			risk+=minf(hit,victim.hp)*T.CPU_DANGER_WEIGHT
			if hit>=victim.hp:
				risk+=T.CPU_KILL_BONUS
		if hit>=victim.hp and _critical(after,key.y):
			risk=maxf(risk,T.CPU_KILL_BONUS*T.CPU_CRITICAL_RISK_WEIGHT)
	return risk

func _critical(b, index: int) -> bool:
	var u: Dictionary=b.units[index]
	var live=b.units.filter(func(other):return other.hp>0 and other.camp==u.camp).size()
	if live==1:
		return true
	for condition in b.stage.victory if u.camp=="ENEMY" else b.stage.defeat:
		if condition.type=="TARGET" and condition.camp==u.camp and (not condition.has("unit") or condition.unit==u.id):
			return true
	return false

func _simulate(b, plan: Dictionary):
	var copy=B.new()
	copy.units=b.units.duplicate(true)
	copy.panels=b.panels
	copy.stage=b.stage
	copy.actor=b.actor
	copy.turn=b.turn
	copy.mode="MOVE"
	for cell in plan.path:
		if not copy.path_click(cell):
			return null
	if not plan.path.is_empty() and not copy.commit_path():
		return null
	if copy.result.is_empty():
		var ok=copy.wait_turn() if plan.skill=="" else (copy.choose_skill(plan.skill) and copy.act(plan.target))
		if not ok:
			return null
	return copy

func _project(b, index: int, route: Array) -> Dictionary:
	var u: Dictionary=b.units[index].duplicate(true)
	for cell in route:
		B.enter_cell(u,cell,b.panels.get(cell,"NORMAL"),b.units)
	return u

func _routes(b, index: int, vacated: int=-1) -> Array:
	var routes=[]
	_walk(b,b.units[index].pos,[],routes,b.movement(b.units[index]),vacated)
	return routes

func _walk(b, cell: Vector2i, path: Array, routes: Array, limit: int, vacated: int) -> void:
	if not path.is_empty():
		routes.append(path.duplicate())
	if path.size()>=limit:
		return
	for direction in B.DIRS:
		var next: Vector2i=cell+direction
		var occupied: int=b.at(next)
		if not Rect2i(0,0,10,10).has_point(next) or (occupied>=0 and occupied!=vacated) or path.has(next):
			continue
		path.append(next)
		_walk(b,next,path,routes,limit,vacated)
		path.pop_back()

static func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x-b.x)+absi(a.y-b.y)
