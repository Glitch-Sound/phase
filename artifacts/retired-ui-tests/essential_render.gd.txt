extends SceneTree
var failures=0
var checks=0
func _initialize() -> void:
	_run.call_deferred()
## NREQ-002-S01、NREQ-002-S04、NREQ-002-S05
func _run() -> void:
	var game=load("res://main.tscn").instantiate()
	game.settings_path="res://artifacts/runtime/essential-render-no-settings.json"
	root.add_child(game)
	var first=await _image()
	var heading=Rect2i(514,173,200,50)
	_check(_bright(first.get_region(heading))>0,"heading has actual text pixels")
	game.build_page="EQUIP"
	game._build()
	var second=await _image()
	_check(first.get_region(heading).get_data()==second.get_region(heading).get_data(),"BUILD heading survives replacement of modal")
	game._start_battle()
	game._cell_input(Vector2i(4,4))
	game._cell_input(Vector2i(5,4))
	game._cell_input(Vector2i(5,4),true)
	game.battle.choose_skill(game.C.DAMAGE)
	game._clear_overlay()
	game._cell_input(Vector2i(6,4))
	game._cell_input(Vector2i(4,6))
	game._cell_input(Vector2i(5,6))
	game.toasts=[]
	game.message_time=0
	var board=await _image()
	game._toggle_info()
	var info=await _image()
	var area=Rect2i(560,100,700,700)
	_check(board.get_region(area).get_data()==info.get_region(area).get_data(),"board remains drawn when details change")
	var baseline=Image.load_from_file("res://artifacts/ui-review/essential-before.png")
	if baseline!=null:
		var old_luma=_luminance(baseline)
		var new_luma=_luminance(board)
		_check(new_luma<=old_luma*load("res://tests/essential_flow.gd").MAX_LUMINANCE_RATIO,"mean luminance at most half of reference")
		print("LUMINANCE old=",old_luma," new=",new_luma," ratio=",new_luma/old_luma)
	await _test_display_modes(game,first.get_region(heading).get_data())
	await _test_target_details(game)
	print("ESSENTIAL RENDER: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
func _image() -> Image:
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func _luminance(image: Image) -> float:
	var sum=0.0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color=image.get_pixel(x,y).srgb_to_linear()
			sum+=0.2126*color.r+0.7152*color.g+0.0722*color.b
	return sum/(image.get_width()*image.get_height())
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)

## NREQ-001-S03、REQ-027-S01、REQ-027-S02
func _test_display_modes(game,heading_pixels: PackedByteArray) -> void:
	var path=game.battle.path.duplicate()
	var units=game.battle.units.duplicate(true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	await create_timer(0.5).timeout
	var full=await _image()
	print("DISPLAY FULL: window ",root.size," / image ",full.get_size()," / transform ",root.get_final_transform())
	full.save_png("res://artifacts/runtime/essential-fullscreen.png")
	_check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN,"native independent fullscreen mode")
	var scale=minf(root.size.x/1920.0,root.size.y/1080.0)
	_check(root.get_final_transform().x.is_equal_approx(Vector2(scale,0)),"fullscreen uniform logical scale")
	_check(game.battle.path==path and game.battle.units==units,"fullscreen preserves model and pending path")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size=Vector2i(1440,810)
	await create_timer(0.4).timeout
	var windowed=await _image()
	windowed.save_png("res://artifacts/runtime/essential-windowed.png")
	_check(root.get_final_transform().x.is_equal_approx(Vector2(0.75,0)),"return to 1440x810 scale")
	root.size=Vector2i(1200,1600)
	await create_timer(0.4).timeout
	var portrait=await _image()
	print("DISPLAY PORTRAIT: window ",root.size," / image ",portrait.get_size()," / transform ",root.get_final_transform())
	portrait.save_png("res://artifacts/runtime/essential-portrait.png")
	_check(is_equal_approx(root.get_final_transform().x.x,root.get_final_transform().y.y),"portrait preserves square cells")
	_check(root.get_final_transform().origin.y>0,"portrait has vertical letterbox")
	root.size=Vector2i(1920,1080)
	game.palette_colors=game.P.PRESETS.AMBER.duplicate()
	game._set_theme()
	game._hud()
	var amber=await _image()
	amber.save_png("res://artifacts/runtime/essential-amber.png")
	_check(game.battle.path==path and game.battle.units==units,"palette rendering preserves model and path")
	game.build_page="CORE"
	game._build()
	var amber_build=await _image()
	_check(amber_build.get_region(Rect2i(514,173,200,50)).get_data()==heading_pixels,"common heading survives palette and modal replacement")


## REQ-019-S02、NREQ-002-S01
func _test_target_details(game) -> void:
	game._start_battle()
	game._cell_input(Vector2i(4,4))
	game._cell_input(Vector2i(5,4))
	game._cell_input(Vector2i(5,4),true)
	game._toggle_info()
	var choice=await _image()
	var detail=Rect2i(1320,140,430,560)
	_check(_bright(choice.get_region(detail))>0,"ACTION has actual unit detail pixels")
	game.battle.choose_skill(game.C.DAMAGE)
	game._clear_overlay()
	game._hud()
	var target=await _image()
	_check(choice.get_region(detail).get_data()==target.get_region(detail).get_data(),"unit details remain complete after switching to TARGET")
	print("DETAIL PIXELS: choice ",_bright(choice.get_region(detail))," / target ",_bright(target.get_region(detail)))
func _bright(image: Image) -> int:
	var count=0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color=image.get_pixel(x,y)
			if maxf(color.r,maxf(color.g,color.b))>0.3:
				count+=1
	return count
