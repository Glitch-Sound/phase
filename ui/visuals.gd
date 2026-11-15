## 画像なしで実際の位相配置をリングと共通角度空間の波形へ描画する。
extends RefCounted
const M = preload("res://game/phase_math.gd")
const COLORS = [Color("a4abb6"),Color("ff526f"),Color("58e59c"),Color("548dff"),Color("f0d56a")]
const CYAN = Color("6bf8ec")
const TEXT = Color("e4eaf0")
const MUTED = Color("738390")

## リングを描く。canvasは描画先、centerは中心、radiusは外半径、uは現在配置、selectedは選択枠。
static func ring(canvas: CanvasItem, center: Vector2, radius: float, u: Dictionary, selected: bool=false) -> void:
	canvas.draw_circle(center,radius+2,Color("090f17"))
	for r in range(3):
		var rad=radius*(0.48+0.23*r)
		var width=radius*0.16
		for status in range(5):
			var sector=M.sector(u,r,status)
			var start=deg_to_rad(sector.x-90)
			var end=deg_to_rad(sector.x+sector.y-90)
			canvas.draw_arc(center,rad,start+0.012,end-0.012,maxi(3,ceili(sector.y/3)),COLORS[status],width,true)
	canvas.draw_line(center+Vector2(0,-radius-3),center+Vector2(0,-radius+5),TEXT,1.3,true)
	if selected:
		canvas.draw_arc(center,radius+2,0,TAU,80,Color(CYAN,0.6),1.5,true)

## 波形を描く。canvasは描画先、rectは共通角度領域、uは予測配置、timeは縦揺れの秒数。
static func wave(canvas: CanvasItem, rect: Rect2, u: Dictionary, time: float) -> void:
	canvas.draw_rect(rect,Color("080d15"))
	for y in range(int(rect.position.y),int(rect.end.y),5):
		canvas.draw_line(Vector2(rect.position.x,y),Vector2(rect.end.x,y),Color(0.13,0.25,0.29,0.18))
	for k in range(13):
		var x=rect.position.x+rect.size.x*k/12.0
		canvas.draw_line(Vector2(x,rect.position.y),Vector2(x,rect.end.y),Color(0.2,0.3,0.35,0.25))
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
				mix_color+=COLORS[status]*weight
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
			result_color+=COLORS[status]*sums[status]
		result_color=result_color/maxf(total,0.001)
		var x=rect.position.x+rect.size.x*sample/200.0
		var base=rect.end.y-15
		var points=[]
		var colors=[]
		for r in range(3):
			points.append(Vector2(x,base-12-profiles[r][5]*rect.size.y*0.49+sin(time*1.5+r+angle*0.07)*1.5))
			colors.append(Color(ring_colors[r],0.34))
		points.append(Vector2(x,base-8-total*rect.size.y*0.77+sin(time*1.7+angle*0.12)*1.5))
		colors.append(Color(result_color,0.95))
		if sample>0:
			for r in range(4):
				if r==3:
					canvas.draw_line(prev[r],points[r],Color(colors[r],0.08),9,true)
				canvas.draw_line(prev[r],points[r],colors[r],2.8 if r==3 else 1.0,true)
		prev=points
		prev_colors=colors
	for k in range(5):
		var x=rect.position.x+fposmod(k*197.0+floor(time*8)*29,rect.size.x-16)
		var y=rect.position.y+fposmod(k*41.0+floor(time*6)*17,rect.size.y)
		canvas.draw_line(Vector2(x,y),Vector2(x+8,y),Color(CYAN,0.13))
