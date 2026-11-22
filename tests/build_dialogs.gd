extends SceneTree
var checks=0
var failures=0
var game
class AuditUI:
	extends "res://ui/main.gd"
	var dialog_rings=[]
	var operation_icons=[]
	func _reference_emblem(canvas: CanvasItem,center: Vector2,radius: float,u: Dictionary) -> void:
		if is_instance_valid(build_dialog) and canvas==build_dialog.preview_area:operation_icons.append({"unit":u.duplicate(true),"profile":_assembly_profile(u.camp).duplicate(true)})
		V.unit_emblem(canvas,center,radius,u,_assembly_profile(u.camp))
	func _ring(canvas: CanvasItem,center: Vector2,radius: float,u: Dictionary,active: bool=false) -> void:
		if is_instance_valid(build_dialog) and canvas==build_dialog.preview_area:dialog_rings.append(u.duplicate(true))
		super._ring(canvas,center,radius,u,active)
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	game=AuditUI.new()
	game.save_path="res://artifacts/runtime/build-dialog-test-save.json"
	game.settings_path="res://artifacts/runtime/build-dialog-test-settings.json"
	root.add_child(game)
	await process_frame
	_check(game.has_method("_open_build_choice"),"shared BUILD selection entry exists")
	if game.has_method("_open_build_choice"):
		await _slot_switch()
		await _compact_content()
		await _dialogs()
		await _keyboard()
		await _class_selection()
		await _mutation_selection()
		await _presentation()
		await _operation_symbols()
		await _layout_alignment()
	game.queue_free()
	await process_frame
	print("BUILD DIALOGS: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
## REQ-042-S01、REQ-014-S02、REQ-024-S01
func _dialogs() -> void:
	var before=game.collection.snapshot()
	var choice=game.C.serial("ARMS",[20,30,10,20,20])
	var origin=game.overlay.find_children("*","Button",true,false).filter(func(b):return b.get_meta("build_choice","")=="arms")[0]
	origin.grab_focus()
	game._open_build_choice("arms")
	await process_frame
	var dialog=game.build_dialog
	dialog.scroll.scroll_vertical=500
	dialog._filter(1)
	await process_frame
	await process_frame
	_check(dialog.scroll.scroll_vertical==0,"filter restarts at the highest matching stat")
	_check(dialog.filter_buttons[2].get_theme_stylebox("normal").border_width_bottom>0 and dialog.filter_buttons[0].get_theme_stylebox("normal").border_width_bottom==0,"filter underline follows selected stat")
	_check(dialog.select_candidate(choice) and game.collection.snapshot()==before and dialog.candidate_build.arms==[20,30,10,20,20],"selection previews actual build without committing")
	dialog.cancel()
	await process_frame
	_check(game.collection.snapshot()==before and not is_instance_valid(game.auxiliary) and game.get_viewport().gui_get_focus_owner()==origin,"cancel discards preview and returns focus")
	game._open_build_choice("arms")
	await process_frame
	game.build_dialog.select_candidate(choice)
	game.build_dialog.confirm()
	await process_frame
	_check(game.collection.builds[0].arms==[20,30,10,20,20] and not is_instance_valid(game.auxiliary),"APPLY commits and closes")
	var focused=game.get_viewport().gui_get_focus_owner()
	_check(is_instance_valid(focused) and focused.get_meta("build_choice","")=="arms","APPLY returns focus to the rebuilt originating control")
	_check(game._equipment_values([25,15,20,30,10],[20,20,20,20,20])==["25","15","20","30","10"],"readout contains values without bracket deltas")
	for kind in ["class_name","gear","arms_mutation","gear_mutation","skill","operation"]:
		game._open_build_choice(kind,2 if kind=="skill" else 0)
		await process_frame
		_check(is_instance_valid(game.build_dialog) and game.build_dialog.kind==kind and game.build_dialog.rows.size()>0,"common dialog is connected: "+kind)
		game.build_dialog.cancel()
		await process_frame
## REQ-042-S05
func _keyboard() -> void:
	game._open_build_choice("arms")
	await process_frame
	var dialog=game.build_dialog
	var before=game.collection.snapshot()
	var key=InputEventKey.new();key.keycode=KEY_END;key.pressed=true
	dialog.navigate(key)
	_check(dialog.selected_id==dialog.rows.filter(func(r):return r.selectable)[-1].id and game.collection.snapshot()==before,"End reaches final available candidate without committing")
	var esc=InputEventKey.new();esc.keycode=KEY_ESCAPE;esc.pressed=true
	game._unhandled_input(esc)
	await process_frame
	_check(not is_instance_valid(game.auxiliary) and game.collection.snapshot()==before,"Esc closes dialog without mutation")
## REQ-041-S01、REQ-044-S01、REQ-019-S14
func _presentation() -> void:
	var layout_fields=game.overlay.find_children("*","Button",true,false).filter(func(b):return b.get_meta("build_choice","") in ["class_name","arms_mutation","gear_mutation"])
	_check(layout_fields.size()==3 and layout_fields.all(func(b):return b.text=="VIRSL" and b.get_children().any(func(child):return child is Label and child.text=="STANDARD" and child.get_theme_font_size("font_size")<b.get_theme_font_size("font_size"))),"CLASS and mutation use VIRSL with a smaller STANDARD caption")
	var toggles=game.overlay.find_children("*","CheckButton",true,false)
	_check(toggles.map(func(c):return c.text).has("UNLOCK ALL") and toggles.map(func(c):return c.text).has("ENEMY CPU"),"unlock and CPU share toggle control")
	var start=game.overlay.find_children("*","Button",true,false).filter(func(b):return b.text=="START")[0]
	_check(start.alignment==HORIZONTAL_ALIGNMENT_CENTER,"START label is centered")
	_check(start.icon==null or start.icon_alignment!=HORIZONTAL_ALIGNMENT_CENTER,"START icon does not overlap the centered label")
	var content_width=start.get_theme_font("font").get_string_size(start.text,HORIZONTAL_ALIGNMENT_LEFT,-1,start.get_theme_font_size("font_size")).x+start.get_theme_constant("icon_max_width")+start.get_theme_constant("h_separation")
	for state in ["normal","hover","pressed","focus","disabled"]:
		var style=start.get_theme_stylebox(state)
		_check(is_equal_approx(style.content_margin_left,style.content_margin_right) and absf(2*style.content_margin_left+content_width-start.size.x)<1.0,"START icon and text share a centered content area: "+state)
	var cpu=toggles.filter(func(c):return c.text=="ENEMY CPU")[0]
	var unlock=toggles.filter(func(c):return c.text=="UNLOCK ALL")[0]
	var unit_end=game.overlay.find_children("*","Button",true,false).filter(func(b):return b.text=="SLOT 3")[0].get_global_rect().end.x
	var group_gap=cpu.global_position.x-unlock.get_global_rect().end.x
	_check(group_gap>0 and unlock.global_position.x-unit_end>group_gap and is_equal_approx(cpu.get_global_rect().end.x,start.get_global_rect().end.x),"right-aligned toggles form a closer group than the unit selection gap")
	var cpu_label_left=cpu.get_global_rect().end.x-cpu.get_theme_stylebox("normal").content_margin_right-cpu.get_theme_icon("unchecked").get_width()-cpu.get_theme_constant("h_separation")-cpu.get_theme_font("font").get_string_size(cpu.text,HORIZONTAL_ALIGNMENT_LEFT,-1,cpu.get_theme_font_size("font_size")).x
	var visible_gap=cpu_label_left-(unlock.get_global_rect().end.x-unlock.get_theme_stylebox("normal").content_margin_right)
	for toggle in [unlock,cpu]:
		var state=toggle.get_children().filter(func(child):return child is Label)[0]
		var switch_left=toggle.size.x-toggle.get_theme_stylebox("normal").content_margin_right-toggle.get_theme_icon("unchecked").get_width()
		var separation=toggle.get_theme_constant("h_separation")
		_check(toggle.alignment==HORIZONTAL_ALIGNMENT_RIGHT and separation>state.size.x and separation<visible_gap and is_equal_approx(switch_left-state.get_rect().end.x,(separation-state.size.x)/2),"toggle label and state sit together beside switch: "+toggle.text)
	_check(cpu.get_rect()==game.T.BUILD_CPU_TOGGLE_RECT and unlock.get_rect()==game.T.DEBUG_TOGGLE_RECT,"compact contents preserve full toggle click regions")
	var cpu_rect=cpu.get_global_rect()
	game.debug_session.allowed=false
	game._build()
	await process_frame
	var release_toggles=game.overlay.find_children("*","CheckButton",true,false)
	_check(release_toggles.size()==1 and release_toggles[0].text=="ENEMY CPU" and release_toggles[0].get_global_rect()==cpu_rect,"without debug entry CPU stays right-aligned and no empty control remains")
	game.debug_session.allowed=true
	game._build()
	await process_frame
	var text=FileAccess.get_file_as_string("res://ui/main.gd")
	_check(text.contains('_text("PREVIEW",'),"PREVIEW heading is drawn")
## REQ-045-S04
func _layout_alignment() -> void:
	var original=game.collection.snapshot()
	var baselines={}
	var kinds=["class_name","arms_mutation","gear_mutation"]
	for kind in kinds:
		var field=game.overlay.find_children("*","Button",true,false).filter(func(b):return b.get_meta("build_choice","")==kind)[0]
		var title=field.get_parent().get_children().filter(func(child):return child is Label and child.text==("CLASS" if kind=="class_name" else "MUTATION") and absf(child.global_position.y-field.global_position.y)<40)[0]
		var baseline=field.global_position.y+(field.size.y-field.get_theme_font("font").get_height(field.get_theme_font_size("font_size")))/2+field.get_theme_font("font").get_ascent(field.get_theme_font_size("font_size"))
		baselines[kind]=baseline
		var labels=[title]+field.get_children().filter(func(child):return child is Label and child.text=="STANDARD")
		_check(labels.size()==2 and labels.all(func(label):return is_equal_approx(label.global_position.y+label.get_theme_font("font").get_ascent(label.get_theme_font_size("font_size")),baseline)) and field.get_theme_stylebox("normal").content_margin_top==field.get_theme_stylebox("normal").content_margin_bottom,"layout title, code and STANDARD share one baseline: "+kind)
	if not game.collection.mutations.has("LSRIV"):game.collection.mutations.append("LSRIV")
	for kind in kinds:game.collection.builds[0][kind]="LSRIV"
	game._build()
	await process_frame
	var fields=game.overlay.find_children("*","Button",true,false).filter(func(b):return b.get_meta("build_choice","") in kinds)
	_check(fields.all(func(field):return field.text=="LSRIV" and not field.get_children().any(func(child):return child is Label and child.text=="STANDARD") and is_equal_approx(field.global_position.y+(field.size.y-field.get_theme_font("font").get_height(field.get_theme_font_size("font_size")))/2+field.get_theme_font("font").get_ascent(field.get_theme_font_size("font_size")),baselines[field.get_meta("build_choice")])),"without STANDARD each main code retains its baseline")
	game.collection.builds=original.builds.duplicate(true)
	game.collection.mutations=original.mutations.duplicate()
	game._build()
	await process_frame
## REQ-042-S01、REQ-042-S03
func _class_selection() -> void:
	game.collection.mutations.append("LSRIV")
	var before=game.collection.snapshot()
	game._open_build_choice("class_name")
	await process_frame
	var dialog=game.build_dialog
	var standard=dialog.row_buttons.get("VIRSL")
	_check(standard!=null and standard.text.begins_with("VIRSL") and standard.get_children().any(func(child):return child is Label and child.text=="STANDARD" and child.get_theme_font_size("font_size")<standard.get_theme_font_size("font_size")),"standard dialog row shows the placement code and small caption")
	_check(dialog.select_candidate("LSRIV") and dialog.candidate_build.class_name=="LSRIV" and game.collection.snapshot()==before,"CLASS selection previews without changing original")
	dialog.cancel()
	await process_frame
	_check(game.collection.snapshot()==before,"CLASS cancel keeps original")
	game._open_build_choice("class_name")
	await process_frame
	game.build_dialog.select_candidate("LSRIV");game.build_dialog.confirm()
	await process_frame
	var field=game.overlay.find_children("*","Button",true,false).filter(func(b):return b.get_meta("build_choice","")=="class_name")[0]
	_check(game.collection.builds[0].class_name=="LSRIV" and field.text=="LSRIV" and game.collection.builds[0].gear==before.builds[0].gear and game.collection.builds[0].arms==before.builds[0].arms,"CLASS APPLY updates the code and leaves equipment unchanged")
	game.collection.builds=before.builds.duplicate(true)
	game._build()
	await process_frame
## REQ-014-S02
func _slot_switch() -> void:
	var original=game.collection.builds.duplicate(true)
	for index in [0,1,2,0]:
		var button=game.overlay.find_children("*","Button",true,false).filter(func(b):return b.text=="SLOT "+str(index+1))[0]
		button.pressed.emit();await process_frame;await process_frame
		var selected=game.overlay.find_children("*","Button",true,false).filter(func(b):return b.text.begins_with("SLOT ") and b.get_theme_stylebox("normal").get_border_width(SIDE_BOTTOM)>0)
		_check(game.edit_unit==index and selected.size()==1 and selected[0].text=="SLOT "+str(index+1) and root.gui_get_focus_owner()==selected[0],"SLOT selection, focus and editing agree: "+str(index))
		game.core_controls[0].value=[25,35,45][index]
	_check(game.collection.builds.map(func(b):return int(b.core[0]))==[25,35,45],"each visible slot edits its own CORE")
	var path="res://artifacts/runtime/slot-roundtrip-"+str(Time.get_ticks_usec())+".json";var previous=game.save_path;game.save_path=path
	game._save();game.collection.builds=original.duplicate(true);game._load();await process_frame
	_check(game.collection.builds.map(func(b):return int(b.core[0]))==[25,35,45],"SAVE and LOAD preserve the three independent slots")
	game.save_path=previous;game.collection.builds=original;game._build();await process_frame
## REQ-042-S03、REQ-042-S04、REQ-042-S06
func _compact_content() -> void:
	var guide="Select a candidate. Apply to confirm. Esc to cancel."
	for kind in ["class_name","arms_mutation","gear_mutation","skill","operation","arms","gear"]:
		game._open_build_choice(kind);await process_frame;await process_frame
		var d=game.build_dialog
		var labels=d.find_children("*","Label",true,false).map(func(node):return node.text)
		_check(labels.has(guide)==(kind in ["arms","gear"]),"only the specified selection guides are removed: "+kind)
		if kind in ["class_name","arms_mutation","gear_mutation"]:
			for row in [["VIRSL",[0,1,2,3,4]],["VLSRI",[0,4,3,2,1]]]:
				var squares=d.row_buttons["NORMAL" if kind!="class_name" and row[0]=="VIRSL" else row[0]].get_children().filter(func(node):return node is ColorRect)
				_check(squares.map(func(node):return node.color)==row[1].map(func(i):return game.status_colors[i]),"five squares follow the actual selected ring and status colors: "+kind+row[0])
			_check(d.description.text.is_empty() and not d.row_buttons.values().any(func(b):return b.text.contains("CORE order") or b.text.contains(" > ")),"CLASS has no redundant order paragraphs")
		elif kind=="skill":
			game.dialog_rings=[];d.preview_area.queue_redraw();await process_frame;await process_frame
			_check(game.dialog_rings.is_empty() and not d.description.text.is_empty(),"SKILL keeps the effect description and draws no current or candidate rings")
		game._close_aux();await process_frame
	game._open_assembly();await process_frame
	var text=game.assembly_dialog.find_children("*","Label",true,false).map(func(node):return node.text)
	_check(not text.has("A shared crest and color for your units.") and not text.has("Names may repeat. Your ownership mark stays separate."),"ASSEMBLY omits the two specified paragraphs")
	game._close_aux();await process_frame
## REQ-042-S01、REQ-042-S03、REQ-042-S06
func _mutation_selection() -> void:
	var original=game.collection.snapshot()
	if not game.collection.mutations.has("LSRIV"):game.collection.mutations.append("LSRIV")
	for kind in ["arms_mutation","gear_mutation"]:
		var before=game.collection.snapshot()
		game._open_build_choice(kind);await process_frame
		var d=game.build_dialog
		_check(d.select_candidate("LSRIV") and game.collection.snapshot()==before and d.candidate_build[kind]=="LSRIV","mutation previews without applying: "+kind)
		var squares=d.row_buttons["LSRIV"].get_children().filter(func(node):return node is ColorRect)
		_check(squares.map(func(node):return node.color)==[4,3,2,1,0].map(func(i):return game.status_colors[i]),"mutation swatches follow the actual nonstandard order: "+kind)
		d.cancel();await process_frame
		_check(game.collection.snapshot()==before,"mutation cancel leaves all data unchanged: "+kind)
		game._open_build_choice(kind);await process_frame;game.build_dialog.select_candidate("LSRIV");game.build_dialog.confirm();await process_frame
		var expected=before.builds.duplicate(true);expected[game.edit_unit][kind]="LSRIV"
		_check(game.collection.builds==expected,"mutation APPLY changes only its intended ring: "+kind)
	game.collection.builds=original.builds.duplicate(true);game.collection.mutations=original.mutations.duplicate();game._build();await process_frame
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)

## REQ-042-S04
func _operation_symbols() -> void:
	game._open_build_choice("operation");await process_frame
	var d=game.build_dialog
	_check(d.has_method("operation_symbols"),"operation diagram exposes the same actual unit references as the description")
	if d.has_method("operation_symbols"):
		for id in ["0","1"]:
			d.select_candidate(id)
			var symbols=d.operation_symbols()
			game.operation_icons=[];d.preview_area.queue_redraw();await process_frame;await process_frame
			_check(game.operation_icons.map(func(row):return row.unit.id)==["01","02","03","A","B","C"] and game.operation_icons.all(func(row):return row.profile==game._assembly_profile(row.unit.camp)) and symbols.all(func(row):return row.unit==game._reference_unit(row.unit.id)),"diagram uses the actual six unit shapes and camps: "+id)
			var description=game.C.stages()[int(id)].brief
			_check(description==("ELIMINATE ALL ENEMY UNITS: A B C" if id=="0" else "DEFEAT A / KEEP 01 ALIVE"),"objective symbols have unambiguous all-enemy or protected-role meaning: "+id)
	d.cancel();await process_frame
