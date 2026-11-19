extends SceneTree
const C=preload("res://game/catalog.gd")
const B=preload("res://tests/fixture_battle.gd")
const L=preload("res://game/collection.gd")
const M=preload("res://game/phase_math.gd")
var checks=0
var failures=0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_first_turn()
	_test_skill_progress()
	_test_breach_runner()
	_test_surviving_runner()
	_test_result_priority()
	var game=load("res://tests/fixture_main.gd").new()
	root.add_child(game)
	await process_frame
	_test_rewards(game)
	_test_equipment(game)
	_test_chips(game)
	game.queue_free()
	await process_frame
	print("REVIEW REGRESSIONS: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)

## REQ-023-S04
func _test_breach_runner() -> void:
	# 実際の移動と攻撃を通し、01の撃破だけで直ちに終わることを確かめる。
	var battle=B.new()
	battle.start(2,C.player_builds())
	battle.actor=2
	battle.units[2].pos=Vector2i(5,4)
	battle.units[0].hp=1.0
	_check(battle.path_click(Vector2i(4,4)) and battle.commit_path(),"fatal attack setup uses a legal move")
	var old_turn=battle.turn
	var old_time=battle.units[2].next_time
	_check(battle.choose_skill(C.DAMAGE) and battle.act(0),"enemy attacks runner")
	_check(battle.units[0].hp==0 and battle.units[1].hp>0 and battle.units[2].hp>0 and battle.units[3].hp>0,"only runner is defeated")
	_check(battle.result=="DEFEAT" and battle.mode=="RESULT","runner death ends BREACH immediately")
	_check(battle.turn==old_turn and battle.actor==2 and battle.units[2].next_time==old_time,"fatal action does not advance the timeline")
	_check(not battle.wait_turn() and not battle.path_click(battle.units[battle.actor].pos+Vector2i.RIGHT) and not battle.choose_skill(C.DAMAGE),"result rejects later commands")
	for enemy_alive in [true,false]:
		var snapshot=B.new()
		snapshot.start(2,C.player_builds())
		snapshot.units[0].hp=0.0
		if not enemy_alive:
			snapshot.units[2].hp=0.0
			snapshot.units[3].hp=0.0
		snapshot.check_result("DEATH")
		_check(snapshot.units[1].hp>0 and snapshot.result=="DEFEAT" and snapshot.mode=="RESULT","runner death loses even with 02 alive and enemy_alive=%s" % enemy_alive)

## REQ-023-S05
func _test_surviving_runner() -> void:
	# 02の撃破や敵全滅だけでは、01の到達条件は達成も不能にもならない。
	var survivor=B.new()
	survivor.start(2,C.player_builds())
	survivor.units[1].hp=0.0
	survivor.check_result("DEATH")
	_check(survivor.result.is_empty(),"02 death alone does not lose BREACH")
	survivor.units[2].hp=0.0
	survivor.units[3].hp=0.0
	survivor.check_result("DEATH")
	_check(survivor.result.is_empty() and survivor.mode=="MOVE","enemy elimination with runner alive still requires REACH")
	survivor.actor=0
	survivor.units[0].pos=Vector2i(8,0)
	_check(survivor.path_click(Vector2i(9,0)) and survivor.commit_path(),"surviving runner can reach after enemy elimination")
	_check(survivor.result=="VICTORY" and survivor.mode=="RESULT","surviving runner completes BREACH")

## REQ-013-S04
func _test_result_priority() -> void:
	# DEATH: SEVERANCEの両TARGET、全滅戦の両ELIMINATEが同時に成立する境界。
	for stage_index in [0,1]:
		var battle=B.new()
		battle.start(stage_index,C.player_builds())
		for index in [0,1,2,3] if stage_index==0 else [0,2]:
			battle.units[index].hp=0.0
		battle.check_result("DEATH")
		_check(battle.result=="DEFEAT" and battle.mode=="RESULT","simultaneous DEATH conditions prefer defeat: %d" % stage_index)
	# MOVE: 同じ到達を両条件へ設定した共通判定のfixture。
	var reach=B.new()
	reach.start(2,C.player_builds())
	reach.units[2].pos=Vector2i(8,1)
	reach.units[0].pos=Vector2i(8,0)
	reach.stage.defeat.append({"type":"REACH","camp":"PLAYER","unit":"01","cell":Vector2i(9,0)})
	_check(reach.path_click(Vector2i(9,0)) and reach.commit_path(),"simultaneous REACH uses legal commit")
	_check(reach.result=="DEFEAT" and reach.mode=="RESULT","simultaneous MOVE conditions prefer defeat")
	# END: ANCHORの別々の勝敗目標を両陣営が占有する実条件。
	var occupy=B.new()
	occupy.start(3,C.player_builds())
	occupy.units[2].pos=Vector2i(0,9)
	occupy.units[0].pos=Vector2i(7,0)
	_check(occupy.path_click(Vector2i(8,0)) and occupy.commit_path() and occupy.result.is_empty(),"both occupations wait until turn end")
	_check(occupy.wait_turn() and occupy.result=="DEFEAT" and occupy.mode=="RESULT","simultaneous END conditions prefer defeat")
	occupy.units[2].pos=Vector2i(1,9)
	occupy.check_result("END")
	_check(occupy.result=="DEFEAT" and occupy.mode=="RESULT","later victory-only check cannot replace the result")

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
	_test_saved_unlocks()

## REQ-026-S02
func _test_saved_unlocks() -> void:
	var l=L.new()
	var data=l.snapshot()
	data.skills=[C.DAMAGE,C.HEAL,C.MOVE]
	data.builds=[C.default_build(),C.default_build(),C.default_build()]
	var p="res://artifacts/runtime/review-legacy.json"
	var f=FileAccess.open(p,FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	_check(l.load_from(p).is_empty(),"current save with collected skills accepted")
	_check(l.skills.size()==3 and l.builds[0].skills.has(C.MOVE),"saved unlocks preserved")

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
	_check(comparison=="CURRENT / VIT 20   INF 20   RES 20   SPD 20   LUK 20\nCANDIDATE / VIT 25   INF 15   RES 20   SPD 30   LUK 10","all five current and candidate values, without bracket deltas")

## REQ-025-S01
func _test_chips(game: Control) -> void:
	if not game.has_method("_effect_chip_rect"):
		_check(false,"effect chip layout exists")
		return
	for cell in [Vector2i(6,4),Vector2i(2,9),Vector2i(0,0)]:
		var rect: Rect2=game._effect_chip_rect(cell)
		var containing=Rect2(game.BOARD+Vector2(cell)*game.CELL,Vector2.ONE*game.CELL)
		_check(containing.encloses(rect),"effect chip stays in its cell")
		var measured=game.mono.get_string_size("-420",HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(16*game.BOARD_SCALE))
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
