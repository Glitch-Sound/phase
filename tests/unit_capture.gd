extends SceneTree
# 72f3ae4の同一TURN2画像に対し、ユニット記号とその重複名、外側HPだけを許可する。
# 旧外周円のアンチエイリアスはセル上端から3px出ていたため、その消去も含める。
const UNIT_AREAS=[Rect2i(196,345,122,58),Rect2i(196,409,122,58),Rect2i(196,473,122,58),Rect2i(196,537,122,58),Rect2i(196,601,122,58),Rect2i(196,665,122,58),Rect2i(910,376,70,74),Rect2i(770,516,70,74),Rect2i(980,376,70,74),Rect2i(980,516,70,74),Rect2i(1320,100,100,55),Rect2i(1445,155,180,180),Rect2i(1324,397,422,4),Rect2i(172,894,106,106)]
var game
var failed=false
var stamp=str(Time.get_unix_time_from_system()).replace(".","-")
func _initialize() -> void:
	_run.call_deferred()
## REQ-030-S03、REQ-031-S02
func _run() -> void:
	game=load("res://main.tscn").instantiate()
	game.settings_path="res://artifacts/runtime/unit-capture-no-settings-"+stamp+".json"
	root.add_child(game)
	await process_frame
	await _capture("build")
	game._start_battle()
	game._cell_input(Vector2i(4,4))
	game._cell_input(Vector2i(5,4))
	game._cell_input(Vector2i(5,4),true)
	await process_frame
	game.battle.choose_skill(game.C.DAMAGE)
	game._clear_overlay()
	game._cell_input(Vector2i(6,4))
	game._cell_input(Vector2i(4,6))
	game._cell_input(Vector2i(5,6))
	game.message_time=0
	game.toasts=[]
	await _capture("battle",true)
	var u=game.battle.preview()
	print("STATE ",JSON.stringify({"turn":game.battle.turn,"actor":u.id,"enemy_a_hp":game.battle.units[2].hp,"path":str(game.battle.path),"inf":game.M.sync(u,1).factor*100,"res":game.M.sync(u,2).factor*100}))
	# 実戦の選択とHP89を拡大詳細に表示する。
	game.selected=2
	await _capture("inspect-a")
	# 境界HPの表示fixture。モデルの数式やセーブは変更しない。
	game.battle.units[2].hp=50
	await _capture("hp-half")
	game.battle.units[2].hp=0
	await _capture("hp-zero")
	game.battle.units[2].hp=100
	await _capture("hp-full")
	game.battle.units[2].hp=89
	game.palette_colors=game.P.PRESETS.AMBER.duplicate()
	game._set_theme()
	await _capture("amber")
	root.size=Vector2i(1152,648)
	await _capture("minimum")
	root.size=Vector2i(1200,1600)
	await _capture("portrait")
	root.size=Vector2i(1920,1080)
	game.palette_colors=game.P.PRESETS.DEFAULT.duplicate()
	game._set_theme()
	game.selected=-1
	await _capture("returned")
	# 配置を明示した検証用戦闘で、実際のHEALと描画の接続も確認する。
	game._start_battle()
	game.battle.units[0].pos=Vector2i(5,5)
	game.battle.units[1].pos=Vector2i(6,5)
	game.battle.units[1].hp=50
	game.selected=1
	game.battle.mode="CHOICE"
	game._action_dialog()
	game.message_time=0
	await _capture("healing-choice")
	var heal=game.overlay.find_children("*","Button",true,false).filter(func(b):return b.text=="HEAL / ADJACENT")[0]
	heal.pressed.emit()
	await process_frame
	game._cell_input(Vector2i(6,5))
	print("ACTUAL HEAL: ",game.battle.last_effect," / HP ",game.battle.units[1].hp)
	await _capture("healing-after")
	game._restart()
	await process_frame
	quit(1 if failed else 0)
func _capture(suffix: String,audit: bool=false) -> void:
	game.queue_redraw()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	if audit:
		var reference=Image.load_from_file("res://artifacts/ui-review/map-labels-battle.png")
		if image.get_size()!=reference.get_size():
			_fail("Comparison uses the same viewport size")
			return
		var inside=0
		var outside=0
		var examples=[]
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				if image.get_pixel(x,y)==reference.get_pixel(x,y):
					continue
				if UNIT_AREAS.any(func(rect):return rect.has_point(Vector2i(x,y))):
					inside+=1
				else:
					outside+=1
					if examples.size()<5:
						examples.append(Vector2i(x,y))
		print("UNIT PIXEL AUDIT: inside ",inside," / outside ",outside," / examples ",examples)
		if inside==0 or outside!=0:
			_fail("Only authorized unit regions change")
			return
	var path="res://artifacts/runtime/PHASE-units-"+stamp+"-"+suffix+".png"
	if FileAccess.file_exists(path):
		_fail("Never overwrite a capture")
		return
	if image.save_png(path)!=OK:
		_fail("Capture could not be saved")
		return
	print("CAPTURE ",ProjectSettings.globalize_path(path)," ",image.get_size())
func _fail(message: String) -> void:
	failed=true
	printerr("FAIL: ",message)
