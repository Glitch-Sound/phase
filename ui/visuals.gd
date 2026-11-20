## 実際の位相配置をリングと共通角度空間の円形予測へ描画する。
extends RefCounted

## 作用する同心円を返す。ageは表示秒、target_radiusは対象外周、healingは中心から広がる回復か。戻り値は時間差のある半径と透明度。戦闘値は参照も変更もしない。
static func convergence_rings(age: float,target_radius: float,healing: bool=false) -> Array:
	var rings=[]
	for index in range(T.CONVERGENCE_COUNT):
		var local=age-index*T.CONVERGENCE_STAGGER_SECONDS
		if local<0 or local>=T.CONVERGENCE_TRAVEL_SECONDS:continue
		var progress=local/T.CONVERGENCE_TRAVEL_SECONDS
		var radius=lerpf(target_radius*T.CONVERGENCE_OUTER_SCALE,target_radius,progress)
		if healing:
			radius=lerpf(target_radius*T.CONVERGENCE_HEAL_START_SCALE,target_radius*T.CONVERGENCE_OUTER_SCALE,pow(progress,T.CONVERGENCE_HEAL_EASE_POWER))
		rings.append({"radius":radius,"alpha":T.CONVERGENCE_ALPHA*(1-smoothstep(0.75,1.0,progress))})
	return rings

## 回復円の接触反応を返す。ageは表示秒、target_radiusは既存円の終点、unit_radiusは記号半径、kindは効果、gain_fromとgain_toは実HP増分の割合。戻り値は1回減衰する増分円弧、攻撃と非表示なら空。戦闘値は変更しない。
static func ring_response(age: float,target_radius: float,unit_radius: float,kind: String,gain_from: float,gain_to: float) -> Dictionary:
	if not is_finite(age) or kind!="HEAL":return {}
	gain_from=clampf(gain_from,0,1);gain_to=clampf(gain_to,0,1)
	if gain_to<=gain_from:return {}
	var radius=unit_radius*T.UNIT_HP_RADIUS
	var inner=target_radius*T.CONVERGENCE_HEAL_START_SCALE;var outer=target_radius*T.CONVERGENCE_OUTER_SCALE
	var begin=T.CONVERGENCE_TRAVEL_SECONDS*pow(clampf((radius-inner)/maxf(0.001,outer-inner),0,1),1.0/T.CONVERGENCE_HEAL_EASE_POWER)
	var progress=(age-begin)/T.RING_RESPONSE_HEAL_SECONDS
	if progress < -0.00000001 or progress>=1:return {}
	return {"radius":radius,"start_angle":-PI/2+TAU*gain_from,"arc_angle":TAU*(gain_to-gain_from),"width":T.RING_RESPONSE_HEAL_WIDTH,"alpha":T.RING_RESPONSE_HEAL_ALPHA*(1-smoothstep(0.0,1.0,clampf(progress,0,1)))}

## 円の可視輪郭を返す。centerは固定中心、radiusは半径、boundsは盤内、masksはユニット外形と名前の矩形、start_angleとarc_angleは表示区間。戻り値は盤外と識別領域を避けた連続線の配列。描画とモデルを変更しない。
static func convergence_segments(center: Vector2,radius: float,bounds: Rect2,masks: Array,start_angle: float=0,arc_angle: float=TAU) -> Array:
	var paths=[];var path=PackedVector2Array()
	for index in range(T.CONVERGENCE_SEGMENTS):
		var a=center+Vector2.from_angle(start_angle+arc_angle*index/T.CONVERGENCE_SEGMENTS)*radius
		var b=center+Vector2.from_angle(start_angle+arc_angle*(index+1)/T.CONVERGENCE_SEGMENTS)*radius
		var clear=bounds.has_point(a) and bounds.has_point(b)
		for mask in masks:
			if mask.has("rect"):
				if _crosses_name(a,b,mask.rect):clear=false;break
			elif Geometry2D.get_closest_point_to_segment(mask.center,a,b).distance_to(mask.center)<mask.radius:clear=false;break
		if clear:
			if path.is_empty():path.append(a)
			path.append(b)
		elif not path.is_empty():paths.append(path);path=PackedVector2Array()
	if not path.is_empty():paths.append(path)
	return paths

