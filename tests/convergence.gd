extends SceneTree
var visual=load("res://ui/visuals.gd")
var tuning=load("res://game/tuning.gd")
var checks=0
var failures=0
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	var methods=visual.get_script_method_list().map(func(m):return m.name)
	_check(methods.has("convergence_rings"),"pure concentric geometry exists")
	if methods.has("convergence_rings"):_geometry()
	var ring_method=visual.get_script_method_list().filter(func(m):return m.name=="convergence_rings")[0]
	_check(ring_method.args.size()==3,"healing has its own outward geometry")
	if ring_method.args.size()==3:_healing()
	_check(methods.has("ring_response"),"localized first-contact response exists")
	if methods.has("ring_response"):_reaction()
	var game=load("res://tests/fixture_main.gd").new()
	game.save_path="res://artifacts/runtime/convergence-prototype/no-save.json";game.settings_path="res://artifacts/runtime/convergence-prototype/no-settings.json"
	root.add_child(game);await process_frame;game.set_process(false)
	_check(game.get("convergences") is Array,"UI owns only passive convergence records")
	if game.get("convergences") is Array:_connection(game)
	game._restart();game.queue_free();await process_frame
	print("CONVERGENCE: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
## REQ-021-S04
func _geometry() -> void:
	var age=tuning.CONVERGENCE_STAGGER_SECONDS*(tuning.CONVERGENCE_COUNT-1)
	var early=visual.convergence_rings(age,44.0)
	var later=visual.convergence_rings(age+tuning.CONVERGENCE_TRAVEL_SECONDS*0.2,44.0)
	_check(early.size()==tuning.CONVERGENCE_COUNT and early[0].radius<early[1].radius and early[1].radius<early[2].radius,"stagger creates distinct concentric inward fronts")
	_check(later[0].radius<early[0].radius and later.all(func(r):return r.radius>=44 and r.alpha>0 and r.alpha<=1),"radii shrink toward the protected ring with bounded opacity")
	_check(visual.convergence_rings(tuning.CONVERGENCE_SECONDS,44).is_empty(),"configured lifetime has no residual circle")
	var center=Vector2(50,50);var board=Rect2(0,0,200,200);var masks=[{"center":Vector2(100,50),"radius":32.0}]
	var lines=visual.convergence_segments(center,70,board,masks)
	_check(not lines.is_empty() and _clear(lines,board,masks[0]),"circle is clipped at board edge and other unit rings")
## REQ-021-S04
func _healing() -> void:
	var start=visual.convergence_rings(0,44,true)
	var age=tuning.CONVERGENCE_STAGGER_SECONDS*(tuning.CONVERGENCE_COUNT-1)
	var early=visual.convergence_rings(age,44,true)
	var later=visual.convergence_rings(age+tuning.CONVERGENCE_TRAVEL_SECONDS*0.2,44,true)
	_check(start.size()==1 and is_equal_approx(start[0].radius,44*tuning.CONVERGENCE_HEAL_START_SCALE) and start[0].radius<44,"healing first appears near the center, before the outer ring")
	_check(early.size()==tuning.CONVERGENCE_COUNT and early[0].radius>early[1].radius and early[1].radius>early[2].radius and later[0].radius>early[0].radius,"staggered healing circles move outward rather than converge")
	_check(visual.convergence_rings(tuning.CONVERGENCE_SECONDS,44,true).is_empty(),"outward circles expire outside without adding wait")
	var hidden=visual.convergence_segments(Vector2(100,50),12,Rect2(0,0,200,200),[{"center":Vector2.ZERO,"radius":0.0,"rect":Rect2(85,35,30,30)}])
	_check(hidden.is_empty(),"healing cannot draw through the protected unit name")
## REQ-021-S04、REQ-021-S06
func _connection(game) -> void:
	for kind in [game.C.DAMAGE,game.C.HEAL]:
		game._start_battle();game.battle.actor=0;game.battle.units[0].pos=Vector2i(4,4);game.battle.units[2].pos=Vector2i(5,4)
		game.battle.units[0].skills=[kind];game.battle.units[0].moved=1;game.battle.mode="CHOICE"
		if kind==game.C.HEAL:game.battle.units[2].camp="PLAYER";game.battle.units[2].hp-=1
		game.battle.choose_skill(kind);var before=game.battle.units[2].hp
		game._cell_input(Vector2i(5,4))
		_check(game.battle.turn==2 and game.battle.units[2].hp!=before and game.convergences.size()==1 and game.convergences[0].age==0,"existing effect and turn apply immediately before passive display")
		_check(game.convergences[0].get("kind","")==game.C.SKILLS[kind].effect and game.convergences[0].get("target",-1)==2,"display receives the real action kind and target")
		var pulse=game.convergences[0]
		if kind==game.C.HEAL:
			_check(is_equal_approx(pulse.get("gain_from",-1.0),before/game.battle.units[2].max_hp) and is_equal_approx(pulse.get("gain_to",-1.0),game.battle.units[2].hp/game.battle.units[2].max_hp),"response uses only actual capped HP gain")
		var history=game.battle.history.duplicate();var hp=game.battle.units[2].hp
		game._advance_convergence(tuning.CONVERGENCE_SECONDS)
		_check(game.convergences.is_empty() and game.battle.history==history and game.battle.units[2].hp==hp,"display lifetime never repeats or delays model action")
	game._start_battle();game.battle.units[2].hp=0;game.battle.last_effect={"kind":"DAMAGE","target":2,"amount":1,"actual":1,"dead":true}
	game._feedback();var cell=game.battle.units[2].pos
	game.battle.mode="RESULT";game.battle.result="VICTORY";game.result_awarded=true;game._result()
	game.battle.units[2].pos=Vector2i.ZERO;game._advance_convergence(tuning.CONVERGENCE_SECONDS/2)
	_check(game.convergences.size()==1 and game.convergences[0].cell==cell,"defeat and later unit state never move or discard the stored center")
	game._restart();_check(game.convergences.is_empty(),"BUILD and restart clear convergence")
	game._start_battle();game.battle.last_effect={"kind":"GUARD","target":0};game._feedback()
	_check(game.convergences.is_empty(),"utility actions do not emit convergence")
	game.battle.last_effect={"kind":"HEAL","target":0,"amount":1,"actual":1,"dead":false};game._feedback();game.reduced_motion=true;game._advance_convergence(0)
	_check(game.convergences.is_empty(),"reduced motion omits convergence without changing effects")
	game.reduced_motion=false;game._feedback();game._help();game._advance_convergence(0)
	_check(game.convergences.is_empty(),"auxiliary screen clears circles without a delayed return")
	game._close_aux();game._feedback();game.battle=game.B.new();game._advance_convergence(0)
	_check(game.convergences.is_empty(),"replacing battle cannot retain an old center")
## REQ-021-S06
func _reaction() -> void:
	var edge=44.0;var unit=44.0;var contact=tuning.CONVERGENCE_TRAVEL_SECONDS
	_check([contact,contact+(tuning.CONVERGENCE_SECONDS-contact)*0.5,tuning.CONVERGENCE_SECONDS].all(func(age):return visual.ring_response(age,edge,unit,"DAMAGE",0,0).is_empty()),"attack never adds a white exterior response")
	var start=edge*tuning.CONVERGENCE_HEAL_START_SCALE;var outer=edge*tuning.CONVERGENCE_OUTER_SCALE
	var crossing=tuning.CONVERGENCE_TRAVEL_SECONDS*pow((unit*tuning.UNIT_HP_RADIUS-start)/(outer-start),1.0/tuning.CONVERGENCE_HEAL_EASE_POWER)
	_check(visual.ring_response(crossing-0.001,edge,unit,"HEAL",0.8,1).is_empty(),"healing waits only in display until first front crosses HP")
	var heal=visual.ring_response(crossing,edge,unit,"HEAL",0.8,1.2)
	_check(not heal.is_empty() and is_equal_approx(heal.radius,unit*tuning.UNIT_HP_RADIUS) and is_equal_approx(heal.start_angle,-PI/2+TAU*0.8) and is_equal_approx(heal.arc_angle,TAU*0.2),"only actual gain interval lights and excess is clipped")
	_check(visual.ring_response(crossing,edge,unit,"HEAL",0.8,0.8).is_empty(),"zero gain never lights an existing HP segment")
	var lines=visual.convergence_segments(Vector2(100,100),heal.radius,Rect2(0,0,200,200),[],heal.start_angle,heal.arc_angle)
	_check(not lines.is_empty() and lines[0][0].is_equal_approx(Vector2(100,100)+Vector2.from_angle(-PI/2+TAU*0.8)*heal.radius) and lines.back()[-1].is_equal_approx(Vector2(100,100)+Vector2.UP*heal.radius),"clipped response geometry covers precisely the gain interval")
func _clear(paths: Array,board: Rect2,mask: Dictionary) -> bool:
	for path in paths:
		for i in range(path.size()-1):
			if not board.has_point(path[i]) or not board.has_point(path[i+1]):return false
			if Geometry2D.get_closest_point_to_segment(mask.center,path[i],path[i+1]).distance_to(mask.center)<mask.radius:return false
	return true
func _check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",note)
