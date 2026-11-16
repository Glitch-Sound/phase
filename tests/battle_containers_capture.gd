extends "res://tests/notification_capture.gd"
var checks=0
var failures=0
## REQ-019-S03、REQ-019-S04
func _capture(suffix: String) -> void:
	game.queue_redraw()
	await create_timer(0.16).timeout
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	var scale=image.get_width()/1920.0
	var points=[Vector2(151,66),Vector2(518,802),Vector2(1302,66),Vector2(1768,802),Vector2(151,822),Vector2(518,1038)]
	for row in range(6):
		points.append(Vector2(164,345+row*64))
		points.append(Vector2(501,396+row*64))
	for row in range(2):
		points.append(Vector2(1740,654+row*43))
	for point in points:
		var pixel=Vector2i((point*scale).floor())
		_check(image.get_pixelv(pixel)==game.BG,suffix+" / flat background at "+str(point))
	if suffix=="battle":
		var previous=Image.load_from_file("res://artifacts/ui-review/battle-containers-removed.png")
		_check(image.get_size()==previous.get_size(),"comparison dimensions")
		if image.get_size()==previous.get_size():
			# 元の1px枠が行の外へ広がる範囲も含める。
			var allowed=[Rect2i(164,345,342,58).grow(1)]
			var protected_areas=[Rect2i(530,100,760,760),Rect2i(1218,1025,600,40)]
			var changed=0
			var outside=0
			var protected_changes=[0,0]
			for y in range(image.get_height()):
				for x in range(image.get_width()):
					if image.get_pixel(x,y)==previous.get_pixel(x,y):
						continue
					var point=Vector2i(x,y)
					changed+=1
					if not allowed.any(func(area):return area.has_point(point)):
						outside+=1
					for i in range(protected_areas.size()):
						if protected_areas[i].has_point(point):
							protected_changes[i]+=1
			_check(changed>0 and outside==0,"only first-turn row changes")
			_check(protected_changes==[0,0],"board and system menu unchanged")
			print("CONTAINER PIXEL AUDIT changed ",changed," / outside ",outside," / protected ",protected_changes)
	var path="res://artifacts/runtime/PHASE-first-row-"+stamp+"-"+suffix+".png"
	_check(not FileAccess.file_exists(path) and image.save_png(path)==OK,"unique capture "+suffix)
	print("CAPTURE ",ProjectSettings.globalize_path(path))
	if suffix=="battle":
		print("BATTLE CONTAINERS: %d checks / %d failures" % [checks,failures])
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failed=true
		failures+=1
		printerr("FAIL: ",message)
