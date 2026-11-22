extends SceneTree
const C=preload("res://game/catalog.gd")
const B=preload("res://game/battle.gd")
const L=preload("res://game/collection.gd")
const TL=preload("res://ui/timeline.gd")
const CPU=preload("res://game/cpu_policy.gd")
var checks=0
var failures=0
func _initialize() -> void:
	_initial()
	_deployment()
	if C.player_builds().size()==3:
		_storage()
		_progression()
	print("THREE UNIT SQUADS: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
## REQ-043-S01
func _initial() -> void:
	var builds=C.player_builds()
	_check(builds.size()==3,"new game has three independent PLAYER builds")
	var b=B.new();b.start(0,builds)
	_check(b.units.map(func(u):return u.id)==["01","02","03","A","B","C"],"all six stable IDs are ordered")
	if b.units.size()!=6:return
	var positions=[]
	for u in b.units:
		_check(Rect2i(0,0,10,10).has_point(u.pos) and not positions.has(u.pos),"six unique initial cells")
		positions.append(u.pos)
	for i in range(3):
		_check(b.units[i+3].pos==Vector2i(9-b.units[i].pos.x,b.units[i].pos.y),"standard deployment is mirrored")
	for u in b.units:u.next_time=100.0
	b.next_actor()
	_check(b.timeline(6).map(func(e):return e.index)==[0,1,2,3,4,5],"simultaneous turns use full stable order")
## REQ-043-S02
func _storage() -> void:
	var l=L.new()
	l.builds[2].class_name="REVERSE"
	var path="res://artifacts/runtime/three-unit-save.json"
	_check(l.save_to(path).is_empty(),"three builds can be saved in isolated storage")
	var loaded=L.new()
	_check(loaded.load_from(path).is_empty() and loaded.builds.size()==3 and loaded.builds[2].class_name=="REVERSE","third build survives save/load")
	var bad=loaded.snapshot();bad.builds.resize(1)
	var f=FileAccess.open("res://artifacts/runtime/three-unit-invalid.json",FileAccess.WRITE);f.store_string(JSON.stringify(bad));f.close()
	var before=loaded.snapshot()
	_check(not loaded.load_from("res://artifacts/runtime/three-unit-invalid.json").is_empty() and loaded.snapshot()==before,"wrong squad size is rejected without mutation")
## REQ-043-S03
func _progression() -> void:
	var b=B.new();b.start(0,C.player_builds())
	b.units[3].hp=0.0;b.units[4].hp=0.0
	b.check_result("DEATH")
	_check(b.result.is_empty(),"C alive prevents premature enemy elimination")
	b.actor=5;b.mode="MOVE"
	var command=CPU.new().choose(b)
	_check(not command.get("path",[]).is_empty() and CPU.new()._simulate(b,command)!=null,"CPU produces a move for C")
	b.units[5].hp=0.0;b.check_result("DEATH")
	_check(b.result=="VICTORY" and b.timeline(6).all(func(e):return e.index<3),"all enemies required; defeated units leave schedule")
	_layout()
## REQ-043-S04
func _layout() -> void:
	var b=B.new();b.start(0,C.player_builds())
	var view=TL.layout(b.units,b.actor,TL.rows(b))
	_check(view.cards.size()==6,"timeline has six current states")
	for card in view.cards:
		_check((card.center.x<view.events[0].point.x)==(card.unit.camp=="PLAYER"),"timeline sides follow camp, including 3 and A")
	for camp in ["PLAYER","ENEMY"]:
		var cards=view.cards.filter(func(c):return c.unit.camp==camp)
		cards.sort_custom(func(a,z):return a.center.y<z.center.y)
		_check(not cards[0].rect.intersects(cards[1].rect) and not cards[1].rect.intersects(cards[2].rect),"three status cards never overlap")
## REQ-060-S01、REQ-060-S02、REQ-060-S03
func _deployment() -> void:
	var tuning=load("res://game/tuning.gd").get_script_constant_map()
	var size=tuning.get("SPAWN_GROUP_SIZE",Vector2i(10,10));var gap=tuning.get("SPAWN_CAMP_GAP",0)
	for stage_index in range(4):
		var signatures={};var consistent=true;var safe=true;var objectives=true
		for seed_value in range(64):
			var b=B.new();b.start(stage_index,C.player_builds(),seed_value)
			var positions=b.units.map(func(u):return u.pos);signatures[str(positions)]=true
			var second=B.new();second.start(stage_index,C.player_builds(),seed_value)
			consistent=consistent and b.units==second.units and b.panels==second.panels
			var unique={}
			for u in b.units:
				unique[u.pos]=true
				safe=safe and Rect2i(0,0,10,10).has_point(u.pos) and not b.panels.has(u.pos) and b.DIRS.any(func(d):return Rect2i(0,0,10,10).has_point(u.pos+d) and b.at(u.pos+d)<0)
			safe=safe and unique.size()==6
			for offset in [0,3]:
				var group=positions.slice(offset,offset+3);var xs=group.map(func(v):return v.x);var ys=group.map(func(v):return v.y)
				safe=safe and xs.max()-xs.min()<size.x and ys.max()-ys.min()<size.y
			for i in range(3):
				for j in range(3,6):safe=safe and abs(positions[i].x-positions[j].x)+abs(positions[i].y-positions[j].y)>=gap
			b.check_result("END");objectives=objectives and b.result.is_empty()
			if b.stage.goal.x>=0:
				objectives=objectives and positions[3]==b.stage.goal
				for i in range(3):objectives=objectives and abs(positions[i].x-b.stage.goal.x)+abs(positions[i].y-b.stage.goal.y)>b.T.BASE_MOVE+1
			var original=b.stage.spawns.duplicate();var panels=b.panels.duplicate(true);b.wait_turn()
			consistent=consistent and b.stage.spawns==original and b.panels==panels
		_check(consistent and signatures.size()>1,"same seed repeats; different seeds vary without regeneration: stage "+str(stage_index))
		_check(safe,"seeded camps are compact, separated, unique, panel-free and movable: stage "+str(stage_index))
		_check(objectives,"guarded goals and initial nonterminal state remain valid: stage "+str(stage_index))
	seed(919);var expected=randi();seed(919);var b=B.new();b.start(0,C.player_builds(),75)
	_check(randi()==expected,"deployment does not consume the global random stream")
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
