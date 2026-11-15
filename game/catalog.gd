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

## 全スキルを持つ検査用ビルドを返す。戻り値は編集可能な独立した辞書。
static func default_build() -> Dictionary:
	return {"class_name":"STANDARD","core":[20,20,20,20,20],"gear":[20,20,20,20,20],"arms":[20,20,20,20,20],"gear_mutation":"NORMAL","arms_mutation":"NORMAL","skills":[DAMAGE,HEAL,MOVE]}

## 新規開始用の構成を返す。戻り値はDAMAGEとHEALを持ち、MOVEを収集に残した独立したビルド。
static func starter_build() -> Dictionary:
	var build=default_build()
	build.skills=[DAMAGE,HEAL]
	return build

## 初期PLAYER構成を返す。戻り値はランナーと迎撃役の独立した2ビルド。
static func player_builds() -> Array:
	var runner=starter_build()
	runner.core=[20,20,15,30,15]
	var interceptor=starter_build()
	interceptor.core=[20,30,15,20,15]
	interceptor.gear=STARTER_STATS[1].duplicate()
	interceptor.arms=STARTER_STATS[1].duplicate()
	return [runner,interceptor]

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
		{"name":"02 / SEVERANCE","type":"TARGET","goal":Vector2i(-1,-1),"brief":"DEFEAT A / KEEP 01 ALIVE","hint":"Lose if 01 falls. 02 can screen the enemy guard."},
		{"name":"03 / BREACH","type":"REACH","goal":Vector2i(9,0),"brief":"01 REACH (9,0) / KEEP 01 ALIVE / STOP B (0,9)","hint":"Lose if 01 falls. A guards the exit; 02 can intercept B."},
		{"name":"04 / ANCHOR","type":"OCCUPY","goal":Vector2i(8,0),"brief":"PLAYER HOLD (8,0) / DENY ENEMY (0,9)","hint":"Occupation resolves at turn end. Moving every turn opens gaps."}
	]
	for stage in result:
		stage.spawns=[Vector2i(3,4),Vector2i(3,6),Vector2i(6,4),Vector2i(6,6)]
		stage.enemy_goal=Vector2i(-1,-1)
		stage.panel_overrides={}
		stage.victory=[{"type":"ELIMINATE","camp":"ENEMY"}]
		stage.defeat=[{"type":"ELIMINATE","camp":"PLAYER"}]
		if stage.type=="TARGET":
			stage.spawns[2]=Vector2i(7,2)
			stage.spawns[3]=Vector2i(6,4)
			stage.victory.append({"type":"TARGET","camp":"ENEMY","unit":"A"})
			stage.defeat.append({"type":"TARGET","camp":"PLAYER","unit":"01"})
		elif stage.type=="REACH":
			stage.spawns[2]=stage.goal
			stage.enemy_goal=Vector2i(0,9)
			stage.panel_overrides={Vector2i(8,0):"LOCK",Vector2i(8,1):"REVERSE",Vector2i(9,1):"SHIFT",Vector2i(3,7):"REVERSE",Vector2i(2,8):"LOCK",Vector2i(1,8):"SHIFT"}
			stage.victory=[{"type":"REACH","camp":"PLAYER","unit":"01","cell":stage.goal}]
			stage.defeat.append({"type":"TARGET","camp":"PLAYER","unit":"01"})
			stage.defeat.append({"type":"REACH","camp":"ENEMY","unit":"B","cell":stage.enemy_goal})
		elif stage.type=="OCCUPY":
			stage.spawns[2]=stage.goal
			stage.enemy_goal=Vector2i(0,9)
			stage.panel_overrides={Vector2i(7,0):"LOCK",Vector2i(8,1):"REVERSE",Vector2i(9,0):"SHIFT",Vector2i(3,7):"SHIFT",Vector2i(2,8):"REVERSE",Vector2i(1,8):"LOCK"}
			stage.victory=[{"type":"OCCUPY","camp":"PLAYER","cell":stage.goal}]
			stage.defeat.append({"type":"OCCUPY","camp":"ENEMY","cell":stage.enemy_goal})
	return result

## 特殊パネルを返す。戻り値は座標から種類への辞書。
static func panels() -> Dictionary:
	return {Vector2i(4,3):"SHIFT",Vector2i(4,4):"LOCK",Vector2i(4,5):"REVERSE",Vector2i(5,3):"REVERSE",Vector2i(5,5):"SHIFT",Vector2i(5,6):"LOCK",Vector2i(2,5):"SHIFT",Vector2i(7,5):"REVERSE",Vector2i(4,7):"LOCK",Vector2i(5,2):"SHIFT"}
