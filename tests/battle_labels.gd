extends SceneTree
var checks=0
var failures=0
const LABELS=["PHASE PREVIEW","PATH ","ROUTE / PHASE / EFFECT","TURN ORDER","T / ","INSPECT","INNER / MIDDLE / OUTER","PHASE / TACTICAL STUDY","BOTH SIDES / HUMAN","TURN "]
const LABEL_AREAS=preload("res://tests/battle_labels_capture.gd").LABEL_AREAS
func _initialize() -> void:
	_run.call_deferred()
## REQ-019-S03
func _run() -> void:
	var game=load("res://tests/phase_preview_audit.gd").new()
	game.settings_path="res://artifacts/runtime/labels-no-settings-"+str(Time.get_ticks_usec())+".json"
	root.add_child(game)
	await process_frame
	for stage in range(4):
		game.collection.stage_index=stage
		game._start_battle()
		await _check_scene(game,"stage "+str(stage))
	game.collection.stage_index=0
	for state in ["CHOICE","DAMAGE","HEAL","RESULT"]:
		game._start_battle()
		await process_frame
		if state=="RESULT":
			game.battle.mode="RESULT"
			game.battle.result="VICTORY"
			game.result_awarded=true
			game.drops=[]
			game._result()
		elif state=="HEAL":
			game.battle.units[0].pos=Vector2i(5,5)
			game.battle.units[1].pos=Vector2i(6,5)
			game.battle.units[1].hp=50
			game.battle.mode="CHOICE"
			game.battle.choose_skill(game.C.HEAL)
			game._hud()
		else:
			game._cell_input(Vector2i(4,4))
			game._cell_input(Vector2i(5,4))
			game._cell_input(Vector2i(5,4),true)
			await process_frame
			if state=="DAMAGE":
				game.battle.choose_skill(game.C.DAMAGE)
				game._clear_overlay()
				game._hud()
		await _check_scene(game,state)
	await _test_header_input(game)
	game.queue_free()
	await process_frame
	print("BATTLE LABELS: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
func _check_scene(game, title: String) -> void:
	var units=game.battle.units.duplicate(true)
	var path=game.battle.path.duplicate()
	game.queue_redraw()
	await create_timer(0.08).timeout
	var texts=game.drawn_text.map(func(item):return item.text)
	for i in range(LABELS.size()):
		var label=LABELS[i]
		# 接頭辞だけを消して時刻や座標を残す誤実装も、元の表示領域で検出する。
		var hits=game.drawn_text.filter(func(item):return (i in [1,4,9] and LABEL_AREAS[i].has_point(Vector2i(item.position)) and (RegEx.create_from_string("^[0-9]+([.][0-9]+)?$").search(item.text)!=null or item.text.contains("DESTINATION"))) or (item.text.begins_with(label) if label in ["PATH ","T / ","TURN "] else item.text==label)).map(func(item):return item.text)
		_check(hits.is_empty(),"only requested labels absent: "+title+" / "+label+" / "+str(hits))
	var displayed=game.battle.units[game.selected if game.selected>=0 else game.battle.actor]
	var expected_count=47+2*displayed.skills.size()+game.battle.panels.values().filter(func(p):return p!="NORMAL").size()
	for goal in [game.battle.stage.goal,game.battle.stage.enemy_goal]:
		if Rect2i(0,0,10,10).has_point(goal):
			expected_count+=1
	expected_count+=1 if game.message_time>0 else 0
	_check(game.drawn_text.size()==expected_count,"complete text set excludes any extra caption fragment: "+title+" / "+str(game.drawn_text.size())+" / "+str(expected_count))
	var required=["PHASE","PLAYER","ENEMY","HP","VIT","INF","RES","SPD","LUK","CORE","GEAR","ARMS","MUTATION / NORMAL","DAMAGE / ADJACENT","HEAL / ADJACENT"]
	_check(required.all(func(text):return texts.has(text)),"keep headers and complete details: "+title)
	_check(texts.filter(func(text):return text.begins_with("I ")).size()==4 and texts.filter(func(text):return text.begins_with("R ")).size()==4,"keep four current states and their factors: "+title)
	var prediction=game.preview_text.map(func(item):return item.text)
	_check(prediction.filter(func(text):return text.begins_with("INF ")).size()==1 and prediction.filter(func(text):return text.begins_with("RES ")).size()==1 and game.preview_rings.size()==1 and game.preview_contours.size()==4,"keep predicted rings, factors and four contours: "+title)
	_check(game.battle.units==units and game.battle.path==path,"label display preserves battle and pending route: "+title)
## REQ-019-S03
func _test_header_input(game) -> void:
	game._start_battle()
	await process_frame
	game._cell_input(Vector2i(4,4))
	game.selected=2
	var units=game.battle.units.duplicate(true)
	var path=game.battle.path.duplicate()
	for area in LABEL_AREAS.slice(7,9):
		var event=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=true
		event.position=Vector2(area.get_center())
		game._unhandled_input(event)
		_check(game.battle.units==units and game.battle.path==path and game.selected==2 and not is_instance_valid(game.overlay),"top explanation area has no action: "+str(area))
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
