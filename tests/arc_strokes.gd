extends SceneTree
const V=preload("res://ui/visuals.gd")
const C=preload("res://game/catalog.gd")
const P=preload("res://ui/palette.gd")
const T=preload("res://game/tuning.gd")
var checks=0
var failures=0
func _initialize() -> void:
	_run.call_deferred()
## REQ-030-S02、REQ-030-S03、NREQ-001-S03
func _run() -> void:
	var visual=V.new()
	_check(visual.has_method("stroke_style"),"physical-pixel stroke style exists")
	if visual.has_method("stroke_style"):
		var u=C.unit("01","PLAYER",Vector2i.ZERO,C.default_build())
		for radius in [22.0,31.0,81.0]:
			var g=V.glyph(radius,u,false,P.PRESETS.DEFAULT.slice(1),P.PRESETS.DEFAULT[0])
			for scale in [0.6,0.75,1.0,1.25,1.5,2.4]:
				for arc in [g.arcs[0],g.arcs[15]]:
					var before=arc.duplicate(true)
					var style=visual.stroke_style(arc,scale)
					var floor_px=T.new().get("UNIT_HP_PIXEL_MIN") if arc.role=="HP" else T.new().get("UNIT_COLOR_PIXEL_MIN")
					_check(is_equal_approx(style.width,maxf(arc.width,floor_px/scale)),"only subpixel width is raised: "+str(radius)+"/"+str(scale)+"/"+arc.role)
					var step=(arc.end-arc.start)/(style.points-1)
					var error=arc.radius*scale*(1-cos(step/2))
					_check(style.points>=3 and error<=T.new().get("UNIT_ARC_ERROR_PIXELS")+0.00001,"physical chord error stays within the configured bound")
					_check(arc==before,"stroke leaves angular HP ratio and geometry unchanged")
	print("ARC STROKES: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
