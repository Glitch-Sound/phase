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
	host._label(self,"Select a candidate. Apply to confirm. Esc to cancel.",Rect2(36,70,1180,28),16,host.MUTED)
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
		minimum.tooltip_text="Minimum selected stat. Choose VIT, INF, RES, SPD or LUK."
		add_child(minimum)
		minimum.value_changed.connect(func(_value):_refresh_rows())
	scroll=ScrollContainer.new()
	scroll.position=Vector2(36,166 if equipment else 112)
	scroll.size=Vector2(600,534 if equipment else 588)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	list=VBoxContainer.new()
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",4)
	scroll.add_child(list)
	counter=host._label(self,"",Rect2(36,710,600,24),14,host.MUTED)
	preview_area=Control.new()
	preview_area.position=Vector2(672,108);preview_area.size=Vector2(572,574)
	preview_area.mouse_filter=Control.MOUSE_FILTER_IGNORE
	preview_area.draw.connect(_draw_preview)
	add_child(preview_area)
	candidate_name=host._label(self,"",Rect2(684,376,548,32),18,host.WHITE)
	candidate_caption=host._label(self,"",Rect2(684,410,548,24),T.LAYOUT_STANDARD_FONT,host.MUTED)
	description=host._wrapped_label(self,"",Rect2(684,442,548,102),17,host.MUTED)
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
		elif kind in ["class_name","arms_mutation","gear_mutation"]:button.text+="\n"+("" if row.get("subtitle","")=="STANDARD" else row.description.get_slice("\n",0))
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size=Vector2(574,68 if row.has("stats") or kind!="skill" else 46)
		button.add_theme_font_override("font",host.mono if row.has("stats") else host.font)
		button.add_theme_font_size_override("font_size",T.CHOICE_ROW_FONT)
		button.add_theme_color_override("font_color",host.CYAN if row.id==selected_id else host.WHITE)
		button.disabled=not row.selectable
		# Tabはフィルター、取消と確定を循環し、長い候補一覧は上下とHome/Endで操作する。
		button.focus_mode=Control.FOCUS_CLICK
		button.tooltip_text="" if kind=="operation" else row.description+("\n"+row.reason if not row.reason.is_empty() else "")
		button.pressed.connect(func():select_candidate(row.id))
		button.gui_input.connect(func(event):
			if event is InputEventKey and navigate(event):button.accept_event())
		list.add_child(button)
		if kind=="operation":
			button.text="";button.accessibility_name=row.title
			host._label(button,row.title+(" / EQUIPPED" if row.current else ""),Rect2(12,6,550,26),T.CHOICE_ROW_FONT,host.WHITE)
			host._objective_label(button,row.description.get_slice("\n",0),Rect2(12,36,550,28),14,host.MUTED)
		if row.get("subtitle","")=="STANDARD":
			host._label(button,"STANDARD",Rect2(12,38,200,20),T.LAYOUT_STANDARD_FONT,host.MUTED)
		row_buttons[row.id]=button
	var available=visible_rows.filter(func(row):return row.selectable).size()
	counter.text="%d shown / %d available   |   Up / Down, Home / End" % [visible_rows.size(),available]
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
	description.text="" if kind in ["arms","gear"] else row.description
	if is_instance_valid(objective_description):remove_child(objective_description);objective_description.queue_free()
	if kind=="operation":
		description.text=""
		objective_description=host._objective_label(self,row.description,Rect2(684,442,548,102),17,host.MUTED)
	apply_button.disabled=not row.selectable
	preview_area.queue_redraw()

func _draw_preview() -> void:
	if not is_instance_valid(host):return
	if kind=="operation":
		_draw_operation()
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
	elif kind=="skill":
		_draw_skill_area()
	else:
		var part=0 if kind=="class_name" else (1 if kind=="gear_mutation" else 2)
		var order=host.M.order(candidate,part).map(func(value):return MODEL.STATUS[value])
		preview_area.draw_string(host.mono,Vector2(12,486)," > ".join(order),HORIZONTAL_ALIGNMENT_LEFT,-1,16,host.WHITE)

func _draw_skill_area() -> void:
	if not C.SKILLS.has(selected_id):return
	var offsets=C.FIELD_OFFSETS if selected_id in [C.FIELD_SLOW,C.FIELD_FAST] else C.target_offsets(selected_id)
	var origin=Vector2(226,420);var cell=24.0
	for y in range(-2,3):
		for x in range(-2,3):
			var offset=Vector2i(x,y)
			var rect=Rect2(origin+Vector2(x+2,y+2)*cell,Vector2.ONE*(cell-2))
			preview_area.draw_rect(rect,host.EDGE,false,1)
			if offset==Vector2i.ZERO:preview_area.draw_circle(rect.get_center(),3,host.WHITE,true,-1,true)
			if offsets.has(offset):preview_area.draw_rect(rect.grow(-3),Color(host.CYAN,0.38))
	preview_area.draw_string(host.font,origin+Vector2(-214,38),"TARGET CELLS",HORIZONTAL_ALIGNMENT_LEFT,-1,13,host.MUTED)

func _draw_operation() -> void:
	var stage=C.stages()[int(selected_id)]
	var origin=Vector2(162,12);var cell=24.0
	for y in range(10):
		for x in range(10):
			preview_area.draw_rect(Rect2(origin+Vector2(x,y)*cell,Vector2.ONE*(cell-2)),host.EDGE,false,1)
	for i in range(stage.spawns.size()):
		var center=origin+(Vector2(stage.spawns[i])+Vector2(0.5,0.5))*cell
		var unit=host._reference_unit(host.I.PLAYER_IDS[i] if i<3 else host.I.ENEMY_IDS[i-3])
		host.V.unit_emblem(preview_area,center,9,unit,host._assembly_profile(unit.camp))
	if stage.goal.x>=0:
		preview_area.draw_rect(Rect2(origin+Vector2(stage.goal)*cell,Vector2.ONE*(cell-2)),host.WHITE,false,2)
	if stage.enemy_goal.x>=0:
		preview_area.draw_rect(Rect2(origin+Vector2(stage.enemy_goal)*cell,Vector2.ONE*(cell-2)),host.status_colors[1],false,2)
