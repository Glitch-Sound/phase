## 旧配置を明示して位相と表示の既存条件を固定する検査専用モデル。
extends "res://game/battle.gd"
const LEGACY_PANELS = {Vector2i(4,3):"CLOCKWISE",Vector2i(4,4):"RESET",Vector2i(4,5):"COUNTERCLOCKWISE",Vector2i(5,3):"COUNTERCLOCKWISE",Vector2i(5,5):"CLOCKWISE",Vector2i(5,6):"RESET",Vector2i(2,5):"CLOCKWISE",Vector2i(7,5):"COUNTERCLOCKWISE",Vector2i(4,7):"RESET",Vector2i(5,2):"CLOCKWISE"}
const LEGACY_OVERRIDES = [{},{},{Vector2i(8,0):"RESET",Vector2i(8,1):"COUNTERCLOCKWISE",Vector2i(9,1):"CLOCKWISE",Vector2i(3,7):"COUNTERCLOCKWISE",Vector2i(2,8):"RESET",Vector2i(1,8):"CLOCKWISE"},{Vector2i(7,0):"RESET",Vector2i(8,1):"COUNTERCLOCKWISE",Vector2i(9,0):"CLOCKWISE",Vector2i(3,7):"CLOCKWISE",Vector2i(2,8):"COUNTERCLOCKWISE",Vector2i(1,8):"RESET"}]
func start(stage_index: int, builds: Array, layout_seed: int=0) -> void:
	super.start(stage_index,builds.slice(0,2),layout_seed)
	# 旧2対2の機械的な条件だけを固定し、本番6体の検査とは分ける。
	units[2]=C.unit("A","ENEMY",stage.spawns[C.SQUAD_SIZE],C.starter_build())
	units[3]=C.unit("B","ENEMY",stage.spawns[C.SQUAD_SIZE+1],C.starter_build())
	next_actor()
	panels=LEGACY_PANELS.duplicate(true)
	panels.merge(LEGACY_OVERRIDES[stage_index],true)
