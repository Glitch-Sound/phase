extends SceneTree
class TextProbe:
	extends "res://ui/main.gd"
	var text_records: Array=[]
	func _text(text: String,position_px: Vector2,font_size: int,color: Color=WHITE,typeface: Font=null) -> void:
		text_records.append(text)
		super._text(text,position_px,font_size,color,typeface)
var checks=0
var failures=0
var game
func _initialize() -> void:_run.call_deferred()
## REQ-044-S01
func _run() -> void:
	game=TextProbe.new()
	game.preferred_locale_override="en"
	game.settings_path="res://artifacts/runtime/english-no-settings.json"
	game.save_path="res://artifacts/runtime/english-no-save.json"
	root.add_child(game)
	await process_frame
	_scan(game.overlay,"BUILD")
	for method in ["_help","_skill_help","_field_help","_settings"]:
		game.call(method)
		await process_frame
		_scan(game.auxiliary,method)
		game._close_aux()
		await process_frame
	game._start_battle()
	game.queue_redraw()
	await create_timer(0.06).timeout
	_check(game.text_records.has("PREVIEW"),"actual battle draw includes PREVIEW")
	_check(_english("\n".join(game.text_records)),"battle canvas text is English")
	game.battle.panels={Vector2i(4,4):"CLOCKWISE"}
	await _panel_hint()
	game.battle.mode="RESULT";game.battle.result="VICTORY"
	game._result()
	await process_frame
	_scan(game.overlay,"RESULT")
	game._restart()
	game.queue_free()
	await process_frame
	print("ENGLISH UI: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
## REQ-018-S03、REQ-019-S14
func _panel_hint() -> void:
	var text=game.panel_description(Vector2i(4,4))
	_check(text.split("\n").size()==2 and _english(text),"CORE panel has English summary and detail")
	_check(game.has_method("_update_panel_hint"),"panel hint has two explicit visual levels")
	if game.has_method("_update_panel_hint"):
		game.hover_cell=Vector2i(4,4)
		game._update_panel_hint()
		_check(game.panel_hint.visible and game.panel_hint.get_child_count()==2 and game.panel_hint.get_child(1).get_child(0).get_theme_color("font_color")==game.MUTED,"second hint line is subdued and actual hover is visible")
		_check(not game.panel_hint.get_global_rect().intersects(game._cell_rect(Vector2i(4,4))),"hint never covers hovered panel icon or focus")
		for i in range(game.battle.units.size()):
			game.battle.units[i].pos=Vector2i(3+i%3,3+i/3)
			game.battle.units[i].skills=[game.C.FIELD_SLOW,game.C.FIELD_FAST]
		game.hover_cell=Vector2i(4,4)
		game._update_panel_hint()
		await process_frame
		await process_frame
		var detail=game.panel_hint.find_children("*","Label",true,false)[-1]
		var hint_bounds=Rect2(game.panel_hint.position,game.T.PANEL_HINT_RECT.size)
		var scroll=detail.get_parent()
		var wheel=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=true
		game._unhandled_input(wheel)
		_check(scroll is ScrollContainer and scroll.clip_contents and hint_bounds.encloses(scroll.get_global_rect()) and scroll.scroll_vertical>0 and detail.text==" | ".join(Array(game.panel_description(Vector2i(4,4)).split("\n",false)).slice(1)),"combined field detail is clipped to the hint, complete and scrollable while hovering the panel")
func _scan(layer: Node,name: String) -> void:
	var texts=[]
	for control in layer.find_children("*","Control",true,false):
		if control is Label or control is BaseButton:texts.append(control.text)
		texts.append(control.tooltip_text)
	_check(_english("\n".join(texts)),name+" user-facing controls have no Japanese")
func _english(text: String) -> bool:
	return RegEx.create_from_string("[ぁ-んァ-ヶ一-龯]").search(text)==null
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
