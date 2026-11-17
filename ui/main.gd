## PHASEの一画面UIと手動操作を提供する。
extends Control
const C = preload("res://game/catalog.gd")
const M = preload("res://game/phase_math.gd")
const B = preload("res://game/battle.gd")
const TL = preload("res://ui/timeline.gd")
const L = preload("res://game/collection.gd")
const V = preload("res://ui/visuals.gd")
const T = preload("res://game/tuning.gd")
const P = preload("res://ui/palette.gd")
const WHITE = P.TEXT
const MUTED = P.MUTED
const BG = P.BG
const PANEL = P.SURFACE
const EDGE = P.EDGE
const PANEL_VIEWS = {
 "CLOCKWISE":{"icon":"rotate_cw","text":"CLOCKWISE / COREをSPD × 1.5度、時計回り","short":"CORE ↷"},
 "RESET":{"icon":"diamond","text":"RESET / COREを戦闘開始角へ戻す","short":"CORE開始角へ"},
 "COUNTERCLOCKWISE":{"icon":"restart","text":"COUNTERCLOCKWISE / COREをSPD × 1.5度、反時計回り","short":"CORE ↶"}
}
const ICONS = {
 "diamond":preload("res://assets/lucide/diamond.svg"),
 "rotate_cw":preload("res://assets/lucide/rotate-cw.svg"),
 "undo":preload("res://assets/lucide/undo-2.svg"),
 "fast_forward":preload("res://assets/lucide/fast-forward.svg"),
 "lock":preload("res://assets/lucide/lock.svg"),
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
var ring_colors: Array=P.ring_colors(palette_colors)
var CYAN: Color=palette_colors[0]
var MAGENTA: Color=palette_colors[0]
var palette_pickers: Array=[]
var palette_error: Label
var settings_path="res://artifacts/runtime/ui-settings.json"
const BOARD = T.BATTLE_BOARD_ORIGIN
const CELL = T.BATTLE_CELL
const BOARD_SCALE = CELL/70.0
const SAVE_PATH = "res://artifacts/runtime/phase-save.json"
var battle=B.new()
var collection=L.new()
var font: SystemFont
var mono: SystemFont
var overlay: Control
var auxiliary: Control
var hud: Control
var selected := -1
var timeline_hover := -1
var timeline_hover_event: Dictionary={}
var timeline_selected_event: Dictionary={}
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
var panel_rng := RandomNumberGenerator.new()
var panel_seed_override: Variant=null
var last_panel_seed: int=-1
var panel_probe: Control
var notice: Label
var preview_contours: Array=[]
var preview_signature: Array=[]
var preview_generation := 0
var result_awarded := false
var equipment_views: Dictionary={}
var window_focused := true

func _ready() -> void:
	get_window().focus_exited.connect(_window_focus_exited)
	get_window().focus_entered.connect(_window_focus_entered)
	get_window().mouse_exited.connect(_timeline_mouse_exited)
	loot_rng.randomize()
	panel_rng.randomize()
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
	panel_probe=preload("res://ui/panel_probe.gd").new()
	panel_probe.host=self
	panel_probe.position=BOARD
	panel_probe.size=Vector2.ONE*CELL*10
	panel_probe.mouse_filter=Control.MOUSE_FILTER_PASS
	panel_probe.focus_mode=Control.FOCUS_NONE
	panel_probe.visible=false
	add_child(panel_probe)
	battle.start(collection.stage_index,collection.builds)
	_hud()
	_build()

func _process(delta: float) -> void:
	panel_probe.visible=not build_open
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
	_draw_info()
	_draw_preview()
	if message_time>0 and not build_open:
		_text(message,T.BATTLE_MESSAGE_POSITION,18,CYAN)
	for t in toasts:
		var color: Color=t.color
		color.a=clampf((2.4-t.age)/0.7,0,1)
		var p: Vector2=_board_point(t.cell,Vector2(35,3-(t.age*24 if not reduced_motion else 0)))
		_center(t.text,p,24,color,mono)

func _draw_left() -> void:
	_text("PHASE",Vector2(T.BATTLE_LEFT_ORIGIN.x,T.BATTLE_TITLE_BASELINE),47,WHITE)
	var y=T.BATTLE_HP_BASELINE
	for camp in ["PLAYER","ENEMY"]:
		var hp=0.0
		var max_hp=0.0
		for u in battle.units:
			if u.camp==camp:
				hp+=u.hp
				max_hp+=u.max_hp
		var color=CYAN if camp=="PLAYER" else status_colors[1]
		var value="%s / %s" % [_hp(hp),_hp(max_hp)]
		var bar_start=maxf(T.BATTLE_HP_BAR.position.x,T.BATTLE_HP_VALUE_X+mono.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,T.BATTLE_HP_FONT_SIZE).x+T.BATTLE_HP_GAP)
		_text(camp,Vector2(T.BATTLE_LEFT_ORIGIN.x,y),T.BATTLE_HP_FONT_SIZE,color,mono)
		_text(value,Vector2(T.BATTLE_HP_VALUE_X,y),T.BATTLE_HP_FONT_SIZE,WHITE,mono)
		_bar(Rect2(Vector2(bar_start,y+T.BATTLE_HP_BAR.position.y),Vector2(T.BATTLE_HP_BAR.end.x-bar_start,T.BATTLE_HP_BAR.size.y)),hp/maxf(1,max_hp),color)
		y+=T.BATTLE_HP_STEP
	_draw_timeline()

