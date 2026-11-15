extends "res://tests/unit_capture.gd"
# e77c381の比較画像に対し、記号の線の描画だけの変更を許可する。
const ARC_AREAS=[Rect2i(196,345,54,58),Rect2i(196,409,54,58),Rect2i(196,473,54,58),Rect2i(196,537,54,58),Rect2i(196,601,54,58),Rect2i(196,665,54,58),Rect2i(910,380,70,70),Rect2i(770,520,70,70),Rect2i(980,380,70,70),Rect2i(980,520,70,70),Rect2i(1445,155,180,180),Rect2i(172,894,106,106)]
func _initialize() -> void:
	stamp="smooth-"+stamp
	super._initialize()
## REQ-030-S02、REQ-030-S03、REQ-030-S04、NREQ-001-S03
func _capture(suffix: String,audit: bool=false) -> void:
	if audit:
		game.queue_redraw()
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		var image=root.get_texture().get_image()
		var previous=Image.load_from_file("res://artifacts/ui-review/unit-rings-tightened-battle.png")
		if image.get_size()!=previous.get_size():
			_fail("Comparison dimensions differ")
			return
		var inside=0
		var outside=0
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				if image.get_pixel(x,y)==previous.get_pixel(x,y):
					continue
				if ARC_AREAS.any(func(rect):return rect.has_point(Vector2i(x,y))):
					inside+=1
				else:
					outside+=1
		print("SMOOTH PIXEL AUDIT: inside ",inside," / outside ",outside)
		if inside==0 or outside!=0:
			_fail("Only glyph rendering should change")
			return
	await super._capture(suffix,false)
	if suffix=="battle" and OS.get_cmdline_user_args().has("--live-review"):
		print("LIVE REVIEW READY")
		await create_timer(50).timeout
	if suffix=="hp-zero":
		game.battle.units[2].hp=1
		await super._capture("hp-one",false)
		game.battle.units[2].hp=0
	if suffix=="returned":
		root.mode=Window.MODE_FULLSCREEN
		for attempt in range(60):
			if root.size==DisplayServer.screen_get_size():
				break
			await create_timer(0.05).timeout
		if root.mode!=Window.MODE_FULLSCREEN or root.size!=DisplayServer.screen_get_size():
			_fail("Fullscreen did not reach the actual screen dimensions")
		await super._capture("fullscreen",false)
		print("FULLSCREEN ",root.size," / mode ",root.mode," / screen ",DisplayServer.screen_get_size()," / transform ",root.get_final_transform()," / screen scale ",DisplayServer.screen_get_scale())
		root.mode=Window.MODE_WINDOWED
		root.size=Vector2i(1920,1080)
		await create_timer(0.4).timeout
		await super._capture("fullscreen-return",false)
		# 明示した隣接と境界の表示fixture。次のHEAL前に再初期化される。
		var cells=[Vector2i(0,0),Vector2i(1,0),Vector2i(8,9),Vector2i(9,9)]
		for i in range(4):
			game.battle.units[i].pos=cells[i]
		game.battle.path=[]
		game.selected=0
		await super._capture("adjacent-edges",false)
