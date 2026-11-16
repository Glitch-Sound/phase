## 実際の位相配置をリングと共通角度空間の円形予測へ描画する。
extends RefCounted
const M = preload("res://game/phase_math.gd")
const P = preload("res://ui/palette.gd")
const TEXT = P.TEXT
const T = preload("res://game/tuning.gd")

## 表示名を返す。uは内部IDと陣営を持つユニット。戻り値は表示専用の名前。副作用なし。
static func unit_name(u: Dictionary) -> String:
	return str(int(u.id)) if u.camp=="PLAYER" and u.id in ["01","02"] else u.id

## ユニット記号を記述する。radiusは基準半径、uは現在配置、selectedは行動中、colorsは5色、accentは行動色。戻り値は円弧と目盛りと中央名の描画データ。副作用なし。
static func glyph(radius: float, u: Dictionary, selected: bool, colors: Array, accent: Color) -> Dictionary:
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
		arcs.append({"role":"HP","radius":radius*T.UNIT_HP_RADIUS,"start":-PI/2,"end":-PI/2+TAU*health,"color":TEXT,"width":maxf(T.UNIT_HP_MIN_LINE,radius*T.UNIT_HP_WIDTH)})
	return {"arcs":arcs,"tick":{"from":Vector2(0,-radius*T.UNIT_TICK_RADII.x),"to":Vector2(0,-radius*T.UNIT_TICK_RADII.y),"color":accent if selected else TEXT,"width":maxf(T.UNIT_MIN_LINE,radius*T.UNIT_TICK_WIDTH)},"name":unit_name(u),"font_size":maxi(T.UNIT_NAME_MIN,roundi(radius*T.UNIT_NAME_SIZE))}

## 記号を描く。canvasは描画先、centerは中心、radiusは基準半径、uは現在配置、selectedは行動中、colorsは5色、accentは行動色、typefaceは名前のフォント。戻り値なし。副作用は描画。
static func ring(canvas: CanvasItem, center: Vector2, radius: float, u: Dictionary, selected: bool, colors: Array, accent: Color, typeface: Font) -> void:
	var g=glyph(radius,u,selected,colors,accent)
	# viewport_transformはRetinaを含む実描画倍率を既に持つ。OSのDPIを追加で掛けない。
	var scale_px=(canvas.get_viewport_transform()*canvas.get_global_transform()).get_scale().x
	for arc in g.arcs:
		var style=stroke_style(arc,scale_px)
		canvas.draw_arc(center,arc.radius,arc.start,arc.end,style.points,arc.color,style.width,true)
	canvas.draw_line(center+g.tick.from,center+g.tick.to,g.tick.color,g.tick.width,true)
	var size=typeface.get_string_size(g.name,HORIZONTAL_ALIGNMENT_LEFT,-1,g.font_size)
	var baseline=(typeface.get_ascent(g.font_size)-typeface.get_descent(g.font_size))/2
	canvas.draw_string(typeface,center+Vector2(-size.x/2,baseline),g.name,HORIZONTAL_ALIGNMENT_LEFT,-1,g.font_size,TEXT)

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
		for status in range(5):
			var sector: Vector2=sectors[r][status]
			var local=fposmod(angle-sector.x,360.0)
			if local<sector.y:
				roles.append(status)
				profiles.append(pow(sin(PI*local/sector.y),2))
				break
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

## 閉じた4輪郭を返す。uは予測ユニット、colorsは基本5色。戻り値はCORE、GEAR、ARMS、結果の局所座標と頂点色と線幅。副作用なし。
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
	for role in ["CORE","GEAR","ARMS","RESULT"]:
		curves.append({"role":role,"points":PackedVector2Array(),"colors":PackedColorArray(),"width":T.PREVIEW_RESULT_LINE if role=="RESULT" else T.PREVIEW_LINE})
	for sample in range(T.PREVIEW_SAMPLES+1):
		# 最後の点は0度を再利用し、色と形の継ぎ目を一致させる。
		var angle=(sample%T.PREVIEW_SAMPLES)*360.0/T.PREVIEW_SAMPLES
		var field=_phase_field(sectors,angle,colors)
		var paint=_phase_paint(sectors,boundaries,angle,colors,field)
		var direction=Vector2.from_angle(deg_to_rad(angle)-PI/2)
		for r in range(4):
			var height=field.profiles[r] if r<3 else field.height
			var color: Color=paint.colors[r]
			color.a=lerpf(T.PREVIEW_BASE_ALPHA,T.PREVIEW_CLEAR_ALPHA,paint.clarity) if r<3 else lerpf(T.PREVIEW_RESULT_BASE_ALPHA,T.PREVIEW_RESULT_CLEAR_ALPHA,paint.clarity)
			curves[r].points.append(direction*(T.PREVIEW_RADII[r]+height*T.PREVIEW_AMPLITUDES[r]))
			curves[r].colors.append(color)
	return curves

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

## 円形予測を描く。canvasは描画先、centerは中心、curvesは生成済みの4輪郭。戻り値なし。副作用は描画だけ。
static func phase_orbit(canvas: CanvasItem, center: Vector2, curves: Array) -> void:
	var scale_px=maxf(0.001,(canvas.get_viewport_transform()*canvas.get_global_transform()).get_scale().x)
	for curve in curves:
		var points=PackedVector2Array()
		for point in curve.points:
			points.append(point+center)
		canvas.draw_polyline_colors(points,curve.colors,maxf(curve.width,T.PREVIEW_PIXEL_MIN/scale_px),true)
