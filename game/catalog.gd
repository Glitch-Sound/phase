## 許可されたスキル、初期装備、ステージを定義する。
extends RefCounted
const M = preload("res://game/phase_math.gd")
const DAMAGE = "ACTIVE_DAMAGE_ADJACENT"
const HEAL = "ACTIVE_HEAL_ADJACENT"
const MOVE = "PASSIVE_MOVE_PLUS_ONE_SELF"
const SKILLS = {
	DAMAGE:{"type":"ACTIVE","effect":"DAMAGE","area":"ADJACENT","label":"DAMAGE / ADJACENT"},
	HEAL:{"type":"ACTIVE","effect":"HEAL","area":"ADJACENT","label":"HEAL / ADJACENT"},
	MOVE:{"type":"PASSIVE","effect":"MOVE +1","area":"SELF","label":"MOVE +1 / SELF"}
}
const STARTER_STATS = [[20,20,20,20,20],[20,30,15,20,15],[20,10,30,20,20],[25,15,20,30,10]]

## 型番を返す。kindはARMSかGEAR、statsは配分、mutationはNORMALか配置文字列。戻り値は型番。
static func serial(kind: String, stats: Array, mutation: String="NORMAL") -> String:
	var result=kind+"-"
	for value in stats:
		result+="%02X" % int(value)
	return result if mutation=="NORMAL" else result+"-M-"+mutation

## 初期ビルドを返す。戻り値は編集可能な独立した辞書。
static func default_build() -> Dictionary:
	return {"class_name":"STANDARD","core":[20,20,20,20,20],"gear":[20,20,20,20,20],"arms":[20,20,20,20,20],"gear_mutation":"NORMAL","arms_mutation":"NORMAL","skills":[DAMAGE,HEAL,MOVE]}

## 戦闘ユニットを作る。idは表示名、campは陣営、posは座標、buildは構成。戻り値はHPと角度を初期化した辞書。
static func unit(id: String, camp: String, pos: Vector2i, build: Dictionary) -> Dictionary:
	var u=build.duplicate(true)
	u.merge({"id":id,"camp":camp,"pos":pos,"gear_angle":0.0,"arms_angle":0.0,"moved":0},true)
	u.max_hp=M.max_hp(u)
	u.hp=u.max_hp
	u.next_time=M.delay(u)
	return u

## ステージ定義を返す。戻り値は目標と説明を持つ4件の独立した辞書。
static func stages() -> Array:
	var result=[
		{"name":"01 / INTERFERENCE","type":"ELIMINATE","goal":Vector2i(-1,-1),"brief":"ELIMINATE ALL ENEMY UNITS","hint":"Compare routes. Both sides are under your control."},
		{"name":"02 / SEVERANCE","type":"TARGET","goal":Vector2i(-1,-1),"brief":"DEFEAT ENEMY A","hint":"A is the target. B does not need to be defeated."},
		{"name":"03 / BREACH","type":"REACH","goal":Vector2i(5,4),"brief":"UNIT 01 MUST REACH (5, 4)","hint":"Only the confirmed endpoint counts. Passing through does not."},
		{"name":"04 / ANCHOR","type":"OCCUPY","goal":Vector2i(5,5),"brief":"END A PLAYER TURN ON (5, 5)","hint":"Occupation resolves after WAIT or an action, not on arrival."}
	]
	for stage in result:
		stage.victory=[{"type":"ELIMINATE","camp":"ENEMY"}]
		stage.defeat=[{"type":"ELIMINATE","camp":"PLAYER"}]
		if stage.type=="TARGET":
			stage.victory.append({"type":"TARGET","camp":"ENEMY","unit":"A"})
		elif stage.type=="REACH":
			stage.victory.append({"type":"REACH","camp":"PLAYER","unit":"01","cell":stage.goal})
		elif stage.type=="OCCUPY":
			stage.victory.append({"type":"OCCUPY","camp":"PLAYER","cell":stage.goal})
	return result

## 特殊パネルを返す。戻り値は座標から種類への辞書。
static func panels() -> Dictionary:
	return {Vector2i(4,3):"SHIFT",Vector2i(4,4):"LOCK",Vector2i(4,5):"REVERSE",Vector2i(5,3):"REVERSE",Vector2i(5,5):"SHIFT",Vector2i(5,6):"LOCK",Vector2i(2,5):"SHIFT",Vector2i(7,5):"REVERSE",Vector2i(4,7):"LOCK",Vector2i(5,2):"SHIFT"}