static func _crosses_name(a: Vector2,b: Vector2,rect: Rect2) -> bool:
	if rect.has_point(a) or rect.has_point(b):return true
	if maxf(a.x,b.x)<rect.position.x or minf(a.x,b.x)>rect.end.x or maxf(a.y,b.y)<rect.position.y or minf(a.y,b.y)>rect.end.y:return false
	var corners=[rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)]
	for i in range(4):
		if Geometry2D.segment_intersects_segment(a,b,corners[i],corners[(i+1)%4])!=null:return true
	return false
const M = preload("res://game/phase_math.gd")
const I=preload("res://game/unit_identity.gd")
const A=preload("res://game/assembly_identity.gd")
const P = preload("res://ui/palette.gd")
const TEXT = P.TEXT
const T = preload("res://game/tuning.gd")

## 表示名を返す。uは内部IDと陣営を持つユニット。戻り値は表示専用の名前。副作用なし。
static func unit_name(u: Dictionary) -> String:
	return I.effective_name(str(u.get("display_name","")),u.id,u.camp)

## ユニット記号を記述する。radiusは基準半径、uは現在配置、selectedは行動中、colorsは5色、accentは行動色、assemblyは独立した所属設定。戻り値は円弧と目盛り、中央の紋章と防御図形の描画データ。副作用なし。
static func glyph(radius: float, u: Dictionary, selected: bool, colors: Array, accent: Color,assembly: Dictionary={}) -> Dictionary:
	if assembly.is_empty():assembly=A.default_profile(u.camp)
	var arcs=[]
	for r in range(3):
		var rad=radius*T.UNIT_RING_RADII[r]
		for status in range(5):
			var sector=M.sector(u,r,status)
			var start=deg_to_rad(sector.x-90)
			var end=deg_to_rad(sector.x+sector.y-90)
			var gap=minf(maxf(T.UNIT_SECTOR_GAP,radius*T.UNIT_SECTOR_GAP_RATIO)/rad,(end-start)*T.UNIT_GAP_MAX_FRACTION)
			arcs.append({"role":["CORE","GEAR","ARMS"][r],"radius":rad,"start":start+gap/2,"end":end-gap/2,"color":colors[status],"width":maxf(T.UNIT_MIN_LINE,radius*T.UNIT_RING_WIDTH)})
	var health=clampf(u.hp/maxf(1.0,u.max_hp),0.0,1.0)
	if health>0:
		arcs.append({"role":"HP","radius":radius*T.UNIT_HP_RADIUS,"start":-PI/2,"end":-PI/2+TAU*health,"color":A.color(assembly),"width":maxf(T.UNIT_HP_MIN_LINE,radius*T.UNIT_HP_WIDTH)})
	var guard={}
	if u.get("guard_active",false) and u.hp>0:
		var points=[]
		for i in range(T.UNIT_GUARD_SIDES):
			points.append(Vector2.from_angle(-PI/2-PI/T.UNIT_GUARD_SIDES+TAU*i/T.UNIT_GUARD_SIDES)*radius*T.UNIT_GUARD_RADIUS)
		guard={"points":points,"fill":Color(TEXT,T.UNIT_GUARD_FILL_ALPHA),"color":Color(accent,T.UNIT_GUARD_LINE_ALPHA),"width":radius*T.UNIT_GUARD_WIDTH}
	return {"guard":guard,"arcs":arcs,"tick":{"from":Vector2(0,-radius*T.UNIT_TICK_RADII.x),"to":Vector2(0,-radius*T.UNIT_TICK_RADII.y),"color":accent if selected else TEXT,"width":maxf(T.UNIT_MIN_LINE,radius*T.UNIT_TICK_WIDTH)},"name":"","identicon":I.recipe(unit_name(u),u.get("identicon_version",I.VERSION)),"identicon_color":A.color(assembly),"identicon_radius":radius*T.UNIT_IDENTICON_RADIUS,"font_size":maxi(T.UNIT_NAME_MIN,roundi(radius*T.UNIT_NAME_SIZE))}

