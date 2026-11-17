extends "res://tests/unit_information_capture.gd"
## REQ-035-S01、REQ-036-S01、REQ-036-S02、REQ-036-S03、REQ-036-S04
func _run() -> void:
	game=load("res://tests/side_info_audit.gd").new()
	game.settings_path="res://artifacts/runtime/cpu-capture-no-settings-"+stamp+".json"
	game.save_path="res://artifacts/runtime/cpu-capture-no-save-"+stamp+".json"
	root.add_child(game)
	await process_frame
	game.set_process(false)
	root.size=Vector2i(1920,1080)
	root.grab_focus()
	await create_timer(0.2).timeout
	game.cpu_enabled=true
	game.panel_seed_override=1
	game._start_battle()
	await process_frame
	for attempt in range(60):
		if root.has_focus() and game.window_focused:
			break
		root.grab_focus()
		await create_timer(0.02).timeout
	_check(root.has_focus() and game.window_focused,"actual game window has input focus")
	for command in [{"path":[Vector2i(4,4),Vector2i(5,4)],"target":2},{"path":[Vector2i(4,6),Vector2i(5,6)],"target":3}]:
		for cell in command.path:
			await _focus_input()
			_click_cell(cell)
			await process_frame
			_check(game.battle.path.has(cell),"real human path click "+str(cell))
			print("CPU INPUT ",cell," / path ",game.battle.path," / transform ",root.get_final_transform())
		await _focus_input()
		_click_cell(command.path[-1],true)
		await process_frame
		await _focus_input()
		_click_button(game.overlay,"DAMAGE / ADJACENT")
		await process_frame
		await _focus_input()
		_click_cell(game.battle.units[command.target].pos)
		await process_frame
	_check(game.battle.turn==3 and game.battle.actor==2 and game.battle.units.map(func(u):return u.hp)==[100.0,100.0,90.0,83.0],"capture begins after two actual human route/attack inputs")
	game._cpu_tick(0)
	game.cpu_paused=true
	var palette=game.palette_colors.duplicate()
	for dimensions in [Vector2i(1152,648),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(1200,1600)]:
		root.size=dimensions
		await process_frame
		game._hud()
		await process_frame
		var before=[game.battle.units.duplicate(true),game.battle.path.duplicate(),game.battle.turn]
		_click_cell(Vector2i(5,4))
		await process_frame
		_check(before==[game.battle.units,game.battle.path,game.battle.turn],"real resized input cannot change CPU route "+str(dimensions))
		var card=game._timeline_view().cards.filter(func(c):return c.index==1)[0]
		_click(root.get_final_transform()*card.center)
		await process_frame
		_check(game.selected==1 and game.battle.path==before[1],"real resized inspection remains available "+str(dimensions))
		_click_button(game.hud,"SPEED 1x" if not game.cpu_fast else "SPEED 4x")
		await process_frame
		_check(game.cpu_fast,"real resized speed click "+str(dimensions))
		_click_button(game.hud,"SPEED 4x")
		await process_frame
		_check(not game.cpu_fast,"real resized speed return "+str(dimensions))
		await _picture("size-"+str(dimensions.x)+"-"+str(dimensions.y))
	game.palette_colors=game.P.PRESETS.AMBER.duplicate()
	game._set_theme()
	root.size=Vector2i(1920,1080)
	await process_frame
	await _picture("amber")
	game.palette_colors=palette
	game._set_theme()
	game.selected=-1
	root.size=Vector2i(1280,720)
	await process_frame
	game.cpu_paused=false
	game._hud()
	game.set_process(true)
	var directory="res://artifacts/runtime/cpu-clip-"+stamp
	DirAccess.make_dir_recursive_absolute(directory)
	var rows=[]
	var seen={}
	var started=Time.get_ticks_usec()/1000000.0
	for i in range(72):
		await create_timer(0.065).timeout
		await RenderingServer.frame_post_draw
		var picture=root.get_texture().get_image()
		picture.convert(Image.FORMAT_RGBA8)
		var hash=HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(picture.get_data())
		var path=directory+("/frame-%03d.png" % i)
		_check(picture.save_png(path)==OK,"actual CPU animation frame "+str(i))
		rows.append({"file":path.get_file(),"time":Time.get_ticks_usec()/1000000.0-started,"sha256":hash.finish().hex_encode(),"x":0,"y":0})
		if game.cpu_turn.active:
			var key=str(game.cpu_turn.actor)+"-"+game.cpu_turn.phase
			if not seen.has(key):
				seen[key]=true
				_check(picture.save_png(directory+"/"+key+".png")==OK,"actual visible CPU stage "+key)
	_check(game.battle.turn==5 and game.battle.actor==0 and not game.cpu_turn.active,"two enemy turns finish naturally at normal speed")
	for actor in [2,3]:
		for phase in ["ROUTE","TARGET","RESULT"]:
			_check(seen.has(str(actor)+"-"+phase),"recording observes each enemy "+str(actor)+" "+phase)
	var file=FileAccess.open(directory+"/frames.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"width":1280,"height":720,"frames":rows,"history":game.battle.history,"seen":seen},"\t"))
	file.close()
	print("CPU CLIP ",ProjectSettings.globalize_path(directory+"/frames.json"))
	game.set_process(false)
	root.size=Vector2i(1920,1080)
	await process_frame
	await _picture("after-enemies")
	game._restart()
	await process_frame
	_check(game.build_open and not game.cpu_turn.active,"GPU verification ends BUILD without saving")
	print("CPU GPU: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)

func _focus_input() -> void:
	root.grab_focus()
	await create_timer(0.05).timeout
	_check(root.has_focus() and game.window_focused,"OS focus before synthetic game input")

func _picture(tag: String) -> void:
	# 停止中の検証でも、BUILDから引き継いだ通知の可視状態を実フレームと揃える。
	game._process(0)
	_move(root.get_final_transform()*Vector2(1880,1060))
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var path="res://artifacts/runtime/PHASE-cpu-"+stamp+"-"+tag+".png"
	_check(not FileAccess.file_exists(path) and root.get_texture().get_image().save_png(path)==OK,"unique real game viewport "+tag)
	for record in game.info_records:
		if record.text.begins_with("CPU ") or record.text.begins_with("DAMAGE / ADJACENT →"):
			_check(record.position.x>game.BOARD.x+game.CELL*10 and record.position.y<game.T.BATTLE_CONTEXT_BUTTON.position.y,"CPU text stays clear of map and menu "+tag)
	print("CPU CAPTURE ",ProjectSettings.globalize_path(path))
