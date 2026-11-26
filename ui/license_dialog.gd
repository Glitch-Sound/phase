## 同梱原文を外部通信なしで選択し、折り返して全文を閲覧する。
extends Control
signal closed
const LANGUAGE = preload("res://ui/language.gd")
const P = preload("res://ui/palette.gd")
var documents: Array = [
	{"title": "Godot Engine / MIT", "path": "res://assets/godot/LICENSE.txt"},
	{
		"title": "Godot / Third-party copyright & licenses",
		"path": "res://assets/godot/COPYRIGHT.txt"
	},
	{"title": "Godot / Source & version", "path": "res://assets/godot/NOTICE.md"},
	{"title": "Lucide / ISC & MIT", "path": "res://assets/lucide/LICENSE"},
	{"title": "Lucide / Source", "path": "res://assets/lucide/NOTICE.md"},
	{"title": "Noto Sans JP / SIL OFL 1.1", "path": "res://assets/fonts/OFL.txt"},
	{"title": "Noto Sans JP / Source", "path": "res://assets/fonts/NOTICE.md"}
]
var selector: OptionButton
var body: TextEdit
var guidance: Label


## 閲覧画面を準備する。localeは案内言語。戻り値なし。原文と保存を変更しない。
func configure(locale: String) -> void:
	if not is_instance_valid(body):
		_build()
	var language = LANGUAGE.new()
	language.selection = locale
	guidance.text = language.text(
		"Bundled notices. Original license texts are shown without translation."
	)


## 文書を表示する。indexは固定候補の番号。戻り値なし。本文とスクロールだけを変更する。
func select_document(index: int) -> void:
	if index < 0 or index >= documents.size():
		return
	selector.selected = index
	body.text = FileAccess.get_file_as_string(documents[index].path)
	body.scroll_vertical = 0
	body.scroll_horizontal = 0


func _build() -> void:
	var background = ColorRect.new()
	background.color = P.BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var title = Label.new()
	title.text = "LICENSES"
	title.position = Vector2(36, 25)
	title.size = Vector2(988, 48)
	title.add_theme_font_size_override("font_size", 32)
	add_child(title)
	guidance = Label.new()
	guidance.position = Vector2(36, 82)
	guidance.size = Vector2(988, 34)
	guidance.add_theme_font_size_override("font_size", 16)
	guidance.add_theme_color_override("font_color", P.MUTED)
	add_child(guidance)
	selector = OptionButton.new()
	selector.name = "Document"
	selector.position = Vector2(36, 128)
	selector.size = Vector2(988, 44)
	for row in documents:
		selector.add_item(row.title)
	selector.item_selected.connect(select_document)
	add_child(selector)
	body = TextEdit.new()
	body.name = "Original"
	body.position = Vector2(36, 192)
	body.size = Vector2(988, 436)
	body.editable = false
	body.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	body.add_theme_font_size_override("font_size", 17)
	body.add_theme_color_override("font_readonly_color", P.TEXT)
	body.add_theme_constant_override("line_spacing", 3)
	add_child(body)
	var back = Button.new()
	back.text = "BACK / ESC"
	back.position = Vector2(36, 654)
	back.size = Vector2(988, 42)
	back.pressed.connect(func(): closed.emit())
	add_child(back)
	select_document(0)
