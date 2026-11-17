extends "res://tests/aligned_preview_capture.gd"
## REQ-018-S03、REQ-018-S04、REQ-033-S01、REQ-033-S03、REQ-033-S04、NREQ-001-S04
func _capture(suffix: String) -> void:
	await super._capture(suffix)
	if game.battle.path.is_empty():
		_check(false,"capture requires the actual aligned route")
		return
	var picture=root.get_texture().get_image()
	var previous=Image.load_from_file("res://artifacts/ui-review/balanced-information-inf-progress.png")
	var masks=[Rect2i(game.T.PREVIEW_PANEL),Rect2i(game._cell_rect(game.battle.units[0].pos).grow(4)),Rect2i(game._cell_rect(game.battle.path.back()).grow(4))]
	for cell in game.battle.panels:
		if game.battle.panels[cell]=="RESET":
			masks.append(Rect2i(Rect2(game.BOARD+Vector2(cell)*game.CELL+game.T.PANEL_ICON_OFFSET,Vector2.ONE*game.T.PANEL_ICON_SIZE).grow(1)))
	var counts=_diff(picture,previous,masks)
	_check(counts[0]>0 and counts[1]==0,"only RESET icons cell focus and preview change "+str(counts))
	print("PANEL FEEDBACK PIXELS ",counts)
	var path="res://artifacts/runtime/PHASE-panel-feedback-"+stamp+"-battle.png"
	_check(not FileAccess.file_exists(path) and picture.save_png(path)==OK,"unique progressed red preview capture")
	print("PANEL FEEDBACK CAPTURE ",ProjectSettings.globalize_path(path))
	var units=game.battle.units.duplicate(true)
	var panels=game.battle.panels.duplicate(true)
	var route=game.battle.path.duplicate()
	var selected=game.selected
	var palette=game.palette_colors.duplicate()
	for dimensions in [Vector2i(1152,648),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(1200,1600)]:
		root.size=dimensions
		await process_frame
		game.battle.units=units.duplicate(true)
		game.battle.panels=panels.duplicate(true)
		game.battle.path=route.duplicate()
		_click_cell(game.battle.units[0].pos)
		await process_frame
		_check(game.battle.path.is_empty(),"real cancel at scaled source "+str(dimensions))
		for cell in route:
			_click_cell(cell)
			await process_frame
		_check(game.battle.path==route and game.battle.units==units,"real route reconstruction preserves state "+str(dimensions))
		var point=game._timeline_view().cards[1].center
		_move(root.get_final_transform()*point)
		_click(root.get_final_transform()*point)
		await process_frame
		_check(game.selected==1 and game.timeline_hover==1 and game.battle.path==route,"timeline inspection keeps aligned prediction "+str(dimensions))
		await _snapshot("progress-"+str(dimensions.x)+"-"+str(dimensions.y))
		await _focus_fixtures(dimensions)
		if dimensions in [Vector2i(1152,648),Vector2i(1920,1080)]:
			for preset in ["DEFAULT","AMBER","CUSTOM"]:
				if preset!="DEFAULT" and dimensions.x!=1920:
					continue
				game.palette_colors=game.P.PRESETS.AMBER.duplicate() if preset=="AMBER" else game.P.PRESETS.DEFAULT.duplicate()
				if preset=="CUSTOM":
					game.palette_colors[0]=game.P.PRESETS.ICE[0]
				game._set_theme()
				await _strength_fixtures(str(dimensions.x)+"-"+preset)
			game.palette_colors=palette.duplicate()
			game._set_theme()
	game.battle.units=units
	game.battle.panels=panels
	game.battle.path=route
	game.selected=selected
	game.timeline_hover=-1
	game.timeline_hover_event={}
	game.palette_colors=palette
	game._set_theme()
	root.size=Vector2i(1920,1080)
	await _snapshot("returned")
	var ordered=game.draw_times.duplicate()
	ordered.sort()
	print("PANEL FEEDBACK DRAW ms p95 ",ordered[floori((ordered.size()-1)*0.95)]," / max ",ordered[-1])
