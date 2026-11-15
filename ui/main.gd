## PHASEの一画面UIと手動操作を提供する。
extends Control
const C = preload("res://game/catalog.gd")
const M = preload("res://game/phase_math.gd")
const B = preload("res://game/battle.gd")
const L = preload("res://game/collection.gd")
const V = preload("res://ui/visuals.gd")
const T = preload("res://game/tuning.gd")
const P = preload("res://ui/palette.gd")
const WHITE = P.TEXT
const MUTED = P.MUTED
const BG = P.BG
const PANEL = P.SURFACE
const EDGE = P.EDGE
const ICONS = {
 "help":preload("res://assets/lucide/circle-question-mark.svg"),
 "settings":preload("res://assets/lucide/settings-2.svg"),
 "restart":preload("res://assets/lucide/rotate-ccw.svg"),
 "quit":preload("res://assets/lucide/log-out.svg"),
 "play":preload("res://assets/lucide/play.svg"),
 "save":preload("res://assets/lucide/save.svg"),
 "load":preload("res://assets/lucide/folder-open.svg"),
 "wait":preload("res://assets/lucide/pause.svg"),
 "attack":preload("res://assets/lucide/swords.svg"),
 "heal":preload("res://assets/lucide/heart-pulse.svg"),
 "close":preload("res://assets/lucide/x.svg"),
 "back":preload("res://assets/lucide/arrow-left.svg"),
 "check":preload("res://assets/lucide/check.svg"),
 "move":preload("res://assets/lucide/move.svg"),
 "target":preload("res://assets/lucide/target.svg")
}
var palette_colors: Array=P.PRESETS.DEFAULT.duplicate()
var status_colors: Array=palette_colors.slice(1)
var CYAN: Color=palette_colors[0]
var MAGENTA: Color=palette_colors[0]
var palette_pickers: Array=[]
var palette_error: Label
var settings_path="res://artifacts/runtime/ui-settings.json"
const BOARD = Vector2(560,100)
# 負幅は拡縮時も1物理ピクセルの線を保ち、セル境界を欠かさない。
const GRID_LINE_WIDTH=-1.0
const SAVE_PATH = "res://artifacts/runtime/phase-save.json"
var battle=B.new()
var collection=L.new()
var font: SystemFont
var mono: SystemFont
var overlay: Control
var auxiliary: Control
var hud: Control
var selected := -1
var edit_unit := 0
var build_open := true
var clock := 0.0
var redraw_elapsed := 0.0
var reduced_motion := false
var message := ""
var message_time := 0.0
var toasts: Array=[]
var drops: Array=[]
var build_preview: Control
var build_summary: Label
var core_controls: Array=[]
var core_refreshing := false
var effect_hover := -1
var hover_cell := Vector2i(-1,-1)
var loot_rng := RandomNumberGenerator.new()
var notice: Label
var result_awarded := false
var equipment_views: Dictionary={}
var window_focused := true
var info_open := false
var phase_open := false
var build_page := "CORE"

func _ready() -> void:
	get_window().focus_exited.connect(_window_focus_exited)
	get_window().focus_entered.connect(_window_focus_entered)
	loot_rng.randomize()
	font=SystemFont.new()
	font.font_names=PackedStringArray(["Helvetica Neue","Hiragino Sans","Arial"])
	mono=SystemFont.new()
	mono.font_names=PackedStringArray(["Menlo","Monaco","monospace"])
	palette_colors=P.load_from(settings_path)
	_set_theme()
	notice=Label.new()
	notice.position=Vector2(300,956)
	notice.size=Vector2(1320,43)
	notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_font_size_override("font_size",19)
	notice.add_theme_color_override("font_color",CYAN)
	notice.mouse_filter=Control.MOUSE_FILTER_IGNORE
	notice.z_index=1000
	add_child(notice)
	battle.start(collection.stage_index,collection.builds)
	_hud()
	_build()

func _process(delta: float) -> void:
	clock+=delta if not reduced_motion else 0.0
	message_time=maxf(0,message_time-delta)
	notice.visible=message_time>0 and build_open
	for t in toasts:
		t.age+=delta
	toasts=toasts.filter(func(t):return t.age<2.4)
	redraw_elapsed+=delta
	if redraw_elapsed>=1.0/30:
		redraw_elapsed=0.0
		queue_redraw()
		if is_instance_valid(build_preview):
			build_preview.queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0,0,1920,1080),BG)
	if build_open:
		return
	_draw_left()
	_draw_board()
	if info_open:
		_draw_info()
	_draw_preview()
	if message_time>0:
		_text(message,Vector2(560,1042),16,CYAN)
	for t in toasts:
		var color: Color=t.color
		color.a=clampf((2.4-t.age)/0.7,0,1)
		var p: Vector2=BOARD+Vector2(t.cell)*70+Vector2(35,3-(t.age*24 if not reduced_motion else 0))
		_center(t.text,p,24,color,mono)

func _draw_left() -> void:
	var rows=battle.timeline(4)
	for k in range(rows.size()):
		var u: Dictionary=battle.units[rows[k].index]
		var y=351+k*57
		if k==0:
			draw_circle(Vector2(461,y-7),3,CYAN)
		_text(u.id,Vector2(480,y),22,CYAN if k==0 else MUTED,mono)

