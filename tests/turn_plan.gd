extends SceneTree
const B=preload("res://tests/fixture_squad_battle.gd")
const C=preload("res://game/catalog.gd")
var checks=0
var failures=0
func _initialize() -> void:
	_check(ResourceLoader.exists("res://ui/turn_plan.gd"),"independent turn planning exists")
	if failures==0:
		_run()
		_zero_wait()
	print("TURN PLAN: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
## REQ-010-S01、REQ-010-S02、REQ-010-S03、REQ-010-S04
func _run() -> void:
	var b=B.new();b.start(0,C.player_builds(),128)
	b.units[3].pos=Vector2i(5,4)
	b.units[0].skills=[C.DAMAGE,C.GUARD,C.HEAL]
	b.path_click(Vector2i(4,4))
	var original=[b.units.duplicate(true),b.history.duplicate(),b.turn,b.mode,b.path.duplicate()]
	var p=load("res://ui/turn_plan.gd").new()
	_check(p.begin(b) and p.phase=="CHOICE" and p.projected.units[0].pos==Vector2i(4,4),"selection uses an independent landing")
	_check(original==[b.units,b.history,b.turn,b.mode,b.path],"planning leaves the full real state untouched")
	_check(not p.choose(C.HEAL) and p.phase=="CHOICE","no valid target cannot enter a skill")
	_check(p.choose(C.DAMAGE) and not p.select(1) and p.select(3) and p.phase=="READY","target follows actual landing geometry and allegiance")
	p.back();_check(p.phase=="TARGET" and p.target==-1,"BACK clears the chosen target only")
	p.back();_check(p.phase=="CHOICE" and p.projected.selected_skill=="","next BACK clears only skill")
	p.back();_check(not p.active() and original==[b.units,b.history,b.turn,b.mode,b.path],"cancel retains editable path and every original value")
	p.begin(b);p.choose(C.GUARD)
	_check(p.phase=="READY" and p.target==0 and not b.units[0].guard_active,"self action needs no redundant target click")
	p.back();p.wait()
	var command=p.commit(b)
	_check(command=={"path":[Vector2i(4,4)],"skill":"","target":-1} and b.units[0].pos==Vector2i(4,4) and b.history.size()==1,"final CONFIRM commits movement once and returns the chosen command")
	_check(p.commit(b).is_empty(),"duplicate final confirmation cannot commit again")
	b.start(0,C.player_builds(),128);b.path_click(Vector2i(4,4));p.begin(b);p.wait();b.turn+=1
	_check(p.commit(b).is_empty() and b.units[0].pos==Vector2i(3,4),"stale turn cannot commit a prepared command")
## REQ-012-S03、REQ-012-S04
func _zero_wait() -> void:
	var b=B.new();b.start(0,C.player_builds(),128)
	var p=load("res://ui/turn_plan.gd").new()
	_check(p.begin(b),"free actor may plan zero-step WAIT")
	if not p.active():return
	_check(not p.choose(C.DAMAGE) and p.wait(),"empty route offers WAIT only")
	var command=p.commit(b)
	_check(command=={"path":[],"skill":"","target":-1} and b.mode=="MOVE" and b.history.is_empty(),"zero-step confirmation yields only WAIT without applying movement")
	_check(b.wait_turn() and b.turn==2 and p.commit(b).is_empty(),"zero-step command ends exactly one turn")
	b.start(0,C.player_builds(),128);b.path_click(Vector2i(4,4))
	var original=p._state(b)
	# 任意の経路を選んでいても、その場の予定は空経路。取消は元の経路を保持する。
	_check(p.begin(b,true) and p.route.is_empty() and p.wait(),"explicit stationary plan ignores an unconfirmed route")
	p.back()
	_check(not p.active() and p._state(b)==original,"stationary BACK returns directly to the exact original route")
	p.begin(b,true);p.wait();p.projected.selected_skill=C.GUARD;p.target=0
	_check(p.commit(b).is_empty() and p._state(b)==original,"forged zero-route skill cannot commit through planning")
func _check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",note)
