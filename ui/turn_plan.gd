## 実戦闘に触れず、着地から行動と対象を予定する。
extends RefCounted
const B=preload("res://game/battle.gd")
const C=preload("res://game/catalog.gd")
var owner
var projected
var phase=""
var target=-1
var original: Array=[]
var route: Array=[]

## 予定の有無を返す。戻り値は独立した予測が開いているか。副作用なし。
func active() -> bool:return projected!=null

## 経路から予定を開く。battleは原本。戻り値は開始可否。原本を変更しない。
func begin(battle: RefCounted) -> bool:
	reset()
	if battle.mode!="MOVE" or battle.actor<0 or not battle.result.is_empty():return false
	if battle.path.is_empty() and not battle.trapped():return false
	owner=battle;route=battle.path.duplicate();original=_state(battle)
	projected=B.new()
	for key in ["units","panels","stage","history","last_effect"]:projected.set(key,battle.get(key).duplicate(true))
	projected.actor=battle.actor;projected.turn=battle.turn;projected.mode="MOVE"
	for cell in route:
		if not projected.path_click(cell):reset();return false
	if not route.is_empty():projected.commit_path()
	else:projected.mode="CHOICE"
	phase="READY" if not projected.result.is_empty() else "CHOICE"
	return true

## 行動を予定する。skillは装備ID。戻り値は合法な対象があるか。原本を変更しない。
func choose(skill: String) -> bool:
	if not active() or phase!="CHOICE":return false
	var valid=false
	for i in range(projected.units.size()):
		if projected.valid_target(projected.actor,i,skill):valid=true;break
	if not valid or not projected.choose_skill(skill):return false
	phase="TARGET"
	if C.SKILLS[skill].effect=="GUARD":return select(projected.actor)
	return true

## WAITを予定する。戻り値は選択可否。原本を変更しない。
func wait() -> bool:
	if not active() or phase!="CHOICE":return false
	projected.selected_skill="";target=-1;phase="READY"
	return true

## 対象を予定する。indexは番号。戻り値は合法か。原本を変更しない。
func select(index: int) -> bool:
	if not active() or phase!="TARGET" or not projected.valid_target(projected.actor,index,projected.selected_skill):return false
	target=index;phase="READY"
	return true

## 一段戻す。戻り値なし。予定だけを戻し、経路編集では原本の経路を保持する。
func back() -> void:
	if not active():return
	if phase=="READY" and projected.result.is_empty() and target>=0 and target!=projected.actor:
		target=-1;phase="TARGET"
	elif phase in ["TARGET","READY"] and projected.result.is_empty():
		projected.back();projected.selected_skill="";target=-1;phase="CHOICE"
	else:reset()

## 最終確定する。battleは原本。戻り値は実行する経路と行動、拒否なら空。原本の移動だけを一度確定し、技は呼出側が着地時に実行する。
func commit(battle: RefCounted) -> Dictionary:
	if not active() or phase!="READY" or battle!=owner or _state(battle)!=original:return {}
	var skill: String=projected.selected_skill
	if not skill.is_empty() and not projected.valid_target(projected.actor,target,skill):return {}
	var command={"path":route.duplicate(),"skill":skill,"target":target}
	if not route.is_empty():
		if not battle.commit_path():return {}
	elif not battle.trapped():return {}
	reset()
	return command

## 予定を破棄する。戻り値なし。原本と保存を変更しない。
func reset() -> void:
	owner=null;projected=null;phase="";target=-1;original=[];route=[]

func _state(battle) -> Array:
	return [battle.units.duplicate(true),battle.history.duplicate(),battle.turn,battle.actor,battle.mode,battle.path.duplicate(),battle.panels.duplicate(true),battle.result,battle.last_effect.duplicate(true)]
