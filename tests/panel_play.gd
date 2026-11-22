extends "res://tests/contested_play.gd"
## REQ-022-S01、REQ-034-S05
func _initialize() -> void:
	var report={"mutual":[]}
	var terminal=0
	var both_heal=0
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
	# 勝敗、回復回数と決着手数は観測だけとし、基本ルールは共通の再生入口で検査する。
	var file=FileAccess.open("res://artifacts/panel-play.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("GENERATED MAP PLAY: ","PASS" if failures==0 else "FAIL"," / terminal ",terminal," / both heal ",both_heal)
	quit(0 if failures==0 else 1)