func _timeline_view() -> Dictionary:
	return TL.layout(battle.units,battle.actor,TL.rows(battle),battle.mode=="RESULT")

func _draw_timeline() -> void:
	var view=_timeline_view()
	var pixel_scale=maxf(0.001,get_global_transform_with_canvas().get_scale().x*get_viewport().get_final_transform().get_scale().x)
	var width=maxf(T.TIMELINE_LINE,1.0/pixel_scale)
	var inspected=timeline_hover_event if not timeline_hover_event.is_empty() else timeline_selected_event
	for i in range(view.events.size()-1):
		var first=view.events[i]
		var next=view.events[i+1]
		draw_line(first.point+Vector2(0,first.radius),next.point-Vector2(0,next.radius),Color(MUTED,0.55),width,true)
	for link in view.links:
		var event=link.event
		# 接続線は選択やホバーでも通常の灰色を保ち、再登場の弱い線を維持する。
		draw_polyline(link.points,Color(MUTED,0.18 if event.repeated else 0.40),width,true)
	for card in view.cards:
		var active=card.index==selected or card.index==timeline_hover
		var color=CYAN if active else MUTED
		_ring(self,card.center,T.TIMELINE_RADIUS,card.unit,card.index==battle.actor)
		_center(_hp(card.unit.hp)+"/"+_hp(card.unit.max_hp),card.center+Vector2(0,38),T.TIMELINE_HP_FONT,color if active else WHITE,mono)
		_text("I %3.0f%%" % (M.sync(card.unit,1).factor*100),card.center+Vector2(-60,56),T.TIMELINE_FACTOR_FONT,status_colors[1],mono)
		_text("R %3.0f%%" % (M.sync(card.unit,2).factor*100),card.center+Vector2(6,56),T.TIMELINE_FACTOR_FONT,status_colors[2],mono)
	for event in view.events:
		var active=_timeline_matches(event,inspected) or (inspected.is_empty() and event.index==selected and not event.repeated)
		_timeline_node(event,CYAN if active or event.rank==1 else WHITE,pixel_scale)

func _timeline_node(event: Dictionary, color: Color, pixel_scale: float) -> void:
	var width=maxf(T.TIMELINE_NODE_WIDTH,1.0/pixel_scale)
	draw_arc(event.point,event.radius,-PI/2,PI*1.5,48,Color(MUTED,0.45),width,true)
	if event.progress_fraction>0:
		draw_arc(event.point,event.radius,-PI/2,-PI/2+TAU*event.progress_fraction,maxi(4,ceili(48*event.progress_fraction)),WHITE,width,true)
	if event.rank==1:
		draw_circle(event.point,minf(3.0,event.radius*0.4),color,true,-1.0,true)

func _timeline_matches(event: Dictionary, inspected: Dictionary) -> bool:
	return inspected.has("time") and event.index==inspected.index and absf(event.time-inspected.time)<=B.TIME_EPS


