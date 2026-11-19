extends SceneTree
var game
var checks=0
var failures=0
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	root.size=Vector2i(1920,1080)
	game=load("res://tests/fixture_main.gd").new()
	game.save_path="res://artifacts/runtime/action-feedback/no-save.json"
	game.settings_path="res://artifacts/runtime/action-feedback/no-settings.json"
	root.add_child(game);await process_frame;game.set_process(false)
	_check(game.get("action_effect")!=null,"UI owns common action presentation")
	if failures==0:_arrival();_cancel();_cpu()
	game._restart();game.queue_free();await process_frame
	print("ACTION EFFECT UI: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
func _prepare(kind: String) -> void:
	game.cpu_enabled=false;game._start_battle();game.battle.actor=0
	game.battle.units[0].pos=Vector2i(4,4);game.battle.units[2].pos=Vector2i(5,4)
	game.battle.units[0].skills=[kind];game.battle.mode="CHOICE"
	if kind==game.C.HEAL:game.battle.units[2].camp="PLAYER";game.battle.units[2].hp-=1
	game.battle.choose_skill(kind)
## REQ-021-S01、REQ-021-S02
func _arrival() -> void:
	for kind in [game.C.DAMAGE,game.C.HEAL]:
		_prepare(kind);var before=game.battle.units[2].hp
		game._cell_input(Vector2i(5,4));game._cell_input(Vector2i(5,4))
		_check(game.action_effect.active and game.battle.units[2].hp==before and game.battle.history.is_empty(),"target confirmation begins flight without applying HP")
		game._window_focus_exited();game._action_tick(100)
		_check(game.action_effect.elapsed==0,"focus loss pauses action")
		game._window_focus_entered();game._help();game._action_tick(100)
		_check(game.action_effect.elapsed==0,"HELP pauses action")
		game._close_aux();game._action_tick(game.action_effect.duration)
		_check(game.battle.history.size()==1 and game.battle.last_effect.kind==("DAMAGE" if kind==game.C.DAMAGE else "HEAL") and game.toasts.map(func(t):return t.text)==[("-"+str(game.battle.last_effect.amount)) if kind==game.C.DAMAGE else "+1"],"arrival applies existing action and numeric feedback once")
		game._action_tick(100);game._action_tick(100)
		_check(not game.action_effect.active and game.battle.history.size()==1,"reaction cannot replay effect")
	_prepare(game.C.DAMAGE);game.battle.units[2].hp=1;game.battle.units[3].hp=0
	game._cell_input(Vector2i(5,4));game._action_tick(game.action_effect.duration)
	_check(game.battle.mode=="RESULT" and game.action_effect.active and not is_instance_valid(game.overlay) and not game.result_awarded,"terminal waits for local reaction")
	game._action_tick(100)
	_check(is_instance_valid(game.overlay) and game.result_awarded,"terminal result opens after reaction")
## REQ-021-S02
func _cancel() -> void:
	_prepare(game.C.DAMAGE)
	game._cell_input(Vector2i(5,4));game._restart();game._action_tick(100)
	_check(game.build_open and not game.action_effect.active and game.battle.history.is_empty() and game.toasts.is_empty(),"restart discards an in-flight arrival")
	_prepare(game.C.DAMAGE);game.reduced_motion=true
	game._cell_input(Vector2i(5,4))
	_check(not game.action_effect.active and game.battle.history.size()==1,"reduced motion completes effect without delay")
	game.reduced_motion=false
## REQ-021-S02
func _cpu() -> void:
	_prepare(game.C.DAMAGE);game.battle.units[0].camp="ENEMY";game.battle.units[2].camp="PLAYER";game.cpu_enabled=true
	game._begin_action({"actor":0,"skill":game.C.DAMAGE,"target":2},true)
	game.cpu_paused=true;game._action_tick(100)
	_check(game.action_effect.elapsed==0 and game.battle.history.is_empty(),"CPU pause freezes action without affecting rule time")
	game.cpu_paused=false;game.cpu_fast=true;game._action_tick(game.action_effect.duration/game.T.CPU_FAST_SPEED)
	_check(game.battle.history.size()==1,"CPU shares arrival dispatch under fast mode")
	game._action_tick(100);game.cpu_fast=false;game.cpu_enabled=false
func _check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",note)
