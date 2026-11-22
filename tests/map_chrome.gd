extends SceneTree
const T=preload("res://game/tuning.gd")
const TEXT_BANDS=[Rect2(T.BATTLE_BOARD_ORIGIN.x,0,T.BATTLE_CELL*10,T.BATTLE_BOARD_ORIGIN.y),Rect2(T.BATTLE_BOARD_ORIGIN-Vector2(T.BATTLE_BOARD_ORIGIN.y,0),Vector2(T.BATTLE_BOARD_ORIGIN.y,T.BATTLE_CELL*10)),Rect2(T.BATTLE_BOARD_ORIGIN+Vector2(0,T.BATTLE_CELL*10),Vector2(T.BATTLE_CELL*10,T.BATTLE_BOARD_ORIGIN.y/2))]
var checks=0
var failures=0
func _initialize() -> void:
	_run.call_deferred()
## REQ-029-S01
func _run() -> void:
	var game=load("res://tests/map_chrome_audit.gd").new()
	game.settings_path="res://artifacts/runtime/map-chrome-no-settings.json"
	root.add_child(game)
	await process_frame
	for stage in range(4):
		game.collection.stage_index=stage
		game._start_battle()
		await _test_case(game,"stage "+str(stage))
	game.collection.stage_index=0
	for state in ["CHOICE","DAMAGE","HEAL","TRAPPED","RESULT"]:
		game._start_battle()
		if state=="TRAPPED":
			game.battle.units[0].pos=Vector2i(0,0)
			game.battle.units[1].pos=Vector2i(1,0)
			game.battle.units[2].pos=Vector2i(0,1)
			game._hud()
		elif state=="RESULT":
			game.battle.mode="RESULT"
			game.battle.result="VICTORY"
			game.result_awarded=true
			game.drops=[]
			game._result()
		elif state=="HEAL":
			game.battle.units[0].pos=Vector2i(5,5)
			game.battle.units[1].pos=Vector2i(6,5)
			game.battle.units[1].hp=90
			game.battle.mode="CHOICE"
			game.battle.units[game.battle.actor].moved=1
			game.battle.choose_skill(game.C.HEAL)
			game._clear_overlay()
			game._hud()
		else:
			game._cell_input(Vector2i(4,4))
			game._cell_input(Vector2i(5,4))
			game._cell_input(Vector2i(5,4),true)
			game._movement_tick(game.T.MOVEMENT_MAX_SECONDS)
			if state=="DAMAGE":
				await process_frame
				game._choose_battle_skill(game.C.DAMAGE)
				game._clear_overlay()
				game._hud()
		await _test_case(game,state,"TARGET" if state in ["DAMAGE","HEAL"] else ("MOVE" if state=="TRAPPED" else state))
		if state in ["DAMAGE","HEAL","TRAPPED"]:
			var names=[]
			var action_button: Button
			for button in game.hud.find_children("*","Button",true,false):
				names.append(button.text)
				if button.text==("WAIT" if state=="TRAPPED" else "BACK"):
					action_button=button
			_check(names.has("WAIT" if state=="TRAPPED" else "BACK"),"keep required action button: "+state)
			var units=game.battle.units.duplicate(true)
			var actor=game.battle.actor
			if is_instance_valid(action_button):
				action_button.pressed.emit()
				if state=="TRAPPED":
					await process_frame;await process_frame;game._pending_plan_tick()
			await process_frame
			_check(game.battle.actor!=actor if state=="TRAPPED" else game._decision_battle().mode=="CHOICE" and game.battle.units==units,"required action remains functional: "+state)
	await _test_help_and_build(game)
	print("MAP CHROME: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
func _test_case(game,title: String,expected_mode: String="MOVE") -> void:
	_check(game._decision_battle().mode==expected_mode,"fixture reaches requested state: "+title)
	game.message_time=0
	var before=game.battle.units.duplicate(true)
	await create_timer(0.07).timeout
	var forbidden=[]
	for item in game.drawn_text:
		for band in TEXT_BANDS:
			if band.has_point(item.position):
				forbidden.append(item.text)
	_check(forbidden.is_empty(),"map surroundings have no title/mode/coordinates/objective: "+title)
	var hints=[]
	for label in game.hud.find_children("*","Label",true,false):
		if label.is_visible_in_tree() and Rect2(540,0,750,50).has_point(label.global_position):
			hints.append(label.text)
	_check(hints.is_empty(),"no central operation prompt: "+title)
	_check(game.battle.units==before,"display preserves units: "+title)
## REQ-018-S01
func _test_help_and_build(game) -> void:
	game._start_battle()
	game._cell_input(Vector2i(4,4))
	game._help()
	await process_frame
	var content=[]
	for label in game.auxiliary.find_children("*","Label",true,false):
		content.append(label.text)
	_check(content.has("Double-click the destination, pick skill\nand target to move and act.\nORTHO = cardinal; DIAGONAL = diagonal;\n1 / 2 = exact cell distance."),"HELP retains destination double-click, target selection, exact range and selection-based execution")
	game._close_aux()
	_check(game.battle.path==[Vector2i(4,4)],"HELP keeps pending route")
	for stage in range(4):
		game.collection.stage_index=stage
		game._build()
		await process_frame
		var texts=[]
		for label in game.overlay.find_children("*","Label",true,false):
			texts.append(label.text)
		var views=game.overlay.find_children("*","Control",true,false).filter(func(node):return node.get_script()!=null and node.get_script().resource_path=="res://ui/unit_reference_text.gd")
		var expected=[["ELIMINATE ALL ENEMY UNITS",[]],["DEFEAT  / KEEP  ALIVE",["A","01"]],[" REACH (9,0) / KEEP  ALIVE / STOP  (0,9)",["01","01","B"]],["PLAYER HOLD (8,0) / DENY ENEMY (0,9)",[]]]
		var view=views[0]
		_check("".join(view.parts.filter(func(part):return part.has("text")).map(func(part):return part.text))==expected[stage][0] and view.parts.filter(func(part):return part.has("unit")).map(func(part):return part.unit.id)==expected[stage][1],"BUILD retains exact stage objective and glyph correspondence: "+str(stage))
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
