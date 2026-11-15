extends SceneTree
const V=preload("res://ui/visuals.gd")
const C=preload("res://game/catalog.gd")
const P=preload("res://ui/palette.gd")
var checks=0
var failures=0
var health=0
var canvas: Control
var typeface: SystemFont
var samples=[]
var stamp=str(Time.get_unix_time_from_system()).replace(".","-")
func _initialize() -> void:
	_run.call_deferred()
## REQ-030-S02、REQ-030-S03、NREQ-001-S03
func _run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("ARC RENDER requires a real display and renderer; headless is not a pixel verification.")
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/runtime"))!=OK:
		printerr("ARC RENDER could not create its output directory.")
		quit(2)
		return
	typeface=SystemFont.new()
	typeface.font_names=PackedStringArray(["Menlo","Monaco"])
	canvas=Control.new()
	root.add_child(canvas)
	var positions=[Vector2(805,415),Vector2(805,555),Vector2(1015,415),Vector2(1015,555)]
	for kind in range(2):
		for i in range(4):
			var u=C.unit(["01","02","A","B"][i],"PLAYER" if i<2 else "ENEMY",Vector2i.ZERO,C.default_build())
			samples.append({"u":u,"position":Vector2(223,374+i*64) if kind==0 else positions[i],"radius":22.0 if kind==0 else 31.0,"kind":"TIMELINE" if kind==0 else "BOARD"})
	canvas.draw.connect(_draw_samples)
	print("ARC ENVIRONMENT: DPI ",DisplayServer.screen_get_dpi()," / screen scale ",DisplayServer.screen_get_scale())
	for size in [Vector2i(1152,648),Vector2i(1440,810),Vector2i(1920,1080),Vector2i(2400,1350),Vector2i(2880,1620),Vector2i(3840,2160)]:
		root.size=size
		health=0
		var zero=await _frame()
		var transform=canvas.get_viewport_transform()
		var scale=transform.get_scale().x
		for hp in [1,50,89,100]:
			health=hp
			var image=await _frame()
			var absent=0
			var spill=0
			for sample in samples:
				var center=transform*sample.position
				var radius=sample.radius*0.41*scale
				var margin=rad_to_deg(2.0/radius)
				var missing=0
				var extra=0
				var peak_signal=0.0
				for degree in range(360):
					var peak=_signal(image,zero,center,radius,deg_to_rad(degree-90))
					peak_signal=maxf(peak_signal,peak)
					if hp==100 or (degree>margin and degree<hp*3.6-margin):
						missing+=1 if peak<0.08 else 0
					if hp<100 and degree>hp*3.6+margin and degree<360-margin:
						extra+=1 if peak>0.02 else 0
				absent+=missing
				spill+=extra
				_check(peak_signal>0.08 and missing==0 and extra==0,"HP "+str(hp)+" "+sample.kind+" "+sample.u.id+" scale "+str(scale)+" missing="+str(missing)+" spill="+str(extra)+" peak="+str(peak_signal))
			print("ARC PIXELS: scale ",scale," / HP ",hp," / missing ",absent," / unintended arc ",spill)
			var path="res://artifacts/runtime/arc-render-"+stamp+"-"+str(size.x)+"-hp"+str(hp)+".png"
			_check(not FileAccess.file_exists(path) and image.save_png(path)==OK,"unique raw capture saved")
			var decoded=Image.load_from_file(path)
			decoded.convert(image.get_format())
			_check(decoded.get_data()==image.get_data(),"PNG round trip preserves every source pixel")
	print("ARC RENDER: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
func _frame() -> Image:
	canvas.queue_redraw()
	await create_timer(0.06).timeout
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func _draw_samples() -> void:
	canvas.draw_rect(Rect2(0,0,1920,1080),P.BG)
	for sample in samples:
		sample.u.hp=health
		V.ring(canvas,sample.position,sample.radius,sample.u,false,P.PRESETS.DEFAULT.slice(1),P.PRESETS.DEFAULT[0],typeface)
func _signal(image: Image,zero: Image,center: Vector2,radius: float,angle: float) -> float:
	var peak=0.0
	for step in range(-8,9):
		var point=center+Vector2.from_angle(angle)*(radius+step*0.25)
		var color=image.get_pixel(roundi(point.x),roundi(point.y))-zero.get_pixel(roundi(point.x),roundi(point.y))
		peak=maxf(peak,maxf(color.r,maxf(color.g,color.b)))
	return peak
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
