## 円環領域と指定された決定的な効果量を計算する。
extends RefCounted
const T = preload("res://game/tuning.gd")
const KEYS = ["core", "gear", "arms"]
const NORMAL = [0,1,2,3,4]
const LETTERS = "VIRSL"

## 配分を検証する。statsはVIT順の5値。戻り値は整数範囲と合計の適否。
static func valid_stats(stats: Variant) -> bool:
	if not stats is Array or stats.size()!=5:
		return false
	var total=0
	for value in stats:
		if not (value is int or value is float) or not is_finite(float(value)) or value!=int(value) or value<1 or value>96:
			return false
		total+=int(value)
	return total==100

## 領域配置を返す。uはユニット、ringは内側から0から2。戻り値はステータス番号列。
static func order(u: Dictionary, ring: int) -> Array:
	if ring==0:
		return NORMAL if u.class_name=="STANDARD" else [0,4,3,2,1]
	var mutation: String=u["gear_mutation" if ring==1 else "arms_mutation"]
	if mutation=="NORMAL":
		return NORMAL
	var result=[]
	for letter in mutation:
		result.append(LETTERS.find(letter))
	return result

## 生領域を返す。uはユニット、ringは0から2、statusはVIT順。戻り値は開始角と幅の度数。
static func sector(u: Dictionary, ring: int, status: int) -> Vector2:
	var start=float(u.get("core_angle",0.0)) if ring==0 else float(u["gear_angle" if ring==1 else "arms_angle"])
	var stats: Array=u[KEYS[ring]]
	for k in order(u,ring):
		if k==status:
			return Vector2(fposmod(start,360.0),float(stats[k])*3.6)
		start+=float(stats[k])*3.6
	return Vector2.ZERO

static func _pieces(s: Vector2) -> Array:
	if s.y>=360.0:
		return [Vector2(0,360)]
	var start=fposmod(s.x,360.0)
	var end=start+s.y
	return [Vector2(start,end)] if end<=360.0 else [Vector2(start,360),Vector2(0,end-360)]

## 円弧の共通角を返す。sectorsは開始角と幅の配列、assistは両端の拡張度。戻り値は共通の度数。
static func overlap(sectors: Array, assist: float=0.0) -> float:
	var intersections=[Vector2(0,360)]
	for s in sectors:
		var next=[]
		for p in _pieces(Vector2(s.x-assist,s.y+2.0*assist)):
			for old in intersections:
				var lo=maxf(old.x,p.x)
				var hi=minf(old.y,p.y)
				if hi>lo:
					next.append(Vector2(lo,hi))
		intersections=next
	var total=0.0
	for p in intersections:
		total+=p.y-p.x
	return total

## 許容角を返す。uはユニット。戻り値は最小LUKから計算した度数。
static func tolerance(u: Dictionary) -> float:
	return 3.0*sqrt(minf(u.core[4],minf(u.gear[4],u.arms[4]))/20.0)

## 同期情報を返す。uはユニット、statusはVIT順。戻り値はraw、assisted、wave、factor。
static func sync(u: Dictionary, status: int) -> Dictionary:
	var sectors=[sector(u,0,status),sector(u,1,status),sector(u,2,status)]
	var minimum=minf(sectors[0].y,minf(sectors[1].y,sectors[2].y))
	var tol=tolerance(u)
	var pairs=[]
	for p in [[0,1],[0,2],[1,2]]:
		pairs.append(clampf(overlap([sectors[p[0]],sectors[p[1]]],tol)/minimum,0,1))
	var triple=clampf(overlap(sectors,tol)/minimum,0,1)
	var wave=clampf(0.7*triple+0.2*(pairs[0]+pairs[1]+pairs[2])/3.0+0.1*maxf(pairs[0],maxf(pairs[1],pairs[2])),0,1)
	var assisted=clampf(0.1+1.9*pow(wave,1.5),0.1,2)
	var luk_factor=tol/3.0
	var sigma=(0.45+0.25*luk_factor) if status==2 else (0.40+0.20*luk_factor)
	sigma*=T.SYNC_SIGMA_SCALE
	var input=clampf(assisted,0,1)
	var factor=clampf(0.1+1.9*exp(-pow(1-input,2)/(2*sigma*sigma)),0.1,2)
	return {"raw":clampf(overlap(sectors)/minimum,0,1),"assisted":assisted,"wave":wave,"factor":factor}

## 特異点を判定する。uはユニット。戻り値は生INF幅と開始角の厳密一致。
static func singularity(u: Dictionary) -> bool:
	if u.core[1]>10:
		return false
	var c=sector(u,0,1)
	for r in [1,2]:
		var s=sector(u,r,1)
		# 回転は1.5度刻みであり、この誤差は浮動小数の計算誤差だけを吸収する。
		if absf(s.y-c.y)>0.0000001 or absf(wrapf(s.x-c.x,-180,180))>0.0000001:
			return false
	return true

## 最大HPを返す。uはユニット。戻り値はVIT3係数の積であり端数を保持する。
static func max_hp(u: Dictionary) -> float:
	var hp=T.BASE_HP
	for key in KEYS:
		hp*=maxf(0.25,float(u[key][0])/20.0)
	return hp

## 次回遅延を返す。uはユニット。戻り値はCORE:SPDによる正の時刻差。
static func delay(u: Dictionary) -> float:
	return T.BASE_DELAY*sqrt(20.0/float(u.core[3]))

## パネル進入を適用する。uは現在角と戦闘開始CORE角を持つユニット、panelはNORMAL、RESET、CLOCKWISE、COUNTERCLOCKWISE、ignore_specialはCOREの特殊効果を無視するか、rotation_scaleは装備回転量の倍率。戻り値はなく、3リングの現在角だけを更新する。
static func enter_panel(u: Dictionary, panel: String, ignore_special: bool=false, rotation_scale: float=1.0) -> void:
	if ignore_special:
		panel="NORMAL"
	var gear=-1.5*float(u.gear[3])*rotation_scale
	var arms=1.5*float(u.arms[3])*rotation_scale
	var core=float(u.get("core_angle",0.0))
	if panel=="RESET":
		core=float(u.get("initial_core_angle",0.0))
	elif panel=="CLOCKWISE":
		core+=1.5*float(u.core[3])
	elif panel=="COUNTERCLOCKWISE":
		core-=1.5*float(u.core[3])
	u.core_angle=fposmod(core,360.0)
	u.gear_angle=fposmod(u.gear_angle+gear,360.0)
	u.arms_angle=fposmod(u.arms_angle+arms,360.0)

## 効果量を返す。sourceは行動側、targetは対象、kindはDAMAGEまたはHEAL。戻り値は防御の最終軽減と切捨て後の非負整数。予測では防御を消費しない。
static func effect(source: Dictionary, target: Dictionary, kind: String) -> int:
	var inf=(float(source.core[1])+source.gear[1]+source.arms[1])/60.0
	var power=(T.BASE_DAMAGE if kind=="DAMAGE" else T.BASE_HEAL)*inf*sync(source,1).factor
	if kind=="DAMAGE":
		var resistance=(float(target.core[2])+target.gear[2]+target.arms[2])/60.0
		power/=1.0+resistance*sync(target,2).factor
	if singularity(source):
		power*=5.0
	var amount=floori(power)
	return floori(amount*T.GUARD_DAMAGE_MULTIPLIER) if kind=="DAMAGE" and target.get("guard_active",false) else amount
