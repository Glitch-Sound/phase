extends SceneTree
const B=preload("res://game/battle.gd")
const C=preload("res://game/catalog.gd")
const M=preload("res://game/phase_math.gd")
const T=preload("res://game/tuning.gd")
var checks=0
var failures=0
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	_contrast()
	var b=B.new()
	_check(b.has_method("reselect_path"),"confirmed movement can be reopened before acting")
	if b.has_method("reselect_path"):
		_reselection()
		_boundaries()
	print("TACTICAL DECISIONS MODEL: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
## REQ-010-S01、REQ-010-S02、REQ-010-S03
func _reselection() -> void:
	var b=B.new()
	b.start(0,C.player_builds().slice(0,2),1)
	b.units[0].core_angle=45.0
	b.units[0].initial_core_angle=17.0
	b.units[0].gear_angle=300.0
	b.units[0].arms_angle=60.0
	b.units[0].hp=73.5
	b.history=["previous completed turn"]
	b.last_effect={"target":0,"actual":26.5}
	b.panels={Vector2i(4,4):"CLOCKWISE",Vector2i(5,4):"RESET",Vector2i(5,5):"COUNTERCLOCKWISE"}
	var original=b.units.duplicate(true)
	var prior=b.history.duplicate()
	var effect=b.last_effect.duplicate()
	var route=[Vector2i(4,4),Vector2i(5,4),Vector2i(5,5)]
	for cell in route:
		_check(b.path_click(cell),"legal mixed-panel route "+str(cell))
	for attempt in range(3):
		_check(b.commit_path(),"repeated commit succeeds "+str(attempt))
		_check([b.units[0].core_angle,b.units[0].gear_angle,b.units[0].arms_angle]==[332.0,210.0,150.0],"reset and rotation apply once in actual order")
		_check(b.reselect_path(),"reselection succeeds before acting")
		_check(b.units==original and b.path==route and b.history==prior and b.last_effect==effect and b.actor==0 and b.turn==1 and b.mode=="MOVE" and b.selected_skill=="","exact restoration of all units, HP, start angle, counters, history and retained editable path")
	_check(b.path_click(Vector2i(4,4)) and b.path==[Vector2i(4,4)],"reopened route can truncate")
	_check(b.commit_path() and [b.units[0].core_angle,b.units[0].gear_angle,b.units[0].arms_angle]==[90.0,270.0,90.0],"only edited route applies after rollback")
	var committed=b.units.duplicate(true)
	_check(b.choose_skill(C.HEAL),"target selection can open")
	b.back()
	_check(b.mode=="CHOICE" and b.units==committed and b.selected_skill=="","TARGET BACK keeps the already chosen movement")
	_check(b.reselect_path() and b.units==original,"second BACK can reopen movement")
## REQ-010-S04
func _boundaries() -> void:
	var b=B.new()
	b.start(0,C.player_builds().slice(0,2),1)
	b.path_click(Vector2i(4,4))
	b.commit_path()
	b.wait_turn()
	var state=[b.units.duplicate(true),b.history.duplicate(),b.turn,b.actor]
	_check(not b.reselect_path() and state==[b.units,b.history,b.turn,b.actor],"WAIT is irreversible")
	b.start(0,C.player_builds().slice(0,2),1)
	b.path_click(Vector2i(4,4))
	b.path_click(Vector2i(5,4))
	b.commit_path()
	b.choose_skill(C.DAMAGE)
	b.act(2)
	state=[b.units.duplicate(true),b.history.duplicate(),b.turn,b.actor]
	_check(not b.reselect_path() and state==[b.units,b.history,b.turn,b.actor],"applied damage and next turn are irreversible")
	b.start(2,C.player_builds().slice(0,2),1)
	b.units[0].pos=Vector2i(8,0)
	b.units[2].hp=0
	b.path_click(Vector2i(9,0))
	b.commit_path()
	state=[b.units.duplicate(true),b.history.duplicate(),b.result,b.turn]
	_check(b.result=="VICTORY" and not b.reselect_path() and state==[b.units,b.history,b.result,b.turn],"movement victory cannot be rolled back")
	b.start(0,C.player_builds().slice(0,2),1)
	b.path_click(Vector2i(4,4))
	b.commit_path()
	b.start(0,C.player_builds().slice(0,2),1)
	b.mode="CHOICE"
	_check(not b.reselect_path(),"restart clears old same-actor same-turn rollback data")
## REQ-005-S01、REQ-005-S02
func _contrast() -> void:
	var tuning: Script=load("res://game/tuning.gd")
	var scale=tuning.get_script_constant_map().get("SYNC_SIGMA_SCALE",1.0)
	_check(scale>0 and scale<1,"phase contrast narrows the configured curve without raising its peak")
	var u=C.unit("X","PLAYER",Vector2i.ZERO,C.starter_build())
	var factors=[]
	for pair in [[120.0,240.0],[330.0,30.0],[0.0,0.0]]:
		var index=factors.size()
		u.gear_angle=pair[0]
		u.arms_angle=pair[1]
		var wave=[0.0,25.0/72.0,1.0][index]
		var assisted=minf(1.0,0.1+1.9*pow(wave,1.5))
		var inf=0.1+1.9*exp(-pow(1-assisted,2)/(2*pow(0.6*scale,2)))
		var res=0.1+1.9*exp(-pow(1-assisted,2)/(2*pow(0.7*scale,2)))
		_check(is_equal_approx(M.sync(u,1).factor,inf) and is_equal_approx(M.sync(u,2).factor,res),"independently calculated low/middle/high INF and RES")
		var aligned=C.unit("Y","ENEMY",Vector2i.ONE,C.starter_build())
		_check(M.effect(u,aligned,"DAMAGE")==floori(T.BASE_DAMAGE*inf/3.0),"actual attack uses the same contrast")
		_check(M.effect(aligned,u,"DAMAGE")==floori(T.BASE_DAMAGE*2/(1+res)),"actual resistance uses the same contrast")
		_check(M.effect(u,aligned,"HEAL")==floori(T.BASE_HEAL*inf),"actual healing uses the same contrast without RES")
		factors.append([M.sync(u,1).factor,M.sync(u,2).factor])
	var old_low=0.1+1.9*exp(-0.9*0.9/(2*0.6*0.6))
	_check(factors[0][0]<old_low and factors[2]==[2.0,2.0],"low/high difference increases while the original peak stays exact")
	_check(factors[0][0]<factors[1][0] and factors[1][0]<factors[2][0] and factors[0][1]>factors[0][0],"middle stays ordered and RES keeps a wider tolerance")
	u.gear_angle=330.0
	u.arms_angle=30.0
	var previous=M.sync(u,1).factor
	u.arms_angle+=0.001
	_check(absf(M.sync(u,1).factor-previous)<0.001,"no new discontinuity at a neighboring angle")
	var low=0.0
	for luk in [5,80]:
		for key in ["core","gear","arms"]:
			u[key]=[1,10,5,84-luk,luk]
		u.gear_angle=120.0
		u.arms_angle=240.0
		var value=M.sync(u,1).factor
		_check(is_finite(value) and value>0 and value<=2,"valid LUK boundary retains finite positive correction")
		if luk==5:
			low=value
		else:
			_check(value>low,"high LUK still broadens the curve")
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
