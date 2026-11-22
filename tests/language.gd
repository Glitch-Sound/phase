extends SceneTree
const C=preload("res://game/catalog.gd")
const BC=preload("res://game/build_choices.gd")
const COLLECTION=preload("res://game/collection.gd")
var checks=0
var failures=0
var model
var folder="res://artifacts/runtime/language-tests-"+str(Time.get_ticks_usec())
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	model=load("res://ui/language.gd") if ResourceLoader.exists("res://ui/language.gd") else null
	_check(model!=null,"explanation language component exists")
	if model!=null:
		_test_resolution()
		_test_storage()
		_test_copy()
	await _test_ui()
	print("LANGUAGE: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
## REQ-053-S01
func _test_resolution() -> void:
	for locale in ["ja","ja-JP","ja_JP","ja_Jpan_JP"]:
		_check(model.resolve("system",locale)=="ja","Japanese locale variants use Japanese: "+locale)
	for locale in ["en_US","en_JP","fr-FR","","jargon"]:
		_check(model.resolve("system",locale)=="en","other primary languages use English: "+locale)
	_check(model.resolve("en","ja_JP")=="en" and model.resolve("ja","en_US")=="ja","explicit choices override the environment in both directions")
	_check([null,{},"unknown"].all(func(value):return model.resolve(value,"ja_JP")=="ja"),"unknown and missing selections are automatic")
## REQ-053-S02
func _test_storage() -> void:
	var path=folder+"/preference.json"
	_check(model.read_from(path)=="system" and not FileAccess.file_exists(path),"missing preference is automatic without writing")
	for value in ["en","ja","system"]:
		_check(model.write_to(path,value).is_empty() and model.read_from(path)==value,"explicit preference survives a new read: "+value)
	for source in ['{}','{"language":"other"}','{"language":3}','["legacy"]','invalid']:
		var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(source);file.close()
		_check(model.read_from(path)=="system","unsupported settings fall back to automatic: "+source)
	var blocker=folder+"/blocker";var file=FileAccess.open(blocker,FileAccess.WRITE);file.store_string("keep");file.close()
	_check(not model.write_to(blocker+"/preferences.json","ja").is_empty() and FileAccess.get_file_as_string(blocker)=="keep","failed writes report an error and preserve existing bytes")
## REQ-053-S04
func _test_copy() -> void:
	var copy=model.new();copy.selection="ja";copy.preferred_locale="en_US"
	_check(copy.text("Damage one adjacent enemy.")=="隣接する敵1体にダメージ","Japanese damage explanation is exact")
	_check(copy.text("Move up to 4 cells per turn.")=="1手で最大4マス移動","formatted explanation preserves its actual value")
	_check(copy.text("CORE order: VIT > INF\nOnly CORE changes. Always available.")=="COREの並び: VIT > INF\nCOREだけに適用\n常に選択できる","layout explanations keep mechanical order labels")
	_check(copy.text("Push one enemy 1 cell outward. No damage.")=="隣接する敵1体を1マス押す\nダメージなし","Japanese sentence boundaries become newlines without a trailing blank")
	_check(copy.COPY.keys().all(func(source):return not copy.text(source).contains("。") and not copy.text(source).ends_with("\n")),"all registered Japanese prose and templates omit punctuation and trailing blank lines")
	_check(copy.text("Inspected unit: 名。前")=="確認中のユニット: 名。前" and copy.text("名。前")=="名。前","format values and unknown user text retain literal punctuation")
	var data=COLLECTION.new();var untranslated=[]
	for kind in ["class_name","arms_mutation","gear_mutation","skill","operation"]:
		for row in BC.candidates(data,0,kind):
			if not Array(row.description.split("\n")).all(func(line):return copy.text(line)!=line):untranslated.append(kind+" / "+row.id)
	_check(untranslated.is_empty(),"all implemented candidate descriptions are covered: "+str(untranslated))
	_check(C.SKILLS.values().all(func(skill):return copy.text(skill.description)!=skill.description),"all implemented skill explanations are covered")
	_check(copy.text("DAMAGE / ADJACENT")=="DAMAGE / ADJACENT" and copy.text("VIRSL")=="VIRSL" and copy.text("ARMS-1414141414")=="ARMS-1414141414","names and mechanical labels stay English")
	copy.selection="en"
	_check(copy.text("Damage one adjacent enemy.")=="Damage one adjacent enemy." and copy.text("Move up to 4 cells per turn.")=="Move up to 4 cells per turn.","English source copy remains exact")
## REQ-053-S03、REQ-044-S01
func _test_ui() -> void:
	var game=load("res://main.tscn").instantiate()
	game.settings_path=folder+"/colors.json";game.save_path=folder+"/unused-save.json"
	if game.get("copy_language")!=null:game.preferred_locale_override="en_US"
	root.add_child(game);await process_frame
	game._settings();await process_frame
	var choice=game.auxiliary.find_child("Language",true,false)
	_check(choice is OptionButton,"SETTINGS contains a Language selector")
	if not choice is OptionButton:
		game.queue_free();await process_frame;return
	_check(range(choice.item_count).map(func(i):return choice.get_item_text(i))==["System","English","日本語"],"only the three explicit language choices are shown")
	var reference=game._objective_label(game,"DEFEAT A / KEEP 01 ALIVE",Rect2(0,0,210,120),17,game.WHITE)
	var badges_fit=true
	for line in range(reference.paragraph.get_line_count()):
		for key in reference.paragraph.get_line_objects(line):
			badges_fit=badges_fit and reference.paragraph.get_line_object_rect(line,key).size.y>=17*game.T.OBJECTIVE_REF_CREST_SCALE*2
	_check(badges_fit,"inline identity crests fit their shaped text objects without clipping")
	reference.queue_free()
	game.collection.unit_names[0]="Damage one adjacent enemy."
	game._close_aux();game._build();game._settings()
	var before=game.collection.snapshot()
	var palette=game.palette_colors.duplicate()
	_check(game._change_language("ja") and game.collection.snapshot()==before and game.name_edit.text=="Damage one adjacent enemy.","switching copy does not translate names or change builds")
	_check(not FileAccess.file_exists(game.settings_path) and game.palette_colors==palette,"language choice never writes color settings")
	game._help();await process_frame
	_check(game.auxiliary.find_children("*","Label",true,false).any(func(label):return label.text.contains("INFは攻撃と回復")),"open HELP uses Japanese prose")
	_check(game.auxiliary.find_children("*","Label",true,false).any(func(label):return label.text=="HELP"),"HELP heading stays English")
	var snapshot=game.collection.snapshot();game._close_aux();game._start_battle()
	game._cell_input(Vector2i(4,4));var units=game.battle.units.duplicate(true);var path=game.battle.path.duplicate();var turn=game.battle.turn;var selected=game.selected
	game._settings();await process_frame
	var layer=game.auxiliary
	_check(game._change_language("en") and game.auxiliary==layer and game.battle.units==units and game.battle.path==path and game.battle.turn==turn and game.selected==selected,"live settings switch preserves the menu, route, selection and all combat values")
	var second=load("res://main.tscn").instantiate();second.settings_path=game.settings_path;second.save_path=folder+"/unused-second-save.json";second.preferred_locale_override="ja_JP";root.add_child(second);await process_frame
	_check(second.copy_language.locale()=="en","a new startup honors saved English over Japanese environment")
	second._settings();_check(second._change_language("system") and second.copy_language.locale()=="ja","returning to System follows the Japanese environment")
	var stored=FileAccess.get_file_as_string(second.settings_path+".language.json")
	second._close_aux();second._toggle_debug(true);second._settings();second._change_language("en")
	_check(FileAccess.get_file_as_string(second.settings_path+".language.json")==stored,"debug language selection is not saved")
	second._close_aux();second._toggle_debug(false)
	_check(second.copy_language.selection=="system" and second.copy_language.locale()=="ja","leaving debug restores the normal language choice")
	game._close_aux();game._restart();second.queue_free();game.queue_free();await process_frame
func _check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",note)