func _draw_board() -> void:
	var effect_chips=[]
	for y in range(10):
		for x in range(10):
			var cell=Vector2i(x,y)
			var pos=_board_point(cell)
			var rect=Rect2(pos+Vector2.ONE*BOARD_SCALE,Vector2(68,68)*BOARD_SCALE)
			var panel=battle.panels.get(cell,"NORMAL")
			var color=Color("0d1013") if (x+y)%2==0 else Color("090c0f")
			if panel!="NORMAL":
				color=Color("13181d")
			if battle.path.has(cell):
				color=Color(CYAN,0.16)
			if cell==hover_cell and not is_instance_valid(overlay):
				color=color.lightened(0.055)
			draw_rect(rect,color)
			draw_rect(rect,EDGE,false,1)
			if panel!="NORMAL":
				var pc=MAGENTA if panel=="COUNTERCLOCKWISE" else (status_colors[3] if panel=="RESET" else CYAN)
				_draw_panel_icon(panel,Rect2(pos+T.PANEL_ICON_OFFSET,Vector2.ONE*T.PANEL_ICON_SIZE),pc)
			if cell==battle.stage.goal:
				draw_rect(rect.grow(-4),Color(MAGENTA,0.6),false,1)
				_text("GOAL",pos+Vector2(6,62)*BOARD_SCALE,11,MAGENTA,mono)
			if cell==battle.stage.enemy_goal:
				draw_rect(rect.grow(-4),status_colors[1],false,2)
				_text("LOSS",pos+Vector2(6,62)*BOARD_SCALE,11,status_colors[1],mono)
			if battle.mode=="TARGET" and _distance(cell,battle.units[battle.actor].pos)==1:
				var tc=status_colors[1] if battle.selected_skill==C.DAMAGE else status_colors[2]
				draw_rect(rect,Color(tc,0.12))
				draw_rect(rect.grow(-3),Color(tc,0.7),false,1.5)
			var i=battle.at(cell)
			if i>=0:
				var u: Dictionary=battle.units[i]
				var center=pos+T.UNIT_BOARD_CENTER*BOARD_SCALE
				_ring(self,center,T.UNIT_BOARD_RADIUS*BOARD_SCALE,u,i==battle.actor)
				if i==selected or i==timeline_hover:
					_brackets(Rect2(pos+Vector2(5,5)*BOARD_SCALE,Vector2(60,60)*BOARD_SCALE),MAGENTA)
				if battle.mode=="TARGET" and battle.valid_target(battle.actor,i,battle.selected_skill):
					var tc=status_colors[1] if battle.selected_skill==C.DAMAGE else status_colors[2]
					draw_rect(rect.grow(-1),tc,false,2)
					var amount=M.effect(battle.units[battle.actor],u,C.SKILLS[battle.selected_skill].effect)
					if battle.selected_skill==C.HEAL:
						amount=mini(amount,ceili(u.max_hp-u.hp))
					effect_chips.append({"cell":cell,"text":("-" if battle.selected_skill==C.DAMAGE else "+")+str(amount),"color":tc})
	if battle.mode=="MOVE":
		for segment in _route_segments():
			draw_line(segment[0],segment[1],CYAN,T.ROUTE_LINE_WIDTH*BOARD_SCALE,true)
		for i in range(battle.path.size()):
			var center=_board_point(battle.path[i],Vector2(35,35))
			draw_circle(center,T.ROUTE_NODE_RADIUS*BOARD_SCALE,WHITE)
			_center(str(i+1),center+Vector2(0,6)*BOARD_SCALE,roundi(17*BOARD_SCALE),BG,mono)
		if not battle.path.is_empty():
			_brackets(Rect2(_board_point(battle.path.back(),Vector2(3,3)),Vector2(64,64)*BOARD_SCALE),CYAN)
	# 全セルの描画後に重ね、次の行の背景で数字を隠さない。
	for chip in effect_chips:
		var rect=_effect_chip_rect(chip.cell)
		draw_rect(rect,BG)
		draw_rect(rect,chip.color,false,1)
		_center(chip.text,rect.position+Vector2(rect.size.x/2,16*BOARD_SCALE),roundi(16*BOARD_SCALE),chip.color,mono)

func _draw_panel_icon(kind: String, rect: Rect2, color: Color) -> void:
	draw_texture_rect(ICONS[PANEL_VIEWS[kind].icon],rect,false,color)

## セルの説明を返す。cellは盤面座標。戻り値は特殊効果の正確な意味、通常や盤外なら空文字。戦闘を変更しない。
func panel_description(cell: Vector2i) -> String:
	var kind: String=battle.panels.get(cell,"NORMAL") if Rect2i(0,0,10,10).has_point(cell) else "NORMAL"
	return PANEL_VIEWS[kind].text if PANEL_VIEWS.has(kind) else ""

func _route_segments() -> Array:
	var segments=[]
	var pixel_scale=maxf(0.001,get_viewport_transform().get_scale().x*get_global_transform().get_scale().x)
	var unit_clear=V.route_unit_clearance(T.UNIT_BOARD_RADIUS*BOARD_SCALE,T.ROUTE_LINE_WIDTH*BOARD_SCALE,pixel_scale)
	var node_clear=(T.ROUTE_NODE_RADIUS+T.ROUTE_LINE_WIDTH/2)*BOARD_SCALE
	var prev: Vector2i=battle.units[battle.actor].pos
	for cell in battle.path:
		var start_clear=unit_clear if battle.at(prev)>=0 else node_clear
		var end_clear=unit_clear if battle.at(cell)>=0 else node_clear
		var segment=V.route_segment(_board_point(prev,Vector2(35,35)),_board_point(cell,Vector2(35,35)),start_clear,end_clear)
		if not segment.is_empty():
			segments.append(segment)
		prev=cell
	return segments

