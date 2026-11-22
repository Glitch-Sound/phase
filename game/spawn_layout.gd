## 戦闘開始だけで使う、陣営ごとのまとまった再現可能な配置。
extends RefCounted
const T=preload("res://game/tuning.gd")
const DIRS=[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]

## 初期6枠を返す。stageは目標を持つ定義、layout_seedは開始シード。戻り値はPLAYER3枠、ENEMY3枠の順の配列。入力と他の乱数を変更しない。
static func generate(stage: Dictionary,layout_seed: int) -> Array:
	var rng=RandomNumberGenerator.new();rng.seed=layout_seed ^ 0x535041574e
	var origin=Vector2i(rng.randi_range(T.SPAWN_X_RANGE.x,_max_left_x(stage)),rng.randi_range(T.SPAWN_Y_RANGE.x,T.SPAWN_Y_RANGE.y))
	var pool=_cells(Rect2i(origin,T.SPAWN_GROUP_SIZE));_shuffle(pool,rng)
	var players=pool.slice(0,3);var enemies=[]
	if stage.goal.x<0:
		for cell in players:enemies.append(Vector2i(9-cell.x,cell.y))
	else:
		pool=_cells(_goal_area(stage));pool.erase(stage.goal)
		var pairs=[]
		for i in range(pool.size()):
			for j in range(i+1,pool.size()):
				if _movable([stage.goal,pool[i],pool[j]]):pairs.append([pool[i],pool[j]])
		var pair=pairs[rng.randi_range(0,pairs.size()-1)].duplicate();_shuffle(pair,rng)
		enemies=[stage.goal]+pair
	return players+enemies

## 全シードで使える開始領域を返す。stageは目標定義。戻り値はPLAYERとENEMYの矩形で、固定の出発点を捏造しない。副作用なし。
static func areas(stage: Dictionary) -> Array:
	var left=Rect2i(Vector2i(T.SPAWN_X_RANGE.x,T.SPAWN_Y_RANGE.x),Vector2i(_max_left_x(stage)-T.SPAWN_X_RANGE.x,T.SPAWN_Y_RANGE.y-T.SPAWN_Y_RANGE.x)+T.SPAWN_GROUP_SIZE)
	return [left,_goal_area(stage) if stage.goal.x>=0 else Rect2i(Vector2i(10-left.end.x,left.position.y),left.size)]

static func _max_left_x(stage: Dictionary) -> int:
	var limit=floori((9-T.SPAWN_CAMP_GAP)/2.0)-T.SPAWN_GROUP_SIZE.x+1 if stage.goal.x<0 else stage.goal.x-2*T.SPAWN_GROUP_SIZE.x+2-T.SPAWN_CAMP_GAP
	return mini(T.SPAWN_X_RANGE.y,limit)

static func _goal_area(stage: Dictionary) -> Rect2i:
	return Rect2i(stage.goal-Vector2i(T.SPAWN_GROUP_SIZE.x-1,0),T.SPAWN_GROUP_SIZE)

static func _cells(area: Rect2i) -> Array:
	var result=[]
	for y in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):result.append(Vector2i(x,y))
	return result

static func _movable(cells: Array) -> bool:
	return cells.all(func(cell):return DIRS.any(func(d):return Rect2i(0,0,10,10).has_point(cell+d) and cell+d not in cells))

static func _shuffle(values: Array,rng: RandomNumberGenerator) -> void:
	for i in range(values.size()-1,0,-1):
		var j=rng.randi_range(0,i);var swap=values[i];values[i]=values[j];values[j]=swap
