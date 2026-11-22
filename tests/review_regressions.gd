extends SceneTree
const C=preload("res://game/catalog.gd")
const B=preload("res://tests/fixture_battle.gd")
const L=preload("res://game/collection.gd")
var checks=0
var failures=0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_skill_progress()
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
		for unit in battle.units:unit.hp=unit.max_hp if unit.camp=="PLAYER" else 0
		battle.check_result("DEATH")
		_check(battle.result=="DEFEAT" and battle.mode=="RESULT","later opposite condition cannot replace a final result")
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

func _check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
