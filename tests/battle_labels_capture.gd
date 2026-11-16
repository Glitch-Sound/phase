extends "res://tests/notification_capture.gd"
const LABEL_AREAS=[Rect2i(172,832,160,22),Rect2i(528,882,450,30),Rect2i(172,136,270,22),Rect2i(172,310,150,24),Rect2i(365,310,145,24),Rect2i(1322,78,110,24),Rect2i(1436,330,205,26),Rect2i(148,18,230,28),Rect2i(1388,18,230,28)]
## REQ-019-S01、REQ-019-S03
func _capture(suffix: String) -> void:
	game.queue_redraw()
	await create_timer(0.16).timeout
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	if suffix=="battle":
		var previous=Image.load_from_file("res://artifacts/ui-review/readable-phase-preview-battle.png")
		if image.get_size()!=previous.get_size():
			failed=true
			printerr("FAIL: comparison dimensions differ")
			return
		var counts=[]
		counts.resize(LABEL_AREAS.size())
		counts.fill(0)
		var outside=0
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				if image.get_pixel(x,y)==previous.get_pixel(x,y):
					continue
				var inside=false
				for i in range(LABEL_AREAS.size()):
					if LABEL_AREAS[i].has_point(Vector2i(x,y)):
						counts[i]+=1
						inside=true
						break
				if not inside:
					outside+=1
		print("LABEL PIXEL AUDIT regions ",counts," / outside ",outside)
		if outside!=0 or not counts.all(func(count):return count>0):
			failed=true
			printerr("FAIL: exactly the requested text regions must change")
	var path="res://artifacts/runtime/PHASE-labels-"+stamp+"-"+suffix+".png"
	if FileAccess.file_exists(path) or image.save_png(path)!=OK:
		failed=true
		printerr("FAIL: unique capture could not be saved")
		return
	print("CAPTURE ",ProjectSettings.globalize_path(path))
