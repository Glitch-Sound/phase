## BUILDの全選択に共通する、候補を確定まで隔離した画面。
extends Control
const C=preload("res://game/catalog.gd")
const MODEL=preload("res://game/build_choices.gd")
const T=preload("res://game/tuning.gd")
signal applied
signal cancelled
var host: Control
var collection: RefCounted
var unit_index: int
var kind: String
var slot: int
var rows: Array=[]
var visible_rows: Array=[]
var selected_id: String
var current_build: Dictionary={}
var candidate_build: Dictionary={}
var list: VBoxContainer
var scroll: ScrollContainer
var apply_button: Button
var description: Label
var candidate_name: Label
var candidate_caption: Label
var counter: Label
var minimum: SpinBox
var stat_index := -1
var filter_buttons: Array=[]
var row_buttons: Dictionary={}
var preview_area: Control
var objective_description: Control

## ダイアログを構成する。owner_uiは画面、dataは所持品、indexは編集番号、selection_kindは選択種、skill_slotは枠。戻り値なし。原本を変更しない。
func configure(owner_ui: Control,data: RefCounted,index: int,selection_kind: String,skill_slot: int=0) -> void:
	host=owner_ui;collection=data;unit_index=index;kind=selection_kind;slot=skill_slot
	size=T.CHOICE_RECT.size
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	current_build=collection.builds[index].duplicate(true)
	candidate_build=current_build.duplicate(true)
	rows=MODEL.candidates(collection,index,kind,slot)
	selected_id=MODEL.current(collection,index,kind,slot)
	var title=kind.replace("_"," ").to_upper()
	if kind=="class_name":title="CLASS"
	if kind=="skill":title="SKILL / SLOT %d" % (slot+1)
	host._label(self,title,Rect2(36,24,1000,42),28,host.WHITE)
	if kind not in ["class_name","arms_mutation","gear_mutation","skill","operation"]:host._prose_label(self,"Select a candidate. Apply to confirm. Esc to cancel.",Rect2(36,70,1180,28),16,host.MUTED)
	var equipment=kind in ["arms","gear"]
	if equipment:
		for i in range(6):
			var label="ALL" if i==0 else MODEL.STATUS[i-1]
			var button=host._button(self,label,Rect2(36+i*75,112,69,34),func():_filter(i-1), "",i==0)
			button.add_theme_font_size_override("font_size",14)
			filter_buttons.append(button)
		host._label(self,"MIN",Rect2(494,116,42,26),13,host.MUTED)
		minimum=SpinBox.new()
		minimum.position=Vector2(540,108);minimum.size=Vector2(92,40)
		minimum.min_value=10;minimum.max_value=60;minimum.step=10;minimum.value=10
		host._set_prose(minimum,"Minimum selected stat. Choose VIT, INF, RES, SPD or LUK.","tooltip_text")
		add_child(minimum)
		minimum.value_changed.connect(func(_value):_refresh_rows())
	scroll=ScrollContainer.new()
	var top=T.CHOICE_COMPACT_TOP if kind in ["class_name","arms_mutation","gear_mutation","skill","operation"] else 112
	scroll.position=Vector2(36,166 if equipment else top)
	scroll.size=Vector2(600,534 if equipment else 700-top)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	list=VBoxContainer.new()
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",4)
	scroll.add_child(list)
	counter=host._label(self,"",Rect2(36,710,600,24),14,host.MUTED)
	preview_area=Control.new()
	preview_area.position=Vector2(672,top-4);preview_area.size=Vector2(572,574)
	if kind=="operation":preview_area.position.y=T.OPERATION_PREVIEW_TOP;preview_area.size.y=T.OPERATION_PREVIEW_HEIGHT
	preview_area.mouse_filter=Control.MOUSE_FILTER_IGNORE
	preview_area.draw.connect(_draw_preview)
	add_child(preview_area)
	candidate_name=host._label(self,"",Rect2(684,top+0 if kind=="skill" else top+264,548,32),18,host.WHITE)
	if kind=="operation":candidate_name.position.y=top
	candidate_caption=host._label(self,"",Rect2(684,top+298,548,24),T.LAYOUT_STANDARD_FONT,host.MUTED)
	description=host._wrapped_label(self,"",Rect2(684,top+48 if kind=="skill" else top+330,548,102),17,host.MUTED)
	host._button(self,"CANCEL",Rect2(36,752,260,44),cancel,"back")
	apply_button=host._button(self,"APPLY",Rect2(984,752,260,44),confirm,"check")
	_refresh_rows(true)
	_refresh_preview()