func _effect_chip_rect(cell: Vector2i) -> Rect2:
	return Rect2(_board_point(cell,Vector2(25,2)),Vector2(43,22)*BOARD_SCALE)

func _board_point(cell: Vector2i, offset: Vector2=Vector2.ZERO) -> Vector2:
	return BOARD+Vector2(cell)*CELL+offset*BOARD_SCALE

func _draw_info() -> void:
	var index=selected if selected>=0 else battle.actor
	var u: Dictionary=battle.units[index]
	var camp_color=CYAN if u.camp=="PLAYER" else status_colors[1]
	_text("CLASS: "+u.class_name,T.BATTLE_INFO_CLASS,17,camp_color,mono)
	_ring(self,T.BATTLE_INFO_RING,81,u,index==battle.actor)
	_text("MOVE %d" % battle.movement(u),T.BATTLE_INFO_MOVE,16,CYAN,mono)
	_text("Move up to %d cells per turn." % battle.movement(u),T.BATTLE_INFO_MOVE+T.BATTLE_INFO_DESCRIPTION_OFFSET,T.BATTLE_INFO_DESCRIPTION_FONT,MUTED)
	var position_px=T.BATTLE_INFO_DETAILS
	for part in ["GEAR","ARMS"]:
		var mutation: String=u[part.to_lower()+"_mutation"]
		_text(C.serial(part,u[part.to_lower()],mutation),position_px,15,WHITE,mono)
		position_px.y+=T.BATTLE_EQUIPMENT_STEP
	position_px.y+=T.BATTLE_EQUIPMENT_GAP
	for id in u.skills:
		_text(C.SKILLS[id].label,position_px,15,WHITE,mono)
		_text(C.SKILLS[id].description,position_px+T.BATTLE_INFO_DESCRIPTION_OFFSET,T.BATTLE_INFO_DESCRIPTION_FONT,MUTED)
		position_px.y+=T.BATTLE_SKILL_STEP

func _draw_preview() -> void:
	var u=battle.preview()
	var signature=[u.core,u.gear,u.arms,u.class_name,u.gear_mutation,u.arms_mutation,u.get("core_angle",0.0),u.gear_angle,u.arms_angle,status_colors]
	if signature!=preview_signature:
		preview_signature=signature.duplicate(true)
		preview_contours=V.phase_contours(u,status_colors)
		preview_generation+=1
	V.phase_orbit(self,T.PREVIEW_CENTER,preview_contours)
	_ring(self,T.PREVIEW_CENTER,T.PREVIEW_RADIUS,u)
	if M.singularity(u):
		_text("×5",Vector2(T.PREVIEW_PANEL.position.x+286,T.PREVIEW_SYNC_BASELINE),15,MAGENTA,mono)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if build_open or not window_focused or is_instance_valid(auxiliary) or is_instance_valid(overlay):
			_timeline_mouse_exited()
		else:
			timeline_hover_event=TL.hit(_timeline_view(),event.position)
			timeline_hover=timeline_hover_event.get("index",-1)

func _timeline_mouse_exited() -> void:
	timeline_hover=-1
	timeline_hover_event={}

func _unhandled_input(event: InputEvent) -> void:
	if not window_focused:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_F1:
			_help()
		elif event.keycode==KEY_ESCAPE:
			if is_instance_valid(auxiliary):
				_close_aux()
			elif battle.mode=="TARGET":
				battle.back()
				_action_dialog()
			elif battle.mode=="MOVE" and not build_open:
				battle.path=[]
		return
	if build_open or is_instance_valid(auxiliary) or is_instance_valid(overlay):
		timeline_hover=-1
		timeline_hover_event={}
		return
	if event is InputEventMouseMotion:
		var p=event.position-BOARD
		hover_cell=Vector2i(floori(p.x/CELL),floori(p.y/CELL)) if Rect2(BOARD,Vector2.ONE*CELL*10).has_point(event.position) else Vector2i(-1,-1)
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		# Godotが拡縮と余白を変換済みの、そのイベントの論理座標を使う。
		var p=event.position
		if Rect2(BOARD,Vector2.ONE*CELL*10).has_point(p):
			_cell_input(Vector2i(floori((p.x-BOARD.x)/CELL),floori((p.y-BOARD.y)/CELL)),event.double_click)
		else:
			var hit=TL.hit(_timeline_view(),p)
			if not hit.is_empty():
				selected=hit.index
				timeline_selected_event=hit.duplicate(true)

