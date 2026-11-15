extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var stamp=str(Time.get_unix_time_from_system()).replace(".","-")
	var game=load("res://main.tscn").instantiate()
	game.settings_path="res://artifacts/runtime/capture-no-settings-"+stamp+".json"
	root.add_child(game)
	await process_frame
	game._start_battle()
	game._cell_input(Vector2i(4,4))
	game._cell_input(Vector2i(5,4))
	game._cell_input(Vector2i(5,4),true)
	game.battle.choose_skill(game.C.DAMAGE)
	game._clear_overlay()
	game._cell_input(Vector2i(6,4))
	game._cell_input(Vector2i(4,6))
	game._cell_input(Vector2i(5,6))
	game.message_time=0
	game.toasts=[]
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	var path="res://artifacts/runtime/PHASE-restored-battle-"+stamp+".png"
	if FileAccess.file_exists(path):
		printerr("Capture destination already exists.")
		quit(1)
		return
	var error=image.save_png(path)
	if error!=OK:
		printerr("Capture failed: ",error)
		quit(1)
		return
	var u=game.battle.preview()
	var reference=Image.load_from_file("res://artifacts/ui-review/essential-before.png")
	print("REFERENCE_PIXELS_EQUAL ",image.get_data()==reference.get_data())
	print("CAPTURE ",ProjectSettings.globalize_path(path))
	print("STATE ",JSON.stringify({"size":[image.get_width(),image.get_height()],"turn":game.battle.turn,"actor":u.id,"enemy_a_hp":game.battle.units[2].hp,"path":str(game.battle.path),"inf":game.M.sync(u,1).factor*100,"res":game.M.sync(u,2).factor*100}))
	quit()
