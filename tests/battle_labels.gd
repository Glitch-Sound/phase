extends SceneTree
var checks=0
var failures=0
const LABELS=["PHASE PREVIEW","PATH ","ROUTE / PHASE / EFFECT","TURN ORDER","T / ","INSPECT","INNER / MIDDLE / OUTER"]
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
		var hits=game.drawn_text.filter(func(item):return LABEL_AREAS[i].has_point(Vector2i(item.position)) or (item.text.begins_with(label) if label in ["PATH ","T / "] else item.text==label)).map(func(item):return item.text)
		_check(hits.is_empty(),"only requested labels absent: "+title+" / "+label+" / "+str(hits))
	var required=["PHASE / TACTICAL STUDY","BOTH SIDES / HUMAN","PHASE","PLAYER","ENEMY","TURN 001","HP","VIT","INF","RES","SPD","LUK","CORE","GEAR","ARMS","MUTATION / NORMAL","DAMAGE / ADJACENT","HEAL / ADJACENT"]
	_check(required.all(func(text):return texts.has(text)),"keep headers, turn count and complete details: "+title)
	_check(texts.filter(func(text):return text.begins_with("I ")).size()==6 and texts.filter(func(text):return text.begins_with("R ")).size()==6,"keep six timeline entries and their factors: "+title)
	var prediction=game.preview_text.map(func(item):return item.text)
	_check(prediction.filter(func(text):return text.begins_with("INF ")).size()==1 and prediction.filter(func(text):return text.begins_with("RES ")).size()==1 and game.preview_rings.size()==1 and game.preview_contours.size()==4,"keep predicted rings, factors and four contours: "+title)
	_check(game.battle.units==units and game.battle.path==path,"label display preserves battle and pending route: "+title)
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
