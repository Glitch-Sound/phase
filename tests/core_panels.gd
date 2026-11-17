extends SceneTree
const C=preload("res://game/catalog.gd")
const M=preload("res://game/phase_math.gd")
const B=preload("res://game/battle.gd")
const L=preload("res://game/collection.gd")
const V=preload("res://ui/visuals.gd")
const P=preload("res://ui/palette.gd")
var checks=0
var failures=0
func _initialize() -> void:
	_rotation()
	_order()
	_geometry()
	_battle()
	print("CORE PANELS: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
func _unit() -> Dictionary:
	return C.unit("01","PLAYER",Vector2i(3,4),C.default_build())
## REQ-003-S01
func _rotation() -> void:
	var initial=_unit()
	_check(initial.get("core_angle",-1)==0 and initial.get("initial_core_angle",-1)==0,"runtime CORE angle and battle-start baseline exist")
	for row in [["NORMAL",90.0],["RESET",15.0],["CLOCKWISE",120.0],["COUNTERCLOCKWISE",60.0]]:
		var u=_unit()
		u.core_angle=90.0
		u.initial_core_angle=15.0
		var before=u.duplicate(true)
		M.enter_panel(u,row[0])
		_check(u.core_angle==row[1] and u.gear_angle==330.0 and u.arms_angle==30.0,"exact three-ring changes "+row[0])
		for key in ["core_angle","gear_angle","arms_angle"]:
			u.erase(key)
			before.erase(key)
		_check(u==before,"no stats, HP, schedule, baseline or other field changed "+row[0])
	for row in [[1,359.0,0.5],[96,300.0,84.0]]:
		var u=_unit()
		u.core[3]=row[0]
		u.core_angle=row[1]
		M.enter_panel(u,"CLOCKWISE")
		_check(u.core_angle==row[2],"CORE SPD boundary and clockwise wrap "+str(row[0]))
	var u=_unit()
	u.core=[15,15,15,40,15]
	u.gear=[20,20,20,30,10]
	u.arms=[20,20,20,10,30]
	u.core_angle=0
	M.enter_panel(u,"CLOCKWISE")
	_check(u.core_angle==60 and u.gear_angle==315 and u.arms_angle==15,"each ring uses its own SPD")
## REQ-003-S02
func _order() -> void:
	for row in [[["CLOCKWISE","RESET"],10.0],[["RESET","CLOCKWISE"],40.0],[["CLOCKWISE","CLOCKWISE","COUNTERCLOCKWISE"],70.0],[["RESET","RESET","COUNTERCLOCKWISE"],340.0]]:
		var u=_unit()
		u.core_angle=40.0
		u.initial_core_angle=10.0
		for kind in row[0]:
			M.enter_panel(u,kind)
		_check(u.core_angle==row[1] and u.initial_core_angle==10,"ordered cumulative reset "+str(row[0]))
## REQ-003-S01、REQ-033-S01
func _geometry() -> void:
	var u=_unit()
	u.core_angle=30
	_check(M.sector(u,0,1)==Vector2(102,72),"CORE phase reaches shared sector math")
	_check(is_equal_approx(M.sync(u,1).raw,7.0/12.0),"raw three-ring overlap uses CORE angle")
	u.class_name="REVERSE"
	_check(M.sector(u,0,1)==Vector2(318,72),"class order and CORE angle compose")
	u.class_name="STANDARD"
	for key in ["core","gear","arms"]:
		u[key]=[20,10,30,20,20]
	_check(not M.singularity(u),"CORE-only offset breaks exact INF alignment")
	u.gear_angle=30
	u.arms_angle=30
	_check(M.singularity(u),"rotating all equal sectors equally preserves singularity")
	var glyph=V.glyph(50,u,false,P.ring_colors(P.PRESETS.DEFAULT),P.TEXT)
	var curves=V.phase_contours(u,P.PRESETS.DEFAULT.slice(1))
	u.core_angle=60
	var changed=V.glyph(50,u,false,P.ring_colors(P.PRESETS.DEFAULT),P.TEXT)
	_check(glyph.arcs.slice(5)==changed.arcs.slice(5) and glyph.arcs.slice(0,5)!=changed.arcs.slice(0,5),"only CORE glyph arcs change")
	_check(curves!=V.phase_contours(u,P.PRESETS.DEFAULT.slice(1)),"shared circular preview follows CORE phase")
## REQ-010-S01、REQ-010-S02、REQ-003-S03
func _battle() -> void:
	var collection=L.new()
	var snapshot=collection.snapshot()
	var b=B.new()
	b.start(0,[C.default_build(),C.default_build()],12)
	b.units[0].core_angle=40.0
	b.panels={Vector2i(4,4):"CLOCKWISE",Vector2i(5,4):"RESET",Vector2i(5,5):"COUNTERCLOCKWISE"}
	for cell in [Vector2i(4,4),Vector2i(5,4),Vector2i(5,5)]:
		_check(b.path_click(cell),"ordered route accepted")
	var before=b.units.duplicate(true)
	var predicted=b.preview()
	_check(predicted.get("core_angle",-1)==330 and predicted.gear_angle==270 and predicted.arms_angle==90,"ordered full route prediction")
	_check(b.units==before and b.preview()==predicted,"prediction is pure and repeatable")
	b.path_click(Vector2i(5,4))
	_check(b.preview().get("core_angle",-1)==0,"suffix cancellation restores earlier reset prediction")
	b.path_click(Vector2i(3,4))
	_check(b.path.is_empty() and b.preview().core_angle==40 and b.units==before,"start-cell cancellation retains pre-route CORE")
	for cell in [Vector2i(4,4),Vector2i(5,4),Vector2i(5,5)]:
		b.path_click(cell)
	_check(b.commit_path() and b.units[0].get("core_angle",-1)==330 and b.units[0].gear_angle==270 and b.units[0].arms_angle==90,"commit equals prediction")
	_check(b.history[0]=="01 MOVE (5, 5) C330.0 G270.0 A90.0","replay evidence records all three phase angles")
	b.choose_skill(C.DAMAGE)
	b.back()
	_check(b.mode=="CHOICE" and b.units[0].get("core_angle",-1)==330,"BACK retains committed CORE")
	b.wait_turn()
	_check(b.actor==1 and b.units[0].get("core_angle",-1)==330,"angle persists across turn change")
	b.actor=2
	b.mode="MOVE"
	b.units[2].core_angle=200
	b.units[2].initial_core_angle=35
	b.path_click(Vector2i(5,4))
	_check(b.preview().get("core_angle",-1)==35 and b.commit_path() and b.units[2].get("core_angle",-1)==35,"enemy RESET uses that enemy's battle-start baseline")
	b.start(0,[C.default_build(),C.default_build()],12)
	_check(b.units.all(func(unit):return unit.get("core_angle",-1)==0 and unit.get("initial_core_angle",-1)==0),"rematch rebuilds all current angles and reset baselines")
	_check(collection.snapshot()==snapshot and collection.builds.all(func(build):return build.size()==7 and not build.has("core_angle") and not build.has("initial_core_angle")),"save schema and existing builds remain unchanged")
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