## 記号を描く。canvasは描画先、centerは中心、radiusは基準半径、uは現在配置、selectedは行動中、colorsは5色、accentは行動色、typefaceは共通フォント、assemblyは独立した所属設定。戻り値なし。副作用は描画。
static func ring(canvas: CanvasItem, center: Vector2, radius: float, u: Dictionary, selected: bool, colors: Array, accent: Color, typeface: Font,assembly: Dictionary={}) -> void:
	var g=glyph(radius,u,selected,colors,accent,assembly)
	# viewport_transformはRetinaを含む実描画倍率を既に持つ。OSのDPIを追加で掛けない。
	var scale_px=(canvas.get_viewport_transform()*canvas.get_global_transform()).get_scale().x
	if not g.guard.is_empty():
		var points=PackedVector2Array()
		for point in g.guard.points:
			points.append(center+point)
		canvas.draw_colored_polygon(points,g.guard.fill)
		points.append(points[0])
		canvas.draw_polyline(points,g.guard.color,maxf(g.guard.width,T.UNIT_GUARD_PIXEL_MIN/maxf(0.001,scale_px)),true)
	for arc in g.arcs:
		var style=stroke_style(arc,scale_px)
		canvas.draw_arc(center,arc.radius,arc.start,arc.end,style.points,arc.color,style.width,true)
	canvas.draw_line(center+g.tick.from,center+g.tick.to,g.tick.color,g.tick.width,true)
	_identicon(canvas,center,g.identicon_radius,g.identicon,Color(g.identicon_color,T.UNIT_IDENTICON_ALPHA))

## ユニット紋章だけを描く。canvasは描画先、centerとradiusは位置と半径、uとassemblyは独立したユニットと所属の表示設定。副作用は描画だけ。
static func unit_emblem(canvas: CanvasItem,center: Vector2,radius: float,u: Dictionary,assembly: Dictionary={}) -> void:
	if assembly.is_empty():assembly=A.default_profile(u.camp)
	_identicon(canvas,center,radius,I.recipe(unit_name(u),u.get("identicon_version",I.VERSION)),Color(A.color(assembly),T.UNIT_IDENTICON_ALPHA))

static func _identicon(canvas: CanvasItem,center: Vector2,radius: float,shape: Dictionary,color: Color) -> void:
	var scale_px=maxf(0.001,(canvas.get_viewport_transform()*canvas.get_global_transform()).get_scale().x)
	for polygon in shape.get("polygons",[]):
		var points=PackedVector2Array()
		for point in polygon:points.append(center+point*radius)
		canvas.draw_colored_polygon(points,color)
		points.append(points[0])
		canvas.draw_polyline(points,color,maxf(T.UNIT_IDENTICON_EDGE,T.UNIT_IDENTICON_PIXEL_MIN/maxf(0.001,scale_px)),true)

## 所属紋章を描く。canvasは描画先、centerは中心、radiusは半径、profileは表示設定、campは空欄の既定陣営。戻り値なし。副作用は描画だけ。
static func assembly_emblem(canvas: CanvasItem,center: Vector2,radius: float,profile: Dictionary,camp: String="PLAYER") -> void:
	var shape=A.recipe(A.label(profile,camp),profile.get("version",A.VERSION))
	var ink=A.color(profile)
	var scale_px=maxf(0.001,(canvas.get_viewport_transform()*canvas.get_global_transform()).get_scale().x)
	for polygon in shape.get("polygons",[]):
		var points=PackedVector2Array()
		for point in polygon:points.append(center+point*radius)
		canvas.draw_colored_polygon(points,ink);points.append(points[0])
		canvas.draw_polyline(points,ink,maxf(T.ASSEMBLY_EMBLEM_EDGE,T.ASSEMBLY_EMBLEM_PIXEL_MIN/scale_px),true)