## 候補を選ぶ。idは有効な開放済み候補。戻り値はプレビューを切り替えたか。所持品と構成の原本を変更しない。
func select_candidate(id: String) -> bool:
	var matching=rows.filter(func(row):return row.id==id and row.selectable)
	if matching.is_empty():return false
	selected_id=id
	candidate_build=MODEL.preview(current_build,kind,id)
	_refresh_preview()
	for key in row_buttons:
		var button: Button=row_buttons[key]
		button.add_theme_color_override("font_color",host.CYAN if key==selected_id else host.WHITE)
		var style=StyleBoxFlat.new();style.bg_color=Color.TRANSPARENT;style.border_color=host.CYAN
		style.border_width_bottom=T.UI_FOCUS_LINE if key==selected_id else 0
		button.add_theme_stylebox_override("normal",style)
	return true

## 選択を確定する。戻り値なし。候補を再検証し、成功時にだけ原本へ反映して画面を閉じる。
func confirm() -> void:
	if MODEL.commit(collection,unit_index,kind,selected_id,slot):
		applied.emit()

## 選択を取り消す。戻り値なし。原本を変更せず画面を閉じる。
func cancel() -> void:
	cancelled.emit()

## 一覧をキーボードで移動する。eventはキー入力。戻り値は処理したか。確定せず、候補とスクロールだけを更新する。
func navigate(event: InputEventKey) -> bool:
	if not event.pressed or event.echo:return false
	if event.keycode not in [KEY_UP,KEY_DOWN,KEY_HOME,KEY_END,KEY_PAGEUP,KEY_PAGEDOWN]:return false
	var selectable=visible_rows.filter(func(row):return row.selectable)
	if selectable.is_empty():return true
	var ids=selectable.map(func(row):return row.id)
	var index=ids.find(selected_id)
	match event.keycode:
		KEY_HOME:index=0
		KEY_END:index=ids.size()-1
		KEY_UP:index=maxi(0,index-1)
		KEY_DOWN:index=mini(ids.size()-1,index+1)
		KEY_PAGEUP:index=maxi(0,index-8)
		KEY_PAGEDOWN:index=mini(ids.size()-1,index+8)
	index=clampi(index,0,ids.size()-1)
	select_candidate(ids[index])
	var button: Button=row_buttons[ids[index]]
	button.grab_focus()
	scroll.ensure_control_visible(button)
	return true

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and navigate(event):
		get_viewport().set_input_as_handled()

func _filter(status: int) -> void:
	stat_index=status
	for i in range(filter_buttons.size()):
		filter_buttons[i].add_theme_color_override("font_color",host.CYAN if i-1==status else host.WHITE)
		var style=StyleBoxFlat.new();style.bg_color=Color.TRANSPARENT;style.border_color=host.CYAN
		style.border_width_bottom=T.UI_FOCUS_LINE if i-1==status else 0
		filter_buttons[i].add_theme_stylebox_override("normal",style)
	_refresh_rows()

