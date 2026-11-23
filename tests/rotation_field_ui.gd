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
	game.battle.start(0,C.player_builds().slice(0,2),1)
	game.battle.panels={}
	game.battle.actor=0
	game.battle.units[0].pos=Vector2i(4,4)
	game.battle.units[0].display_name="Aster"
	game.battle.units[0].skills=[C.GUARD]
	if C.SKILLS.has("PASSIVE_FIELD_SLOW_ADJACENT"):game.battle.units[0].skills.append("PASSIVE_FIELD_SLOW_ADJACENT")
	game.battle.units[1].pos=Vector2i(8,8)
	game.battle.mode="CHOICE"
	game.battle.units[game.battle.actor].moved=1
	game.battle.choose_skill(C.GUARD)
	game._follow_turn()
	game.hover_cell=Vector2i(4,4)
	game.queue_redraw()
	await create_timer(0.08).timeout
	_check(game.target_frames.is_empty() and game._turn_focus_cell()==Vector2i(4,4),"GUARD self target has no full rectangle and keeps ordinary corner focus")
	_check(game.has_method("_field_view"),"UI uses the shared field world")
	if game.has_method("_field_view"):
		var expected=[Vector2i(3,3),Vector2i(4,3),Vector2i(5,3),Vector2i(3,4),Vector2i(5,4),Vector2i(3,5),Vector2i(4,5),Vector2i(5,5)]
		_check(_keys(game._field_view().cells.keys())==_keys(expected) and game.field_clouds.size()==1 and game._field_view().get("emitters",[]).size()==1,"exact eight-cell coverage has one continuous source cloud below units")
		var hint=game.panel_description(Vector2i(5,4))
		_check(hint=="EQUIPMENT x0.5 ON ENTRY\nSLOW FIELD","hover explains exactly the actual multiplier and source")
		game.battle.back()
		game.battle.mode="MOVE"
		game.battle.path_click(Vector2i(5,4))
		var before=game.battle.units.duplicate(true)
		var view=game._field_view()
		_check(view.world[0].pos==Vector2i(5,4) and not view.preview.is_empty() and game.battle.units==before,"moving source forecasts coverage without moving actual units")
		game.battle.path=[]
		_check(game._field_view().preview.is_empty() and game._field_view().world==before,"route cancellation restores current coverage")
	var visual=load("res://ui/visuals.gd")
	_check(visual.new().has_method("field_cloud_shape"),"cloud geometry is procedural and shared")
	if visual.new().has_method("field_cloud_shape"):
		var rect=Rect2(300,300,300,300)
		var layers=visual.field_cloud_shape(Vector2(450,450),100.0,0.0,0.0,Rect2(0,0,1000,1000),false)
		var corner=visual.field_cloud_shape(Vector2(50,50),100.0,0.0,0.0,Rect2(0,0,1000,1000),false)
		var later=visual.field_cloud_shape(Vector2(450,450),100.0,2.0,0.0,Rect2(0,0,1000,1000),false)
		_check(not layers.is_empty() and not corner.is_empty() and corner.all(func(layer):return Array(layer.points).all(func(point):return Rect2(-0.001,-0.001,1000.002,1000.002).has_point(point))) and layers!=later and layers.all(func(layer):return Array(layer.points).all(func(point):return rect.grow(0.001).has_point(point))) and layers.any(func(layer):return Array(layer.points).any(func(point):return not Rect2(400,400,100,100).has_point(point))),"cloud drifts continuously around its source inside the actual surrounding cells")
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
