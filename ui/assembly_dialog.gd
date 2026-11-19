## アセンブリの候補だけを編集し、明示確定まで通常データを変更しない。
extends Control
const A=preload("res://game/assembly_identity.gd")
const I=preload("res://game/unit_identity.gd")
signal applied
signal cancelled
var host: Control
var collection: RefCounted
var candidate: Dictionary={}
var name_edit: LineEdit
var preview: Control
var color_buttons: Dictionary={}

## 編集画面を構成する。owner_uiは画面、dataは編集対象。戻り値なし。原本を変更せず候補と部品を作る。
func configure(owner_ui: Control,data: RefCounted) -> void:
	host=owner_ui;collection=data;candidate=data.assembly.duplicate(true)
	size=host.T.ASSEMBLY_DIALOG_RECT.size;mouse_filter=Control.MOUSE_FILTER_IGNORE
	host._label(self,"ASSEMBLY",Rect2(36,25,620,42),28,host.WHITE)
	host._label(self,"A shared crest and color for your units.",Rect2(36,76,700,26),16,host.MUTED)
	host._label(self,"NAME",Rect2(36,132,58,38),14,host.MUTED)
	name_edit=LineEdit.new();name_edit.position=Vector2(106,128);name_edit.size=Vector2(405,42);name_edit.text=candidate.name
	name_edit.placeholder_text="ORBIT";name_edit.add_theme_font_size_override("font_size",20)
	name_edit.tooltip_text="Up to 32 characters. Blank uses ORBIT. Apply to confirm; Esc cancels."
	add_child(name_edit);name_edit.text_changed.connect(_name_changed)
	name_edit.text_submitted.connect(func(_value):name_edit.text=candidate.name;name_edit.release_focus())
	name_edit.focus_exited.connect(func():name_edit.text=candidate.name)
	host._label(self,"COLOR",Rect2(36,213,490,26),14,host.MUTED)
	var keys=A.PALETTE.keys()
	for i in range(keys.size()):
		var key: String=keys[i]
		var button=host._button(self,key,Rect2(36+(i%3)*158,253+floori(i/3.0)*54,146,42),func():choose_color(key))
		button.add_theme_font_size_override("font_size",14);button.tooltip_text=key+" / crest and bright HP"
		var swatch=ColorRect.new();swatch.color=A.color({"color":key});swatch.position=Vector2(9,15);swatch.size=Vector2(5,12);swatch.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(swatch)
		color_buttons[key]=button
	preview=Control.new();preview.position=Vector2(552,132);preview.size=Vector2(220,230);preview.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(preview)
	preview.draw.connect(func():
		host._assembly_emblem(preview,Vector2(110,76),62,candidate,"PLAYER")
		preview.draw_string(host.font,Vector2(30,180),"CREST / BRIGHT HP",HORIZONTAL_ALIGNMENT_LEFT,-1,13,host.MUTED)
		preview.draw_rect(Rect2(30,200,160,5),A.health(candidate)))
	host._label(self,"Names may repeat. Your gray ownership mark stays separate.",Rect2(36,378,748,28),14,host.MUTED)
	host._button(self,"APPLY",Rect2(36,434,360,44),confirm)
	host._button(self,"CANCEL",Rect2(424,434,360,44),func():cancelled.emit())
	_refresh()

## 色の候補を選ぶ。keyは安定キー。戻り値なし。不明なキーは無視し原本を変更しない。
func choose_color(key: String) -> void:
	if not A.PALETTE.has(key):return
	candidate.color=key;_refresh()

## 候補を確定する。戻り値なし。検証した表示設定だけを原本へ写し、適用を通知する。
func confirm() -> void:
	if not A.valid(candidate):return
	collection.assembly=candidate.duplicate(true);applied.emit()

func _name_changed(value: String) -> void:
	candidate.name=I.normalize(value);preview.queue_redraw()

func _refresh() -> void:
	for key in color_buttons:
		var button: Button=color_buttons[key]
		var style=button.get_theme_stylebox("normal").duplicate()
		style.border_width_bottom=host.T.UI_FOCUS_LINE if key==candidate.color else 0
		style.border_color=A.color(candidate);button.add_theme_stylebox_override("normal",style)
	preview.queue_redraw()
