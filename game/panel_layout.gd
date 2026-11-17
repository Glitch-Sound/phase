## 戦闘開始時だけ、シードから分散した効果パネルを生成する。
extends RefCounted
const T=preload("res://game/tuning.gd")
const KINDS=["CLOCKWISE","RESET","COUNTERCLOCKWISE"]

## 配置を返す。stageは初期位置と両目標、layout_seedは再現用整数、rateは全100セルに対する密度。戻り値は座標と効果の辞書。入力と他の乱数を変更しない。
static func generate(stage: Dictionary, layout_seed: int, rate: float=T.PANEL_EFFECT_RATE) -> Dictionary:
	var bins=[[],[],[],[]]
	var excluded=stage.spawns.duplicate()
	excluded.append(stage.goal)
	excluded.append(stage.enemy_goal)
	var available=0
	for y in range(10):
		for x in range(10):
			var cell=Vector2i(x,y)
			if excluded.has(cell):
				continue
			bins[floori(x/5.0)+2*floori(y/5.0)].append(cell)
			available+=1
	var count=mini(available,floori(100*clampf(rate,0,1)+0.5))
	if count==0:
		return {}
	var rng=RandomNumberGenerator.new()
	rng.seed=layout_seed
	var quotas=[]
	var order=[]
	var remaining=count
	for i in range(4):
		var share=float(count)*bins[i].size()/available
		quotas.append(floori(share))
		remaining-=quotas[i]
		order.append({"index":i,"fraction":share-floor(share),"tie":rng.randi()})
	order.sort_custom(func(a,b):return a.fraction>b.fraction if a.fraction!=b.fraction else a.tie>b.tie)
	for i in range(remaining):
		quotas[order[i].index]+=1
	var selected=[]
	for i in range(4):
		_shuffle(bins[i],rng)
		selected.append_array(bins[i].slice(0,quotas[i]))
	var types=KINDS.duplicate()
	_shuffle(types,rng)
	var bag=[]
	for i in range(count):
		bag.append(types[i%3])
	_shuffle(bag,rng)
	_shuffle(selected,rng)
	var panels={}
	for i in range(count):
		panels[selected[i]]=bag[i]
	return panels

static func _shuffle(values: Array, rng: RandomNumberGenerator) -> void:
	for i in range(values.size()-1,0,-1):
		var j=rng.randi_range(0,i)
		var item=values[i]
		values[i]=values[j]
		values[j]=item
