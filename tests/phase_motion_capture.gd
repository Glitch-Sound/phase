extends "res://tests/aligned_preview_capture.gd"
## REQ-033-S01、REQ-033-S02、REQ-033-S03、REQ-033-S04、REQ-033-S05、REQ-033-S06
func _capture(suffix: String) -> void:
	await super._capture(suffix)
	if OS.get_cmdline_user_args().has("--record-motion"):
		await _record_motion()
		return
	var before=root.get_texture().get_image()
	var previous=Image.load_from_file("res://artifacts/ui-review/panel-feedback-inf-progress.png")
	var masks=[Rect2i(game.T.PREVIEW_PANEL)]
	for cell in game.battle.panels:
		if game.battle.panels[cell]=="RESET":
			masks.append(Rect2i(Rect2(game.BOARD+Vector2(cell)*game.CELL+game.T.PANEL_ICON_OFFSET,Vector2.ONE*game.T.PANEL_ICON_SIZE).grow(1)))
	var outside=0
	for y in range(before.get_height()):
		for x in range(before.get_width()):
			if before.get_pixel(x,y)!=previous.get_pixel(x,y) and not masks.any(func(rect):return rect.has_point(Vector2i(x,y))):
				outside+=1
	_check(outside==0,"only reset icons and animated preview change; cell focus is preserved")
	var original=game.battle.units.duplicate(true)
	var route=game.battle.path.duplicate()
	var palette=game.palette_colors.duplicate()
	for dimensions in [Vector2i(1152,648),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(1200,1600)]:
		root.size=dimensions
		await process_frame
		var generation=game.preview_generation
		var points=game.preview_points.duplicate(true)
		await create_timer(0.2).timeout
		_check(game.preview_points!=points and game.preview_generation==generation,"actual moving frame reuses cache "+str(dimensions))
		_check(game.battle.units==original and game.battle.path==route,"animation never advances battle "+str(dimensions))
		var card=game._timeline_view().cards[1]
		_click(root.get_final_transform()*card.center)
		await process_frame
		_check(game.selected==1 and game.battle.path==route,"scaled inspection preserves animated prediction "+str(dimensions))
		await _snapshot("size-"+str(dimensions.x))
	root.size=Vector2i(1920,1080)
	await process_frame
	game.battle.path=[]
	var u=game.battle.units[0]
	u.class_name="STANDARD"
	u.gear_mutation="NORMAL"
	u.arms_mutation="NORMAL"
	for key in ["core","gear","arms"]:
		u[key]=[20,20,20,20,20]
	u.core_angle=0.0
	for i in range(3):
		u.gear_angle=[72.0,0.0,0.0][i]
		u.arms_angle=[144.0,72.0,0.0][i]
		await _sample_motion("agreement-"+str(i))
	for spd in [1,96]:
		for key in ["core","gear","arms"]:
			u[key]=[97-spd,1,1,spd,1]
		await _sample_motion("equal-SPD-"+str(spd))
	game.palette_colors=game.P.PRESETS.AMBER.duplicate()
	game._set_theme()
	await _sample_motion("AMBER")
	game.reduced_motion=true
	await _snapshot("reduced-motion")
	var stopped=game.preview_points.duplicate(true)
	var stopped_time=game.clock
	await create_timer(0.25).timeout
	_check(game.clock==stopped_time and game.preview_points==stopped,"actual GPU frames freeze under reduced motion")
	game.reduced_motion=false
	await create_timer(0.25).timeout
	_check(game.clock>stopped_time and game.preview_points!=stopped,"actual GPU frames resume")
	game.battle.units=original
	game.battle.path=route
	game.palette_colors=palette
	game._set_theme()
	game.selected=0
	await _snapshot("returned")
	var times=game.draw_times.duplicate()
	times.sort()
	print("MOTION DRAW ms p95 ",times[floori((times.size()-1)*0.95)]," / max ",times[-1])
func _snapshot(tag: String) -> void:
	_move(root.get_final_transform()*Vector2(1900,1000))
	game.queue_redraw()
	await create_timer(0.08).timeout
	await RenderingServer.frame_post_draw
	for r in range(4):
		var width=game.preview_contours[r].width
		_check(Array(game.preview_points[r]).all(func(p):return game.T.PREVIEW_PANEL.has_point(game.T.PREVIEW_CENTER+p+Vector2.ONE*width/2) and game.T.PREVIEW_PANEL.has_point(game.T.PREVIEW_CENTER+p-Vector2.ONE*width/2) and p.length()-width/2>game.T.PREVIEW_RADIUS),"moving geometry and width avoid rings and other UI "+tag)
	var path="res://artifacts/runtime/PHASE-motion-"+stamp+"-"+tag+".png"
	_check(not FileAccess.file_exists(path) and root.get_texture().get_image().save_png(path)==OK,"real motion snapshot "+tag)
	print("MOTION FRAME ",ProjectSettings.globalize_path(path)," / t ",game.clock)
func _sample_motion(tag: String) -> void:
	await _snapshot(tag+"-0")
	var points=game.preview_points.duplicate(true)
	var state=game.battle.units.duplicate(true)
	var periods=game.preview_contours.slice(0,3).map(func(curve):return TAU/curve.speed)
	await create_timer(0.7).timeout
	await _snapshot(tag+"-1")
	_check(game.preview_points!=points and game.battle.units==state,"time moves all tested configurations without changing real values "+tag)
	print("MOTION PERIODS ",tag," / ",periods)
func _record_motion() -> void:
	root.size=Vector2i(1920,1080)
	await process_frame
	await RenderingServer.frame_post_draw
	var directory="res://artifacts/runtime/motion-clip-"+stamp
	DirAccess.make_dir_recursive_absolute(directory)
	var ignore=FileAccess.open(directory+"/.gdignore",FileAccess.WRITE)
	ignore.close()
	var rows=[]
	var state=game.battle.units.duplicate(true)
	var route=game.battle.path.duplicate()
	var crop=Rect2i(game.T.PREVIEW_PANEL)
	for i in range(120):
		await process_frame
		await RenderingServer.frame_post_draw
		var picture=root.get_texture().get_image()
		picture.convert(Image.FORMAT_RGBA8)
		var hash=HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(picture.get_data())
		var path=directory+("/frame-%03d.png" % i)
		var frame=picture if i==0 else picture.get_region(crop)
		_check(frame.save_png(path)==OK,"actual temporal frame "+str(i))
		rows.append({"file":path.get_file(),"time":game.clock,"sha256":hash.finish().hex_encode(),"x":0 if i==0 else crop.position.x,"y":0 if i==0 else crop.position.y})
	_check(game.battle.units==state and game.battle.path==route,"whole animation recording keeps actual battle state")
	var manifest={"width":1920,"height":1080,"frames":rows,"turn":game.battle.turn,"actor":game.battle.actor,"inf":game.M.sync(game.battle.preview(),1),"periods":game.preview_contours.slice(0,3).map(func(curve):return TAU/curve.speed)}
	var file=FileAccess.open(directory+"/frames.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t"))
	file.close()
	print("MOTION CLIP ",ProjectSettings.globalize_path(directory+"/frames.json"))
