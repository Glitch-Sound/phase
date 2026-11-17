extends "res://tests/unit_information_capture.gd"
## REQ-019-S07、REQ-027-S01、REQ-027-S02
func _capture(suffix: String) -> void:
	if suffix.begins_with("progress-"):
		var card=game._timeline_view().cards.filter(func(item):return item.index==1)[0]
		_click(root.get_final_transform()*card.center)
		_move(Vector2(1900,1000))
		await process_frame
	await super._capture(suffix)
	if not suffix.begins_with("progress-"):
		return
	var selected_before=game.selected
	var selected_event_before=game.timeline_selected_event.duplicate(true)
	var view=game._timeline_view()
	var units=game.battle.units.duplicate(true)
	var route=game.battle.path.duplicate()
	var preview=game.preview_generation
	game.selected=-1
	game.timeline_selected_event={}
	_move(Vector2(1900,1000))
	await _settle_links()
	var neutral=root.get_texture().get_image()
	for event in view.events:
		_click(root.get_final_transform()*event.point)
		_move(Vector2(1900,1000))
		await _settle_links()
		_check(game.selected==event.index and game.timeline_selected_event.time==event.time,"link test selects exact occurrence "+suffix+" / "+str(event.rank))
		_check(_same_links(neutral,root.get_texture().get_image(),view),"selected links retain ordinary gray and brightness "+suffix+" / "+str(event.rank))
	var hover_event=view.events.filter(func(event):return event.index==2)[0]
	_move(root.get_final_transform()*hover_event.point)
	await _settle_links()
	_check(game.timeline_hover==2 and _same_links(neutral,root.get_texture().get_image(),view),"hover preserves common link appearance "+suffix)
	_check(game.battle.units==units and game.battle.path==route and game.preview_generation==preview,"inspection retains battle route and preview "+suffix)
	game.selected=selected_before
	game.timeline_selected_event=selected_event_before
	_move(Vector2(1900,1000))
	await _settle_links()
	if suffix=="progress-1920-1080":
		var picture=root.get_texture().get_image()
		var previous=Image.load_from_file("res://artifacts/ui-review/unit-information-progress.png")
		var masks=[]
		for link in view.links:
			var rect=Rect2(link.points[0],Vector2.ZERO)
			for point in link.points:
				rect=rect.expand(point)
			masks.append(Rect2i(rect.grow(2)))
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
		_check(changed>0 and outside==0,"only leader pixels change at identical progressed battle "+str([changed,outside]))
		print("TIMELINE LINK PIXELS changed ",changed," / outside ",outside)
		var path="res://artifacts/runtime/PHASE-timeline-links-"+stamp+"-battle.png"
		_check(not FileAccess.file_exists(path) and picture.save_png(path)==OK,"unique progressed link capture")
		print("TIMELINE LINK CAPTURE ",ProjectSettings.globalize_path(path))
func _settle_links() -> void:
	game.queue_redraw()
	await create_timer(0.06).timeout
	await RenderingServer.frame_post_draw
func _same_links(before: Image,after: Image,view: Dictionary) -> bool:
	# 各節点直後の水平部を比較する。HP文字やリングを含めず、再登場も個別に見る。
	var scale=Vector2(before.get_size())/Vector2(1920,1080)
	for link in view.links:
		var point=(link.points[0]+link.points[1])/2
		var center=Vector2i(point*scale)
		for y in range(center.y-2,center.y+3):
			for x in range(center.x-2,center.x+3):
				if before.get_pixel(x,y)!=after.get_pixel(x,y):
					return false
	return true