## 物理描画に適した線を返す。arcは円弧の記述、pixel_scaleは論理1pxに対応する物理倍率。戻り値は線幅と頂点数。副作用なし。
static func stroke_style(arc: Dictionary, pixel_scale: float) -> Dictionary:
	var scale=maxf(0.001,pixel_scale)
	var floor_px=T.UNIT_HP_PIXEL_MIN if arc.role=="HP" else T.UNIT_COLOR_PIXEL_MIN
	var step=2*acos(clampf(1-T.UNIT_ARC_ERROR_PIXELS/(arc.radius*scale),-1,1))
	return {"width":maxf(arc.width,floor_px/scale),"points":maxi(3,ceili((arc.end-arc.start)/maxf(0.001,step))+1)}

## 局所位相を返す。uは予測ユニット、angleは上端を0とする度数、colorsは基本5色。戻り値は3領域と山の高さ、生領域の一致度と混色。副作用なし。
static func phase_field(u: Dictionary, angle: float, colors: Array) -> Dictionary:
	return _phase_field(_sectors(u),angle,colors)

static func _sectors(u: Dictionary) -> Array:
	var sectors=[]
	for r in range(3):
		var row=[]
		for status in range(5):
			row.append(M.sector(u,r,status))
		sectors.append(row)
	return sectors

static func _phase_field(sectors: Array, angle: float, colors: Array) -> Dictionary:
	var roles=[]
	var profiles=[]
	for r in range(3):
		var nearest=INF
		var role=0
		for status in range(5):
			var sector: Vector2=sectors[r][status]
			var local=fposmod(angle-sector.x,360.0)
			# 開始境界の循環順で所属を決め、Vector2の丸めで隣接領域に微小な隙間を作らない。
			if local<nearest:
				nearest=local;role=status
		roles.append(role)
		profiles.append(pow(sin(PI*clampf(nearest/sectors[r][role].y,0,1)),2))
	var clarity=0.0
	var height=0.0
	var mixed=Color(0,0,0,0)
	for status in range(5):
		var a=1.0 if roles[0]==status else 0.0
		var b=1.0 if roles[1]==status else 0.0
		var c=1.0 if roles[2]==status else 0.0
		var pair=(minf(a,b)+minf(a,c)+minf(b,c))/3.0
		var peak=maxf(minf(a,b),maxf(minf(a,c),minf(b,c)))
		var weight=0.7*minf(a,minf(b,c))+0.2*pair+0.1*peak
		var ah=a*profiles[0]
		var bh=b*profiles[1]
		var ch=c*profiles[2]
		clarity+=weight
		height+=0.7*minf(ah,minf(bh,ch))+0.2*(minf(ah,bh)+minf(ah,ch)+minf(bh,ch))/3.0+0.1*maxf(minf(ah,bh),maxf(minf(ah,ch),minf(bh,ch)))
		mixed+=colors[status]*weight
	return {"roles":roles,"profiles":profiles,"clarity":clarity,"height":height,"color":mixed/clarity if clarity>0 else P.MUTED}

