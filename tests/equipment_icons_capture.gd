extends "res://tests/unit_information_capture.gd"
## REQ-019-S04、REQ-019-S07、REQ-019-S09、NREQ-001-S04
func _capture(suffix: String) -> void:
	if suffix=="comparison":
		return
	if suffix.begins_with("progress-"):
		_select_two()
		await process_frame
	await super._capture(suffix)
	_check_icon_pixels(root.get_texture().get_image(),suffix)
	if not suffix.begins_with("progress-"):
		return
	var source: Vector2i=game.battle.units[game.battle.actor].pos
	_click_cell(source+Vector2i.LEFT)
	await process_frame
	_select_two()
	await process_frame
	var units=game.battle.units.duplicate(true)
	var route=game.battle.path.duplicate()
	_check(route==[source+Vector2i.LEFT],"pending route exists for equipment input test "+suffix)
	var generation=game.preview_generation
	for i in range(2):
		var icon=game.info_icons[i]
		for point in [icon.rect.get_center(),game.info_records[i+1].position+Vector2(12,-5)]:
			_move(root.get_final_transform()*point)
			_click(root.get_final_transform()*point)
			await process_frame
			_check(game.selected==1 and game.battle.units==units and game.battle.path==route and not is_instance_valid(game.overlay),"icon and name are passive, preserving inspection and route "+suffix)
	_check(game.preview_generation==generation,"passive equipment never changes predicted phase")
	_click_cell(source)
	await process_frame
	_select_two()
	await process_frame
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
	_check(focused.size()==4 and focused.has("HELP") and focused.has("SETTINGS") and focused.has("RESTART") and focused.has("QUIT"),"four original system buttons retain tab cycle "+suffix)
	root.gui_release_focus()
	_move(Vector2(1900,1000))
	game.queue_redraw()
	await create_timer(0.08).timeout
	await RenderingServer.frame_post_draw
	if suffix=="progress-1920-1080":
		var picture=root.get_texture().get_image()
		var previous=Image.load_from_file("res://artifacts/ui-review/factor-gap-progress.png")
		var mask=Rect2i(1436,316,408,110)
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
		_check(changed>0 and outside==0,"only equipment rows change "+str([changed,outside]))
		print("EQUIPMENT ICON PIXELS changed ",changed," / outside ",outside)
		var path="res://artifacts/runtime/PHASE-equipment-icons-"+stamp+"-battle.png"
		_check(not FileAccess.file_exists(path) and picture.save_png(path)==OK,"unique progressed equipment icon capture")
		print("EQUIPMENT ICON CAPTURE ",ProjectSettings.globalize_path(path))
		await _test_color_fixture(picture)
func _select_two() -> void:
	var card=game._timeline_view().cards.filter(func(item):return item.index==1)[0]
	_click(root.get_final_transform()*card.center)
	_move(Vector2(1900,1000))
func _check_icon_pixels(picture: Image,suffix: String) -> void:
	var scale=Vector2(picture.get_size())/Vector2(1920,1080)
	_check(game.info_icons.size()==2,"exactly two visible equipment icons "+suffix)
	for i in range(game.info_icons.size()):
		var rect=Rect2i(Transform2D.IDENTITY.scaled(scale)*game.info_icons[i].rect)
		var bright=0
		var peak=0.0
		for y in range(rect.position.y,rect.end.y):
			for x in range(rect.position.x,rect.end.x):
				var color=picture.get_pixel(x,y)
				var value=maxf(color.r,maxf(color.g,color.b))
				peak=maxf(peak,value)
				if value>0.1:
					bright+=1
		_check(bright>4 and peak<=maxf(game.MUTED.r,maxf(game.MUTED.g,game.MUTED.b))+0.02,"recognizable muted icon pixels "+suffix+" / "+str(i))
		# 旧枠の上辺と下辺。新しい名称や記号を含まない位置で囲いの欠落を確かめる。
		for point in [Vector2(1552,330),Vector2(1664,330),Vector2(1440,358),Vector2(1552,358)]:
			point.y+=i*56
			_check(picture.get_pixelv(Vector2i(point*scale)).to_rgba32()==game.BG.to_rgba32(),"former border is absent "+suffix)
		var gap=Vector2(game.info_icons[i].rect.end.x+game.T.BATTLE_EQUIPMENT_NAME_GAP/2,game.info_icons[i].rect.get_center().y)
		_check(picture.get_pixelv(Vector2i(gap*scale)).to_rgba32()==game.BG.to_rgba32(),"icon-name gap has no filled background "+suffix)
## REQ-019-S09、NREQ-002-S01
func _test_color_fixture(before: Image) -> void:
	var palette=game.palette_colors.duplicate()
	game.palette_colors=game.P.PRESETS.AMBER.duplicate()
	game._set_theme()
	game.queue_redraw()
	await create_timer(0.08).timeout
	await RenderingServer.frame_post_draw
	var after=root.get_texture().get_image()
	for icon in game.info_icons:
		var rect=Rect2i(icon.rect)
		_check(before.get_region(rect).get_data()==after.get_region(rect).get_data(),"equipment glyph stays neutral under AMBER preset")
	_check_icon_pixels(after,"explicit AMBER display fixture")
	var path="res://artifacts/runtime/PHASE-equipment-icons-"+stamp+"-amber.png"
	_check(not FileAccess.file_exists(path) and after.save_png(path)==OK,"AMBER display fixture capture")
	print("EQUIPMENT AMBER CAPTURE ",ProjectSettings.globalize_path(path))
	game.palette_colors=palette
	game._set_theme()
	game.queue_redraw()
	await process_frame
