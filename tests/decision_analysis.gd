extends "res://tests/cpu_policy.gd"
## REQ-005-S02、REQ-035-S03、REQ-035-S04
func _run() -> void:
	policy=load("res://game/cpu_policy.gd").new()
	var reports=[]
	for stage in [0,1,2,3]:
		for survivor in [0,1]:
			var b=B.new()
			b.start(stage,C.player_builds(),1)
			b.units[1-survivor].hp=0
			b.check_result("DEATH")
			b.next_actor() if b.result.is_empty() else null
			var heal_targets=[]
			for i in range(b.units.size()):
				if b.valid_target(survivor,i,C.HEAL):
					heal_targets.append(i)
			var memory=[]
			while b.result.is_empty() and b.turn<=160:
				var actor=b.actor
				var plan=policy.choose(b,memory)
				if not _execute(b,plan):
					_check(false,"solo analysis uses only legal existing operations")
					break
				memory.append({"actor":actor,"pos":b.units[actor].pos,"skill":plan.skill,"target":plan.target})
				memory=memory.slice(-load("res://game/tuning.gd").CPU_MEMORY_LIMIT)
			reports.append({"stage":stage,"survivor":b.units[survivor].id,"healing_targets":heal_targets,"turns":b.turn,"result":b.result,"hp":b.units.map(func(u):return u.hp),"history":b.history})
	var phases=[]
	# 片陣営の人数だけでは勝敗は決まらないことを、進行済み相当の低HP配置で観測する。
	var comeback=B.new()
	comeback.start(0,C.player_builds(),1)
	comeback.units[1].hp=0
	comeback.units[0].hp=40
	comeback.units[2].hp=1
	comeback.units[3].hp=1
	var comeback_memory=[]
	while comeback.result.is_empty() and comeback.turn<=160:
		var index=comeback.actor
		var plan=policy.choose(comeback,comeback_memory)
		if not _execute(comeback,plan):
			_check(false,"comeback analysis remains legal")
			break
		comeback_memory.append({"actor":index,"pos":comeback.units[index].pos,"skill":plan.skill,"target":plan.target})
		comeback_memory=comeback_memory.slice(-load("res://game/tuning.gd").CPU_MEMORY_LIMIT)
	var comeback_report={"fixture":"one-versus-two-near-victory","turns":comeback.turn,"result":comeback.result,"hp":comeback.units.map(func(u):return u.hp),"history":comeback.history}
	for pair in [[120.0,240.0],[330.0,30.0],[0.0,0.0]]:
		var u=C.unit("X","PLAYER",Vector2i.ZERO,C.starter_build())
		u.gear_angle=pair[0]
		u.arms_angle=pair[1]
		var target=C.unit("Y","ENEMY",Vector2i.ONE,C.starter_build())
		phases.append({"angles":pair,"inf":load("res://game/phase_math.gd").sync(u,1),"res":load("res://game/phase_math.gd").sync(u,2),"damage_to_aligned":load("res://game/phase_math.gd").effect(u,target,"DAMAGE"),"aligned_to_damage":load("res://game/phase_math.gd").effect(target,u,"DAMAGE"),"heal":load("res://game/phase_math.gd").effect(u,target,"HEAL")})
	var file=FileAccess.open("res://artifacts/runtime/decisions-analysis.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"solo":reports,"comeback":comeback_report,"phases":phases},"\t"))
	for report in reports:
		print("SOLO ANALYSIS ",report.stage," / ",report.survivor," / ",report.result," / turns ",report.turns," / HP ",report.hp)
	print("COMEBACK ANALYSIS ",comeback_report)
	print("DECISION ANALYSIS COMPLETE / failures ",failures)
	quit(0 if failures==0 else 1)
