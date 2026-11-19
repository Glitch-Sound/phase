## 防御の実描画とクリックを確認する検証専用シーン。
extends "res://tests/utility_capture.gd"
func _initialize() -> void:
	prefix="res://artifacts/runtime/guard-overlay-gpu-"+str(Time.get_unix_time_from_system())
	_run.call_deferred()
## REQ-018-S07、NREQ-001-S01
func _run() -> void:
	game=load("res://tests/skill_pattern_audit.gd").new()
	game.settings_path="res://artifacts/runtime/guard-overlay-gpu-no-settings.json"
	game.save_path="res://artifacts/runtime/guard-overlay-gpu-no-save.json"
	root.add_child(game)
	await process_frame
	for dimensions in [Vector2i(1152,648),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(1200,1600)]:
		root.size=dimensions
		await _utility_fixture(C.GUARD)
		game.battle.units[0].hp=30
		game.battle.units[1].guard_active=true
		game.battle.units[2].guard_active=true
		game.battle.units[2].hp=60
		await _focus_input()
		var hover=InputEventMouseMotion.new()
		hover.position=root.get_final_transform()*game._cell_rect(game.battle.units[0].pos).get_center()
		Input.parse_input_event(hover)
		await process_frame
		await _shot("preview-"+str(dimensions.x)+"x"+str(dimensions.y))
		_check(not game.drawn_text.any(func(record):return record.text=="GUARD") and game.info_text.has("PREVIEW") and not game.battle.units[0].guard_active,"preview is graphic-only and distinct from real defense "+str(dimensions))
		await _focus_input()
		_click(game._cell_rect(game.battle.units[0].pos).get_center())
		await create_timer(0.05).timeout
		_check(game.battle.units[0].guard_active and game.battle.turn==2,"scaled GUARD target remains clickable "+str(dimensions))
		game._follow_turn()
		game.selected=0
		game.hover_cell=Vector2i(-1,-1)
		await _shot("active-"+str(dimensions.x)+"x"+str(dimensions.y))
		game.battle.actor=2
		game.battle.units[2].skills=[C.DAMAGE]
		game.battle.units[2].pos=Vector2i(4,3)
		game.battle.mode="CHOICE"
		game.battle.choose_skill(C.DAMAGE)
		game._follow_turn()
		game.hover_cell=Vector2i(4,4)
		game._hud()
		await _focus_input()
		_click(game._cell_rect(game.battle.units[0].pos).get_center())
		await create_timer(0.05).timeout
		_check(not game.battle.units[0].guard_active,"real attack removes the polygon through the existing state "+str(dimensions))
		await _shot("consumed-"+str(dimensions.x)+"x"+str(dimensions.y))
	await _replay_reference()
	game._restart()
	_check(game.build_open,"GPU workflow returns BUILD")
	game.queue_free()
	await process_frame
	print("GUARD OVERLAY GPU: %d checks / %d failures; %s" % [checks,failures,prefix])
	quit(0 if failures==0 else 1)
## REQ-018-S07
func _replay_reference() -> void:
	root.size=Vector2i(1920,1080)
	game._clear_overlay()
	await process_frame
	game.toasts=[]
	game.cpu_enabled=false
	game.battle=B.new()
	var builds=C.player_builds()
	builds[0].skills=[C.SWAP,C.GUARD,C.IGNORE_PANEL]
	builds[1].skills=[C.PUSH,C.DAMAGE_DIAGONAL_TWO,C.HEAL]
	game.battle.start(0,builds,1)
	game.build_open=false
	var plans=[
		[[Vector2i(3,5)],C.SWAP,1],
		[[Vector2i(4,5),Vector2i(5,5),Vector2i(6,5)],C.PUSH,2],
		[[Vector2i(6,4)],C.DAMAGE,1],
		[[Vector2i(7,6),Vector2i(7,5)],C.DAMAGE,1]
	]
	for plan in plans:
		for cell in plan[0]:
			_check(game.battle.path_click(cell),"reference replay uses legal movement")
		_check(game.battle.commit_path() and game.battle.choose_skill(plan[1]) and game.battle.act(plan[2]),"reference replay uses the real battle API")
	for cell in [Vector2i(4,6),Vector2i(5,6),Vector2i(5,5)]:
		_check(game.battle.path_click(cell),"reference fifth-hand route remains legal")
	_check(game.battle.commit_path() and game.battle.choose_skill(C.GUARD),"reference reaches actual GUARD target selection")
	game._follow_turn()
	game.selected=-1
	game.hover_cell=game.battle.units[0].pos
	game._hud()
	# WMの寸法変更と遅延削除が描画へ反映してから、比較対象のホバーを送る。
	await create_timer(0.2).timeout
	await _focus_input()
	var hover=InputEventMouseMotion.new()
	hover.position=root.get_final_transform()*game._cell_rect(game.battle.units[0].pos).get_center()
	Input.parse_input_event(hover)
	await process_frame
	await _shot("reference-turn05")
	var file=FileAccess.open("res://artifacts/runtime/guard-overlay-reference-state.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"turn":game.battle.turn,"mode":game.battle.mode,"history":game.battle.history,"units":game.battle.units,"forecast":game._utility_preview()},"\t"))