func _draw_board() -> void:
	var effect_chips=[]
	for y in range(10):
		for x in range(10):
			var cell=Vector2i(x,y)
			var pos=BOARD+Vector2(cell)*70
			var rect=Rect2(pos+Vector2.ONE,Vector2(68,68))
			var panel=battle.panels.get(cell,"NORMAL")
			# A faint connected grid supplies legal cell boundaries without 100 panels.
			draw_line(pos,pos+Vector2(70,0),EDGE,GRID_LINE_WIDTH)
			draw_line(pos,pos+Vector2(0,70),EDGE,GRID_LINE_WIDTH)
			if battle.path.has(cell):
				draw_rect(rect,Color(CYAN,0.035))
			if cell==hover_cell and not is_instance_valid(overlay):
				_brackets(rect.grow(-3),MUTED)
			if panel!="NORMAL":
				_text({"SHIFT":">>","LOCK":"=","REVERSE":"<"}[panel],pos+Vector2(7,17),12,MUTED,mono)
			if cell==battle.stage.goal:
				draw_rect(rect.grow(-4),Color(MAGENTA,0.6),false,1)
				_text("GOAL",pos+Vector2(6,62),11,MAGENTA,mono)
			if cell==battle.stage.enemy_goal:
				draw_rect(rect.grow(-4),status_colors[1],false,2)
				_text("LOSS",pos+Vector2(6,62),11,status_colors[1],mono)
			if battle.mode=="TARGET" and _distance(cell,battle.units[battle.actor].pos)==1:
				var tc=status_colors[1] if battle.selected_skill==C.DAMAGE else status_colors[2]
				draw_rect(rect,Color(tc,0.12))
				draw_rect(rect.grow(-3),Color(tc,0.7),false,1.5)
			var i=battle.at(cell)
			if i>=0:
				var u: Dictionary=battle.units[i]
				var center=pos+Vector2(35,27)
				if i==battle.actor:
					draw_arc(center,29,0,TAU,48,CYAN,1.5,true)
				if u.camp=="PLAYER":
					draw_arc(center,20,0,TAU,40,CYAN if i==battle.actor else MUTED,1,true)
				else:
					var points=PackedVector2Array([center+Vector2(0,-22),center+Vector2(22,0),center+Vector2(0,22),center+Vector2(-22,0),center+Vector2(0,-22)])
					draw_polyline(points,CYAN if i==battle.actor else MUTED,1,true)
				_center(u.id,pos+Vector2(35,33),14,WHITE,mono)
				_bar(Rect2(pos+Vector2(15,64),Vector2(40,2)),u.hp/u.max_hp,CYAN if u.camp=="PLAYER" else status_colors[1])
				if i==selected:
					_brackets(Rect2(pos+Vector2(5,5),Vector2(60,60)),MAGENTA)
				if battle.mode=="TARGET" and battle.valid_target(battle.actor,i,battle.selected_skill):
					var tc=status_colors[1] if battle.selected_skill==C.DAMAGE else status_colors[2]
					draw_rect(rect.grow(-1),tc,false,2)
					var amount=M.effect(battle.units[battle.actor],u,C.SKILLS[battle.selected_skill].effect)
					if battle.selected_skill==C.HEAL:
						amount=mini(amount,ceili(u.max_hp-u.hp))
					effect_chips.append({"cell":cell,"text":("-" if battle.selected_skill==C.DAMAGE else "+")+str(amount),"color":tc})
	if battle.mode=="MOVE":
		var prev: Vector2=BOARD+Vector2(battle.units[battle.actor].pos)*70+Vector2(35,35)
		for cell in battle.path:
			var now=BOARD+Vector2(cell)*70+Vector2(35,35)
			var direction=(now-prev).normalized()
			draw_line(prev+direction*15,now-direction*15,CYAN,2,true)
			prev=now
		for i in range(battle.path.size()):
			var center=BOARD+Vector2(battle.path[i])*70+Vector2(35,35)
			draw_circle(center,12,BG)
			draw_arc(center,12,0,TAU,32,CYAN,1,true)
			_center(str(i+1),center+Vector2(0,5),15,WHITE,mono)
		if not battle.path.is_empty():
			_brackets(Rect2(BOARD+Vector2(battle.path.back())*70+Vector2(3,3),Vector2(64,64)),CYAN)
	# 全セルの描画後に重ね、次の行の背景で数字を隠さない。
	for chip in effect_chips:
		var rect=_effect_chip_rect(chip.cell)
		draw_rect(rect,BG)
		draw_rect(rect,chip.color,false,1)
		_center(chip.text,rect.position+Vector2(rect.size.x/2,16),16,chip.color,mono)
	draw_line(BOARD+Vector2(700,0),BOARD+Vector2(700,700),EDGE,GRID_LINE_WIDTH)
	draw_line(BOARD+Vector2(0,700),BOARD+Vector2(700,700),EDGE,GRID_LINE_WIDTH)

func _effect_chip_rect(cell: Vector2i) -> Rect2:
	return Rect2(BOARD+Vector2(cell)*70+Vector2(25,2),Vector2(43,22))

func _draw_info() -> void:
	var u: Dictionary=battle.units[selected if selected>=0 else battle.actor]
	_text(u.id+" / "+u.camp,Vector2(1320,160),23,WHITE,mono)
	_text("HP %s / %s" % [_hp(u.hp),_hp(u.max_hp)],Vector2(1320,205),20,WHITE,mono)
	_text(u.class_name+" / MOVE "+str(battle.movement(u)),Vector2(1320,243),15,MUTED,mono)
	for k in range(5):
		_text(["VIT","INF","RES","SPD","LUK"][k],Vector2(1415+k*66,295),13,status_colors[k],mono)
	for r in range(3):
		_text(["CORE","GEAR","ARMS"][r],Vector2(1320,330+r*31),14,MUTED,mono)
		for k in range(5):
			_text(str(u[M.KEYS[r]][k]),Vector2(1420+k*66,330+r*31),17,WHITE,mono)
	for r in range(2):
		var key="arms" if r==0 else "gear"
		_text(C.serial(key.to_upper(),u[key]),Vector2(1320,450+r*64),15,MUTED,mono)
		if u[key+"_mutation"]!="NORMAL":
			_text(u[key+"_mutation"],Vector2(1320,475+r*64),14,CYAN,mono)
	for k in range(u.skills.size()):
		_text(C.SKILLS[u.skills[k]].label,Vector2(1320,615+k*36),17,WHITE,mono)

