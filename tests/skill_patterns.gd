extends SceneTree
const C=preload("res://game/catalog.gd")
const B=preload("res://game/battle.gd")
const L=preload("res://game/collection.gd")
const T=preload("res://game/tuning.gd")
const CASES=[
	["ACTIVE_DAMAGE_ADJACENT","DAMAGE",[Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)]],
	["ACTIVE_HEAL_ADJACENT","HEAL",[Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)]],
	["ACTIVE_DAMAGE_DIAGONAL_ONE","DAMAGE",[Vector2i(-1,-1),Vector2i(1,-1),Vector2i(1,1),Vector2i(-1,1)]],
	["ACTIVE_HEAL_DIAGONAL_ONE","HEAL",[Vector2i(-1,-1),Vector2i(1,-1),Vector2i(1,1),Vector2i(-1,1)]],
	["ACTIVE_DAMAGE_ORTHOGONAL_TWO","DAMAGE",[Vector2i(0,-2),Vector2i(2,0),Vector2i(0,2),Vector2i(-2,0)]],
	["ACTIVE_HEAL_ORTHOGONAL_TWO","HEAL",[Vector2i(0,-2),Vector2i(2,0),Vector2i(0,2),Vector2i(-2,0)]],
	["ACTIVE_DAMAGE_DIAGONAL_TWO","DAMAGE",[Vector2i(-2,-2),Vector2i(2,-2),Vector2i(2,2),Vector2i(-2,2)]],
	["ACTIVE_HEAL_DIAGONAL_TWO","HEAL",[Vector2i(-2,-2),Vector2i(2,-2),Vector2i(2,2),Vector2i(-2,2)]]
]
var checks=0
var failures=0
func _initialize()->void:
	_patterns()
	_boundaries()
	_inventory()
	print("SKILL PATTERNS: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
## REQ-011-S01、REQ-011-S02
func _patterns()->void:
	for row in CASES:
		var b=_battle(row[0],row[1])
		var found=[]
		for y in range(10):
			for x in range(10):
				b.units[2].pos=Vector2i(x,y)
				if b.valid_target(0,2,row[0]): found.append(Vector2i(x,y))
		var expected=[]
		for offset in row[2]: expected.append(Vector2i(4,4)+offset)
		_check(_sorted(found)==_sorted(expected),"complete exact target set "+row[0])
		if not C.SKILLS.has(row[0]): continue
		b.units[0].pos=Vector2i.ZERO
		found=[]
		for y in range(3):
			for x in range(3):
				b.units[2].pos=Vector2i(x,y)
				if b.valid_target(0,2,row[0]): found.append(Vector2i(x,y))
		expected=[]
		for offset in row[2]:
			if offset.x>=0 and offset.y>=0: expected.append(offset)
		_check(_sorted(found)==_sorted(expected),"edge keeps only the specified in-board cells "+row[0])
		b=_battle(row[0],row[1])
		b.units[2].pos=Vector2i(4,4)+row[2][0]
		# 中間セルの占有は移動と違い、単体対象の射程を遮らない。
		b.units[1].pos=Vector2i(4,4)+Vector2i(signi(row[2][0].x),signi(row[2][0].y)) if row[2][0].length()>1.5 else Vector2i(0,0)
		var before=b.units.duplicate(true)
		var amount=floori(T.BASE_DAMAGE*2.0/3.0) if row[1]=="DAMAGE" else floori(T.BASE_HEAL*2.0)
		var hp=maxf(0,before[2].hp-amount) if row[1]=="DAMAGE" else minf(before[2].max_hp,before[2].hp+amount)
		var ended=before[0].duplicate(true)
		ended.next_time+=T.BASE_DELAY
		_check(b.choose_skill(row[0]) and b.act(2),"equipped skill executes "+row[0])
		_check(b.units[2].hp==hp and b.last_effect.kind==row[1] and b.last_effect.amount==amount,"same configured power, integer rounding and HP bounds "+row[0])
		_check([b.units[0],b.units[1],b.units[3]]==[ended,before[1],before[3]] and b.turn==2,"only the chosen target and one completed hand change "+row[0])
## REQ-011-S03
func _boundaries()->void:
	var heal="ACTIVE_HEAL_DIAGONAL_TWO"
	if not C.SKILLS.has(heal): return
	var b=_battle(heal,"HEAL")
	b.units[2].pos=Vector2i(6,6)
	_check(not b.valid_target(0,0,heal) and b.valid_target(0,2,heal),"wounded ally in range is valid; self is not")
	b.units[2].hp=b.units[2].max_hp
	_check(not b.valid_target(0,2,heal),"full HP cannot be healed")
	b.units[2].hp=0
	_check(not b.valid_target(0,2,heal),"defeated target cannot be revived")
	b.units[2].hp=1
	b.units[2].camp="ENEMY"
	_check(not b.valid_target(0,2,heal),"enemy cannot be healed")
	var damage="ACTIVE_DAMAGE_DIAGONAL_TWO"
	_check(b.valid_target(0,2,damage),"living enemy is valid for damage")
	b.units[2].camp="PLAYER"
	_check(not b.valid_target(0,2,damage),"ally cannot take the damage skill")
	_check(not b.valid_target(-1,2,heal) and not b.valid_target(b.units.size(),2,heal) and not b.valid_target(0,b.units.size(),heal) and not b.valid_target(0,2,"UNKNOWN") and not b.valid_target(0,2,C.MOVE),"invalid indices, IDs and passive skill have no target")
	var before=[b.units.duplicate(true),b.turn,b.history.duplicate(),b.mode]
	b.units[2].pos=Vector2i(5,5)
	_check(b.choose_skill(heal) and not b.act(2),"one diagonal step is not two")
	_check(b.units[0]==before[0][0] and b.turn==before[1] and b.history==before[2],"invalid action has no applied side effects")
	b.back()
	b.units[0].skills=[]
	_check(not b.choose_skill(heal),"unowned skill cannot be selected")
## REQ-026-S01、REQ-026-S02、REQ-026-S03
func _inventory()->void:
	var expected=CASES.map(func(row):return row[0])+[C.MOVE,"ACTIVE_SWAP_ADJACENT","ACTIVE_PUSH_ADJACENT","ACTIVE_GUARD_SELF","PASSIVE_IGNORE_PANEL_SELF","PASSIVE_FIELD_SLOW_ADJACENT","PASSIVE_FIELD_FAST_ADJACENT"]
	expected.sort()
	var actual=C.SKILLS.keys()
	actual.sort()
	_check(actual==expected,"exact eight damage/heal actives, MOVE, four utilities and two fields; no line or area attack")
	var inventory=L.new()
	_check(inventory.skills==[C.DAMAGE,C.HEAL] and inventory.builds.all(func(b):return b.skills==[C.DAMAGE,C.HEAL]),"initial builds and unlocks preserve the old IDs")
	var obtained=true
	for row in CASES.slice(2): obtained=inventory.accept_drop({"skill":row[0]}) and obtained
	_check(obtained and inventory.skills.size()==8,"all six new skills can be acquired without unlocking MOVE")
	if not obtained: return
	inventory.builds[0].skills=[CASES[2][0],CASES[5][0],CASES[6][0]]
	inventory.builds[1].skills=inventory.builds[0].skills.duplicate()
	_check(inventory.builds.all(func(b):return inventory.valid_build(b)),"unlocked new skills can be shared in three slots")
	var duplicate=inventory.builds[0].duplicate(true)
	duplicate.skills=[CASES[2][0],CASES[2][0]]
	_check(not inventory.valid_build(duplicate),"duplicate skill rejected")
	var locked=L.new()
	_check(not locked.valid_build(inventory.builds[0]),"locked new skill rejected")
	var path="res://artifacts/runtime/skill-patterns-save-"+str(Time.get_ticks_usec())+".json"
	var restored=L.new()
	var save_error=inventory.save_to(path)
	var load_error=restored.load_from(path)
	# JSONの数値型を両辺で正規化し、内容の全体を比較する。
	var round_trip=JSON.parse_string(JSON.stringify(restored.snapshot()))==JSON.parse_string(JSON.stringify(inventory.snapshot()))
	_check(save_error=="" and load_error=="" and round_trip,"new skills round-trip through isolated version-1 save")
	var legacy=L.new()
	legacy.skills=[C.DAMAGE,C.HEAL,C.MOVE]
	legacy.builds[0].skills=legacy.skills.duplicate()
	path=path.replace(".json","-legacy.json")
	_check(legacy.save_to(path)=="" and restored.load_from(path)=="" and restored.skills==[C.DAMAGE,C.HEAL,C.MOVE] and restored.builds==JSON.parse_string(JSON.stringify(legacy.builds)),"old three-skill save stays unchanged and does not gain the new skills")
func _battle(skill:String,kind:String):
	var b=B.new()
	b.start(0,[C.starter_build(),C.starter_build()],1)
	b.units[0].pos=Vector2i(4,4)
	b.units[0].skills=[skill]
	b.units[0].moved=1
	b.units[1].pos=Vector2i(0,0)
	b.units[3].pos=Vector2i(9,9)
	if kind=="HEAL":
		b.units[2].camp="PLAYER"
		b.units[2].hp=b.units[2].max_hp/2.0
	b.mode="CHOICE"
	return b
func _sorted(values:Array)->Array:
	values.sort_custom(func(a,b):return a.y<b.y if a.y!=b.y else a.x<b.x)
	return values
func _check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
