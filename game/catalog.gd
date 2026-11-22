## 許可されたスキル、初期装備、ステージを定義する。
extends RefCounted
const I=preload("res://game/unit_identity.gd")
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
const FIELD_FAST = "PASSIVE_FIELD_FAST_ADJACENT"
const FIELD_FACTORS = {"SLOW":0.5,"FAST":1.5}
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
	FIELD_FAST:{"type":"PASSIVE","effect":"FAST FIELD","area":"SURROUNDING","field":"FAST","label":"FAST FIELD / SURROUNDING","description":"Surrounding others: equipment rotation x1.5."}
}
const SQUAD_SIZE = 3
const PLAYER_IDS = I.PLAYER_IDS
const ENEMY_IDS = I.ENEMY_IDS
const STARTER_STATS = [[20,20,20,20,20],[20,30,10,20,20],[20,10,30,20,20],[30,10,20,30,10]]

## 新規装備の全配分を返す。戻り値は各値10以上の10刻みで合計100の126配列。呼び出しごとに独立し、副作用なし。
static func equipment_catalog() -> Array:
	var result=[]
	for vit in range(10,61,10):
		for inf in range(10,61,10):
			for res in range(10,61,10):
				for spd in range(10,61,10):
					var luk=100-vit-inf-res-spd
					if luk>=10:result.append([vit,inf,res,spd,luk])
	return result

## 共有変異の全種類を返す。戻り値はNORMALと通常順以外の119配置の独立した配列。副作用なし。
static func mutation_catalog() -> Array:
	var result=["NORMAL"]
	_mutation_orders("","VIRSL",result)
	return result

## CLASSの全配置を返す。戻り値は変異と同じ120配置のコードであり、旧別名を含まず副作用はない。
static func class_catalog() -> Array:
	return mutation_catalog().map(func(value):return M.layout_code(value))

static func _mutation_orders(prefix: String, remaining: String, result: Array) -> void:
	if remaining.is_empty():
		if prefix!="VIRSL":result.append(prefix)
		return
	for letter in remaining:
		_mutation_orders(prefix+letter,remaining.replace(letter,""),result)

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

## 初期PLAYER構成を返す。戻り値はランナー、迎撃役と支援役の独立した3ビルド。
static func player_builds() -> Array:
	var runner=starter_build()
	runner.core=[20,20,15,30,15]
	var interceptor=starter_build()
	interceptor.core=[20,30,15,20,15]
	interceptor.gear=STARTER_STATS[1].duplicate()
	interceptor.arms=STARTER_STATS[1].duplicate()
	var support=starter_build()
	support.core=[20,15,30,20,15]
	support.gear=STARTER_STATS[2].duplicate()
	support.arms=STARTER_STATS[2].duplicate()
	return [runner,interceptor,support]

## 戦闘ユニットを作る。idは内部識別子、campは陣営、posは座標、buildは構成、display_nameは表示専用の入力名。戻り値はHPと角度を初期化した辞書。
static func unit(id: String, camp: String, pos: Vector2i, build: Dictionary,display_name: String="") -> Dictionary:
	var u=build.duplicate(true)
	# 開始角は従来どおり0度であり、戦闘中のリセット基準だけを別に保持する。
	var core_start=0.0
	u.merge({"id":id,"camp":camp,"display_name":I.effective_name(display_name,id,camp),"identicon_version":I.VERSION,"pos":pos,"core_angle":core_start,"initial_core_angle":core_start,"gear_angle":0.0,"arms_angle":0.0,"moved":0,"guard_active":false},true)
	u.max_hp=M.max_hp(u)
	u.hp=u.max_hp
	u.next_time=M.delay(u)
	return u

## ステージ定義を返す。戻り値は目標と説明を持つ2件の独立した辞書。
static func stages() -> Array:
	var result=[
		{"name":"01 / INTERFERENCE","type":"ELIMINATE","summary":"Defeat every enemy.","brief":"ELIMINATE ALL ENEMY UNITS: A B C","hint":""},
		{"name":"02 / SEVERANCE","type":"TARGET","summary":"Keep 01 alive; defeat A.","brief":"DEFEAT A / KEEP 01 ALIVE","hint":"Lose if 01 falls. 02 and 03 can screen the guards."},
	]
	for stage in result:
		stage.spawns=[Vector2i(3,4),Vector2i(3,6),Vector2i(3,2),Vector2i(6,4),Vector2i(6,6),Vector2i(6,2)]
		stage.victory=[{"type":"ELIMINATE","camp":"ENEMY"}]
		stage.defeat=[{"type":"ELIMINATE","camp":"PLAYER"}]
		if stage.type=="TARGET":
			stage.spawns[3]=Vector2i(7,2)
			stage.spawns[4]=Vector2i(6,4)
			stage.spawns[5]=Vector2i(6,6)
			stage.victory.append({"type":"TARGET","camp":"ENEMY","unit":"A"})
			stage.defeat.append({"type":"TARGET","camp":"PLAYER","unit":"01"})
	return result
