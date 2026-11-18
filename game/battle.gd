## 両陣営に共通する経路、手番、対象、勝敗を管理する。
extends RefCounted
const M = preload("res://game/phase_math.gd")
const C = preload("res://game/catalog.gd")
const PANEL_LAYOUT = preload("res://game/panel_layout.gd")
const T = preload("res://game/tuning.gd")
const F = preload("res://game/rotation_field.gd")
const DIRS = [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]
const TIME_EPS := 0.00000001
var units: Array=[]
var panels: Dictionary={}
var panel_seed: int=0
var path: Array=[]
var actor := 0
var mode := "BUILD"
var selected_skill := ""
var stage: Dictionary={}
var result := ""
var turn := 1
var last_effect: Dictionary={}
var history: Array=[]
var _movement_undo: Dictionary={}

## 戦闘を初期化する。stage_indexは0から3、buildsはPLAYER2体の構成、layout_seedは配置の再現用整数。既存戦闘を置換する。
func start(stage_index: int, builds: Array, layout_seed: int=0) -> void:
	stage=C.stages()[stage_index].duplicate(true)
	panel_seed=layout_seed
	panels=PANEL_LAYOUT.generate(stage,panel_seed)
	units=[C.unit("01","PLAYER",stage.spawns[0],builds[0]),C.unit("02","PLAYER",stage.spawns[1],builds[1]),C.unit("A","ENEMY",stage.spawns[2],C.starter_build()),C.unit("B","ENEMY",stage.spawns[3],C.starter_build())]
	path=[]
	result=""
	turn=1
	history=[]
	last_effect={}
	next_actor()

## 生存占有者を返す。cellは座標。戻り値はユニット番号、空きなら-1。
func at(cell: Vector2i) -> int:
	for i in range(units.size()):
		if units[i].hp>0 and units[i].pos==cell:
			return i
	return -1

## 移動力を返す。uはユニット。戻り値は受動効果を含むセル数。
func movement(u: Dictionary) -> int:
	return T.BASE_MOVE+(1 if u.skills.has(C.MOVE) else 0)

## 次のユニットを選ぶ。固定順を維持し、経路と選択スキルを初期化する。
func next_actor() -> void:
	_movement_undo={}
	var best=-1
	for i in range(units.size()):
		if units[i].hp>0 and (best<0 or units[i].next_time<units[best].next_time-TIME_EPS):
			best=i
	actor=best
	mode="MOVE"
	path=[]
	selected_skill=""
	if actor>=0:
		units[actor].moved=0

## 将来の手番を返す。countは表示件数。戻り値は番号と時刻の配列で同着は固定順。
func timeline(count: int=7) -> Array:
	var times=[]
	for u in units:
		times.append(u.next_time if u.hp>0 else INF)
	var result_rows=[]
	for k in range(count):
		var best=0
		for i in range(1,times.size()):
			if times[i]<times[best]-TIME_EPS:
				best=i
		if is_inf(times[best]):
			break
		result_rows.append({"index":best,"time":times[best]})
		times[best]+=M.delay(units[best])
	return result_rows

## 経路クリックを処理する。cellは選択座標。戻り値は経路が有効に更新されたか。
func path_click(cell: Vector2i) -> bool:
	if mode!="MOVE" or actor<0:
		return false
	if cell==units[actor].pos:
		path=[]
		return true
	if path.has(cell):
		path=path.slice(0,path.find(cell)+1)
		return true
	var end: Vector2i=units[actor].pos if path.is_empty() else path.back()
	if path.size()>=movement(units[actor]) or not _inside(cell) or at(cell)>=0 or _distance(end,cell)!=1:
		return false
	path.append(cell)
	return true

## 経路後の予測を返す。戻り値は原本に影響しないユニットの複製。
func preview() -> Dictionary:
	var u: Dictionary=units[actor].duplicate(true)
	if mode=="MOVE":
		for cell in path:
			enter_cell(u,cell,panels.get(cell,"NORMAL"),units)
	return u

