extends SceneTree
const C=preload("res://game/catalog.gd")
const B=preload("res://game/battle.gd")
var checks=0
var failures=0
func _initialize() -> void:
	_run.call_deferred()
## REQ-018-S07
func _run() -> void:
	var game=load("res://tests/skill_pattern_audit.gd").new()
	game.settings_path="res://artifacts/runtime/utility-ui-no-settings.json"
	game.save_path="res://artifacts/runtime/utility-ui-no-save.json"
	root.add_child(game)
	await process_frame
	game.battle=B.new()
	game.battle.start(0,C.player_builds().slice(0,2),1)
	game.build_open=false
	game._clear_overlay()
	game.battle.actor=0
	game.battle.units[0].pos=Vector2i(4,4)
	game.battle.units[1].pos=Vector2i(5,4)
	game.battle.units[0].skills=[C.SWAP,C.GUARD,C.IGNORE_PANEL]
	game.battle.panels={Vector2i(5,4):"CLOCKWISE"}
	game.battle.mode="CHOICE"
	game.battle.units[0].moved=1
	game.battle.choose_skill(C.SWAP)
	var event=InputEventMouseMotion.new()
	event.position=game._cell_rect(Vector2i(5,4)).get_center()
	game._unhandled_input(event)
	var before=game.battle.units.duplicate(true)
	game.queue_redraw()
	await create_timer(0.08).timeout
	_check(game.drawn_text.any(func(record):return record.text=="SWAP"),"target uses the utility name instead of a healing amount")
	_check(game.has_method("_utility_preview"),"UI exposes the shared utility forecast")
	if game.has_method("_utility_preview"):
		var forecast=game._utility_preview()
		_check(forecast.units[0].pos==Vector2i(5,4) and forecast.units[0].core_angle==0.0 and game.battle.units==before,"hover forecast shares movement and passive rules without mutation")
	_check(game.info_text.any(func(text):return text=="SWAP PREVIEW / UNIT P2"),"right detail explicitly identifies projected target state")
	game.battle.act(1)
	game._feedback()
	_check(game.toasts[-1].text=="SWAP","utility feedback is not plus-zero healing")
	game.battle.units[game.battle.actor].guard_active=true
	game.selected=-1
	game.hover_cell=Vector2i(-1,-1)
	game.queue_redraw()
	await create_timer(0.08).timeout
	_check(not game.info_text.any(func(text):return text.begins_with("GUARD / NEXT")),"guard state no longer adds a prose status line")
	game.battle.actor=0
	game.battle.mode="CHOICE"
	game.battle.units[0].guard_active=false
	game.battle.choose_skill(C.GUARD)
	game._follow_turn()
	game.hover_cell=game.battle.units[0].pos
	game.queue_redraw()
	await create_timer(0.08).timeout
	_check(not game.drawn_text.any(func(record):return record.text=="GUARD") and game.info_text.has("PREVIEW / UNIT P1") and not game.battle.units[0].guard_active,"GUARD target uses a graphic-only preview without mutating live defense")
	game.toasts=[]
	game.battle.act(0)
	game._feedback()
	_check(game.battle.units[0].guard_active and not game.toasts.any(func(toast):return toast.text=="GUARD"),"defense activates without a GUARD word toast")
	game._help()
	await process_frame
	_check(game.auxiliary.find_children("*","Button",true,false).any(func(button):return button.text=="SKILLS"),"existing HELP links to the new skill explanations")
	if game.has_method("_skill_help"):
		game._skill_help()
		await process_frame
		var labels=game.auxiliary.find_children("*","Label",true,false).map(func(label):return label.text)
		_check(labels.any(func(text):return text.contains("SWAP") and text.contains("PUSH")) and labels.any(func(text):return text.contains("GUARD")) and labels.any(func(text):return text.contains("CORE") and text.contains("GEAR")),"HELP explains utility scope, guard and normal rotation")
	game._close_aux()
	game._restart()
	_check(game.build_open,"new utility flow returns BUILD without saving")
	game.queue_free()
	await process_frame
	print("UTILITY UI: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
