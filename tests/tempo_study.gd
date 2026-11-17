extends SceneTree
## REQ-005-S02、REQ-035-S05
## 旧版と現行の隔離コピーを、同じ条件と合法APIで比較する。
func _initialize() -> void:
	var reports=[]
	for version in ["baseline","current"]:
		var prefix="res://artifacts/runtime/tempo-study/"+version+"/"
		var catalog=load(prefix+"catalog.gd")
		var model=load(prefix+"battle.gd")
		var normal=load(prefix+"cpu_policy.gd").new()
		var aggressive=load(prefix+"aggressive.gd").new()
		for kind in ["starter","balanced","reverse","aggressive"]:
			for stage in range(4):
				for layout_seed in ([1,128,729,7,2026] if kind=="starter" else ([128,2026] if kind=="reverse" else [128])):
					var builds=catalog.player_builds()
					if kind=="balanced": builds=[catalog.starter_build(),catalog.starter_build()]
					if kind=="reverse":
						for unit in builds:
							unit.class_name="REVERSE"
							unit.gear_mutation="LSRIV"
					var b=model.new()
					b.start(stage,builds,layout_seed)
					var memory=[]
					var actions=0
					var heals=0
					var damage=0
					var maximum=0
					var one_shots=0
					var history=[]
					var states={}
					var repeated=0
					while b.result.is_empty() and actions<160:
						var actor=b.actor
						var policy=aggressive if kind=="aggressive" and actor<2 else normal
						var plan=policy.choose(b,memory)
						var target=plan.target
						var target_hp=b.units[target].hp if target>=0 else 0
						var target_max=b.units[target].max_hp if target>=0 else 0
						for cell in plan.path:
							assert(b.path_click(cell),"legal study route")
						if not plan.path.is_empty(): assert(b.commit_path(),"legal study commit")
						if b.result.is_empty():
							if plan.skill=="": assert(b.wait_turn(),"legal study wait")
							else:
								assert(b.choose_skill(plan.skill) and b.act(target),"legal study action")
								if plan.skill==catalog.DAMAGE:
									damage+=1
									maximum=maxi(maximum,b.last_effect.amount)
									if target_hp==target_max and b.units[target].hp<=0:one_shots+=1
								else:heals+=1
						actions+=1
						memory.append({"actor":actor,"pos":b.units[actor].pos,"skill":plan.skill,"target":target})
						memory=memory.slice(-8)
						history.append({"actor":actor,"path":plan.path,"skill":plan.skill,"target":target,"hp":b.units.map(func(u):return u.hp)})
						var key=str(b.units.map(func(u):return [u.hp,u.pos,u.core_angle,u.gear_angle,u.arms_angle]))
						states[key]=states.get(key,0)+1
						repeated=maxi(repeated,states[key])
					var row={"version":version,"kind":kind,"stage":stage,"seed":layout_seed,"hands":actions,"turn":b.turn,"result":b.result,"damage":damage,"heals":heals,"max_hit":maximum,"full_hp_kills":one_shots,"max_repetition":repeated,"history":history}
					reports.append(row)
					print("TEMPO ",version," ",kind," ",stage," ",layout_seed," ",actions," ",b.result)
	var file=FileAccess.open("res://artifacts/runtime/tempo-study/results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(reports,"\t"))
	quit()
