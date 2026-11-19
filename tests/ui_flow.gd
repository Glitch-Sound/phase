extends SceneTree
const C=preload("res://game/catalog.gd")
var count=0
var failures=0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game=load("res://tests/fixture_main.gd").new()
	root.add_child(game)
	await process_frame
	_check(game.build_open and is_instance_valid(game.overlay),"startup BUILD")
	game._start_battle()
	game._cell_input(Vector2i(4,4))
	game._cell_input(Vector2i(5,4))
	game._cell_input(Vector2i(5,4),true)
	game._movement_tick(game.T.MOVEMENT_MAX_SECONDS)
	_check(game.planning.phase=="CHOICE" and game.battle.mode=="MOVE" and is_instance_valid(game.overlay),"endpoint opens action dialog")
	game._choose_battle_skill(C.DAMAGE)
	game._clear_overlay()
	game._cell_input(Vector2i(6,4))
	game._confirm_plan();game._movement_tick(game.T.MOVEMENT_MAX_SECONDS);game._action_tick(game.T.ACTION_FLIGHT_MAX_SECONDS);game._action_tick(game.T.ACTION_HEAL_REACTION_SECONDS)
	_check(game.battle.units[2].hp<100 and game.battle.actor==1,"UI target connects to battle and ends turn")
	_check(game.toasts.back().text=="-"+str(game.battle.last_effect.amount),"damage toast connects to computed effect")
	game._cell_input(Vector2i(6,4))
	_check(game.selected==2 and game.battle.actor==1,"inspection selects a unit without changing actor")
	_check(game.battle.preview().id=="02","preview stays on acting unit while inspecting enemy")
	await process_frame
	game.battle.start(0,game.collection.builds)
	game.battle.units[0].pos=Vector2i(5,5)
	game.battle.units[1].pos=Vector2i(6,5)
	game.battle.units[1].hp=95.0
	game.battle.mode="CHOICE"
	game.battle.choose_skill(C.HEAL)
	game._cell_input(Vector2i(6,5));game._action_tick(game.T.ACTION_FLIGHT_MAX_SECONDS);game._action_tick(game.T.ACTION_HEAL_REACTION_SECONDS)
	_check(game.toasts.back().text=="+5","heal toast reports actual capped recovery")
	game.battle.start(0,game.collection.builds)
	game.battle.units[0].pos=Vector2i(5,4)
	game.battle.units[2].hp=1.0
	game.battle.mode="CHOICE"
	game.battle.choose_skill(C.DAMAGE)
	game._cell_input(Vector2i(6,4));game._action_tick(game.T.ACTION_FLIGHT_MAX_SECONDS);game._action_tick(game.T.ACTION_HEAL_REACTION_SECONDS)
	_check(game.toasts.any(func(t):return t.text=="DEFEATED"),"defeat toast connected")
	await process_frame
	game.collection.stage_index=2
	game._start_battle()
	game.loot_rng.seed=187
	# この検査はREACHからRESULTへの接続であり、実ステージの攻略ではない。
	game.battle.stage.victory=[{"type":"REACH","camp":"PLAYER","unit":"01","cell":Vector2i(5,4)}]
	game._cell_input(Vector2i(4,4))
	game._cell_input(Vector2i(5,4))
	game._cell_input(Vector2i(5,4),true)
	game._confirm_plan();game._movement_tick(game.T.MOVEMENT_MAX_SECONDS);game._action_tick(game.T.ACTION_FLIGHT_MAX_SECONDS);game._action_tick(game.T.ACTION_HEAL_REACTION_SECONDS)
	_check(game.battle.result=="VICTORY" and is_instance_valid(game.overlay),"REACH connects to RESULT")
	_check(game.drops.size()<=2,"RESULT loot connection")
	game._build()
	await process_frame
	_check(game.build_open and game.battle.mode=="MOVE" and is_instance_valid(game.overlay),"return to BUILD")
	game._notify("UI TEST NOTICE")
	_check(game.notice.text=="UI TEST NOTICE" and game.notice.z_index>game.overlay.z_index,"notification above overlay")
	game.queue_free()
	await process_frame
	print("UI CONNECTIONS: %d checks / %d failures" % [count,failures])
	quit(0 if failures==0 else 1)

func _check(value: bool, message: String) -> void:
	count+=1
	if not value:
		failures+=1
		printerr("FAIL: ",message)