func _draw_preview() -> void:
	var u=battle.preview()
	_ring(self,Vector2(615,893),43,u)
	_text("INF  %.1f%%" % (M.sync(u,1).factor*100),Vector2(700,882),20,status_colors[1],mono)
	_text("RES  %.1f%%" % (M.sync(u,2).factor*100),Vector2(700,917),20,status_colors[2],mono)
	var length=battle.path.size() if battle.mode=="MOVE" else u.moved
	_text("%d / %d" % [length,battle.movement(u)],Vector2(1000,891),17,MUTED,mono)
	if M.singularity(u):
		_text("×5",Vector2(1060,918),20,CYAN,mono)
	if phase_open:
		V.wave(self,Rect2(560,950,700,65),u,clock,status_colors)
		_text("PATH %d → (%d,%d)   G %.1f° / A %.1f°" % [length,u.pos.x,u.pos.y,u.gear_angle,u.arms_angle],Vector2(560,1042),14,MUTED,mono)

func _unhandled_input(event: InputEvent) -> void:
	if not window_focused:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_F1:
			_help()
		elif not is_instance_valid(auxiliary) and event.keycode==KEY_M:
			_menu()
		elif not build_open and not is_instance_valid(auxiliary) and event.keycode==KEY_I:
			_toggle_info()
		elif not build_open and not is_instance_valid(auxiliary) and event.keycode==KEY_P:
			_toggle_phase()
		elif event.keycode==KEY_ESCAPE:
			if is_instance_valid(auxiliary):
				_close_aux()
			elif battle.mode=="TARGET":
				battle.back()
				_action_dialog()
			elif battle.mode=="MOVE" and not build_open:
				battle.path=[]
		return
	if is_instance_valid(auxiliary) or is_instance_valid(overlay):
		return
	if event is InputEventMouseMotion:
		var p=event.position-BOARD
		hover_cell=Vector2i(floori(p.x/70),floori(p.y/70)) if Rect2(BOARD,Vector2(700,700)).has_point(event.position) else Vector2i(-1,-1)
		tooltip_text="Double-click to confirm" if not battle.path.is_empty() and hover_cell==battle.path.back() else ""
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		# Godotが拡縮と余白を変換済みの、そのイベントの論理座標を使う。
		var p=event.position
		if Rect2(560,100,700,700).has_point(p):
			_cell_input(Vector2i(floori((p.x-560)/70),floori((p.y-100)/70)),event.double_click)
		else:
			for k in range(4):
				if Rect2(455,320+k*57,70,48).has_point(p):
					selected=battle.timeline(4)[k].index
					info_open=true

func _window_focus_exited() -> void:
	window_focused=false
	hover_cell=Vector2i(-1,-1)
	get_viewport().gui_release_focus()
	queue_redraw()

func _window_focus_entered() -> void:
	window_focused=true
	if is_instance_valid(auxiliary):
		_focus_modal.call_deferred(auxiliary)
	elif is_instance_valid(overlay):
		_focus_modal.call_deferred(overlay)

func _cell_input(cell: Vector2i, double_click: bool=false) -> void:
	var index=battle.at(cell)
	if battle.mode=="TARGET":
		if index>=0 and battle.act(index):
			_feedback()
			_after_action()
		else:
			_notify("Choose a highlighted adjacent target. BACK keeps your movement.")
	elif battle.mode=="MOVE":
		if index>=0 and cell!=battle.units[battle.actor].pos:
			selected=index
			info_open=true
		elif double_click and not battle.path.is_empty() and cell==battle.path.back():
			battle.commit_path()
			selected=-1
			if battle.mode=="RESULT":
				_result()
			else:
				_action_dialog()
		elif battle.path_click(cell):
			selected=-1
		else:
			_notify("Add an empty adjacent cell. No revisits. Maximum %d steps." % battle.movement(battle.units[battle.actor]))
	queue_redraw()

func _after_action() -> void:
	selected=-1
	_clear_overlay()
	if battle.mode=="RESULT":
		_result()
	_hud()

func _feedback() -> void:
	var e: Dictionary=battle.last_effect
	var u: Dictionary=battle.units[e.target]
	var shown=str(e.amount) if e.kind=="DAMAGE" else _hp(e.actual)
	toasts.append({"cell":u.pos,"text":("-" if e.kind=="DAMAGE" else "+")+shown,"color":status_colors[1] if e.kind=="DAMAGE" else status_colors[2],"age":0.0})
	if e.dead:
		toasts.append({"cell":u.pos,"text":"DEFEATED","color":status_colors[1],"age":-0.65})

