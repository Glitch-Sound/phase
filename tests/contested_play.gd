extends SceneTree
const C=preload("res://game/catalog.gd")
const B=preload("res://tests/fixture_battle.gd")
const RUNTIME_B=preload("res://game/battle.gd")
const M=preload("res://game/phase_math.gd")
var failures=0

func _initialize() -> void:
	var report={"unopposed":[],"mutual":[],"contested_wins":[]}
	for stage in [2,3]:
		var run=_unopposed(stage)
		report.unopposed.append(run)
		_check(run.result=="DEFEAT" and run.turns>4,"ignoring counter-goal loses after opponents act")
	var first=_mutual(0.88,160)
	var second=_mutual(0.88,160)
	report.mutual.append(first)
	_check(first==second,"mutual play deterministic")
	_check(not first.result.is_empty(),"mutual play finishes")
	for camp in ["PLAYER","ENEMY"]:
		_check(first.actions[camp].DAMAGE>0 and first.actions[camp].HEAL>0,"both camps attack and heal")
	report.mutual.append(_mutual(1.8,160))
	report.mutual.append(_mutual(10.0,160))
	for stage in [2,3]:
		var win=_contested_win(stage)
		report.contested_wins.append(win)
		_check(win.result=="VICTORY","contested objective is winnable: %d" % stage)
	report.native_replay=_mutual(1.1,160,true)
	_check(report.native_replay.result=="VICTORY","actual starter roles finish the native replay")
	for camp in ["PLAYER","ENEMY"]:
		_check(report.native_replay.actions[camp].DAMAGE>0 and report.native_replay.actions[camp].HEAL>0 and report.native_replay.actions[camp].WAIT==0,"native replay includes both actions without waiting")
	print("NATIVE REPLAY: ",JSON.stringify(report.native_replay.actions)," / ",report.native_replay.result," / ",report.native_replay.turns)
	var file=FileAccess.open("res://artifacts/contested-play.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	for row in report.unopposed:
		print("COUNTER OBJECTIVE: stage %d / %s / %d turns" % [row.stage,row.result,row.turns])
	for row in report.mutual:
		print("MUTUAL PLAY: heal weight %.2f / %s / %d turns / %s" % [row.heal_weight,row.result if not row.result.is_empty() else "UNFINISHED",row.turns,JSON.stringify(row.actions)])
	for row in report.contested_wins:
		print("CONTESTED WIN: stage %d / %s / %d turns" % [row.stage,row.result,row.turns])
	print("CONTESTED PLAY: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)

## REQ-023-S02
func _unopposed(stage: int, layout_seed: Variant=null) -> Dictionary:
	var b=B.new() if layout_seed==null else RUNTIME_B.new()
	b.start(stage,[C.starter_build(),C.starter_build()],0 if layout_seed==null else int(layout_seed))
	var actors=[]
	while b.result.is_empty() and b.turn<40:
		var source=b.actor
		var path=[]
		if source==3:
			path=_toward(b,b.stage.enemy_goal)
		else:
			for d in B.DIRS:
				var cell: Vector2i=b.units[source].pos+d
				if _inside(cell) and b.at(cell)<0 and cell!=b.stage.goal:
					path=[cell]
					break
		_check(not path.is_empty(),"a legal step exists")
		for cell in path:
			_check(b.path_click(cell),"counter path legal")
		b.commit_path()
		actors.append(b.units[source].id)
		if b.result.is_empty():
			b.wait_turn()
	return {"stage":stage,"result":b.result,"turns":b.turn,"actors":actors,"history":b.history}

## REQ-023-S03
func _mutual(heal_weight: float, limit: int, roles: bool=false, layout_seed: Variant=null) -> Dictionary:
	var b=B.new() if layout_seed==null else RUNTIME_B.new()
	b.start(0,C.player_builds() if roles else [C.starter_build(),C.starter_build()],0 if layout_seed==null else int(layout_seed))
	var actions={"PLAYER":{"DAMAGE":0,"HEAL":0,"WAIT":0},"ENEMY":{"DAMAGE":0,"HEAL":0,"WAIT":0}}
	var commands=[]
	var state_counts={}
	var repeated_states=0
	while b.result.is_empty() and b.turn<=limit:
		var options=[]
		_paths(b,b.units[b.actor].pos,[],options)
		var best={"score":-INF,"path":[],"skill":"","target":-1}
		for path in options:
			var u=b.units[b.actor].duplicate(true)
			for cell in path:
				M.enter_panel(u,b.panels.get(cell,"NORMAL"))
				u.pos=cell
			var nearest_enemy=100
			var nearest_wounded=100
			for i in range(b.units.size()):
				var target: Dictionary=b.units[i]
				if target.hp<=0:
					continue
				var distance=_distance(u.pos,target.pos)
				if target.camp!=u.camp:
					nearest_enemy=mini(nearest_enemy,distance)
				elif i!=b.actor and target.hp<target.max_hp:
					nearest_wounded=mini(nearest_wounded,distance)
				if distance!=1 or i==b.actor:
					continue
				var skill=C.DAMAGE if target.camp!=u.camp else C.HEAL
				var kind="DAMAGE" if skill==C.DAMAGE else "HEAL"
				var amount=M.effect(u,target,kind)
				var actual=minf(target.hp,amount) if kind=="DAMAGE" else minf(target.max_hp-target.hp,amount)
				if actual<=0:
					continue
				var score=actual*(heal_weight if kind=="HEAL" else 1.0)
				if kind=="DAMAGE" and amount>=target.hp:
					score+=100
				score+=M.sync(u,2).factor*0.05-path.size()*0.001
				if score>best.score:
					best={"score":score,"path":path,"skill":skill,"target":i}
			var movement_score=-100.0-nearest_enemy*10.0
			if nearest_wounded<100:
				movement_score=maxf(movement_score,-100.0-nearest_wounded*8.0)
			if movement_score>best.score:
				best={"score":movement_score,"path":path,"skill":"","target":-1}
		var camp: String=b.units[b.actor].camp
		var command={"unit":b.units[b.actor].id,"camp":camp,"path":[],"skill":best.skill,"target":best.target,"target_cell":[] if best.target<0 else [b.units[best.target].pos.x,b.units[best.target].pos.y]}
		for cell in best.path:
			command.path.append([cell.x,cell.y])
		for cell in best.path:
			_check(b.path_click(cell),"mutual path legal")
		if not best.path.is_empty():
			_check(b.commit_path(),"mutual move committed")
		else:
			_check(b.trapped(),"empty route only while trapped")
		if best.target>=0:
			var kind: String=C.SKILLS[best.skill].effect
			_check(b.choose_skill(best.skill) and b.act(best.target),"mutual action valid")
			actions[camp][kind]+=1
		else:
			_check(b.wait_turn(),"mutual wait valid")
			actions[camp].WAIT+=1
		commands.append(command)
		var state=[]
		for u in b.units:
			state.append([u.id,str(u.pos),u.hp,u.gear_angle,u.arms_angle])
		var key=JSON.stringify([b.actor,state])
		state_counts[key]=state_counts.get(key,0)+1
		if state_counts[key]>1:
			repeated_states+=1
	return {"roles":roles,"heal_weight":heal_weight,"result":b.result,"turns":b.turn,"actions":actions,"repeated_states":repeated_states,"history":b.history,"commands":commands}

func _contested_win(stage_index: int, layout_seed: Variant=null, builds_override: Array=[]) -> Dictionary:
	var b=B.new() if layout_seed==null else RUNTIME_B.new()
	b.start(stage_index,C.player_builds() if builds_override.is_empty() else builds_override,0 if layout_seed==null else int(layout_seed))
	var commands=[]
	while b.result.is_empty() and b.turn<100:
		var routes=[]
		_paths(b,b.units[b.actor].pos,[],routes)
		var source: Dictionary=b.units[b.actor]
		var best={"score":-INF,"path":[],"target":-1,"skill":""}
		var rush_distance=100
		if b.actor==3:
			for route in routes:
				rush_distance=mini(rush_distance,_distance(route.back(),b.stage.enemy_goal))
		for route in routes:
			var unit=source.duplicate(true)
			for cell in route:
				M.enter_panel(unit,b.panels.get(cell,"NORMAL"))
				unit.pos=cell
			var goal_distance=_distance(unit.pos,b.stage.goal)
			if b.actor==2 and goal_distance>1:
				continue
			if b.actor==3 and _distance(unit.pos,b.stage.enemy_goal)!=rush_distance:
				continue
			var focus=b.units[3].pos if b.units[3].hp>0 else b.units[2].pos
			if b.units[2].hp<=0 and b.units[3].hp<=0:
				focus=b.stage.goal
			var score=-100.0-_distance(unit.pos,focus)*10.0
			var target=-1
			var skill=""
			for i in range(b.units.size()):
				var other: Dictionary=b.units[i]
				if i==b.actor or other.hp<=0 or _distance(unit.pos,other.pos)!=1:
					continue
				var kind="DAMAGE" if other.camp!=unit.camp else "HEAL"
				var amount=M.effect(unit,other,kind)
				var actual=minf(amount,other.hp) if kind=="DAMAGE" else minf(amount,other.max_hp-other.hp)
				if actual<=0:
					continue
				var value=actual*(0.88 if kind=="HEAL" else 1.0)
				if unit.camp=="PLAYER" and i==3:
					value+=60
				if kind=="DAMAGE" and amount>=other.hp:
					value+=100
				if value>score:
					score=value
					target=i
					skill=C.DAMAGE if kind=="DAMAGE" else C.HEAL
			if b.actor==2:
				score-=goal_distance*150
			if unit.camp=="PLAYER" and unit.pos==b.stage.goal and (stage_index==3 or b.actor==0):
				score=10000
				target=-1
				skill=""
			# 初動で02の最短攻撃経路(4,6)を塞がず、迎撃を連携する。
			if b.turn==1 and b.actor==0 and unit.pos==(Vector2i(5,6) if source.skills.has(C.MOVE) else Vector2i(5,5)):
				score+=1000
			score+=M.sync(unit,2).factor*0.05-route.size()*0.001
			if score>best.score:
				best={"score":score,"path":route,"target":target,"skill":skill}
		var command={"unit":source.id,"path":str(best.path),"skill":best.skill,"target":best.target}
		if best.path.is_empty():
			_check(b.trapped(),"contested fallback trapped")
			b.wait_turn()
		else:
			for cell in best.path:
				_check(b.path_click(cell),"contested legal path")
			b.commit_path()
			if b.result.is_empty():
				if best.target>=0:
					_check(b.choose_skill(best.skill) and b.act(best.target),"contested valid action")
				else:
					b.wait_turn()
		commands.append(command)
	return {"stage":stage_index,"result":b.result,"turns":b.turn,"history":b.history,"commands":commands}

func _toward(b: RefCounted, goal: Vector2i) -> Array:
	var routes=[]
	_paths(b,b.units[b.actor].pos,[],routes)
	var best=[]
	var distance=100
	for path in routes:
		var d=_distance(path.back(),goal)
		if d<distance or (d==distance and path.size()<best.size()):
			distance=d
			best=path
	return best

func _paths(b: RefCounted, cell: Vector2i, path: Array, result: Array) -> void:
	if not path.is_empty():
		result.append(path.duplicate())
	if path.size()>=b.movement(b.units[b.actor]):
		return
	for direction in B.DIRS:
		var next: Vector2i=cell+direction
		if not _inside(next) or b.at(next)>=0 or path.has(next):
			continue
		path.append(next)
		_paths(b,next,path,result)
		path.pop_back()

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		printerr("FAIL: ",message)

static func _distance(a: Vector2i,b: Vector2i) -> int:
	return absi(a.x-b.x)+absi(a.y-b.y)

static func _inside(cell: Vector2i) -> bool:
	return cell.x>=0 and cell.y>=0 and cell.x<10 and cell.y<10
