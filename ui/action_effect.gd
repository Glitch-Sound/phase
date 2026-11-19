## 確定した攻撃と回復の飛行と局所反応を所有する。戦闘計算と保存は変更しない。
extends RefCounted
const C=preload("res://game/catalog.gd")
const M=preload("res://game/phase_math.gd")
const T=preload("res://game/tuning.gd")
var active=false
var actor=-1
var turn=-1
var result=""
var owner
var command: Dictionary={}
var source: Dictionary={}
var target: Dictionary={}
var units: Array=[]
var cpu=false
var kind=""
var elapsed=0.0
var duration=0.0
var hit=false
var acknowledged=false
var impact_elapsed=0.0
var impact_duration=0.0
var strength=0.0

## 表示を始める。battleは所有戦闘、chosenは確定行動、via_cpuはCPUか、reducedは動きを抑える設定。戻り値は開始可否。HPと手番は変更しない。
func begin(battle: RefCounted,chosen: Dictionary,via_cpu: bool=false,reduced: bool=false) -> bool:
	if active:return false
	reset()
	var skill=chosen.get("skill","")
	var effect=C.SKILLS.get(skill,{}).get("effect","")
	var index=int(chosen.get("target",-1))
	if effect not in ["DAMAGE","HEAL"] or battle.mode!="TARGET" or battle.selected_skill!=skill or not battle.valid_target(battle.actor,index,skill):return false
	owner=battle;actor=battle.actor;turn=battle.turn;result=battle.result
	command=chosen.duplicate(true);command.actor=actor
	source=battle.units[actor].duplicate(true);target=battle.units[index].duplicate(true)
	units=battle.units.duplicate(true);kind=effect;cpu=via_cpu
	var distance=Vector2(source.pos).distance_to(Vector2(target.pos))
	duration=0.0 if reduced else minf(T.ACTION_FLIGHT_BASE_SECONDS+maxf(0,distance-1)*T.ACTION_FLIGHT_CELL_SECONDS,T.ACTION_FLIGHT_MAX_SECONDS)
	impact_duration=0.0 if reduced else (T.ACTION_DAMAGE_REACTION_SECONDS if kind=="DAMAGE" else T.ACTION_HEAL_REACTION_SECONDS)
	strength=clampf(M.sync(source,1).factor-1,0,1)*T.ACTION_STRONG_EMPHASIS
	active=true
	return true

## 時間を進める。battleは所有戦闘、deltaは実時間、blockedは中断、speedは表示速度。戻り値は空、hit、doneかcancel。到達の通知だけを返し、モデルを変えない。
func advance(battle: RefCounted,delta: float,blocked: bool,speed: float=1.0) -> String:
	if not active:return ""
	if battle!=owner or battle.actor!=actor or battle.turn!=turn or battle.result!=result:
		reset();return "cancel"
	if blocked or not is_finite(delta) or delta<0 or not is_finite(speed) or speed<=0:return ""
	if not hit:
		elapsed=minf(duration,elapsed+delta*speed)
		if elapsed+0.00000001<duration:return ""
		hit=true
		return "hit"
	if not acknowledged:return ""
	impact_elapsed=minf(impact_duration,impact_elapsed+delta*speed)
	if impact_elapsed+0.00000001<impact_duration:return ""
	active=false
	return "done"

## 一度のモデル実行後に所有を更新する。battleは実行した戦闘。戻り値なし。終局も反応の間だけ保持する。
func confirm_result(battle: RefCounted) -> void:
	if not active or not hit or acknowledged or battle!=owner:return
	acknowledged=true;actor=battle.actor;turn=battle.turn;result=battle.result

## 表示を捨てる。戻り値なし。未到達の行動を実行しない。
func reset() -> void:
	active=false;actor=-1;turn=-1;result="";owner=null;command={};source={};target={};units=[];cpu=false;kind=""
	elapsed=0;duration=0;hit=false;acknowledged=false;impact_elapsed=0;impact_duration=0;strength=0