func _hud() -> void:
	if is_instance_valid(hud):
		remove_child(hud)
		hud.queue_free()
	hud=Control.new()
	hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	if is_instance_valid(overlay):
		move_child(hud,overlay.get_index())
	if build_open:
		return
	_button(hud,"MENU",Rect2(1650,45,120,40),_menu,"settings").tooltip_text="Menu / M / F1 help"
	_button(hud,battle.stage.name,Rect2(560,45,360,40),_objective).tooltip_text="Objective"
	_button(hud,"ORDER",Rect2(435,250,100,40),_order).tooltip_text="Turn order and faction HP"
	_button(hud,"INFO",Rect2(1310,95,115,40),_toggle_info,"",info_open).tooltip_text="Unit details / I"
	_button(hud,"PHASE",Rect2(1130,866,130,40),_toggle_phase,"",phase_open).tooltip_text="Four waveforms and angles / P"
	if info_open and battle.mode!="CHOICE":
		_info_selectors(hud)
	if battle.mode=="TARGET":
		_label(hud,"ATTACK" if battle.selected_skill==C.DAMAGE else "HEAL",Rect2(560,810,300,32),16,WHITE)
		_button(hud,"BACK",Rect2(1130,805,130,40),func():battle.back();_action_dialog())
	elif battle.mode=="MOVE" and battle.trapped():
		_button(hud,"WAIT",Rect2(1130,805,130,40),func():battle.wait_turn();_after_action())
	elif battle.mode=="MOVE" and not battle.path.is_empty():
		hud.tooltip_text="Double-click the last step to confirm / Esc clears the path"

func _action_dialog() -> void:
	_clear_overlay()
	_hud()
	var u: Dictionary=battle.units[battle.actor]
	var active=[]
	for skill in u.skills:
		if C.SKILLS[skill].type=="ACTIVE":
			active.append(skill)
	var panel=_modal(Rect2(1320,710 if info_open else 300,390,180+active.size()*58),false,true)
	if info_open:
		_info_selectors(overlay)
	_label(panel,u.id,Rect2(24,18,90,36),25,WHITE)
	_label(panel,"HP %s / %s" % [_hp(u.hp),_hp(u.max_hp)],Rect2(110,23,250,28),17,MUTED)
	_button(panel,"WAIT",Rect2(24,77,342,45),func():battle.wait_turn();_after_action())
	for i in range(active.size()):
		var skill: String=active[i]
		var button=_button(panel,"ATTACK" if skill==C.DAMAGE else "HEAL",Rect2(24,135+i*58,342,45),func():battle.choose_skill(skill);_clear_overlay();_hud(),"attack" if skill==C.DAMAGE else "heal")
		var available=false
		for target in range(battle.units.size()):
			if battle.valid_target(battle.actor,target,skill):
				available=true
		button.disabled=not available
		button.tooltip_text="No adjacent target" if not available else C.SKILLS[skill].label

func _build() -> void:
	build_open=true
	selected=-1
	battle.start(collection.stage_index,collection.builds)
	_clear_overlay()
	var panel=_modal(Rect2(480,150,960,780),false)
	_label(panel,"PHASE",Rect2(34,23,650,46),30,WHITE)
	_button(panel,"MENU",Rect2(792,27,132,40),_menu,"settings")
	for i in range(2):
		_button(panel,"%02d" % (i+1),Rect2(34+i*96,96,80,42),func():edit_unit=i;_build(),"",i==edit_unit)
	for i in range(3):
		var page=["CORE","EQUIP","SKILLS"][i]
		_button(panel,page,Rect2(34+i*169,173,152,42),func():build_page=page;_build(),"",page==build_page)
	var b: Dictionary=collection.builds[edit_unit]
	core_controls=[]
	equipment_views={}
	if build_page=="CORE":
		_option(panel,["STANDARD","REVERSE"],b.class_name,Rect2(34,258,490,42),func(value):b.class_name=value;_refresh_build())
		for k in range(5):
			_label(panel,["VIT","INF","RES","SPD","LUK"][k],Rect2(34+k*100,340,90,25),15,status_colors[k])
			var spin=SpinBox.new()
			spin.position=Vector2(34+k*100,379)
			spin.get_line_edit().add_theme_constant_override("minimum_character_width",2)
			spin.size=Vector2(87,43)
			spin.min_value=1
			spin.max_value=96
			spin.value=b.core[k]
			panel.add_child(spin)
			core_controls.append(spin)
			spin.value_changed.connect(func(value):_core_change(k,int(value)))
		_label(panel,"Σ 100",Rect2(34,451,490,30),17,MUTED)
	elif build_page=="EQUIP":
		for r in range(2):
			var key="arms" if r==0 else "gear"
			var y=252+r*164
			_label(panel,key.to_upper(),Rect2(34,y,100,30),15,MUTED)
			var choices: Array=collection.items[key.to_upper()].keys()
			var view=Control.new()
			view.position=Vector2(34,y+63)
			view.size=Vector2(510,30)
			view.mouse_filter=Control.MOUSE_FILTER_IGNORE
			view.set_meta("before",b[key].duplicate())
			panel.add_child(view)
			equipment_views[key]=view
			view.draw.connect(func():
				for status in range(5):
					var delta=int(b[key][status])-int(view.get_meta("before")[status])
					var text="%s %d" % [["VIT","INF","RES","SPD","LUK"][status],b[key][status]]
					if delta!=0:
						text+=" (%+d)" % delta
					view.draw_string(font,Vector2(status*102,20),text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,status_colors[status]))
			var option=_option(panel,choices,C.serial(key.to_upper(),b[key]),Rect2(145,y-3,379,40),func(value):
				view.set_meta("before",b[key].duplicate())
				b[key]=collection.items[key.to_upper()][value].duplicate()
				_refresh_build())
			for index in range(choices.size()):
				option.get_popup().set_item_tooltip(index,_equipment_comparison(collection.items[key.to_upper()][choices[index]],b[key]))
			option.item_selected.connect(func(_index):
				for index in range(choices.size()):
					option.get_popup().set_item_tooltip(index,_equipment_comparison(collection.items[key.to_upper()][choices[index]],b[key])))
			if collection.mutations.size()>1:
				_option(panel,collection.mutations,b[key+"_mutation"],Rect2(145,y+104,379,34),func(value):b[key+"_mutation"]=value;_refresh_build())
	else:
		for i in range(3):
			var choices=["NONE"]
			choices.append_array(collection.skills)
			var current: String=b.skills[i] if i<b.skills.size() else "NONE"
			_option(panel,choices,current,Rect2(34,267+i*70,490,44),func(value):_skill_change(i,value))
	build_preview=Control.new()
	build_preview.position=Vector2(600,240)
	build_preview.size=Vector2(300,285)
	build_preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_child(build_preview)
	var preview=build_preview
	preview.draw.connect(func():
		var u=C.unit("%02d" % (edit_unit+1),"PLAYER",Vector2i.ZERO,collection.builds[edit_unit])
		_ring(preview,Vector2(150,95),70,u)
		preview.draw_string(mono,Vector2(58,220),"HP %s / MOVE %d" % [_hp(u.max_hp),battle.movement(u)],HORIZONTAL_ALIGNMENT_LEFT,-1,17,WHITE))
	var stages=[]
	for stage in C.stages():
		stages.append(stage.name)
	_option(panel,stages,C.stages()[collection.stage_index].name,Rect2(34,601,490,43),func(value):collection.stage_index=stages.find(value);_build())
	_label(panel,C.stages()[collection.stage_index].brief,Rect2(34,656,860,30),15,MUTED)
	_button(panel,"START",Rect2(660,708,264,44),_start_battle)
	_refresh_build()

