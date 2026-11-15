extends "res://tests/unit_capture.gd"
func _initialize() -> void:
	stamp="orbit-"+stamp
	super._initialize()
## REQ-019-S01、REQ-033-S03、NREQ-001-S01、NREQ-001-S03
func _run() -> void:
	game=load("res://tests/phase_preview_audit.gd").new()
	game.settings_path="res://artifacts/runtime/orbit-no-settings-"+stamp+".json"
	root.add_child(game)
	await process_frame
	game._start_battle()
	game._cell_input(Vector2i(4,4))
	game._cell_input(Vector2i(5,4))
	game._cell_input(Vector2i(5,4),true)
	await process_frame
	game.battle.choose_skill(game.C.DAMAGE)
	game._clear_overlay()
	game._cell_input(Vector2i(6,4))
	game._cell_input(Vector2i(4,6))
	game._cell_input(Vector2i(5,6))
	game.message_time=0
	game.toasts=[]
	await _capture("battle")
	await _pixel_audit()
	var u=game.battle.preview()
	print("STATE ",JSON.stringify({"turn":game.battle.turn,"actor":u.id,"enemy_a_hp":game.battle.units[2].hp,"path":str(game.battle.path),"inf":game.M.sync(u,1).factor*100,"res":game.M.sync(u,2).factor*100}))
	await _performance("baseline")
	game._help()
	await _capture("help")
	game._close_aux()
	var original=game.battle.units[game.battle.actor].duplicate(true)
	var path=game.battle.path.duplicate()
	game.battle.path=[]
	for key in ["core","gear","arms"]:
		game.battle.units[game.battle.actor][key]=[20,20,20,20,20]
	game.battle.units[game.battle.actor].class_name="STANDARD"
	game.battle.units[game.battle.actor].gear_angle=0.0
	game.battle.units[game.battle.actor].arms_angle=0.0
	await _capture("aligned")
	game.battle.units[game.battle.actor].arms_angle=72.0
	await _capture("pair")
	game.battle.units[game.battle.actor].gear_angle=72.0
	game.battle.units[game.battle.actor].arms_angle=144.0
	await _capture("apart")
	game.battle.units[game.battle.actor]=original
	game.battle.path=path
	game.palette_colors=game.P.PRESETS.AMBER.duplicate()
	game._set_theme()
	await _capture("amber")
	root.size=Vector2i(1440,810)
	await _capture("window-1440")
	root.size=Vector2i(1152,648)
	await _capture("minimum")
	await _performance("minimum")
	root.size=Vector2i(1200,1600)
	await _capture("portrait")
	root.size=Vector2i(2560,1080)
	await _capture("wide")
	root.size=Vector2i(1920,1080)
	game.palette_colors=game.P.PRESETS.ICE.duplicate()
	game._set_theme()
	await _capture("ice")
	game.palette_colors=game.P.PRESETS.DEFAULT.duplicate()
	game.palette_colors[0]=game.P.PRESETS.AMBER[0]
	game._set_theme()
	await _capture("custom")
	game.palette_colors=game.P.PRESETS.DEFAULT.duplicate()
	game._set_theme()
	root.mode=Window.MODE_FULLSCREEN
	await create_timer(0.7).timeout
	await _capture("fullscreen")
	_click_cell(Vector2i(6,4))
	if game.selected!=2:
		_fail("fullscreen scaled input reaches inspected enemy")
	print("FULLSCREEN mode ",root.mode," / size ",root.size," / viewport ",root.get_texture().get_image().get_size()," / scale ",root.get_final_transform().get_scale()," / inspected ",game.selected)
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1920,1080)
	await create_timer(0.5).timeout
	game.selected=-1
	await _capture("returned")
	game._cell_input(Vector2i(5,6),true)
	await _capture("action")
	# 実UIの両陣営攻撃と回復は、到達可能な隣接配置fixtureで操作する。
	for actor in [0,2]:
		game._start_battle()
		await process_frame
		game.battle.actor=actor
		var source=game.battle.units[actor]
		source.pos=Vector2i(5,6)
		var ally=1 if actor==0 else 3
		var enemy=2 if actor==0 else 0
		game.battle.units[ally].pos=Vector2i(6,5)
		game.battle.units[ally].hp=50
		game.battle.units[enemy].pos=Vector2i(4,5)
		game.battle.mode="MOVE"
		_click_cell(Vector2i(5,5))
		_click_cell(Vector2i(5,5),true)
		await process_frame
		# commit_pathは予測の複製へ置き換えるので、確定後の原本を再取得する。
		source=game.battle.units[actor]
		if source.pos!=Vector2i(5,5) or game.battle.mode!="CHOICE" or not is_instance_valid(game.overlay):
			_fail("both camps move and commit through enlarged-map input")
			quit(1)
			return
		print("BOTH SIDE MOVE actor ",actor," path commit PASS / gear ",source.gear_angle," / arms ",source.arms_angle)
		var heal=game.overlay.find_children("*","Button",true,false).filter(func(b):return b.text=="HEAL / ADJACENT")[0]
		heal.pressed.emit()
		await _capture("heal-target-"+str(actor))
		_click_cell(Vector2i(6,5))
		if game.battle.last_effect.kind!="HEAL" or game.battle.last_effect.actual<=0:
			_fail("actual healing remains functional")
		game.battle.actor=actor
		game.battle.mode="CHOICE"
		game._action_dialog()
		await process_frame
		var attack=game.overlay.find_children("*","Button",true,false).filter(func(b):return b.text=="DAMAGE / ADJACENT")[0]
		attack.pressed.emit()
		await _capture("attack-target-"+str(actor))
		_click_cell(Vector2i(4,5))
		if game.battle.last_effect.kind!="DAMAGE" or game.battle.last_effect.amount<=0:
			_fail("actual attack remains functional")
		print("BOTH SIDE INPUT actor ",actor," attack and healing PASS")
	game._restart()
	await process_frame
	quit(1 if failed else 0)
