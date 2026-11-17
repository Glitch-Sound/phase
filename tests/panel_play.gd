extends "res://tests/contested_play.gd"
## REQ-022-S01、REQ-034-S05
func _initialize() -> void:
	var report={"mutual":[],"counter":[],"objectives":[],"first_turn_routes":0}
	var terminal=0
	var both_heal=0
	var wins={2:0,3:0}
	for layout_seed in [0,1,7]:
		var mutual=_mutual(1.1,160,true,layout_seed)
		var repeated=_mutual(1.1,160,true,layout_seed) if layout_seed==0 else mutual
		_check(mutual==repeated,"same generated layout replays exactly")
		mutual.seed=layout_seed
		report.mutual.append(mutual)
		if not mutual.result.is_empty():
			terminal+=1
		if mutual.actions.PLAYER.HEAL>0 and mutual.actions.ENEMY.HEAL>0:
			both_heal+=1
		print("GENERATED MUTUAL: seed ",layout_seed," / ",mutual.result," / turns ",mutual.turns," / ",mutual.actions)
		for stage in [2,3]:
			var counter=_unopposed(stage,layout_seed)
			counter.seed=layout_seed
			report.counter.append(counter)
			var contest=_contested_win(stage,layout_seed)
			contest.seed=layout_seed
			report.objectives.append(contest)
			if contest.result=="VICTORY":
				wins[stage]+=1
			print("GENERATED OBJECTIVE: seed ",layout_seed," / stage ",stage," / ",contest.result," / turns ",contest.turns)
			var prepared=C.player_builds()
			for build in prepared:
				build.skills.append(C.MOVE)
			var intercept=_contested_win(stage,layout_seed,prepared,Vector2i(6,5))
			intercept.seed=layout_seed
			intercept.build="collected MOVE / same stats"
			report.objectives.append(intercept)
			if intercept.result=="VICTORY":
				wins[stage]+=1
			print("GENERATED INTERCEPT: seed ",layout_seed," / stage ",stage," / ",intercept.result," / turns ",intercept.turns)
		for stage in range(4):
			var battle=RUNTIME_B.new()
			battle.start(stage,C.player_builds(),layout_seed)
			var routes=[]
			_paths(battle,battle.units[battle.actor].pos,[],routes)
			_check(not routes.is_empty(),"at least one legal opening route")
			for path in routes:
				var trial=RUNTIME_B.new()
				trial.start(stage,C.player_builds(),layout_seed)
				for cell in path:
					_check(trial.path_click(cell),"opening route remains legal")
				_check(trial.commit_path() and trial.result.is_empty(),"no immediate victory from generated opening")
				_check(trial.wait_turn() and trial.result.is_empty(),"no reward by ending first move")
				report.first_turn_routes+=1
	# 勝敗、回復回数と決着手数は観測だけとし、基本ルールは共通の再生入口で検査する。
	var file=FileAccess.open("res://artifacts/panel-play.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("GENERATED MAP PLAY: ","PASS" if failures==0 else "FAIL"," / opening routes ",report.first_turn_routes," / terminal ",terminal," / both heal ",both_heal," / objective wins ",wins)
	quit(0 if failures==0 else 1)
