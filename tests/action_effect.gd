extends SceneTree
const B=preload("res://game/battle.gd")
const C=preload("res://game/catalog.gd")
const T=preload("res://game/tuning.gd")
var factory
var checks=0
var failures=0
func _initialize() -> void:
	_check(ResourceLoader.exists("res://ui/action_effect.gd"),"action presentation exists")
	if failures==0:
		factory=load("res://ui/action_effect.gd")
		_sequence();_boundaries();_geometry()
	print("ACTION EFFECT: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
func _battle(kind: String=C.DAMAGE):
	var b=B.new();b.start(0,C.player_builds(),128);b.actor=0
	b.units[0].pos=Vector2i.ZERO;b.units[3].pos=Vector2i(1,0)
	if kind==C.HEAL:b.units[3].camp="PLAYER";b.units[3].hp-=1
	b.units[0].skills=[kind];b.mode="CHOICE";b.choose_skill(kind)
	return b
## REQ-021-S01
func _sequence() -> void:
	for kind in [C.DAMAGE,C.HEAL]:
		var b=_battle(kind);var control=_battle(kind);var p=factory.new()
		var before=[b.units.duplicate(true),b.history.duplicate(),b.turn,b.mode]
		_check(p.begin(b,{"actor":0,"skill":kind,"target":3}),"legal action starts without committing")
		p.advance(b,p.duration/2,false)
		_check(before==[b.units,b.history,b.turn,b.mode],"flight never changes HP, phase or history")
		_check(p.advance(b,p.duration/2+0.000001,false)=="hit" and p.hit,"arrival is a single event")
		_check(p.advance(b,100,false)=="","unacknowledged arrival cannot repeat")
		b.act(3);control.act(3);p.confirm_result(b)
		_check(b.units==control.units and b.history==control.history and b.turn==control.turn and b.result==control.result,"normal model action is unchanged")
		_check(p.advance(b,p.impact_duration,false)=="done" and not p.active and p.advance(b,100,false)=="","reaction completes once")
## REQ-021-S02
func _boundaries() -> void:
	var b=_battle();var p=factory.new();var command={"actor":0,"skill":C.DAMAGE,"target":3}
	p.begin(b,command,true);p.advance(b,100,true);p.advance(b,NAN,false)
	_check(p.elapsed==0 and p.active,"pause and invalid time do not accumulate")
	_check(p.advance(b,p.duration/T.CPU_FAST_SPEED+0.000001,false,T.CPU_FAST_SPEED)=="hit","fast mode changes presentation time only")
	p.reset();p.begin(b,command);b.turn+=1
	_check(p.advance(b,100,false)=="cancel" and not p.active,"changed turn invalidates effect")
	b=_battle();p.begin(b,command)
	_check(p.advance(_battle(),100,false)=="cancel","replaced battle invalidates effect")
	p.begin(b,command,false,true)
	_check(p.advance(b,0,false)=="hit","reduced motion has no flight wait")
	b.act(3);p.confirm_result(b)
	_check(p.advance(b,0,false)=="done","reduced motion has no reaction wait")
	b=_battle(C.HEAL)
	_check(not p.begin(b,{"actor":0,"skill":C.HEAL,"target":0}),"illegal self heal creates no light")
## REQ-021-S01
func _geometry() -> void:
	var board=Rect2(0,0,1000,1000);var clearance=47.0
	var cases=[[C.DAMAGE,Vector2i(1,0)],[C.DAMAGE_DIAGONAL,Vector2i(1,1)],[C.DAMAGE_ORTHOGONAL_TWO,Vector2i(2,0)],[C.HEAL_DIAGONAL_TWO,Vector2i(2,2)]]
	for example in cases:
		var b=_battle();var skill=example[0];b.units[0].skills=[skill];b.units[3].pos=example[1]
		if C.SKILLS[skill].effect=="HEAL":b.units[3].camp="PLAYER";b.units[3].hp-=1
		if example[1]==Vector2i(2,2):b.units[2].pos=Vector2i(0,1)
		b.mode="CHOICE";b.choose_skill(skill)
		var p=factory.new()
		_check(p.begin(b,{"actor":0,"skill":skill,"target":3}),"actual range pattern is legal")
		for progress in [0.2,0.6,1.0]:
			p.elapsed=p.duration*progress
			var view=p.geometry(board,100,clearance)
			_check(not view.lines.is_empty() and _clear(view.lines,b,board,clearance),"curve is visible, on board and outside every living ring")
		p.hit=true;p.impact_elapsed=p.impact_duration*0.4
		var reaction=p.geometry(board,100,clearance)
		_check(not reaction.lines.is_empty() and _clear(reaction.lines,b,board,clearance),"damage cuts and healing arcs stay outside rings and on board")
func _clear(lines: Array,b,board: Rect2,clearance: float) -> bool:
	for line in lines:
		for point in line:
			if not board.has_point(point):return false
		for u in b.units:
			if u.hp<=0:continue
			var center=(Vector2(u.pos)+Vector2.ONE*0.5)*100
			if Geometry2D.get_closest_point_to_segment(center,line[0],line[1]).distance_to(center)<clearance-0.001:return false
	return true
func _check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",note)
