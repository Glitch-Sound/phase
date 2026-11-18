## 許可されたスキル、初期装備、ステージを定義する。
extends RefCounted
const M = preload("res://game/phase_math.gd")
const DAMAGE = "ACTIVE_DAMAGE_ADJACENT"
const HEAL = "ACTIVE_HEAL_ADJACENT"
const MOVE = "PASSIVE_MOVE_PLUS_ONE_SELF"
const DAMAGE_DIAGONAL = "ACTIVE_DAMAGE_DIAGONAL_ONE"
const HEAL_DIAGONAL = "ACTIVE_HEAL_DIAGONAL_ONE"
const DAMAGE_ORTHOGONAL_TWO = "ACTIVE_DAMAGE_ORTHOGONAL_TWO"
const HEAL_ORTHOGONAL_TWO = "ACTIVE_HEAL_ORTHOGONAL_TWO"
const DAMAGE_DIAGONAL_TWO = "ACTIVE_DAMAGE_DIAGONAL_TWO"
const HEAL_DIAGONAL_TWO = "ACTIVE_HEAL_DIAGONAL_TWO"
const SWAP = "ACTIVE_SWAP_ADJACENT"
const PUSH = "ACTIVE_PUSH_ADJACENT"
const GUARD = "ACTIVE_GUARD_SELF"
const IGNORE_PANEL = "PASSIVE_IGNORE_PANEL_SELF"
const FIELD_SLOW = "PASSIVE_FIELD_SLOW_ADJACENT"
const FIELD_STOP = "PASSIVE_FIELD_STOP_ADJACENT"
const FIELD_FAST = "PASSIVE_FIELD_FAST_ADJACENT"
const FIELD_FACTORS = {"SLOW":0.5,"STOP":0.0,"FAST":1.5}
# 周囲用だけの8方向。旧保存のADJACENT付きIDは保持し、通常スキルの上下左右とは分ける。
const FIELD_OFFSETS = [Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1),Vector2i(-1,0),Vector2i(1,0),Vector2i(-1,1),Vector2i(0,1),Vector2i(1,1)]
const TARGET_PATTERNS = {
	"SELF":[Vector2i.ZERO],
	"ADJACENT":[Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)],
	"DIAGONAL_ONE":[Vector2i(-1,-1),Vector2i(1,-1),Vector2i(1,1),Vector2i(-1,1)],
	"ORTHOGONAL_TWO":[Vector2i(0,-2),Vector2i(2,0),Vector2i(0,2),Vector2i(-2,0)],
	"DIAGONAL_TWO":[Vector2i(-2,-2),Vector2i(2,-2),Vector2i(2,2),Vector2i(-2,2)]
}
const SKILLS = {
	DAMAGE:{"type":"ACTIVE","effect":"DAMAGE","area":"ADJACENT","label":"DAMAGE / ADJACENT","description":"Damage one adjacent enemy."},
	HEAL:{"type":"ACTIVE","effect":"HEAL","area":"ADJACENT","label":"HEAL / ADJACENT","description":"Heal one adjacent wounded ally."},
	MOVE:{"type":"PASSIVE","effect":"MOVE +1","area":"SELF","label":"MOVE +1 / SELF","description":"Adds 1 cell to movement."},
	DAMAGE_DIAGONAL:{"type":"ACTIVE","effect":"DAMAGE","area":"DIAGONAL_ONE","label":"DAMAGE / DIAGONAL 1","description":"Damage one enemy 1 diagonal cell away."},
	HEAL_DIAGONAL:{"type":"ACTIVE","effect":"HEAL","area":"DIAGONAL_ONE","label":"HEAL / DIAGONAL 1","description":"Heal one wounded ally 1 diagonal cell away."},
	DAMAGE_ORTHOGONAL_TWO:{"type":"ACTIVE","effect":"DAMAGE","area":"ORTHOGONAL_TWO","label":"DAMAGE / ORTHO 2","description":"Damage one enemy exactly 2 orthogonal cells away."},
	HEAL_ORTHOGONAL_TWO:{"type":"ACTIVE","effect":"HEAL","area":"ORTHOGONAL_TWO","label":"HEAL / ORTHO 2","description":"Heal one wounded ally exactly 2 orthogonal cells away."},
	DAMAGE_DIAGONAL_TWO:{"type":"ACTIVE","effect":"DAMAGE","area":"DIAGONAL_TWO","label":"DAMAGE / DIAGONAL 2","description":"Damage one enemy exactly 2 diagonal cells away."},
	HEAL_DIAGONAL_TWO:{"type":"ACTIVE","effect":"HEAL","area":"DIAGONAL_TWO","label":"HEAL / DIAGONAL 2","description":"Heal one wounded ally exactly 2 diagonal cells away."},
	SWAP:{"type":"ACTIVE","effect":"SWAP","area":"ADJACENT","label":"SWAP / ADJACENT","description":"Exchange positions with one adjacent ally."},
	PUSH:{"type":"ACTIVE","effect":"PUSH","area":"ADJACENT","label":"PUSH / ADJACENT","description":"Push one enemy 1 cell outward. No damage."},
	GUARD:{"type":"ACTIVE","effect":"GUARD","area":"SELF","label":"GUARD / SELF","description":"Reduce the next attack once. Cannot stack."},
	IGNORE_PANEL:{"type":"PASSIVE","effect":"IGNORE PANEL","area":"SELF","label":"PANEL IGNORE / SELF","description":"Ignore special CORE effects. Equipment still turns."},
	FIELD_SLOW:{"type":"PASSIVE","effect":"SLOW FIELD","area":"SURROUNDING","field":"SLOW","label":"SLOW FIELD / SURROUNDING","description":"Surrounding others: equipment rotation x0.5."},
	FIELD_STOP:{"type":"PASSIVE","effect":"STOP FIELD","area":"SURROUNDING","field":"STOP","label":"STOP FIELD / SURROUNDING","description":"Surrounding others: equipment rotation x0."},
	FIELD_FAST:{"type":"PASSIVE","effect":"FAST FIELD","area":"SURROUNDING","field":"FAST","label":"FAST FIELD / SURROUNDING","description":"Surrounding others: equipment rotation x1.5."}
}
const STARTER_STATS = [[20,20,20,20,20],[20,30,15,20,15],[20,10,30,20,20],[25,15,20,30,10]]

