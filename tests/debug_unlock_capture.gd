## 実GPUの描画標本を保存する検証専用シーン。物理入力とOSフォーカスの合格には使わない。
extends SceneTree
var game
var prefix="res://artifacts/runtime/debug-unlock-render-"+str(Time.get_unix_time_from_system())
func _initialize() -> void:_run.call_deferred()
## REQ-041-S05
func _run() -> void:
	game=load("res://ui/main.gd").new()
	game.save_path=prefix+"-save.json"
	game.settings_path=prefix+"-settings.json"
	root.add_child(game)
	await process_frame
	game._toggle_debug(true)
	for dimensions in [Vector2i(1152,648),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(1200,1600)]:
		root.size=dimensions
		await create_timer(0.15).timeout
		var options=game.overlay.find_children("*","OptionButton",true,false)
		_select(options[1],125)
		_select(options[2],119)
		_select(options[3],0)
		_select(options[4],0)
		_select(options[5],game.collection.skills.find(game.C.GUARD)+1)
		_select(game.overlay.find_children("*","OptionButton",true,false)[6],game.collection.skills.find(game.C.FIELD_FAST)+1)
		await _shot("build-"+str(dimensions.x)+"x"+str(dimensions.y))
	root.size=Vector2i(1920,1080)
	game._start_battle()
	game.battle.path_click(Vector2i(4,5))
	game.battle.path_click(Vector2i(4,4))
	game.battle.commit_path()
	game.battle.choose_skill(game.C.GUARD)
	game.battle.act(game.battle.actor)
	await _shot("battle")
	game._restart()
	game._toggle_debug(false)
	await _shot("normal-return")
	print("DEBUG UNLOCK RENDER: "+prefix+" / normal BUILD restored; OS input not verified")
	game.queue_free()
	await process_frame
	quit()
func _select(option: OptionButton,index: int) -> void:
	option.select(index)
	option.item_selected.emit(index)
func _shot(suffix: String) -> void:
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(prefix+"-"+suffix+".png")