func _core_change(index: int, value: int) -> void:
	if core_refreshing:
		return
	var core: Array=collection.builds[edit_unit].core
	var difference=value-int(core[index])
	core[index]=value
	while difference!=0:
		for offset in range(1,5):
			var other=(index+offset)%5
			if difference>0 and core[other]>1:
				core[other]-=1
				difference-=1
			elif difference<0 and core[other]<96:
				core[other]+=1
				difference+=1
			if difference==0:
				break
	core_refreshing=true
	for k in range(core_controls.size()):
		core_controls[k].value=core[k]
	core_refreshing=false
	_refresh_build()

func _skill_change(slot: int, value: String) -> void:
	var skills: Array=collection.builds[edit_unit].skills
	if value!="NONE" and skills.has(value) and skills.find(value)!=slot:
		_notify("A skill can be equipped only once per unit.")
		_build()
		return
	var slots=["NONE","NONE","NONE"]
	for i in range(skills.size()):
		slots[i]=skills[i]
	slots[slot]=value
	collection.builds[edit_unit].skills=slots.filter(func(s):return s!="NONE")
	_build()

func _refresh_build() -> void:
	battle.start(collection.stage_index,collection.builds)
	queue_redraw()
	if is_instance_valid(build_preview):
		build_preview.queue_redraw()
	for view in equipment_views.values():
		if is_instance_valid(view):
			view.queue_redraw()

func _equipment_comparison(candidate: Array, equipped: Array) -> String:
	var lines=[]
	for index in range(5):
		var delta=int(candidate[index])-int(equipped[index])
		var change="0" if delta==0 else "%+d" % delta
		lines.append("%s %d (%s)" % [["VIT","INF","RES","SPD","LUK"][index],candidate[index],change])
	return "\n".join(lines)

func _start_battle() -> void:
	for b in collection.builds:
		if not collection.valid_build(b):
			_notify("Invalid build. Check unlocked elements and the CORE total.")
			return
	build_open=false
	result_awarded=false
	battle.start(collection.stage_index,collection.builds)
	_clear_overlay()
	_hud()
	info_open=false
	phase_open=false
	message_time=0

func _result() -> void:
	if battle.mode!="RESULT" or battle.result.is_empty():
		return
	_clear_overlay()
	if not result_awarded:
		drops=collection.roll_loot(loot_rng)
		result_awarded=true
	var panel=_modal(Rect2(630,300,660,480),false)
	_icon(panel,"check" if battle.result=="VICTORY" else "close",Rect2(32,32,30,30),CYAN if battle.result=="VICTORY" else status_colors[1])
	_label(panel,battle.result,Rect2(82,23,540,48),32,WHITE)
	if drops.is_empty():
		_label(panel,"NO DROP",Rect2(34,148,592,35),18,MUTED)
	for i in range(drops.size()):
		var drop=drops[i]
		var title=C.SKILLS[drop.skill].label if drop.has("skill") else drop.kind+(" / "+drop.mutation if drop.new_mutation else "")
		_button(panel,title,Rect2(34,140+i*72,592,48),func():_drop_detail(drop))
	_button(panel,"RETURN TO BUILD",Rect2(34,390,592,48),_build)

