extends SceneTree
var game
var checks=0
var failures=0
var stamp=str(Time.get_unix_time_from_system()).replace(".","-")
func _initialize() -> void:
	_run.call_deferred()
## REQ-018-S03、REQ-034-S06、NREQ-002-S01
func _run() -> void:
	game=load("res://tests/panel_audit.gd").new()
	game.settings_path="res://artifacts/runtime/panels-capture-"+stamp+".json"
	root.add_child(game)
	await process_frame
	for layout_seed in [0,1,128]:
		game.panel_seed_override=layout_seed
		for dimensions in [Vector2i(1152,648),Vector2i(1920,1080),Vector2i(2560,1440)]:
			root.size=dimensions
			root.grab_focus()
			await process_frame
			game._start_battle()
			for attempt in range(60):
				if root.has_focus() and game.window_focused:
					break
				root.grab_focus()
				await create_timer(0.02).timeout
			await _capture("seed-"+str(layout_seed)+"-"+str(dimensions.x))
			_click(root.get_final_transform()*(game.BOARD+Vector2(4.5,4.5)*game.CELL))
			await process_frame
			_check(game.battle.path==[Vector2i(4,4)],"real transformed GUI board click "+str([layout_seed,dimensions]))
	root.size=Vector2i(1920,1080)
	await process_frame
	game.panel_seed_override=128
	game._start_battle()
	var cells={}
	for kind in ["SHIFT","LOCK","REVERSE"]:
		cells[kind]=game.battle.panels.keys().filter(func(cell):return game.battle.panels[cell]==kind)[0]
		var units=game.battle.units.duplicate(true)
		var path=game.battle.path.duplicate()
		_move(root.get_final_transform()*(game.BOARD+(Vector2(cells[kind])+Vector2.ONE/2)*game.CELL))
		await create_timer(0.8).timeout
		_check(game.panel_probe._get_tooltip((Vector2(cells[kind])+Vector2.ONE/2)*game.CELL)==game.PANEL_VIEWS[kind].text,"effect hover meaning "+kind)
		_check(game.battle.units==units and game.battle.path==path,"hover never changes route or units "+kind)
		await _capture("hover-"+kind.to_lower())
	# 3種類を実際の生成セルで踏み、予測と確定の回転が一致することを確認する。
	for kind in cells:
		game._start_battle()
		var cell: Vector2i=cells[kind]
		var source=cell+Vector2i.DOWN if cell.y==0 else cell+Vector2i.UP
		game.battle.units[0].pos=source
		for i in range(1,4):
			game.battle.units[i].pos=Vector2i(7+i%3,9)
		game.battle.units[0].gear_angle=0
		game.battle.units[0].arms_angle=0
		_click(root.get_final_transform()*(game.BOARD+(Vector2(cell)+Vector2.ONE/2)*game.CELL))
		await process_frame
		var preview=game.battle.preview()
		var expected={"SHIFT":Vector2(330,60),"LOCK":Vector2(0,30),"REVERSE":Vector2(330,330)}[kind]
		_check(Vector2(preview.gear_angle,preview.arms_angle)==expected,"actual generated effect preserves rotation "+kind)
		_click(root.get_final_transform()*(game.BOARD+(Vector2(cell)+Vector2.ONE/2)*game.CELL),true)
		await process_frame
		_check(game.battle.mode=="CHOICE" and game.battle.units[0].gear_angle==expected.x and game.battle.units[0].arms_angle==expected.y,"commit same prediction "+kind)
		game._clear_overlay()
		game.battle.mode="MOVE"
		game.selected=0
		await _capture("occupied-"+kind.to_lower())
	game._start_battle()
	game._help()
	await _capture("help")
	game._close_aux()
	game.collection.stage_index=2
	game._start_battle()
	await _capture("breach")
	game.collection.stage_index=0
	game._start_battle()
	_click(root.get_final_transform()*(game.BOARD+Vector2(4.5,4.5)*game.CELL))
	_click(root.get_final_transform()*(game.BOARD+Vector2(5.5,4.5)*game.CELL))
	_click(root.get_final_transform()*(game.BOARD+Vector2(5.5,4.5)*game.CELL),true)
	await process_frame
	_check(game.battle.mode=="CHOICE","actual endpoint opens action overlay")
	var damage=game.overlay.find_children("*","Button",true,false).filter(func(b):return b.text=="DAMAGE / ADJACENT")[0]
	_click(root.get_final_transform()*damage.get_global_rect().get_center())
	await process_frame
	_check(game.battle.mode=="TARGET","actual action button selects damage")
	await _capture("target")
	_click(root.get_final_transform()*(game.BOARD+Vector2(6.5,4.5)*game.CELL))
	await process_frame
	_check(game.battle.units[2].hp<100 and game.battle.actor==1 and game.selected==-1,"one target click damages once and advances without duplicate inspection")
	_click(root.get_final_transform()*(game.BOARD+Vector2(4.5,6.5)*game.CELL))
	_click(root.get_final_transform()*(game.BOARD+Vector2(5.5,6.5)*game.CELL))
	game.message_time=0
	game.toasts=[]
	_move(Vector2(1900,1000))
	await _capture("battle")
	game._restart()
	await process_frame
	_check(game.build_open,"capture runner returns BUILD without saving")
	print("PANEL GPU: %d checks / %d failures" % [checks,failures])
	print("PANEL REFERENCE CELLS ",cells)
	quit(0 if failures==0 else 1)
## REQ-018-S03
func _capture(suffix: String) -> void:
	game.queue_redraw()
	await create_timer(0.12).timeout
	await RenderingServer.frame_post_draw
	var picture=root.get_texture().get_image()
	var transform=Transform2D.IDENTITY.scaled(Vector2(picture.get_width()/1920.0,picture.get_height()/1080.0))
	_check(game.drawn_icons.size()==game.battle.panels.size() and game.drawn_icons.size()==20,"all twenty actual icons rendered "+suffix)
	_check(not game.drawn_text.any(func(t):return t.text in ["S+","L=","R-"]),"no letter substitute "+suffix)
	for kind in ["SHIFT","LOCK","REVERSE"]:
		# HELPは盤面を覆うため、盤面の明度ではなく前面の凡例を検査する。
		if is_instance_valid(game.auxiliary):
			var labels=game.auxiliary.find_children("*","Label",true,false)
			_check(labels.any(func(label):return label.visible and label.text==game.PANEL_VIEWS[kind].short),"foreground HELP legend "+kind)
			continue
		var icon=game.drawn_icons.filter(func(i):return i.kind==kind)[0]
		var region=Rect2i(transform*icon.rect)
		var bright=0
		for y in range(region.position.y,region.end.y):
			for x in range(region.position.x,region.end.x):
				var pixel=picture.get_pixel(x,y)
				if maxf(pixel.r,maxf(pixel.g,pixel.b))>0.35:
					bright+=1
		_check(bright>10,"visible colored icon pixels "+kind+" / "+suffix+" / "+str(bright))
	var path="res://artifacts/runtime/PHASE-panels-"+stamp+"-"+suffix+".png"
	_check(not FileAccess.file_exists(path) and picture.save_png(path)==OK,"unique capture "+suffix)
	print("CAPTURE ",ProjectSettings.globalize_path(path))
func _click(point: Vector2,double_click: bool=false) -> void:
	for pressed in [true,false]:
		var event=InputEventMouseButton.new()
		event.position=point
		event.global_position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		event.double_click=double_click
		root.push_input(event,false)
func _move(point: Vector2) -> void:
	var event=InputEventMouseMotion.new()
	event.position=point
	event.global_position=point
	root.push_input(event,false)
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