func _refresh_rows(reveal_current: bool=false) -> void:
	for child in list.get_children():list.remove_child(child);child.queue_free()
	row_buttons={}
	visible_rows=MODEL.filtered(rows,stat_index,int(minimum.value) if is_instance_valid(minimum) else 10)
	var group=""
	for row in visible_rows:
		if row.group!=group:
			group=row.group
			var header=Label.new();header.text=group
			header.add_theme_color_override("font_color",host.MUTED)
			header.add_theme_font_size_override("font_size",13)
			header.custom_minimum_size=Vector2(0,28)
			list.add_child(header)
		var button=Button.new()
		button.text=row.title+("  / EQUIPPED" if row.current else "")+("  / "+row.reason if not row.reason.is_empty() else "")
		if row.has("stats"):button.text+="\n"+MODEL._stats_text(row.stats)
		elif kind in ["class_name","arms_mutation","gear_mutation"]:button.text+="\n"
		host._set_prose(button,button.text)
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size=Vector2(574,68 if row.has("stats") or kind!="skill" else 46)
		button.add_theme_font_override("font",host.mono if row.has("stats") else host.font)
		button.add_theme_font_size_override("font_size",T.CHOICE_ROW_FONT)
		button.add_theme_color_override("font_color",host.CYAN if row.id==selected_id else host.WHITE)
		button.disabled=not row.selectable
		# Tabはフィルター、取消と確定を循環し、長い候補一覧は上下とHome/Endで操作する。
		button.focus_mode=Control.FOCUS_CLICK
		host._set_prose(button,(row.reason if kind!="operation" else "") if kind in ["operation","class_name","arms_mutation","gear_mutation"] else row.description+("\n"+row.reason if not row.reason.is_empty() else ""),"tooltip_text")
		button.pressed.connect(func():select_candidate(row.id))
		button.gui_input.connect(func(event):
			if event is InputEventKey and navigate(event):button.accept_event())
		list.add_child(button)
		if kind=="operation":
			host._set_prose(button,"");button.accessibility_name=row.title
			host._label(button,row.title+(" / EQUIPPED" if row.current else ""),Rect2(12,6,550,26),T.CHOICE_ROW_FONT,host.WHITE)
			host._objective_label(button,row.description.get_slice("\n",0),Rect2(12,36,550,28),14,host.MUTED)
		if row.get("subtitle","")=="STANDARD":
			host._label(button,"STANDARD",Rect2(12,38,200,20),T.LAYOUT_STANDARD_FONT,host.MUTED)
		if kind in ["class_name","arms_mutation","gear_mutation"]:
			var unit=C.unit("01","PLAYER",Vector2i.ZERO,MODEL.preview(current_build,kind,row.id))
			var part=0 if kind=="class_name" else (1 if kind=="gear_mutation" else 2)
			var order=host.M.order(unit,part)
			for i in range(5):
				var square=ColorRect.new();square.position=T.CLASS_SWATCH_ORIGIN+Vector2(i*T.CLASS_SWATCH_STEP,0);square.size=Vector2.ONE*T.CLASS_SWATCH_SIZE;square.color=host.status_colors[order[i]];square.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(square)
			button.accessibility_name=row.title+" / "+["CORE","GEAR","ARMS"][part]+" / "+" > ".join(order.map(func(index):return MODEL.STATUS[index]))
		row_buttons[row.id]=button
	var available=visible_rows.filter(func(row):return row.selectable).size()
	host._set_prose(counter,"%d shown / %d available   |   Up / Down, Home / End" % [visible_rows.size(),available])
	# 開く時だけ装備中へ、絞り込み後は値順の先頭へ移す。
	if reveal_current:_reveal.call_deferred()
	else:_scroll_top.call_deferred()

func _scroll_top() -> void:
	if is_instance_valid(scroll) and not is_queued_for_deletion():scroll.scroll_vertical=0

func _reveal() -> void:
	if not is_instance_valid(scroll) or is_queued_for_deletion():return
	if row_buttons.has(selected_id):scroll.ensure_control_visible(row_buttons[selected_id])

func _refresh_preview() -> void:
	var matching=rows.filter(func(row):return row.id==selected_id)
	if matching.is_empty():return
	var row=matching[0]
	candidate_name.text=row.title
	candidate_caption.text=row.get("subtitle","")
	host._set_prose(description,"" if kind in ["arms","gear","class_name","arms_mutation","gear_mutation"] else row.description)
	if is_instance_valid(objective_description):remove_child(objective_description);objective_description.queue_free()
	if kind=="operation":
		host._set_prose(description,"")
		objective_description=host._objective_label(self,row.description,T.OPERATION_DESCRIPTION_RECT,17,host.MUTED)
	apply_button.disabled=not row.selectable
	# 省いた領域を再描画した時も、スクロール後の確定と取消を確実に更新する。
	if kind in ["class_name","arms_mutation","gear_mutation","skill","operation"]:
		for child in get_children():
			if child is Button:child.queue_redraw()
	preview_area.queue_redraw()

