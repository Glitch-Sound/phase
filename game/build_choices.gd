## 構成選択の候補、可否と原本から独立したプレビューを提供する。
extends RefCounted
const C=preload("res://game/catalog.gd")
const M=preload("res://game/phase_math.gd")
const STATUS=["VIT","INF","RES","SPD","LUK"]

## 現在値を返す。collectionは所持品、indexは編集番号、kindは選択種、slotはスキル枠。戻り値は候補ID。副作用なし。
static func current(collection: RefCounted,index: int,kind: String,slot: int=0) -> String:
	var b: Dictionary=collection.builds[index]
	if kind in ["arms","gear"]:return C.serial(kind.to_upper(),b[kind])
	if kind=="skill":return b.skills[slot] if slot<b.skills.size() else "NONE"
	if kind=="operation":return str(collection.stage_index)
	if kind=="class_name":return M.layout_code(b.class_name)
	return str(b.get(kind,""))

## 候補を返す。collectionは開放状態、indexは編集番号、kindは選択種、slotはスキル枠。戻り値はIDと内容、可否、現在値を持つ独立した行。原本を変更しない。
static func candidates(collection: RefCounted,index: int,kind: String,slot: int=0) -> Array:
	if index<0 or index>=collection.builds.size():return []
	var result=[]
	var b: Dictionary=collection.builds[index]
	var equipped=current(collection,index,kind,slot)
	if kind in ["arms","gear"]:
		var kind_name=kind.to_upper()
		var catalogue={}
		for stats in C.equipment_catalog():catalogue[C.serial(kind_name,stats)]=stats
		for id in collection.items[kind_name]:catalogue[id]=collection.items[kind_name][id].duplicate()
		for id in catalogue:
			var stats: Array=catalogue[id]
			var row=_row(id,id,_stats_text(stats),kind_name,collection.items[kind_name].has(id),id==equipped)
			row.stats=stats.duplicate()
			result.append(row)
	elif kind in ["arms_mutation","gear_mutation"]:
		for id in C.mutation_catalog():
			var part=kind.trim_suffix("_mutation").to_upper()
			var row=_row(id,M.layout_code(id),part+" order: "+_order_text(id)+"\nOnly "+part+" changes. Shared MUTATION unlocks.",part,collection.mutations.has(id),id==equipped)
			row.subtitle="STANDARD" if row.title=="VIRSL" else ""
			result.append(row)
	elif kind=="class_name":
		for id in C.class_catalog():
			var baseline=id in ["VIRSL","VLSRI"]
			var row=_row(id,id,"CORE order: "+_order_text(id)+"\nOnly CORE changes. "+("Always available." if baseline else "Uses shared MUTATION unlocks."),"CORE",baseline or collection.mutations.has(id),id==equipped)
			row.subtitle="STANDARD" if id=="VIRSL" else ""
			result.append(row)
	elif kind=="skill":
		result.append(_row("NONE","NONE","Leave this skill slot empty.","EMPTY",true,equipped=="NONE"))
		var groups=["DAMAGE","HEAL","POSITION","DEFENSE","MOVEMENT","PANELS","FIELDS"]
		for group in groups:
			for id in C.SKILLS:
				if _skill_group(id)!=group:continue
				var row=_row(id,C.SKILLS[id].label,C.SKILLS[id].description,group,collection.skills.has(id),id==equipped)
				if b.skills.has(id) and id!=equipped:
					row.selectable=false
					row.reason="IN ANOTHER SLOT"
				result.append(row)
	elif kind=="operation":
		var stages=C.stages()
		for i in range(stages.size()):
			var stage=stages[i]
			result.append(_row(str(i),stage.name,stage.brief+"\n"+stage.hint,"OPERATION",true,str(i)==equipped))
	return result

## 絞り込んだ行を返す。rowsは候補、statusは能力番号で負なら全件、minimumは下限。戻り値は下限以上を値降順にした独立した配列。候補自体を変更しない。
static func filtered(rows: Array,status: int=-1,minimum: int=10) -> Array:
	if status<0 or status>4:return rows.duplicate(true)
	var result=rows.filter(func(row):return row.get("stats",[]).size()==5 and row.stats[status]>=minimum).duplicate(true)
	result.sort_custom(func(a,b):return a.stats[status]>b.stats[status] if a.stats[status]!=b.stats[status] else a.id<b.id)
	return result

## 候補構成を返す。buildは原本、kindは選択種、idは候補ID。戻り値は変更を試した複製。クラスと変異の規則を混ぜず、原本を変更しない。
static func preview(build: Dictionary,kind: String,id: String) -> Dictionary:
	var result=build.duplicate(true)
	if kind in ["arms","gear"]:
		var pieces=id.split("-")
		if pieces.size()==2 and pieces[1].length()==10:
			var stats=[]
			for i in range(5):stats.append(pieces[1].substr(i*2,2).hex_to_int())
			if M.valid_stats(stats):result[kind]=stats
	elif kind in ["class_name","arms_mutation","gear_mutation"]:
		result[kind]=id
	return result

## 選択を確定する。collectionは変更先、indexは編集番号、kindとidは候補、slotはスキル枠。戻り値は再検証した有効候補だけを反映できたか。無効時は原本を保つ。
static func commit(collection: RefCounted,index: int,kind: String,id: String,slot: int=0) -> bool:
	var rows=candidates(collection,index,kind,slot)
	var matches=rows.filter(func(row):return row.id==id and row.selectable)
	if matches.is_empty():return false
	if kind=="operation":
		collection.stage_index=int(id)
		return true
	var candidate=preview(collection.builds[index],kind,id)
	if kind=="skill":
		if slot<0 or slot>=3:return false
		var slots=["NONE","NONE","NONE"]
		for i in range(candidate.skills.size()):slots[i]=candidate.skills[i]
		slots[slot]=id
		candidate.skills=slots.filter(func(value):return value!="NONE")
	if not collection.valid_build(candidate):return false
	collection.builds[index]=candidate
	return true

static func _row(id: String,title: String,description: String,group: String,unlocked: bool,equipped: bool) -> Dictionary:
	return {"id":id,"title":title,"description":description,"group":group,"unlocked":unlocked,"selectable":unlocked,"current":equipped,"reason":"" if unlocked else "LOCKED"}

static func _stats_text(stats: Array) -> String:
	var parts=[]
	for i in range(5):parts.append("%s %d" % [STATUS[i],stats[i]])
	return "   ".join(parts)

static func _order_text(id: String) -> String:
	var parts=[]
	for letter in M.layout_code(id):parts.append(STATUS["VIRSL".find(letter)])
	return " > ".join(parts)

static func _skill_group(id: String) -> String:
	var effect: String=C.SKILLS[id].effect
	if effect in ["DAMAGE","HEAL"]:return effect
	if effect in ["SWAP","PUSH"]:return "POSITION"
	if effect=="GUARD":return "DEFENSE"
	if effect=="MOVE +1":return "MOVEMENT"
	if effect=="IGNORE PANEL":return "PANELS"
	return "FIELDS"
