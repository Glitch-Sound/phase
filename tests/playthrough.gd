extends SceneTree
const B=preload("res://tests/fixture_battle.gd")
const C=preload("res://game/catalog.gd")
const M=preload("res://game/phase_math.gd")
var failed=false

func _initialize() -> void:
	var player=_play("PLAYER")
	var repeat=_play("PLAYER")
	var enemy=_play("ENEMY")
	_assert(player.result=="VICTORY","PLAYER full battle completes")
	_assert(enemy.result=="DEFEAT","ENEMY full battle completes")
	_assert(player==repeat,"full deterministic replay matches")
	var f=FileAccess.open("res://artifacts/playthrough.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"player":player,"enemy":enemy},"\t"))
	f.close()
	print("FULL BATTLE REPLAY: player %d turns / enemy %d turns / %s" % [player.turns,enemy.turns,"FAIL" if failed else "PASS"])
	quit(1 if failed else 0)

func _play(attacking_camp: String) -> Dictionary:
	var b=B.new()
	b.start(0,[C.default_build(),C.default_build()])
	var total_damage=0
	while b.result.is_empty() and b.turn<160:
		var choices=[]
		_paths(b,b.units[b.actor].pos,[],choices)
		var best=[]
		var best_value=-INF
		for path in choices:
			var u=b.units[b.actor].duplicate(true)
			for cell in path:
				M.enter_panel(u,b.panels.get(cell,"NORMAL"))
				u.pos=cell
			var damage=0
			var distance=100
			for other in b.units:
				if other.hp>0 and other.camp!=u.camp:
					var d=absi(u.pos.x-other.pos.x)+absi(u.pos.y-other.pos.y)
					distance=mini(distance,d)
					if d==1:
						damage=maxi(damage,M.effect(u,other,"DAMAGE"))
			var value=damage*10.0 if damage>0 else -distance*100.0
			value+=M.sync(u,2).factor*0.1-path.size()*0.001
			if value>best_value:
				best_value=value
				best=path
		if best.is_empty():
			_assert(b.trapped() and b.wait_turn(),"trapped fallback")
			continue
		for cell in best:
			_assert(b.path_click(cell),"generated path accepted")
		_assert(b.commit_path(),"commit path")
		var target=-1
		if b.units[b.actor].camp==attacking_camp:
			for i in range(b.units.size()):
				if b.valid_target(b.actor,i,C.DAMAGE):
					if target<0 or b.units[i].hp<b.units[target].hp:
						target=i
		if target>=0:
			_assert(b.choose_skill(C.DAMAGE),"active selection")
			_assert(b.act(target),"active execution")
			total_damage+=b.last_effect.amount
		else:
			_assert(b.wait_turn(),"manual WAIT column")
	return {"result":b.result,"turns":b.turn,"damage":total_damage,"history":b.history}

func _paths(b: RefCounted, cell: Vector2i, path: Array, result: Array) -> void:
	if not path.is_empty():
		result.append(path.duplicate())
	if path.size()>=b.movement(b.units[b.actor]):
		return
	for d in B.DIRS:
		var next: Vector2i=cell+d
		if next.x<0 or next.y<0 or next.x>=10 or next.y>=10 or b.at(next)>=0 or path.has(next):
			continue
		path.append(next)
		_paths(b,next,path,result)
		path.pop_back()

func _assert(ok: bool, message: String) -> void:
	if not ok:
		failed=true
		printerr("FAIL: ",message)
