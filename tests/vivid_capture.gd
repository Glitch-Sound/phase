extends "res://tests/unit_capture.gd"
const RING_AREAS=[Rect2i(196,345,54,58),Rect2i(196,409,54,58),Rect2i(196,473,54,58),Rect2i(196,537,54,58),Rect2i(196,601,54,58),Rect2i(196,665,54,58),Rect2i(910,380,70,70),Rect2i(770,520,70,70),Rect2i(980,380,70,70),Rect2i(980,520,70,70),Rect2i(1445,155,180,180),Rect2i(172,894,106,106)]
func _initialize() -> void:
	stamp="vivid-"+stamp
	super._initialize()
## REQ-032-S04
func _capture(suffix: String,audit: bool=false) -> void:
	if audit:
		game.queue_redraw()
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		var image=root.get_texture().get_image()
		var previous=Image.load_from_file("res://artifacts/ui-review/unit-arcs-smooth-battle.png")
		if image.get_size()!=previous.get_size():
			_fail("Comparison dimensions differ")
			return
		var hp_regions=[]
		for k in range(6):
			hp_regions.append({"center":Vector2(223,374+k*64),"radius":22*game.T.UNIT_HP_RADIUS+2})
		for center in [Vector2(945,415),Vector2(805,555),Vector2(1015,415),Vector2(1015,555)]:
			hp_regions.append({"center":center,"radius":game.T.UNIT_BOARD_RADIUS*game.T.UNIT_HP_RADIUS+2})
		hp_regions.append({"center":Vector2(1535,245),"radius":81*game.T.UNIT_HP_RADIUS+2})
		hp_regions.append({"center":Vector2(225,947),"radius":48*game.T.UNIT_HP_RADIUS+2})
		var inside=0
		var outside=0
		var hp_changed=0
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				if image.get_pixel(x,y)==previous.get_pixel(x,y):
					continue
				var point=Vector2i(x,y)
				if RING_AREAS.any(func(rect):return rect.has_point(point)):
					inside+=1
				else:
					outside+=1
				if hp_regions.any(func(region):return Vector2(point).distance_to(region.center)<=region.radius):
					hp_changed+=1
		print("VIVID PIXEL AUDIT: ring ",inside," / outside ",outside," / HP and center ",hp_changed)
		if inside==0 or outside!=0 or hp_changed!=0:
			_fail("Only colored ring regions may change")
			return
		print("VIVID PALETTE ",game.ring_colors.map(func(c):return c.to_html(false)))
	await super._capture(suffix,false)
	if suffix=="build":
		game._settings()
		await super._capture("settings",false)
		game._close_aux()
	if suffix=="returned":
		game.palette_colors=game.P.PRESETS.ICE.duplicate()
		game._set_theme()
		await super._capture("ice",false)
		game.palette_colors=game.P.PRESETS.DEFAULT.duplicate()
		game.palette_colors[0]=game.P.PRESETS.AMBER[0]
		game._set_theme()
		await super._capture("custom",false)
		print("EXACT CUSTOM ",game.ring_colors==game.status_colors)
		game.palette_colors=game.P.PRESETS.DEFAULT.duplicate()
		game._set_theme()
