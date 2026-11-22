## 起動時のプロフィールを共通化し、初回抽選をセッションで一度だけ行う。
extends RefCounted
const L=preload("res://game/collection.gd")
const S=preload("res://game/storage.gd")
static var _profiles: Dictionary={}

## プロフィールを開く。pathは保存先、rngは初回抽選専用乱数。戻り値はcollectionとerror。既存保存を読むだけとし、新規だけ抽選して保存し、同セッションでは同じ参照を返す。
static func open_profile(path: String,rng: RandomNumberGenerator) -> Dictionary:
	if _profiles.has(path):return _profiles[path]
	var value=L.new()
	var error=""
	var unlocks=[]
	if S.exists(path):error=value.load_from(path)
	else:
		unlocks=value.unlock_starters(rng)
		error=value.save_to(path)
	var result={"collection":value,"error":error,"unlocks":unlocks}
	_profiles[path]=result
	return result

## 未表示の初回解放を取り出す。pathは起動済み保存キー。戻り値は今回の追加品だけの独立した配列。セッションの未表示状態を一度だけ消費し、保存を書かない。
static func take_unlocks(path: String) -> Array:
	if not _profiles.has(path):return []
	var rows: Array=_profiles[path].unlocks.duplicate(true)
	_profiles[path].unlocks=[]
	return rows
