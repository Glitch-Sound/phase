extends SceneTree
const C=preload("res://game/catalog.gd")
const L=preload("res://game/collection.gd")
var checks=0
var failures=0
func _initialize() -> void:
	_catalog()
	_session()
	print("DEBUG UNLOCK: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
## REQ-015-S01
func _catalog() -> void:
	var catalog=C.new()
	_check(catalog.has_method("equipment_catalog"),"shared finite equipment catalog exists")
	var normal=L.new()
	_check(normal.items.values().all(func(items):return items.values().all(func(stats):return stats.all(func(value):return value>=10 and int(value)%10==0))),"new-game equipment follows the ten-step rule")
	if not catalog.has_method("equipment_catalog"):return
	var expected=[]
	# 独立した9境界から4点を選び、5区間へ分割する。
	for a in range(1,7):
		for b in range(a+1,8):
			for c in range(b+1,9):
				for d in range(c+1,10):expected.append([a*10,(b-a)*10,(c-b)*10,(d-c)*10,(10-d)*10])
	var rows=catalog.equipment_catalog()
	_check(rows.size()==126 and _canonical(rows)==_canonical(expected),"catalog is exactly all 126 distributions, without duplicates")
	rows[0][0]=-1
	_check(_canonical(catalog.equipment_catalog())==_canonical(expected),"caller edits do not poison the catalog")
## REQ-041-S01、REQ-041-S02、REQ-041-S03、REQ-041-S04
func _session() -> void:
	_check(ResourceLoader.exists("res://game/debug_session.gd"),"isolated debug session exists")
	if not ResourceLoader.exists("res://game/debug_session.gd"):return
	var session=load("res://game/debug_session.gd").new()
	var normal=L.new()
	normal.stage_index=2
	var original=normal.snapshot()
	session.allowed=false
	_check(not session.available() and session.begin(normal)==null and not session.active() and normal.snapshot()==original,"unavailable mode refuses direct entry without touching normal state")
	session.allowed=true
	_check(session.available()==OS.is_debug_build(),"runtime debug condition cannot be enabled in release")
	if not OS.is_debug_build():return
	var sandbox=session.begin(normal)
	_check(sandbox!=null and sandbox!=normal and session.active() and sandbox.temporary,"debug starts with a separate temporary collection")
	_check(sandbox.items.ARMS.size()==126 and sandbox.items.GEAR.size()==126 and sandbox.builds.all(func(build):return sandbox.valid_build(build)),"all equipment is usable with new-game builds")
	var labels=sandbox.skills.duplicate();labels.sort()
	var all_skills=C.SKILLS.keys();all_skills.sort()
	_check(labels==all_skills and labels.size()==15,"all fifteen skills are unlocked exactly once")
	var mutations=sandbox.mutations
	var unique={}
	for mutation in mutations:unique[mutation]=true
	_check(mutations.size()==120 and unique.size()==120 and mutations.has("NORMAL") and not mutations.has("VIRSL") and mutations.all(func(value):return value=="NORMAL" or (value.length()==5 and "VIRSL".count(value[0])==1 and ["V","I","R","S","L"].all(func(letter):return value.count(letter)==1))),"all shared mutation permutations are present exactly once")
	_check(session.begin(normal)==null,"repeated entry cannot replace the saved normal reference")
	var path="res://artifacts/runtime/debug-unlock-no-write-%d.json" % Time.get_ticks_usec()
	var state=sandbox.snapshot()
	_check(sandbox.save_to(path)=="DEBUG / NOT SAVED" and sandbox.load_from(path)=="DEBUG / NOT SAVED" and not FileAccess.file_exists(path) and sandbox.snapshot()==state,"temporary save and load reject before any file access")
	var rng=RandomNumberGenerator.new();rng.seed=417
	var rng_state=rng.state
	_check(sandbox.roll_loot(rng)==[] and rng.state==rng_state and sandbox.snapshot()==state,"debug result has no loot or random-state changes")
	sandbox.builds[0].skills=[C.GUARD,C.FIELD_SLOW,C.SWAP]
	sandbox.stage_index=3
	_check(normal.snapshot()==original,"debug edits never mutate normal state")
	_check(session.end()==normal and not session.active() and normal.snapshot()==original,"exit returns the exact untouched normal object")
	var again=session.begin(normal)
	_check(again!=sandbox and again.stage_index==0 and again.builds==C.player_builds(),"reentry uses fresh test data")
	session.end()
func _canonical(rows: Array) -> Array:
	var keys=rows.map(func(row):return str(row));keys.sort();return keys
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
