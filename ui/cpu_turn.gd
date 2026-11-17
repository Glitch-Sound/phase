## CPUの表示段階を進め、既存の戦闘操作を一度だけ実行する。
extends RefCounted
const T=preload("res://game/tuning.gd")
var active=false
var phase=""
var elapsed=0.0
var command: Dictionary={}
var actor=-1
var turn=-1
var path_index=0
var owner

## 表示を開始する。battleは対象の戦闘、planは合法な選択。戦闘自体は変更しない。
func begin(battle: RefCounted, plan: Dictionary) -> void:
	reset()
	if plan.is_empty() or battle.mode!="MOVE" or not battle.result.is_empty():
		return
	owner=battle
	command=plan.duplicate(true)
	actor=battle.actor
	turn=battle.turn
	phase="THINK"
	active=true

## 保留中の表示を破棄する。戦闘と保存を変更しない。
func reset() -> void:
	active=false
	phase=""
	elapsed=0.0
	command={}
	actor=-1
	turn=-1
	path_index=0
	owner=null

## 1段階まで進める。battleは開始時の対象、deltaは実時間差、blockedは停止、speedは表示速度。戻り値は発生イベント。中断中は時間を蓄積しない。
func advance(battle: RefCounted, delta: float, blocked: bool, speed: float=1.0) -> String:
	if not active:
		return ""
	if battle!=owner or (phase!="RESULT" and (battle.actor!=actor or battle.turn!=turn)):
		reset()
		return "cancel"
	if not battle.result.is_empty():
		reset()
		return "terminal"
	if blocked or delta<=0 or not is_finite(delta):
		return ""
	elapsed+=delta*speed
	if elapsed<T.CPU_TIMES[phase]-0.00000001:
		return ""
	elapsed=0.0
	match phase:
		"THINK":
			if command.path.is_empty():
				phase="ACTION"
				return "hold"
			return _route(battle)
		"ROUTE":
			if path_index<command.path.size():
				return _route(battle)
			phase="COMMIT"
			return "hold"
		"COMMIT":
			if not battle.commit_path():
				return _cancel()
			phase="ACTION"
			return "commit"
		"ACTION":
			if command.skill=="":
				if not battle.wait_turn():
					return _cancel()
				phase="RESULT"
				return "wait"
			if not battle.choose_skill(command.skill):
				return _cancel()
			phase="TARGET"
			return "target"
		"TARGET":
			if not battle.act(command.target):
				return _cancel()
			phase="RESULT"
			return "act"
		"RESULT":
			reset()
			return "done"
	return _cancel()

func _route(battle) -> String:
	if not battle.path_click(command.path[path_index]):
		return _cancel()
	path_index+=1
	phase="ROUTE"
	return "route"

func _cancel() -> String:
	reset()
	return "cancel"