## 描画用の独立した線分を返す。boardは論理盤面、cellはセル寸法、clearanceは光の太さを含むリング外形。戻り値は線分、先端、反応の透明度。全ユニットと盤外を避ける。
func geometry(board: Rect2,cell: float,clearance: float) -> Dictionary:
	var view={"lines":[],"tip":[],"alpha":1.0,"kind":kind,"strength":strength}
	if not active:return view
	var a=board.position+(Vector2(source.pos)+Vector2.ONE*0.5)*cell
	var z=board.position+(Vector2(target.pos)+Vector2.ONE*0.5)*cell
	var normal=(z-a).normalized().orthogonal()
	var bend=minf(a.distance_to(z)*T.ACTION_CURVE_BEND,cell*T.ACTION_CURVE_BEND)
	var control=(a+z)*0.5+normal*bend
	if not board.grow(-T.ACTION_HALO_WIDTH).has_point(control):control=(a+z)*0.5-normal*bend
	var lo=0.0;var hi=0.5
	for i in range(20):
		var mid=(lo+hi)*0.5
		if _point(a,control,z,mid).distance_to(a)<clearance:lo=mid
		else:hi=mid
	var first=hi
	lo=0.5;hi=1.0
	for i in range(20):
		var mid=(lo+hi)*0.5
		if _point(a,control,z,mid).distance_to(z)>clearance:lo=mid
		else:hi=mid
	var last=lo
	var raw=[]
	if not hit:
		var progress=1.0 if duration==0 else clampf(elapsed/duration,0,1)
		var finish=lerpf(first,last,progress)
		var start=lerpf(first,last,maxf(0,progress-T.ACTION_TAIL_FRACTION))
		for i in range(T.ACTION_CURVE_SEGMENTS):
			raw.append([_point(a,control,z,lerpf(start,finish,float(i)/T.ACTION_CURVE_SEGMENTS)),_point(a,control,z,lerpf(start,finish,float(i+1)/T.ACTION_CURVE_SEGMENTS))])
		view.lines=_clip(raw,board,cell,clearance)
		view.tip=view.lines.slice(-2)
	else:
		var progress=1.0 if impact_duration==0 else clampf(impact_elapsed/impact_duration,0,1)
		view.alpha=pow(1-progress,1.3 if kind=="DAMAGE" else 0.8)
		var angle=(_point(a,control,z,last)-z).angle()
		var radius=clearance+T.ACTION_REACTION_GAP+progress*T.ACTION_REACTION_SPREAD*(1+strength)
		if kind=="DAMAGE":
			for offset in [-0.30,0.0,0.30]:
				var direction=Vector2.from_angle(angle+offset)
				raw.append([z+direction*radius,z+direction*(radius+T.ACTION_REACTION_SPREAD*(1+strength)*(1-progress*0.4))])
		else:
			for offset in [-0.55,0.55]:
				for i in range(12):
					var start=angle+offset-0.22+float(i)/12*0.44
					var finish=start+0.44/12
					raw.append([z+Vector2.from_angle(start)*radius,z+Vector2.from_angle(finish)*radius])
		view.lines=_clip(raw,board,cell,clearance)
	return view

func _point(a: Vector2,c: Vector2,z: Vector2,t: float) -> Vector2:
	return a.lerp(c,t).lerp(c.lerp(z,t),t)

func _clip(lines: Array,board: Rect2,cell: float,clearance: float) -> Array:
	var output=[]
	var bounds=board.grow(-T.ACTION_HALO_WIDTH)
	for line in lines:
		var start: Vector2=line[0];var finish: Vector2=line[1]
		var delta=finish-start;var low=0.0;var high=1.0
		for axis in range(2):
			if absf(delta[axis])<0.000001:
				if start[axis]<bounds.position[axis] or start[axis]>bounds.end[axis]:high=-1
			else:
				var t0=(bounds.position[axis]-start[axis])/delta[axis]
				var t1=(bounds.end[axis]-start[axis])/delta[axis]
				low=maxf(low,minf(t0,t1));high=minf(high,maxf(t0,t1))
		if high<=low:continue
		var pieces=[[start+delta*low,start+delta*high]]
		for u in units:
			if u.hp<=0:continue
			var center=board.position+(Vector2(u.pos)+Vector2.ONE*0.5)*cell
			var next=[]
			for piece in pieces:
				var axis=(piece[1]-piece[0]).normalized();var length=piece[0].distance_to(piece[1])
				if length<0.000001:continue
				var along=(center-piece[0]).dot(axis)
				var side=maxf(0,(center-piece[0]).length_squared()-along*along)
				if side>=clearance*clearance or along+clearance<=0 or along-clearance>=length:next.append(piece)
				else:
					var half=sqrt(clearance*clearance-side)
					var begin=clampf(along-half,0,length);var end=clampf(along+half,0,length)
					if begin>0.000001:next.append([piece[0],piece[0]+axis*begin])
					if end<length-0.000001:next.append([piece[0]+axis*end,piece[1]])
			pieces=next
		output.append_array(pieces)
	return output
