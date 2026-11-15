extends SceneTree
var game
var capture_prefix=""
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	game=load("res://main.tscn").instantiate()
	game.settings_path="res://artifacts/runtime/essential-capture-no-settings.json"
	root.add_child(game)
	await process_frame
	await _screens("")
	game.palette_colors=game.P.PRESETS.AMBER.duplicate()
	game._set_theme()
	game._hud()
	await _screens("amber-")
	print("ESSENTIAL CAPTURE DONE")
	quit()
func _screens(prefix: String) -> void:
	capture_prefix=prefix
	game._close_aux()
	game.build_page="CORE"
	game._build()
	await _capture("build-core")
	for page in ["EQUIP","SKILLS"]:
		game.build_page=page
		game._build()
		await _capture("build-"+page.to_lower())
	game._start_battle()
	game._cell_input(Vector2i(4,4))
	game._cell_input(Vector2i(5,4))
	game._cell_input(Vector2i(5,4),true)
	game.battle.choose_skill(game.C.DAMAGE)
	game._clear_overlay()
	game._cell_input(Vector2i(6,4))
	game._cell_input(Vector2i(4,6))
	game._cell_input(Vector2i(5,6))
	game.message_time=0
	game.toasts=[]
	await _capture("battle")
	game._toggle_info()
	game._toggle_phase()
	await _capture("battle-details")
	game._toggle_info()
	game._toggle_phase()
	game._cell_input(Vector2i(5,6),true)
	await _capture("action")
	game._toggle_info()
	await _capture("action-info")
	game._toggle_info()
	game.battle.choose_skill(game.C.DAMAGE)
	game._clear_overlay()
	game._hud()
	await _capture("target-attack")
	game._toggle_info()
	await _capture("target-info")
	game._toggle_info()
	game._cell_input(Vector2i(6,6))
	await _capture("enemy-turn")
	game._order()
	await _capture("order")
	game._close_aux()
	game._objective()
	await _capture("objective")
	for page in ["PLAY","PHASE","BUILD"]:
		game._help(page)
		await _capture("help-"+page.to_lower())
	for page in ["DISPLAY","COLOR"]:
		game._settings(page)
		await _capture("settings-"+page.to_lower())
	game._close_aux()
	game.battle.mode="RESULT"
	game.battle.result="VICTORY"
	game.loot_rng.seed=187
	game._result()
	await _capture("result")
	if not game.drops.is_empty():
		game._drop_detail(game.drops[0])
		await _capture("result-detail")
	game._close_aux()
	game._build()

	game._start_battle()
	game.battle.mode="RESULT"
	game.battle.result="VICTORY"
	game.result_awarded=true
	game.drops=[]
	game._result()
	await _capture("victory-empty")
	game.battle.result="DEFEAT"
	game.drops=[{"kind":"ARMS","stats":[25,15,20,30,10],"mutation":"NORMAL","new_item":true,"new_mutation":false},{"skill":game.C.MOVE}]
	game._result()
	await _capture("defeat-two")
	game._drop_detail(game.drops[0])
	await _capture("equipment-drop")
	game._close_aux()
	game._build()

func _capture(name: String) -> void:
	await create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	var img=root.get_texture().get_image()
	img.save_png("res://artifacts/runtime/essential-"+capture_prefix+name+".png")
	print("CAPTURE ",name," / ",img.get_size())
