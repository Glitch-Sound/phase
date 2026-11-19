## 確定済みの移動だけを描画用に補間し、モデルへ書き戻さない。
extends RefCounted
const T=preload("res://game/tuning.gd")
var active=false
var actor=-1
var turn=-1
var owner
var source: Dictionary={}
var route: Array=[]
var cpu=false
var elapsed=0.0
var duration=0.0
var result=""

## 表示を始める。battleは所有戦闘、beforeは確定前の行動者、pathは確定経路、via_cpuはCPUか、reducedは動きを抑える設定。戻り値は開始可否。モデルは変更しない。
func begin(battle: RefCounted, before: Dictionary, path: Array, via_cpu: bool=false, reduced: bool=false) -> bool:
	if active:return false
	reset()
	if path.is_empty() or battle.actor<0:return false
	owner=battle;actor=battle.actor;turn=battle.turn
	source=before.duplicate(true);route=path.duplicate();cpu=via_cpu;result=battle.result
	duration=0.0 if reduced else minf(route.size()*T.MOVEMENT_CELL_SECONDS,T.MOVEMENT_MAX_SECONDS)
	active=true
	return true

## 表示を破棄する。戻り値なし。モデルを変更せず、古い表示の到着を無効化する。
func reset() -> void:
	active=false;actor=-1;turn=-1;owner=null;source={};route=[];cpu=false;elapsed=0;duration=0;result=""

## 表示時間を進める。battleは所有戦闘、deltaは実時間差、blockedは中断、speedは表示速度。戻り値は空、arrivedかcancel。戦闘値と保存を変更しない。
func advance(battle: RefCounted, delta: float, blocked: bool, speed: float=1.0) -> String:
	if not active:return ""
	if battle!=owner or battle.turn!=turn or battle.actor!=actor or battle.result!=result:
		reset();return "cancel"
	if blocked or not is_finite(delta) or delta<0 or not is_finite(speed) or speed<=0:return ""
	elapsed=minf(duration,elapsed+delta*speed)
	if elapsed+0.00000001>=duration:
		active=false;return "arrived"
	return ""

## 経路上の描画座標を返す。戻り値はセル単位の連続位置。モデルと配列を変更しない。
func position() -> Vector2:
	if source.is_empty():return Vector2.ZERO
	if route.is_empty():return Vector2(source.pos)
	var progress=1.0 if duration==0 else clampf(elapsed/duration,0,1)
	if progress>=1:return Vector2(route.back())
	var leg=progress*route.size();var index=floori(leg)
	var start=Vector2(source.pos if index==0 else route[index-1])
	return start.lerp(Vector2(route[index]),leg-index)

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
