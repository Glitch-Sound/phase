extends "res://tests/unit_information_capture.gd"
## REQ-019-S04、REQ-019-S07、REQ-019-S09、REQ-019-S10、REQ-019-S11、NREQ-001-S04
func _capture(suffix: String) -> void:
	if suffix=="comparison":
		return
	if suffix.begins_with("progress-"):
		var card=game._timeline_view().cards.filter(func(item):return item.index==1)[0]
		_click(root.get_final_transform()*card.center)
		_move(Vector2(1900,1000))
		await process_frame
	await super._capture(suffix)
	if suffix.begins_with("progress-"):
		var units=game.battle.units.duplicate(true)
		var route=game.battle.path.duplicate()
		var fields=game.drawn_text.filter(func(item):return item.text.begins_with("I:"))
		for i in range(fields.size()):
			var point=root.get_final_transform()*(fields[i].position+Vector2(3,-5))
			_move(point)
			await process_frame
			_check(game.timeline_hover==i,"factor label hover identifies its unit "+suffix+" / "+str(i))
			_click(point)
			await process_frame
			_check(game.selected==i and game.battle.units==units and game.battle.path==route,"factor label inspection preserves battle and route "+suffix)
		var card=game._timeline_view().cards.filter(func(item):return item.index==1)[0]
		_click(root.get_final_transform()*card.center)
		_move(Vector2(1900,1000))
		game.queue_redraw()
		await create_timer(0.08).timeout
		await RenderingServer.frame_post_draw
	_check_readout_bounds(suffix,"TURN 11")
	var picture=root.get_texture().get_image()
	var scale=Vector2(picture.get_size())/Vector2(1920,1080)
	for i in range(2):
		var rect=game.T.BATTLE_EQUIPMENT_FRAME
		rect.position.y+=i*game.T.BATTLE_EQUIPMENT_FRAME_STEP
		var point=Vector2(rect.get_center().x,rect.position.y)*scale
		var peak=0.0
		for y in range(int(point.y)-1,int(point.y)+2):
			for x in range(int(point.x)-1,int(point.x)+2):
				peak=maxf(peak,picture.get_pixel(x,y).r-game.BG.r)
		_check(peak>0,"small equipment outline remains visible "+suffix)
	if suffix=="progress-1920-1080":
		var previous=Image.load_from_file("res://artifacts/ui-review/equipment-frame-progress.png")
		var masks=[Rect2i(40,180,320,40),Rect2i(1436,316,408,110)]
		for card in game._timeline_view().cards:
			masks.append(Rect2i(card.center+Vector2(-64,41),Vector2(128,24)))
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
		_check(changed>0 and outside==0,"only turn factor fields and equipment margins change "+str([changed,outside]))
		print("COMPACT READOUT PIXELS changed ",changed," / outside ",outside)
		var path="res://artifacts/runtime/PHASE-compact-readouts-"+stamp+"-battle.png"
		_check(not FileAccess.file_exists(path) and picture.save_png(path)==OK,"unique progressed compact capture")
		print("COMPACT READOUT CAPTURE ",ProjectSettings.globalize_path(path))
		await _boundary_fixture()
func _check_readout_bounds(suffix: String,turn_label: String) -> void:
	var labels=game.drawn_text.filter(func(item):return item.text.begins_with("TURN ") or item.text.begins_with("I:") or item.text.begins_with("R:"))
	_check(labels.size()==9 and labels[0].text==turn_label,"exact turn and eight factor fields "+suffix)
	var bounds=[]
	for label in labels:
		var font: Font=label.typeface
		var rect=Rect2(label.position-Vector2(0,font.get_ascent(label.font_size)),Vector2(font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.font_size).x,font.get_height(label.font_size)))
		_check(rect.position.x>=game.T.PREVIEW_PANEL.position.x and rect.end.x<=game.T.PREVIEW_PANEL.end.x and rect.end.y<game.T.PREVIEW_PANEL.position.y,"readout stays inside left information "+suffix+" / "+label.text)
		_check(bounds.all(func(other):return not rect.intersects(other)),"factor and turn text do not overlap "+suffix)
		bounds.append(rect)
	if turn_label=="TURN 11":
		_check(labels.slice(1).all(func(label):return label.text.length()==6),"fixed six-character compact labels "+suffix)
		_check(game.battle.turn==11,"display uses actual turn after ten completed actions "+suffix)
## REQ-019-S10、REQ-019-S11
func _boundary_fixture() -> void:
	var units=game.battle.units.duplicate(true)
	var route=game.battle.path.duplicate()
	var selected=game.selected
	var original_size=root.size
	game.factor_inputs=[0.0,9.0,83.0,100.0,999.0,-1.0,INF,NAN]
	for dimensions in [Vector2i(1152,648),Vector2i(1920,1080)]:
		root.size=dimensions
		game.battle.turn=1000 if dimensions.x==1152 else 9223372036854775807
		game.queue_redraw()
		await create_timer(0.1).timeout
		await RenderingServer.frame_post_draw
		var expected="TURN 1000" if dimensions.x==1152 else "TURN 9223372036854775807"
		_check_readout_bounds("explicit boundary fixture "+str(dimensions),expected)
		var fields=game.drawn_text.filter(func(item):return item.text.begins_with("I:") or item.text.begins_with("R:"))
		_check(fields.map(func(item):return item.text)==["I:  0%","R:  9%","I: 83%","R:100%","I:999%","R:---%","I:---%","R:---%"],"exact visible boundary fields")
		var picture=root.get_texture().get_image()
		var path="res://artifacts/runtime/PHASE-compact-readouts-"+stamp+"-fixture-"+str(dimensions.x)+".png"
		_check(not FileAccess.file_exists(path) and picture.save_png(path)==OK,"explicit fixture capture")
		print("COMPACT FIXTURE CAPTURE ",ProjectSettings.globalize_path(path))
	_check(game.battle.units==units and game.battle.path==route and game.selected==selected,"boundary display never changes actual units route or inspection")
	game.factor_inputs=[]
	game.battle.turn=11
	root.size=original_size
	game.queue_redraw()
	await process_frame
