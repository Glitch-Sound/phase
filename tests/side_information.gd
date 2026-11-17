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
	_check(game.info_text==["CLASS: STANDARD","MOVE %d" % game.T.BASE_MOVE,"Move up to %d cells per turn." % game.T.BASE_MOVE,"GEAR-1414141414","ARMS-1414141414","DAMAGE / ADJACENT","Damage one adjacent enemy.","HEAL / ADJACENT","Heal one adjacent wounded ally."],"exact default right information: "+str(game.info_text))
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
	_check(game.info_text==["CLASS: REVERSE","MOVE %d" % (game.T.BASE_MOVE+1),"Move up to %d cells per turn." % (game.T.BASE_MOVE+1),"GEAR-1414141414-M-LSRIV","ARMS-1414141414-M-IVRSL","DAMAGE / ADJACENT","Damage one adjacent enemy.","HEAL / ADJACENT","Heal one adjacent wounded ally.","MOVE +1 / SELF","Adds 1 cell to movement."],"mutation and passive skill remain with accurate descriptions: "+str(game.info_text))
	_check(game.info_rings[0].unit==u and game.battle.units==before and game.battle.path==path,"inspection preserves selected state and pending route")
	await _test_details(game)
	await _test_menu(game)
	game.queue_free()
	await process_frame
	print("SIDE INFORMATION: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
## REQ-019-S09、NREQ-001-S04
func _test_details(game) -> void:
	var unit=game.battle.units[2]
	var items=[[[20,20,20,20,20],"1414141414"],[[20,30,15,20,15],"141E0F140F"],[[20,10,30,20,20],"140A1E1414"],[[25,15,20,30,10],"190F141E0A"],[[96,1,1,1,1],"6001010101"]]
	unit.skills=[]
	unit.gear_mutation="NORMAL"
	unit.arms_mutation="NORMAL"
	for item in items:
		unit.gear=item[0].duplicate()
		unit.arms=item[0].duplicate()
		await _redraw(game)
		_check(game.info_text==["CLASS: REVERSE","MOVE %d" % game.T.BASE_MOVE,"Move up to %d cells per turn." % game.T.BASE_MOVE,"GEAR-"+item[1],"ARMS-"+item[1]],"all actual equipment identifiers and no invented skill "+item[1])
	unit.skills=[game.C.MOVE]
	await _redraw(game)
	_check(game.info_text.slice(-2)==["MOVE +1 / SELF","Adds 1 cell to movement."] and game.info_text[1]=="MOVE %d" % (game.T.BASE_MOVE+1) and game.info_text[2]=="Move up to %d cells per turn." % (game.T.BASE_MOVE+1),"passive-only description and movement use actual cap")
	unit.skills=[game.C.DAMAGE,game.C.HEAL,game.C.MOVE]
	unit.gear_mutation="LSRIV"
	unit.arms_mutation="IVRSL"
	await _redraw(game)
	var descriptions=game.info_records.filter(func(record):return record.text in ["Move up to %d cells per turn." % (game.T.BASE_MOVE+1),"Damage one adjacent enemy.","Heal one adjacent wounded ally.","Adds 1 cell to movement."])
	_check(descriptions.size()==4 and descriptions.all(func(record):return record.color==game.MUTED and record.color.a==1 and record.color!=game.WHITE),"four secondary explanations are muted and fully opaque")
	var luminances=[]
	for color in [game.MUTED,game.BG]:
		var values=[]
		for channel in [color.r,color.g,color.b]:
			values.append(channel/12.92 if channel<=0.04045 else pow((channel+0.055)/1.055,2.4))
		luminances.append(values[0]*0.2126+values[1]*0.7152+values[2]*0.0722)
	_check((luminances[0]+0.05)/(luminances[1]+0.05)>game.P.MIN_CONTRAST,"muted description remains readable against near-black background")
	var bounds=[]
	for record in game.info_records:
		var rect=_bounds(record)
		_check(rect.position.x>game.BOARD.x+10*game.CELL and rect.end.x<=game.T.BATTLE_CONTEXT_BUTTON.end.x and rect.end.y<game.T.BATTLE_CONTEXT_BUTTON.position.y,"long names and descriptions stay between board and menu "+record.text)
		_check(bounds.all(func(other):return not rect.intersects(other)),"information text does not overlap "+record.text)
		bounds.append(rect)
	for dimensions in [Vector2i(1152,648),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(1200,1600)]:
		root.size=dimensions
		await process_frame
		var visible=Rect2(Vector2.ZERO,Vector2(dimensions))
		_check(game.info_records.all(func(record):return visible.encloses(root.get_final_transform()*_bounds(record))),"worst-case information stays visible "+str(dimensions))
	root.size=Vector2i(1920,1080)
	await process_frame
func _bounds(record: Dictionary) -> Rect2:
	var face: Font=record.typeface
	return Rect2(record.position-Vector2(0,face.get_ascent(record.font_size)),Vector2(face.get_string_size(record.text,HORIZONTAL_ALIGNMENT_LEFT,-1,record.font_size).x,face.get_height(record.font_size)))
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
