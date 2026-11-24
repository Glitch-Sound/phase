extends SceneTree
const C=preload("res://game/catalog.gd")
const L=preload("res://game/collection.gd")
const B=preload("res://game/battle.gd")
var checks=0
var failures=0
var folder="res://artifacts/runtime/starter-profile-tests/"+str(Time.get_ticks_usec())

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check(ResourceLoader.exists("res://game/profile.gd") and ResourceLoader.exists("res://game/storage.gd"),"common profile and storage boundary exist")
	if failures==0:
		var profile=load("res://game/profile.gd")
		var storage=load("res://game/storage.gd")
		storage.memory_only=false
		_new_profile(profile)
		_existing(profile)
		_failures(profile)
		await _web(profile,storage)
		await _notice(profile,storage)
		await _demo(profile,storage)
		storage.memory_only=null
	print("STARTER PROFILE: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)

## REQ-061-S01
func _new_profile(profile) -> void:
	var original=C.equipment_catalog()
	var rng=RandomNumberGenerator.new();rng.seed=48
	var opened=profile.open_profile(folder+"/new.json",rng)
	_check(opened.error.is_empty(),"new profile is saved")
	var value=opened.collection
	for kind in ["ARMS","GEAR"]:
		var extra=[]
		for row in value.items[kind].values():
			if not C.STARTER_STATS.has(row):extra.append(row)
		var axes=[]
		for row in extra:
			if row.count(row.max())==1:axes.append(row.find(row.max()))
		axes.sort()
		_check(value.items[kind].size()==C.STARTER_STATS.size()+5 and extra.size()==5 and axes==[0,1,2,3,4],"five unique additions span all five dominant axes "+kind)
		_check(C.STARTER_STATS.all(func(row):return value.items[kind].values().has(row)) and extra.all(func(row):return original.has(row)),"fixed items and unchanged catalog values "+kind)
	_check(value.builds==C.player_builds() and value.skills==[C.DAMAGE,C.HEAL] and value.mutations==["NORMAL"],"initial builds and skill collection are unchanged")
	var equal=L.new();var seeded=RandomNumberGenerator.new();seeded.seed=48
	equal.unlock_starters(seeded)
	_check(equal.snapshot()==value.snapshot() and C.equipment_catalog()==original,"same seed is reproducible and catalog is not mutated")
	var small=L.new();var candidate=[60,10,10,10,10]
	small.unlock_starters(seeded,[candidate,candidate,C.STARTER_STATS[0]])
	_check(small.items.ARMS.size()==5 and small.items.GEAR.size()==5 and small.items.ARMS.values().has(candidate),"short duplicate candidate pool adds only one distinct available item")
	profile._profiles.clear()
	var before=rng.state;var reopened=profile.open_profile(folder+"/new.json",rng)
	_check(reopened.error.is_empty() and _same(reopened.collection.snapshot(),value.snapshot()) and rng.state==before,"restart restores exact initial roll without drawing RNG")

## REQ-061-S02
func _existing(profile) -> void:
	var old=L.new();old.unit_names[0]="Fixture";old.stage_index=1
	old.accept_drop({"skill":C.MOVE});old.builds[0].skills=[C.MOVE]
	var path=folder+"/existing.json"
	_check(old.save_to(path).is_empty(),"valid existing fixture saved")
	var bytes=FileAccess.get_file_as_bytes(path);var rng=RandomNumberGenerator.new();rng.seed=53;var before=rng.state
	var loaded=profile.open_profile(path,rng)
	_check(loaded.error.is_empty() and _same(loaded.collection.snapshot(),old.snapshot()) and rng.state==before and FileAccess.get_file_as_bytes(path)==bytes,"existing profile gets no roll, write, or composition changes")

## REQ-061-S03
func _failures(profile) -> void:
	var path=folder+"/broken.json";var file=FileAccess.open(path,FileAccess.WRITE);file.store_string("broken");file.close()
	var rng=RandomNumberGenerator.new();rng.seed=32;var before=rng.state
	var broken=profile.open_profile(path,rng)
	_check(not broken.error.is_empty() and rng.state==before and FileAccess.get_file_as_string(path)=="broken","invalid existing save is reported without rolling or overwriting")
	var blocked=folder+"/blocked";file=FileAccess.open(blocked,FileAccess.WRITE);file.store_string("file");file.close()
	var failed=profile.open_profile(blocked+"/save.json",rng);before=rng.state
	var again=profile.open_profile(blocked+"/save.json",rng)
	_check(not failed.error.is_empty() and again.collection==failed.collection and rng.state==before and FileAccess.get_file_as_string(blocked)=="file","failed initial write retains one roll for the session")

## REQ-062-S01、REQ-062-S02
func _web(profile,storage) -> void:
	profile._profiles.clear();storage.memory_only=true;storage._memory.clear()
	var path=folder+"/web.json";var rng=RandomNumberGenerator.new();rng.seed=48
	var opened=profile.open_profile(path,rng);var value=opened.collection
	value.unit_names[0]="Session";value.accept_drop({"skill":C.MOVE});value.builds[0].skills=[C.MOVE]
	value.stage_index=1
	var before=rng.state
	_check(profile.open_profile(path,rng).collection==value and rng.state==before,"scene recreation shares live profile without reroll")
	_check(value.save_to(path).is_empty(),"same collection save uses memory")
	var restored=L.new();_check(restored.load_from(path).is_empty() and _same(restored.snapshot(),value.snapshot()),"same snapshot and validation restore edited memory save")
	var battle=B.new();battle.start(value.stage_index,value.builds,17,value.unit_names)
	_check(battle.units.size()==6 and battle.units[0].skills==[C.MOVE],"memory build enters common battle")
	var colors=preload("res://ui/palette.gd");var language=preload("res://ui/language.gd");var sound=preload("res://ui/sfx.gd");var display=preload("res://ui/display_settings.gd")
	var base=folder+"/web-settings"
	_check(colors.save_to(base,colors.PRESETS.AMBER).is_empty() and language.write_to(base+".language.json","ja").is_empty() and sound.write_enabled(base+".audio.json",false).is_empty() and display.write_to(base+".display.json",3).is_empty(),"all settings save into memory")
	_check(colors.load_from(base)==colors.PRESETS.AMBER and language.read_from(base+".language.json")=="ja" and not sound.read_enabled(base+".audio.json") and display.read_from(base+".display.json")==3,"all settings read the memory values")
	_check(not FileAccess.file_exists(path) and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(base)),"no game file is created")
	_check([base,base+".language.json",base+".audio.json",base+".display.json"].all(func(p):return not FileAccess.file_exists(p)),"no settings files are created")
	# 同じシーンの再構築でも、UIが共通保存を復元することだけを代表確認する。
	var scene=load("res://main.tscn").instantiate();scene.save_path=path;scene.settings_path=base;scene.profile_startup=true
	root.add_child(scene);await process_frame
	_check(scene.collection==value and scene.copy_language.selection=="ja" and not scene.sfx.enabled and scene.palette_colors==colors.PRESETS.AMBER,"UI profile and settings entrance uses memory backend")
	scene.queue_free();await process_frame
	profile._profiles.clear();storage._memory.clear()
	var fresh=profile.open_profile(path,rng).collection
	_check(fresh.unit_names[0]!="Session" and fresh.skills==[C.DAMAGE,C.HEAL] and language.read_from(base+".language.json")=="system" and sound.read_enabled(base+".audio.json"),"fresh page state forgets prior build, rewards and settings")