func _window_focus_exited() -> void:
	window_focused=false
	timeline_hover=-1
	timeline_hover_event={}
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
	timeline_selected_event={}
	timeline_hover=-1
	timeline_hover_event={}
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
	timeline_hover=-1
	timeline_hover_event={}
	timeline_selected_event={}
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
		hud.queue_free()
	hud=Control.new()
	hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	var rows=[["HELP",1218,_help],["SETTINGS",1346,_settings],["RESTART",1492,_restart],["QUIT",1640,_quit]]
	for i in range(rows.size()):
		var row=rows[i]
		var rect=Rect2(row[1],1025,118,40) if build_open else Rect2(T.BATTLE_MENU_ORIGIN+Vector2(i%2,floori(i/2.0))*(T.BATTLE_MENU_SIZE+T.BATTLE_MENU_GAP),T.BATTLE_MENU_SIZE)
		_button(hud,row[0],rect,row[2])
	if battle.mode=="TARGET":
		_button(hud,"BACK",T.BATTLE_CONTEXT_BUTTON,func():battle.back();_action_dialog())
	elif battle.mode=="MOVE" and battle.trapped():
		_button(hud,"WAIT",T.BATTLE_CONTEXT_BUTTON,func():battle.wait_turn();_after_action())

func _action_dialog() -> void:
	_clear_overlay()
	_hud()
	var active=[]
	for skill in battle.units[battle.actor].skills:
		if C.SKILLS[skill].type=="ACTIVE":
			active.append(skill)
	var height=122+active.size()*63
	var panel=_modal(Rect2(700,330,420,height),false,true)
	_label(panel,"UNIT "+V.unit_name(battle.units[battle.actor])+" / ACTION",Rect2(25,16,370,32),22,CYAN)
	_button(panel,"WAIT",Rect2(25,63,370,48),func():battle.wait_turn();_after_action())
	for i in range(active.size()):
		var skill: String=active[i]
		var button=_button(panel,C.SKILLS[skill].label,Rect2(25,126+i*63,370,48),func():battle.choose_skill(skill);_clear_overlay();_hud())
		var available=false
		for target in range(battle.units.size()):
			if battle.valid_target(battle.actor,target,skill):
				available=true
		button.disabled=not available
		button.tooltip_text="No valid adjacent target." if not available else ""