## 閉じた4輪郭を返す。uは予測ユニット、colorsは基本5色。戻り値はCORE、GEAR、ARMS、結果の局所座標、頂点色、線幅と動きの包絡。副作用なし。
static func phase_contours(u: Dictionary, colors: Array) -> Array:
	var sectors=_sectors(u)
	var boundaries=[]
	for row in sectors:
		for sector in row:
			var boundary=fposmod(sector.x,360.0)
			if not boundaries.any(func(value):return is_equal_approx(value,boundary)):
				boundaries.append(boundary)
	boundaries.sort()
	var curves=[]
	var speeds=[]
	for r in range(3):
		var speed=T.PREVIEW_MOTION_RATE*sqrt(float(u[M.KEYS[r]][3])/20.0)*T.PREVIEW_RATE_BIASES[r]
		while speeds.any(func(other):return absf(other-speed)<T.PREVIEW_RATE_GAP):
			speed+=T.PREVIEW_RATE_GAP
		speeds.append(speed)
	for r in range(4):
		curves.append({"role":["CORE","GEAR","ARMS","RESULT"][r],"points":PackedVector2Array(),"colors":PackedColorArray(),"width":T.PREVIEW_RESULT_LINE if r==3 else T.PREVIEW_LINE,"envelope":PackedFloat32Array(),"speed":speeds[r] if r<3 else 0.0})
	var directions=PackedVector2Array()
	var basis=PackedVector2Array()
	var profiles=PackedVector3Array()
	var result_boost=PackedFloat32Array()
	var clarity_sum=0.0
	for sample in range(T.PREVIEW_SAMPLES+1):
		# 最後の点は0度を再利用し、色と形の継ぎ目を一致させる。
		var angle=(sample%T.PREVIEW_SAMPLES)*360.0/T.PREVIEW_SAMPLES
		var field=_phase_field(sectors,angle,colors)
		if sample<T.PREVIEW_SAMPLES:
			clarity_sum+=clampf(field.clarity,0,1)
		var paint=_phase_paint(sectors,boundaries,angle,colors,field)
		var strength=sqrt(clampf(paint.clarity,0,1))
		var gain=lerpf(T.PREVIEW_MIN_GAIN,1.0,strength)
		result_boost.append(smoothstep(T.PREVIEW_RESULT_BOOST_START,1.0,clampf(paint.clarity,0,1)))
		var radians=deg_to_rad(angle)
		var direction=Vector2.from_angle(radians-PI/2)
		directions.append(direction)
		# .5sin(p)+.3sin(2θ-p)+.2sin(3θ+p)を2成分へまとめる。
		basis.append(Vector2(0.5-0.3*cos(2*radians)+0.2*cos(3*radians),0.3*sin(2*radians)+0.2*sin(3*radians)))
		profiles.append(Vector3(field.profiles[0],field.profiles[1],field.profiles[2]))
		for r in range(4):
			var height=field.profiles[r] if r<3 else field.height
			var color: Color=paint.colors[r]
			color.a=lerpf(T.PREVIEW_BASE_ALPHA,T.PREVIEW_CLEAR_ALPHA,sqrt(clampf(paint.clarity,0,1))) if r<3 else lerpf(T.PREVIEW_RESULT_BASE_ALPHA,T.PREVIEW_RESULT_CLEAR_ALPHA,sqrt(clampf(paint.clarity,0,1)))
			curves[r].points.append(direction*(T.PREVIEW_RADII[r]+height*T.PREVIEW_AMPLITUDES[r]*gain))
			curves[r].colors.append(color)
			curves[r].envelope.append(gain*(0.45+0.55*field.profiles[r]) if r<3 else lerpf(T.PREVIEW_RESULT_MIN_GAIN,1.0,strength)*(0.45+0.55*field.height))
	# 線幅は実際の全周平均に従い、毎フレームの乱数や時間では変えない。
	var mean_strength=sqrt(clarity_sum/T.PREVIEW_SAMPLES)
	for r in range(4):
		curves[r].width=lerpf(T.PREVIEW_LINE,T.PREVIEW_LINE_MAX,mean_strength) if r<3 else lerpf(T.PREVIEW_RESULT_LINE,T.PREVIEW_RESULT_LINE_MAX,mean_strength)
	curves[3].directions=directions
	curves[3].basis=basis
	curves[3].profiles=profiles
	curves[3].boost=_smooth_result_mask(result_boost)
	curves[3].pulse_speed=(speeds[0]+speeds[1]+speeds[2])/3*T.PREVIEW_RESULT_RATE_SCALE
	var pulse_ranges=PackedVector2Array()
	for direction in directions:
		pulse_ranges.append(_result_pulse_range(direction,curves[3].width))
	curves[3].pulse_ranges=pulse_ranges
	return curves