func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)

func _same(a: Variant,b: Variant) -> bool:
	# JSONの数値は復元時にfloatとなるため、同じJSON値として厳密な全体比較を行う。
	return JSON.parse_string(JSON.stringify(a))==JSON.parse_string(JSON.stringify(b))

## REQ-061-S04
func _notice(profile,storage) -> void:
	profile._profiles.clear();storage.memory_only=true;storage._memory.clear()
	var scene=load("res://main.tscn").instantiate();scene.save_path=folder+"/notice.json";scene.settings_path=folder+"/notice-settings";scene.profile_startup=true
	root.add_child(scene);await process_frame
	_check(scene.has_method("_starter_unlocks"),"initial equipment dialog exists")
	if scene.has_method("_starter_unlocks"):
		_check(is_instance_valid(scene.auxiliary) and scene.auxiliary.has_meta("starter_unlocks"),"first BUILD opens the announcement")
		if is_instance_valid(scene.auxiliary) and scene.auxiliary.has_meta("starter_unlocks"):
			var shown=scene.auxiliary.get_meta("starter_unlocks");var expected=[]
			for kind in ["ARMS","GEAR"]:
				for stats in scene.collection.items[kind].values():
					if not C.STARTER_STATS.has(stats):expected.append(C.serial(kind,stats))
			var labels=scene.auxiliary.find_children("*","Label",true,false).map(func(label):return label.text)
			var actual=labels.filter(func(text):return text.begins_with("ARMS-") or text.begins_with("GEAR-"));actual.sort();expected.sort()
			_check(actual==expected and actual.size()==10 and shown.size()==10 and labels.count("ARMS")==1 and labels.count("GEAR")==1,"rendered dialog matches exactly the ten added items in two categories")
			var escape=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true
			scene._unhandled_input(escape);await process_frame
			scene._build();await process_frame
			_check(scene.build_open and not is_instance_valid(scene.auxiliary),"closing returns to BUILD and revisiting does not repeat")
	scene.queue_free();await process_frame
	var again=load("res://main.tscn").instantiate();again.save_path=folder+"/notice.json";again.settings_path=folder+"/notice-settings";again.profile_startup=true
	root.add_child(again);await process_frame
	_check(not is_instance_valid(again.auxiliary),"scene recreation does not repeat the announcement")
	again.queue_free();await process_frame
	profile._profiles.clear();storage._memory.clear()
	var fresh=load("res://main.tscn").instantiate();fresh.save_path=folder+"/notice.json";fresh.settings_path=folder+"/notice-settings";fresh.profile_startup=true
	root.add_child(fresh);await process_frame
	_check(is_instance_valid(fresh.auxiliary) and fresh.auxiliary.get_meta("starter_unlocks").size()==10,"new page session announces its own ten new items again")
	fresh._close_aux();fresh.queue_free();await process_frame

