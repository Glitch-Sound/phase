extends "res://tests/cpu_capture.gd"
## REQ-010-S03、REQ-010-S04、REQ-018-S01、REQ-018-S03、REQ-018-S04、REQ-018-S05、REQ-019-S13
## 現行ルールの入力接続を検査し、手動戦の固定結果はartifactsの観測記録へ分離する。
func _run() -> void:
	game=load("res://tests/side_info_audit.gd").new()
	game.battle=game.B.new()
	game.settings_path="res://artifacts/runtime/tempo-gpu-no-settings-"+stamp+".json"
	game.save_path="res://artifacts/runtime/tempo-gpu-no-save-"+stamp+".json"
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.panel_seed_override=1
	for dimensions in [Vector2i(1152,648),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(1200,1600)]:
		root.size=dimensions
		await process_frame
		await create_timer(0.2).timeout
		for attempt in range(60):
			if root.has_focus() and game.window_focused:
				break
			root.grab_focus()
			await create_timer(0.02).timeout
		await _focus_input()
		game.cpu_enabled=false
		game._start_battle()
		await process_frame
		var before=game.battle.units.duplicate(true)
		_click_cell(Vector2i(4,4))
		_click_cell(Vector2i(4,4),true)
		await process_frame
		_check(game.battle.mode=="CHOICE","resized actual path commit "+str(dimensions))
		_click_button(game.overlay,"BACK")
		await process_frame
		_check(game.battle.mode=="MOVE" and game.battle.units==before and game.battle.history.is_empty() and game.battle.path==[Vector2i(4,4)],"resized actual BACK exactly restores "+str(dimensions))
		_click_cell(Vector2i(4,4),true)
		await process_frame
		var key=InputEventKey.new()
		key.keycode=KEY_ESCAPE
		key.pressed=true
		root.push_input(key,false)
		await process_frame
		_check(game.battle.mode=="MOVE" and game.battle.units==before and game.battle.history.is_empty(),"resized actual Esc restores "+str(dimensions))
		for actor in range(4):
			game.battle.start(0,game.collection.builds,1)
			game.battle.actor=actor
			game.selected=-1
			game.timeline_hover=(actor+2)%4
			game.battle.units[actor].pos=Vector2i(0,0) if actor%2==0 else Vector2i(9,9)
			await _picture("focus-"+str(dimensions.x)+"-"+str(dimensions.y)+"-"+str(actor))
			_check(game._turn_focus_cell()==game.battle.units[actor].pos,"GPU uses existing movement focus on actor "+str(actor))
			var shown=root.get_texture().get_image()
			game.hide_cell_focus=true
			game.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var hidden=root.get_texture().get_image()
			_check(shown.get_data()!=hidden.get_data(),"actual GPU corner focus is visible "+str(actor))
			game.hide_cell_focus=false
		if dimensions==Vector2i(1920,1080):
			var colors=game.palette_colors.duplicate()
			game.palette_colors=game.P.PRESETS.AMBER.duplicate()
			game._set_theme()
			await _picture("amber-focus")
			game.palette_colors=colors
			game._set_theme()
		game._start_battle()
		_click_cell(Vector2i(4,4))
		_click_cell(Vector2i(4,4),true)
		await process_frame
		await _picture("action-"+str(dimensions.x)+"-"+str(dimensions.y))
		var panel=game.overlay.get_child(1)
		var content=Rect2(root.get_final_transform()*Vector2.ZERO,Vector2(1920,1080)*root.get_final_transform().get_scale())
		_check(content.encloses(Rect2(root.get_final_transform()*panel.position,panel.size*root.get_final_transform().get_scale())),"ACTION fits actual content area "+str(dimensions))
		game._reselect_path()
		await process_frame
	root.size=Vector2i(1920,1080)
	await process_frame
	await _focus_input()
	game.cpu_enabled=true
	game._start_battle()
	await process_frame
	# この再生は現在のルールへの入力接続を検査する。過去の勝敗やHPへ固定しない。
	var captured=false
	var memory=[]
	for hand in range(24):
		for tick in range(300):
			if not game._cpu_locked(): break
			game._process(0.1)
			await process_frame
		if not game.battle.result.is_empty(): break
		_check(not game._cpu_locked(),"CPU presentation releases the input lock")
		if game._cpu_locked(): break
		game._follow_turn()
		_check(game.selected==-1 and game._turn_focus_cell()==game.battle.units[game.battle.actor].pos,"current hand uses actor focus without stale inspection")
		if hand>=4 and not captured:
			await _picture("progress-battle")
			captured=true
		var before=[game.battle.turn,game.battle.actor,game.battle.units[game.battle.actor].next_time]
		var plan=game.cpu_policy.choose(game.battle,memory)
		_check(not plan.is_empty(),"current public state has a legal input plan")
		if plan.is_empty(): break
		for cell in plan.path:
			_click_cell(cell)
			await process_frame
		if not plan.path.is_empty():
			_click_cell(plan.path.back(),true)
			await process_frame
		if game.battle.result.is_empty():
			if plan.skill.is_empty():
				_click_button(game.hud if plan.path.is_empty() else game.overlay,"WAIT")
			else:
				_click_button(game.overlay,game.C.SKILLS[plan.skill].label)
				await process_frame
				_click_cell(game.battle.units[plan.target].pos)
			await process_frame
		_check(_step_contract(game.battle,before),"actual input preserves HP bounds and one-hand progression or result")
		memory.append({"actor":before[1],"pos":game.battle.units[before[1]].pos,"skill":plan.skill,"target":plan.target})
		memory=memory.slice(-game.T.CPU_MEMORY_LIMIT)
	if not captured: await _picture("progress-battle")
	print("GPU BALANCE OBSERVATION ",game.battle.turn," / ",game.battle.result," / ",game.battle.units.map(func(u):return u.hp))
	game._restart()
	await process_frame
	_check(game.build_open,"GPU decisions end BUILD without saving")
	print("TURN TEMPO GPU: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
func _picture(tag: String) -> void:
	# 人の入力より速い再生で蓄積した通知を、通常の経過処理で完了させる。
	# 手番とHPは変えず、実画面で操作を止めて読む状態と揃える。
	var before=[game.battle.turn,game.battle.history.duplicate(),game.battle.units.duplicate(true)]
	game._process(8.0)
	_check(before==[game.battle.turn,game.battle.history,game.battle.units],"settling feedback never changes the captured battle "+tag)
	_move(root.get_final_transform()*Vector2(1880,1060))
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var path="res://artifacts/runtime/PHASE-tempo-"+stamp+"-"+tag+".png"
	_check(not FileAccess.file_exists(path) and root.get_texture().get_image().save_png(path)==OK,"unique actual viewport "+tag)
	print("TEMPO CAPTURE ",ProjectSettings.globalize_path(path))
