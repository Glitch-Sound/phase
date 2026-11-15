extends SceneTree
const V=preload("res://ui/visuals.gd")
class MeasuredGame extends "res://ui/main.gd":
	var baseline=false
	var measuring=false
	var samples=[]
	var ring_us=0
	func _draw() -> void:
		var start=Time.get_ticks_usec()
		ring_us=0
		super._draw()
		if measuring and not build_open:
			samples.append({"draw_us":Time.get_ticks_usec()-start,"ring_us":ring_us})
	func _ring(canvas: CanvasItem,center: Vector2,radius: float,u: Dictionary,active: bool=false) -> void:
		var start=Time.get_ticks_usec()
		if baseline:
			_baseline_ring(canvas,center,radius,u,active)
		else:
			super._ring(canvas,center,radius,u,active)
		ring_us+=Time.get_ticks_usec()-start
	# e77c381のringの本体。glyphの半径、角度、配色は修正前後で同一である。
	func _baseline_ring(canvas: CanvasItem,center: Vector2,radius: float,u: Dictionary,active: bool) -> void:
		var g=V.glyph(radius,u,active,status_colors,CYAN)
		for arc in g.arcs:
			canvas.draw_arc(center,arc.radius,arc.start,arc.end,maxi(3,ceili(rad_to_deg(arc.end-arc.start)/3)),arc.color,arc.width,true)
		canvas.draw_line(center+g.tick.from,center+g.tick.to,g.tick.color,g.tick.width,true)
		var size=mono.get_string_size(g.name,HORIZONTAL_ALIGNMENT_LEFT,-1,g.font_size)
		var baseline_y=(mono.get_ascent(g.font_size)-mono.get_descent(g.font_size))/2
		canvas.draw_string(mono,center+Vector2(-size.x/2,baseline_y),g.name,HORIZONTAL_ALIGNMENT_LEFT,-1,g.font_size,WHITE)
func _initialize() -> void:
	_run.call_deferred()
## REQ-030-S03、NREQ-001-S03
func _run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("ARC PERFORMANCE requires a real display and renderer.")
		quit(2)
		return
	var game=MeasuredGame.new()
	game.settings_path="res://artifacts/runtime/arc-performance-no-settings.json"
	root.add_child(game)
	await process_frame
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
	for size in [Vector2i(1920,1080),Vector2i(4608,2592)]:
		if size.x>1920:
			root.mode=Window.MODE_FULLSCREEN
			for attempt in range(60):
				if root.size==DisplayServer.screen_get_size():
					break
				await create_timer(0.05).timeout
		else:
			root.size=size
		for phase in ["BEFORE","AFTER","AFTER","BEFORE"]:
			game.measuring=false
			game.baseline=phase=="BEFORE"
			for frame in range(15):
				await process_frame
			game.samples=[]
			game.measuring=true
			var elapsed=[]
			var previous=Time.get_ticks_usec()
			for frame in range(90):
				await process_frame
				var now=Time.get_ticks_usec()
				elapsed.append(now-previous)
				previous=now
			game.measuring=false
			var draws=game.samples.map(func(s):return s.draw_us)
			var rings=game.samples.map(func(s):return s.ring_us)
			if draws.is_empty():
				printerr("ARC PERFORMANCE observed no redraws; no measurement is available.")
				quit(2)
				return
			print("ARC PERFORMANCE ",JSON.stringify({"phase":phase,"window":str(root.size),"scale":root.get_final_transform().get_scale().x,"engine_fps":1000000.0*elapsed.size()/elapsed.reduce(func(a,b):return a+b,0.0),"redraw_count":draws.size(),"draw_median_ms":_percentile(draws,0.5)/1000.0,"draw_p95_ms":_percentile(draws,0.95)/1000.0,"rings_median_ms":_percentile(rings,0.5)/1000.0,"rings_p95_ms":_percentile(rings,0.95)/1000.0,"frame_p95_ms":_percentile(elapsed,0.95)/1000.0}))
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1920,1080)
	game._restart()
	await process_frame
	quit()
func _percentile(values: Array,fraction: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted=values.duplicate()
	sorted.sort()
	return sorted[clampi(ceili(sorted.size()*fraction)-1,0,sorted.size()-1)]
