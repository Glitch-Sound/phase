extends SceneTree
const C=preload("res://game/catalog.gd")
const B=preload("res://tests/fixture_battle.gd")
const RUNTIME_B=preload("res://game/battle.gd")
const M=preload("res://game/phase_math.gd")
var failures=0

func _initialize() -> void:
	var report={"mutual":[]}
	var first=_mutual(1.8,160)
	var second=_mutual(1.8,160)
	report.mutual.append(first)
	_check(first==second,"mutual play deterministic")
	report.mutual.append(_mutual(0.88,160))
	report.mutual.append(_mutual(10.0,160))
	report.native_replay=_mutual(1.4,160,true)
	print("NATIVE REPLAY: ",JSON.stringify(report.native_replay.actions)," / ",report.native_replay.result," / ",report.native_replay.turns)
	var file=FileAccess.open("res://artifacts/contested-play.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	for row in report.mutual:
		print("MUTUAL PLAY: heal weight %.2f / %s / %d turns / %s" % [row.heal_weight,row.result if not row.result.is_empty() else "UNFINISHED",row.turns,JSON.stringify(row.actions)])
	print("CONTESTED PLAY: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)

## REQ-023-S03
func _mutual(heal_weight: float, limit: int, roles: bool=false, layout_seed: Variant=null) -> Dictionary:
	var b=B.new() if layout_seed==null else RUNTIME_B.new()
	b.start(0,C.player_builds() if roles else [C.starter_build(),C.starter_build()],0 if layout_seed==null else int(layout_seed))
	var actions={"PLAYER":{"DAMAGE":0,"HEAL":0,"WAIT":0},"ENEMY":{"DAMAGE":0,"HEAL":0,"WAIT":0}}
	var commands=[]
	var state_counts={}
	var repeated_states=0
	# 上限は検査の実行量だけを制限し、決着までの手数を合否へ固定しない。
	for hand in range(limit):
		if not b.result.is_empty(): break
		var before=[b.turn,b.actor,b.units[b.actor].next_time]
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
		_check(_step_contract(b,before),"mutual action preserves HP bounds and advances exactly one hand or ends")
		var state=[]
		for u in b.units:
			state.append([u.id,str(u.pos),u.hp,u.core_angle,u.gear_angle,u.arms_angle])
		var key=JSON.stringify([b.actor,state])
		state_counts[key]=state_counts.get(key,0)+1
		if state_counts[key]>1:
			repeated_states+=1
	return {"roles":roles,"heal_weight":heal_weight,"result":b.result,"turns":b.turn,"actions":actions,"repeated_states":repeated_states,"history":b.history,"commands":commands}

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

## REQ-008-S01、REQ-011-S01、REQ-012-S01
## 再生の入口では基本ルールへの接続だけを確かめ、戦術の勝敗を固定しない。
static func _step_contract(b, before: Array) -> bool:
	for unit in b.units:
		if not is_finite(unit.hp) or unit.hp<0 or unit.hp>unit.max_hp:
			return false
	if not b.result.is_empty():
		return b.result in ["VICTORY","DEFEAT"] and b.mode=="RESULT" and b.turn==before[0]
	return b.mode=="MOVE" and b.turn==before[0]+1 and b.units[before[1]].next_time>before[2] and b.actor>=0 and b.units[b.actor].hp>0
