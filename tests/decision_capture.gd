extends "res://tests/cpu_capture.gd"
## REQ-010-S03、REQ-010-S04、REQ-018-S01、REQ-018-S03、REQ-018-S04、REQ-018-S05
## 実画面操作で得た16手を同じ入力経路で再生し、別の初期状態を捏造しない。
const HUMAN_COMMANDS=[
	[1,[[4,4],[5,4]],"DAMAGE",2], [2,[[4,6],[5,6]],"DAMAGE",3],
	[5,[[4,4],[4,5],[5,5]],"HEAL",1], [6,[[6,6],[6,7]],"DAMAGE",3],
	[9,[[6,5],[6,6]],"DAMAGE",3], [10,[[5,7]],"DAMAGE",3],
	[13,[[5,6],[4,6]],"DAMAGE",3], [14,[[5,8],[4,8]],"DAMAGE",3],
	[16,[[3,6],[3,5]],"DAMAGE",2], [17,[[3,6],[4,6]],"DAMAGE",2],
	[18,[[4,7]],"HEAL",0], [20,[[3,6],[2,6],[2,7]],"DAMAGE",2],
	[21,[[4,6],[3,6]],"DAMAGE",2], [23,[[3,7],[4,7]],"DAMAGE",2],
	[25,[[5,7]],"DAMAGE",2], [27,[[5,6],[4,6]],"DAMAGE",2]]
func _run() -> void:
	game=load("res://tests/side_info_audit.gd").new()
	game.battle=game.B.new()
	game.settings_path="res://artifacts/runtime/decisions-gpu-no-settings-"+stamp+".json"
	game.save_path="res://artifacts/runtime/decisions-gpu-no-save-"+stamp+".json"
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
			game.selected=(actor+1)%4
			game.timeline_hover=(actor+2)%4
			game.battle.units[actor].pos=Vector2i(0,0) if actor%2==0 else Vector2i(9,9)
			await _picture("marker-"+str(dimensions.x)+"-"+str(dimensions.y)+"-"+str(actor))
			var triangle=game._acting_marker()
			_check(triangle.index==actor,"GPU actor distinct from inspection "+str(actor))
		if dimensions==Vector2i(1920,1080):
			var colors=game.palette_colors.duplicate()
			game.palette_colors=game.P.PRESETS.AMBER.duplicate()
			game._set_theme()
			await _picture("amber-marker")
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
	var final=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/runtime/decisions-natural-match-final.json"))
	for command in HUMAN_COMMANDS:
		for tick in range(300):
			if not game._cpu_locked():
				break
			game._process(0.1)
			await process_frame
		_check(game.battle.turn==command[0] and game.battle.units[game.battle.actor].camp=="PLAYER","actual native command actor/turn "+str(command[0]))
		for pair in command[1]:
			_click_cell(Vector2i(pair[0],pair[1]))
			await process_frame
		var last=command[1][-1]
		_click_cell(Vector2i(last[0],last[1]),true)
		await process_frame
		if command[0]==17:
			await _picture("progress-action")
		_click_button(game.overlay,command[2]+" / ADJACENT")
		await process_frame
		_click_cell(game.battle.units[command[3]].pos)
		await process_frame
		var same=game.battle.history==final.history.slice(0,game.battle.history.size())
		_check(same,"GPU replay exactly matches native history "+str(command[0]))
		if not same:
			print("REPLAY MISMATCH ",game.battle.history)
			quit(1)
			return
		if command[0]==17:
			_check(game.battle.turn==18 and game.battle.units.map(func(u):return u.hp)==[23.0,78.0,56.0,0.0],"progressed capture is the real native recovery decision")
			await _picture("progress-battle")
	_check(game.battle.turn==27 and game.battle.result=="VICTORY" and game.battle.units.map(func(u):return u.hp)==[26.0,0.0,0.0,0.0],"native whole match reproduces without HP overrides")
	game._restart()
	await process_frame
	_check(game.build_open,"GPU decisions end BUILD without saving")
	print("TACTICAL DECISIONS GPU: %d checks / %d failures" % [checks,failures])
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
	var path="res://artifacts/runtime/PHASE-decisions-"+stamp+"-"+tag+".png"
	_check(not FileAccess.file_exists(path) and root.get_texture().get_image().save_png(path)==OK,"unique actual viewport "+tag)
	print("DECISIONS CAPTURE ",ProjectSettings.globalize_path(path))
