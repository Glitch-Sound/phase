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
	_check(skills.size()==17 and not skills.filter(func(r):return r.id==C.DAMAGE)[0].selectable and not skills.filter(func(r):return r.id==C.MOVE)[0].selectable,"NONE plus all skills distinguish equipped and locked entries")
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
	var reversed=model.preview(base,"class_name","REVERSE")
	_check(reversed.class_name=="REVERSE" and reversed.core==base.core and reversed.gear_mutation==base.gear_mutation and reversed.arms_mutation==base.arms_mutation,"class changes CORE order only, never applies a mutation")
	var mutant=model.preview(base,"gear_mutation","LSRIV")
	_check(mutant.gear_mutation=="LSRIV" and mutant.arms_mutation==base.arms_mutation and mutant.class_name==base.class_name and mutant.gear==base.gear,"mutation changes only target equipment order")
	_check(model.candidates(collection,0,"class_name").map(func(r):return r.id)==["STANDARD","REVERSE"],"class candidates remain exactly existing two rules")
	_skill_and_operation(model,collection)
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
