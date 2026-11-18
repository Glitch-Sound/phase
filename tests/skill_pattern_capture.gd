## 描画と入力の検証専用。対象パターンの全体集合はskill_patterns.gdで確認する。
extends SceneTree
const C=preload("res://game/catalog.gd")
const B=preload("res://game/battle.gd")
const CASES=preload("res://tests/skill_patterns.gd").CASES
var game
var checks=0
var failures=0
var prefix="res://artifacts/runtime/target-skills-gpu-"+str(Time.get_unix_time_from_system())
func _initialize() -> void:
	_run.call_deferred()
## REQ-018-S06、NREQ-001-S01、REQ-018-S01
func _run() -> void:
	game=load("res://tests/skill_pattern_audit.gd").new()
	game.settings_path="res://artifacts/runtime/skill-gpu-no-settings.json"
	game.save_path="res://artifacts/runtime/skill-gpu-no-save.json"
	root.add_child(game)
	await process_frame
	await _focus_input()
	game.collection.skills=C.SKILLS.keys()
	game.collection.builds[0].skills=[C.DAMAGE_DIAGONAL,C.HEAL_ORTHOGONAL_TWO,C.HEAL_DIAGONAL_TWO]
	game._build()
	await _shot("build")
	for row in CASES:
		await _fixture(row)
		await _shot(row[0])
		var records=game.info_records.filter(func(record):return record.text==C.SKILLS[row[0]].description)
		_check(records.size()==1 and records[0].position.x+records[0].typeface.get_string_size(records[0].text,HORIZONTAL_ALIGNMENT_LEFT,-1,records[0].font_size).x<=1840,"full skill description fits right column "+row[0])
		await _focus_input()
		_click(game._cell_rect(game.battle.units[2].pos).get_center())
		await create_timer(0.05).timeout
		_check(game.battle.mode!="TARGET" and game.battle.history.size()>0,"rendered target accepts actual viewport click "+row[0])
	for dimensions in [Vector2i(1152,648),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(1200,1600)]:
		root.size=dimensions
		await _focus_input()
		await _fixture(CASES[-1])
		await _shot("scaled-"+str(dimensions.x))
		var hp=game.battle.units[2].hp
		await _focus_input()
		_click(game._cell_rect(game.battle.units[2].pos).get_center())
		await process_frame
		_check(game.battle.units[2].hp>hp and game.battle.units[2].hp<=game.battle.units[2].max_hp,"scaled target click heals exactly one unit "+str(dimensions))
		game._help()
		await _shot("help-"+str(dimensions.x))
		var labels=game.auxiliary.find_children("*","Label",true,false).filter(func(label):return label.text.contains("DIAGONAL"))
		_check(labels.size()==1 and labels[0].get_minimum_size().y<=labels[0].size.y and labels[0].get_minimum_size().x<=labels[0].size.x,"HELP new range explanation fits "+str(dimensions))
		game._close_aux()
	game._restart()
	_check(game.build_open,"capture workflow returns to BUILD")
	game.queue_free()
	await process_frame
	print("SKILL PATTERN GPU: %d checks / %d failures; %s" % [checks,failures,prefix])
	quit(0 if failures==0 else 1)
func _fixture(row: Array) -> void:
	game._clear_overlay()
	await process_frame
	game.toasts=[]
	game.battle=B.new()
	game.battle.start(0,C.player_builds(),1)
	game.build_open=false
	game.selected=0
	game.battle.actor=0
	game.battle.panels={}
	game.battle.units[0].pos=Vector2i(4,4)
	game.battle.units[0].skills=[row[0]]
	game.battle.units[0].moved=1
	game.battle.units[2].pos=Vector2i(4,4)+row[2][0]
	if row[1]=="HEAL":
		game.battle.units[2].camp="PLAYER"
		game.battle.units[2].hp=game.battle.units[2].max_hp-1
	game.battle.mode="CHOICE"
	game.battle.choose_skill(row[0])
	game._hud()
	game.queue_redraw()
	await create_timer(0.1).timeout
func _focus_input() -> void:
	root.grab_focus()
	await create_timer(0.05).timeout
	_check(root.has_focus() and game.window_focused,"OS focus before viewport input")
func _click(logical: Vector2) -> void:
	var event=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.position=root.get_final_transform()*logical
	event.pressed=true
	Input.parse_input_event(event)
	event=event.duplicate()
	event.pressed=false
	Input.parse_input_event(event)
func _shot(suffix: String) -> void:
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(prefix+"-"+suffix+".png")
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