## 経路を確定する。戻り値は成功可否。確定した位置と位相を保持し、移動目標を判定する。
func commit_path() -> bool:
	if mode!="MOVE" or path.is_empty():
		return false
	_movement_undo={"actor":actor,"turn":turn,"unit":units[actor].duplicate(true),"path":path.duplicate(),"history_size":history.size()}
	var u=preview()
	u.moved=path.size()
	units[actor]=u
	history.append("%s MOVE %s C%.1f G%.1f A%.1f" % [u.id,u.pos,u.core_angle,u.gear_angle,u.arms_angle])
	path=[]
	mode="CHOICE"
	check_result("MOVE")
	if not result.is_empty():
		_movement_undo={}
	return true

## 確定移動を選び直す。戻り値は同じ手番の行動選択から復元できたか。位置、角度と移動履歴を戻し、経路を予測用に保持する。実行済みの行動と終局は変更しない。
func reselect_path() -> bool:
	if mode!="CHOICE" or not result.is_empty() or _movement_undo.is_empty() or actor!=_movement_undo.actor or turn!=_movement_undo.turn:
		return false
	units[actor]=_movement_undo.unit.duplicate(true)
	path=_movement_undo.path.duplicate()
	history.resize(_movement_undo.history_size)
	selected_skill=""
	mode="MOVE"
	_movement_undo={}
	return true

## 移動不能を返す。戻り値は上下左右に空きセルがないか。
func trapped() -> bool:
	for d in DIRS:
		var p: Vector2i=units[actor].pos+d
		if _inside(p) and at(p)<0:
			return false
	return true

## WAITを実行する。戻り値は成功可否。無移動は閉塞時だけ許可する。
func wait_turn() -> bool:
	if mode=="CHOICE" or (mode=="MOVE" and trapped()):
		history.append(units[actor].id+" WAIT")
		_end_turn()
		return true
	return false

## ACTIVEを選ぶ。skillは保有するID。戻り値は成功可否、成功時は対象選択へ移る。
func choose_skill(skill: String) -> bool:
	if mode!="CHOICE" or not units[actor].skills.has(skill) or not C.SKILLS.has(skill) or C.SKILLS[skill].type!="ACTIVE":
		return false
	selected_skill=skill
	mode="TARGET"
	return true

## 対象選択を戻す。位置と位相を維持して行動選択へ戻る。
func back() -> void:
	if mode=="TARGET":
		mode="CHOICE"
		selected_skill=""

## 対象の適否を返す。sourceとtargetは番号、skillはID。戻り値は指定位置、生存、陣営の条件を満たすか。
func valid_target(source: int, target: int, skill: String) -> bool:
	if source<0 or source>=units.size() or target<0 or target>=units.size():
		return false
	var s: Dictionary=units[source]
	var t: Dictionary=units[target]
	if not _inside(s.pos) or not _inside(t.pos) or not C.target_matches(skill,s,t):
		return false
	if C.SKILLS[skill].effect=="PUSH":
		var landing: Vector2i=t.pos+(t.pos-s.pos)
		return _inside(landing) and at(landing)<0
	return true

## 1歩の進入を適用する。uは変更するユニット、cellは到着セル、panelは効果名、worldは全員の現在位置。装備した受動と周囲に従う位相と位置を変更する。戻り値はない。
static func enter_cell(u: Dictionary, cell: Vector2i, panel: String, world: Array=[]) -> void:
	M.enter_panel(u,panel,u.skills.has(C.IGNORE_PANEL),F.resolve(u,cell,world).factor)
	u.pos=cell

## 位置操作と防御を予測する。targetは対象番号。戻り値はunits、moved、kind、targetを含む独立した辞書、無効または他の作用なら空。戦闘を変更しない。
func action_preview(target: int) -> Dictionary:
	if mode!="TARGET" or not valid_target(actor,target,selected_skill):
		return {}
	var kind: String=C.SKILLS[selected_skill].effect
	if kind not in ["SWAP","PUSH","GUARD"]:
		return {}
	var projected=units.duplicate(true)
	var moved=_apply_utility(projected,actor,target,kind)
	return {"units":projected,"moved":moved,"kind":kind,"target":target}

