extends SceneTree
const C=preload("res://game/catalog.gd")
const B=preload("res://game/battle.gd")
var checks=0
var failures=0
func _initialize() -> void:_run.call_deferred()
## REQ-018-S07、REQ-018-S08
func _run() -> void:
	var probe=load("res://tests/skill_pattern_audit.gd").new()
	var game=load("res://tests/rotation_field_audit.gd").new() if probe.has_method("_field_view") else probe
	if game!=probe:probe.free()
	game.save_path="res://artifacts/runtime/field-ui-no-save.json"
	game.settings_path="res://artifacts/runtime/field-ui-no-settings.json"
	root.add_child(game)
	await process_frame
	game._clear_overlay()
	await process_frame
	game.build_open=false
	game.battle=B.new()
	game.battle.start(0,C.player_builds(),1)
	game.battle.panels={}
	game.battle.actor=0
	game.battle.units[0].pos=Vector2i(4,4)
	game.battle.units[0].skills=[C.GUARD]
	if C.SKILLS.has("PASSIVE_FIELD_SLOW_ADJACENT"):game.battle.units[0].skills.append("PASSIVE_FIELD_SLOW_ADJACENT")
	game.battle.units[1].pos=Vector2i(8,8)
	game.battle.mode="CHOICE"
	game.battle.choose_skill(C.GUARD)
	game._follow_turn()
	game.hover_cell=Vector2i(4,4)
	game.queue_redraw()
	await create_timer(0.08).timeout
	_check(game.target_frames.is_empty() and game._turn_focus_cell()==Vector2i(4,4),"GUARD self target has no full rectangle and keeps ordinary corner focus")
	_check(game.has_method("_field_view"),"UI uses the shared field world")
	if game.has_method("_field_view"):
		var expected=[Vector2i(4,3),Vector2i(3,4),Vector2i(5,4),Vector2i(4,5)]
		_check(_keys(game._field_view().cells.keys())==_keys(expected) and game.field_clouds.size()==4,"exact four-cell coverage is drawn once below units")
		var hint=game.panel_description(Vector2i(5,4))
		_check(hint=="EQUIPMENT x0.5 ON ENTRY\nSLOW / 1","hover explains exactly the actual multiplier and source")
		game.battle.back()
		game.battle.mode="MOVE"
		game.battle.path_click(Vector2i(5,4))
		var before=game.battle.units.duplicate(true)
		var view=game._field_view()
		_check(view.world[0].pos==Vector2i(5,4) and not view.preview.is_empty() and game.battle.units==before,"moving source forecasts coverage without moving actual units")
		game.battle.path=[]
		_check(game._field_view().preview.is_empty() and game._field_view().world==before,"route cancellation restores current coverage")
	var visual=load("res://ui/visuals.gd")
	_check(visual.new().has_method("cloud_shape"),"cloud geometry is procedural and shared")
	if visual.new().has_method("cloud_shape"):
		var rect=Rect2(10,20,100,100)
		var layers=visual.cloud_shape(rect,false)
		_check(not layers.is_empty() and layers.all(func(layer):return layer.points.all(func(point):return rect.has_point(point))),"all cloud vertices stay inside their own cell")
	game._skill_help()
	await process_frame
	var buttons=game.auxiliary.find_children("*","Button",true,false)
	_check(buttons.any(func(button):return button.text=="FIELDS"),"existing skill HELP opens the field rules")
	if game.has_method("_field_help"):
		game._field_help()
		await process_frame
		var text="\n".join(game.auxiliary.find_children("*","Label",true,false).map(func(label):return label.text))
		_check(text.contains("STOP") and text.contains("SLOW") and text.contains("FAST") and text.contains("停止を優先") and text.contains("相殺"),"HELP explains every field and the full overlap rule")
	game._close_aux()
	game._restart()
	_check(game.build_open,"field UI returns BUILD without saving")
	game.queue_free()
	await process_frame
	print("ROTATION FIELD UI: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
func _keys(cells: Array) -> Array:
	var names=cells.map(func(cell):return str(cell));names.sort();return names
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