## REQ-062-S01、REQ-062-S02、REQ-062-S04
func _demo(profile,storage) -> void:
	var methods=storage.get_script_method_list().map(func(row):return row.name)
	_check(methods.has("is_demo"),"demo policy is available at the storage boundary")
	if not methods.has("is_demo"):return
	profile._profiles.clear();storage._memory.clear();storage.memory_only=null;storage.demo_override=true
	var path=folder+"/demo.json";var base=folder+"/demo-settings"
	var rng=RandomNumberGenerator.new();rng.seed=48
	var opened=profile.open_profile(path,rng);var value=opened.collection
	_check(opened.error.is_empty() and value.items.ARMS.size()==9 and value.items.GEAR.size()==9,"demo startup rolls the normal ten additions without save errors")
	value.unit_names[0]="Demo fixture";value.accept_drop({"skill":C.MOVE})
	var before=value.snapshot()
	var candidate=L.new();candidate.unit_names[0]="Stored fixture"
	var bytes=JSON.stringify(candidate.snapshot())
	storage.write_text(path,bytes)
	_check(value.save_to(path)=="DEMO / SAVE and LOAD are unavailable." and value.load_from(path)=="DEMO / SAVE and LOAD are unavailable." and value.snapshot()==before and storage.read_text(path).text==bytes,"demo refuses even a valid stored snapshot without reading, replacing it or changing the build")
	storage._memory.erase(path)
	var language=preload("res://ui/language.gd")
	_check(language.write_to(base+".language.json","ja").is_empty(),"demo settings can change within the session")
	var scene=load("res://main.tscn").instantiate();scene.save_path=path;scene.settings_path=base;scene.profile_startup=true
	root.add_child(scene);await process_frame
	if is_instance_valid(scene.auxiliary):scene._close_aux()
	var saves=scene.overlay.find_children("*","Button",true,false).filter(func(button):return button.text in ["SAVE","LOAD"])
	_check(saves.size()==2 and saves.all(func(button):return button.visible and button.disabled),"demo BUILD keeps SAVE and LOAD visible but disabled")
	scene._save();scene._load()
	_check(scene.collection==value and value.snapshot()==before and scene.copy_language.selection=="ja","UI requests preserve live composition, unlocks and session settings")
	scene._build();await process_frame
	_check(scene.collection==value and not is_instance_valid(scene.auxiliary),"revisit keeps edited profile without repeating initial notice")
	scene.queue_free();await process_frame
	profile._profiles.clear();storage._memory.clear()
	var fresh=profile.open_profile(path,rng).collection
	_check(fresh.unit_names[0]!="Demo fixture" and fresh.skills==[C.DAMAGE,C.HEAL] and language.read_from(base+".language.json")=="system" and profile.take_unlocks(path).size()==10,"fresh page resets identifiable build and setting, and announces its own unlocks")
	_check(not FileAccess.file_exists(path) and not FileAccess.file_exists(base+".language.json"),"demo never writes game or settings files")
	storage.demo_override=null;storage.memory_only=null;profile._profiles.clear();storage._memory.clear()