## 対象位置を返す。skillはスキルID。戻り値は指定位置の座標差の独立した配列であり、不明または受動なら空。
static func target_offsets(skill: String) -> Array:
	if SKILLS.get(skill,{}).get("type","")!="ACTIVE":
		return []
	var area=SKILLS.get(skill,{}).get("area","")
	return TARGET_PATTERNS.get(area,[]).duplicate()

## 単体対象の条件を返す。skillはID、sourceとtargetは位置、陣営、HPを持つユニット。戻り値は作用と位置の適否であり、装備と操作状態は呼び出し側で制限する。
static func target_matches(skill: String, source: Dictionary, target: Dictionary) -> bool:
	if SKILLS.get(skill,{}).get("type","")!="ACTIVE" or source.hp<=0 or target.hp<=0 or not target_offsets(skill).has(target.pos-source.pos):
		return false
	match SKILLS[skill].effect:
		"DAMAGE","PUSH":
			return source.camp!=target.camp
		"HEAL":
			return source.camp==target.camp and target.hp<target.max_hp
		"SWAP":
			return source.camp==target.camp
		"GUARD":
			return source.id==target.id and source.camp==target.camp and not source.get("guard_active",false)
	return false

## 型番を返す。kindはARMSかGEAR、statsは配分、mutationはNORMALか配置文字列。戻り値は型番。
static func serial(kind: String, stats: Array, mutation: String="NORMAL") -> String:
	var result=kind+"-"
	for value in stats:
		result+="%02X" % int(value)
	return result if mutation=="NORMAL" else result+"-M-"+mutation

## 従来3種を持つ検査用ビルドを返す。戻り値は編集可能な独立した辞書。
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

## 戦闘ユニットを作る。idは内部識別子、campは陣営、posは座標、buildは構成。戻り値はHPと角度を初期化した辞書。
static func unit(id: String, camp: String, pos: Vector2i, build: Dictionary) -> Dictionary:
	var u=build.duplicate(true)
	# 開始角は従来どおり0度であり、戦闘中のリセット基準だけを別に保持する。
	var core_start=0.0
	u.merge({"id":id,"camp":camp,"pos":pos,"core_angle":core_start,"initial_core_angle":core_start,"gear_angle":0.0,"arms_angle":0.0,"moved":0,"guard_active":false},true)
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
			stage.victory=[{"type":"REACH","camp":"PLAYER","unit":"01","cell":stage.goal}]
			stage.defeat.append({"type":"TARGET","camp":"PLAYER","unit":"01"})
			stage.defeat.append({"type":"REACH","camp":"ENEMY","unit":"B","cell":stage.enemy_goal})
		elif stage.type=="OCCUPY":
			stage.spawns[2]=stage.goal
			stage.enemy_goal=Vector2i(0,9)
			stage.victory=[{"type":"OCCUPY","camp":"PLAYER","cell":stage.goal}]
			stage.defeat.append({"type":"OCCUPY","camp":"ENEMY","cell":stage.enemy_goal})
	return result
