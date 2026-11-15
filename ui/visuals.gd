## 実際の位相配置を静的なリングと共通角度空間の波形へ描画する。
extends RefCounted
const M = preload("res://game/phase_math.gd")
const P = preload("res://ui/palette.gd")
const TEXT = P.TEXT
# 細い輪郭で位相を読み、広い色面を作らない。
const RING_WIDTH_RATIO=0.065

## リングを描く。canvasは描画先、centerは中心、radiusは外半径、uは現在配置、selectedは選択枠、colorsは5色、accentは選択色。戻り値なし。副作用は描画。
static func ring(canvas: CanvasItem, center: Vector2, radius: float, u: Dictionary, selected: bool, colors: Array, accent: Color) -> void:
	canvas.draw_circle(center,radius+2,P.BG)
	for r in range(3):
		var rad=radius*(0.48+0.23*r)
		var width=radius*RING_WIDTH_RATIO
		for status in range(5):
			var sector=M.sector(u,r,status)
			var start=deg_to_rad(sector.x-90)
			var end=deg_to_rad(sector.x+sector.y-90)
			canvas.draw_arc(center,rad,start+0.012,end-0.012,maxi(3,ceili(sector.y/3)),colors[status],width,true)
	canvas.draw_line(center+Vector2(0,-radius-3),center+Vector2(0,-radius+5),TEXT,1.3,true)
	if selected:
		canvas.draw_arc(center,radius+2,0,TAU,80,Color(accent,0.8),1.5,true)

## 波形を描く。canvasは描画先、rectは共通角度領域、uは予測配置、_timeは互換用の秒数、colorsは5色。戻り値なし。副作用は描画。
static func wave(canvas: CanvasItem, rect: Rect2, u: Dictionary, _time: float, colors: Array) -> void:
	canvas.draw_line(Vector2(rect.position.x,rect.end.y-15),Vector2(rect.end.x,rect.end.y-15),P.EDGE,1)
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