func _help(page: String="PLAY") -> void:
	_close_aux()
	var panel=_modal(Rect2(560,220,800,640),true)
	_label(panel,"HELP",Rect2(32,22,736,40),26,WHITE)
	for i in range(3):
		var name=["PLAY","PHASE","BUILD"][i]
		_button(panel,name,Rect2(32+i*246,90,228,42),func():_help(name),"",page==name)
	if page=="PLAY":
		_label(panel,"隣接する空きマスをクリックして経路を作る。\n終点をダブルクリックして確定する。\nWAITかスキルを選び、対象をクリックする。",Rect2(32,180,736,120),22,WHITE)
		_label(panel,"両陣営を手動操作。上下左右のみ。再進入不可。\n毎手番1歩以上。無移動WAITは閉塞時のみ。\n開始マスかEscで経路取消。BACKで行動を選び直す。\nユニット/手番IDかINFOで詳細を開く。",Rect2(32,325,736,106),18,MUTED)
		_label(panel,"I 詳細    P 位相    M メニュー    F1 HELP",Rect2(32,477,736,36),18,MUTED)
	elif page=="PHASE":
		_label(panel,"内側 CORE / 中央 GEAR / 外側 ARMS",Rect2(32,180,736,35),21,WHITE)
		_label(panel,"通常 GEAR ↶ / ARMS ↷\n>> ARMS回転2倍    = GEAR固定    < ARMS逆回転",Rect2(32,250,736,77),20,WHITE)
		_label(panel,"−はダメージ、＋は回復。\nINFは攻撃と回復、RESは抵抗。",Rect2(32,360,736,70),21,WHITE)
		_label(panel,"最終補正は最大200%。\n特異点 ×5: 生INF完全一致 + CORE INF ≤10",Rect2(32,465,736,66),18,MUTED)
	else:
		_label(panel,"COREは合計100、各値1以上。\n装備は5値と差分を比較して選ぶ。\nスキルは最大3。取得品と変異は共有。",Rect2(32,180,736,134),22,WHITE)
		_label(panel,"SAVE / LOADは明示操作。以前の保存は退避する。",Rect2(32,370,736,40),18,MUTED)
	_button(panel,"CLOSE / ESC",Rect2(32,562,736,44),_close_aux)

func _settings(page: String="DISPLAY") -> void:
	_close_aux()
	var panel=_modal(Rect2(590,240,740,600),true)
	_label(panel,"SETTINGS",Rect2(32,22,676,40),26,WHITE)
	for i in range(2):
		var name=["DISPLAY","COLOR"][i]
		_button(panel,name,Rect2(32+i*346,90,330,42),func():_settings(name),"",page==name)
	palette_pickers=[]
	if page=="DISPLAY":
		_button(panel,"WINDOWED",Rect2(32,210,330,46),func():DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED))
		_button(panel,"FULLSCREEN",Rect2(378,210,330,46),func():DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN))
		var check=CheckButton.new()
		check.text="REDUCED MOTION"
		check.position=Vector2(32,310)
		check.size=Vector2(676,46)
		check.button_pressed=reduced_motion
		check.toggled.connect(func(value):reduced_motion=value)
		panel.add_child(check)
	else:
		var presets=P.PRESETS.keys()
		for i in range(presets.size()):
			var preset: String=presets[i]
			_button(panel,preset,Rect2(32+i*230,185,215,42),func():
				for k in range(6):
					palette_pickers[k].color=P.PRESETS[preset][k])
		for i in range(6):
			var x=32+i*115
			_label(panel,["ACCENT","VIT","INF","RES","SPD","LUK"][i],Rect2(x,270,108,28),15,WHITE)
			var picker=ColorPickerButton.new()
			picker.position=Vector2(x,315)
			picker.size=Vector2(36,36)
			picker.color=palette_colors[i]
			picker.edit_alpha=false
			picker.tooltip_text=["ACCENT","VIT","INF","RES","SPD","LUK"][i]
			panel.add_child(picker)
			var editor=picker.get_picker()
			editor.sampler_visible=false
			editor.color_modes_visible=false
			editor.sliders_visible=false
			editor.presets_visible=false
			palette_pickers.append(picker)
		palette_error=_label(panel,"",Rect2(32,393,676,50),17,status_colors[1])
		_button(panel,"APPLY COLORS",Rect2(32,465,676,44),_apply_colors,"check")
	_button(panel,"CLOSE / ESC",Rect2(32,530,676,44),_close_aux)

func _apply_colors() -> void:
	var colors=[]
	for picker in palette_pickers:
		colors.append(picker.color)
	var error=P.validate(colors)
	if not error.is_empty():
		palette_error.text=error
		return
	error=P.save_to(settings_path,colors)
	if not error.is_empty():
		palette_error.text=error
		return
	palette_colors=colors
	_set_theme()
	if is_instance_valid(notice):
		notice.add_theme_color_override("font_color",CYAN)
	_close_aux()
	if build_open:
		_build()
	elif battle.mode=="CHOICE":
		_action_dialog()
	elif battle.mode=="RESULT":
		_result()
	_hud()
	_settings("COLOR")
	palette_error.text="APPLIED"
	palette_error.add_theme_color_override("font_color",CYAN)
	queue_redraw()

func _set_theme() -> void:
	CYAN=palette_colors[0]
	MAGENTA=palette_colors[0]
	status_colors=palette_colors.slice(1)
	var skin=Theme.new()
	skin.default_font=font
	skin.default_font_size=20
	for type in ["Label","Button","OptionButton","CheckButton","LineEdit","SpinBox","PopupMenu"]:
		skin.set_color("font_color",type,WHITE)
		skin.set_color("font_hover_color",type,CYAN)
		skin.set_color("font_pressed_color",type,CYAN)
		skin.set_color("font_focus_color",type,CYAN)
		skin.set_color("font_disabled_color",type,MUTED)
		if type=="Label":
			continue
		for state in ["normal","hover","pressed","focus","disabled","panel"]:
			var style=StyleBoxFlat.new()
			style.bg_color=PANEL if state in ["normal","panel","disabled"] else P.INTERACTIVE
			style.border_color=CYAN if state in ["pressed","focus"] else EDGE
			style.set_border_width_all(2 if state=="focus" else 0)
			style.content_margin_left=12
			style.content_margin_right=12
			style.content_margin_top=4
			style.content_margin_bottom=4
			skin.set_stylebox(state,type,style)
	for type in ["PopupPanel","PanelContainer","TooltipPanel"]:
		var surface=StyleBoxFlat.new()
		surface.bg_color=PANEL
		surface.border_color=EDGE
		surface.set_border_width_all(1)
		surface.content_margin_left=10
		surface.content_margin_right=10
		surface.content_margin_top=10
		surface.content_margin_bottom=10
		skin.set_stylebox("panel",type,surface)
	skin.set_color("font_color","TooltipLabel",WHITE)
	skin.set_font_size("font_size","TooltipLabel",18)
	self.theme=skin

