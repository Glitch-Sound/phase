extends SceneTree
var game
var checks=0
var failures=0
func _initialize() -> void:_run.call_deferred()
## REQ-051-S01、REQ-019-S12、REQ-031-S02、REQ-031-S03
func _run() -> void:
	game=load("res://tests/assembly_audit.gd").new();game.save_path="res://artifacts/runtime/assembly-identity/ui-no-save.json";game.settings_path="res://artifacts/runtime/assembly-identity/ui-no-settings.json"
	root.add_child(game);await process_frame;game.set_process(false)
	_check(game.get("assembly_button") is Button,"BUILD has compact assembly entry")
	if game.get("assembly_button") is Button:
		var before=game.collection.snapshot();game._open_assembly();await process_frame
		var dialog=game.assembly_dialog;dialog.name_edit.text="  星環  ";dialog.name_edit.text_changed.emit(dialog.name_edit.text);dialog.choose_color("ICE")
		_check(dialog.candidate=={"name":"星環","color":"ICE","version":1} and game.collection.snapshot()==before,"editing previews a canonical draft without touching collection")
		dialog.cancelled.emit();await process_frame
		_check(game.collection.snapshot()==before and not is_instance_valid(game.auxiliary),"cancel preserves normal data")
		game._open_assembly();await process_frame;dialog=game.assembly_dialog;dialog.name_edit.text="星環";dialog.name_edit.text_changed.emit("星環");dialog.choose_color("ICE");dialog.confirm();await process_frame;await process_frame
		_check(game.collection.assembly=={"name":"星環","color":"ICE","version":1} and game.get_viewport().gui_get_focus_owner()==game.assembly_button,"apply stores profile and restores entry focus")
		game.opponent_assembly=game.collection.assembly.duplicate(true);game.collection.unit_names=["Same","Same","P1"];game._start_battle();await _draw()
		var rows=game._assembly_rows()
		_check(rows.size()==2 and rows[0].bar.position.x==rows[1].bar.position.x and rows[0].bar.size==rows[1].bar.size and rows[0].text_origin.x==rows[1].text_origin.x and rows.all(func(r):return is_equal_approx(r.emblem.get_center().y,r.bar.get_center().y) and is_equal_approx(r.center_y,r.text_origin.y-(game.mono.get_ascent(game.T.BATTLE_HP_FONT_SIZE)-game.mono.get_descent(game.T.BATTLE_HP_FONT_SIZE))/2)),"both assembly HP rows share columns and vertical centers")
		var clean_name=game.displayed_text.all(func(text):return not text.contains("Same") and not text.contains("P1"))
		game.selected=2;await _draw()
		_check(clean_name and not game.displayed_text.has("P1") and game.battle.units[2].display_name=="P1","battle uses symbols only while user-supplied names remain unmodified in data")
		var own_ids=game.ownership_marks.map(func(r):return r.unit.id);own_ids.sort()
		_check(game.displayed_assemblies.any(func(r):return r.center==game.T.ASSEMBLY_INFO_CENTER and r.profile==game.collection.assembly and r.camp=="PLAYER") and own_ids==["01","02","03"] and game.ownership_marks.all(func(r):return game._cell_rect(r.unit.pos).grow(-2*game.T.UI_FOCUS_LINE).encloses(Rect2(r.center-Vector2.ONE*game.T.OWNER_MARK_RADIUS,Vector2.ONE*game.T.OWNER_MARK_RADIUS*2)) and r.center.distance_to(game._cell_rect(r.unit.pos).get_center())>game.T.UNIT_BOARD_RADIUS*game.BOARD_SCALE+game.T.OWNER_MARK_RADIUS),"detail crest and ownership connect to the correct assembly")
		game.view_camp="ENEMY";game.selected=3;await _draw()
		own_ids=game.ownership_marks.map(func(r):return r.unit.id);own_ids.sort()
		_check(own_ids==["A","B","C"] and game.displayed_assemblies.any(func(r):return r.center==game.T.ASSEMBLY_INFO_CENTER and r.camp=="ENEMY"),"same-color and same-crest camps keep viewpoint ownership and detail correspondence")
		game.battle.mode="CHOICE";game._action_dialog();await process_frame
		var badges=game.overlay.find_children("*","Control",true,false).filter(func(node):return node.has_meta("unit_id"))
		var texts=game.overlay.find_children("*","Label",true,false).map(func(label):return label.text)
		_check(badges.size()==1 and badges[0].get_meta("unit_id")==game.battle.units[game.battle.actor].id and badges[0].accessibility_name=="Same" and texts==["ACTION"],"action header uses a unit crest and retains its name only as nonvisual accessibility metadata")
		game._clear_overlay();game.battle.mode="MOVE"
		var unit=game.battle.units[0].duplicate(true);var original=game.collection.snapshot()
		game._restart();game._toggle_debug(true);game.collection.assembly.name="Temporary";game._toggle_debug(false);await process_frame
		_check(game.battle.units[0].id==unit.id and game.collection.snapshot()==original,"display settings preserve immutable identity and normal snapshot")
	game._restart();game.queue_free();await process_frame
	print("ASSEMBLY IDENTITY UI: %d checks / %d failures" % [checks,failures]);quit(0 if failures==0 else 1)
func _draw() -> void:
	game.queue_redraw();await process_frame;await create_timer(0.02).timeout
func _check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",note)
