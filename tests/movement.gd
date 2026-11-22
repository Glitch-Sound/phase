extends SceneTree
const B=preload("res://tests/fixture_squad_battle.gd")
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
		_cell_rhythm()
		_boundaries()
		_angles()
		_attack_beat()
		_cloud_fade()
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
## REQ-046-S01
func _cell_rhythm() -> void:
	var b=_battle();b.panels={}
	var source=b.units[0].duplicate(true);var route=[Vector2i(4,4),Vector2i(4,5)]
	b.path=route.duplicate();b.commit_path()
	var final=[b.units.duplicate(true),b.history.duplicate(),b.turn]
	var p=factory.new();p.begin(b,source,route)
	var distances=[];var speeds=[];var on_path=true;var rings_match=true
	for i in range(65):
		p.elapsed=p.duration*i/64.0
		var point=p.position();var distance=point.x-source.pos.x if i<=32 else 1+point.y-4
		on_path=on_path and (is_equal_approx(point.y,4) if i<=32 else is_equal_approx(point.x,4))
		distances.append(distance)
		if i>0:speeds.append(distance-distances[i-1])
		# 位相の期待値は描画関数を使わず、経路上の実変位と通常1歩の規則から求める。
		var u=p.unit()
		rings_match=rings_match and is_equal_approx(u.gear_angle,fposmod(source.gear_angle-source.gear[3]*1.5*distance,360)) and is_equal_approx(u.arms_angle,fposmod(source.arms_angle+source.arms[3]*1.5*distance,360))
	var near=[speeds[0],speeds[31],speeds[32],speeds[63]];var middle=[speeds[15],speeds[16],speeds[47],speeds[48]]
	var pulse=tuning.get_script_constant_map().get("MOVEMENT_CELL_PULSE",0.0)
	_check(pulse>0 and pulse<1 and speeds.min()>0 and near.max()+0.000001<middle.min(),"cell centers slow down without any stop or reversal; between centers accelerates")
	_check(on_path and is_equal_approx(distances[32],1) and is_equal_approx(distances.back(),2),"same clock crosses each exact cell center and corner without a shortcut")
	_check(rings_match and final==[b.units,b.history,b.turn],"per-step ring progress follows spatial progress without changing the model")
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
	p.begin(b,source,[Vector2i(4,4)])
	b.turn+=1
	_check(p.advance(b,100,false)=="cancel" and not p.active,"stale turn cancels old work")
	p.begin(b,source,[Vector2i(4,4)])
	_check(p.advance(_battle(),100,false)=="cancel","replaced battle cannot complete old work")
	p.begin(b,source,[Vector2i(4,4),Vector2i(5,4),Vector2i(6,4),Vector2i(7,4)])
	_check(p.duration<=tuning.MOVEMENT_MAX_SECONDS,"long path never exceeds the configured cap")
	p.reset()
	_check(not p.active and p.advance(b,100,false)=="","explicit exit invalidates all callbacks")
## REQ-046-S01
func _angles() -> void:
	var b=_battle();var source=b.units[0].duplicate(true)
	source.core=[20,20,20,20,20]
	source.core_angle=60;source.initial_core_angle=10;source.gear_angle=350;source.arms_angle=10
	b.units[0]=source.duplicate(true)
	b.panels={Vector2i(4,4):"CLOCKWISE",Vector2i(4,5):"RESET"}
	b.path=[Vector2i(4,4),Vector2i(4,5)];b.commit_path()
	var p=factory.new();p.begin(b,source,[Vector2i(4,4),Vector2i(4,5)])
	_check(p.has_method("unit"),"movement exposes changing per-step rings")
	if not p.has_method("unit"):return
	var before=b.units.duplicate(true)
	p.advance(b,p.duration/4,false)
	var u=p.unit()
	_check(is_equal_approx(u.core_angle,75) and is_equal_approx(u.gear_angle,335) and is_equal_approx(u.arms_angle,25),"first half step follows actual rotation directions")
	p.advance(b,p.duration/2,false);u=p.unit()
	_check(is_equal_approx(u.core_angle,50) and is_equal_approx(u.gear_angle,305) and is_equal_approx(u.arms_angle,55),"RESET interpolates from the first landing rather than skipping it")
	p.advance(b,p.duration/4,false)
	_check(p.unit()==b.units[0] and b.units==before,"arrival state matches actual calculation without extra panel application")
	b.units[0]=source.duplicate(true);b.units[3].pos=Vector2i(5,4);b.units[3].skills=[C.FIELD_SLOW]
	b.panels[Vector2i(4,4)]="COUNTERCLOCKWISE"
	p.begin(b,source,[Vector2i(4,4)]);p.advance(b,p.duration/2,false);u=p.unit()
	_check(is_equal_approx(u.core_angle,45) and is_equal_approx(u.gear_angle,342.5) and is_equal_approx(u.arms_angle,17.5),"SLOW halves equipment rotation while counterclockwise CORE still changes during travel")
