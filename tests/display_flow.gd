extends SceneTree
const T=preload("res://game/tuning.gd")
var checks=0
var failures=0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await _test_scaling(game)
	await _test_resize_route(game)
	_test_event_position(game)
	await _test_focus(game)
	game.queue_free()
	await process_frame
	print("DISPLAY FLOW: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)

## NREQ-001-S02
func _test_scaling(game: Control) -> void:
	for size_px in [Vector2i(1920,1080),Vector2i(1440,810),Vector2i(1280,720),Vector2i(3840,2160),Vector2i(1600,1200),Vector2i(2560,1080),Vector2i(1200,1600),Vector2i(1280,720)]:
		root.size=size_px
		await process_frame
		var factor=minf(size_px.x/1920.0,size_px.y/1080.0)
		# 奇数ピクセルの余りは最も近い物理ピクセルへ丸める。
		var offset=((Vector2(size_px)-Vector2(1920,1080)*factor)/2).round()
		var transform=root.get_final_transform()
		_check(transform.x.is_equal_approx(Vector2(factor,0)) and transform.y.is_equal_approx(Vector2(0,factor)),"uniform scale for %s" % size_px)
		_check(transform.origin.is_equal_approx(offset),"centered letterbox for %s: actual %s / expected %s" % [size_px,transform.origin,offset])
		_check(game.size.is_equal_approx(Vector2(1920,1080)),"logical layout stays 1920x1080 for %s" % size_px)
		await _test_gui_mouse(game,factor,offset)

## REQ-027-S01
func _test_gui_mouse(game: Control, factor: float, offset: Vector2) -> void:
	game._build()
	await process_frame
	# BUILDのBATTLE STARTを、実ウィンドウ座標からGUI入力へ通す。
	_push_click(offset+Vector2(1404,870)*factor)
	await process_frame
	_check(not game.build_open,"scaled GUI button receives click")
	_push_click(offset+_point(Vector2i(4,4))*factor)
	await process_frame
	_check(game.battle.path==[Vector2i(4,4)],"scaled click selects visible board cell")
	_push_click(offset+_point(Vector2i(4,4))*factor,true)
	await process_frame
	_check(game.battle.mode=="CHOICE" and is_instance_valid(game.overlay),"scaled double click opens action overlay")
	game._start_battle()
	await process_frame
	if offset!=Vector2.ZERO:
		_push_click(Vector2(2,2))
		await process_frame
		_check(game.battle.path.is_empty() and game.selected==-1,"letterbox clicks leave selection unchanged")

## REQ-027-S01
func _test_resize_route(game: Control) -> void:
	game._start_battle()
	await process_frame
	_push_click(root.get_final_transform()*_point(Vector2i(4,4)))
	_check(game.battle.path==[Vector2i(4,4)],"route starts before resize")
	root.size=Vector2i(2560,1080)
	await process_frame
	_check(game.battle.path==[Vector2i(4,4)] and game.battle.mode=="MOVE","resize preserves pending route")
	_push_click(root.get_final_transform()*_point(Vector2i(5,4)))
	_check(game.battle.path==[Vector2i(4,4),Vector2i(5,4)],"route can extend after resize")
	root.size=Vector2i(1280,720)
	await process_frame
	_check(game.battle.path==[Vector2i(4,4),Vector2i(5,4)],"resize return preserves the route")
	_push_click(root.get_final_transform()*_point(Vector2i(5,4)),true)
	await process_frame
	_check(game.battle.mode=="CHOICE" and game.battle.units[0].pos==Vector2i(5,4),"route can commit after resize return")

## REQ-027-S01
func _test_event_position(game: Control) -> void:
	game._start_battle()
	var event=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	event.position=_point(Vector2i(4,4))
	game._unhandled_input(event)
	_check(game.battle.path==[Vector2i(4,4)],"event coordinates select the cell independently of cursor polling")

## REQ-027-S02
func _test_focus(game: Control) -> void:
	game._start_battle()
	game._cell_input(Vector2i(4,4))
	game.hover_cell=Vector2i(4,4)
	root.focus_exited.emit()
	_check(game.hover_cell==Vector2i(-1,-1),"focus loss clears hover")
	var event=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	event.position=_point(Vector2i(5,4))
	game._unhandled_input(event)
	_check(game.battle.path==[Vector2i(4,4)],"unfocused input does not change the route")
	root.focus_entered.emit()
	game._unhandled_input(event)
	_check(game.battle.path==[Vector2i(4,4),Vector2i(5,4)],"focus return resumes the preserved route")
	_push_click(root.get_final_transform()*Vector2(1277,1045))
	await process_frame
	_check(is_instance_valid(game.auxiliary),"GUI remains usable after focus return")
	game._close_aux()

func _push_click(position_px: Vector2, double_click: bool=false) -> void:
	for pressed in [true,false]:
		var event=InputEventMouseButton.new()
		event.position=position_px
		event.global_position=position_px
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		event.double_click=double_click and pressed
		root.push_input(event,false)

func _check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)

func _point(cell: Vector2i) -> Vector2:
	return T.BATTLE_BOARD_ORIGIN+(Vector2(cell)+Vector2.ONE/2)*T.BATTLE_CELL
