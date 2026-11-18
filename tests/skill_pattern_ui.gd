extends SceneTree
const C=preload("res://game/catalog.gd")
const B=preload("res://game/battle.gd")
var checks=0
var failures=0
func _initialize() -> void:
	_run.call_deferred()
## REQ-018-S06
func _run() -> void:
	var game=load("res://tests/skill_pattern_audit.gd").new()
	game.settings_path="res://artifacts/runtime/target-skills-no-settings.json"
	game.save_path="res://artifacts/runtime/target-skills-no-save.json"
	root.add_child(game)
	await process_frame
	game.battle=B.new()
	game.battle.start(0,C.player_builds(),1)
	game.build_open=false
	game.battle.panels={}
	game.battle.units[0].pos=Vector2i(4,4)
	game.battle.units[0].skills=[C.DAMAGE_DIAGONAL_TWO,C.HEAL_ORTHOGONAL_TWO,C.MOVE]
	game.battle.units[2].pos=Vector2i(6,6)
	game.battle.units[1].pos=Vector2i(4,2)
	game.battle.units[1].hp=game.battle.units[1].max_hp-1
	game.battle.mode="CHOICE"
	game.battle.units[0].moved=1
	game._clear_overlay()
	game.battle.choose_skill(C.DAMAGE_DIAGONAL_TWO)
	game.queue_redraw()
	await create_timer(0.08).timeout
	_check(_sorted(game.target_frames)==_sorted([Vector2i(2,2),Vector2i(6,2),Vector2i(6,6),Vector2i(2,6)]),"UI uses exact diagonal-two target cells")
	var negative=game.drawn_text.filter(func(record):return record.text.begins_with("-"))
	_check(negative.size()==1,"new damage has a negative target effect chip")
	game._cell_input(Vector2i(4,5))
	_check(game.message=="Choose a highlighted target. BACK keeps your movement.","invalid target notice does not falsely require adjacency")
	game.battle.back()
	game.battle.choose_skill(C.HEAL_ORTHOGONAL_TWO)
	game.queue_redraw()
	await create_timer(0.08).timeout
	_check(game.drawn_text.any(func(record):return record.text=="+1"),"new heal chip caps at missing HP")
	game.battle.back()
	game._action_dialog()
	await process_frame
	var buttons=game.overlay.find_children("*","Button",true,false)
	_check(buttons.any(func(button):return button.text==C.SKILLS[C.DAMAGE_DIAGONAL_TWO].label and not button.disabled) and buttons.any(func(button):return button.text==C.SKILLS[C.HEAL_ORTHOGONAL_TWO].label and not button.disabled),"action menu exposes the equipped new active patterns")
	game._clear_overlay()
	game._help()
	await process_frame
	var labels=game.auxiliary.find_children("*","Label",true,false)
	_check(labels.any(func(label):return label.text.contains("DIAGONAL") and label.text.contains("ORTHO") and label.text.contains("2")),"HELP explains exact directions and distance")
	game._close_aux()
	game._restart()
	_check(game.build_open,"new target flow returns to BUILD without saving")
	game.queue_free()
	await process_frame
	print("SKILL PATTERN UI: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
func _sorted(values: Array) -> Array:
	var result=values.duplicate()
	result.sort_custom(func(a,b):return a.y<b.y or (a.y==b.y and a.x<b.x))
	return result
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
