extends "res://tests/unit_information_capture.gd"
## REQ-019-S01、REQ-019-S05、REQ-019-S07、REQ-019-S09、REQ-019-S10、NREQ-001-S04
func _capture(suffix: String) -> void:
	if suffix=="comparison":
		return
	_select_two()
	await process_frame
	if suffix.begins_with("fixture-long-"):
		game.battle.turn=9223372036854775807
		for unit in game.battle.units:
			unit.hp=11059.2
			unit.max_hp=11059.2
		game.factor_inputs=[0.0,1.0,83.0,999.0,-1.0,1000.0,NAN,INF]
	await super._capture(suffix)
	var transform=root.get_final_transform()
	var visible=Rect2(Vector2.ZERO,Vector2(root.size))
	var left_text=game.drawn_text.filter(func(item):return item.position.x<game.BOARD.x and item.position.y<game.T.PREVIEW_PANEL.position.y)
	for item in left_text:
		var face: Font=item.typeface
		var rect=Rect2(item.position-Vector2(0,face.get_ascent(item.font_size)),Vector2(face.get_string_size(item.text,HORIZONTAL_ALIGNMENT_LEFT,-1,item.font_size).x,face.get_height(item.font_size)))
		_check(rect.position.x>=0 and rect.end.x<game.BOARD.x and visible.encloses(transform*rect),"left text remains visible and clear of map "+suffix+" / "+item.text)
	_check(game.info_icons.map(func(item):return item.key)==["arms","gear"] and game.info_text[1].begins_with("ARMS-") and game.info_text[2].begins_with("GEAR-"),"actual equipment rows and glyph meanings agree "+suffix)
	var source: Vector2i=game.battle.units[game.battle.actor].pos
	_click_cell(source+Vector2i.LEFT)
	await process_frame
	var units=game.battle.units.duplicate(true)
	var route=game.battle.path.duplicate()
	# 経路の最初の描画を待ってから、検査対象のホバーを始める。
	await RenderingServer.frame_post_draw
	var generation=game.preview_generation
	_check(route==[source+Vector2i.LEFT],"route available for shifted timeline input "+suffix)
	var view=game._timeline_view()
	for event in view.events:
		_move(transform*event.point)
		await process_frame
		_check(game.timeline_hover==event.index and game.timeline_hover_event.time==event.time,"shifted point hover matches exact occurrence "+suffix)
		_click(transform*event.point)
		await process_frame
		_check(game.selected==event.index and game.timeline_selected_event.time==event.time and game.battle.path==route and game.battle.units==units,"shifted occurrence selects current state without moving "+suffix)
	for card in view.cards:
		var factor=game.drawn_text.filter(func(item):return item.text.begins_with("I:"))[card.index]
		_move(transform*(factor.position-Vector2(0,game.mono.get_ascent(factor.font_size)/2)))
		await process_frame
		_check(game.timeline_hover==card.index,"lower factor row remains in correct state hit area "+suffix)
		_click(transform*card.center)
		await process_frame
		_check(game.selected==card.index and game.battle.path==route,"shifted state selects its board unit "+suffix)
	_check(game.preview_generation==generation,"all shifted inspection preserves acting preview "+suffix)
	_select_two()
	await process_frame
	for i in range(2):
		var icon=game.info_icons[i]
		for point in [icon.rect.get_center(),game.info_records[i+1].position+Vector2(12,-5)]:
			_move(transform*point)
			_click(transform*point)
			await process_frame
			_check(game.selected==1 and game.battle.path==route and game.battle.units==units,"reordered icon and name remain passive "+suffix)
	_click_cell(source)
	await process_frame
	_select_two()
	_move(Vector2(1900,1000))
	game.queue_redraw()
	await create_timer(0.08).timeout
	await RenderingServer.frame_post_draw
	if suffix=="progress-1920-1080":
		var picture=root.get_texture().get_image()
		var previous=Image.load_from_file("res://artifacts/ui-review/equipment-icons-progress.png")
		var masks=[Rect2i(36,180,328,500),Rect2i(1436,316,408,110)]
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
		_check(changed>0 and outside==0,"only timeline placement and equipment rows change "+str([changed,outside]))
		print("BALANCED INFO PIXELS changed ",changed," / outside ",outside)
		var path="res://artifacts/runtime/PHASE-balanced-information-"+stamp+"-battle.png"
		_check(not FileAccess.file_exists(path) and picture.save_png(path)==OK,"unique progressed balanced information capture")
		print("BALANCED INFO CAPTURE ",ProjectSettings.globalize_path(path))
func _select_two() -> void:
	var card=game._timeline_view().cards.filter(func(item):return item.index==1)[0]
	_click(root.get_final_transform()*card.center)
	_move(Vector2(1900,1000))