## 周期的な座標を返す。curvesは実位相のキャッシュ、secondsは表示時間。戻り値は4本の閉曲線。入力と戦闘値を変更しない。
static func motion_points(curves: Array, seconds: float) -> Array:
	var result=[PackedVector2Array(),PackedVector2Array(),PackedVector2Array(),PackedVector2Array()]
	var oscillators=[]
	for r in range(3):
		var phase=fposmod(seconds,TAU/curves[r].speed)*curves[r].speed+T.PREVIEW_MOTION_PHASES[r]
		oscillators.append(Vector2(sin(phase),cos(phase)))
	var shared: Dictionary=curves[3]
	# 一つの時計を全角度で共有し、局所の一致区間は移動させない。
	var phase=fposmod(seconds,TAU/shared.pulse_speed)*shared.pulse_speed
	var breath=(1-cos(phase))/2
	for i in range(shared.directions.size()):
		var direction: Vector2=shared.directions[i]
		var wave_basis: Vector2=shared.basis[i]
		var waves=Vector3(wave_basis.dot(oscillators[0]),wave_basis.dot(oscillators[1]),wave_basis.dot(oscillators[2]))
		for r in range(3):
			result[r].append(direction*(T.PREVIEW_RADII[r]+T.PREVIEW_AMPLITUDES[r]*curves[r].envelope[i]*waves[r]))
		var weights: Vector3=Vector3.ONE*0.25+shared.profiles[i]*0.75
		var combined=waves.dot(weights)/(weights.x+weights.y+weights.z)
		var displacement=T.PREVIEW_AMPLITUDES[3]*curves[3].envelope[i]*combined
		if shared.boost[i]>0:
			var limits: Vector2=shared.pulse_ranges[i]
			displacement=lerpf(displacement,lerpf(limits.x,limits.y,breath),shared.boost[i])
		result[3].append(direction*(T.PREVIEW_RADII[3]+displacement))
	return result

# 対称な循環平均をキャッシュ生成時だけ行う。色は平滑化せず実際の一致のまま描く。
static func _smooth_result_mask(raw: PackedFloat32Array) -> PackedFloat32Array:
	var count=T.PREVIEW_SAMPLES
	var radius=maxi(1,roundi(T.PREVIEW_RESULT_MASK_HALF_DEGREES*count/360/T.PREVIEW_RESULT_MASK_PASSES))
	var values=raw.slice(0,count)
	for _pass in range(T.PREVIEW_RESULT_MASK_PASSES):
		var next=PackedFloat32Array()
		var total=0.0
		for j in range(-radius,radius+1):total+=values[posmod(j,count)]
		for i in range(count):
			next.append(total/(2*radius+1))
			total+=values[posmod(i+radius+1,count)]-values[posmod(i-radius,count)]
		values=next
	values.append(values[0])
	return values

# 円と矩形の交差を滑らかなノルムで内包する。動きを上限へ押しつぶさず包絡を先に決める。
static func _result_pulse_range(direction: Vector2,width: float) -> Vector2:
	var margin=width/2+T.PREVIEW_RESULT_CLEARANCE
	var bounds=T.PREVIEW_RESULT_BOUNDS.grow(-margin)
	var power=T.PREVIEW_RESULT_BOUND_POWER
	var reciprocal=pow(1/(T.PREVIEW_RESULT_OUTER_RADIUS-margin),power)
	reciprocal+=pow(maxf(direction.x,0)/(bounds.end.x-T.PREVIEW_CENTER.x),power)
	reciprocal+=pow(maxf(-direction.x,0)/(T.PREVIEW_CENTER.x-bounds.position.x),power)
	reciprocal+=pow(maxf(direction.y,0)/(bounds.end.y-T.PREVIEW_CENTER.y),power)
	reciprocal+=pow(maxf(-direction.y,0)/(T.PREVIEW_CENTER.y-bounds.position.y),power)
	var outer=(pow(reciprocal,-1/power)-T.PREVIEW_RADII[3])*T.PREVIEW_RESULT_PULSE_FILL
	return Vector2(-T.PREVIEW_RESULT_PULSE_INWARD,outer)

static func _field_colors(field: Dictionary, colors: Array) -> Array:
	return [colors[field.roles[0]],colors[field.roles[1]],colors[field.roles[2]],field.color]

