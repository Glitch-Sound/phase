## 周囲とGUARDの実描画、入力と自動対戦を観測する専用シーン。
extends "res://tests/guard_overlay_capture.gd"
const POLICY=preload("res://game/cpu_policy.gd")
var decisions=[]
var captured=false
func _initialize() -> void:
	prefix="res://artifacts/runtime/eight-fields-gpu-"+str(Time.get_unix_time_from_system())
	_run.call_deferred()
## REQ-018-S07、REQ-018-S08、NREQ-001-S01
func _run() -> void:
	game=load("res://tests/rotation_field_audit.gd").new()
	game.settings_path="res://artifacts/runtime/fields-gpu-no-settings.json"
	game.save_path="res://artifacts/runtime/fields-gpu-no-save.json"
	root.add_child(game)
	await create_timer(0.15).timeout
	for dimensions in [Vector2i(1152,648),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(1200,1600)]:
		root.size=dimensions
		await _utility_fixture(C.GUARD)
		game.battle.units[0].skills=[C.GUARD,C.FIELD_SLOW]
		game.battle.units[1].pos=Vector2i(5,5)
		game.battle.units[1].skills=[C.FIELD_FAST,C.GUARD]
		game.battle.units[2].pos=Vector2i(6,4)
		game.battle.units[2].skills=[C.DAMAGE,C.FIELD_STOP]
		game.battle.units[3].pos=Vector2i(9,9)
		game.battle.units[3].skills=[C.FIELD_SLOW]
		await _focus_input()
		_motion(game.battle.units[0].pos)
		await _shot("guard-"+str(dimensions.x)+"x"+str(dimensions.y))
		_check(game.target_frames.is_empty() and not game.field_clouds.is_empty(),"GUARD uses corners while field coverage is rendered "+str(dimensions))
		await _focus_input()
		_click(game._cell_rect(game.battle.units[0].pos).get_center())
		await create_timer(0.05).timeout
		_check(game.battle.units[0].guard_active,"scaled self target still applies GUARD "+str(dimensions))
		await _focus_input()
		_click(game._cell_rect(Vector2i(5,6)).get_center())
		await create_timer(0.05).timeout
		await _shot("forecast-"+str(dimensions.x)+"x"+str(dimensions.y))
		_check(game.battle.path==[Vector2i(5,6)] and game._field_view().preview.has(Vector2i(4,7)) and game.battle.units[1].pos==Vector2i(5,5),"real route click forecasts the emitter without moving it "+str(dimensions))
		await _focus_input()
		_click(game._cell_rect(game.battle.units[1].pos).get_center())
		await create_timer(0.05).timeout
		_check(game.battle.path.is_empty() and game._field_view().preview.is_empty(),"cancelling a route restores actual field coverage "+str(dimensions))
		game._field_help()
		await create_timer(0.08).timeout
		await _shot("help-"+str(dimensions.x)+"x"+str(dimensions.y))
		var labels=game.auxiliary.find_children("*","Label",true,false)
		_check(labels.all(func(label):return label.get_minimum_size().x<=label.size.x and label.get_minimum_size().y<=label.size.y),"field HELP stays inside allocated text areas "+str(dimensions))
		var close=game.auxiliary.find_children("*","Button",true,false).filter(func(button):return button.text=="CLOSE / ESC")[0]
		await _focus_input()
		_click(close.get_global_rect().get_center())
		await create_timer(0.04).timeout
		_check(game.auxiliary==null,"field HELP closes through actual scaled input "+str(dimensions))
	await _forced_observation()
	await _motion_observation()
	await _battle_observation()
	game._restart()
	_check(game.build_open,"final GPU scene returns BUILD without saving")
	game.queue_free()
	await process_frame
	print("EIGHT FIELDS GPU: %d checks / %d failures; %s" % [checks,failures,prefix])
	quit(0 if failures==0 else 1)
func _motion(cell: Vector2i) -> void:
	var event=InputEventMouseMotion.new()
	event.position=root.get_final_transform()*game._cell_rect(cell).get_center()
	Input.parse_input_event(event)
