extends SceneTree
var checks=0
var failures=0
var game
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	game=load("res://ui/main.gd").new()
	game.settings_path="res://artifacts/runtime/cpu-ui-no-settings.json"
	root.add_child(game)
	await process_frame
	_check(game.get("cpu_enabled") is bool,"CPU mode exists without touching saved configuration")
	if failures:
		_finish()
		return
	await _connection()
	await _controls()
	_finish()
## REQ-035-S01、REQ-036-S03
func _connection() -> void:
	var saved=game.collection.snapshot()
	var choices=game.overlay.find_children("*","CheckButton",true,false).filter(func(c):return c.text=="ENEMY CPU")
	_check(choices.size()==1 and not game.cpu_enabled,"BUILD defaults to the original manual mode and exposes CPU choice")
	choices[0].button_pressed=true
	_check(game.cpu_enabled and game.collection.snapshot()==saved,"CPU toggle keeps the exact save snapshot")
	var labels=game.overlay.find_children("*","Label",true,false).map(func(label):return label.text)
	_check(not labels.has("Compare routes. Both sides are under your control."),"CPU stage hint does not falsely claim human control of the enemy")
	game.panel_seed_override=128
	game._start_battle()
	game.battle.actor=2
	game._cpu_tick(0.0)
	game._cpu_tick(game.T.CPU_TIMES.THINK)
	var before=[game.battle.units.duplicate(true),game.battle.path.duplicate(),game.battle.mode]
	_check(not before[1].is_empty(),"input protection is checked against a real pending CPU route")
	game._cell_input(game.battle.units[2].pos)
	_check(before==[game.battle.units,game.battle.path,game.battle.mode],"human origin click preserves the entire pending CPU route")
	var escape=InputEventKey.new()
	escape.keycode=KEY_ESCAPE
	escape.pressed=true
	game._unhandled_input(escape)
	_check(before==[game.battle.units,game.battle.path,game.battle.mode],"Esc preserves the entire pending CPU route")
	game._cell_input(game.battle.units[0].pos)
	_check(game.selected==0,"inspection still works during CPU turn")
	game._help()
	await process_frame
	var phase=game.cpu_turn.phase
	game._cpu_tick(100.0)
	_check(game.cpu_turn.phase==phase and before==[game.battle.units,game.battle.path,game.battle.mode],"HELP pauses CPU progression")
	game._close_aux()
	await process_frame
	game._window_focus_exited()
	game._cpu_tick(100.0)
	_check(game.cpu_turn.phase==phase,"focus loss pauses CPU progression")
	game._window_focus_entered()
	game._restart()
	game._cpu_tick(100.0)
	_check(game.build_open and not game.cpu_turn.active and game.collection.snapshot()==saved,"restart returns BUILD and discards CPU work without save changes")
	game.cpu_enabled=false
	game._start_battle()
	game.battle.actor=2
	game._cpu_tick(100.0)
	game._cell_input(Vector2i(5,4))
	_check(not game.cpu_turn.active and game.battle.path==[Vector2i(5,4)],"manual enemy turn stays human controlled")
## REQ-036-S02、REQ-036-S03、REQ-036-S04
func _controls() -> void:
	game.set_process(false)
	game.cpu_enabled=true
	game._start_battle()
	game.battle.actor=2
	game._cpu_tick(0)
	for dimensions in [Vector2i(1152,648),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(1200,1600)]:
		root.size=dimensions
		await process_frame
		game._hud()
		await process_frame
		var buttons=game.hud.find_children("*","Button",true,false)
		var speed=buttons.filter(func(b):return b.text.begins_with("SPEED "))[0]
		var pause=buttons.filter(func(b):return b.text=="PAUSE")[0]
		var frame=root.get_final_transform()
		var speed_rect=Rect2(frame*speed.get_global_rect().position,speed.size*frame.get_scale())
		var pause_rect=Rect2(frame*pause.get_global_rect().position,pause.size*frame.get_scale())
		_check(Rect2(Vector2.ZERO,dimensions).encloses(speed_rect) and Rect2(Vector2.ZERO,dimensions).encloses(pause_rect) and not speed_rect.intersects(pause_rect),"CPU buttons fit and remain separate "+str(dimensions))
		var before=[game.battle.units.duplicate(true),game.battle.path.duplicate(),game.cpu_turn.phase,game.cpu_turn.elapsed]
		var was_fast=game.cpu_fast
		speed.pressed.emit()
		_check(game.cpu_fast!=was_fast,"actual speed button toggles at "+str(dimensions))
		pause.pressed.emit()
		game._cpu_tick(100)
		_check(game.cpu_paused and before==[game.battle.units,game.battle.path,game.cpu_turn.phase,game.cpu_turn.elapsed],"actual pause button stops exact state "+str(dimensions))
		game.cpu_paused=false
		game._settings()
		game._cpu_tick(100)
		_check(before==[game.battle.units,game.battle.path,game.cpu_turn.phase,game.cpu_turn.elapsed],"SETTINGS blocks CPU without saving "+str(dimensions))
		game._close_aux()
		await process_frame
	# 同時刻のA、Bをそれぞれ一度だけ実行し、PLAYERへ返す。
	game._start_battle()
	game.battle.units[0].next_time=1000
	game.battle.units[1].next_time=1000
	game.battle.actor=2
	var actors=[]
	for tick in range(200):
		var turn=game.battle.turn
		var actor=game.battle.actor
		game._cpu_tick(0.2)
		if game.battle.turn!=turn:
			actors.append(actor)
		if game.battle.actor==0 and not game.cpu_turn.active:
			break
		if actors.size()>=2 and not game.cpu_turn.active:
			break
	_check(actors==[2,3],"consecutive same-time enemy turns each execute once in order")
	game._restart()
	_check(game.build_open and not game.cpu_turn.active,"final CPU interface check returns BUILD")
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
func _finish() -> void:
	if is_instance_valid(game):
		game.queue_free()
	print("CPU INTERFACE: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