static func _phase_paint(sectors: Array,boundaries: Array,angle: float,colors: Array,field: Dictionary) -> Dictionary:
	for i in range(boundaries.size()):
		var boundary: float=boundaries[i]
		var before=fposmod(boundary-boundaries[posmod(i-1,boundaries.size())],360.0)
		var after=fposmod(boundaries[(i+1)%boundaries.size()]-boundary,360.0)
		var half=minf(T.PREVIEW_BLEND_DEGREES,minf(before,after)/2)
		var delta=fposmod(angle-boundary+180.0,360.0)-180.0
		if half>0 and absf(delta)<=half:
			var a=_phase_field(sectors,boundary-0.0001,colors)
			var b=_phase_field(sectors,boundary+0.0001,colors)
			var t=smoothstep(-half,half,delta)
			var left=_field_colors(a,colors)
			var right=_field_colors(b,colors)
			var blended=[]
			for r in range(4):
				blended.append(left[r].lerp(right[r],t))
			return {"colors":blended,"clarity":lerpf(a.clarity,b.clarity,t)}
	return {"colors":_field_colors(field,colors),"clarity":field.clarity}

## 円形予測を描く。canvasは描画先、centerは中心、curvesは生成済みの4輪郭、animatedは表示時刻の座標で省略時は包絡。戻り値なし。副作用は描画だけ。
static func phase_orbit(canvas: CanvasItem, center: Vector2, curves: Array, animated: Array=[]) -> void:
	var scale_px=maxf(0.001,(canvas.get_viewport_transform()*canvas.get_global_transform()).get_scale().x)
	for r in range(curves.size()):
		var curve: Dictionary=curves[r]
		var points=PackedVector2Array()
		for point in (animated[r] if not animated.is_empty() else curve.points):
			points.append(point+center)
		canvas.draw_polyline_colors(points,curve.colors,maxf(curve.width,T.PREVIEW_PIXEL_MIN/scale_px),true)

## ユニット外周の非描画距離を返す。radiusは記号半径、line_widthは経路線幅、pixel_scaleは物理倍率。戻り値は線の半幅と物理余白を含む距離。副作用なし。
static func route_unit_clearance(radius: float, line_width: float, pixel_scale: float) -> float:
	var scale=maxf(0.001,pixel_scale)
	var color_width=maxf(maxf(T.UNIT_MIN_LINE,radius*T.UNIT_RING_WIDTH),T.UNIT_COLOR_PIXEL_MIN/scale)
	var hp_width=maxf(maxf(T.UNIT_HP_MIN_LINE,radius*T.UNIT_HP_WIDTH),T.UNIT_HP_PIXEL_MIN/scale)
	var extent=maxf(radius*T.UNIT_RING_RADII.max()+color_width/2,radius*T.UNIT_HP_RADIUS+hp_width/2)
	extent=maxf(extent,radius*T.UNIT_TICK_RADII.y+maxf(T.UNIT_MIN_LINE,radius*T.UNIT_TICK_WIDTH)/2)
	return extent+line_width/2+T.ROUTE_RING_GAP_PIXELS/scale

## 線の両端を外周の外へ切る。fromとtoは中心、start_clearとend_clearは非描画距離。戻り値は両端の配列、余白がなければ空。副作用なし。
static func route_segment(from: Vector2, to: Vector2, start_clear: float, end_clear: float) -> PackedVector2Array:
	var distance=from.distance_to(to)
	if distance<=start_clear+end_clear or distance<=0:
		return PackedVector2Array()
	var direction=(to-from)/distance
	return PackedVector2Array([from+direction*start_clear,to-direction*end_clear])

static var _cloud_texture: GradientTexture2D

