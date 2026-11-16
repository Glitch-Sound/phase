extends "res://tests/notification_capture.gd"
## REQ-019-S01、REQ-019-S03
func _capture(suffix: String) -> void:
	game.queue_redraw()
	await create_timer(0.16).timeout
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	if suffix=="battle":
		var previous=Image.load_from_file("res://artifacts/ui-review/battle-labels-removed.png")
		if image.get_size()!=previous.get_size():
			failed=true
			printerr("FAIL: comparison dimensions differ")
			return
		var areas=load("res://tests/battle_labels_capture.gd").LABEL_AREAS.slice(7)
		var counts=[0,0]
		var outside=0
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				if image.get_pixel(x,y)==previous.get_pixel(x,y):
					continue
				var inside=false
				for i in range(areas.size()):
					if areas[i].has_point(Vector2i(x,y)):
						counts[i]+=1
						inside=true
						break
				if not inside:
					outside+=1
		print("TOP LABEL PIXEL AUDIT ",counts," / outside ",outside)
		if outside!=0 or not counts.all(func(count):return count>0):
			failed=true
			printerr("FAIL: only both top label regions must change")
	var path="res://artifacts/runtime/PHASE-top-labels-"+stamp+"-"+suffix+".png"
	if FileAccess.file_exists(path) or image.save_png(path)!=OK:
		failed=true
		printerr("FAIL: unique capture could not be saved")
		return
	print("CAPTURE ",ProjectSettings.globalize_path(path))