func _apply_utility(target_units: Array, source: int, target: int, kind: String) -> Array:
	var moved=[]
	var origin: Vector2i=target_units[source].pos
	var destination: Vector2i=target_units[target].pos
	if kind=="SWAP":
		target_units[source].pos=destination
		target_units[target].pos=origin
		moved=[source,target]
	elif kind=="PUSH":
		target_units[target].pos=destination+(destination-origin)
		moved=[target]
	elif kind=="GUARD":
		target_units[source].guard_active=true
	# 全位置を先に決め、どちらから回転しても同じ周囲を見る。
	for index in moved:
		var cell: Vector2i=target_units[index].pos
		enter_cell(target_units[index],cell,panels.get(cell,"NORMAL"),target_units)
	return moved

## 効果を実行する。targetは番号。戻り値は成功可否。位置、角度、防御またはHPと手番、勝敗を更新する。
func act(target: int) -> bool:
	if mode!="TARGET" or not valid_target(actor,target,selected_skill):
		return false
	var kind: String=C.SKILLS[selected_skill].effect
	if kind in ["SWAP","PUSH","GUARD"]:
		var moved=_apply_utility(units,actor,target,kind)
		last_effect={"target":target,"kind":kind,"amount":0,"actual":0.0,"dead":false,"singularity":false}
		history.append("%s %s %s %s" % [units[actor].id,kind,units[target].id,units[target].pos])
		if not moved.is_empty():
			check_result("MOVE",moved)
	else:
		var amount=M.effect(units[actor],units[target],kind)
		var old_hp: float=units[target].hp
		var guarded=kind=="DAMAGE" and units[target].get("guard_active",false)
		units[target].hp=maxf(0,old_hp-amount) if kind=="DAMAGE" else minf(units[target].max_hp,old_hp+amount)
		if guarded:
			units[target].guard_active=false
		last_effect={"target":target,"kind":kind,"amount":amount,"actual":absf(old_hp-units[target].hp),"dead":units[target].hp<=0,"singularity":M.singularity(units[actor]),"guard_used":guarded}
		history.append("%s %s %s %d (HP %.2f)" % [units[actor].id,kind,units[target].id,amount,units[target].hp])
		if units[target].hp<=0:
			check_result("DEATH")
	if result.is_empty():
		_end_turn()
	return true

## 目標を判定する。eventはDEATH、MOVE、END、moved_indicesはMOVEで動いた番号の配列で空なら行動者。成立するとRESULTへ移る。
func check_result(event: String, moved_indices: Array=[]) -> void:
	if not result.is_empty():
		return
	for entry in [["defeat","DEFEAT"],["victory","VICTORY"]]:
		for condition in stage[entry[0]]:
			if _condition_met(condition,event,moved_indices):
				result=entry[1]
				mode="RESULT"
				return
	if not result.is_empty():
		mode="RESULT"

func _condition_met(condition: Dictionary, event: String, moved_indices: Array=[]) -> bool:
	var kind: String=condition.type
	if (kind in ["ELIMINATE","TARGET"] and event!="DEATH") or (kind=="REACH" and event!="MOVE") or (kind=="OCCUPY" and event!="END"):
		return false
	if kind=="ELIMINATE":
		var found=false
		for u in units:
			if u.camp==condition.camp:
				found=true
				if u.hp>0:
					return false
		return found
	if kind=="TARGET":
		for u in units:
			if _matches_condition(u,condition):
				return u.hp<=0
	if kind=="REACH":
		for index in moved_indices if not moved_indices.is_empty() else [actor]:
			var u: Dictionary=units[index]
			if u.hp>0 and _matches_condition(u,condition) and u.pos==condition.cell:
				return true
		return false
	if kind=="OCCUPY":
		var occupant=at(condition.cell)
		return occupant>=0 and _matches_condition(units[occupant],condition)
	return false

static func _matches_condition(u: Dictionary, condition: Dictionary) -> bool:
	return u.camp==condition.camp and (not condition.has("unit") or u.id==condition.unit)

func _end_turn() -> void:
	_movement_undo={}
	check_result("END")
	if not result.is_empty():
		return
	units[actor].next_time+=M.delay(units[actor])
	turn+=1
	next_actor()

static func _inside(cell: Vector2i) -> bool:
	return cell.x>=0 and cell.y>=0 and cell.x<10 and cell.y<10

static func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x-b.x)+absi(a.y-b.y)
