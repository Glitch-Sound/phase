extends "res://tests/unit_capture.gd"
# 36c7827の比較画像に対し、ユニット記号だけの変更を許可する。
const GLYPH_AREAS=[Rect2i(196,345,54,58),Rect2i(196,409,54,58),Rect2i(196,473,54,58),Rect2i(196,537,54,58),Rect2i(196,601,54,58),Rect2i(196,665,54,58),Rect2i(910,380,70,70),Rect2i(770,520,70,70),Rect2i(980,380,70,70),Rect2i(980,520,70,70),Rect2i(1445,155,180,180),Rect2i(172,894,106,106)]
func _initialize() -> void:
	stamp="tight-"+stamp
	super._initialize()
## REQ-030-S03、REQ-030-S04
func _capture(suffix: String,audit: bool=false) -> void:
	if audit:
		game.queue_redraw()
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		var image=root.get_texture().get_image()
		var previous=Image.load_from_file("res://artifacts/ui-review/unit-rings-battle.png")
		if image.get_size()!=previous.get_size():
			_fail("Comparison viewport dimensions differ")
			return
		var inside=0
		var outside=0
		var core_changed=0
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				if image.get_pixel(x,y)==previous.get_pixel(x,y):
					continue
				if GLYPH_AREAS.any(func(rect):return rect.has_point(Vector2i(x,y))):
					inside+=1
				else:
					outside+=1
				var distance=Vector2(x+0.5-1535,y+0.5-245).length()
				if distance>44 and distance<52:
					core_changed+=1
		var old_hp=_white_hp_pixels(previous)
		var new_hp=_white_hp_pixels(image)
		print("TIGHT PIXEL AUDIT: inside ",inside," / outside ",outside," / CORE changed ",core_changed," / HP white ",old_hp," -> ",new_hp)
		if inside==0 or outside!=0 or core_changed!=0 or new_hp<=0 or new_hp>=old_hp:
			_fail("Unit-only change, stable CORE, and thinner HP expected")
			return
	await super._capture(suffix,false)
	if suffix=="hp-zero":
		game.battle.units[2].hp=1
		await super._capture("hp-one",false)
		game.battle.units[2].hp=0
	if suffix=="returned":
		# 隣接と四隅の検証用配置。保存せず、次の実HEALの前に再初期化される。
		var cells=[Vector2i(0,0),Vector2i(1,0),Vector2i(8,9),Vector2i(9,9)]
		for i in range(4):
			game.battle.units[i].pos=cells[i]
		game.battle.path=[]
		game.selected=0
		await super._capture("adjacent-edges",false)
		game.battle.units[2].pos=Vector2i(2,0)
		game.battle.units[3].pos=Vector2i(3,0)
		game.selected=2
		game.battle.mode="CHOICE"
		game.battle.choose_skill(game.C.DAMAGE)
		game._hud()
		await super._capture("target",false)
func _white_hp_pixels(image: Image) -> int:
	var count=0
	for y in range(209,282):
		for x in range(1499,1572):
			var distance=Vector2(x+0.5-1535,y+0.5-245).length()
			var color=image.get_pixel(x,y)
			if distance>30 and distance<36 and minf(color.r,minf(color.g,color.b))>0.78:
				count+=1
	return count
