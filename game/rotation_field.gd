## 現在位置と装備だけから周囲回転の範囲と倍率を求める。
extends RefCounted
const C=preload("res://game/catalog.gd")

## 装備した種類を返す。uはユニット。戻り値は種類名の重複しない配列。副作用なし。
static func types(u: Dictionary) -> Array:
	var found=[]
	for skill in u.skills:
		var kind=C.SKILLS.get(skill,{}).get("field","")
		if not kind.is_empty() and not found.has(kind):found.append(kind)
	return found

## 生存する発生源の有無を返す。worldは全ユニット。戻り値は周囲効果を持つ生存者がいるか。副作用なし。
static func has_fields(world: Array) -> bool:
	return world.any(func(u):return u.hp>0 and not types(u).is_empty())

## 着地の倍率を返す。receiverは受け手、cellは着地、worldは全員の現在位置。戻り値はfactor、kinds、sourcesを持つ辞書。周囲8マスから本人と撃破済みを除外し、原本は変更しない。
static func resolve(receiver: Dictionary, cell: Vector2i, world: Array) -> Dictionary:
	if not Rect2i(0,0,10,10).has_point(cell):return {"factor":1.0,"kinds":[],"sources":[]}
	var kinds=[]
	var sources=[]
	for source in world:
		if source.hp<=0 or (source.id==receiver.id and source.camp==receiver.camp) or not C.FIELD_OFFSETS.has(cell-source.pos):
			continue
		for kind in types(source):
			if not kinds.has(kind):kinds.append(kind)
			sources.append({"id":source.id,"camp":source.camp,"kind":kind})
	kinds.sort()
	var factor=1.0
	if kinds.has("STOP"):factor=C.FIELD_FACTORS.STOP
	elif kinds.has("SLOW") and kinds.has("FAST"):factor=1.0
	elif kinds.has("SLOW"):factor=C.FIELD_FACTORS.SLOW
	elif kinds.has("FAST"):factor=C.FIELD_FACTORS.FAST
	return {"factor":factor,"kinds":kinds,"sources":sources}

## 盤内の範囲を返す。worldは全ユニット。戻り値はセルをキーとしてその場の倍率と作用元を持つ辞書。重複セルを1件にし、原本は変更しない。
static func coverage(world: Array) -> Dictionary:
	var cells={}
	for source in world:
		if source.hp<=0 or types(source).is_empty():continue
		for offset in C.FIELD_OFFSETS:
			var cell: Vector2i=source.pos+offset
			if Rect2i(0,0,10,10).has_point(cell):cells[cell]=true
	var result={}
	for cell in cells:
		var receiver={"id":"","camp":""}
		for u in world:
			if u.hp>0 and u.pos==cell:receiver=u;break
		result[cell]=resolve(receiver,cell,world)
	return result