func _snapshot(suffix: String,save: bool=true) -> Image:
	_move(root.get_final_transform()*Vector2(1900,1000))
	game.queue_redraw()
	await create_timer(0.06).timeout
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	if save:
		var path="res://artifacts/runtime/PHASE-panel-feedback-"+stamp+"-"+suffix+".png"
		_check(not FileAccess.file_exists(path) and image.save_png(path)==OK,"snapshot "+suffix)
		print("FEEDBACK FIXTURE ",ProjectSettings.globalize_path(path))
	return image
## REQ-018-S04
func _focus_fixtures(dimensions: Vector2i) -> void:
	# 端と隣接の表示fixtureは他の生存者の占有を避ける。
	for i in range(1,4):
		game.battle.units[i].pos=Vector2i(6+i,7)
	game.battle.panels={}
	var cells=[Vector2i(0,0),Vector2i(9,0),Vector2i(0,9),Vector2i(9,9),Vector2i(4,4)]
	for cell in cells:
		game.battle.panels[cell]="RESET"
	game.battle.panels[Vector2i(5,4)]="CLOCKWISE"
	game.battle.panels[Vector2i(4,5)]="COUNTERCLOCKWISE"
	for cell in cells:
		game.battle.units[0].pos=cell
		game.selected=-1
		game.timeline_hover=-1
		game.timeline_hover_event={}
		game.battle.path=[]
		for endpoint in [false,true]:
			game.battle.units[0].pos=cell+(Vector2i.DOWN if cell.y==0 else Vector2i.UP) if endpoint else cell
			game.selected=-1 if endpoint else 0
			game.battle.path=[cell] if endpoint else []
			game.hide_cell_focus=true
			var baseline=await _snapshot("baseline",false)
			game.hide_cell_focus=false
			var tag="focus-"+str(dimensions.x)+"-"+str(cell.x)+"-"+str(cell.y)+("-endpoint" if endpoint else "-unit")
			var after=await _snapshot(tag,cell in [Vector2i(0,0),Vector2i(9,9)])
			var scale=Vector2(after.get_size())/Vector2(1920,1080)
			var cell_rect=game._cell_rect(cell)
			var outer=Rect2i(Transform2D.IDENTITY.scaled(scale)*cell_rect.grow(3.0))
			var inner=Rect2i(Transform2D.IDENTITY.scaled(scale)*cell_rect.grow(-3.0))
			var pixel_board=Transform2D.IDENTITY.scaled(scale)*Rect2(game.BOARD,Vector2.ONE*game.CELL*10)
			# 小数の境界に覆われる画素は切り捨てない。
			var board=Rect2i(pixel_board.position.floor(),pixel_board.end.ceil()-pixel_board.position.floor())
			var changed=0
			var bad=0
			for y in range(outer.position.y,outer.end.y):
				for x in range(outer.position.x,outer.end.x):
					if after.get_pixel(x,y)==baseline.get_pixel(x,y):
						continue
					changed+=1
					if inner.has_point(Vector2i(x,y)) or not board.has_point(Vector2i(x,y)):
						bad+=1
			_check(changed>0 and bad==0,"focus pixels stay on border inside map and out of cell interior "+tag+" / "+str([changed,bad]))
			var icon=Rect2i(Transform2D.IDENTITY.scaled(scale)*Rect2(game.BOARD+Vector2(cell)*game.CELL+game.T.PANEL_ICON_OFFSET,Vector2.ONE*game.T.PANEL_ICON_SIZE))
			var glyph_changed=0
			var glyph_ink=0
			for y in range(icon.position.y,icon.end.y):
				for x in range(icon.position.x,icon.end.x):
					var a=after.get_pixel(x,y)
					var b=baseline.get_pixel(x,y)
					if b.b>0.3 and b.b>b.r*1.2:
						glyph_ink+=1
						if a!=b:
							glyph_changed+=1
			_check(glyph_ink>0 and glyph_changed==0,"filled RESET ink is never overpainted by focus "+tag)
	game.battle.units[0].pos=Vector2i(4,4)
	game.battle.path=[]
	_click_cell(Vector2i(5,4))
	await process_frame
	_click(root.get_final_transform()*game._timeline_view().cards[0].center)
	await process_frame
	_check(game.battle.at(Vector2i(5,4))<0 and game.battle.path==[Vector2i(5,4)] and game.selected==0,"adjacent fixture uses a legal empty endpoint and actual inspection input "+str(dimensions))
	game.hide_cell_focus=true
	var adjacent_before=await _snapshot("adjacent-baseline-"+str(dimensions.x))
	game.hide_cell_focus=false
	var adjacent=await _snapshot("adjacent-"+str(dimensions.x))
	var adjacent_scale=Vector2(adjacent.get_size())/Vector2(1920,1080)
	var adjacent_masks=[]
	for cell in [Vector2i(4,4),Vector2i(5,4)]:
		var pixel_rect=Transform2D.IDENTITY.scaled(adjacent_scale)*game._cell_rect(cell).grow(3)
		var rect=Rect2i(pixel_rect.position.floor(),pixel_rect.end.ceil()-pixel_rect.position.floor())
		adjacent_masks.append(rect)
		_check(adjacent.get_region(rect).get_data()!=adjacent_before.get_region(rect).get_data(),"both adjacent cells retain distinct focus pixels "+str(dimensions)+" / "+str(cell))
	_check(_diff(adjacent,adjacent_before,adjacent_masks)[1]==0,"adjacent focus leaves all other cells unchanged "+str(dimensions))
	game.selected=-1
	game.battle.path=[]
	game.battle.units[0].pos=Vector2i(4,4)
	game.battle.units[2].pos=Vector2i(5,4)
	game.battle.mode="TARGET"
	game.battle.selected_skill=game.C.DAMAGE
	await _snapshot("target-"+str(dimensions.x))
	game.battle.back()
	game._clear_overlay()
	game.battle.mode="MOVE"
