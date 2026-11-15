## 共有開放一覧、ビルド、乱数ドロップと検証付き保存を管理する。
extends RefCounted
const C = preload("res://game/catalog.gd")
const M = preload("res://game/phase_math.gd")
const T = preload("res://game/tuning.gd")
var items: Dictionary={"ARMS":{},"GEAR":{}}
var mutations: Array=["NORMAL"]
var skills: Array=[C.DAMAGE,C.HEAL,C.MOVE]
var builds: Array=[]
var stage_index := 0
var last_backup := ""

func _init() -> void:
	for kind in ["ARMS","GEAR"]:
		for stats in C.STARTER_STATS:
			items[kind][C.serial(kind,stats)]=stats.duplicate()
	builds=[C.default_build(),C.default_build()]

## ビルドを検証する。buildは候補、inventoryは検証用開放状態で空なら現状態。戻り値は適否。
func valid_build(build: Variant, inventory: Dictionary={}) -> bool:
	if not build is Dictionary:
		return false
	var inv=snapshot() if inventory.is_empty() else inventory
	var fields=["class_name","core","gear","arms","gear_mutation","arms_mutation","skills"]
	if build.size()!=fields.size():
		return false
	for key in fields:
		if not build.has(key):
			return false
	if not build.class_name in ["STANDARD","REVERSE"] or not M.valid_stats(build.core):
		return false
	for key in ["gear","arms"]:
		if not M.valid_stats(build[key]) or not inv.items[key.to_upper()].has(C.serial(key.to_upper(),build[key])):
			return false
		if not build[key+"_mutation"] in inv.mutations:
			return false
	if not build.skills is Array or build.skills.size()>3:
		return false
	var seen=[]
	for skill in build.skills:
		if not skill in inv.skills or seen.has(skill):
			return false
		seen.append(skill)
	return true

## ドロップを開放する。dropはkindとstatsとmutation、またはskill。戻り値は新規取得の有無。
func accept_drop(drop: Dictionary) -> bool:
	if drop.has("skill"):
		if C.SKILLS.has(drop.skill) and not skills.has(drop.skill):
			skills.append(drop.skill)
			return true
		return false
	if not drop.get("kind","") in ["ARMS","GEAR"] or not M.valid_stats(drop.get("stats",[])) or not _valid_mutation(drop.get("mutation","")):
		return false
	var serial=C.serial(drop.kind,drop.stats)
	var new_item=not items[drop.kind].has(serial)
	var new_mutation=not mutations.has(drop.mutation)
	if not new_item and not new_mutation:
		return false
	drop.new_item=new_item
	drop.new_mutation=new_mutation
	items[drop.kind][serial]=drop.stats.duplicate()
	if new_mutation:
		mutations.append(drop.mutation)
	return true

## 戦利品を生成し開放する。rngは注入した乱数生成器。戻り値は0から2件の新規候補。
func roll_loot(rng: RandomNumberGenerator) -> Array:
	var result=[]
	var count=rng.randi_range(0,2)
	for slot in range(count):
		for attempt in range(128):
			var locked=[]
			for skill in C.SKILLS:
				if not skills.has(skill):
					locked.append(skill)
			var drop: Dictionary
			if not locked.is_empty() and rng.randi_range(0,2)==0:
				drop={"skill":locked[rng.randi_range(0,locked.size()-1)]}
			else:
				var cuts=[0,100]
				while cuts.size()<6:
					var cut=rng.randi_range(1,99)
					if not cuts.has(cut):
						cuts.append(cut)
				cuts.sort()
				var stats=[]
				for i in range(5):
					stats.append(cuts[i+1]-cuts[i])
				var mutation="NORMAL"
				if rng.randf()<T.MUTANT_CHANCE:
					var letters=["V","I","R","S","L"]
					for i in range(4,0,-1):
						var j=rng.randi_range(0,i)
						var old=letters[i]
						letters[i]=letters[j]
						letters[j]=old
					mutation="".join(letters)
					if mutation=="VIRSL":
						mutation="IVRSL"
				drop={"kind":"ARMS" if rng.randi_range(0,1)==0 else "GEAR","stats":stats,"mutation":mutation}
			if accept_drop(drop):
				result.append(drop)
				break
	return result

