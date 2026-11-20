extends SceneTree
var checks=0
var failures=0
func _initialize() -> void:
	_run.call_deferred()
## REQ-033-S02、REQ-018-S03、REQ-010-S02
func _run() -> void:
	var game=load("res://tests/core_panel_audit.gd").new()
	game.settings_path="res://artifacts/runtime/core-panels-no-settings-"+str(Time.get_ticks_usec())+".json"
	root.add_child(game)
	await process_frame
	game.panel_seed_override=128
	game._start_battle()
	await create_timer(0.08).timeout
	var before=game.preview_contours.duplicate(true)
	var generation=game.preview_generation
	game.battle.units[0].core_angle=45.0
	game.queue_redraw()
	await create_timer(0.08).timeout
	_check(game.preview_generation==generation+1 and game.preview_contours!=before,"CORE-only change invalidates circular preview exactly once")
	var copies=game.ring_records.filter(func(record):return record.unit.id=="01")
	_check(copies.size()==4 and copies.all(func(record):return record.unit.get("core_angle",-1)==45),"map, timeline, detail and preview receive the same CORE angle")
	game.queue_redraw()
	await create_timer(0.08).timeout
	_check(game.preview_generation==generation+1,"unchanged CORE retains cache")
	game.battle.panels={Vector2i(4,4):"CLOCKWISE",Vector2i(5,4):"RESET"}
	game._cell_input(Vector2i(4,4))
	await create_timer(0.08).timeout
	_check(game.battle.preview().get("core_angle",-1)==90 and game.battle.units[0].core_angle==45,"CORE SPD30 route predicts 45 degrees without applying it")
	game._cell_input(Vector2i(5,4))
	await create_timer(0.08).timeout
	_check(game.battle.preview().get("core_angle",-1)==0,"later reset returns route preview to battle-start angle")
	var event=InputEventKey.new()
	event.keycode=KEY_ESCAPE
	event.pressed=true
	game._unhandled_input(event)
	await process_frame
	_check(game.battle.path.is_empty() and game.battle.units[0].core_angle==45 and game.battle.preview().core_angle==45,"Escape clears uncommitted CORE operations only")
	game._help()
	await process_frame
	var labels=game.auxiliary.find_children("*","Label",true,false).map(func(label):return label.text)
	_check(labels.has("Each step turns GEAR left and ARMS right.\nPanels turn CORE using SPD, or reset its start angle."),"short HELP retains normal equipment turns and SPD-based CORE rotation or reset")
	_check(not labels.any(func(text):return text.contains("GEAR固定") or text.contains("ARMS ×2") or text.contains("ARMS逆回転")),"old panel meanings are absent from HELP")
	game._close_aux()
	game._restart()
	await process_frame
	_check(game.build_open,"returns to BUILD without saving")
	game.queue_free()
	await process_frame
	print("CORE PANEL UI: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
