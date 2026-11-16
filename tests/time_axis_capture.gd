extends SceneTree
var game
var checks=0
var failures=0
var stamp=str(Time.get_unix_time_from_system()).replace(".","-")
func _initialize() -> void:
	_run.call_deferred()
## REQ-019-S06、REQ-019-S07、REQ-019-S08、NREQ-001-S01
func _run() -> void:
	game=load("res://tests/map_orbit_audit.gd").new()
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
	var view=game._timeline_view()
	var future=view.events.filter(func(e):return e.repeated)[0]
	var label
	for group in view.groups:
		for item in group.labels:
			if item.event==future:
				label=item
	_click(root.get_final_transform()*label.rect.get_center())
	await process_frame
	_check(game.timeline_selected_event.time==future.time,"future event selection retains actual occurrence")
	await _capture("future-selected")
	game.battle.units[2].hp=0.0
	await _capture("defeated-A")
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
	print("TIME AXIS GPU: %d checks / %d failures" % [checks,failures])
	print("DRAW CPU MS median ",times[times.size()/2]," / max ",times[-1])
	quit(0 if failures==0 else 1)
## REQ-019-S04、REQ-019-S06、REQ-019-S07
func _capture(suffix: String) -> void:
	game.queue_redraw()
	await create_timer(0.16).timeout
	await RenderingServer.frame_post_draw
	var picture=root.get_texture().get_image()
	var view=game._timeline_view()
	var transform=Transform2D.IDENTITY.scaled(Vector2(picture.get_width()/1920.0,picture.get_height()/1080.0))
	for card in view.cards:
		_check(picture.get_pixelv(Vector2i(transform*card.rect.position))==game.BG,"no card background or frame "+suffix)
		_check(game.mono.get_string_size(game._hp(card.unit.hp)+"/"+game._hp(card.unit.max_hp),HORIZONTAL_ALIGNMENT_LEFT,-1,game.T.TIMELINE_HP_FONT).x<=card.rect.size.x,"current HP fits state "+suffix)
	var visible=Rect2(Vector2.ZERO,Vector2(root.size))
	_check(game.drawn_text.all(func(t):return visible.encloses(root.get_final_transform()*Rect2(t.position-Vector2(0,t.font_size),Vector2(t.typeface.get_string_size(t.text,HORIZONTAL_ALIGNMENT_LEFT,-1,t.font_size).x,t.font_size+6)))),"GPU all text within window "+suffix)
	if suffix=="battle":
		var previous=Image.load_from_file("res://artifacts/ui-review/map-orbit-battle.png")
		var changed=0
		for y in range(1080):
			for x in range(384,1920):
				if picture.get_pixel(x,y)!=previous.get_pixel(x,y):
					changed+=1
		_check(changed==0,"all pixels outside left action-order area unchanged: "+str(changed))
	var path="res://artifacts/runtime/PHASE-time-axis-"+stamp+"-"+suffix+".png"
	_check(not FileAccess.file_exists(path) and picture.save_png(path)==OK,"unique screenshot "+suffix)
	print("CAPTURE ",ProjectSettings.globalize_path(path))
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