func _double_click(cell: Vector2i) -> void:
	var event=InputEventMouseButton.new()
	event.position=root.get_final_transform()*game._cell_rect(cell).get_center()
	event.button_index=MOUSE_BUTTON_LEFT
	event.double_click=true
	event.pressed=true
	Input.parse_input_event(event)
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event)
## REQ-018-S08、REQ-035-S08
func _battle_observation() -> void:
	root.size=Vector2i(1920,1080)
	game._clear_overlay()
	await process_frame
	game.collection.skills=C.SKILLS.keys()
	game.collection.builds=C.player_builds()
	game.collection.builds[0].skills=[C.DAMAGE,C.GUARD,C.FIELD_SLOW]
	game.collection.builds[1].skills=[C.DAMAGE,C.GUARD,C.FIELD_FAST]
	game.panel_seed_override=1
	game.cpu_enabled=true
	game.cpu_fast=false
	game._start_battle()
	game.battle.units[2].skills=[C.DAMAGE,C.HEAL,C.FIELD_STOP]
	game.battle.units[3].skills=[C.DAMAGE,C.HEAL,C.FIELD_SLOW]
	await create_timer(0.2).timeout
	var policy=POLICY.new()
	var started=Time.get_ticks_msec()
	while game.battle.result.is_empty() and game.battle.turn<=40 and Time.get_ticks_msec()-started<90000:
		if game.battle.units[game.battle.actor].camp=="ENEMY" or game.cpu_turn.active:
			await create_timer(0.05).timeout
			continue
		var turn=game.battle.turn
		var began=Time.get_ticks_usec()
		var plan=policy.choose(game.battle,[])
		decisions.append({"turn":turn,"plan":plan,"decision_ms":(Time.get_ticks_usec()-began)/1000.0})
		_check(not plan.is_empty(),"field-aware player policy has a legal plan")
		if plan.is_empty():break
		await _focus_input()
		for cell in plan.path:
			_click(game._cell_rect(cell).get_center())
			await process_frame
		if plan.path.is_empty():
			_check(game.battle.wait_turn(),"only trapped unit uses empty-route WAIT")
			continue
		_double_click(plan.path.back())
		await create_timer(0.05).timeout
		_check(game.battle.mode=="CHOICE","real route double-click opens the action dialog")
		if game.battle.mode!="CHOICE":break
		var kind=plan.skill
		if not game.battle.units[game.battle.actor].guard_active and (turn<=2 or (turn>=5 and not captured)):
			kind=C.GUARD
		var text="WAIT" if kind.is_empty() else C.SKILLS[kind].label
		var buttons=game.overlay.find_children("*","Button",true,false).filter(func(button):return button.text==text)
		_check(buttons.size()==1 and not buttons[0].disabled,"chosen action is enabled in the real dialog")
		if buttons.is_empty() or buttons[0].disabled:break
		await _focus_input()
		_click(buttons[0].get_global_rect().get_center())
		await create_timer(0.05).timeout
		if kind.is_empty():continue
		var target=game.battle.actor if kind==C.GUARD else plan.target
		_motion(game.battle.units[target].pos)
		await process_frame
		if turn>=5 and kind==C.GUARD and not captured:
			await _shot("progressed-guard")
			_save_state("res://artifacts/runtime/eight-fields-capture-state.json")
			captured=true
		await _focus_input()
		_click(game._cell_rect(game.battle.units[target].pos).get_center())
		await create_timer(0.05).timeout
		_check(game.battle.turn==turn+1 or not game.battle.result.is_empty(),"target click completes exactly one real hand")
	_save_state("res://artifacts/runtime/eight-fields-gpu-battle.json")
	if not captured:await _shot("progressed-battle")
	print("EIGHT FIELDS BATTLE OBSERVATION ",JSON.stringify({"turn":game.battle.turn,"result":game.battle.result,"captured":captured,"elapsed_ms":Time.get_ticks_msec()-started,"decisions":decisions}))
func _save_state(file_name: String) -> void:
	var file=FileAccess.open(file_name,FileAccess.WRITE)
	file.store_string(JSON.stringify({"turn":game.battle.turn,"mode":game.battle.mode,"result":game.battle.result,"units":game.battle.units,"history":game.battle.history,"decisions":decisions},"\t"))

## REQ-018-S08
func _motion_observation() -> void:
	root.size=Vector2i(1920,1080)
	await _utility_fixture(C.GUARD)
	game.battle.units[0].skills=[C.GUARD,C.FIELD_SLOW]
	game.battle.units[1].skills=[C.FIELD_FAST]
	game.battle.units[2].skills=[C.FIELD_STOP]
	game.battle.units[3].skills=[C.FIELD_SLOW]
	game.cpu_paused=true
	game.field_draw_times=[]
	var before=game.battle.units.duplicate(true)
	var start=game.clock
	await _shot("drift-0")
	await create_timer(1.5).timeout
	await _shot("drift-1")
	await create_timer(1.5).timeout
	await _shot("drift-2")
	_check(game.clock>start and game.battle.units==before,"cloud moves over real time without changing game values")
	game.reduced_motion=true
	var frozen=game.clock
	await create_timer(0.15).timeout
	_check(game.clock==frozen and game.battle.units==before,"reduced motion freezes clouds without game changes")
	game.reduced_motion=false
	game.cpu_paused=false
	var times=game.field_draw_times.duplicate()
	times.sort()
	var stats={"samples":times.size(),"median_ms":times[times.size()/2],"p95_ms":times[mini(times.size()-1,ceili(times.size()*0.95))],"elapsed_s":game.clock-start}
	print("EIGHT FIELD DRAW OBSERVATION ",JSON.stringify(stats))
	var file=FileAccess.open("res://artifacts/runtime/eight-fields-motion.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(stats,"\t"))

## REQ-018-S08、REQ-040-S04
func _forced_observation() -> void:
	root.size=Vector2i(1920,1080)
	for skill in [C.SWAP,C.PUSH]:
		await _utility_fixture(skill)
		game.battle.units[1].pos=Vector2i(5,4) if skill==C.SWAP else Vector2i(7,3)
		game.battle.units[1].skills=[C.FIELD_FAST]
		var target=1 if skill==C.SWAP else 2
		var before=game.battle.units.duplicate(true)
		_motion(game.battle.units[target].pos)
		await process_frame
		var forecast=game._utility_preview()
		_check(not forecast.is_empty() and game.battle.units==before,"forced field preview stays read-only "+skill)
		await _shot("forced-"+skill)
		await _focus_input()
		_click(game._cell_rect(game.battle.units[target].pos).get_center())
		await create_timer(0.05).timeout
		var actual=game.battle.units[target]
		var expected=forecast.units[target]
		_check(actual.pos==expected.pos and actual.gear_angle==expected.gear_angle and actual.arms_angle==expected.arms_angle and actual.core_angle==expected.core_angle and actual.hp==before[target].hp,"actual forced movement matches field prediction "+skill)
