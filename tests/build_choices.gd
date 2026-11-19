extends SceneTree
const C=preload("res://game/catalog.gd")
const L=preload("res://game/collection.gd")
var checks=0
var failures=0
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	if not FileAccess.file_exists("res://game/build_choices.gd"):
		_check(false,"shared candidate model exists")
	else:
		var choices=load("res://game/build_choices.gd")
		_catalog(choices)
		_preview_and_commit(choices)
		_contents(choices)
		_class_catalog(choices)
		_class_battle()
		_class_save()
	print("BUILD CHOICES: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
## REQ-042-S02
func _catalog(model) -> void:
	var collection=L.new()
	var rows=model.candidates(collection,0,"arms")
	_check(rows.size()==126 and rows.filter(func(r):return r.unlocked).size()==4,"all equipment visible and only owned items selectable")
	var locked=rows.filter(func(r):return not r.unlocked)[0]
	var before=collection.snapshot()
	_check(not locked.selectable and not model.commit(collection,0,"arms",locked.id) and collection.snapshot()==before,"locked item cannot be committed through direct call")
	var filtered=model.filtered(rows,1,40)
	_check(not filtered.is_empty() and filtered.all(func(r):return r.stats[1]>=40) and filtered[0].stats[1]==60,"INF filter keeps only matching candidates in descending order")
	var mutations=model.candidates(collection,0,"gear_mutation")
	_check(mutations.size()==120 and mutations.filter(func(r):return r.selectable).map(func(r):return r.id)==["NORMAL"],"mutations are a separate shared catalogue with inactive locks")
	var skills=model.candidates(collection,0,"skill",2)
	_check(skills.size()==16 and not skills.filter(func(r):return r.id==C.DAMAGE)[0].selectable and not skills.filter(func(r):return r.id==C.MOVE)[0].selectable,"NONE plus all current skills distinguish equipped and locked entries")
	_check(skills.filter(func(r):return r.id=="NONE")[0].selectable,"empty slot remains available")
## REQ-042-S01、REQ-024-S01
func _preview_and_commit(model) -> void:
	var collection=L.new()
	var before=collection.snapshot()
	var id=C.serial("ARMS",[20,30,10,20,20])
	var candidate=model.preview(collection.builds[0],"arms",id)
	_check(candidate.arms==[20,30,10,20,20] and collection.snapshot()==before,"candidate changes only an independent preview")
	_check(model.commit(collection,0,"arms",id) and collection.builds[0].arms==[20,30,10,20,20] and collection.builds[1]==before.builds[1],"explicit commit affects only selected equipment and unit")
	var invalid=collection.snapshot()
	_check(not model.commit(collection,0,"arms","ARMS-invalid") and collection.snapshot()==invalid,"unknown candidates fail without mutation")
## REQ-042-S03
func _contents(model) -> void:
	var collection=L.new()
	var base=collection.builds[0].duplicate(true)
	var reversed=model.preview(base,"class_name","LSRIV")
	var expected=base.duplicate(true);expected.class_name="LSRIV"
	_check(reversed==expected and C.M.order(C.unit("01","PLAYER",Vector2i.ZERO,reversed),0)==[4,3,2,1,0],"class changes CORE order only, never applies a mutation")
	var mutant=model.preview(base,"gear_mutation","LSRIV")
	_check(mutant.gear_mutation=="LSRIV" and mutant.arms_mutation==base.arms_mutation and mutant.class_name==base.class_name and mutant.gear==base.gear,"mutation changes only target equipment order")
	_check(model.candidates(collection,0,"class_name").filter(func(r):return r.current).map(func(r):return r.id)==["VIRSL"],"legacy default selects the standard placement code")
	_skill_and_operation(model,collection)
## REQ-045-S01、REQ-042-S02
func _class_catalog(model) -> void:
	var collection=L.new()
	var rows=model.candidates(collection,0,"class_name")
	var unique={}
	for row in rows:unique[row.id]=true
	_check(rows.size()==120 and unique.size()==120 and rows.all(func(row):return row.id.length()==5 and ["V","I","R","S","L"].all(func(letter):return row.id.count(letter)==1)),"CLASS contains every unique five-stat permutation")
	_check(rows.filter(func(r):return r.selectable).map(func(r):return r.id)==["VIRSL","VLSRI"],"only standard and legacy reverse are initially available")
	var before=collection.snapshot()
	_check(not model.commit(collection,0,"class_name","LSRIV") and not model.commit(collection,0,"class_name","VIRSS") and collection.snapshot()==before,"locked and malformed CLASS do not change the build")
	_check(model.commit(collection,0,"class_name","VLSRI") and collection.mutations==["NORMAL"] and not model.commit(collection,0,"gear_mutation","VLSRI"),"legacy reverse CLASS does not unlock equipment mutation")
	collection.accept_drop({"kind":"GEAR","stats":[20,20,20,20,20],"mutation":"LSRIV"})
	var available=model.candidates(collection,0,"class_name").filter(func(r):return r.selectable).map(func(r):return r.id)
	available.sort()
	_check(available==["LSRIV","VIRSL","VLSRI"] and model.commit(collection,0,"class_name","LSRIV") and collection.valid_build(collection.builds[0]),"shared mutation unlock makes exactly its CORE placement available")
	collection.mutations=C.mutation_catalog()
	_check(model.candidates(collection,0,"class_name").filter(func(r):return r.selectable).size()==120,"all-unlock exposes all 120 CLASS placements")
## REQ-045-S02
func _class_battle() -> void:
	var builds=C.player_builds();builds[0].class_name="LSRIV"
	var battle=load("res://game/battle.gd").new();battle.start(0,builds,19)
	battle.panels={Vector2i(4,4):"CLOCKWISE",Vector2i(4,5):"RESET"}
	var initial=battle.units[0].duplicate(true)
	var sectors=[]
	for status in range(5):sectors.append(C.M.sector(initial,0,status))
	_check(C.M.order(initial,0)==[4,3,2,1,0] and C.M.order(initial,1)==[0,1,2,3,4] and C.M.order(initial,2)==[0,1,2,3,4],"nonstandard CLASS reaches battle and affects CORE only")
	battle.path_click(Vector2i(4,4))
	var preview=battle.preview()
	_check(preview.core_angle==initial.core[3]*1.5 and battle.units[0]==initial and battle.commit_path() and battle.units[0].core_angle==preview.core_angle,"nonstandard CORE rotation preview matches commit without mutating origin")
	_check(battle.reselect_path() and battle.units[0]==initial,"route reselect restores original nonstandard CORE")
	battle.path_click(Vector2i(4,5));preview=battle.preview()
	_check(battle.commit_path() and battle.units[0].core_angle==0.0 and battle.units[0].gear_angle==preview.gear_angle and battle.units[0].arms_angle==preview.arms_angle and battle.units[0].class_name=="LSRIV","RESET preserves selected CLASS and normal equipment entry")
	var restored=[]
	for status in range(5):restored.append(C.M.sector(battle.units[0],0,status))
	battle.start(0,builds,20)
	var restarted=[]
	for status in range(5):restarted.append(C.M.sector(battle.units[0],0,status))
	_check(restored==sectors and restarted==sectors,"RESET and a new battle restore the selected starting sectors")
## REQ-045-S03
func _class_save() -> void:
	var legacy=L.new().snapshot()
	legacy.builds[0].class_name="STANDARD";legacy.builds[1].class_name="REVERSE"
	var path="res://artifacts/runtime/class-legacy-disposable.json"
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(legacy));file.close()
	var bytes=FileAccess.get_file_as_bytes(path)
	var loaded=L.new()
	_check(loaded.load_from(path).is_empty() and JSON.parse_string(JSON.stringify(loaded.snapshot()))==JSON.parse_string(JSON.stringify(legacy)) and FileAccess.get_file_as_bytes(path)==bytes,"legacy read preserves inventory, literal classes and source bytes")
	_check(C.M.order(C.unit("01","PLAYER",Vector2i.ZERO,loaded.builds[0]),0)==[0,1,2,3,4] and C.M.order(C.unit("02","PLAYER",Vector2i.ZERO,loaded.builds[1]),0)==[0,4,3,2,1],"legacy STANDARD and REVERSE keep exactly their original order")
	loaded.mutations.append("LSRIV");loaded.builds[2].class_name="LSRIV"
	var new_path="res://artifacts/runtime/class-new-disposable.json"
	var saved=loaded.save_to(new_path);var roundtrip=L.new()
	_check(saved.is_empty() and roundtrip.load_from(new_path).is_empty() and JSON.parse_string(JSON.stringify(roundtrip.snapshot()))==JSON.parse_string(JSON.stringify(loaded.snapshot())),"new CLASS and legacy classes round-trip together")
	var before=loaded.snapshot()
	for invalid in ["VIRSS","IVRSL"]:
		var bad=before.duplicate(true);bad.builds[0].class_name=invalid
		file=FileAccess.open(new_path,FileAccess.WRITE);file.store_string(JSON.stringify(bad));file.close()
		_check(not loaded.load_from(new_path).is_empty() and loaded.snapshot()==before,"malformed or locked CLASS read is atomic: "+invalid)
## REQ-042-S04
func _skill_and_operation(model,collection) -> void:
	var rows=model.candidates(collection,0,"skill",2)
	_check(rows.filter(func(r):return r.id==C.DAMAGE_DIAGONAL_TWO)[0].group=="DAMAGE" and rows.all(func(r):return not r.description.is_empty()),"skill family grouping and short effects cover every candidate")
	var operations=model.candidates(collection,0,"operation")
	_check(operations.size()==4 and operations.all(func(r):return not r.description.is_empty() and r.selectable),"all operations explain objectives")
	_check(model.commit(collection,0,"operation","2") and collection.stage_index==2,"operation changes only after explicit commit")
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
