## 戦闘開始だけで使う、陣営ごとのまとまった再現可能な配置。
extends RefCounted
const T=preload("res://game/tuning.gd")

## 初期6枠を返す。layout_seedは開始シード。戻り値はPLAYER3枠、ENEMY3枠の順の配列。入力と他の乱数を変更しない。
static func generate(layout_seed: int) -> Array:
	var rng=RandomNumberGenerator.new();rng.seed=layout_seed ^ 0x535041574e
	var origin=Vector2i(rng.randi_range(T.SPAWN_X_RANGE.x,_max_left_x()),rng.randi_range(T.SPAWN_Y_RANGE.x,T.SPAWN_Y_RANGE.y))
	var pool=_cells(Rect2i(origin,T.SPAWN_GROUP_SIZE));_shuffle(pool,rng)
	var players=pool.slice(0,3);var enemies=[]
	for cell in players:enemies.append(Vector2i(9-cell.x,cell.y))
	return players+enemies

## 全シードで使える開始領域を返す。戻り値はPLAYERとENEMYの矩形で、固定の出発点を捏造しない。副作用なし。
static func areas() -> Array:
	var left=Rect2i(Vector2i(T.SPAWN_X_RANGE.x,T.SPAWN_Y_RANGE.x),Vector2i(_max_left_x()-T.SPAWN_X_RANGE.x,T.SPAWN_Y_RANGE.y-T.SPAWN_Y_RANGE.x)+T.SPAWN_GROUP_SIZE)
	return [left,Rect2i(Vector2i(10-left.end.x,left.position.y),left.size)]

static func _max_left_x() -> int:
	return mini(T.SPAWN_X_RANGE.y,floori((9-T.SPAWN_CAMP_GAP)/2.0)-T.SPAWN_GROUP_SIZE.x+1)

static func _cells(area: Rect2i) -> Array:
	var result=[]
	for y in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):result.append(Vector2i(x,y))
	return result

static func _shuffle(values: Array,rng: RandomNumberGenerator) -> void:
	for i in range(values.size()-1,0,-1):
		var j=rng.randi_range(0,i);var swap=values[i];values[i]=values[j];values[j]=swap
