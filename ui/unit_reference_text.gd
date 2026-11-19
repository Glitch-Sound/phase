## 目標文の固定参照を紋章として折り返し、名前は非表示の読み上げ用だけに保持する。
extends Control
var host: Control
var parts: Array=[]
var font_size: int
var ink: Color

## 文を構成する。owner_uiは画面、textは目標文、rectは領域、pixelsとcolorは文字の様式。戻り値なし。戦闘と保存を変更しない。
func configure(owner_ui: Control,text: String,rect: Rect2,pixels: int,color: Color) -> void:
	host=owner_ui;position=rect.position;size=rect.size;font_size=pixels;ink=color
	mouse_filter=Control.MOUSE_FILTER_IGNORE;clip_contents=true
	var regex=RegEx.create_from_string("\\b(0[123]|[ABC])\\b")
	var start=0;var accessible=""
	for match in regex.search_all(text):
		var prefix=text.substr(start,match.get_start()-start)
		parts.append({"text":prefix});accessible+=prefix
		var unit=host._reference_unit(match.get_string())
		parts.append({"unit":unit});accessible+=host.V.unit_name(unit)
		start=match.get_end()
	parts.append({"text":text.substr(start)});accessible+=text.substr(start)
	accessibility_name=accessible

func _draw() -> void:
	var point=Vector2.ZERO;var height=host.font.get_height(font_size)+2
	for part in parts:
		if part.has("unit"):
			var width=font_size*1.55
			if point.x+width>size.x:point=Vector2(0,point.y+height)
			host.V.unit_emblem(self,point+Vector2(width/2,height/2),font_size*0.65,part.unit,host._assembly_profile(part.unit.camp))
			point.x+=width
		else:
			for word in part.text.replace("\n"," \n ").split(" ",false):
				if word=="\n":point=Vector2(0,point.y+height);continue
				var width=host.font.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
				if point.x+width>size.x:point=Vector2(0,point.y+height)
				draw_string(host.font,point+Vector2(0,host.font.get_ascent(font_size)),word,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,ink)
				point.x+=width+host.font.get_string_size(" ",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
