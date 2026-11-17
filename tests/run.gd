extends SceneTree

const M = preload("res://game/phase_math.gd")
const B = preload("res://tests/fixture_battle.gd")
const C = preload("res://game/catalog.gd")
const L = preload("res://game/collection.gd")
const T = preload("res://game/tuning.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	for method in get_method_list():
		if str(method.name).begins_with("test_"):
			call(method.name)
	print("PHASE TESTS: %d checks / %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _unit() -> Dictionary:
	return C.unit("01", "PLAYER", Vector2i(3,4), C.default_build())

## REQ-001-S01
func test_distribution() -> void:
	_check(M.valid_stats([96,1,1,1,1]), "96 boundary")
	for bad in [[0,25,25,25,25],[97,1,1,1,0],[19,20,20,20,20],[20.5,19.5,20,20,20]]:
		_check(not M.valid_stats(bad), "invalid distribution")

## REQ-001-S02
func test_serial() -> void:
	_check(C.serial("ARMS",[20,5,25,40,10]) == "ARMS-140519280A", "hex serial")
	_check(C.serial("ARMS",[20,5,25,40,10],"ISVLR") == "ARMS-140519280A-M-ISVLR", "mutant serial")

## REQ-002-S01
func test_hp() -> void:
	for pair in [[20,100.0],[1,25.0],[5,25.0],[10,50.0],[40,200.0]]:
		var u := _unit()
		u.core[0] = pair[0]
		_check(is_equal_approx(M.max_hp(u),pair[1]), "HP factor %s" % pair[0])

## REQ-003-S01
func test_shift() -> void:
	for row in [["NORMAL",0.0],["RESET",0.0],["CLOCKWISE",30.0],["COUNTERCLOCKWISE",330.0]]:
		var u := _unit()
		M.enter_panel(u,row[0])
		_check(u.gear_angle == 330.0 and u.arms_angle == 30.0 and u.get("core_angle",0)==row[1], "panel " + row[0])
		_check(M.sector(u,0,1).x == fposmod(72.0+row[1],360.0), "CORE sector follows actual angle")

## REQ-004-S01
func test_overlap() -> void:
	_check(is_equal_approx(M.overlap([Vector2(350,30),Vector2(0,30)]),20), "wrap intersection")
	_check(M.overlap([Vector2(0,10),Vector2(20,10)]) == 0, "disjoint")
	_check(M.overlap([Vector2(350,30),Vector2(0,30),Vector2(10,10)]) == 10, "triple wrap")

## REQ-005-S01
func test_sync() -> void:
	for pair in [[5,1.5],[20,3.0],[80,6.0]]:
		var u := _unit()
		for key in ["core","gear","arms"]:
			u[key][4] = pair[0]
		_check(is_equal_approx(M.tolerance(u),pair[1]), "LUK tolerance")
	var u := _unit()
	_check(M.sync(u,1).assisted == 2.0, "assisted saturation")
	_check(M.sync(u,1).factor == 2.0, "bell saturation")
	u.gear_angle=120.0
	u.arms_angle=240.0
	_check(M.sync(u,1).raw == 0.0 and M.sync(u,1).factor > 0.0, "no forced zero")

## REQ-006-S01
func test_singularity() -> void:
	var u := _unit()
	for key in ["core","gear","arms"]:
		u[key]=[20,10,30,20,20]
	_check(M.singularity(u), "exact narrow")
	u.arms_angle=0.001
	_check(not M.singularity(u), "tiny angle mismatch")
	u.arms_angle=0.0
	u.arms[1]=9
	_check(not M.singularity(u), "different width")
	for key in ["core","gear","arms"]:
		u[key]=[20,11,29,20,20]
	_check(not M.singularity(u), "11 threshold")

## REQ-007-S01
func test_effects() -> void:
	var u := _unit()
	_check(M.effect(u,u,"DAMAGE") == floori(T.BASE_DAMAGE*2.0/3.0), "independent damage formula")
	_check(M.effect(u,u,"HEAL") == floori(T.BASE_HEAL*2.0), "heal ignores RES")
	for key in ["core","gear","arms"]:
		u[key]=[20,10,30,20,20]
	var expected := floori(T.BASE_HEAL*0.5*2.0*5.0)
	_check(M.effect(u,u,"HEAL") == expected, "singularity final multiplier")

## REQ-007-S02
func test_heal_cap() -> void:
	var b = B.new()
	b.start(0,[C.default_build(),C.default_build()])
	b.units[1].pos=Vector2i(4,4)
	b.units[1].hp=95.0
	b.mode="CHOICE"
	_check(b.choose_skill(C.HEAL), "choose heal")
	_check(b.act(1), "heal action")
	_check(b.units[1].hp == 100.0, "cap at max")
	_check(not b.valid_target(0,1,C.HEAL), "cannot heal full target")
	b.units[1].hp=0.0
	_check(not b.valid_target(0,1,C.HEAL), "cannot revive")

## REQ-008-S01
func test_timeline() -> void:
	var b = B.new()
	var fast = C.default_build()
	fast.core=[5,5,5,80,5]
	b.start(0,[C.default_build(),fast])
	_check(b.actor == 1 and b.units[1].next_time == 50.0, "SPD80 first")
	b.units[1].next_time=100.0
	b.next_actor()
	_check(b.actor == 0, "stable tie")

## REQ-008-S02
func test_speed_change() -> void:
	var b=B.new()
	b.start(0,[C.default_build(),C.default_build()])
	b.units[0].core=[5,5,5,80,5]
	_check(b.units[0].next_time == 100.0, "scheduled time unchanged")
	b.mode="CHOICE"
	b.wait_turn()
	_check(b.units[0].next_time == 150.0, "new delay after end")

## REQ-009-S01
func test_paths() -> void:
	var b=B.new()
	b.start(0,[C.default_build(),C.default_build()])
	_check(not b.path_click(Vector2i(4,5)), "no diagonal")
	_check(not b.path_click(Vector2i(-1,4)), "no out of map")
	_check(b.path_click(Vector2i(4,4)), "step one")
	_check(b.path_click(Vector2i(5,4)), "step two")
	_check(not b.path_click(Vector2i(6,4)), "living occupancy")
	_check(b.path_click(Vector2i(5,5)), "step three")
	_check(b.path_click(Vector2i(4,5)), "passive fourth")
	_check(not b.path_click(Vector2i(4,6)), "movement limit")
	_check(b.path_click(Vector2i(4,4)) and b.path.size()==1, "truncate suffix")
	_check(b.path_click(Vector2i(3,4)) and b.path.is_empty(), "start clears path, no reentry")

## REQ-010-S01
func test_prediction() -> void:
	var b=B.new()
	b.start(0,[C.default_build(),C.default_build()])
	b.panels[Vector2i(4,4)]="NORMAL"
	b.panels[Vector2i(5,4)]="CLOCKWISE"
	b.path_click(Vector2i(4,4))
	b.path_click(Vector2i(5,4))
	var u=b.preview()
	_check(u.gear_angle == 300.0 and u.arms_angle == 60.0 and u.get("core_angle",0)==30.0, "path prediction")
	_check(b.units[0].gear_angle==0.0, "preview is pure")
	_check(b.commit_path(), "commit")
	_check(b.units[0].gear_angle==300.0 and b.units[0].arms_angle==60.0 and b.units[0].get("core_angle",0)==30.0 and b.mode=="CHOICE", "prediction equals committed")

## REQ-011-S01
func test_targets_back() -> void:
	var b=B.new()
	b.start(0,[C.default_build(),C.default_build()])
	b.path_click(Vector2i(4,4))
	b.path_click(Vector2i(5,4))
	b.commit_path()
	var pos=b.units[0].pos
	var angle=b.units[0].arms_angle
	_check(b.choose_skill(C.DAMAGE), "damage owned")
	_check(b.valid_target(0,2,C.DAMAGE), "adjacent enemy")
	_check(not b.valid_target(0,3,C.DAMAGE), "distant enemy")
	_check(not b.valid_target(0,1,C.DAMAGE), "wrong camp")
	b.back()
	_check(b.mode=="CHOICE" and b.units[0].pos==pos and b.units[0].arms_angle==angle, "BACK preserves movement")

## REQ-012-S01
func test_trapped_wait() -> void:
	var b=B.new()
	b.start(0,[C.default_build(),C.default_build()])
	_check(not b.wait_turn(), "must move")
	_check(b.movement(b.units[0])==T.BASE_MOVE+1,"passive movement")
	for p in [Vector2i(2,4),Vector2i(4,4),Vector2i(3,3),Vector2i(3,5)]:
		b.units.append(C.unit("X","ENEMY",p,C.default_build()))
	_check(b.trapped(),"trapped")
	_check(b.wait_turn(),"forced WAIT")

## REQ-013-S01
func test_objectives() -> void:
	for stage in range(4):
		var b=B.new()
		b.start(stage,[C.default_build(),C.default_build()])
		if stage==0:
			b.units[2].hp=0.0
			b.units[3].hp=0.0
		elif stage==1:
			b.units[2].hp=0.0
		else:
			b.units[2].pos=Vector2i(9,9)
			b.units[0].pos=C.stages()[stage].goal
		var event=["DEATH","DEATH","MOVE","END"][stage]
		if stage>=2:
			b.check_result("DEATH")
			_check(b.result.is_empty(),"goal timing")
		b.check_result(event)
		_check(b.result=="VICTORY","objective %d" % stage)

## REQ-013-S02
func test_defeat() -> void:
	var b=B.new()
	b.start(0,[C.default_build(),C.default_build()])
	b.units[0].hp=0.0
	b.units[1].hp=0.0
	_check(b.at(Vector2i(3,4)) == -1,"dead removed from map")
	b.check_result("DEATH")
	_check(b.result=="DEFEAT" and b.mode=="RESULT","defeat")

## REQ-014-S01
func test_builds() -> void:
	var l=L.new()
	var v=C.default_build()
	v.skills=[]
	v.class_name="REVERSE"
	_check(l.valid_build(v),"empty skills reverse")
	_check(l.valid_build(v.duplicate(true)),"shared equipment allowed")
	v.skills=[C.DAMAGE,C.DAMAGE]
	_check(not l.valid_build(v),"duplicate skill")
	v.skills=[]
	v.arms=[96,1,1,1,1]
	_check(not l.valid_build(v),"locked equipment")
	v=C.default_build()
	v.arms_mutation="VVVVV"
	_check(not l.valid_build(v),"invalid mutation")

## REQ-015-S01
func test_loot() -> void:
	var l=L.new()
	var rng=RandomNumberGenerator.new()
	rng.seed=187
	var mutant_seen=false
	var counts={}
	for i in range(180):
		var drops=l.roll_loot(rng)
		counts[drops.size()]=true
		_check(drops.size()<=2,"loot max")
		for d in drops:
			if d.has("stats"):
				_check(M.valid_stats(d.stats),"generated stats")
				if d.mutation!="NORMAL":
					mutant_seen=true
					_check(l.mutations.has(d.mutation),"mutation unlocked")
					_check(l.items[d.kind].has(C.serial(d.kind,d.stats)),"base unlocked")
	_check(mutant_seen and counts.size()==3,"random boundary coverage")

## REQ-015-S02
func test_duplicate_mutant() -> void:
	var l=L.new()
	var d={"kind":"ARMS","stats":[20,20,20,20,20],"mutation":"ISVLR"}
	_check(l.accept_drop(d),"existing base new mutation")
	_check(l.mutations.has("ISVLR"),"new mutation")
	_check(not l.accept_drop(d),"both duplicate rejected")

## REQ-016-S01
func test_save_roundtrip() -> void:
	var l=L.new()
	l.builds[0].class_name="REVERSE"
	l.stage_index=2
	var p="res://artifacts/runtime/test-save-%d.json" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/runtime"))
	_check(l.save_to(p).is_empty(),"save")
	l.builds[0].class_name="STANDARD"
	_check(l.load_from(p).is_empty(),"load")
	_check(l.stage_index==2 and l.builds[0].class_name=="REVERSE","restore content")
	_check(l.save_to(p).is_empty(),"save with backup")
	_check(not l.last_backup.is_empty() and FileAccess.file_exists(l.last_backup),"backup preserved")

## REQ-016-S02
func test_invalid_load() -> void:
	var l=L.new()
	var before=JSON.stringify(l.snapshot())
	_check(not l.load_from("res://artifacts/runtime/no-such-save.json").is_empty(),"missing")
	for value in ["{broken",'{"version":999}',JSON.stringify({"version":1,"builds":[]})]:
		var p="res://artifacts/runtime/invalid-test.json"
		var f=FileAccess.open(p,FileAccess.WRITE)
		f.store_string(value)
		f.close()
		_check(not l.load_from(p).is_empty(),"reject invalid")
		_check(JSON.stringify(l.snapshot())==before,"preserve state")

## REQ-022-S01
func test_deterministic_play() -> void:
	var a=B.new()
	var b=B.new()
	a.start(0,[C.default_build(),C.default_build()])
	b.start(0,[C.default_build(),C.default_build()])
	# 接続のfixtureを実ステージの難易度から独立させる。
	a.stage.victory=[{"type":"REACH","camp":"PLAYER","unit":"01","cell":Vector2i(5,4)}]
	b.stage.victory=a.stage.victory.duplicate(true)
	for cell in [Vector2i(4,4),Vector2i(5,4)]:
		a.path_click(cell)
		b.path_click(cell)
	a.commit_path()
	b.commit_path()
	_check(a.result=="VICTORY" and b.result=="VICTORY","reach full flow")
	_check(a.units==b.units,"deterministic states")

## REQ-005-S01
func test_partial_interference() -> void:
	var u := _unit()
	u.gear_angle=330.0
	u.arms_angle=30.0
	var info=M.sync(u,1)
	# 独立した円弧計算: 三重18度、ペア48/48/18度、最小幅72度。
	_check(is_equal_approx(info.raw,1.0/6.0),"raw overlap independently derived")
	_check(is_equal_approx(info.wave,25.0/72.0),"triple and pair weighted wave")
	var expected_assisted=0.1+1.9*pow(25.0/72.0,1.5)
	var expected_factor=0.1+1.9*exp(-pow(1.0-expected_assisted,2)/(2*0.6*0.6))
	_check(is_equal_approx(info.assisted,expected_assisted),"assisted power")
	_check(is_equal_approx(info.factor,expected_factor),"bell input ordering")
	u.core[4]=80
	u.gear[4]=80
	u.arms[4]=5
	_check(M.tolerance(u)==1.5,"minimum LUK is bottleneck")

## REQ-011-S01
func test_skill_limits() -> void:
	var b=B.new()
	b.start(0,[C.default_build(),C.default_build()])
	b.mode="CHOICE"
	_check(not b.choose_skill(C.MOVE),"passive never consumes action")
	_check(not b.choose_skill("ACTIVE_DAMAGE_DIAGONAL"),"undefined skill refused")
	b.units[0].skills=[]
	_check(not b.choose_skill(C.DAMAGE),"unowned skill refused")
	_check(b.wait_turn(),"empty skill build can WAIT")

## REQ-015-S02
func test_skill_unlock_and_distribution() -> void:
	var l=L.new()
	if not l.skills.has(C.MOVE):
		l.skills.append(C.MOVE)
	l.skills.erase(C.HEAL)
	var rng=RandomNumberGenerator.new()
	rng.seed=918
	var obtained=false
	for i in range(60):
		for drop in l.roll_loot(rng):
			if drop.has("skill"):
				_check(drop.skill==C.HEAL,"only locked skill can drop")
				obtained=true
	_check(obtained and l.skills.has(C.HEAL),"skill acquisition works")
	_check(not l.accept_drop({"skill":C.HEAL}),"skill duplicate reroll candidate")

## REQ-013-S03
func test_stage_specific_defeat_and_occupant() -> void:
	var b=B.new()
	b.start(0,[C.default_build(),C.default_build()])
	b.stage.defeat=[{"type":"REACH","camp":"ENEMY","unit":"A","cell":Vector2i(6,5)}]
	b.actor=2
	b.units[2].pos=Vector2i(6,5)
	b.check_result("END")
	_check(b.result.is_empty(),"enemy REACH not tested on END")
	b.check_result("MOVE")
	_check(b.result=="DEFEAT","configured enemy REACH defeat")
	b.start(0,[C.default_build(),C.default_build()])
	b.stage.victory=[{"type":"OCCUPY","camp":"PLAYER","unit":"02","cell":Vector2i(5,5)}]
	b.units[0].pos=Vector2i(5,5)
	b.check_result("END")
	_check(b.result.is_empty(),"wrong PLAYER cannot occupy for 02")
	b.units[0].pos=Vector2i(4,5)
	b.units[1].pos=Vector2i(5,5)
	b.check_result("MOVE")
	_check(b.result.is_empty(),"occupation not tested on MOVE")
	b.check_result("END")
	_check(b.result=="VICTORY","specific 02 occupation")
	b.start(0,[C.default_build(),C.default_build()])
	b.stage.victory=[{"type":"TARGET","camp":"ENEMY","unit":"A"}]
	b.stage.defeat=[{"type":"TARGET","camp":"PLAYER","unit":"02"}]
	b.units[1].hp=0.0
	b.units[2].hp=0.0
	b.check_result("DEATH")
	_check(b.result=="DEFEAT","simultaneous defeat priority")

## REQ-016-S02
func test_complete_corrupt_save() -> void:
	var l=L.new()
	var original=JSON.stringify(l.snapshot())
	for field in ["bad_stats","battle_fields","bad_mutation","bad_skill"]:
		var data=l.snapshot()
		if field=="bad_stats":
			data.builds[0].core=[0,25,25,25,25]
		elif field=="battle_fields":
			data.builds[0].gear_angle="corrupt"
		elif field=="bad_mutation":
			data.mutations.append("VIRSL")
		else:
			data.skills.append("UNKNOWN")
		var p="res://artifacts/runtime/complete-invalid.json"
		var f=FileAccess.open(p,FileAccess.WRITE)
		f.store_string(JSON.stringify(data))
		f.close()
		_check(not l.load_from(p).is_empty(),"complete corrupt save rejected: "+field)
		_check(JSON.stringify(l.snapshot())==original,"atomic rejection: "+field)
