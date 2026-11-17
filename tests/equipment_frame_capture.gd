extends "res://tests/unit_information_capture.gd"
## REQ-019-S04、REQ-019-S07、REQ-019-S09、NREQ-001-S04
func _capture(suffix: String) -> void:
	if suffix.begins_with("progress-"):
		var card=game._timeline_view().cards.filter(func(item):return item.index==1)[0]
		_click(root.get_final_transform()*card.center)
		_move(Vector2(1900,1000))
		await process_frame
	await super._capture(suffix)
	var picture=root.get_texture().get_image()
	var scale=Vector2(picture.get_size())/Vector2(1920,1080)
	var frames=[]
	for i in range(2):
		var rect=game.T.BATTLE_EQUIPMENT_FRAME
		rect.position.y+=i*game.T.BATTLE_EQUIPMENT_FRAME_STEP
		frames.append(rect)
		for point in [Vector2(rect.get_center().x,rect.position.y),Vector2(rect.position.x,rect.get_center().y),Vector2(rect.get_center().x,rect.end.y),Vector2(rect.end.x,rect.get_center().y)]:
			var peak=0.0
			var center=Vector2i(point*scale)
			for y in range(center.y-1,center.y+2):
				for x in range(center.x-1,center.x+2):
					var value=picture.get_pixel(x,y)
					peak=maxf(peak,maxf(absf(value.r-game.BG.r),maxf(absf(value.g-game.BG.g),absf(value.b-game.BG.b))))
			var contrast=maxf(game.MUTED.r-game.BG.r,maxf(game.MUTED.g-game.BG.g,game.MUTED.b-game.BG.b))*game.T.BATTLE_EQUIPMENT_FRAME_OPACITY
			_check(peak>contrast*0.2 and peak<contrast*1.2,"thin subdued frame visible on all four edges "+suffix+" / "+str(i))
		for offset in [Vector2(-16,8),Vector2(-16,22),Vector2(-16,36)]:
			var point=Vector2(rect.end.x,rect.position.y)+offset
			_check(picture.get_pixelv(Vector2i(point*scale)).to_rgba32()==game.BG.to_rgba32(),"frame interior has no background fill "+suffix)
	if suffix.begins_with("progress-"):
		var before=game.battle.units.duplicate(true)
		var route=game.battle.path.duplicate()
		var selected=game.selected
		var preview=game.preview_generation
		for rect in frames:
			var point=Vector2(rect.end.x-16,rect.get_center().y)
			_move(root.get_final_transform()*point)
			_click(root.get_final_transform()*point)
			await process_frame
			_check(game.battle.units==before and game.battle.path==route and game.selected==selected and game.preview_generation==preview and not is_instance_valid(game.overlay),"equipment click is passive and keeps inspection and route "+suffix)
		var focused=[]
		for i in range(4):
			for pressed in [true,false]:
				var event=InputEventKey.new()
				event.keycode=KEY_TAB
				event.pressed=pressed
				root.push_input(event,false)
			await process_frame
			var owner=root.gui_get_focus_owner()
			_check(owner is Button and owner.text in ["HELP","SETTINGS","RESTART","QUIT"],"equipment adds no focus stop "+suffix)
			if owner is Button:
				focused.append(owner.text)
		_check(focused.size()==4 and focused.has("HELP") and focused.has("SETTINGS") and focused.has("RESTART") and focused.has("QUIT"),"only four system buttons in tab cycle "+suffix)
		root.gui_release_focus()
		_move(Vector2(1900,1000))
		game.queue_redraw()
		await create_timer(0.08).timeout
		await RenderingServer.frame_post_draw
	if suffix=="progress-1920-1080":
		picture=root.get_texture().get_image()
		var previous=Image.load_from_file("res://artifacts/ui-review/timeline-links-progress.png")
		var mask=Rect2i(1436,316,408,430)
		var changed=0
		var outside=0
		for y in range(picture.get_height()):
			for x in range(picture.get_width()):
				if picture.get_pixel(x,y)==previous.get_pixel(x,y):
					continue
				if mask.has_point(Vector2i(x,y)):
					changed+=1
				else:
					outside+=1
		_check(changed>0 and outside==0,"only approved equipment and action area changes "+str([changed,outside]))
		print("EQUIPMENT FRAME PIXELS changed ",changed," / outside ",outside)
		var path="res://artifacts/runtime/PHASE-equipment-frame-"+stamp+"-battle.png"
		_check(not FileAccess.file_exists(path) and picture.save_png(path)==OK,"unique progressed equipment capture")
		print("EQUIPMENT FRAME CAPTURE ",ProjectSettings.globalize_path(path))