func _ring(canvas: CanvasItem,center: Vector2,radius: float,u: Dictionary,active: bool=false) -> void:
	V.ring(canvas,center,radius,u,active,status_colors,CYAN)

func _restart() -> void:
	_close_aux()
	_build()
	_hud()

func _save() -> void:
	var error=collection.save_to(SAVE_PATH)
	_notify("SAVED / Previous save is backed up." if error.is_empty() else error)

func _load() -> void:
	var error=collection.load_from(SAVE_PATH)
	if error.is_empty():
		_build()
	_notify("LOADED / Builds and shared archive restored." if error.is_empty() else error)

func _quit() -> void:
	get_tree().quit()

func _close_aux() -> void:
	var previous=null
	if is_instance_valid(auxiliary):
		previous=auxiliary.get_meta("previous_focus") if auxiliary.has_meta("previous_focus") else null
		remove_child(auxiliary)
		auxiliary.queue_free()
	auxiliary=null
	_restore_focus.call_deferred(previous)

func _clear_overlay() -> void:
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
	overlay=null
	build_preview=null

func _modal(rect: Rect2, is_aux: bool, keep_context: bool=false) -> Control:
	var layer=Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(layer)
	var owner=get_viewport().gui_get_focus_owner()
	if is_instance_valid(owner):
		layer.set_meta("previous_focus",weakref(owner))
	_focus_modal.call_deferred(layer)
	var dim=ColorRect.new()
	dim.color=Color(BG,P.ACTION_SCRIM_ALPHA if keep_context else (0.98 if build_open or is_aux else 0.82))
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var panel=Panel.new()
	panel.position=rect.position
	panel.size=rect.size
	var style=StyleBoxFlat.new()
	style.bg_color=PANEL
	style.border_color=CYAN if keep_context else EDGE
	style.set_border_width_all(1)
	style.shadow_color=Color(0,0,0,0.5)
	style.shadow_size=0
	panel.add_theme_stylebox_override("panel",style)
	layer.add_child(panel)
	if is_aux:
		auxiliary=layer
	else:
		overlay=layer
	return panel

func _button(parent: Control, text: String, rect: Rect2, callback: Callable, icon_name: String="", active: bool=false) -> Button:
	var button=Button.new()
	button.text=text
	button.tooltip_text=text
	var key=icon_name
	if key.is_empty():
		key={"HELP":"help","SETTINGS":"settings","RESTART":"restart","QUIT":"quit","START":"play","SAVE":"save","LOAD":"load","WAIT":"wait","BACK":"back","CLOSE / ESC":"close","RETURN TO BUILD":"back"}.get(text,"")
		if text.contains("DAMAGE"):
			key="attack"
		elif text.contains("HEAL"):
			key="heal"
	if ICONS.has(key):
		button.icon=ICONS[key]
		button.expand_icon=true
		button.icon_alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_constant_override("icon_max_width",20)
		button.add_theme_constant_override("h_separation",9)
	if active:
		button.add_theme_color_override("font_color",CYAN)
		var selected_style=StyleBoxFlat.new()
		selected_style.bg_color=P.INTERACTIVE
		selected_style.border_color=CYAN
		selected_style.set_border_width_all(0)
		selected_style.border_width_bottom=2
		button.add_theme_stylebox_override("normal",selected_style)
	button.position=rect.position
	button.size=rect.size
	button.add_theme_font_size_override("font_size",15 if rect.size.x<=136 else 17)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _option(parent: Control, values: Array, current: String, rect: Rect2, callback: Callable) -> OptionButton:
	var option=OptionButton.new()
	option.position=rect.position
	option.size=rect.size
	option.add_theme_font_size_override("font_size",16)
	for value in values:
		option.add_item(C.SKILLS[value].label if C.SKILLS.has(value) else str(value))
		option.get_popup().set_item_tooltip(option.item_count-1,str(value))
	option.selected=maxi(0,values.find(current))
	option.item_selected.connect(func(index):callback.call(str(values[index])))
	parent.add_child(option)
	return option

func _label(parent: Control, text: String, rect: Rect2, size_px: int=20, color: Color=WHITE) -> Label:
	var label=Label.new()
	label.text=text
	label.position=rect.position
	label.size=rect.size
	label.add_theme_font_size_override("font_size",size_px)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _notify(text: String) -> void:
	message=text
	message_time=7.0
	if is_instance_valid(notice):
		notice.text=text
	print("PHASE / ",text)

func _panel(rect: Rect2) -> void:
	draw_rect(rect,PANEL)
	draw_line(rect.position,Vector2(rect.end.x,rect.position.y),EDGE,1)

