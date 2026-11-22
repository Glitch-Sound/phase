## 作用の検証でだけ、固定した6枠を明示する。実開始配置の検証は本番battleを使う。
extends "res://game/battle.gd"
func _spawn_positions(_layout_seed: int) -> Array:
	return stage.spawns.duplicate()
