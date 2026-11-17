extends "res://tests/contested_play.gd"
var game
var checks=0
var stamp=str(Time.get_unix_time_from_system()).replace(".","-")
func _initialize() -> void:
	_run.call_deferred()
## REQ-019-S01、REQ-019-S04、REQ-019-S09、NREQ-001-S04
func _run() -> void:
	var policy=_mutual(1.1,160,true,128)
	game=load("res://tests/side_info_audit.gd").new()
	game.battle=RUNTIME_B.new()
	game.settings_path="res://artifacts/runtime/unit-info-capture-"+stamp+".json"
	root.add_child(game)
	await process_frame
	root.size=Vector2i(1920,1080)
	root.grab_focus()
	await process_frame
	await create_timer(0.2).timeout
	game.panel_seed_override=128
	game._start_battle()
	# BUILDのqueue_freeされた操作面を破棄してから実入力する。
	await process_frame
	for attempt in range(60):
		if root.has_focus() and game.window_focused:
			break
		root.grab_focus()
		await create_timer(0.02).timeout
	# 以前の同一場面は、右の文字以外が変わらないことを比べる検査用とする。
	_click_cell(Vector2i(4,4))
	await process_frame
	_check(game.battle.path==[Vector2i(4,4)],"comparison first real click accepted")
	_click_cell(Vector2i(5,4))
	await process_frame
	_click_cell(Vector2i(5,4),true)
	await process_frame
	_click_button(game.overlay,"DAMAGE / ADJACENT")
	await process_frame
	_click_cell(Vector2i(6,4))
	await process_frame
	_click_cell(Vector2i(4,6))
	_click_cell(Vector2i(5,6))
	await _capture("comparison")
	game._start_battle()
	var commands=[]
	for command in policy.commands.slice(0,10):
		_check(game.battle.units[game.battle.actor].id==command.unit,"real replay actor "+command.unit)
		for pair in command.path:
			_click_cell(Vector2i(pair[0],pair[1]))
		if not command.path.is_empty():
			var last=command.path[-1]
			_click_cell(Vector2i(last[0],last[1]),true)
			await process_frame
		if command.skill=="":
			_click_button(game.hud if command.path.is_empty() else game.overlay,"WAIT")
		else:
			_click_button(game.overlay,game.C.SKILLS[command.skill].label)
			await process_frame
			_click_cell(game.battle.units[command.target].pos)
		await process_frame
		commands.append(command)
		_check(game.battle.result.is_empty(),"capture advances through a continuing battle")
	_check(game.battle.turn>5 and game.battle.units.any(func(unit):return unit.hp<unit.max_hp),"main capture has actual progress and changed HP")
	_check(game.battle.history==policy.history.slice(0,game.battle.history.size()),"GUI progression exactly matches reproducible model history")
	var inspected=1 if game.battle.units[1].hp>0 else game.battle.actor
	var card=game._timeline_view().cards.filter(func(item):return item.index==inspected)[0]
	_click(root.get_final_transform()*card.center)
	await process_frame
	_check(game.selected==inspected,"timeline selects actual current information")
	print("PROGRESSED CAPTURE turn ",game.battle.turn," / hp ",game.battle.units.map(func(unit):return unit.hp)," / inspected ",inspected," / history ",game.battle.history)
	for dimensions in [Vector2i(1152,648),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(1200,1600)]:
		root.size=dimensions
		await process_frame
		var before=game.battle.units.duplicate(true)
		var actor=game.battle.actor
		var source: Vector2i=game.battle.units[actor].pos
		var destination=source+Vector2i.LEFT
		_click_cell(destination)
		await process_frame
		_check(game.battle.path==[destination],"resized real board input "+str(dimensions))
		var inspected_card=game._timeline_view().cards.filter(func(item):return item.index==inspected)[0]
		_click(root.get_final_transform()*inspected_card.center)
		await process_frame
		_check(game.selected==inspected and game.battle.path==[destination] and game.battle.units==before,"resized inspection preserves pending route "+str(dimensions))
		_click_cell(source)
		await process_frame
		_check(game.battle.path.is_empty() and game.battle.actor==actor,"resized route cancellation "+str(dimensions))
		await _capture("progress-"+str(dimensions.x)+"-"+str(dimensions.y))
	var original=game.battle.units.duplicate(true)
	var unit=game.battle.units[inspected]
	unit.class_name="REVERSE"
	unit.skills=[game.C.DAMAGE,game.C.HEAL,game.C.MOVE]
	unit.gear=[96,1,1,1,1]
	unit.arms=[96,1,1,1,1]
	unit.gear_mutation="LSRIV"
	unit.arms_mutation="IVRSL"
	for dimensions in [Vector2i(1152,648),Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size=dimensions
		await process_frame
		await _capture("fixture-long-"+str(dimensions.x))
	game.battle.units=original
	root.size=Vector2i(1920,1080)
	await process_frame
	game._restart()
	await process_frame
	_check(game.build_open,"returns BUILD without saving")
	print("UNIT INFORMATION GPU: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
func _capture(suffix: String) -> void:
	game.message_time=0
	game.toasts=[]
	_move(Vector2(1900,1000))
	game.queue_redraw()
	await create_timer(0.12).timeout
	await RenderingServer.frame_post_draw
	var picture=root.get_texture().get_image()
	var bounds=[]
	for record in game.info_records:
		var face: Font=record.typeface
		var rect=Rect2(record.position-Vector2(0,face.get_ascent(record.font_size)),Vector2(face.get_string_size(record.text,HORIZONTAL_ALIGNMENT_LEFT,-1,record.font_size).x,face.get_height(record.font_size)))
		_check(rect.position.x>game.BOARD.x+game.CELL*10 and rect.end.x<=game.T.BATTLE_CONTEXT_BUTTON.end.x and rect.end.y<game.T.BATTLE_CONTEXT_BUTTON.position.y,"GPU text clear of board and menu "+record.text+" / "+suffix)
		_check(bounds.all(func(other):return not rect.intersects(other)),"GPU text lines do not overlap "+suffix)
		bounds.append(rect)
	_check(game.info_text[0]=="CLASS: "+game.battle.units[game.selected if game.selected>=0 else game.battle.actor].class_name,"GPU shows actual selected class")
	if suffix=="comparison":
		var previous=Image.load_from_file("res://artifacts/ui-review/diamond-reset-battle.png")
		var masks=[Rect2i(1436,72,408,40),Rect2i(1436,317,408,550)]
		var outside=0
		var changed=0
		for y in range(picture.get_height()):
			for x in range(picture.get_width()):
				if picture.get_pixel(x,y)==previous.get_pixel(x,y):
					continue
				if masks.any(func(rect):return rect.has_point(Vector2i(x,y))):
					changed+=1
				else:
					outside+=1
		_check(changed>0 and outside==0,"only the requested right-side text changes: "+str([changed,outside]))
		print("UNIT INFO PIXELS changed ",changed," / outside ",outside)
	var path="res://artifacts/runtime/PHASE-unit-information-"+stamp+"-"+suffix+".png"
	_check(not FileAccess.file_exists(path) and picture.save_png(path)==OK,"unique real GPU capture")
	print("CAPTURE ",ProjectSettings.globalize_path(path))
func _click_cell(cell: Vector2i,double_click: bool=false) -> void:
	_click(root.get_final_transform()*(game.BOARD+(Vector2(cell)+Vector2.ONE/2)*game.CELL),double_click)
func _click_button(parent: Control,label: String) -> void:
	_check(is_instance_valid(parent),"actual button parent available "+label)
	if not is_instance_valid(parent):
		return
	var buttons=parent.find_children("*","Button",true,false).filter(func(button):return button.text==label)
	_check(buttons.size()==1,"actual operation available "+label)
	if buttons.size()==1:
		_click(root.get_final_transform()*buttons[0].get_global_rect().get_center())
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