## REQ-046-S01、REQ-046-S02、REQ-046-S03
func _attack_beat() -> void:
	var b=_battle();var before=b.units[0].duplicate(true);var route=[Vector2i(4,4)]
	b.path=route.duplicate();b.commit_path()
	var p=factory.new()
	_check(p.get("beat_duration")!=null,"movement owns a bounded attack preparation beat")
	if p.get("beat_duration")==null:return
	var beat=tuning.get_script_constant_map().get("MOVEMENT_ATTACK_BEAT_SECONDS",0)
	p.begin(b,before,route,false,true)
	_check(p.beat_duration==beat and beat>0,"requested attack uses the configured preparation time")
	var state=[b.units.duplicate(true),b.history.duplicate(),b.turn]
	_check(p.advance(b,p.duration,false)=="landed" and p.active and p.landed and p.position()==Vector2(4,4) and p.unit()==b.units[0],"landing holds the exact final state before completion")
	p.advance(b,100,true)
	_check(p.beat_elapsed==0 and state==[b.units,b.history,b.turn],"paused beat accumulates neither display nor battle time")
	p.advance(b,beat/8,false,4)
	_check(p.active and is_equal_approx(p.beat_elapsed,beat/2),"fast playback also accelerates the beat")
	_check(p.advance(b,beat/8+0.000001,false,4)=="arrived" and not p.active and p.advance(b,100,false)=="","attack preparation completes exactly once")
	p.begin(b,before,route,false,true);p.advance(b,p.duration+beat/2,false)
	_check(p.landed and is_equal_approx(p.beat_elapsed,beat/2),"time crossing the landing boundary carries into the beat")
	b.turn+=1
	_check(p.advance(b,100,false)=="cancel" and not p.active,"changed turn cancels a landed pending action")
	_check(not p.begin(b,before,[],false,true),"zero-step movement adds no preparation hold")
## REQ-018-S08、REQ-046-S01、REQ-046-S02、REQ-046-S03
func _cloud_fade() -> void:
	var b=_battle();var source=b.units[0].duplicate(true);source.skills=[C.FIELD_SLOW]
	var p=factory.new()
	_check(p.has_method("cloud_alpha"),"movement exposes only its own cloud visibility")
	if not p.has_method("cloud_alpha"):return
	p.begin(b,source,[Vector2i(4,4)],false,true)
	var fade=tuning.MOVEMENT_CLOUD_OUT_SECONDS
	_check(p.cloud_alpha(source)==1 and p.position()==Vector2(source.pos),"cloud starts visible at the original position")
	p.advance(b,fade/2,false)
	_check(p.cloud_alpha(source)>0 and p.cloud_alpha(source)<1 and p.elapsed==0 and p.position()==Vector2(source.pos),"only departure cloud fades before movement starts")
	var alpha=p.cloud_alpha(source);p.advance(b,100,true)
	_check(p.cloud_alpha(source)==alpha and p.cloud_alpha(b.units[3])==1,"pause holds opacity and other clouds remain unchanged")
	p.advance(b,fade/2,false)
	_check(p.cloud_alpha(source)==0 and p.elapsed==0,"departure is completely clear before the first moving frame")
	p.advance(b,p.duration,false)
	_check(p.landed and p.cloud_alpha(source)==0,"cloud remains hidden through travel and begins revealing at the destination")
	p.advance(b,p.beat_duration,false)
	_check(not p.active and p.cloud_alpha(source)==1,"attack beat overlaps the whole reveal without another wait")
	p.begin(b,source,[Vector2i(4,4)]);p.advance(b,fade+p.duration,false)
	_check(not p.active and p.cloud_alpha(source)==0,"nonattack completes without waiting for the cloud reveal")
	p.advance_cloud(tuning.MOVEMENT_CLOUD_IN_SECONDS,false)
	_check(p.cloud_alpha(source)==1,"nonblocking reveal completes after nonattack")
	p.reset();p.begin(b,source,[])
	_check(p.cloud_alpha(source)==1,"zero steps and reset never leave a hidden cloud")
func _check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",note)
