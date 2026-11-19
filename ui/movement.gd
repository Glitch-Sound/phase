## 確定済みの移動だけを描画用に補間し、モデルへ書き戻さない。
extends RefCounted
const T=preload("res://game/tuning.gd")
const B=preload("res://game/battle.gd")
const F=preload("res://game/rotation_field.gd")
const C=preload("res://game/catalog.gd")
var active=false
var actor=-1
var turn=-1
var owner
var source: Dictionary={}
var route: Array=[]
var cpu=false
var elapsed=0.0
var duration=0.0
var landed=false
var beat_duration=0.0
var beat_elapsed=0.0
var departure_duration=0.0
var departure_elapsed=0.0
var reveal_elapsed=0.0
var result=""
var samples: Array=[]
var deltas: Array=[]

## 表示を始める。battleは所有戦闘、beforeは確定前の行動者、pathは確定経路、via_cpuはCPUか、reducedは動きを抑える設定、attackは攻撃前の一拍を使うか。戻り値は開始可否。モデルは変更しない。
func begin(battle: RefCounted, before: Dictionary, path: Array, via_cpu: bool=false, reduced: bool=false, attack: bool=false) -> bool:
	if active:return false
	reset()
	if path.is_empty() or battle.actor<0:return false
	owner=battle;actor=battle.actor;turn=battle.turn
	source=before.duplicate(true);route=path.duplicate();cpu=via_cpu;result=battle.result
	samples=[source.duplicate(true)]
	for cell in route:
		var u: Dictionary=samples.back().duplicate(true)
		var scale=F.resolve(u,cell,battle.units).factor
		var panel=battle.panels.get(cell,"NORMAL")
		B.enter_cell(u,cell,panel,battle.units)
		u.moved=samples.size()
		var core_delta=0.0
		if not source.skills.has(C.IGNORE_PANEL):
			if panel=="CLOCKWISE":core_delta=source.core[3]*1.5
			elif panel=="COUNTERCLOCKWISE":core_delta=-source.core[3]*1.5
			elif panel=="RESET":core_delta=fposmod(u.core_angle-samples.back().core_angle+180,360)-180
		deltas.append([core_delta,-source.gear[3]*1.5*scale,source.arms[3]*1.5*scale])
		samples.append(u)
	duration=0.0 if reduced else minf(route.size()*T.MOVEMENT_CELL_SECONDS,T.MOVEMENT_MAX_SECONDS)
	beat_duration=T.MOVEMENT_ATTACK_BEAT_SECONDS if attack and not reduced else 0.0
	departure_duration=T.MOVEMENT_CLOUD_OUT_SECONDS if not reduced and not F.types(source).is_empty() else 0.0
	active=true
	return true

## 表示を破棄する。戻り値なし。モデルを変更せず、古い表示の到着を無効化する。
func reset() -> void:
	active=false;actor=-1;turn=-1;owner=null;source={};route=[];cpu=false;elapsed=0;duration=0;result="";samples=[];deltas=[]
	landed=false;beat_duration=0;beat_elapsed=0
	departure_duration=0;departure_elapsed=0;reveal_elapsed=0

## 表示時間を進める。battleは所有戦闘、deltaは実時間差、blockedは中断、speedは表示速度。戻り値は空、攻撃前の着地landed、完了arrivedかcancel。戦闘値と保存を変更しない。
func advance(battle: RefCounted, delta: float, blocked: bool, speed: float=1.0) -> String:
	if not active:return ""
	if battle!=owner or battle.turn!=turn or battle.actor!=actor or battle.result!=result:
		reset();return "cancel"
	if blocked or not is_finite(delta) or delta<0 or not is_finite(speed) or speed<=0:return ""
	var remaining=delta*speed
	if departure_elapsed<departure_duration:
		var fading=minf(remaining,departure_duration-departure_elapsed)
		departure_elapsed+=fading;remaining=maxf(0,remaining-fading)
		if departure_elapsed+0.00000001<departure_duration:return ""
		departure_elapsed=departure_duration
	if not landed:
		var travel=maxf(0,duration-elapsed)
		elapsed=minf(duration,elapsed+remaining)
		if elapsed+0.00000001<duration:return ""
		elapsed=duration;landed=true
		remaining=maxf(0,remaining-travel)
		beat_elapsed=minf(beat_duration,remaining)
		reveal_elapsed=remaining
		if beat_elapsed+0.00000001<beat_duration:return "landed"
	else:
		beat_elapsed=minf(beat_duration,beat_elapsed+remaining)
		reveal_elapsed+=remaining
		if beat_elapsed+0.00000001<beat_duration:return ""
	active=false
	return "arrived"

