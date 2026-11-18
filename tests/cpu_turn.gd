extends SceneTree
const B=preload("res://game/battle.gd")
const C=preload("res://game/catalog.gd")
var checks=0
var failures=0
var presenter
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	_check(ResourceLoader.exists("res://ui/cpu_turn.gd"),"CPU presentation state machine is implemented")
	if failures:
		_finish()
		return
	presenter=load("res://ui/cpu_turn.gd").new()
	_sequence()
	_interruptions()
	_finish()
## REQ-036-S01
func _sequence() -> void:
	var normal=_replay(1.0)
	var fast=_replay(4.0)
	_check(normal.state==fast.state,"presentation speed never changes the exact resulting battle")
	_check(normal.events==["route","route","hold","commit","target","act","done"],"every visible step occurs once in the exact order")
	var t=load("res://game/tuning.gd")
	var duration=t.CPU_TIMES.THINK+2*t.CPU_TIMES.ROUTE+t.CPU_TIMES.COMMIT+t.CPU_TIMES.ACTION+t.CPU_TIMES.TARGET+t.CPU_TIMES.RESULT
	_check(absf(normal.elapsed-duration)<0.09 and fast.elapsed<normal.elapsed/3.0,"configured duration is separate from battle time and fast mode shortens it")
func _replay(speed: float) -> Dictionary:
	var b=_battle()
	var before=b.units.duplicate(true)
	presenter.begin(b,{"path":[Vector2i(3,3),Vector2i(3,4)],"skill":C.DAMAGE,"target":0})
	var events=[]
	var elapsed=0.0
	while presenter.active and elapsed<5:
		var event=presenter.advance(b,0.01,false,speed)
		elapsed+=0.01
		if not event.is_empty():
			events.append(event)
		if event in ["route","hold"]:
			_check(b.units==before and b.preview().pos==b.path.back(),"route preview preserves the actual units and HP")
	_check(b.turn==2 and b.history.size()==2 and b.units[0].hp<100,"single actual movement and attack complete one turn")
	return {"events":events,"state":[b.units,b.history,b.turn,b.actor],"elapsed":elapsed}
## REQ-036-S02、REQ-036-S03
func _interruptions() -> void:
	for target_phase in ["THINK","ROUTE","COMMIT","ACTION","TARGET","RESULT"]:
		var b=_battle()
		presenter.begin(b,{"path":[Vector2i(3,3),Vector2i(3,4)],"skill":C.DAMAGE,"target":0})
		for i in range(1000):
			if presenter.phase==target_phase:
				break
			presenter.advance(b,0.01,false,1.0)
		_check(presenter.phase==target_phase,"reaches stage "+target_phase)
		var before=[b.units.duplicate(true),b.path.duplicate(),b.turn,b.actor,b.mode,presenter.phase,presenter.elapsed]
		presenter.advance(b,100.0,true,4.0)
		_check(before==[b.units,b.path,b.turn,b.actor,b.mode,presenter.phase,presenter.elapsed],"pause/help/focus blocking freezes exact state "+target_phase)
		presenter.reset()
		presenter.advance(b,100.0,false,1.0)
		_check(not presenter.active and before[0]==b.units and before[1]==b.path and before[2]==b.turn,"reset discards all pending work "+target_phase)
	var b=B.new()
	b.start(2,C.player_builds().slice(0,2),1)
	b.actor=3
	b.units[3].pos=Vector2i(0,8)
	presenter.begin(b,{"path":[Vector2i(0,9)],"skill":"","target":-1})
	for i in range(1000):
		presenter.advance(b,0.01,false,1.0)
	_check(b.result=="DEFEAT" and b.history.size()==1 and not presenter.active,"movement terminal never adds WAIT or next action")
	b=_battle()
	presenter.begin(b,{"path":[Vector2i(3,3)],"skill":"","target":-1})
	b.turn+=1
	_check(presenter.advance(b,1.0,false,1.0)=="cancel" and not presenter.active,"unexpected turn invalidates an old presentation")
func _battle():
	var b=B.new()
	b.start(0,C.player_builds().slice(0,2),128)
	b.actor=2
	b.units[2].pos=Vector2i(2,3)
	b.units[0].pos=Vector2i(4,4)
	return b
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
func _finish() -> void:
	print("CPU TURN: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
