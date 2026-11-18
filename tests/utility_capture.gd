## 実レンダラーの確認用。対象の全条件はutility_skills.gdへ集約する。
extends "res://tests/skill_pattern_capture.gd"
func _initialize() -> void:
	prefix="res://artifacts/runtime/utility-gpu-"+str(Time.get_unix_time_from_system())
	_run.call_deferred()
## REQ-018-S07、NREQ-001-S01
func _run() -> void:
	game=load("res://tests/skill_pattern_audit.gd").new()
	game.settings_path="res://artifacts/runtime/utility-gpu-no-settings.json"
	game.save_path="res://artifacts/runtime/utility-gpu-no-save.json"
	root.add_child(game)
	await process_frame
	game.collection.skills=C.SKILLS.keys()
	game.collection.builds[0].skills=[C.SWAP,C.GUARD,C.IGNORE_PANEL]
	game._build()
	await _shot("build")
	for kind in [C.SWAP,C.PUSH,C.GUARD]:
		await _utility_fixture(kind)
		await _shot(C.SKILLS[kind].effect+"-preview")
		var before=game.battle.units.duplicate(true)
		var target=game.battle.at(game.hover_cell)
		var forecast=game.battle.action_preview(target)
		_check(not forecast.is_empty() and game.battle.units==before,"rendered forecast preserves the live battle "+kind)
		await _focus_input()
		_click(game._cell_rect(game.hover_cell).get_center())
		await create_timer(0.05).timeout
		_check(game.battle.turn==2 and ["pos","core_angle","gear_angle","arms_angle","hp","guard_active"].all(func(field):return game.battle.units[target][field]==forecast.units[target][field]),"viewport action commits shared prediction "+kind)
		await _shot(C.SKILLS[kind].effect+"-result")
	for dimensions in [Vector2i(1152,648),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(1200,1600)]:
		root.size=dimensions
		await _utility_fixture(C.PUSH)
		await _shot("push-"+str(dimensions.x)+"x"+str(dimensions.y))
		var records=game.info_records
		_check(not records.is_empty() and records.all(func(record):return record.position.x+record.typeface.get_string_size(record.text,HORIZONTAL_ALIGNMENT_LEFT,-1,record.font_size).x<=1840),"PUSH description remains inside column "+str(dimensions))
		await _focus_input()
		_click(game._cell_rect(game.hover_cell).get_center())
		await create_timer(0.05).timeout
		_check(game.battle.units[2].pos==Vector2i(6,4),"scaled target click uses the displayed cell "+str(dimensions))
		game._skill_help()
		await create_timer(0.1).timeout
		await _shot("help-"+str(dimensions.x)+"x"+str(dimensions.y))
		var labels=game.auxiliary.find_children("*","Label",true,false)
		_check(labels.all(func(label):return label.get_minimum_size().y<=label.size.y and label.get_minimum_size().x<=label.size.x),"skill HELP fits its allocated labels "+str(dimensions))
		await _focus_input()
		var close=game.auxiliary.find_children("*","Button",true,false).filter(func(button):return button.text=="CLOSE / ESC")
		_click(close[0].get_global_rect().get_center())
		await create_timer(0.05).timeout
		_check(game.auxiliary==null or not is_instance_valid(game.auxiliary),"HELP closes via actual scaled click "+str(dimensions))
	game._restart()
	_check(game.build_open,"GPU workflow returns BUILD without saving")
	game.queue_free()
	await process_frame
	print("UTILITY GPU: %d checks / %d failures; %s" % [checks,failures,prefix])
	quit(0 if failures==0 else 1)
func _utility_fixture(skill: String) -> void:
	game._clear_overlay()
	await process_frame
	game.toasts=[]
	game.battle=B.new()
	game.battle.start(0,C.player_builds(),1)
	game.build_open=false
	game.selected=0
	game.battle.actor=0
	game.battle.panels={Vector2i(5,4):"CLOCKWISE",Vector2i(6,4):"RESET"}
	game.battle.units[0].pos=Vector2i(4,4)
	game.battle.units[0].skills=[skill,C.IGNORE_PANEL]
	game.battle.units[0].moved=1
	game.battle.units[1].pos=Vector2i(5,4) if skill==C.SWAP else Vector2i.ZERO
	game.battle.units[2].pos=Vector2i(5,4) if skill==C.PUSH else Vector2i(8,8)
	game.battle.mode="CHOICE"
	game.battle.choose_skill(skill)
	game._hud()
	game.queue_redraw()
	await create_timer(0.1).timeout
	await _focus_input()
	game.hover_cell=Vector2i(4,4) if skill==C.GUARD else Vector2i(5,4)
	game.queue_redraw()
	await process_frame