## 完了後の雲だけを進める。deltaは表示時間、blockedは停止、speedは表示倍率。戻り値なし。行動の開始を遅らせず、戦闘を変更しない。
func advance_cloud(delta: float, blocked: bool, speed: float=1.0) -> void:
	if active or not landed or blocked or not is_finite(delta) or delta<0 or not is_finite(speed) or speed<=0:return
	reveal_elapsed=minf(T.MOVEMENT_CLOUD_IN_SECONDS,reveal_elapsed+delta*speed)

## 発生源の雲の不透明度を返す。uは表示する発生源。戻り値は0から1で他者と0歩は常に1。実際の周囲効果を変更しない。
func cloud_alpha(u: Dictionary) -> float:
	if source.is_empty() or departure_duration==0 or u.id!=source.id or u.camp!=source.camp:return 1.0
	if landed:return smoothstep(0,1,clampf(reveal_elapsed/T.MOVEMENT_CLOUD_IN_SECONDS,0,1))
	return 1.0-smoothstep(0,1,clampf(departure_elapsed/departure_duration,0,1)) if active else 1.0

## 経路上の描画座標を返す。戻り値はセル単位の連続位置。モデルと配列を変更しない。
func position() -> Vector2:
	if source.is_empty():return Vector2.ZERO
	if route.is_empty():return Vector2(source.pos)
	var leg=_leg_progress()
	if leg>=route.size():return Vector2(route.back())
	var index=floori(leg)
	var start=Vector2(source.pos if index==0 else route[index-1])
	return start.lerp(Vector2(route[index]),leg-index)

## 各歩の表示ユニットを返す。戻り値は補間した独立辞書。実計算と保存は変更しない。
func unit() -> Dictionary:
	if samples.is_empty():return source.duplicate(true)
	var leg=_leg_progress()
	if leg>=route.size():return samples.back().duplicate(true)
	var index=floori(leg)
	var u: Dictionary=samples[index].duplicate(true)
	for ring in range(3):
		var key=["core_angle","gear_angle","arms_angle"][ring]
		u[key]=fposmod(u.get(key,0.0)+deltas[index][ring]*(leg-index),360)
	return u

# 歩内の速度は1-a*cos(2πt)で常に正。各整数時刻と全体の尺は元の時計のままにする。
func _leg_progress() -> float:
	var leg=(1.0 if duration==0 else clampf(elapsed/duration,0,1))*route.size()
	var whole=floorf(leg);var local=leg-whole
	return whole+local-T.MOVEMENT_CELL_PULSE*sin(TAU*local)/TAU

## 白線の部分を返す。clearanceはセル単位のリング外形と余白。戻り値は移動中の円を除いた線分。モデルは変更しない。
func segments(clearance: float) -> Array:
	var lines=[];var start=Vector2(source.pos);var center=position()
	for cell in route:
		var finish=Vector2(cell);var axis=(finish-start).normalized();var length=start.distance_to(finish)
		var along=(center-start).dot(axis)
		var side=maxf(0,(center-start).length_squared()-along*along)
		if side>=clearance*clearance or along+clearance<=0 or along-clearance>=length:
			lines.append([start,finish])
		else:
			var half=sqrt(clearance*clearance-side)
			var low=clampf(along-half,0,length);var high=clampf(along+half,0,length)
			if low>0.000001:lines.append([start,start+axis*low])
			if high<length-0.000001:lines.append([start+axis*high,finish])
		start=finish
	return lines
