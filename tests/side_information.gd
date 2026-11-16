extends SceneTree
var checks=0
var failures=0
func _initialize() -> void:
	_run.call_deferred()
## REQ-019-S03、REQ-019-S09、NREQ-001-S04
func _run() -> void:
	var game=load("res://tests/side_info_audit.gd").new()
	game.settings_path="res://artifacts/runtime/side-info-lab-"+str(Time.get_ticks_usec())+".json"
	root.add_child(game)
	await process_frame
	game._start_battle()
	await _redraw(game)
	_check(game.info_text==["STANDARD","MOVE %d" % game.T.BASE_MOVE,"DAMAGE / ADJACENT","HEAL / ADJACENT"],"exact default right information: "+str(game.info_text))
	_check(game.info_bars.is_empty(),"no allocation bars remain")
	_check(game.info_rings.size()==1 and game.info_rings[0].center==game.T.BATTLE_INFO_RING and game.info_rings[0].unit==game.battle.units[0],"keep current selected ring at spaced position")
	for state in ["MOVE","CHOICE","TARGET","RESULT"]:
		game.battle.mode=state
		for index in [-1,0,2]:
			game.selected=index
			var view=game._timeline_view()
			game.timeline_hover_event=view.events[-1] if not view.events.is_empty() else {}
			await _redraw(game)
			var remnants=game.drawn_text.filter(func(t):return Rect2(36,646,328,30).has_point(t.position) or Rect2(36,914,290,35).has_point(t.position))
			_check(remnants.is_empty(),"no caption, synchronization values or substitutes in "+state+" / "+str(index)+" / "+str(remnants))
	game._start_battle()
	game.selected=2
	var u=game.battle.units[2]
	u.class_name="REVERSE"
	u.gear_mutation="LSRIV"
	u.arms_mutation="IVRSL"
	u.skills=[game.C.DAMAGE,game.C.HEAL,game.C.MOVE]
	var before=game.battle.units.duplicate(true)
	var path=game.battle.path.duplicate()
	await _redraw(game)
	_check(game.info_text==["REVERSE","MOVE %d" % (game.T.BASE_MOVE+1),"GEAR / LSRIV","ARMS / IVRSL","DAMAGE / ADJACENT","HEAL / ADJACENT","MOVE +1 / SELF"],"mutation and passive skill remain without type repetition: "+str(game.info_text))
	_check(game.info_rings[0].unit==u and game.battle.units==before and game.battle.path==path,"inspection preserves selected state and pending route")
	await _test_menu(game)
	game.queue_free()
	await process_frame
	print("SIDE INFORMATION: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
## NREQ-001-S04
func _test_menu(game) -> void:
	game._start_battle()
	await process_frame
	var labels=["HELP","SETTINGS","RESTART","QUIT"]
	var methods=["_help","_settings","_restart","_quit"]
	var buttons=game.hud.get_children()
	_check(buttons.size()==4,"four system operations")
	var board=Rect2(game.T.BATTLE_BOARD_ORIGIN,Vector2.ONE*10*game.T.BATTLE_CELL)
	var previous=[]
	for i in range(4):
		var button=buttons[i]
		var expected=Rect2(game.T.BATTLE_MENU_ORIGIN+Vector2(i%2,floori(i/2.0))*(game.T.BATTLE_MENU_SIZE+game.T.BATTLE_MENU_GAP),game.T.BATTLE_MENU_SIZE)
		_check(button.text==labels[i] and button.get_rect()==expected,"row-major menu geometry "+labels[i]+" / "+str(button.get_rect()))
		_check(button.pressed.get_connections().size()==1 and button.pressed.get_connections()[0].callable.get_method()==methods[i],"callback retained "+labels[i])
		_check(not button.get_rect().intersects(board) and button.get_rect().position.x-board.end.x>0,"menu separated from board "+labels[i])
		for rect in previous:
			_check(not rect.intersects(button.get_rect()),"menu buttons do not overlap")
		previous.append(button.get_rect())
	_check(buttons[3].get_rect().end.y==board.end.y,"menu and map lower edges align")
	for state in ["TARGET","MOVE"]:
		game.battle.mode=state
		if state=="MOVE":
			game.battle.units[0].pos=Vector2i(0,0)
			game.battle.units[1].pos=Vector2i(1,0)
			game.battle.units[2].pos=Vector2i(0,1)
		game._hud()
		await process_frame
		var context=game.hud.get_children().filter(func(b):return b.text in ["BACK","WAIT"])
		_check(context.size()==1,"context operation retained "+state)
		if context.size()==1:
			_check(previous.all(func(rect):return not rect.intersects(context[0].get_rect())) and not context[0].get_rect().intersects(board),"context button separated from menu and map "+state)
func _redraw(game) -> void:
	game.queue_redraw()
	await create_timer(0.05).timeout
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
