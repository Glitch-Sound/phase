extends SceneTree
const B=preload("res://game/battle.gd")
const C=preload("res://game/catalog.gd")
var tuning=load("res://game/tuning.gd")
var checks=0
var failures=0
var factory
func _initialize() -> void:
	_check(ResourceLoader.exists("res://ui/movement.gd"),"committed movement presentation exists")
	if failures==0:
		factory=load("res://ui/movement.gd")
		_sequence()
		_boundaries()
	print("MOVEMENT: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
func _battle():
	var b=B.new();b.start(0,C.player_builds(),128);b.actor=0
	return b
## REQ-046-S01
func _sequence() -> void:
	var b=_battle();var source=b.units[0].duplicate(true)
	var route=[Vector2i(4,4),Vector2i(4,5)]
	for cell in route:b.path_click(cell)
	b.commit_path()
	var final=[b.units.duplicate(true),b.history.duplicate(),b.turn,b.mode]
	var p=factory.new()
	_check(p.begin(b,source,route),"starts after a valid committed path")
	var duration=minf(route.size()*tuning.MOVEMENT_CELL_SECONDS,tuning.MOVEMENT_MAX_SECONDS)
	_check(p.duration==duration and p.position()==Vector2(3,4),"duration is bounded distance and begins at source")
	p.advance(b,duration/4,false)
	_check(p.active and p.position().is_equal_approx(Vector2(3.5,4)),"travels first leg rather than teleporting")
	for segment in p.segments(0.45):
		_check(Geometry2D.get_closest_point_to_segment(p.position(),segment[0],segment[1]).distance_to(p.position())>=0.44999,"committed line excludes the moving ring even inside a segment")
	p.advance(b,duration/2,false)
	_check(p.position().is_equal_approx(Vector2(4,4.5)),"turn follows the actual corner")
	_check(p.advance(b,duration/4+0.000001,false)=="arrived" and not p.active and p.position()==Vector2(4,5),"arrival occurs once at exact destination")
	_check(p.advance(b,100,false)=="" and final==[b.units,b.history,b.turn,b.mode],"presentation never reapplies panels, changes battle time or repeats completion")
## REQ-046-S02、REQ-046-S03
func _boundaries() -> void:
	var b=_battle();var source=b.units[0].duplicate(true);var p=factory.new()
	_check(not p.begin(b,source,[]) and not p.active,"zero movement adds no presentation")
	p.begin(b,source,[Vector2i(4,4)],true)
	var initial=p.position()
	p.advance(b,100,true,4)
	p.advance(b,NAN,false)
	_check(p.position()==initial and p.elapsed==0,"pause and invalid delta accumulate no time")
	_check(p.advance(b,p.duration/4+0.000001,false,4)=="arrived","CPU fast speed only shortens display time")
	p.begin(b,source,[Vector2i(4,4)],false,true)
	_check(p.advance(b,0,false)=="arrived" and not p.active,"reduced motion completes without a hold")
	p.begin(b,source,[Vector2i(4,4)])
	b.turn+=1
	_check(p.advance(b,100,false)=="cancel" and not p.active,"stale turn cancels old work")
	p.begin(b,source,[Vector2i(4,4)])
	_check(p.advance(_battle(),100,false)=="cancel","replaced battle cannot complete old work")
	p.begin(b,source,[Vector2i(4,4),Vector2i(5,4),Vector2i(6,4),Vector2i(7,4)])
	_check(p.duration<=tuning.MOVEMENT_MAX_SECONDS,"long path never exceeds the configured cap")
	p.reset()
	_check(not p.active and p.advance(b,100,false)=="","explicit exit invalidates all callbacks")
func _check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",note)