func _text(text: String, position_px: Vector2, font_size: int, color: Color=WHITE, typeface: Font=null) -> void:
	draw_string(font if typeface==null else typeface,position_px,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _center(text: String, position_px: Vector2, font_size: int, color: Color=WHITE, typeface: Font=null) -> void:
	var f=font if typeface==null else typeface
	var width=f.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	draw_string(f,position_px-Vector2(width/2,0),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _bar(rect: Rect2, ratio: float, color: Color) -> void:
	draw_rect(rect,EDGE)
	draw_rect(Rect2(rect.position,Vector2(rect.size.x*clampf(ratio,0,1),rect.size.y)),color)

func _brackets(rect: Rect2, color: Color) -> void:
	for corner in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
		var p=rect.position+rect.size*corner
		var dx=1 if corner.x==0 else -1
		var dy=1 if corner.y==0 else -1
		draw_line(p,p+Vector2(12*dx,0),color,2,true)
		draw_line(p,p+Vector2(0,12*dy),color,2,true)

static func _hp(value: float) -> String:
	return str(int(value)) if value==floor(value) else "%.1f" % value

static func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x-b.x)+absi(a.y-b.y)

func _icon(parent: Control,key: String,rect: Rect2,tint: Color) -> void:
	var icon=TextureRect.new()
	icon.texture=ICONS[key]
	icon.position=rect.position
	icon.size=rect.size
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate=tint
	icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)

func _separator(parent: Control,rect: Rect2) -> void:
	var line=ColorRect.new()
	line.position=rect.position
	line.size=rect.size
	line.color=EDGE
	line.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)

func _focus_modal(layer: Control) -> void:
	if not is_instance_valid(layer) or layer.is_queued_for_deletion():
		return
	var controls=[]
	for control in layer.find_children("*","Control",true,false):
		if control.focus_mode==Control.FOCUS_ALL and control.is_visible_in_tree() and not (control is BaseButton and control.disabled):
			controls.append(control)
	if controls.is_empty():
		return
	for i in range(controls.size()):
		controls[i].focus_next=controls[(i+1)%controls.size()].get_path()
		controls[i].focus_previous=controls[(i-1+controls.size())%controls.size()].get_path()
	controls[0].grab_focus()

func _restore_focus(previous) -> void:
	if is_instance_valid(auxiliary):
		return
	var control=previous.get_ref() if previous is WeakRef else null
	if is_instance_valid(control) and not control.is_queued_for_deletion() and control.is_visible_in_tree():
		control.grab_focus()
	elif is_instance_valid(overlay):
		_focus_modal(overlay)

func _toggle_info() -> void:
	info_open=not info_open
	if battle.mode=="CHOICE":
		_action_dialog()
	else:
		_hud()
	queue_redraw()

func _toggle_phase() -> void:
	phase_open=not phase_open
	_hud()
	queue_redraw()

func _menu() -> void:
	_close_aux()
	var rows=[["HELP",_help],["SETTINGS",_settings]]
	if build_open:
		rows.append_array([["SAVE",_save],["LOAD",_load]])
	else:
		rows.append(["RESTART",_restart])
	rows.append(["QUIT",_quit])
	var panel=_modal(Rect2(765,250,390,150+rows.size()*58),true)
	_label(panel,"MENU",Rect2(24,18,342,35),25,WHITE)
	for i in range(rows.size()):
		var callback: Callable=rows[i][1]
		_button(panel,rows[i][0],Rect2(24,77+i*58,342,44),func():_close_aux();callback.call())
	_button(panel,"CLOSE / ESC",Rect2(24,90+rows.size()*58,342,40),_close_aux)

func _objective() -> void:
	_close_aux()
	var panel=_modal(Rect2(590,340,740,400),true)
	_label(panel,battle.stage.name,Rect2(32,25,676,40),25,WHITE)
	_label(panel,battle.stage.brief,Rect2(32,110,676,45),20,WHITE)
	_label(panel,battle.stage.hint,Rect2(32,185,676,100),18,MUTED)
	_button(panel,"CLOSE / ESC",Rect2(32,320,676,44),_close_aux)

func _order() -> void:
	_close_aux()
	var panel=_modal(Rect2(710,220,500,640),true)
	_label(panel,"ORDER",Rect2(32,23,436,40),25,WHITE)
	var totals={"PLAYER":0.0,"ENEMY":0.0}
	for u in battle.units:
		totals[u.camp]+=u.hp
	_label(panel,"HP  PLAYER %s / ENEMY %s" % [_hp(totals.PLAYER),_hp(totals.ENEMY)],Rect2(32,91,436,35),17,MUTED)
	var rows=battle.timeline(6)
	for i in range(rows.size()):
		var row=rows[i]
		_label(panel,"%s     T %.1f" % [battle.units[row.index].id,row.time],Rect2(32,159+i*55,436,38),22,WHITE)
	_button(panel,"CLOSE / ESC",Rect2(32,560,436,44),_close_aux)

func _drop_detail(drop: Dictionary) -> void:
	_close_aux()
	var panel=_modal(Rect2(610,310,700,460),true)
	if drop.has("skill"):
		_label(panel,C.SKILLS[drop.skill].label,Rect2(32,30,636,45),25,WHITE)
		_label(panel,drop.skill,Rect2(32,115,636,50),17,MUTED)
	else:
		_label(panel,C.serial(drop.kind,drop.stats,drop.mutation),Rect2(32,30,636,45),23,WHITE)
		var values=[]
		for i in range(5):
			values.append("%s %d" % [["VIT","INF","RES","SPD","LUK"][i],drop.stats[i]])
		_label(panel,"\n".join(values),Rect2(32,110,636,190),20,WHITE)
		_label(panel,drop.mutation,Rect2(32,315,636,35),17,MUTED)
	_button(panel,"CLOSE / ESC",Rect2(32,380,636,44),_close_aux)

func _info_selectors(parent: Control) -> void:
	for i in range(battle.units.size()):
		_button(parent,battle.units[i].id,Rect2(1440+i*75,95,65,40),func():
			selected=i
			if battle.mode=="CHOICE":
				_action_dialog()
			else:
				_hud()
			queue_redraw(),"",i==(selected if selected>=0 else battle.actor))
