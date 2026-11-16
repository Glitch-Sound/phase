extends SceneTree
# 比較画像中の削除対象の文字だけを囲む。盤面と他パネルは除外しない。
const REMOVED_TEXT_AREAS=[Rect2i(560,14,720,30),Rect2i(560,55,700,25),Rect2i(560,81,700,15),Rect2i(535,100,20,700),Rect2i(560,805,700,30)]
func _initialize() -> void:
	_run.call_deferred()
## REQ-029-S01、NREQ-001-S01
func _run() -> void:
	var stamp=str(Time.get_unix_time_from_system()).replace(".","-")
	var game=load("res://tests/fixture_main.gd").new()
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
	var path="res://artifacts/runtime/PHASE-map-labels-"+stamp+".png"
	if FileAccess.file_exists(path):
		printerr("Capture destination already exists.")
		quit(1)
		return
	var reference=Image.load_from_file("res://artifacts/ui-review/restored-battle.png")
	var inside=0
	var outside=0
	var examples=[]
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x,y)==reference.get_pixel(x,y):
				continue
			var removed=false
			for rect in REMOVED_TEXT_AREAS:
				if rect.has_point(Vector2i(x,y)):
					removed=true
			if removed:
				inside+=1
			else:
				outside+=1
				if examples.size()<5:
					examples.append(Vector2i(x,y))
	print("PIXEL AUDIT: changed inside ",inside," / outside ",outside," / examples ",examples)
	if inside==0 or outside!=0:
		printerr("Pixel audit failed.")
		quit(1)
		return
	var error=image.save_png(path)
	if error!=OK:
		printerr("Capture failed: ",error)
		quit(1)
		return
	var u=game.battle.preview()
	print("CAPTURE ",ProjectSettings.globalize_path(path))
	print("STATE ",JSON.stringify({"size":[image.get_width(),image.get_height()],"turn":game.battle.turn,"actor":u.id,"enemy_a_hp":game.battle.units[2].hp,"path":str(game.battle.path),"inf":game.M.sync(u,1).factor*100,"res":game.M.sync(u,2).factor*100}))
	quit()
