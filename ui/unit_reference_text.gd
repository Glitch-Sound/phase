## 目標文の固定参照を紋章として折り返し、名前は非表示の読み上げ用だけに保持する。
extends Control
var host: Control
var parts: Array=[]
var font_size: int
var ink: Color
var source_text=""
var paragraph: TextParagraph

## 文を構成する。owner_uiは画面、textは目標文、rectは領域、pixelsとcolorは文字の様式。戻り値なし。戦闘と保存を変更しない。
func configure(owner_ui: Control,text: String,rect: Rect2,pixels: int,color: Color) -> void:
	host=owner_ui;position=rect.position;size=rect.size;font_size=pixels;ink=color;source_text=text
	mouse_filter=Control.MOUSE_FILTER_IGNORE;clip_contents=true
	refresh_language()

## 説明の現在言語で段落を組み直す。戻り値なし。原文と名前、紋章と参照IDを変更しない。
func refresh_language() -> void:
	parts.clear();paragraph=TextParagraph.new();paragraph.width=size.x
	paragraph.break_flags=TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_ADAPTIVE
	var text=host._explain(source_text)
	var regex=RegEx.create_from_string("\\b(0[123]|[ABC])\\b")
	var start=0;var accessible=""
	for matched in regex.search_all(text):
		var prefix=text.substr(start,matched.get_start()-start)
		parts.append({"text":prefix});accessible+=prefix
		var unit=host._reference_unit(matched.get_string())
		parts.append({"unit":unit});accessible+=host.V.unit_name(unit)
		start=matched.get_end()
	parts.append({"text":text.substr(start)});accessible+=text.substr(start)
	accessibility_name=accessible
	for i in range(parts.size()):
		var part=parts[i]
		if part.has("unit"):paragraph.add_object(i,Vector2(font_size*1.55,maxf(host.font.get_height(font_size)+2,font_size*host.T.OBJECTIVE_REF_CREST_SCALE*2)),INLINE_ALIGNMENT_CENTER)
		else:paragraph.add_string(part.text,host.font,font_size,host.copy_language.locale())
	queue_redraw()

func _draw() -> void:
	if paragraph==null:return
	paragraph.draw(get_canvas_item(),Vector2.ZERO,ink)
	for line in range(paragraph.get_line_count()):
		for key in paragraph.get_line_objects(line):
			var rect=paragraph.get_line_object_rect(line,key)
			var center=rect.get_center()
			host.V.unit_emblem(self,center,font_size*host.T.OBJECTIVE_REF_CREST_SCALE,parts[int(key)].unit,host._assembly_profile(parts[int(key)].unit.camp))
