extends SceneTree
var game
var checks=0
var failures=0
var stamp=str(Time.get_unix_time_from_system()).replace(".","-")
func _initialize() -> void:
	_run.call_deferred()
## REQ-019-S06、REQ-019-S07、REQ-019-S08、NREQ-001-S01
func _run() -> void:
	game=load("res://tests/order_axis_audit.gd").new()
	game.settings_path="res://artifacts/runtime/time-axis-capture-"+stamp+".json"
	root.add_child(game)
	await process_frame
	for dimensions in [Vector2i(1152,648),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(1200,1600)]:
		root.size=dimensions
		root.grab_focus()
		await process_frame
		game._start_battle()
		await _capture("start-"+str(dimensions.x))
		# macOSの初回ウィンドウ有効化を待ち、実際のフォーカスなしで入力を合格にしない。
		for attempt in range(60):
			if root.has_focus() and game.window_focused:
				break
			root.grab_focus()
			await create_timer(0.02).timeout
		game._cell_input(Vector2i(4,4))
		_check(game.window_focused,"GPU window has actual focus before input")
		var units=game.battle.units.duplicate(true)
		var path=game.battle.path.duplicate()
		var view=game._timeline_view()
		_move(root.get_final_transform()*view.cards[2].center)
		await process_frame
		_check(game.timeline_hover==2,"GPU transformed hover "+str(dimensions))
		_click(root.get_final_transform()*view.cards[2].center)
		await process_frame
		_check(game.selected==2 and game.battle.units==units and game.battle.path==path,"GPU transformed inspection preserves route "+str(dimensions))
		await _capture("selected-A-"+str(dimensions.x))
		var help=game.hud.find_children("*","Button",true,false).filter(func(b):return b.text=="HELP")[0]
		_click(root.get_final_transform()*help.get_global_rect().get_center())
		await process_frame
		_check(is_instance_valid(game.auxiliary) and game.timeline_hover==-1,"GPU menu still opens and clears hover")
		game._close_aux()
	root.size=Vector2i(1920,1080)
	await process_frame
	game._start_battle()
	for i in range(4):
		game.battle.units[i].next_time=100.0
	game.battle.next_actor()
	await _capture("equal-times")
	game.battle.units[2].next_time=100.01
	await _capture("near-times")
	game._start_battle()
	for i in range(4):
		game.battle.units[i].core=[20,20,20,20,20]
		game.battle.units[i].next_time=[0.0,50.0,75.0,100.0][i]
	game.battle.next_actor()
	await _capture("wait-third")
	game.battle.units[3].next_time=300.0
	await _capture("range-expanded")
	game.battle.units[3].next_time=100.0
	await _capture("range-restored")
	var view=game._timeline_view()
	var future=view.events.filter(func(e):return e.repeated)[0]
	_click(root.get_final_transform()*future.point)
	await process_frame
	_check(game.timeline_selected_event.time==future.time,"future event selection retains actual occurrence")
	await _capture("future-selected")
	game.battle.units[2].hp=0.0
	await _capture("defeated-A")
	game._start_battle()
	for i in range(4):
		game.battle.units[i].core=[1,1,1,96,1] if i<3 else [25,25,25,1,24]
		game.battle.units[i].next_time=50.0 if i<3 else 450.0
		game.battle.units[i].max_hp=game.M.max_hp(game.battle.units[i])
		game.battle.units[i].hp=game.battle.units[i].max_hp
	game.battle.next_actor()
	for dimensions in [Vector2i(1152,648),Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size=dimensions
		root.grab_focus()
		await process_frame
		for event in game._timeline_view().events:
			_click(root.get_final_transform()*event.point)
			_check(game.selected==event.index and game.timeline_selected_event.time==event.time,"dense GPU input "+str(dimensions)+" / "+str(event.rank))
		await _capture("dense-"+str(dimensions.x))
	root.size=Vector2i(1920,1080)
	await process_frame
	game.battle.result="DEFEAT"
	game.battle.mode="RESULT"
	game._result()
	await _capture("result")
	game._start_battle()
	for unit in game.battle.units:
		for key in ["core","gear","arms"]:
			unit[key]=[96,1,1,1,1]
		unit.max_hp=game.M.max_hp(unit)
		unit.hp=unit.max_hp
	await _capture("max-hp")
	game._start_battle()
	game.palette_colors=game.P.PRESETS.AMBER.duplicate()
	game._set_theme()
	await _capture("amber")
	game.palette_colors=game.P.PRESETS.DEFAULT.duplicate()
	game._set_theme()
	game._cell_input(Vector2i(4,4))
	game._cell_input(Vector2i(5,4))
	game._cell_input(Vector2i(5,4),true)
	await process_frame
	game.battle.choose_skill(game.C.DAMAGE)
	game._clear_overlay()
	game._hud()
	game._cell_input(Vector2i(6,4))
	game._cell_input(Vector2i(4,6))
	game._cell_input(Vector2i(5,6))
	game.message_time=0
	game.toasts=[]
	game.selected=-1
	game.timeline_hover=-1
	game.timeline_hover_event={}
	await _capture("battle")
	game._restart()
	await process_frame
	_check(game.build_open,"capture runner returns BUILD without save")
	var times=game.draw_times.duplicate()
	times.sort()
	print("TIMELINE PROGRESS GPU: %d checks / %d failures" % [checks,failures])
	print("DRAW CPU MS median ",times[times.size()/2]," / max ",times[-1])
	quit(0 if failures==0 else 1)
## REQ-019-S04、REQ-019-S06、REQ-019-S07
func _capture(suffix: String) -> void:
	game.queue_redraw()
	await create_timer(0.16).timeout
	await RenderingServer.frame_post_draw
	var picture=root.get_texture().get_image()
	var view=game._timeline_view()
	_check(not game.axis_centers.any(func(c):return Rect2(180,200,40,440).has_point(c.position)),"no central unit names "+suffix)
	_check(view.links.size()==view.events.size(),"one unit association per point "+suffix)
	var transform=Transform2D.IDENTITY.scaled(Vector2(picture.get_width()/1920.0,picture.get_height()/1080.0))
	if suffix=="wait-third":
		# 予定0、50、75、100、100、150の2番目は、白2/3、灰1/3である。
		var event=view.events[1]
		var bright=_brightness(picture,Vector2i(transform*(event.point+Vector2(-1,1).normalized()*event.radius)))
		var dim=_brightness(picture,Vector2i(transform*(event.point+Vector2(-1,-1).normalized()*event.radius)))
		_check(bright>dim+0.25 and dim<0.45,"actual white arc means progressed share, gray means remaining")
	if suffix!="result" and not view.events.is_empty() and view.events[0].radius>=8:
		for event in view.events.filter(func(e):return e.remaining<=game.B.TIME_EPS):
			var white=_peak_color(picture,Vector2i(transform*(event.point+Vector2(-1,1).normalized()*event.radius)))
			_check(maxf(white.r,maxf(white.g,white.b))>0.6 and maxf(white.r,maxf(white.g,white.b))-minf(white.r,minf(white.g,white.b))<0.05,"zero wait ring is white even for queued or palette accent "+suffix+" / "+str(event.index))
		var far=view.events[-1]
		if far.remaining>0:
			_check(_brightness(picture,Vector2i(transform*(far.point+Vector2(-1,1).normalized()*far.radius)))<0.45,"maximum wait stays gray "+suffix)
	for card in view.cards:
		_check(picture.get_pixelv(Vector2i(transform*card.rect.position))==game.BG,"no card background or frame "+suffix)
		_check(game.mono.get_string_size(game._hp(card.unit.hp)+"/"+game._hp(card.unit.max_hp),HORIZONTAL_ALIGNMENT_LEFT,-1,game.T.TIMELINE_HP_FONT).x<=card.rect.size.x,"current HP fits state "+suffix)
	var visible=Rect2(Vector2.ZERO,Vector2(root.size))
	_check(game.drawn_text.all(func(t):return visible.encloses(root.get_final_transform()*Rect2(t.position-Vector2(0,t.font_size),Vector2(t.typeface.get_string_size(t.text,HORIZONTAL_ALIGNMENT_LEFT,-1,t.font_size).x,t.font_size+6)))),"GPU all text within window "+suffix)
	if suffix=="battle":
		var previous=Image.load_from_file("res://artifacts/ui-review/order-axis-battle.png")
		var changed=0
		for y in range(1080):
			for x in range(384,1920):
				if picture.get_pixel(x,y)!=previous.get_pixel(x,y):
					changed+=1
		_check(changed==0,"all pixels outside left action-order area unchanged: "+str(changed))
	var path="res://artifacts/runtime/PHASE-timeline-progress-"+stamp+"-"+suffix+".png"
	_check(not FileAccess.file_exists(path) and picture.save_png(path)==OK,"unique screenshot "+suffix)
	print("CAPTURE ",ProjectSettings.globalize_path(path))
func _peak_color(picture: Image,point: Vector2i) -> Color:
	var maximum=0.0
	var peak=Color.BLACK
	for y in range(point.y-1,point.y+2):
		for x in range(point.x-1,point.x+2):
			var color=picture.get_pixel(x,y)
			var value=maxf(color.r,maxf(color.g,color.b))
			if value>maximum:
				maximum=value
				peak=color
	return peak
func _brightness(picture: Image,point: Vector2i) -> float:
	var color=_peak_color(picture,point)
	return maxf(color.r,maxf(color.g,color.b))
func _click(point: Vector2) -> void:
	for pressed in [true,false]:
		var event=InputEventMouseButton.new()
		event.position=point
		event.global_position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
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
