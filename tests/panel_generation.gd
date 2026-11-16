extends SceneTree
const C=preload("res://game/catalog.gd")
const B=preload("res://game/battle.gd")
const T=preload("res://game/tuning.gd")
var checks=0
var failures=0
func _initialize() -> void:
	_run.call_deferred()
## REQ-034-S01、REQ-034-S02、REQ-034-S03、REQ-034-S04
func _run() -> void:
	_check(ResourceLoader.exists("res://game/panel_layout.gd"),"panel generator exists")
	if ResourceLoader.exists("res://game/panel_layout.gd"):
		var generator=load("res://game/panel_layout.gd").new()
		_test_count(generator)
		_test_repeat(generator)
		_test_spread(generator)
		_test_scarcity(generator)
		_test_link(generator)
	print("PANEL GENERATION: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
## REQ-034-S01
func _test_count(generator) -> void:
	var target=floori(100*T.new().get("PANEL_EFFECT_RATE")+0.5)
	for stage in C.stages():
		var before=stage.duplicate(true)
		var panels=generator.generate(stage,128)
		_check(panels.size()==target,"whole 100 cells form denominator "+stage.name)
		_check(panels.keys().all(func(cell):return Rect2i(0,0,10,10).has_point(cell) and not stage.spawns.has(cell) and cell!=stage.goal and cell!=stage.enemy_goal),"spawn and both goals excluded "+stage.name)
		var counts=[]
		for kind in ["SHIFT","LOCK","REVERSE"]:
			counts.append(panels.values().count(kind))
		_check(counts.max()-counts.min()<=1 and panels.values().all(func(kind):return kind in ["SHIFT","LOCK","REVERSE"]),"balanced complete type set")
		_check(stage==before,"source stage unchanged")
	var stage=C.stages()[0]
	_check(generator.generate(stage,0,0.005).size()==1 and generator.generate(stage,0,0.0049).is_empty(),"half-up rounding independently of exclusions")
## REQ-034-S02
func _test_repeat(generator) -> void:
	var stage=C.stages()[2]
	var before=generator.generate(stage,730)
	seed(8273)
	var expected=randi()
	seed(8273)
	_check(generator.generate(stage,730)==before and randi()==expected,"same seed reproduces without global RNG consumption")
	var rng=RandomNumberGenerator.new()
	rng.seed=119
	for i in range(30):
		rng.randi()
	_check(generator.generate(stage,730)==before,"unrelated RNG cannot affect layout")
## REQ-034-S03
func _test_spread(generator) -> void:
	var stage=C.stages()[0]
	var heat={}
	var signatures={}
	var neighbors=0
	for layout_seed in range(512):
		var panels=generator.generate(stage,layout_seed)
		signatures[str(panels)]=true
		var quadrants=[0,0,0,0]
		for cell in panels:
			heat[cell]=heat.get(cell,0)+1
			quadrants[int(cell.x/5)+2*int(cell.y/5)]+=1
			if panels.has(cell+Vector2i.RIGHT) or panels.has(cell+Vector2i.DOWN):
				neighbors+=1
		# 現在の4ステージの候補数では各区画の比例配分を丸めると5枚ずつとなる。
		var quarter=floori(100*T.new().get("PANEL_EFFECT_RATE")+0.5)/4.0
		_check(quadrants.all(func(q):return q==floori(quarter) or q==ceili(quarter)) and quadrants.reduce(func(total,q):return total+q,0)==floori(100*T.new().get("PANEL_EFFECT_RATE")+0.5),"coarse spread for seed "+str(layout_seed))
	_check(signatures.size()==512,"different seeds change actual coordinates and types")
	_check(heat.size()==96 and heat.values().min()>512*0.1 and heat.values().max()<512*0.35,"every eligible cell appears without gross selection bias: "+str([heat.size(),heat.values().min(),heat.values().max()]))
	_check(neighbors>0,"adjacent and clustered panels are allowed")
	print("PANEL HEAT: eligible ",heat.size()," / min ",heat.values().min()," / max ",heat.values().max()," / adjacent ",neighbors)
## REQ-034-S04
func _test_scarcity(generator) -> void:
	var stage=C.stages()[0]
	stage.spawns=[]
	for y in range(10):
		for x in range(10):
			if Vector2i(x,y) not in [Vector2i(8,9),Vector2i(9,9)]:
				stage.spawns.append(Vector2i(x,y))
	var panels=generator.generate(stage,22)
	_check(panels.size()==2 and panels.has(Vector2i(8,9)) and panels.has(Vector2i(9,9)),"scarcity fills exactly remaining cells, including empty quadrants")
	stage.spawns.append(Vector2i(8,9))
	stage.spawns.append(Vector2i(9,9))
	_check(generator.generate(stage,22).is_empty(),"no candidates yields empty layout")
## REQ-034-S02
func _test_link(generator) -> void:
	var battle=B.new()
	battle.call("start",2,C.player_builds(),730)
	var expected=generator.generate(C.stages()[2],730)
	_check(battle.panels==expected and battle.panel_seed==730,"runtime battle uses generated layout and retains seed")
	var before=battle.panels.duplicate(true)
	battle.path_click(Vector2i(4,4))
	battle.preview()
	battle.commit_path()
	battle.wait_turn()
	_check(battle.panels==before,"thinking and actions never regenerate layout")
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