## 保存用状態を返す。戻り値は編集から独立したJSON互換の辞書。
func snapshot() -> Dictionary:
	return {"version":T.SAVE_VERSION,"items":items.duplicate(true),"mutations":mutations.duplicate(),"skills":skills.duplicate(),"builds":builds.duplicate(true),"stage_index":stage_index}

## 状態を保存する。pathは保存先。戻り値は成功時空文字、失敗時説明。既存ファイルを別名バックアップする。
func save_to(path: String) -> String:
	var data=snapshot()
	var error=_validate_snapshot(data)
	if not error.is_empty():
		return error
	var absolute=ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())!=OK:
		return "Cannot create save directory."
	var suffix=".%d-%d" % [int(Time.get_unix_time_from_system()),Time.get_ticks_usec()]
	var temporary=absolute+suffix+".tmp"
	var f=FileAccess.open(temporary,FileAccess.WRITE)
	if f==null:
		return "Cannot write save file."
	f.store_string(JSON.stringify(data,"\t"))
	f.flush()
	var write_error=f.get_error()
	f.close()
	if write_error!=OK:
		return "Save write failed. Original is preserved."
	if FileAccess.file_exists(absolute):
		last_backup=absolute+suffix+".backup.json"
		if DirAccess.copy_absolute(absolute,last_backup)!=OK:
			return "Backup failed. Original is preserved."
	if DirAccess.rename_absolute(temporary,absolute)!=OK:
		return "Cannot replace save. Original or backup is preserved."
	return ""

## 状態を読み込む。pathは候補ファイル。戻り値は成功時空文字、失敗時説明。検証成功後にだけ現在データを更新する。
func load_from(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "No saved build. Use SAVE first."
	var f=FileAccess.open(path,FileAccess.READ)
	if f==null:
		return "Cannot read save."
	if f.get_length()>8*1024*1024:
		return "Save is too large. Current build is preserved."
	var parser=JSON.new()
	var status=parser.parse(f.get_as_text())
	f.close()
	if status!=OK:
		return "Invalid JSON. Current build is preserved."
	var error=_validate_snapshot(parser.data)
	if not error.is_empty():
		return error
	var data: Dictionary=parser.data
	items=data.items.duplicate(true)
	mutations=data.mutations.duplicate()
	skills=data.skills.duplicate()
	builds=data.builds.duplicate(true)
	stage_index=int(data.stage_index)
	return ""

func _validate_snapshot(data: Variant) -> String:
	if not data is Dictionary or data.get("version",-1)!=T.SAVE_VERSION:
		return "Unsupported save version."
	for key in ["items","mutations","skills","builds","stage_index"]:
		if not data.has(key):
			return "Incomplete save."
	if not data.items is Dictionary or not data.mutations is Array or not data.skills is Array or not data.builds is Array:
		return "Invalid save structure."
	if not (data.stage_index is float or data.stage_index is int) or data.stage_index!=int(data.stage_index) or data.stage_index<0 or data.stage_index>=C.stages().size():
		return "Invalid stage."
	for kind in ["ARMS","GEAR"]:
		if not data.items.get(kind) is Dictionary or data.items[kind].is_empty():
			return "Invalid inventory."
		for serial in data.items[kind]:
			var stats=data.items[kind][serial]
			if not M.valid_stats(stats) or serial!=C.serial(kind,stats):
				return "Invalid equipment distribution."
	if not data.mutations.has("NORMAL"):
		return "Missing NORMAL mutation."
	var seen=[]
	for mutation in data.mutations:
		if not _valid_mutation(mutation) or seen.has(mutation):
			return "Invalid mutation."
		seen.append(mutation)
	seen=[]
	for skill in data.skills:
		if not C.SKILLS.has(skill) or seen.has(skill):
			return "Unknown or duplicate skill."
		seen.append(skill)
	if data.builds.size()!=2:
		return "Expected two PLAYER builds."
	for build in data.builds:
		if not valid_build(build,data):
			return "Invalid or locked build element."
	return ""

static func _valid_mutation(value: Variant) -> bool:
	if not value is String:
		return false
	if value=="NORMAL":
		return true
	if value.length()!=5 or value=="VIRSL":
		return false
	for letter in "VIRSL":
		if value.count(letter)!=1:
			return false
	return true