func _draw_preview() -> void:
	if not is_instance_valid(host):return
	if kind=="operation":
		_draw_operation()
		return
	if kind=="skill":
		_draw_skill_area()
		return
	var source=C.unit("%02d" % (unit_index+1),"PLAYER",Vector2i.ZERO,current_build)
	var candidate=C.unit("%02d" % (unit_index+1),"PLAYER",Vector2i.ZERO,candidate_build)
	for i in range(2):
		var center=Vector2(128+i*284,112)
		host._ring(preview_area,center,87,source if i==0 else candidate)
		preview_area.draw_string(host.mono,center+Vector2(-43,133),"CURRENT" if i==0 else "CANDIDATE",HORIZONTAL_ALIGNMENT_LEFT,-1,14,host.MUTED)
	if kind in ["arms","gear"]:
		for i in range(5):
			var pos=Vector2(12,318+i*26)
			preview_area.draw_string(host.mono,pos,MODEL.STATUS[i],HORIZONTAL_ALIGNMENT_LEFT,-1,14,host.status_colors[i])
			preview_area.draw_string(host.mono,pos+Vector2(116,0),str(int(current_build[kind][i])),HORIZONTAL_ALIGNMENT_LEFT,-1,18,host.MUTED)
			preview_area.draw_string(host.mono,pos+Vector2(400,0),str(int(candidate_build[kind][i])),HORIZONTAL_ALIGNMENT_LEFT,-1,20,host.WHITE)

func _draw_skill_area() -> void:
	if not C.SKILLS.has(selected_id):return
	var offsets=C.FIELD_OFFSETS if selected_id in [C.FIELD_SLOW,C.FIELD_FAST] else C.target_offsets(selected_id)
	var origin=Vector2(226,T.SKILL_AREA_Y);var cell=24.0
	for y in range(-2,3):
		for x in range(-2,3):
			var offset=Vector2i(x,y)
			var rect=Rect2(origin+Vector2(x+2,y+2)*cell,Vector2.ONE*(cell-2))
			preview_area.draw_rect(rect,host.EDGE,false,1)
			if offset==Vector2i.ZERO:preview_area.draw_circle(rect.get_center(),3,host.WHITE,true,-1,true)
			if offsets.has(offset):preview_area.draw_rect(rect.grow(-3),Color(host.CYAN,0.38))
	preview_area.draw_string(host.font,origin+Vector2(-214,38),"TARGET CELLS",HORIZONTAL_ALIGNMENT_LEFT,-1,13,host.MUTED)

## 概要図の所属と紋章を返す。戻り値は現在の6体と開始可能領域内の相対位置。モデルと固定配置を変更しない。
func operation_symbols() -> Array:
	var result=[]
	var areas=host.B.SPAWN_LAYOUT.areas()
	for i in range(C.SQUAD_SIZE*2):
		var unit=host._reference_unit((C.PLAYER_IDS+C.ENEMY_IDS)[i])
		var area: Rect2i=areas[0 if i<C.SQUAD_SIZE else 1]
		result.append({"unit":unit,"point":Vector2(area.position)+Vector2(area.size)*Vector2((i%C.SQUAD_SIZE+0.5)/C.SQUAD_SIZE,0.5)})
	return result

func _draw_operation() -> void:
	var origin=Vector2(162,12);var cell=24.0
	for y in range(10):
		for x in range(10):
			preview_area.draw_rect(Rect2(origin+Vector2(x,y)*cell,Vector2.ONE*(cell-2)),host.EDGE,false,1)
	var areas=host.B.SPAWN_LAYOUT.areas()
	for i in range(areas.size()):
		var area: Rect2i=areas[i]
		var camp="PLAYER" if i==0 else "ENEMY"
		var color=host.A.color(host._assembly_profile(camp))
		for y in range(area.position.y,area.end.y):
			for x in range(area.position.x,area.end.x):preview_area.draw_rect(Rect2(origin+Vector2(x,y)*cell,Vector2.ONE*(cell-2)),Color(color,0.12))
	for symbol in operation_symbols():
		# 説明文のunit_reference_textと同じ紋章と所属色で役割を対応させる。
		host._reference_emblem(preview_area,origin+symbol.point*cell,10,symbol.unit)
	preview_area.draw_string(host.mono,T.OPERATION_LEGEND,"START AREAS",HORIZONTAL_ALIGNMENT_LEFT,-1,13,host.MUTED)
