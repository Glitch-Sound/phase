extends SceneTree
var game
var stamp=str(Time.get_unix_time_from_system()).replace(".","-")
var failed=false
func _initialize() -> void:
	_run.call_deferred()
## REQ-033-S03、NREQ-001-S01
func _run() -> void:
	game=load("res://tests/phase_preview_audit.gd").new()
	game.settings_path="res://artifacts/runtime/notification-capture-"+stamp+".json"
	root.add_child(game)
	await process_frame
	for dimensions in [Vector2i(1920,1080),Vector2i(1440,810),Vector2i(1152,648)]:
		root.size=dimensions
		await process_frame
		for state in ["start","invalid-move","invalid-target"]:
			game._start_battle()
			await process_frame
			if state=="invalid-move":
				game._cell_input(Vector2i(0,9))
			elif state=="invalid-target":
				game._cell_input(Vector2i(4,4))
				game._cell_input(Vector2i(5,4))
				game._cell_input(Vector2i(5,4),true)
				await process_frame
				game.battle.choose_skill(game.C.DAMAGE)
				game._clear_overlay()
				game._hud()
				game._cell_input(Vector2i(0,0))
			await _capture(state+"-"+str(dimensions.x))
	root.size=Vector2i(1440,810)
	game._start_battle()
	await process_frame
	game.message_time=0
	var u=game.battle.units[0]
	for key in ["core","gear","arms"]:
		u[key]=[20,20,20,20,20]
	u.gear_angle=0.0
	u.arms_angle=0.0
	await _capture("aligned-1440")
	u.gear_angle=72.0
	u.arms_angle=144.0
	await _capture("apart-1440")
	root.size=Vector2i(1920,1080)
	game._start_battle()
	await process_frame
	game._cell_input(Vector2i(4,4))
	game._cell_input(Vector2i(5,4))
	game._cell_input(Vector2i(5,4),true)
	await process_frame
	game.battle.choose_skill(game.C.DAMAGE)
	game._clear_overlay()
	game._cell_input(Vector2i(6,4))
	game._cell_input(Vector2i(4,6))
	game._cell_input(Vector2i(5,6))
	# 比較画像以外の9画面では通知を消さずに検証する。
	game.message_time=0
	game.toasts=[]
	await _capture("battle")
	game._restart()
	await process_frame
	quit(1 if failed else 0)
func _capture(suffix: String) -> void:
	game.queue_redraw()
	await create_timer(0.16).timeout
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	var path="res://artifacts/runtime/PHASE-notification-"+stamp+"-"+suffix+".png"
	if FileAccess.file_exists(path) or image.save_png(path)!=OK:
		failed=true
		printerr("FAIL: unique capture could not be saved")
		return
	print("CAPTURE ",ProjectSettings.globalize_path(path))
