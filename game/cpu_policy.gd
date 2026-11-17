## 公開された現在の戦闘状態から、決定的な経路と行動を選ぶ。
extends RefCounted
const B=preload("res://game/battle.gd")
const C=preload("res://game/catalog.gd")
const M=preload("res://game/phase_math.gd")
const T=preload("res://game/tuning.gd")

## CPUの候補を選ぶ。battleは現在の戦闘、memoryは過去の選択。戻り値はpath、skill、target、scoreの辞書、終了時は空。原本と乱数を変えない。
func choose(battle: RefCounted, memory: Array=[]) -> Dictionary:
	if battle.mode!="MOVE" or not battle.result.is_empty() or battle.actor<0:
		return {}
	var actor: int=battle.actor
	var source: Dictionary=battle.units[actor]
	var routes=_routes(battle,actor)
	if routes.is_empty():
		return {"path":[],"skill":"","target":-1,"score":0.0}
	var threats=[]
	for i in range(battle.units.size()):
		if battle.units[i].hp>0 and battle.units[i].camp!=source.camp:
			for route in _routes(battle,i,actor):
				var projected=_project(battle,i,route)
				threats.append({"index":i,"path":route,"unit":projected})
	var best={"score":-INF}
	for route in routes:
		var moved=_project(battle,actor,route)
		var options=[{"skill":"","target":-1}]
		for skill in source.skills:
			if skill not in [C.DAMAGE,C.HEAL]:
				continue
			for i in range(battle.units.size()):
				var target: Dictionary=battle.units[i]
				if i==actor or target.hp<=0 or _distance(moved.pos,target.pos)!=1:
					continue
				if (skill==C.DAMAGE and target.camp!=source.camp) or (skill==C.HEAL and target.camp==source.camp and target.hp<target.max_hp):
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
					if action.skill==C.DAMAGE:
						score+=(old.hp-now.hp)*T.CPU_DAMAGE_WEIGHT
						if now.hp<=0:
							score+=T.CPU_KILL_BONUS
					else:
						var weight=T.CPU_HEAL_WEIGHT
						for recent in memory.slice(-2):
							if recent.actor==actor and recent.skill==C.HEAL:
								weight*=0.5
						score+=(now.hp-old.hp)*weight
				score-=_danger(after,actor,threats)
				for recent in memory:
					if recent.actor==actor and recent.pos==moved.pos:
						score-=T.CPU_REPEAT_PENALTY
				score+=M.sync(moved,2).factor*0.05-route.size()*0.001
			if score>best.score:
				plan.score=score
				best=plan
	return best

func _position_score(b, actor: int) -> float:
	var u: Dictionary=b.units[actor]
	var nearest=100
	for target in b.units:
		if target.hp>0 and target.camp!=u.camp:
			nearest=mini(nearest,_distance(u.pos,target.pos))
	var score=-float(nearest)*3.0
	var own=b.stage.defeat if u.camp=="ENEMY" else b.stage.victory
	for condition in own:
		if condition.type in ["REACH","OCCUPY"] and (not condition.has("unit") or condition.unit==u.id):
			score-=_distance(u.pos,condition.cell)*12.0
	# Aの守備は脅威が近いときに強め、Bは反対側の目標へ進む。
	if u.camp=="ENEMY" and b.stage.type in ["REACH","OCCUPY"] and u.id=="A" and b.units[3].hp>0:
		var approach=100
		for target in b.units:
			if target.hp>0 and target.camp=="PLAYER":
				approach=mini(approach,_distance(target.pos,b.stage.goal))
		score-=_distance(u.pos,b.stage.goal)*(18.0 if approach<=4 else 3.0)
	return score

func _danger(after, actor: int, threats: Array) -> float:
	var u: Dictionary=after.units[actor]
	var risk=0.0
	var max_hits={}
	var opposing=after.stage.victory if u.camp=="ENEMY" else after.stage.defeat
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
		for condition in opposing:
			if condition.type in ["REACH","OCCUPY"] and condition.camp==attacker.camp and (not condition.has("unit") or condition.unit==attacker.id) and entry.unit.pos==condition.cell:
				risk=maxf(risk,T.CPU_TERMINAL_SCORE*0.5)
		if not attacker.skills.has(C.DAMAGE):
			continue
		for j in range(after.units.size()):
			var victim: Dictionary=after.units[j]
			if victim.hp<=0 or victim.camp!=u.camp or _distance(entry.unit.pos,victim.pos)!=1:
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
		M.enter_panel(u,b.panels.get(cell,"NORMAL"))
		u.pos=cell
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