## REQ-033-S01、REQ-033-S03、REQ-033-S04
func _strength_fixtures(tag: String) -> void:
	game.battle.path=[]
	var u=game.battle.units[game.battle.actor]
	for key in ["core","gear","arms"]:
		u[key]=[20,20,20,20,20]
	u.class_name="STANDARD"
	u.gear_mutation="NORMAL"
	u.arms_mutation="NORMAL"
	u.core_angle=0.0
	var metrics=[]
	for i in range(3):
		u.gear_angle=[72.0,0.0,0.0][i]
		u.arms_angle=[144.0,72.0,0.0][i]
		var image=await _snapshot("strength-"+tag+"-"+str(i))
		var scale=Vector2(image.get_size())/Vector2(1920,1080)
		var rect=Rect2i(Transform2D.IDENTITY.scaled(scale)*game.T.PREVIEW_PANEL)
		var brightness=0.0
		var pixels=0
		for y in range(rect.position.y,rect.end.y):
			for x in range(rect.position.x,rect.end.x):
				var point=Vector2(x,y)/scale
				if point.distance_to(game.T.PREVIEW_CENTER)<game.T.PREVIEW_RADIUS+10:
					continue
				var c=image.get_pixel(x,y)
				brightness+=c.r+c.g+c.b
				if maxf(c.r,maxf(c.g,c.b))>0.1:
					pixels+=1
		metrics.append([brightness,pixels])
		for r in range(4):
			var curve=game.preview_contours[r]
			_check(Array(curve.points).all(func(p):return game.T.PREVIEW_PANEL.has_point(game.T.PREVIEW_CENTER+p+Vector2.ONE*curve.width/2) and game.T.PREVIEW_PANEL.has_point(game.T.PREVIEW_CENTER+p-Vector2.ONE*curve.width/2)),"contour and full line width remain inside preview "+tag)
	_check(metrics[0][0]<metrics[1][0] and metrics[1][0]<metrics[2][0] and metrics[0][1]<metrics[1][1] and metrics[1][1]<metrics[2][1],"actual low medium high pixels increase brightness and visible area "+tag+" / "+str(metrics))
	print("STRENGTH PIXELS ",tag," / ",metrics)
func _diff(a: Image,b: Image,masks: Array) -> Array:
	var inside=0
	var outside=0
	var samples=[]
	for y in range(a.get_height()):
		for x in range(a.get_width()):
			if a.get_pixel(x,y)!=b.get_pixel(x,y):
				if masks.any(func(rect):return rect.has_point(Vector2i(x,y))):inside+=1
				else:
					outside+=1
					if samples.size()<12:
						samples.append([x,y,a.get_pixel(x,y),b.get_pixel(x,y)])
	if outside>0:
		print("OUTSIDE DIFF ",outside," / ",samples)
	return [inside,outside]
