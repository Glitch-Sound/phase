extends SceneTree
const B=preload("res://game/battle.gd")
const C=preload("res://game/catalog.gd")
const M=preload("res://game/phase_math.gd")
const L=preload("res://game/collection.gd")
const SLOW="PASSIVE_FIELD_SLOW_ADJACENT"
const STOP="PASSIVE_FIELD_STOP_ADJACENT"
const FAST="PASSIVE_FIELD_FAST_ADJACENT"
var checks=0
var failures=0
## REQ-026-S05
func _initialize() -> void:
	for skill in [SLOW,FAST]:
		_check(C.SKILLS.has(skill) and C.SKILLS.get(skill,{}).get("type","")=="PASSIVE","new passive "+skill)
	_check(C.SKILLS.keys().filter(func(id):return C.SKILLS[id].has("field"))==[SLOW,FAST] and C.FIELD_FACTORS=={"SLOW":0.5,"FAST":1.5},"only the two surviving fields remain in the live catalog and multipliers")
	_check(C.SKILLS[FAST].label=="FAST FIELD / SURROUNDING" and C.SKILLS[SLOW].label=="SLOW FIELD / SURROUNDING","field display names preserve the old fast ID")
	_entries()
	_inventory()
	_retired_save()
	_check(ResourceLoader.exists("res://game/rotation_field.gd"),"shared field resolver exists")
	if ResourceLoader.exists("res://game/rotation_field.gd"):
		_boundaries()
		_path()
		_forced()
	print("ROTATION FIELDS: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
## REQ-040-S01
func _entries() -> void:
	for row in [[SLOW,345.0,15.0],[FAST,315.0,45.0]]:
		var b=_battle()
		b.units[0].pos=Vector2i(2,4)
		b.units[2].pos=Vector2i(4,5)
		b.units[2].skills=[row[0]]
		b.units[0].core_angle=90.0
		b.panels={Vector2i(3,4):"CLOCKWISE"}
		var before=b.units.duplicate(true)
		b.path_click(Vector2i(3,4))
		var u=b.preview()
		_check([u.gear_angle,u.arms_angle,u.core_angle]==[row[1],row[2],120.0] and b.units==before,"field changes only normal equipment rotation; prediction is read-only "+row[0])
		_check(u.core==before[0].core and u.gear==before[0].gear and u.arms==before[0].arms and M.delay(u)==M.delay(before[0]) and u.hp==before[0].hp,"field leaves stats, delay and HP unchanged "+row[0])
## REQ-040-S02
func _boundaries() -> void:
	var f=load("res://game/rotation_field.gd")
	var b=_battle()
	var u=b.units[0]
	u.pos=Vector2i(4,4)
	var owner=b.units[1]
	owner.pos=Vector2i(5,4)
	owner.skills=[SLOW]
	_check(f.resolve(u,u.pos,[owner]).factor==0.5,"same-camp neighbor follows the same rule as the enemy")
	u.skills=[FAST]
	_check(f.resolve(u,u.pos,[u]).factor==1.0,"field never affects its own source")
	for row in [[Vector2i(4,4),100.0],[Vector2i(6,4),100.0],[Vector2i(5,4),0.0]]:
		owner.pos=row[0]
		owner.hp=row[1]
		_check(f.resolve(u,u.pos,[owner]).factor==1.0,"same cell, distance two or defeated source is excluded")
	owner.pos=Vector2i(5,4)
	owner.hp=100
	var other=b.units[2]
	other.pos=Vector2i(4,5)
	for row in [[[SLOW],[SLOW],0.5],[[FAST],[FAST],1.5],[[SLOW],[FAST],1.0]]:
		owner.skills=row[0]
		other.skills=row[1]
		_check(f.resolve(u,u.pos,[owner,other]).factor==row[2] and f.resolve(u,u.pos,[other,owner]).factor==row[2],"same-kind idempotence, and cancellation are order-independent")
	owner.pos=Vector2i.ZERO
	owner.skills=[SLOW]
	_check(_sorted(f.coverage([owner]).keys())==_sorted([Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]) and f.resolve(u,Vector2i(-1,0),[owner]).factor==1.0,"corner coverage is exactly three surrounding in-board cells")
## REQ-040-S03、REQ-040-S05
func _path() -> void:
	var b=_battle()
	b.units[0].pos=Vector2i(2,2)
	b.units[1].pos=Vector2i(4,4)
	b.units[1].skills=[SLOW]
	var before=b.units.duplicate(true)
	for cell in [Vector2i(3,2),Vector2i(3,3),Vector2i(2,3)]: b.path_click(cell)
	var u=b.preview()
	_check([u.gear_angle,u.arms_angle]==[285.0,75.0],"normal, slow, normal applies once per landing without persistence")
	_check(b.commit_path() and b.units[0].gear_angle==285.0 and b.units[0].arms_angle==75.0 and b.units[1]==before[1],"actual route matches prediction and never rotates the stationary owner")
	_check(b.reselect_path() and b.units==before,"reselect restores all original state with field-equipped units")
	b.path=[]
	b.actor=1
	b.path_click(Vector2i(5,4))
	_check(b.commit_path() and b.units[0]==before[0],"moving the emitter does not retroactively change a stationary receiver")
	b.actor=0
	b.mode="MOVE"
	b.units[0].pos=Vector2i(3,3)
	b.path_click(Vector2i(3,4))
	_check(b.preview().gear_angle==330.0,"old field location stops applying after the emitter moves")
## REQ-040-S04、REQ-040-S05
func _forced() -> void:
	var b=_battle()
	b.units[0].pos=Vector2i(4,4)
	b.units[0].skills=[C.SWAP,C.IGNORE_PANEL]
	b.units[0].core_angle=90.0
	b.units[1].pos=Vector2i(5,4)
	b.units[1].skills=[SLOW]
	b.units[1].core_angle=60.0
	b.units[1].initial_core_angle=15.0
	b.panels={Vector2i(4,4):"RESET",Vector2i(5,4):"CLOCKWISE"}
	b.mode="CHOICE"
	b.units[0].moved=1
	b.choose_skill(C.SWAP)
	var before=b.units.duplicate(true)
	var forecast=b.action_preview(1)
	_check(b.units==before and [forecast.units[0].gear_angle,forecast.units[0].arms_angle,forecast.units[0].core_angle,forecast.units[1].gear_angle,forecast.units[1].core_angle]==[345.0,15.0,90.0,330.0,15.0],"SWAP resolves both final positions before field entry; ignore affects only CORE")
	b.back()
	_check(b.units==before and b.mode=="CHOICE","target BACK applies no forced entry or field")
	b.choose_skill(C.SWAP)
	_check(b.act(1) and b.units[0].gear_angle==345.0 and b.units[1]==forecast.units[1],"SWAP commits prediction and preserves displaced clock and movement count")
	b=_battle()
	b.units[0].pos=Vector2i(4,4)
	b.units[0].skills=[C.PUSH]
	b.units[1].pos=Vector2i(7,3)
	b.units[1].skills=[FAST]
	b.units[2].pos=Vector2i(5,4)
	b.units[2].core_angle=90
	b.units[2].guard_active=true
	b.panels={Vector2i(6,4):"COUNTERCLOCKWISE"}
	b.mode="CHOICE"
	b.units[0].moved=1
	b.choose_skill(C.PUSH)
	before=b.units.duplicate(true)
	forecast=b.action_preview(2)
	_check([forecast.units[2].gear_angle,forecast.units[2].arms_angle,forecast.units[2].core_angle]==[315.0,45.0,60.0] and b.units==before,"PUSH receives the field at its landing and the normal CORE panel")
	_check(b.act(2) and b.units[2]==forecast.units[2] and b.units[2].hp==before[2].hp and b.units[2].guard_active,"PUSH prediction connects without damage or clock and guard changes")
## REQ-026-S05
func _inventory() -> void:
	var l=L.new()
	_check(l.skills==[C.DAMAGE,C.HEAL],"new fields remain locked initially")
	var accepted=true
	for skill in [SLOW,FAST]: accepted=l.accept_drop({"skill":skill}) and accepted
	_check(accepted,"both fields use the existing loot acceptance path")
	if not accepted:return
	_check(not l.accept_drop({"skill":STOP}),"retired STOP cannot be collected")
	l.builds[0].skills=[SLOW,FAST]
	l.builds[1].skills=[FAST,SLOW,C.DAMAGE]
	var copy=L.new()
	var file="res://artifacts/runtime/rotation-field-save-%d.json" % Time.get_ticks_usec()
	_check(l.builds.all(func(build):return l.valid_build(build)) and l.save_to(file)=="" and copy.load_from(file)=="" and _json(copy.snapshot())==_json(l.snapshot()),"new passives share three slots and round-trip in v1 without cloud state")
	l.skills=[C.DAMAGE,C.HEAL,C.MOVE,C.DAMAGE_DIAGONAL,C.HEAL_DIAGONAL,C.DAMAGE_ORTHOGONAL_TWO,C.HEAL_ORTHOGONAL_TWO,C.DAMAGE_DIAGONAL_TWO,C.HEAL_DIAGONAL_TWO,C.SWAP,C.PUSH,C.GUARD,C.IGNORE_PANEL]
	l.builds=C.player_builds()
	_check(l.save_to(file)=="" and copy.load_from(file)=="" and _json(copy.snapshot())==_json(l.snapshot()),"old thirteen-skill v1 preserves inventory and never auto-unlocks fields")
## REQ-016-S03
func _retired_save() -> void:
	var original=L.new().snapshot()
	original.skills=[C.DAMAGE,C.HEAL,FAST,STOP,SLOW]
	original.mutations=["NORMAL","VLSRI"]
	original.stage_index=2
	original.builds[0].skills=[FAST,STOP,C.DAMAGE]
	original.builds[1].skills=[STOP]
	original.builds[2].skills=[C.HEAL,SLOW]
	_check(not L.new().valid_build(original.builds[0],original),"retired ID is accepted only by legacy loading, never normal build validation")
	var expected=original.duplicate(true)
	expected.skills=[C.DAMAGE,C.HEAL,FAST,SLOW]
	expected.builds[0].skills=[FAST,C.DAMAGE]
	expected.builds[1].skills=[]
	var path="res://artifacts/runtime/remove-stop/legacy-%d.json" % Time.get_ticks_usec()
	var bytes=JSON.stringify(original,"\t")
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(bytes);file.close()
	var loaded=L.new()
	_check(loaded.load_from(path)=="" and _json(loaded.snapshot())==_json(expected),"valid old STOP inventory and slots remove only STOP, preserving order and all other data")
	_check(FileAccess.get_file_as_string(path)==bytes,"legacy load never rewrites the source")
	var roundtrip=path+".current.json"
	var copy=L.new()
	_check(loaded.save_to(roundtrip)=="" and copy.load_from(roundtrip)=="" and _json(copy.snapshot())==_json(expected),"cleaned state can explicitly save and reload without STOP")
	for kind in ["unknown","duplicate","locked"]:
		var bad=original.duplicate(true)
		if kind=="unknown":bad.skills.append("UNKNOWN")
		elif kind=="duplicate":bad.skills.append(STOP)
		else:bad.skills.erase(STOP)
		file=FileAccess.open(path+kind,FileAccess.WRITE);file.store_string(JSON.stringify(bad));file.close()
		var before=loaded.snapshot()
		_check(not loaded.load_from(path+kind).is_empty() and loaded.snapshot()==before,"legacy cleanup cannot hide an invalid original "+kind)
	original.builds=original.builds.slice(0,2)
	file=FileAccess.open(path+".two",FileAccess.WRITE);file.store_string(JSON.stringify(original));file.close()
	_check(loaded.load_from(path+".two")=="" and _json(loaded.builds.slice(0,2))==_json(expected.builds.slice(0,2)) and loaded.builds.size()==3 and loaded.builds.all(func(b):return loaded.valid_build(b)),"old two-build save also removes only STOP before the existing third-build supplement")
func _battle():
	var b=B.new()
	b.start(0,[C.default_build(),C.default_build()],1)
	b.panels={}
	b.actor=0
	b.units[0].skills=[C.DAMAGE,C.HEAL]
	for i in range(4):b.units[i].pos=Vector2i(6+i%2,8+i/2)
	b.mode="MOVE"
	return b
func _sorted(cells: Array) -> Array:
	var names=cells.map(func(cell):return "%d,%d" % [cell.x,cell.y]);names.sort();return names
func _json(value):return JSON.parse_string(JSON.stringify(value))
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