func _build() -> void:
	build_open=true
	selected=-1
	battle.start(collection.stage_index,collection.builds)
	_clear_overlay()
	var panel=_modal(Rect2(300,115,1320,810),false)
	_label(panel,"BUILD",Rect2(36,25,920,45),32,WHITE)
	_label(panel,"1 / 2     SHARED ARCHIVE     BOTH SIDES: HUMAN",Rect2(36,78,1100,29),19,MUTED)
	for i in range(2):
		_button(panel,"UNIT %d" % (i+1),Rect2(36+i*200,126,185,43),func():edit_unit=i;_build(),"",i==edit_unit)
	_label(panel,"ARCHIVE   %d ARMS / %d GEAR / %d MUTATIONS" % [collection.items.ARMS.size(),collection.items.GEAR.size(),collection.mutations.size()],Rect2(36,187,1150,22),14,CYAN)
	var b: Dictionary=collection.builds[edit_unit]
	_label(panel,"CLASS",Rect2(36,237,160,30),16,MUTED)
	_option(panel,["STANDARD","REVERSE"],b.class_name,Rect2(210,230,390,43),func(value):b.class_name=value;_refresh_build())
	_label(panel,"CORE / TOTAL 100",Rect2(36,292,560,27),16,MUTED)
	core_controls=[]
	equipment_views={}
	for k in range(5):
		_label(panel,["VIT","INF","RES","SPD","LUK"][k],Rect2(36+k*116,326,100,25),17,status_colors[k])
		var spin=SpinBox.new()
		spin.position=Vector2(36+k*116,359)
		spin.size=Vector2(102,46)
		spin.min_value=1
		spin.max_value=96
		spin.step=1
		spin.value=b.core[k]
		panel.add_child(spin)
		core_controls.append(spin)
		spin.value_changed.connect(func(value):_core_change(k,int(value)))
	_label(panel,"Σ 100   /   MIN 1   /   AUTOMATIC REDISTRIBUTION",Rect2(36,414,570,27),14,MUTED)
	for r in range(2):
		var key="arms" if r==0 else "gear"
		var y=454+r*128
		_label(panel,key.to_upper(),Rect2(36,y,170,28),17,WHITE)
		var choices: Array=collection.items[key.to_upper()].keys()
		var view=Control.new()
		view.position=Vector2(36,y+40)
		view.size=Vector2(564,27)
		view.mouse_filter=Control.MOUSE_FILTER_IGNORE
		view.set_meta("before",b[key].duplicate())
		panel.add_child(view)
		equipment_views[key]=view
		view.draw.connect(func():
			for status in range(5):
				var delta=int(b[key][status])-int(view.get_meta("before")[status])
				view.draw_line(Vector2(status*112,24),Vector2(status*112+minf(b[key][status],100)*0.85,24),status_colors[status],2)
				var text="%s %d" % [["VIT","INF","RES","SPD","LUK"][status],b[key][status]]
				if delta!=0:
					text+=" (%+d)" % delta
				view.draw_string(font,Vector2(status*112,20),text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,status_colors[status]))
		var option=_option(panel,choices,C.serial(key.to_upper(),b[key]),Rect2(210,y-5,390,40),func(value):
			view.set_meta("before",b[key].duplicate())
			b[key]=collection.items[key.to_upper()][value].duplicate()
			_refresh_build())
		for index in range(choices.size()):
			option.get_popup().set_item_tooltip(index,_equipment_comparison(collection.items[key.to_upper()][choices[index]],b[key]))
		option.item_selected.connect(func(_index):
			for index in range(choices.size()):
				option.get_popup().set_item_tooltip(index,_equipment_comparison(collection.items[key.to_upper()][choices[index]],b[key])))
		_label(panel,"MUTATION",Rect2(36,y+77,170,24),14,MUTED)
		_option(panel,collection.mutations,b[key+"_mutation"],Rect2(210,y+70,390,34),func(value):b[key+"_mutation"]=value;_refresh_build())
	_label(panel,"MODEL: hover to compare   /   Δ: previous equipment",Rect2(36,695,600,24),12,MUTED)
	_label(panel,"SKILLS / 3 SLOTS",Rect2(688,328,580,30),15,MUTED)
	for i in range(3):
		var choices=["NONE"]
		choices.append_array(collection.skills)
		var current: String=b.skills[i] if i<b.skills.size() else "NONE"
		_option(panel,choices,current,Rect2(688,368+i*49,588,41),func(value):_skill_change(i,value))
	_label(panel,"OPERATION",Rect2(688,536,570,26),16,MUTED)
	var stages=[]
	for s in C.stages():
		stages.append(s.name)
	_option(panel,stages,C.stages()[collection.stage_index].name,Rect2(688,573,588,42),func(value):collection.stage_index=stages.find(value);_build())
	_label(panel,_unit_references(C.stages()[collection.stage_index].brief),Rect2(688,626,588,27),17,MAGENTA)
	_label(panel,_unit_references(C.stages()[collection.stage_index].hint),Rect2(688,660,588,48),16,MUTED)
	build_preview=Control.new()
	build_preview.position=Vector2(688,115)
	build_preview.size=Vector2(588,196)
	build_preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_child(build_preview)
	var preview=build_preview
	preview.draw.connect(func():
		var u=C.unit("%02d" % (edit_unit+1),"PLAYER",Vector2i.ZERO,collection.builds[edit_unit])
		_ring(preview,Vector2(100,103),79,u,true)
		preview.draw_string(mono,Vector2(220,84),"HP %s / MOVE %d" % [_hp(u.max_hp),battle.movement(u)],HORIZONTAL_ALIGNMENT_LEFT,-1,20,WHITE)
		preview.draw_string(mono,Vector2(220,119),"DELAY %.1f / INF %.1f%%" % [M.delay(u),M.sync(u,1).factor*100],HORIZONTAL_ALIGNMENT_LEFT,-1,16,CYAN))
	for row in [["SAVE",36,_save],["LOAD",151,_load],["HELP",266,_help],["SETTINGS",381,_settings],["QUIT",526,_quit]]:
		_button(panel,row[0],Rect2(row[1],730,106 if row[0]!="SETTINGS" else 136,44),row[2])
	_button(panel,"START",Rect2(934,730,342,48),_start_battle)
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
	for k in range(5):
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
	selected=-1
	timeline_hover=-1
	timeline_hover_event={}
	timeline_selected_event={}
	result_awarded=false
	var layout_seed=int(panel_seed_override) if panel_seed_override!=null else panel_rng.randi()
	while panel_seed_override==null and layout_seed==last_panel_seed:
		layout_seed=panel_rng.randi()
	last_panel_seed=layout_seed
	battle.start(collection.stage_index,collection.builds,layout_seed)
	_clear_overlay()
	_hud()
	_notify("UNIT %s / %s — Click adjacent empty cells, then double-click the endpoint." % [V.unit_name(battle.units[battle.actor]),battle.units[battle.actor].camp])