## 漂う雲の形を返す。centerは発生源、cellはセル幅、secondsは表示時間、phaseは発生源の周期差、boardは盤面、previewは予測か。戻り値は盤内と周囲3x3に収まるpoints、rect、uvとalphaの配列。戦闘状態と乱数を変更しない。
static func field_cloud_shape(center: Vector2, cell: float, seconds: float, phase: float, board: Rect2, preview: bool) -> Array:
	var layers=[]
	var bounds=Rect2(center-Vector2.ONE*cell*1.5,Vector2.ONE*cell*3).intersection(board)
	if not bounds.has_area():return layers
	for wisp in range(T.FIELD_CLOUD_WISPS):
		var orbit=phase+TAU*wisp/T.FIELD_CLOUD_WISPS+seconds*(T.FIELD_CLOUD_SPEED+0.009*sin(wisp*2.1))
		var axis=Vector2(cos(orbit),sin(orbit))
		# 軸を通るときも急加速しない、滑らかな丸い四角の軌道。
		var stretch=pow(pow(axis.x,4)+pow(axis.y,4),-0.25)
		var offset=axis*stretch*cell*T.FIELD_CLOUD_ORBIT
		var tangent=Vector2(-axis.y,axis.x)
		var breath=1.0+0.10*sin(seconds*0.7+wisp*0.93+phase)
		for layer in range(T.FIELD_CLOUD_LAYERS):
			var drift=tangent*(layer-1)*cell*0.17+axis*cell*0.06*sin(seconds*0.43+wisp+layer)
			var radius=T.FIELD_CLOUD_RADIUS*cell*breath*(1.0-layer*0.13)
			var raw=Rect2(center+offset+drift-radius,radius*2)
			var rect=raw.intersection(bounds)
			if not rect.has_area():continue
			var points=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
			var trail=[]
			if preview and layer==0:
				for i in range(12):
					var point=center+offset+tangent*cell*(float(i)/11-0.5)*0.5+axis*cell*0.04*sin(float(i)/11*PI)
					if bounds.has_point(point):trail.append(point)
			layers.append({"points":points,"rect":rect,"uv":Rect2((rect.position-raw.position)/raw.size,rect.size/raw.size),"alpha":T.FIELD_CLOUD_ALPHA*(1.0-layer*0.2)*(0.55 if preview else 1.0),"trail":trail})
	return layers

static func _field_texture() -> GradientTexture2D:
	if _cloud_texture==null:
		var gradient=Gradient.new()
		gradient.offsets=PackedFloat32Array([0.0,0.3,0.65,1.0])
		gradient.colors=PackedColorArray([Color(1,1,1,1),Color(1,1,1,0.8),Color(1,1,1,0.25),Color(1,1,1,0)])
		_cloud_texture=GradientTexture2D.new()
		_cloud_texture.gradient=gradient
		_cloud_texture.width=T.FIELD_CLOUD_TEXTURE_SIZE
		_cloud_texture.height=T.FIELD_CLOUD_TEXTURE_SIZE
		_cloud_texture.fill=GradientTexture2D.FILL_RADIAL
		_cloud_texture.fill_from=Vector2(0.5,0.5)
		_cloud_texture.fill_to=Vector2(0.5,0.0)
	return _cloud_texture

## 発生源の雲を描く。canvasは描画先、centerは中心、cellはセル幅、secondsは表示時間、phaseは周期差、boardは盤面、previewは予測か、colorは設定色。戻り値なし。副作用はユニットより下の描画だけ。
## opacityは発生源の移動に合わせる不透明度で、形や効果判定を変更しない。
static func field_cloud(canvas: CanvasItem, center: Vector2, cell: float, seconds: float, phase: float, board: Rect2, preview: bool, color: Color, opacity: float=1.0) -> void:
	var layers=field_cloud_shape(center,cell,seconds,phase,board,preview)
	var texture=_field_texture()
	var scale_px=maxf(0.001,(canvas.get_viewport_transform()*canvas.get_global_transform()).get_scale().x)
	var width=T.FIELD_CLOUD_PIXEL_MIN/scale_px
	for layer in layers:
		canvas.draw_texture_rect_region(texture,layer.rect,Rect2(layer.uv.position*texture.get_size(),layer.uv.size*texture.get_size()),Color(color,layer.alpha*opacity))
		for i in range(layer.trail.size()-1):
			if i%4<2:canvas.draw_line(layer.trail[i],layer.trail[i+1],Color(color,T.FIELD_CLOUD_PREVIEW_ALPHA*opacity),width,true)
