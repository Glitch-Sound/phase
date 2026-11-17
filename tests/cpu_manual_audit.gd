## 通常のゲームを操作し、変更された状態だけを検証用パスへ記録する。
extends "res://ui/main.gd"
var audit_key=""
func _init() -> void:
	settings_path="res://artifacts/runtime/cpu-manual-no-settings.json"
	save_path="res://artifacts/runtime/cpu-manual-no-save.json"
	panel_seed_override=1
func _process(delta: float) -> void:
	super._process(delta)
	if battle.units.is_empty():
		return
	var key=str([build_open,battle.turn,battle.mode,cpu_turn.phase,cpu_paused,cpu_fast,battle.result])
	if key==audit_key:
		return
	audit_key=key
	var state={"build":build_open,"turn":battle.turn,"actor":battle.actor,"mode":battle.mode,"phase":cpu_turn.phase,"cpu":cpu_enabled,"paused":cpu_paused,"fast":cpu_fast,"result":battle.result,"units":battle.units,"path":battle.path,"history":battle.history,"window_size":get_window().size,"transform":str(get_viewport().get_final_transform()),"selected":selected,"hover":timeline_hover,"turn_focus":_turn_focus_cell()}
	var file=FileAccess.open("res://artifacts/runtime/cpu-manual-state.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(state,"\t"))
	print("MANUAL STATE ",key)
