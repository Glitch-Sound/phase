extends "res://tests/cpu_policy.gd"
## REQ-035-S02、REQ-035-S03、REQ-035-S04
func _run() -> void:
	policy=load("res://game/cpu_policy.gd").new()
	var reports=[]
	for stage in range(4):
		for layout_seed in [1,128,729]:
			var b=B.new()
			b.start(stage,C.player_builds(),layout_seed)
			var memory=[]
			var actions={"PLAYER":{"DAMAGE":0,"HEAL":0,"WAIT":0},"ENEMY":{"DAMAGE":0,"HEAL":0,"WAIT":0}}
			var slowest=0.0
			var states={}
			var repetitions=0
			while b.result.is_empty() and b.turn<=160:
				var actor=b.actor
				var camp=b.units[actor].camp
				var start=Time.get_ticks_usec()
				var plan=policy.choose(b,memory)
				slowest=maxf(slowest,(Time.get_ticks_usec()-start)/1000.0)
				if not _execute(b,plan):
					_check(false,"all generated CPU actions are legal stage "+str(stage)+" seed "+str(layout_seed))
					break
				actions[camp][C.SKILLS[plan.skill].effect if not plan.skill.is_empty() else "WAIT"]+=1
				memory.append({"actor":actor,"pos":b.units[actor].pos,"skill":plan.skill,"target":plan.target})
				memory=memory.slice(-load("res://game/tuning.gd").CPU_MEMORY_LIMIT)
				var state=JSON.stringify([b.actor,b.units.map(func(u):return [u.pos.x,u.pos.y,u.hp,u.core_angle,u.gear_angle,u.arms_angle])])
				states[state]=states.get(state,0)+1
				repetitions=maxi(repetitions,states[state]-1)
			_check(not b.result.is_empty(),"real rule CPU match terminates stage "+str(stage)+" seed "+str(layout_seed)+" turns "+str(b.turn))
			_check(repetitions<4,"no sustained exact state loop")
			var report={"stage":stage,"seed":layout_seed,"turns":b.turn,"result":b.result,"actions":actions,"repetitions":repetitions,"slowest_ms":slowest,"history":b.history}
			reports.append(report)
			print("CPU MATCH ",JSON.stringify(report))
	var file=FileAccess.open("res://artifacts/runtime/cpu-matches.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(reports,"\t"))
	print("CPU PLAY: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