func _result() -> void:
	if battle.mode!="RESULT" or battle.result.is_empty():
		return
	_clear_overlay()
	if not result_awarded:
		drops=collection.roll_loot(loot_rng)
		result_awarded=true
	var panel=_modal(Rect2(530,240,860,540),false)
	_icon(panel,"check" if battle.result=="VICTORY" else "close",Rect2(40,42,48,48),CYAN if battle.result=="VICTORY" else status_colors[1])
	_label(panel,battle.result,Rect2(110,35,710,66),48,CYAN if battle.result=="VICTORY" else status_colors[1])
	_label(panel,"%s / %d TURNS" % [battle.stage.name,battle.turn],Rect2(40,120,780,34),19,MUTED)
	_label(panel,"ARCHIVE / NEW SIGNALS",Rect2(40,187,780,27),16,MUTED)
	var y=235
	if drops.is_empty():
		_label(panel,"0 / NO NEW SIGNALS",Rect2(40,y,780,40),23,WHITE)
	for drop in drops:
		if drop.has("skill"):
			_label(panel,C.SKILLS[drop.skill].label,Rect2(40,y,780,33),22,CYAN)
			_label(panel,drop.skill,Rect2(40,y+36,780,30),14,MUTED)
		else:
			var title=C.serial(drop.kind,drop.stats,drop.mutation) if drop.new_item else "MUTATION / "+drop.mutation
			_label(panel,title,Rect2(40,y,780,33),20,CYAN)
			var values=[]
			for i in range(5):
				values.append("%s %d" % [["VIT","INF","RES","SPD","LUK"][i],drop.stats[i]])
			_label(panel," / ".join(values)+(" / "+drop.mutation if drop.new_mutation else ""),Rect2(40,y+36,780,35),16,MUTED)
		y+=91
	_button(panel,"RETURN TO BUILD",Rect2(40,440,780,54),_build)

func _help() -> void:
	_close_aux()
	var panel=_modal(Rect2(400,135,1120,810),true)
	_label(panel,"HELP",Rect2(36,25,1048,48),32,WHITE)
	_label(panel,"両陣営を手動で操作する。敵CPUはない。",Rect2(36,85,1048,30),19,MUTED)
	var steps=[
		["move","01 / ROUTE","隣接する空きマスを順番にクリック。\n経路上をクリックすると後続を取消。"],
		["target","02 / ALIGN","4輪郭はCORE、GEAR、ARMSと全体。\n実位相の一致を示し、境界色を補間。"],
		["check","03 / ACT","終点をダブルクリックして確定。\nWAITかスキルを選び、対象をクリック。"]
	]
	for i in range(3):
		var x=36+i*354
		_icon(panel,steps[i][0],Rect2(x,153,28,28),CYAN)
		_label(panel,steps[i][1],Rect2(x+42,149,298,32),20,WHITE)
		_label(panel,steps[i][2],Rect2(x,201,340,76),18,MUTED)
	_separator(panel,Rect2(36,300,1048,1))
	_label(panel,"MOVEMENT",Rect2(36,329,490,28),16,CYAN)
	_label(panel,"上下左右のみ。生存ユニットのマスは通れない。\n毎手番1歩以上。無移動WAITは閉塞時のみ。\n開始マスかEscで全取消。同じマスへ再進入不可。\nBACKは移動を保持してスキルを選び直す。\n白は相対進捗、灰は残り。満周は待ち0。\n表示最大の待ち量で再計算。個別周期ではない。\n縦は順番。中心点が手番。満周でも順番待ち。",Rect2(36,377,500,174),18,WHITE)
	_label(panel,"PHASE",Rect2(580,329,500,28),16,CYAN)
	_label(panel,"鮮明な所ほど同じステータスが一致。\nINF / RESはLUK補助後の最終補正(最大200%)。\n全セルでGEAR ↶、ARMS ↷\nCORE回転はSPD × 1.5度、リセットは戦闘開始角。\n×5: 生INF完全一致 + CORE INF ≤10",Rect2(580,377,510,152),18,WHITE)
	var panel_kinds=["CLOCKWISE","RESET","COUNTERCLOCKWISE"]
	for i in range(panel_kinds.size()):
		var view=PANEL_VIEWS[panel_kinds[i]]
		_icon(panel,view.icon,Rect2(580+i*172,514,20,20),CYAN)
		_label(panel,view.short,Rect2(608+i*172,512,140,28),14,WHITE)
	if not build_open:
		_label(panel,"%s / SEED %d" % [battle.stage.name,battle.panel_seed],Rect2(36,704,1048,24),13,MUTED)
	_separator(panel,Rect2(36,560,1048,1))
	_label(panel,"BUILD / ARCHIVE",Rect2(36,589,490,28),16,CYAN)
	_label(panel,"1と2を編集し、装備の5値と差分を比較する。\nスキルは最大3。NONEも可。取得品と変異は共有。",Rect2(36,631,500,66),18,WHITE)
	_label(panel,"READING THE SIGNAL",Rect2(580,589,500,28),16,CYAN)
	_label(panel,"−はダメージ、＋は回復。\nINFは攻撃と回復、RESは抵抗。\nSAVE / LOADは明示操作。以前の保存は退避する。",Rect2(580,631,510,66),18,WHITE)
	_button(panel,"CLOSE / ESC",Rect2(36,736,1048,44),_close_aux)

