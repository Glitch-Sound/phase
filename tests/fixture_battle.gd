## 旧配置を明示して位相と表示の既存条件を固定する検査専用モデル。
extends "res://game/battle.gd"
const LEGACY_PANELS = {Vector2i(4,3):"SHIFT",Vector2i(4,4):"LOCK",Vector2i(4,5):"REVERSE",Vector2i(5,3):"REVERSE",Vector2i(5,5):"SHIFT",Vector2i(5,6):"LOCK",Vector2i(2,5):"SHIFT",Vector2i(7,5):"REVERSE",Vector2i(4,7):"LOCK",Vector2i(5,2):"SHIFT"}
const LEGACY_OVERRIDES = [{},{},{Vector2i(8,0):"LOCK",Vector2i(8,1):"REVERSE",Vector2i(9,1):"SHIFT",Vector2i(3,7):"REVERSE",Vector2i(2,8):"LOCK",Vector2i(1,8):"SHIFT"},{Vector2i(7,0):"LOCK",Vector2i(8,1):"REVERSE",Vector2i(9,0):"SHIFT",Vector2i(3,7):"SHIFT",Vector2i(2,8):"REVERSE",Vector2i(1,8):"LOCK"}]
func start(stage_index: int, builds: Array, layout_seed: int=0) -> void:
	super.start(stage_index,builds,layout_seed)
	panels=LEGACY_PANELS.duplicate(true)
	panels.merge(LEGACY_OVERRIDES[stage_index],true)
