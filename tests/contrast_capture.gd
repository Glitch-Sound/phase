extends SceneTree
var game
var checks=0
var failures=0
var stamp=str(Time.get_unix_time_from_system()).replace(".","-")
func _initialize() -> void:
	_run.call_deferred()
## REQ-018-S02、REQ-030-S03、REQ-033-S03
func _run() -> void:
	game=load("res://tests/side_info_audit.gd").new()
	game.settings_path="res://artifacts/runtime/contrast-lab-"+stamp+".json"
	root.add_child(game)
	await process_frame
	for dimensions in [Vector2i(1152,648),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(1200,1600)]:
		root.size=dimensions
		root.grab_focus()
		await process_frame
		game._start_battle()
		for attempt in range(60):
			if root.has_focus() and game.window_focused:
				break
			root.grab_focus()
			await create_timer(0.02).timeout
		game._cell_input(Vector2i(4,4))
		await _capture("east-"+str(dimensions.x))
		var endpoint=root.get_final_transform()*(game.BOARD+Vector2(4.5,4.5)*game.CELL)
		_click(endpoint,true)
		await process_frame
		_check(game.battle.mode=="CHOICE" and is_instance_valid(game.overlay),"scaled route commit "+str(dimensions))
		game.battle.wait_turn()
		game._after_action()
		_check(game.battle.actor==1,"hand update after commit "+str(dimensions))
		var help=game.hud.find_children("*","Button",true,false).filter(func(b):return b.text=="HELP")[0]
		_click(root.get_final_transform()*help.get_global_rect().get_center())
		await process_frame
		_check(is_instance_valid(game.auxiliary),"scaled system menu "+str(dimensions))
		game._close_aux()
	root.size=Vector2i(1920,1080)
	await process_frame
	for direction in [Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
		game._start_battle()
		game._cell_input(game.battle.units[0].pos+direction)
		await _capture("direction-"+str(direction.x)+"-"+str(direction.y))
	for dimensions in [Vector2i(1152,648),Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size=dimensions
		await process_frame
		game._start_battle()
		for i in range(4):
			game.battle.units[i].pos=[Vector2i(0,0),Vector2i(1,0),Vector2i(8,9),Vector2i(9,9)][i]
			game.battle.units[i].hp=[0.0,1.0,50.0,100.0][i]
		game.selected=2
		await _capture("hp-boundary-"+str(dimensions.x))
	root.size=Vector2i(1920,1080)
	await process_frame
	game._start_battle()
	await _capture("aligned")
	game.battle.units[0].gear_angle=72.0
	game.battle.units[0].arms_angle=144.0
	await _capture("unaligned")
	game.palette_colors=game.P.PRESETS.AMBER.duplicate()
	game._set_theme()
	await _capture("amber")
	game.palette_colors=game.P.PRESETS.DEFAULT.duplicate()
	game._set_theme()
	game._start_battle()
	game._cell_input(Vector2i(4,4))
	game._cell_input(Vector2i(5,4))
	game._cell_input(Vector2i(5,4),true)
	await process_frame
	game.battle.choose_skill(game.C.DAMAGE)
	game._clear_overlay()
	game._hud()
	await _capture("target")
	game._cell_input(Vector2i(6,4))
	_check(game.battle.units[2].hp==89 and game.battle.actor==1,"actual damage and hand progression retained")
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
	_check(game.build_open,"runner returns BUILD without save")
	var times=game.draw_times.duplicate()
	times.sort()
	print("CONTRAST GPU: %d checks / %d failures" % [checks,failures])
	print("DRAW CPU MS median ",times[times.size()/2]," / max ",times[-1])
	quit(0 if failures==0 else 1)
## REQ-018-S02、REQ-030-S03、REQ-033-S03
func _capture(suffix: String) -> void:
	game.queue_redraw()
	await create_timer(0.16).timeout
	await RenderingServer.frame_post_draw
	var picture=root.get_texture().get_image()
	var transform=Transform2D.IDENTITY.scaled(Vector2(picture.get_width()/1920.0,picture.get_height()/1080.0))
	# 画素の位置も同じ物理倍率で評価し、リングと経路の間に背景の隙間が残ることを確かめる。
	if game.battle.mode=="MOVE" and not game.battle.path.is_empty():
		var center=game.BOARD+(Vector2(game.battle.units[game.battle.actor].pos)+Vector2.ONE/2)*game.CELL
		var segment=game._route_segments()[0]
		var direction=(segment[0]-center).normalized()
		var gap=game.T.ROUTE_RING_GAP_PIXELS/transform.get_scale().x
		var point=segment[0]-direction*(game.T.ROUTE_LINE_WIDTH*game.BOARD_SCALE/2+gap/2)
		var darkest=1.0
		for offset in [-1.0,0.0,1.0]:
			var color=picture.get_pixelv(Vector2i(transform*point+direction*offset))
			darkest=minf(darkest,maxf(color.r,maxf(color.g,color.b)))
		_check(darkest<0.3,"physical dark gap outside ring "+suffix)
	for record in game.info_rings:
		if record.unit.hp>0:
			var angle=-PI/2+TAU*(record.unit.hp/record.unit.max_hp)/2
			var p=record.center+Vector2.from_angle(angle)*81*game.T.UNIT_HP_RADIUS
			var peak=_peak(picture,Vector2i(transform*p))
			_check(peak.r>0.96 and peak.g>0.96 and peak.b>0.96,"HP arc has bright white core "+suffix+" / "+str(peak))
	var visible=Rect2(Vector2.ZERO,Vector2(root.size))
	_check(game.drawn_text.all(func(t):return visible.encloses(root.get_final_transform()*Rect2(t.position-Vector2(0,t.font_size),Vector2(t.typeface.get_string_size(t.text,HORIZONTAL_ALIGNMENT_LEFT,-1,t.font_size).x,t.font_size+6)))),"texts fit "+suffix)
	if suffix=="battle":
		var previous=Image.load_from_file("res://artifacts/ui-review/side-info-battle.png")
		var old_light=0.0
		var new_light=0.0
		for y in range(704,905):
			for x in range(100,301):
				var distance=Vector2(x,y).distance_to(game.T.PREVIEW_CENTER)
				if distance<68 or distance>100:
					continue
				var before=previous.get_pixel(x,y)
				var after=picture.get_pixel(x,y)
				old_light+=before.r+before.g+before.b
				new_light+=after.r+after.g+after.b
		_check(new_light>old_light,"actual orbit annulus gets brighter without unit HP affecting comparison")
		print("ORBIT LIGHT SUM ",old_light," -> ",new_light)
		var changed=0
		for y in range(1080):
			for x in range(1920):
				var p=Vector2i(x,y)
				if Rect2i(40,710,320,210).has_point(p) or Rect2i(40,220,320,430).has_point(p) or Rect2i(1540,110,200,190).has_point(p):
					continue
				if Rect2i(864,416,220,100).has_point(p) or Rect2i(664,616,420,100).has_point(p):
					continue
				if picture.get_pixel(x,y)!=previous.get_pixel(x,y):
					changed+=1
		_check(changed==0,"all pixels outside HP, route and preview unchanged: "+str(changed))
	var path="res://artifacts/runtime/PHASE-contrast-"+stamp+"-"+suffix+".png"
	_check(not FileAccess.file_exists(path) and picture.save_png(path)==OK,"unique capture "+suffix)
	print("CAPTURE ",ProjectSettings.globalize_path(path))
func _peak(picture: Image,point: Vector2i) -> Color:
	var peak=Color.BLACK
	for y in range(point.y-2,point.y+3):
		for x in range(point.x-2,point.x+3):
			var color=picture.get_pixel(x,y)
			if color.r+color.g+color.b>peak.r+peak.g+peak.b:
				peak=color
	return peak
func _click(point: Vector2,double_click: bool=false) -> void:
	for pressed in [true,false]:
		var event=InputEventMouseButton.new()
		event.position=point
		event.global_position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		event.double_click=double_click
		root.push_input(event,false)
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
