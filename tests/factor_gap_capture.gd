extends "res://tests/compact_readouts_capture.gd"
## REQ-019-S11、REQ-019-S07、NREQ-001-S04
func _capture(suffix: String) -> void:
	await super._capture(suffix)
	if suffix!="progress-1920-1080":
		return
	game.queue_redraw()
	await create_timer(0.08).timeout
	await RenderingServer.frame_post_draw
	var picture=root.get_texture().get_image()
	var previous=Image.load_from_file("res://artifacts/ui-review/compact-readouts-progress.png")
	var masks=[]
	for card in game._timeline_view().cards:
		masks.append(Rect2i(card.center+Vector2(0,41),Vector2(66,24)))
	var changed=0
	var outside=0
	for y in range(picture.get_height()):
		for x in range(picture.get_width()):
			if picture.get_pixel(x,y)==previous.get_pixel(x,y):
				continue
			if masks.any(func(rect):return rect.has_point(Vector2i(x,y))):
				changed+=1
			else:
				outside+=1
	_check(changed>0 and outside==0,"only R column pixels move; I and all other UI unchanged "+str([changed,outside]))
	print("FACTOR GAP PIXELS changed ",changed," / outside ",outside)
	var path="res://artifacts/runtime/PHASE-factor-gap-"+stamp+"-battle.png"
	_check(not FileAccess.file_exists(path) and picture.save_png(path)==OK,"unique progressed factor-gap capture")
	print("FACTOR GAP CAPTURE ",ProjectSettings.globalize_path(path))
