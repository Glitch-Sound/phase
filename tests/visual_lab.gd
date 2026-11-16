## UIのみの再現用ラボ。ゲーム本体の起動シーンには組み込まない。
extends SceneTree
class LabInput extends Node:
	var game
	var fixture="BUILD"
	var shots=0
	func _input(event: InputEvent) -> void:
		if not event is InputEventKey or not event.pressed or event.echo:
			return
		if event.keycode==KEY_F2 or event.keycode==KEY_F3:
			game._close_aux()
			game._start_battle()
			game.battle.mode="RESULT"
			game.battle.result="VICTORY" if event.keycode==KEY_F2 else "DEFEAT"
			game.result_awarded=true
			game.drops=[] if event.keycode==KEY_F2 else [
				{"kind":"ARMS","stats":[25,15,20,30,10],"mutation":"NORMAL","new_item":true,"new_mutation":false},
				{"skill":game.C.MOVE}]
			game._result()
			fixture=game.battle.result
		elif event.keycode==KEY_F4 or event.keycode==KEY_F5:
			game._close_aux()
			game._start_battle()
			game.battle.units[0].pos=Vector2i(5,5) if event.keycode==KEY_F4 else Vector2i(5,4)
			if event.keycode==KEY_F4:
				game.battle.units[1].pos=Vector2i(6,5)
				game.battle.units[1].hp=84.0
			else:
				game.battle.units[2].hp=11.0
			game.battle.mode="CHOICE"
			game.battle.choose_skill(game.C.HEAL if event.keycode==KEY_F4 else game.C.DAMAGE)
			game._clear_overlay()
			game._hud()
			fixture="HEAL TARGET" if event.keycode==KEY_F4 else "ATTACK TARGET"
		elif event.keycode==KEY_F6:
			game._close_aux()
			game._start_battle()
			game._cell_input(Vector2i(4,4))
			game._cell_input(Vector2i(5,4))
			game._cell_input(Vector2i(5,4),true)
			fixture="ACTION"
		elif event.keycode==KEY_F10:
			shots+=1
			_capture.call_deferred()
		else:
			return
		game.queue_redraw()
		get_viewport().set_input_as_handled()
		print("UI LAB / ",fixture," / window ",get_window().size," / scale ",DisplayServer.screen_get_scale())
	func _capture() -> void:
		await RenderingServer.frame_post_draw
		var stamp=str(Time.get_unix_time_from_system()).replace(".","-")
		var path="res://artifacts/runtime/ui-lab-%s-%02d.png" % [stamp,shots]
		while FileAccess.file_exists(path):
			shots+=1
			path="res://artifacts/runtime/ui-lab-%s-%02d.png" % [stamp,shots]
		get_viewport().get_texture().get_image().save_png(path)
		print("UI LAB CAPTURE / ",path)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	root.title="PHASE / UI LAB"
	var game=load("res://tests/fixture_main.gd").new()
	game.settings_path="res://artifacts/runtime/ui-lab-settings.json"
	root.add_child(game)
	var input=LabInput.new()
	input.game=game
	root.add_child(input)
	print("UI LAB / F2 victory0 / F3 defeat2 / F4 heal / F5 damage / F6 action / F10 capture")
