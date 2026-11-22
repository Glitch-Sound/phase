extends SceneTree
const B=preload("res://game/battle.gd")
const C=preload("res://game/catalog.gd")
const M=preload("res://game/phase_math.gd")
const T=preload("res://game/tuning.gd")
const L=preload("res://game/collection.gd")
const SWAP="ACTIVE_SWAP_ADJACENT"
const PUSH="ACTIVE_PUSH_ADJACENT"
const GUARD="ACTIVE_GUARD_SELF"
const IGNORE="PASSIVE_IGNORE_PANEL_SELF"
var checks=0
var failures=0
func _initialize() -> void:
	for skill in [SWAP,PUSH,GUARD,IGNORE]:
		_check(C.SKILLS.has(skill),"new catalog item "+skill)
	_passive()
	if [SWAP,PUSH,GUARD,IGNORE].all(func(skill):return C.SKILLS.has(skill)):
		_swap()
		_push()
		_guard()
		_goals()
	_inventory()
	print("UTILITY SKILLS: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
## REQ-003-S04、REQ-012-S02
func _passive() -> void:
	for panel in ["NORMAL","RESET","CLOCKWISE","COUNTERCLOCKWISE"]:
		var b=_battle(IGNORE)
		b.mode="MOVE"
		b.units[0].skills=[IGNORE,C.MOVE]
		b.units[0].core_angle=90.0
		b.units[0].initial_core_angle=15.0
		b.panels={Vector2i(5,4):panel}
		b.units[1].pos=Vector2i.ZERO
		var before=b.units.duplicate(true)
		_check(b.path_click(Vector2i(5,4)),"ignore passive leaves ordinary legal movement "+panel)
		var predicted=b.preview()
		_check([predicted.core_angle,predicted.gear_angle,predicted.arms_angle]==[90.0,330.0,30.0] and b.units==before,"ignore affects only CORE; preview is read-only "+panel)
		_check(b.commit_path() and b.units[0].core_angle==predicted.core_angle and b.units[0].gear_angle==predicted.gear_angle and b.units[0].arms_angle==predicted.arms_angle,"passive prediction connects to committed entry "+panel)
		_check(b.reselect_path() and b.units==before and b.path==[Vector2i(5,4)] and b.turn==1,"reselect restores exact original with the passive "+panel)
## REQ-037-S01、REQ-037-S02
func _swap() -> void:
	var b=_battle(SWAP)
	b.units[0].core_angle=90.0
	b.units[1].core_angle=60.0
	b.units[1].initial_core_angle=15.0
	b.units[1].guard_active=true
	b.panels={Vector2i(4,4):"RESET",Vector2i(5,4):"CLOCKWISE"}
	var before=b.units.duplicate(true)
	_check(b.choose_skill(SWAP) and b.valid_target(0,1,SWAP),"SWAP accepts a full-HP orthogonal ally")
	var preview=b.action_preview(1)
	_check(b.units==before and preview.units[0].pos==Vector2i(5,4) and preview.units[1].pos==Vector2i(4,4),"SWAP preview changes only the independent copy")
	_check([preview.units[0].core_angle,preview.units[1].core_angle,preview.units[0].gear_angle,preview.units[1].arms_angle]==[120.0,15.0,330.0,30.0],"both swap destinations receive exactly one entry")
	_check(b.act(1) and b.units[0].pos==preview.units[0].pos and b.units[1]==preview.units[1],"SWAP commits the preview and preserves the displaced ally clock")
	_check(b.units[0].hp==before[0].hp and b.units[1].hp==before[1].hp and b.units[1].guard_active and b.units[0].moved==before[0].moved and b.turn==2,"SWAP deals no damage, preserves guard and movement count, completes once")
	b=_battle(SWAP)
	b.units[1].skills=[IGNORE]
	b.units[1].core_angle=60.0
	b.panels={Vector2i(4,4):"RESET",Vector2i(5,4):"CLOCKWISE"}
	b.choose_skill(SWAP)
	preview=b.action_preview(1)
	_check(preview.units[0].core_angle==30.0 and preview.units[1].core_angle==60.0,"forced entry honors only the displaced unit's own ignore passive")
	b=_battle(SWAP)
	_check(not b.valid_target(0,0,SWAP) and not b.valid_target(0,2,SWAP),"SWAP excludes self and enemy")
	for position in [Vector2i(5,5),Vector2i(6,4)]:
		b.units[1].pos=position
		_check(not b.valid_target(0,1,SWAP),"SWAP rejects diagonal or nonadjacent ally")
	b.units[1].pos=Vector2i(5,4)
	b.units[1].hp=0
	_check(not b.valid_target(0,1,SWAP),"SWAP excludes defeated ally")
	_check(b.choose_skill(SWAP),"equipped SWAP can enter target selection")
	var state=_state(b)
	_check(not b.act(1) and _state(b)==state,"invalid SWAP has no side effects")
	b.back()
	b.units[0].skills=[]
	_check(not b.choose_skill(SWAP),"unequipped SWAP cannot be selected")
## REQ-038-S01、REQ-038-S02
func _push() -> void:
	var b=_battle(PUSH)
	b.units[1].pos=Vector2i.ZERO
	b.units[2].pos=Vector2i(5,4)
	b.units[2].core_angle=90.0
	b.units[2].guard_active=true
	b.panels={Vector2i(6,4):"COUNTERCLOCKWISE"}
	var before=b.units.duplicate(true)
	_check(b.choose_skill(PUSH) and b.valid_target(0,2,PUSH),"PUSH accepts an adjacent enemy with an empty landing")
	var predicted=b.action_preview(2)
	_check(predicted.units[2].pos==Vector2i(6,4) and [predicted.units[2].core_angle,predicted.units[2].gear_angle,predicted.units[2].arms_angle]==[60.0,330.0,30.0] and b.units==before,"PUSH predicts the exact landing and one entry without mutation")
	_check(b.act(2) and b.units[2]==predicted.units[2] and b.units[2].hp==before[2].hp and b.units[2].guard_active and b.turn==2,"PUSH has no damage or guard consumption and keeps target clock and movement count")
	b=_battle(PUSH)
	b.units[1].pos=Vector2i.ZERO
	b.units[2].pos=Vector2i(5,4)
	b.units[3].pos=Vector2i(6,4)
	b.choose_skill(PUSH)
	var state=_state(b)
	_check(not b.valid_target(0,2,PUSH) and not b.act(2) and _state(b)==state,"occupied landing cannot be pushed or chain-pushed")
	b.units[3].hp=0
	_check(b.valid_target(0,2,PUSH),"a defeated occupant does not block PUSH")
	b.units[0].pos=Vector2i(8,4)
	b.units[2].pos=Vector2i(9,4)
	_check(not b.valid_target(0,2,PUSH),"PUSH cannot leave the board")
	b.units[1].pos=Vector2i(7,4)
	_check(not b.valid_target(0,1,PUSH) and not b.valid_target(0,0,PUSH),"PUSH excludes ally and self")
## REQ-039-S01、REQ-039-S02、REQ-007-S03
func _guard() -> void:
	var b=_battle(GUARD)
	_check(b.choose_skill(GUARD) and not b.valid_target(0,1,GUARD) and b.valid_target(0,0,GUARD),"GUARD can target only the unguarded actor")
	var hp=b.units[0].hp
	_check(b.act(0) and b.units[0].guard_active and b.units[0].hp==hp and b.turn==2,"GUARD costs one action without changing HP")
	var factor=float(load("res://game/tuning.gd").get_script_constant_map().GUARD_DAMAGE_MULTIPLIER)
	var expected=floori(floori(T.BASE_DAMAGE*2.0/3.0)*factor)
	_check(M.effect(b.units[1],b.units[0],"DAMAGE")==expected and b.units[0].guard_active,"guarded damage uses configured final integer reduction without consuming in prediction")
	_check(M.effect(b.units[1],b.units[0],"HEAL")==floori(T.BASE_HEAL*2.0),"GUARD does not affect healing")
	b.actor=0
	b.mode="CHOICE"
	b.units[b.actor].moved=1
	b.choose_skill(GUARD)
	var state=_state(b)
	_check(not b.act(0) and _state(b)==state,"GUARD cannot stack")
	b.actor=2
	b.mode="CHOICE"
	b.units[b.actor].moved=1
	b.units[2].pos=Vector2i(4,3)
	b.units[2].skills=[C.DAMAGE]
	b.choose_skill(C.DAMAGE)
	_check(b.act(0) and not b.units[0].guard_active and b.units[0].hp==hp-expected,"first real attack consumes guard and uses the same preview amount")
	b.actor=0
	b.mode="CHOICE"
	b.units[b.actor].moved=1
	b.units[0].skills=[GUARD]
	_check(b.choose_skill(GUARD) and b.act(0) and b.units[0].guard_active,"guard can be reapplied after consumption")
	b.actor=1
	b.mode="CHOICE"
	b.units[b.actor].moved=1
	_check(b.choose_skill(C.HEAL) and b.act(0) and b.units[0].guard_active,"actual HEAL preserves the target's guard")
	b.actor=1
	b.mode="CHOICE"
	b.units[b.actor].moved=1
	_check(b.wait_turn() and b.units[0].guard_active,"WAIT and hand progression preserve another unit's guard")
	# 現行式で0になり得る入力でも、期待値をバランスの固定値にしない。
	var weak=C.default_build()
	weak.core=[25,1,25,24,25]
	weak.gear=weak.core.duplicate()
	weak.arms=weak.core.duplicate()
	b.units[2]=C.unit("A","ENEMY",Vector2i(4,3),weak)
	b.units[2].gear_angle=90.0
	b.units[2].arms_angle=180.0
	var amount=M.effect(b.units[2],b.units[0],"DAMAGE")
	b.actor=2
	b.mode="CHOICE"
	b.units[b.actor].moved=1
	b.choose_skill(C.DAMAGE)
	_check(b.act(0) and not b.units[0].guard_active and b.last_effect.amount==amount,"attack consumes guard independently of zero or positive damage")
	b.units[0].guard_active=true
	b.actor=0
	b.mode="MOVE"
	b.units[1].pos=Vector2i.ZERO
	b.path_click(Vector2i(5,4))
	b.commit_path()
	b.reselect_path()
	_check(b.units[0].guard_active,"moving and reselecting preserve existing guard")
	b.start(0,C.player_builds().slice(0,2),1)
	_check(b.units.all(func(u):return not u.guard_active),"new battle resets all runtime guard states")
## REQ-013-S05
func _goals() -> void:
	var b=_battle(SWAP)
	b.stage.victory=[{"type":"REACH","camp":"PLAYER","unit":"02","cell":Vector2i(4,4)}]
	b.stage.defeat=[]
	b.choose_skill(SWAP)
	_check(b.act(1) and b.result=="VICTORY" and b.turn==1,"nonacting swapped ally can reach its actual goal and stops before another hand")
	b=_battle(SWAP)
	b.stage.victory=[{"type":"REACH","camp":"PLAYER","unit":"01","cell":Vector2i(5,4)}]
	b.stage.defeat=[{"type":"REACH","camp":"PLAYER","unit":"02","cell":Vector2i(4,4)}]
	b.choose_skill(SWAP)
	_check(b.act(1) and b.result=="DEFEAT" and b.units[0].pos==Vector2i(5,4) and b.units[1].pos==Vector2i(4,4),"atomic SWAP applies both positions then resolves simultaneous loss first")
	b=_battle(PUSH)
	b.units[1].pos=Vector2i.ZERO
	b.units[2].pos=Vector2i(5,4)
	b.stage.victory=[]
	b.stage.defeat=[{"type":"REACH","camp":"ENEMY","unit":"A","cell":Vector2i(6,4)}]
	b.choose_skill(PUSH)
	_check(b.act(2) and b.result=="DEFEAT" and b.turn==1,"pushed opponent reaching its goal is not ignored")
## REQ-026-S04
func _inventory() -> void:
	var l=L.new()
	_check(l.skills==[C.DAMAGE,C.HEAL],"new utilities do not alter initial unlocks")
	var all_new=true
	for skill in [SWAP,PUSH,GUARD,IGNORE]: all_new=l.accept_drop({"skill":skill}) and all_new
	_check(all_new,"four new skills are obtainable through the existing shared inventory")
	if not all_new: return
	l.builds[0].skills=[SWAP,GUARD,IGNORE]
	l.builds[1].skills=[PUSH,GUARD,IGNORE]
	var path="res://artifacts/runtime/utility-save-%d.json" % Time.get_ticks_usec()
	var copy=L.new()
	_check(l.builds.all(func(build):return l.valid_build(build)) and l.save_to(path)=="" and copy.load_from(path)=="" and _normalized(copy.snapshot())==_normalized(l.snapshot()),"new skills round-trip in v1 with three slots and no runtime defense fields")
	l.skills=[C.DAMAGE,C.HEAL,C.MOVE,C.DAMAGE_DIAGONAL,C.HEAL_DIAGONAL,C.DAMAGE_ORTHOGONAL_TWO,C.HEAL_ORTHOGONAL_TWO,C.DAMAGE_DIAGONAL_TWO,C.HEAL_DIAGONAL_TWO]
	l.builds=C.player_builds()
	var old=L.new()
	_check(l.save_to(path)=="" and old.load_from(path)=="" and _normalized(old.snapshot())==_normalized(l.snapshot()),"old nine-skill v1 does not auto-unlock new utilities")
func _battle(skill: String):
	var build=C.default_build()
	build.skills=[skill]
	var b=B.new()
	b.start(0,[build,C.default_build()],1)
	b.panels={}
	b.actor=0
	b.units[0].pos=Vector2i(4,4)
	b.units[1].pos=Vector2i(5,4)
	b.units[2].pos=Vector2i(8,8)
	b.units[3].pos=Vector2i(9,9)
	b.mode="CHOICE"
	b.units[b.actor].moved=1
	return b
func _state(b) -> Array:
	return [b.units.duplicate(true),b.actor,b.mode,b.selected_skill,b.path.duplicate(),b.history.duplicate(),b.turn,b.last_effect.duplicate(true),b.result]
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)

func _normalized(value):
	return JSON.parse_string(JSON.stringify(value))
