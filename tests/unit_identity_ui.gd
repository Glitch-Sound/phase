extends SceneTree
var game
var checks=0
var failures=0
func _initialize() -> void:_run.call_deferred()
## REQ-049-S01
func _run() -> void:
	game=load("res://tests/movement_audit.gd").new();game.save_path="res://artifacts/runtime/unit-identity/ui-save.json";game.settings_path="res://artifacts/runtime/unit-identity/no-settings.json"
	root.add_child(game);await process_frame;game.set_process(false)
	_check(game.get("name_edit") is LineEdit,"BUILD has a compact name editor")
	if game.get("name_edit") is LineEdit:
		var field=game.name_edit
		field.focus_entered.emit();field.text="星屑";field.text_changed.emit(field.text)
		await _draw()
		var preview=game.displayed_rings.filter(func(r):return r.center==Vector2(90,100))
		_check(game.collection.unit_names[0]=="星屑" and preview.size()==1 and preview[0].unit.display_name=="星屑","name edit updates only its live preview")
		var escape=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true;field.gui_input.emit(escape)
		_check(game.collection.unit_names[0]=="Kestrel","Esc restores the value at focus entry")
		field=game.name_edit;field.text="  Aster  Vale  ";field.text_changed.emit(field.text);field.text_submitted.emit(field.text)
		_check(game.collection.unit_names==["Aster Vale","Vesper","Lyra"] and field.text=="Aster Vale","Enter normalizes without changing other slots")
		var original=game.collection.snapshot();game._toggle_debug(true)
		game.name_edit.text="Sandbox";game.name_edit.text_changed.emit("Sandbox");game._toggle_debug(false)
		_check(game.collection.snapshot()==original,"temporary names never overwrite normal names")
		game.collection.unit_names=["Aster","Aster","界".repeat(32)];game._start_battle();await _draw()
		_check(game.battle.units[0].display_name=="Aster" and game.battle.units[1].display_name=="Aster" and game.battle.units[0].id!=game.battle.units[1].id,"battle preserves duplicate names without merging units")
		game.selected=2;await _draw()
		_check(game.displayed_rings.any(func(r):return r.center==game.T.BATTLE_INFO_RING and r.unit.display_name=="界".repeat(32)),"long full name stays attached to its detail glyph")
		var layouts=[]
		for name in ["界".repeat(32),"﷽".repeat(32)]:
			game.battle.units[2].display_name=name;await _draw()
			var lines=game.text_records.filter(func(r):return r.position.x==game.T.BATTLE_NAME_ORIGIN.x and r.position.y<game.T.BATTLE_INFO_CLASS.y)
			layouts.append(lines.size()<=2 and "".join(lines.map(func(r):return r.text))=="P3 / "+name)
		_check(layouts.all(func(ok):return ok),"ordinary and wide Unicode names stay complete within the name region")
		game._help();await process_frame
		var guide=game.auxiliary.find_children("*","Label",true,false).filter(func(label):return label.text.begins_with("Name 3 PLAYER slots."))[0]
		var seed=game.auxiliary.find_children("*","Label",true,false).filter(func(label):return label.text.contains(" / SEED "))[0]
		var close=game.auxiliary.find_children("*","Button",true,false).filter(func(button):return button.text=="CLOSE / ESC")[0]
		_check(guide.global_position.y+guide.get_minimum_size().y<close.global_position.y and not guide.get_global_rect().intersects(seed.get_global_rect()),"name guidance and stage reference stay separated above HELP controls")
		game._close_aux()
	game._restart();game.queue_free();await process_frame
	print("UNIT IDENTITY UI: %d checks / %d failures" % [checks,failures]);quit(0 if failures==0 else 1)
func _draw() -> void:
	game.queue_redraw();if is_instance_valid(game.build_preview):game.build_preview.queue_redraw()
	await process_frame;await create_timer(0.02).timeout
func _check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",note)
