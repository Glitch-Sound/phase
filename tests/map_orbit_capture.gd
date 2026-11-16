extends "res://tests/notification_capture.gd"
var checks=0
var failures=0
## REQ-019-S04、NREQ-001-S01、NREQ-001-S04、REQ-033-S03
func _capture(suffix: String) -> void:
	game.queue_redraw()
	await create_timer(0.16).timeout
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	# viewportテクスチャは余白を含まないため、ウィンドウの余白オフセットを掛けない。
	var transform=Transform2D.IDENTITY.scaled(Vector2(image.get_width()/1920.0,image.get_height()/1080.0))
	var points=[Vector2(40,90),Vector2(1400,40),Vector2(1870,800),game.T.PREVIEW_PANEL.position+Vector2(2,2),game.T.PREVIEW_PANEL.end-Vector2(2,2)]
	for row in range(2):
		points.append(Vector2(1740,654+row*43)+game.T.BATTLE_INFO_OFFSET)
	for card in game._timeline_view().cards:
		var rect: Rect2=card.rect
		points.append(rect.position)
		points.append(rect.end-Vector2(4,4))
	for point in points:
		_check(image.get_pixelv(Vector2i(transform*point))==game.BG,suffix+" / no frame or background at "+str(point))
	var bounds=Rect2(game.T.PREVIEW_CENTER-Vector2.ONE*100,Vector2.ONE*200)
	var orbit_pixels=0
	var scaled=Rect2i(transform*bounds)
	for y in range(scaled.position.y,scaled.end.y):
		for x in range(scaled.position.x,scaled.end.x):
			var c=image.get_pixel(x,y)
			if maxf(c.r,maxf(c.g,c.b))>0.25:
				orbit_pixels+=1
	_check(orbit_pixels>0,suffix+" / rings and orbit remain visible")
	if suffix=="battle":
		var previous=Image.load_from_file("res://artifacts/ui-review/first-turn-container-removed.png")
		var changed=0
		for y in range(1025,1065):
			for x in range(1218,1818):
				if image.get_pixel(x,y)!=previous.get_pixel(x,y):
					changed+=1
		_check(changed==0,"system menu pixels preserved")
		print("MAP ORBIT FOOTER DIFFERENCE ",changed)
	var path="res://artifacts/runtime/PHASE-map-orbit-"+stamp+"-"+suffix+".png"
	_check(not FileAccess.file_exists(path) and image.save_png(path)==OK,"unique capture "+suffix)
	print("CAPTURE ",ProjectSettings.globalize_path(path))
	if suffix.begins_with("start-") or suffix.begins_with("battle-"):
		var before=game.battle.path.duplicate()
		var selected=game.selected
		var cell=Vector2i(4,4) if suffix.begins_with("start-") else Vector2i(6,4)
		_click(root.get_final_transform()*(game.BOARD+(Vector2(cell)+Vector2.ONE/2)*game.CELL))
		await process_frame
		_check(game.battle.path==[cell] if suffix.begins_with("start-") else game.selected==2 and game.battle.path==before,"GPU window scaled cell click: "+suffix)
		var help=game.hud.find_children("*","Button",true,false).filter(func(b):return b.text=="HELP")[0]
		_click(root.get_final_transform()*help.get_global_rect().get_center())
		await process_frame
		_check(is_instance_valid(game.auxiliary),"GPU window scaled system button click: "+suffix)
		game._close_aux()
		game.battle.path=before
		game.selected=selected
		await process_frame
	if suffix=="battle":
		for size_px in [Vector2i(2560,1440),Vector2i(1200,1600)]:
			root.size=size_px
			await process_frame
			await _capture("battle-"+str(size_px.x)+"x"+str(size_px.y))
		print("MAP ORBIT GPU: %d checks / %d failures" % [checks,failures])
		var ordered=game.draw_times.duplicate()
		ordered.sort()
		print("DRAW CPU MS median ",ordered[ordered.size()/2]," / max ",ordered[-1])
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failed=true
		failures+=1
		printerr("FAIL: ",message)
func _click(point: Vector2) -> void:
	for pressed in [true,false]:
		var event=InputEventMouseButton.new()
		event.position=point
		event.global_position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		root.push_input(event,false)
