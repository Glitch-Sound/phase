extends SceneTree
const C=preload("res://game/catalog.gd")
const B=preload("res://game/battle.gd")
const L=preload("res://game/collection.gd")
const M=preload("res://game/phase_math.gd")
var checks=0
var failures=0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_first_turn()
	_test_skill_progress()
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	_test_rewards(game)
	_test_equipment(game)
	_test_chips(game)
	game.queue_free()
	await process_frame
	print("REVIEW REGRESSIONS: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)

## REQ-023-S01
func _test_first_turn() -> void:
	var builds=[C.default_build(),C.default_build(),L.new().builds[0]]
	builds[0].core=[1,1,1,96,1]
	builds[1].core=[1,96,1,1,1]
	for stage in range(4):
		for build_index in range(builds.size()):
			var b=B.new()
			b.start(stage,[builds[build_index],builds[build_index]])
			var routes=[]
			_paths(b,b.units[b.actor].pos,[],routes)
			var endings=0
			for route in routes:
				var trial=B.new()
				trial.start(stage,[builds[build_index],builds[build_index]])
				for cell in route:
					trial.path_click(cell)
				trial.commit_path()
				if not trial.result.is_empty():
					endings+=1
					continue
				var waiting=_copy_battle(trial)
				waiting.wait_turn()
				if not waiting.result.is_empty():
					endings+=1
				for target in range(trial.units.size()):
					if trial.valid_target(trial.actor,target,C.DAMAGE):
						var attack=_copy_battle(trial)
						attack.choose_skill(C.DAMAGE)
						attack.act(target)
						if not attack.result.is_empty():
							endings+=1
			_check(endings==0,"no first-action result: stage %d / build %d / endings %d" % [stage,build_index,endings])
		if stage>=2:
			var b=B.new()
			b.start(stage,[builds[0],builds[0]])
			var needed=99
			for unit in [0,1] if stage==3 else [0]:
				var p: Vector2i=b.units[unit].pos
				var distance=absi(p.x-b.stage.goal.x)+absi(p.y-b.stage.goal.y)
				needed=mini(needed,ceili(distance/float(b.movement(b.units[unit]))))
			var earliest=needed*M.delay(b.units[0])
			_check(earliest>minf(b.units[2].next_time,b.units[3].next_time),"enemy has an opportunity before fastest goal")
			_check(b.at(b.stage.goal)>=2,"goal starts defended")

## REQ-026-S01
func _test_skill_progress() -> void:
	var l=L.new()
	_check(l.skills.has(C.DAMAGE) and l.skills.has(C.HEAL) and not l.skills.has(C.MOVE),"new game leaves MOVE collectible")
	for build in l.builds:
		_check(not build.skills.has(C.MOVE),"new build cannot equip locked MOVE")
	var rng=RandomNumberGenerator.new()
	rng.seed=918
	for i in range(60):
		l.roll_loot(rng)
	_check(l.skills.has(C.MOVE),"MOVE can be collected")
	for index in range(2):
		l.builds[index].skills.append(C.MOVE)
		_check(l.valid_build(l.builds[index]),"collected MOVE is shared")
	_test_legacy()

## REQ-026-S02
func _test_legacy() -> void:
	var l=L.new()
	var data=l.snapshot()
	data.skills=[C.DAMAGE,C.HEAL,C.MOVE]
	data.builds=[C.default_build(),C.default_build()]
	var p="res://artifacts/runtime/review-legacy.json"
	var f=FileAccess.open(p,FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	_check(l.load_from(p).is_empty(),"legacy version 1 accepted")
	_check(l.skills.size()==3 and l.builds[0].skills.has(C.MOVE),"legacy unlocks preserved")

## REQ-015-S03
func _test_rewards(game: Control) -> void:
	game.build_open=false
	game.battle.result="VICTORY"
	game.battle.mode="RESULT"
	game.loot_rng.seed=187
	game._result()
	var before=JSON.stringify(game.collection.snapshot())
	var drops=game.drops.duplicate(true)
	var rng_state=game.loot_rng.state
	game._result()
	_check(JSON.stringify(game.collection.snapshot())==before and game.drops==drops and game.loot_rng.state==rng_state,"same result cannot reroll rewards")
	game.battle.result=""
	game.battle.mode="MOVE"
	game._result()
	_check(JSON.stringify(game.collection.snapshot())==before and game.loot_rng.state==rng_state,"no rewards outside RESULT")

## REQ-024-S01
func _test_equipment(game: Control) -> void:
	if not game.has_method("_equipment_comparison"):
		_check(false,"decimal equipment comparison exists")
		return
	var comparison=game._equipment_comparison([25,15,20,30,10],[20,20,20,20,20])
	_check(comparison=="VIT 25 (+5)\nINF 15 (-5)\nRES 20 (0)\nSPD 30 (+10)\nLUK 10 (-10)","all five values and signed deltas")

## REQ-025-S01
func _test_chips(game: Control) -> void:
	if not game.has_method("_effect_chip_rect"):
		_check(false,"effect chip layout exists")
		return
	for cell in [Vector2i(6,4),Vector2i(2,9),Vector2i(0,0)]:
		var rect: Rect2=game._effect_chip_rect(cell)
		var containing=Rect2(game.BOARD+Vector2(cell)*70,Vector2(70,70))
		_check(containing.encloses(rect),"effect chip stays in its cell")
		var measured=game.mono.get_string_size("-420",HORIZONTAL_ALIGNMENT_LEFT,-1,16)
		_check(measured.x<=rect.size.x and measured.y<=rect.size.y,"full signed value fits the chip")

func _paths(b: RefCounted, cell: Vector2i, path: Array, result: Array) -> void:
	if not path.is_empty():
		result.append(path.duplicate())
	if path.size()>=b.movement(b.units[b.actor]):
		return
	for direction in B.DIRS:
		var next: Vector2i=cell+direction
		if next.x<0 or next.y<0 or next.x>=10 or next.y>=10 or b.at(next)>=0 or path.has(next):
			continue
		path.append(next)
		_paths(b,next,path,result)
		path.pop_back()

func _copy_battle(source: RefCounted) -> RefCounted:
	var result=B.new()
	result.units=source.units.duplicate(true)
	result.stage=source.stage.duplicate(true)
	result.panels=source.panels.duplicate(true)
	result.actor=source.actor
	result.mode=source.mode
	return result

func _check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