func _settings() -> void:
	_close_aux()
	var panel=_modal(Rect2(430,135,1060,810),true)
	_label(panel,"SETTINGS",Rect2(36,25,960,48),32,WHITE)
	_label(panel,"DISPLAY",Rect2(36,98,400,28),14,MUTED)
	_button(panel,"WINDOWED",Rect2(36,138,470,48),func():DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED))
	_button(panel,"FULLSCREEN",Rect2(524,138,500,48),func():DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN))
	var check=CheckButton.new()
	check.text="REDUCED MOTION"
	check.position=Vector2(36,205)
	check.size=Vector2(988,46)
	check.button_pressed=reduced_motion
	check.toggled.connect(func(value):reduced_motion=value)
	panel.add_child(check)
	_label(panel,"COLOR / ACCENT + FIVE SIGNALS",Rect2(36,286,988,28),16,MUTED)
	var presets=P.PRESETS.keys()
	for i in range(presets.size()):
		var preset: String=presets[i]
		_button(panel,preset,Rect2(36+i*332,335,316,44),func():
			for k in range(6):
				palette_pickers[k].color=P.PRESETS[preset][k])
	palette_pickers=[]
	for i in range(6):
		_label(panel,["ACCENT","VIT","INF","RES","SPD","LUK"][i],Rect2(36+i*166,422,150,28),16,WHITE)
		var picker=ColorPickerButton.new()
		picker.position=Vector2(36+i*166,464)
		picker.size=Vector2(150,64)
		picker.color=palette_colors[i]
		picker.edit_alpha=false
		picker.tooltip_text="Choose color / "+["ACCENT","VIT","INF","RES","SPD","LUK"][i]
		panel.add_child(picker)
		var editor=picker.get_picker()
		editor.sampler_visible=false
		editor.color_modes_visible=false
		editor.sliders_visible=false
		editor.presets_visible=false
		palette_pickers.append(picker)
	_label(panel,"RINGS: VIVID PRESETS / CUSTOM COLORS AS CHOSEN",Rect2(36,558,988,30),15,MUTED)
	palette_error=_label(panel,"",Rect2(36,600,988,52),17,status_colors[1])
	_button(panel,"APPLY COLORS",Rect2(36,676,988,48),_apply_colors,"check")
	_button(panel,"CLOSE / ESC",Rect2(36,742,988,42),_close_aux,"close")

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
	_settings()
	palette_error.text="APPLIED / Saved separately from your build."
	palette_error.add_theme_color_override("font_color",CYAN)
	queue_redraw()

func _set_theme() -> void:
	CYAN=palette_colors[0]
	MAGENTA=palette_colors[0]
	status_colors=palette_colors.slice(1)
	ring_colors=P.ring_colors(palette_colors)
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
			style.set_border_width_all(2 if state=="focus" else 1)
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

func _unit_references(text: String) -> String:
	return RegEx.create_from_string("\\b0([12])\\b").sub(text,"$1",true)

func _ring(canvas: CanvasItem,center: Vector2,radius: float,u: Dictionary,active: bool=false) -> void:
	V.ring(canvas,center,radius,u,active,ring_colors,CYAN,mono)

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
		auxiliary.queue_free()
	auxiliary=null
	_restore_focus.call_deferred(previous)

func _clear_overlay() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay=null
	build_preview=null

func _modal(rect: Rect2, is_aux: bool, keep_context: bool=false) -> Control:
	timeline_hover=-1
	timeline_hover_event={}
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
		selected_style.set_border_width_all(1)
		selected_style.border_width_bottom=3
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
	draw_rect(rect,Color("232a30"))
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