func _click_cell(cell: Vector2i, double_click: bool=false) -> void:
	for pressed in [true,false]:
		var event=InputEventMouseButton.new()
		event.position=root.get_final_transform()*(game.BOARD+(Vector2(cell)+Vector2.ONE/2)*game.CELL)
		event.global_position=event.position
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		event.double_click=double_click and pressed
		root.push_input(event,false)
func _capture(suffix: String,_audit: bool=false) -> void:
	game.message_time=0
	game.toasts=[]
	await super._capture(suffix,false)
func _pixel_audit() -> void:
	var image=root.get_texture().get_image()
	var previous=Image.load_from_file("res://artifacts/ui-review/unit-rings-vivid-battle.png")
	# パネル上端の1px線は中心の上下へ描かれるので、その画素も含める。
	var allowed=[Rect2i(530,100,760,760),Rect2i(150,820,1620,250).grow(1)]
	var outside=0
	var changed=0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x,y)!=previous.get_pixel(x,y):
				changed+=1
				if not allowed.any(func(rect):return rect.has_point(Vector2i(x,y))):
					outside+=1
	print("ORBIT PIXEL AUDIT changed ",changed," / outside ",outside)
	if changed==0 or outside!=0:
		_fail("only map and preview regions may change")
func _performance(label: String) -> void:
	var generation=game.preview_generation
	var generated=[]
	for i in range(30):
		var u=game.battle.preview()
		u.gear_angle=i*1.5
		var begin=Time.get_ticks_usec()
		game.V.phase_contours(u,game.status_colors)
		generated.append((Time.get_ticks_usec()-begin)/1000.0)
	# ピクセル比較とPNG保存の負荷を測定区間へ混ぜない。
	await create_timer(1.2).timeout
	game.draw_times=[]
	var frames=[]
	var start=Time.get_ticks_usec()
	var previous=start
	for i in range(180):
		await RenderingServer.frame_post_draw
		var now=Time.get_ticks_usec()
		frames.append((now-previous)/1000.0)
		previous=now
	var elapsed=(Time.get_ticks_usec()-start)/1000.0
	generated.sort()
	frames.sort()
	game.draw_times.sort()
	print("ORBIT PERF ",label," generation median ",generated[15],"ms / p95 ",generated[28],"ms; cached draw CPU median ",game.draw_times[game.draw_times.size()/2],"ms / p95 ",game.draw_times[int(game.draw_times.size()*0.95)],"ms; rendered frame median ",frames[90],"ms / p95 ",frames[171],"ms; 180 frames ",elapsed,"ms / cached ",game.preview_generation==generation," / scale ",root.get_final_transform().get_scale()," / screen scale ",DisplayServer.screen_get_scale())
	if generated[28]>33.3 or frames[171]>33.3 or game.preview_generation!=generation:
		_fail("phase preview exceeds 30Hz measurement budget or rebuilds while idle")
