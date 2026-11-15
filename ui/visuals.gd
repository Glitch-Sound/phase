## 実際の位相配置を静的なリングと共通角度空間の波形へ描画する。
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

## 波形を描く。canvasは描画先、rectは共通角度領域、uは予測配置、_timeは互換用の秒数、colorsは5色。戻り値なし。副作用は描画。
static func wave(canvas: CanvasItem, rect: Rect2, u: Dictionary, _time: float, colors: Array) -> void:
	canvas.draw_line(Vector2(rect.position.x,rect.end.y-15),Vector2(rect.end.x,rect.end.y-15),Color("30363d"),1)
	var prev=[]
	var prev_colors=[]
	for sample in range(201):
		var angle=sample*360.0/200.0
		var profiles=[]
		var ring_colors=[]
		var sums=[0.0,0.0,0.0,0.0,0.0]
		for r in range(3):
			var amplitudes=[]
			var mix_color=Color(0,0,0,1)
			var weights=0.0
			var height=0.0
			for status in range(5):
				var sector=M.sector(u,r,status)
				var distance=absf(wrapf(angle-(sector.x+sector.y/2),-180,180))
				var weight=1.0-smoothstep(sector.y/2-3,sector.y/2+3,distance)
				var shape=0.18+0.82*pow(maxf(0,cos(PI*distance/maxf(0.001,sector.y))),2)
				amplitudes.append(weight*shape)
				mix_color+=colors[status]*weight
				weights+=weight
				height+=weight*shape
			profiles.append(amplitudes)
			ring_colors.append(mix_color/maxf(weights,0.001))
			profiles[r].append(height)
		for status in range(5):
			var a=profiles[0][status]
			var b=profiles[1][status]
			var c=profiles[2][status]
			sums[status]=0.7*minf(a,minf(b,c))+0.2*(minf(a,b)+minf(a,c)+minf(b,c))/3.0+0.1*maxf(minf(a,b),maxf(minf(a,c),minf(b,c)))
		var total=0.0
		var result_color=Color(0,0,0,1)
		for status in range(5):
			total+=sums[status]
			result_color+=colors[status]*sums[status]
		result_color=result_color/maxf(total,0.001)
		var x=rect.position.x+rect.size.x*sample/200.0
		var base=rect.end.y-15
		var points=[]
		var line_colors=[]
		for r in range(3):
			points.append(Vector2(x,base-12-profiles[r][5]*rect.size.y*0.49))
			line_colors.append(Color(ring_colors[r],0.62))
		points.append(Vector2(x,base-8-total*rect.size.y*0.77))
		line_colors.append(Color(result_color,0.95))
		if sample>0:
			for r in range(4):
				canvas.draw_line(prev[r],points[r],line_colors[r],2.8 if r==3 else 1.3,true)
		prev=points
		prev_colors=line_colors
