## PHASEの一画面UIと手動操作を提供する。
extends Control
const I=preload("res://game/unit_identity.gd")
const A=preload("res://game/assembly_identity.gd")
const ASSEMBLY_DIALOG=preload("res://ui/assembly_dialog.gd")
const C = preload("res://game/catalog.gd")
const M = preload("res://game/phase_math.gd")
const B = preload("res://game/battle.gd")
const F = preload("res://game/rotation_field.gd")
const TL = preload("res://ui/timeline.gd")
const L = preload("res://game/collection.gd")
const DEBUG_SESSION = preload("res://game/debug_session.gd")
const BUILD_CHOICES = preload("res://game/build_choices.gd")
const BUILD_DIALOG = preload("res://ui/build_dialog.gd")
const V = preload("res://ui/visuals.gd")
const T = preload("res://game/tuning.gd")
const P = preload("res://ui/palette.gd")
const LANGUAGE=preload("res://ui/language.gd")
const CPU = preload("res://game/cpu_policy.gd")
const CPU_TURN = preload("res://ui/cpu_turn.gd")
const MOVEMENT = preload("res://ui/movement.gd")
const TURN_PLAN = preload("res://ui/turn_plan.gd")
const WHITE = P.TEXT
const MUTED = P.MUTED
const BG = P.BG
const PANEL = P.SURFACE
const EDGE = P.EDGE
const PANEL_VIEWS = {
 "CLOCKWISE":{"icon":"rotate_cw","text":"CORE CLOCKWISE\nCORE +SPD x 1.5 deg. Equipment turns normally.","short":"CORE ↷"},
 "RESET":{"icon":"diamond","text":"CORE RESET\nRestore the battle-start CORE angle. Equipment still turns.","short":"CORE RESET"},
 "COUNTERCLOCKWISE":{"icon":"restart","text":"CORE COUNTERCLOCKWISE\nCORE -SPD x 1.5 deg. Equipment turns normally.","short":"CORE ↶"}
}
const ICONS = {
 "gear":preload("res://assets/lucide/shield.svg"),
 "arms":preload("res://assets/lucide/sword.svg"),
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
var copy_language=LANGUAGE.new()
var preferred_locale_override: Variant=null
var language_selector: OptionButton
var language_note: Label
var settings_path="res://artifacts/runtime/ui-settings.json"
const BOARD = T.BATTLE_BOARD_ORIGIN
const CELL = T.BATTLE_CELL
const BOARD_SCALE = CELL/70.0
const SAVE_PATH = "res://artifacts/runtime/phase-save.json"
# 検証では実ユーザー保存へ触れず、専用の保存先を注入する。
var save_path=SAVE_PATH
var battle=B.new()
var collection=L.new()
var debug_session=DEBUG_SESSION.new()
var debug_ui_state: Dictionary={}
var debug_notice: Label
var font: SystemFont
var mono: SystemFont
var overlay: Control
var auxiliary: Control
var hud: Control
var selected := -1
var movement=MOVEMENT.new()
var convergences: Array=[]
var planning=TURN_PLAN.new()
var playback_command: Dictionary={}
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
var build_dialog: Control
var assembly_button: Button
var assembly_dialog: Control
var opponent_assembly: Dictionary=A.default_profile("ENEMY")
var view_camp="PLAYER"
var name_edit: LineEdit
var name_hint: Label
var name_before_edit=""
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
var panel_hint: Control
var panel_probe: Control
var notice: Label
var preview_contours: Array=[]
var preview_points: Array=[]
var preview_signature: Array=[]
var preview_generation := 0
var result_awarded := false
var equipment_views: Dictionary={}
var window_focused := true
var cpu_enabled := false
var cpu_fast := false
var cpu_paused := false
var cpu_policy=CPU.new()
var cpu_turn=CPU_TURN.new()
var cpu_memory: Array=[]
var followed_turn: Array=[]

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
	copy_language.preferred_locale=TranslationServer.get_locale() if preferred_locale_override==null else str(preferred_locale_override)
	copy_language.selection=LANGUAGE.read_from(settings_path+".language.json")
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
	debug_notice=Label.new()
	debug_notice.text="DEBUG / NOT SAVED"
	debug_notice.position=T.DEBUG_BADGE_RECT.position
	debug_notice.size=T.DEBUG_BADGE_RECT.size
	debug_notice.add_theme_font_size_override("font_size",T.DEBUG_BADGE_FONT)
	debug_notice.add_theme_color_override("font_color",CYAN)
	debug_notice.mouse_filter=Control.MOUSE_FILTER_IGNORE
	debug_notice.z_index=1001
	debug_notice.visible=false
	add_child(debug_notice)
	panel_probe=preload("res://ui/panel_probe.gd").new()
	panel_probe.host=self
	panel_probe.position=BOARD
	panel_probe.size=Vector2.ONE*CELL*10
	panel_probe.mouse_filter=Control.MOUSE_FILTER_PASS
	panel_probe.focus_mode=Control.FOCUS_NONE
	panel_probe.visible=false
	add_child(panel_probe)
	panel_hint=Control.new()
	panel_hint.position=T.PANEL_HINT_RECT.position
	panel_hint.size=T.PANEL_HINT_RECT.size
	panel_hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(panel_hint)
	_label(panel_hint,"",Rect2(0,0,T.PANEL_HINT_RECT.size.x,22),T.PANEL_HINT_TITLE_FONT,WHITE)
	var hint_scroll=ScrollContainer.new()
	hint_scroll.position=Vector2(0,24);hint_scroll.size=Vector2(T.PANEL_HINT_RECT.size.x,48)
	hint_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	hint_scroll.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel_hint.add_child(hint_scroll)
	var detail=_label(hint_scroll,"",Rect2(0,0,T.PANEL_HINT_RECT.size.x-14,48),T.PANEL_HINT_DETAIL_FONT,MUTED,true)
	detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	panel_hint.visible=false
	battle.start(collection.stage_index,collection.builds,0,collection.unit_names)
	_hud()
	_build()

func _process(delta: float) -> void:
	if debug_session.active() and not debug_session.available():_toggle_debug(false)
	debug_notice.visible=collection.temporary
	_advance_convergence(delta)
	_movement_tick(delta)
	_cpu_tick(delta)
	_follow_turn()
	panel_probe.visible=not build_open
	_update_panel_hint()
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
		_text(_explain(message),T.BATTLE_MESSAGE_POSITION,18,CYAN)
	for t in toasts:
		var color: Color=t.color
		color.a=clampf((2.4-t.age)/0.7,0,1)
		var p: Vector2=_board_point(t.cell,Vector2(35,3-(t.age*24 if not reduced_motion else 0)))
		_center(t.text,p,24,color,mono)

func _assembly_rows() -> Array:
	var rows=[]
	var width=0.0
	for camp in ["PLAYER","ENEMY"]:
		var hp=0.0;var maximum=0.0
		for u in battle.units:
			if u.camp==camp:hp+=u.hp;maximum+=u.max_hp
		var text="%s / %s" % [_hp(hp),_hp(maximum)]
		var text_width=mono.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,T.BATTLE_HP_FONT_SIZE).x
		width=maxf(width,text_width)
		rows.append({"camp":camp,"hp":hp,"maximum":maximum,"text":text,"text_width":text_width})
	var bar_end=T.BATTLE_HP_RIGHT-width-T.BATTLE_HP_GAP
	var baseline_offset=(mono.get_ascent(T.BATTLE_HP_FONT_SIZE)-mono.get_descent(T.BATTLE_HP_FONT_SIZE))/2
	for i in range(rows.size()):
		var row=rows[i];var center_y=T.BATTLE_HP_BASELINE+i*T.BATTLE_HP_STEP-baseline_offset
		row.center_y=center_y
		row.bar=Rect2(T.BATTLE_HP_BAR.position.x,center_y-T.BATTLE_HP_BAR.size.y/2,bar_end-T.BATTLE_HP_BAR.position.x,T.BATTLE_HP_BAR.size.y)
		row.emblem=Rect2(row.bar.position.x-T.ASSEMBLY_HP_GAP-T.ASSEMBLY_EMBLEM_RADIUS*2,center_y-T.ASSEMBLY_EMBLEM_RADIUS,T.ASSEMBLY_EMBLEM_RADIUS*2,T.ASSEMBLY_EMBLEM_RADIUS*2)
		row.text_origin=Vector2(T.BATTLE_HP_RIGHT-row.text_width,center_y+baseline_offset)
		row.text_rect=Rect2(row.text_origin.x,center_y-mono.get_height(T.BATTLE_HP_FONT_SIZE)/2,row.text_width,mono.get_height(T.BATTLE_HP_FONT_SIZE))
	return rows

func _draw_left() -> void:
	_text("PHASE",Vector2(T.BATTLE_LEFT_ORIGIN.x,T.BATTLE_TITLE_BASELINE),47,WHITE)
	for row in _assembly_rows():
		var profile=_assembly_profile(row.camp)
		_assembly_emblem(self,row.emblem.get_center(),T.ASSEMBLY_EMBLEM_RADIUS,profile,row.camp)
		_bar(row.bar,row.hp/maxf(1,row.maximum),A.color(profile))
		_text(row.text,row.text_origin,T.BATTLE_HP_FONT_SIZE,WHITE,mono)
	_draw_timeline()

func _timeline_view() -> Dictionary:
	return TL.layout(_display_units(),battle.actor,TL.rows(battle),battle.mode=="RESULT" and not movement.active)

func _display_units() -> Array:
	if not movement.active:return battle.units
	var units=battle.units.duplicate(true)
	units[movement.actor]=movement.unit()
	return units

func _decision_battle():
	return planning.projected if planning.active() else battle

func _draw_timeline() -> void:
	var view=_timeline_view()
	var turn_text=_turn_label(battle.turn)
	_text(turn_text,T.TIMELINE_TURN_CENTER-Vector2(mono.get_string_size(turn_text,HORIZONTAL_ALIGNMENT_LEFT,-1,T.TIMELINE_TURN_FONT).x/2,0),T.TIMELINE_TURN_FONT,MUTED,mono)
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
	var factor_width=mono.get_string_size("I:000% R:000%",HORIZONTAL_ALIGNMENT_LEFT,-1,T.TIMELINE_FACTOR_FONT).x
	var factor_step=mono.get_string_size("I:000% ",HORIZONTAL_ALIGNMENT_LEFT,-1,T.TIMELINE_FACTOR_FONT).x+T.TIMELINE_FACTOR_EXTRA_GAP
	for card in view.cards:
		var active=card.index==selected or card.index==timeline_hover
		var color=CYAN if active else MUTED
		_ring(self,card.center,T.TIMELINE_RADIUS,card.unit,card.index==battle.actor)
		_center(_hp(card.unit.hp)+"/"+_hp(card.unit.max_hp),card.center+Vector2(0,38),T.TIMELINE_HP_FONT,color if active else WHITE,mono)
		var factor_origin=card.center+Vector2(-factor_width/2,56)
		_text("I:"+_factor_field(M.sync(card.unit,1).factor*100)+"%",factor_origin,T.TIMELINE_FACTOR_FONT,status_colors[1],mono)
		_text("R:"+_factor_field(M.sync(card.unit,2).factor*100)+"%",factor_origin+Vector2(factor_step,0),T.TIMELINE_FACTOR_FONT,status_colors[2],mono)
	for event in view.events:
		var active=_timeline_matches(event,inspected) or (inspected.is_empty() and event.index==selected and not event.repeated)
		_timeline_node(event,CYAN if active or event.rank==1 else WHITE,pixel_scale)

func _factor_field(value: float) -> String:
	# 表示幅を超える値を偽の999%へ丸めず、不正な表示入力を明示する。
	return "%3d" % roundi(value) if is_finite(value) and value>=0 and value<=999 else "---"

func _turn_label(value: int) -> String:
	return "TURN %02d" % value if value>0 else "TURN --"

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
	var decision=_decision_battle()
	var fields=_field_view()
	var effect_chips=[]
	var target_cells=[]
	var effect=C.SKILLS.get(decision.selected_skill,{}).get("effect","")
	if decision.mode=="TARGET" and not movement.active:
		for offset in C.target_offsets(decision.selected_skill):
			target_cells.append(decision.units[decision.actor].pos+offset)
	for y in range(10):
		for x in range(10):
			var cell=Vector2i(x,y)
			var rect=_cell_rect(cell)
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
	# セルをまたぐ雲を次の行の背景で隠さず、全リングとパネル記号の下へ置く。
	for emitter in fields.emitters:
		_field_cloud(emitter.unit,emitter.preview,emitter.phase)
	_draw_convergence()
	for y in range(10):
		for x in range(10):
			var cell=Vector2i(x,y)
			var pos=_board_point(cell)
			var rect=_cell_rect(cell)
			var panel=battle.panels.get(cell,"NORMAL")
			if panel!="NORMAL":
				var pc=MAGENTA if panel=="COUNTERCLOCKWISE" else (status_colors[3] if panel=="RESET" else CYAN)
				_draw_panel_icon(panel,Rect2(pos+T.PANEL_ICON_OFFSET,Vector2.ONE*T.PANEL_ICON_SIZE),pc)
			if cell==battle.stage.goal:
				draw_rect(rect.grow(-4),Color(MAGENTA,0.6),false,1)
				_text("GOAL",pos+Vector2(6,62)*BOARD_SCALE,11,MAGENTA,mono)
			if cell==battle.stage.enemy_goal:
				draw_rect(rect.grow(-4),status_colors[1],false,2)
				_text("LOSS",pos+Vector2(6,62)*BOARD_SCALE,11,status_colors[1],mono)
			if target_cells.has(cell) and effect!="GUARD":
				var tc=_action_color(effect)
				draw_rect(rect,Color(tc,0.12))
				_draw_cell_focus(rect,Color(tc,0.7),true,1.5)
			var i=battle.at(cell)
			if i>=0 and not (movement.active and i==movement.actor):
				var u: Dictionary=battle.units[i]
				if effect=="GUARD" and decision.mode=="TARGET" and decision.valid_target(decision.actor,i,decision.selected_skill):
					u=u.duplicate(true)
					u.guard_active=true
				var center=pos+T.UNIT_BOARD_CENTER*BOARD_SCALE
				_ring(self,center,T.UNIT_BOARD_RADIUS*BOARD_SCALE,u,i==battle.actor)
				_ownership_marker(center,u)
				if i==selected or i==timeline_hover:
					_draw_cell_focus(rect,MAGENTA)
				if decision.mode=="TARGET" and not movement.active and decision.valid_target(decision.actor,i,decision.selected_skill):
					var tc=_action_color(effect)
					_draw_cell_focus(rect,tc,effect!="GUARD")
					var text=effect
					if effect in ["DAMAGE","HEAL"]:
						var amount=M.effect(decision.units[decision.actor],u,effect)
						if effect=="HEAL":
							amount=mini(amount,ceili(u.max_hp-u.hp))
						text=_effect_text(amount,effect)
					if effect!="GUARD":
						effect_chips.append({"cell":cell,"text":text,"color":tc,"font_size":16 if effect in ["DAMAGE","HEAL"] else 14})
				if cpu_turn.active and (cpu_turn.phase=="TARGET" or movement.active) and cpu_turn.command.target==i:
					_draw_cell_focus(rect,WHITE)
	if movement.active:
		var center=BOARD+(movement.position()+Vector2.ONE*0.5)*CELL
		_ring(self,center,T.UNIT_BOARD_RADIUS*BOARD_SCALE,movement.unit(),true)
		_ownership_marker(center,movement.unit())
	elif battle.mode=="MOVE":
		for segment in _route_segments():
			draw_line(segment[0],segment[1],CYAN,T.ROUTE_LINE_WIDTH*BOARD_SCALE,true)
		for i in range(battle.path.size()):
			var center=_board_point(battle.path[i],Vector2(35,35))
			draw_circle(center,T.ROUTE_NODE_RADIUS*BOARD_SCALE,WHITE)
			_center(str(i+1),center+Vector2(0,6)*BOARD_SCALE,roundi(17*BOARD_SCALE),BG,mono)
		if not battle.path.is_empty():
			_draw_cell_focus(_cell_rect(battle.path.back()),CYAN)
	var turn_cell=_turn_focus_cell()
	if turn_cell!=Vector2i(-1,-1):
		_draw_cell_focus(_cell_rect(turn_cell),CYAN)
	var forecast=_utility_preview()
	if not forecast.is_empty():
		for index in forecast.moved:
			_draw_cell_focus(_cell_rect(forecast.units[index].pos),WHITE)
	# 全セルの描画後に重ね、次の行の背景で数字を隠さない。
	for chip in effect_chips:
		var rect=_effect_chip_rect(chip.cell)
		draw_rect(rect,BG)
		draw_rect(rect,chip.color,false,1)
		_center(chip.text,rect.position+Vector2(rect.size.x/2,16*BOARD_SCALE),roundi(chip.font_size*BOARD_SCALE),chip.color,mono)

func _turn_focus_cell() -> Vector2i:
	if movement.active or build_open or not battle.result.is_empty() or battle.actor<0 or battle.units[battle.actor].hp<=0 or selected>=0 or (battle.mode=="MOVE" and not battle.path.is_empty()):
		return Vector2i(-1,-1)
	return battle.units[battle.actor].pos

func _follow_turn() -> void:
	if build_open:
		followed_turn=[]
		return
	var current=[battle.turn,battle.actor]
	if current==followed_turn:
		return
	followed_turn=current
	selected=-1
	timeline_hover=-1
	timeline_hover_event={}
	timeline_selected_event={}
	hover_cell=Vector2i(-1,-1)
	queue_redraw()

func _cell_rect(cell: Vector2i) -> Rect2:
	var inset=T.CELL_BORDER_INSET*BOARD_SCALE
	return Rect2(_board_point(cell)+Vector2.ONE*inset,Vector2.ONE*(CELL-2*inset))

func _draw_cell_focus(rect: Rect2,color: Color,full_outline: bool=false,line_width: float=2.0) -> void:
	if full_outline:
		draw_rect(rect,color,false,line_width)
	else:
		_brackets(rect,color)

func _draw_panel_icon(kind: String, rect: Rect2, color: Color) -> void:
	draw_texture_rect(ICONS[PANEL_VIEWS[kind].icon],rect,false,color)

func _field_cloud(source: Dictionary, preview: bool, phase: float) -> void:
	var opacity=movement.cloud_alpha(source)
	if opacity<=0:return
	var center=BOARD+(movement.position()+Vector2.ONE*0.5)*CELL if movement.active and source.id==movement.source.id and source.camp==movement.source.camp else _cell_rect(source.pos).get_center()
	V.field_cloud(self,center,CELL,clock,phase,Rect2(BOARD,Vector2.ONE*CELL*10),preview,CYAN,opacity)

func _field_view() -> Dictionary:
	var current=F.coverage(_display_units())
	var world=planning.projected.units if planning.active() else _display_units()
	var forecast=_utility_preview()
	if not forecast.is_empty():world=forecast.units
	elif not planning.active() and battle.mode=="MOVE" and not battle.path.is_empty():
		world=battle.units.duplicate(true)
		world[battle.actor]=battle.preview()
	var cells=F.coverage(world)
	var preview={}
	for cell in cells:
		if cells[cell]!=current.get(cell,{}):preview[cell]=true
	var emitters=[]
	for i in range(world.size()):
		var u: Dictionary=world[i]
		if u.hp>0 and not F.types(u).is_empty():
			emitters.append({"unit":u,"preview":not movement.active and u.pos!=battle.units[i].pos,"phase":i*1.618})
	return {"world":world,"cells":cells,"preview":preview,"emitters":emitters}

## セルの説明を返す。cellは盤面座標。戻り値はCOREパネルと現在または移動後の周囲回転の説明、対象がなければ空文字。戦闘を変更しない。
func panel_description(cell: Vector2i) -> String:
	if not Rect2i(0,0,10,10).has_point(cell):return ""
	var kind: String=battle.panels.get(cell,"NORMAL")
	var text=PANEL_VIEWS[kind].text if PANEL_VIEWS.has(kind) else ""
	var view=_field_view()
	if view.cells.has(cell):
		var field: Dictionary=view.cells[cell]
		var lines=[("AFTER MOVE / " if view.preview.has(cell) else "")+"EQUIPMENT x%.1f ON ENTRY" % field.factor]
		for name in ["SLOW","FAST"]:
			var count=field.sources.filter(func(source):return source.kind==name).size()
			if count>0:lines.append(name+" FIELD"+(" x%d" % count if count>1 else ""))
		if field.kinds.has("SLOW") and field.kinds.has("FAST"):lines.append("SLOW + FAST cancel.")
		text+=("\n" if not text.is_empty() else "")+"\n".join(lines)
	return _explain(text)

func _update_panel_hint() -> void:
	if not is_instance_valid(panel_hint):return
	var hint=panel_description(hover_cell) if not movement.active and not build_open and window_focused and not is_instance_valid(overlay) and not is_instance_valid(auxiliary) else ""
	panel_hint.visible=not hint.is_empty()
	if hint.is_empty():return
	var lines=hint.split("\n",false)
	var detail=panel_hint.get_child(1).get_child(0)
	var body=" | ".join(Array(lines).slice(1))
	if panel_hint.get_child(0).text!=lines[0] or detail.text!=body:
		panel_hint.get_child(1).scroll_vertical=0
	panel_hint.get_child(0).language=copy_language.locale()
	detail.language=copy_language.locale()
	panel_hint.get_child(0).text=lines[0]
	detail.text=body

func _route_segments() -> Array:
	var segments=[]
	var pixel_scale=maxf(0.001,get_viewport_transform().get_scale().x*get_global_transform().get_scale().x)
	var unit_clear=V.route_unit_clearance(T.UNIT_BOARD_RADIUS*BOARD_SCALE,T.ROUTE_LINE_WIDTH*BOARD_SCALE,pixel_scale)
	if movement.active:
		for line in movement.segments(unit_clear/CELL):
			segments.append([BOARD+(line[0]+Vector2.ONE*0.5)*CELL,BOARD+(line[1]+Vector2.ONE*0.5)*CELL])
		return segments
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

func _action_color(kind: String) -> Color:
	return status_colors[1] if kind=="DAMAGE" else (status_colors[2] if kind=="HEAL" else CYAN)

func _utility_preview() -> Dictionary:
	var decision=_decision_battle()
	if movement.active or build_open or decision.mode!="TARGET" or not decision.result.is_empty():
		return {}
	var target=planning.target if planning.active() and planning.phase=="READY" else decision.at(hover_cell)
	if cpu_turn.active and cpu_turn.phase=="TARGET":
		target=cpu_turn.command.target
	return decision.action_preview(target) if target>=0 else {}

func _draw_info() -> void:
	var index=movement.actor if movement.active else (selected if selected>=0 else battle.actor)
	var forecast=_utility_preview()
	if not forecast.is_empty():
		index=forecast.target
		_text("%sPREVIEW" % ("" if forecast.kind=="GUARD" else forecast.kind+" "),T.BATTLE_INFO_CLASS-Vector2(0,24),13,MUTED,mono)
	var u: Dictionary=forecast.units[index] if not forecast.is_empty() else (planning.projected.units[index] if planning.active() and selected<0 else _display_units()[index])
	var class_origin=T.BATTLE_INFO_CLASS+Vector2(T.ASSEMBLY_EMBLEM_RADIUS*2+T.ASSEMBLY_INFO_GAP,0)
	var class_center=Vector2(T.BATTLE_INFO_CLASS.x+T.ASSEMBLY_EMBLEM_RADIUS,class_origin.y-(mono.get_ascent(17)-mono.get_descent(17))/2)
	_assembly_emblem(self,class_center,T.ASSEMBLY_EMBLEM_RADIUS,_assembly_profile(u.camp),u.camp)
	accessibility_description=_explain("Inspected unit: "+V.unit_name(u))
	var camp_color=CYAN if u.camp=="PLAYER" else status_colors[1]
	var core_code=M.layout_code(u.class_name)
	var class_text="CLASS: "+core_code
	_text(class_text,class_origin,17,camp_color,mono)
	if core_code=="VIRSL":
		var label_width=mono.get_string_size(class_text,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x
		_text("STANDARD",class_origin+Vector2(label_width+T.LAYOUT_STANDARD_GAP,0),T.LAYOUT_STANDARD_FONT,MUTED,mono)
	_ring(self,T.BATTLE_INFO_RING,81,u,index==battle.actor)
	var icon_rect=T.BATTLE_EQUIPMENT_ICON
	for part in ["ARMS","GEAR"]:
		var mutation: String=u[part.to_lower()+"_mutation"]
		_equipment_icon(part.to_lower(),icon_rect,MUTED)
		_text(C.serial(part,u[part.to_lower()],mutation),Vector2(icon_rect.end.x+T.BATTLE_EQUIPMENT_NAME_GAP,icon_rect.position.y+T.BATTLE_EQUIPMENT_BASELINE),15,WHITE,mono)
		icon_rect.position.y+=T.BATTLE_EQUIPMENT_STEP
	_text("MOVE %d" % battle.movement(u),T.BATTLE_INFO_MOVE,16,CYAN,mono)
	_text(_explain("Move up to %d cells per turn." % battle.movement(u)),T.BATTLE_INFO_MOVE+T.BATTLE_INFO_DESCRIPTION_OFFSET,T.BATTLE_INFO_DESCRIPTION_FONT,MUTED)
	var position_px=T.BATTLE_INFO_SKILLS
	for id in u.skills:
		_text(C.SKILLS[id].label,position_px,15,WHITE,mono)
		_text(_explain(C.SKILLS[id].description),position_px+T.BATTLE_INFO_DESCRIPTION_OFFSET,T.BATTLE_INFO_DESCRIPTION_FONT,MUTED)
		position_px.y+=T.BATTLE_SKILL_STEP
	if cpu_enabled and battle.result.is_empty():
		var phase=("AIMING" if movement.landed else "MOVING") if movement.active and movement.cpu else (cpu_turn.phase if cpu_turn.active else "READY")
		var stopped=cpu_paused or not window_focused or is_instance_valid(auxiliary)
		_text(_fit_text("CPU / "+("PAUSED" if stopped else phase),400,14,mono),T.CPU_CONTROL_ORIGIN+Vector2(0,14),14,MUTED,mono)
		if cpu_turn.active and cpu_turn.phase in ["ACTION","TARGET"]:
			var action="WAIT" if cpu_turn.command.skill.is_empty() else C.SKILLS[cpu_turn.command.skill].label
			_text(_fit_text(action,350,13,mono),T.CPU_CONTROL_ORIGIN+Vector2(0,-12),13,WHITE,mono)
			if not cpu_turn.command.skill.is_empty():V.unit_emblem(self,T.CPU_CONTROL_ORIGIN+Vector2(380,-17),11,battle.units[cpu_turn.command.target],_assembly_profile(battle.units[cpu_turn.command.target].camp))

func _equipment_icon(key: String, rect: Rect2, tint: Color) -> void:
	draw_texture_rect(ICONS[key],rect,false,tint)

func _draw_preview() -> void:
	_text("PREVIEW",T.PREVIEW_HEADING_CENTER-Vector2(mono.get_string_size("PREVIEW",HORIZONTAL_ALIGNMENT_LEFT,-1,T.TIMELINE_TURN_FONT).x/2,0),T.TIMELINE_TURN_FONT,MUTED,mono)
	var forecast=_utility_preview()
	var u=movement.unit() if movement.active else (_decision_battle().preview() if forecast.is_empty() else forecast.units[battle.actor])
	var signature=[u.core,u.gear,u.arms,u.class_name,u.gear_mutation,u.arms_mutation,u.get("core_angle",0.0),u.gear_angle,u.arms_angle,status_colors]
	if signature!=preview_signature:
		preview_signature=signature.duplicate(true)
		preview_contours=V.phase_contours(u,status_colors)
		preview_generation+=1
	preview_points=V.motion_points(preview_contours,clock)
	V.phase_orbit(self,T.PREVIEW_CENTER,preview_contours,preview_points)
	_ring(self,T.PREVIEW_CENTER,T.PREVIEW_RADIUS,u)
	if M.singularity(u):
		_text("×5",Vector2(T.PREVIEW_PANEL.position.x+286,T.PREVIEW_SYNC_BASELINE),15,MAGENTA,mono)

func _input(event: InputEvent) -> void:
	_follow_turn()
	if event is InputEventMouseMotion:
		if movement.active or build_open or not window_focused or is_instance_valid(auxiliary) or is_instance_valid(overlay):
			_timeline_mouse_exited()
		else:
			timeline_hover_event=TL.hit(_timeline_view(),event.position)
			timeline_hover=timeline_hover_event.get("index",-1)

func _timeline_mouse_exited() -> void:
	timeline_hover=-1
	timeline_hover_event={}

func _unhandled_input(event: InputEvent) -> void:
	_follow_turn()
	if not window_focused:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and panel_hint.visible:
		var detail_scroll=panel_hint.get_child(1)
		detail_scroll.scroll_vertical+=-24 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 24
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_F1:
			_help()
		elif event.keycode==KEY_ESCAPE:
			if is_instance_valid(auxiliary):
				_close_aux()
			elif movement.active or _cpu_locked():
				return
			elif planning.active():
				_plan_back()
			elif battle.mode=="CHOICE" and not build_open:
				_reselect_path()
			elif battle.mode=="TARGET":
				battle.back()
				_action_dialog()
			elif battle.mode=="MOVE" and not build_open:
				battle.path=[]
		return
	if movement.active or build_open or is_instance_valid(auxiliary) or is_instance_valid(overlay):
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
	_follow_turn()
	if movement.active:return
	if _cpu_locked():
		var occupant=battle.at(cell)
		if occupant>=0:
			selected=occupant
		queue_redraw()
		return
	timeline_selected_event={}
	timeline_hover=-1
	timeline_hover_event={}
	var index=battle.at(cell)
	if planning.active():
		if planning.phase=="TARGET" and planning.select(index):_confirm_dialog()
		elif planning.phase=="TARGET":_notify("Choose a highlighted target. BACK keeps your planned route.")
		queue_redraw()
		return
	if battle.mode=="TARGET":
		if index>=0 and battle.act(index):
			_feedback()
			_after_action()
		else:
			_notify("Choose a highlighted target. BACK keeps your movement.")
	elif battle.mode=="MOVE":
		if index>=0 and cell!=battle.units[battle.actor].pos:
			selected=index
		elif double_click and not battle.path.is_empty() and cell==battle.path.back():
			if planning.begin(battle):
				selected=-1
				if planning.phase=="READY":_confirm_dialog()
				else:_action_dialog()
		elif battle.path_click(cell):
			selected=-1
		else:
			_notify("Add an empty adjacent cell. No revisits. Maximum %d steps." % battle.movement(battle.units[battle.actor]))
	queue_redraw()

func _begin_movement(before: Dictionary, route: Array, via_cpu: bool) -> void:
	selected=-1
	timeline_hover=-1
	timeline_hover_event={}
	timeline_selected_event={}
	hover_cell=Vector2i(-1,-1)
	_clear_overlay()
	var attack=battle.result.is_empty() and C.SKILLS.get(playback_command.get("skill",""),{}).get("effect","")=="DAMAGE"
	if movement.begin(battle,before,route,via_cpu,reduced_motion,attack):
		_hud()
		_movement_tick(0)
	else:
		_movement_arrived(via_cpu)
	queue_redraw()

func _movement_tick(delta: float) -> void:
	var via_cpu=movement.cpu
	var blocked=not window_focused or is_instance_valid(auxiliary) or (via_cpu and cpu_paused)
	if not movement.active:
		movement.advance_cloud(delta,blocked,T.CPU_FAST_SPEED if via_cpu and cpu_fast else 1.0)
		return
	var event=movement.advance(battle,delta,blocked,T.CPU_FAST_SPEED if via_cpu and cpu_fast else 1.0)
	if event=="arrived":_movement_arrived(via_cpu)
	elif event=="cancel":
		playback_command={}
		if via_cpu:cpu_turn.reset()
		_hud()
	queue_redraw()

func _movement_arrived(via_cpu: bool) -> void:
	var command=playback_command
	playback_command={}
	if not battle.result.is_empty():
		cpu_turn.reset()
		_result()
		_hud()
	elif not command.is_empty():
		var ok=battle.wait_turn() if command.skill.is_empty() else (battle.choose_skill(command.skill) and battle.act(command.target))
		if via_cpu:
			cpu_turn.phase="RESULT";cpu_turn.elapsed=0
			cpu_memory.append({"actor":command.actor,"pos":battle.units[command.actor].pos,"skill":command.skill,"target":command.target})
			cpu_memory=cpu_memory.slice(-T.CPU_MEMORY_LIMIT)
		if ok:
			if not command.skill.is_empty():_feedback()
			_after_action()
		else:
			cpu_paused=via_cpu
			_notify("Action stopped / State changed. RESTART returns to BUILD.")
			_hud()
	else:_hud()

func _confirm_plan() -> void:
	if movement.active or _cpu_locked() or not planning.active():return
	var before=battle.units[battle.actor].duplicate(true)
	var actor=battle.actor
	var command=planning.commit(battle)
	if command.is_empty():return
	command.actor=actor
	playback_command=command
	_begin_movement(before,command.path,false)

func _confirm_dialog() -> void:
	_clear_overlay();_hud()
	var panel=_modal(Rect2(700,380,420,220),false,true)
	_unit_action_heading(panel,"READY",battle.units[battle.actor])
	var decision=planning.projected
	var text="MOVE / FINISH" if not decision.result.is_empty() else ("WAIT" if decision.selected_skill.is_empty() else C.SKILLS[decision.selected_skill].label)
	if planning.target>=0 and planning.target!=battle.actor:_unit_badge(panel,Vector2(376,76),13,battle.units[planning.target])
	var summary=_label(panel,_fit_text(text,325,16),Rect2(25,60,325,32),16,MUTED)
	summary.tooltip_text=text
	_button(panel,"CONFIRM",Rect2(25,105,370,42),_confirm_plan)
	_button(panel,"BACK",Rect2(25,158,370,42),_plan_back)

func _plan_back() -> void:
	if movement.active or _cpu_locked() or not planning.active():return
	planning.back()
	_clear_overlay()
	if planning.active() and planning.phase=="CHOICE":_action_dialog()
	else:_hud()
	queue_redraw()

func _after_action() -> void:
	_follow_turn()
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
	if e.kind=="GUARD":
		return
	if e.kind in ["SWAP","PUSH"]:
		toasts.append({"cell":u.pos,"text":e.kind,"color":CYAN,"age":0.0})
		return
	if e.kind in ["DAMAGE","HEAL"] and not reduced_motion:
		var gain_to=clampf(u.hp/maxf(1.0,u.max_hp),0,1)
		var gain_from=clampf((u.hp-e.actual)/maxf(1.0,u.max_hp),0,1) if e.kind=="HEAL" else gain_to
		convergences.append({"cell":u.pos,"age":0.0,"owner":battle,"kind":e.kind,"target":e.target,"gain_from":gain_from,"gain_to":gain_to})
	var shown=_effect_text(e.amount if e.kind=="DAMAGE" else e.actual,e.kind)
	toasts.append({"cell":u.pos,"text":shown,"color":status_colors[1] if e.kind=="DAMAGE" else status_colors[2],"age":0.0})
	if e.dead:
		toasts.append({"cell":u.pos,"text":"DEFEATED","color":status_colors[1],"age":-0.65})

func _advance_convergence(delta: float) -> void:
	if build_open or reduced_motion or not window_focused or is_instance_valid(auxiliary):
		convergences=[];return
	if not is_finite(delta) or delta<0:return
	for pulse in convergences:pulse.age+=delta
	convergences=convergences.filter(func(p):return p.owner==battle and p.age<T.CONVERGENCE_SECONDS)

func _draw_convergence() -> void:
	if convergences.is_empty():return
	var scale_px=maxf(0.001,get_viewport_transform().get_scale().x*get_global_transform().get_scale().x)
	var width=maxf(T.CONVERGENCE_LINE_WIDTH,T.CONVERGENCE_MIN_PIXEL_WIDTH/scale_px)
	var radius=V.route_unit_clearance(T.UNIT_BOARD_RADIUS*BOARD_SCALE,width,scale_px)
	var bounds=Rect2(BOARD,Vector2.ONE*CELL*10).grow(-width/2-1/scale_px)
	var masks=[]
	for i in range(battle.units.size()):
		if battle.units[i].hp<=0:continue
		var point=BOARD+(movement.position()+Vector2.ONE*0.5)*CELL if movement.active and movement.actor==i else _cell_rect(battle.units[i].pos).get_center()
		masks.append({"center":point,"radius":radius,"index":i})
	for pulse in convergences:
		var center=_cell_rect(pulse.cell).get_center()
		var healing=pulse.kind=="HEAL"
		# 対象の内側だけを見せ、文字とHP、装備リングは後の既存描画を前面に保つ。
		var protected=masks.filter(func(m):return not healing or m.index!=pulse.target or not m.center.is_equal_approx(center))
		if healing and protected.size()<masks.size():
			protected.append({"center":center,"radius":T.UNIT_BOARD_RADIUS*BOARD_SCALE*T.UNIT_IDENTICON_RADIUS+width/2+0.5/scale_px})
		var color=_convergence_color(pulse.kind)
		for ring in V.convergence_rings(pulse.age,radius,healing):
			for line in V.convergence_segments(center,ring.radius,bounds,protected):
				draw_polyline(line,Color(color,ring.alpha),width,true)

		var response=V.ring_response(pulse.age,radius,T.UNIT_BOARD_RADIUS*BOARD_SCALE,pulse.kind,pulse.gain_from,pulse.gain_to)
		if not response.is_empty():
			var response_color=color.lerp(Color.WHITE,T.RING_RESPONSE_HEAL_WHITE)
			var response_width=maxf(response.width,T.CONVERGENCE_MIN_PIXEL_WIDTH/scale_px)
			for line in V.convergence_segments(center,response.radius,bounds,protected,response.start_angle,response.arc_angle):
				draw_polyline(line,Color(response_color,response.alpha),response_width,true)

func _convergence_color(kind: String) -> Color:
	var color: Color=ring_colors[2 if kind=="HEAL" else 1]
	if P.PRESETS.values().has(palette_colors):
		color=Color.from_hsv(color.h,color.s,maxf(color.v,T.CONVERGENCE_COLOR_VALUE),color.a)
	return color

func _hud() -> void:
	if is_instance_valid(hud):
		hud.queue_free()
	hud=Control.new()
	hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hud.visible=not build_open
	add_child(hud)
	var rows=[["HELP",1218,_help],["SETTINGS",1346,_settings],["RESTART",1492,_restart],["QUIT",1640,_quit]]
	for i in range(rows.size()):
		var row=rows[i]
		var rect=Rect2(row[1],1025,118,40) if build_open else Rect2(T.BATTLE_MENU_ORIGIN+Vector2(i%2,floori(i/2.0))*(T.BATTLE_MENU_SIZE+T.BATTLE_MENU_GAP),T.BATTLE_MENU_SIZE)
		var button=_button(hud,row[0],rect,row[2])
		# 盤面のシステムメニューは今回の変更対象外であり、既存の面と囲いを保つ。
		for state in ["normal","hover","pressed","focus","disabled"]:
			var style=StyleBoxFlat.new()
			style.bg_color=PANEL if state in ["normal","disabled"] else P.INTERACTIVE
			style.border_color=CYAN if state in ["pressed","focus"] else EDGE
			style.set_border_width_all(2 if state=="focus" else 1)
			style.content_margin_left=12
			style.content_margin_right=12
			style.content_margin_top=4
			style.content_margin_bottom=4
			button.add_theme_stylebox_override(state,style)
	if cpu_enabled and not build_open and battle.result.is_empty():
		_button(hud,"SPEED 4x" if cpu_fast else "SPEED 1x",Rect2(T.CPU_CONTROL_ORIGIN+Vector2(0,38),Vector2(190,40)),func():cpu_fast=not cpu_fast;_hud(),"fast_forward")
		_button(hud,"RESUME" if cpu_paused else "PAUSE",Rect2(T.CPU_CONTROL_ORIGIN+Vector2(210,38),Vector2(190,40)),func():cpu_paused=not cpu_paused;_hud(),"play" if cpu_paused else "wait")
	if movement.active or _cpu_locked():
		return
	if planning.active():
		if planning.phase=="TARGET":_button(hud,"BACK",T.BATTLE_CONTEXT_BUTTON,_plan_back)
		return
	if battle.mode=="TARGET":
		_button(hud,"BACK",T.BATTLE_CONTEXT_BUTTON,func():battle.back();_action_dialog())
	elif battle.mode=="MOVE" and battle.trapped():
		_button(hud,"WAIT",T.BATTLE_CONTEXT_BUTTON,_wait_action)

func _action_dialog() -> void:
	if movement.active:return
	_clear_overlay()
	_hud()
	var active=[]
	var decision=_decision_battle()
	for skill in decision.units[decision.actor].skills:
		if C.SKILLS[skill].type=="ACTIVE":
			active.append(skill)
	var height=185+active.size()*63
	var panel=_modal(Rect2(700,330,420,height),false,true)
	_unit_action_heading(panel,"ACTION",battle.units[battle.actor])
	_button(panel,"WAIT",Rect2(25,63,370,48),_wait_action)
	for i in range(active.size()):
		var skill: String=active[i]
		var button=_button(panel,C.SKILLS[skill].label,Rect2(25,126+i*63,370,48),func():_choose_battle_skill(skill))
		var available=false
		for target in range(decision.units.size()):
			if decision.valid_target(decision.actor,target,skill):
				available=true
		button.disabled=not available
		_set_prose(button,"No valid target in this pattern." if not available else C.SKILLS[skill].description,"tooltip_text")
	_button(panel,"BACK",Rect2(25,126+active.size()*63,370,48),_reselect_path)

func _choose_battle_skill(skill: String) -> void:
	if movement.active or _cpu_locked():return
	if planning.active():
		if not planning.choose(skill):return
		_clear_overlay()
		if planning.phase=="READY":_confirm_dialog()
		else:_hud()
		queue_redraw()
		return
	if battle.choose_skill(skill):
		_clear_overlay()
		_hud()

func _wait_action() -> void:
	if movement.active or _cpu_locked():return
	if planning.active():
		if planning.wait():_confirm_dialog()
		return
	if battle.mode=="MOVE" and battle.trapped():
		if planning.begin(battle) and planning.wait():_confirm_dialog()
		return
	if battle.wait_turn():_after_action()

func _reselect_path() -> void:
	if movement.active or _cpu_locked():return
	if planning.active():planning.reset()
	elif not battle.reselect_path():
		return
	selected=-1
	timeline_hover=-1
	timeline_hover_event={}
	timeline_selected_event={}
	_clear_overlay()
	_hud()
	queue_redraw()

func _build() -> void:
	convergences=[]
	planning.reset();playback_command={}
	movement.reset()
	build_open=true
	followed_turn=[]
	if is_instance_valid(hud):
		hud.visible=false
	selected=-1
	battle.start(collection.stage_index,collection.builds,0,collection.unit_names)
	_clear_overlay()
	var panel=_modal(T.BUILD_RECT,false)
	var left=T.BUILD_COLUMNS[0]
	var middle=T.BUILD_COLUMNS[1]
	var right=T.BUILD_COLUMNS[2]
	_label(panel,"BUILD",Rect2(left,20,200,45),32,WHITE)
	for i in range(collection.builds.size()):
		_button(panel,"SLOT %d" % (i+1),Rect2(210+i*110,22,100,43),func():edit_unit=i;_build(),"",i==edit_unit)
	_toggle(panel,"ENEMY CPU",T.BUILD_CPU_TOGGLE_RECT,cpu_enabled,func(value):cpu_enabled=value;_build())
	if debug_session.available():
		_toggle(panel,"UNLOCK ALL",T.DEBUG_TOGGLE_RECT,collection.temporary,func(value):_toggle_debug(value))
	_label(panel,"SHARED ARCHIVE   %d ARMS / %d GEAR / %d MUTATIONS     %s" % [collection.items.ARMS.size(),collection.items.GEAR.size(),collection.mutations.size(),"PLAYER: HUMAN / ENEMY: CPU" if cpu_enabled else "BOTH SIDES: HUMAN"],Rect2(left,83,880,26),14,MUTED)
	_build_assembly_entry(panel)
	var b: Dictionary=collection.builds[edit_unit]
	_label(panel,"NAME",Rect2(left,132,62,40),14,MUTED)
	name_edit=LineEdit.new();name_edit.position=Vector2(left+70,132);name_edit.size=Vector2(330,40)
	name_edit.placeholder_text=I.PLAYER_NAMES[edit_unit];name_edit.text=collection.unit_names[edit_unit]
	name_edit.add_theme_font_size_override("font_size",20)
	_set_prose(name_edit,"Up to 32 characters. Blank uses the slot name. Enter / Tab confirms; Esc cancels this edit.","tooltip_text")
	panel.add_child(name_edit)
	name_hint=_label(panel,"",Rect2(left,178,400,20),12,MUTED)
	name_before_edit=collection.unit_names[edit_unit]
	name_edit.focus_entered.connect(func():name_before_edit=collection.unit_names[edit_unit])
	name_edit.text_changed.connect(_name_changed)
	name_edit.focus_exited.connect(_finish_name_edit)
	name_edit.text_submitted.connect(func(_value):_finish_name_edit();name_edit.release_focus())
	name_edit.gui_input.connect(_name_key)
	_update_name_hint()
	_label(panel,"CORE / TOTAL 100",Rect2(left,208,400,28),17,WHITE)
	var class_title=_label(panel,"CLASS",Rect2(left,248,96,28),14,MUTED)
	var class_field=_choice_button(panel,"class_name",b.class_name,Rect2(left+100,248,300,43))
	_align_layout_text(class_field,class_title)
	core_controls=[]
	equipment_views={}
	for k in range(5):
		var x=left+k*T.BUILD_STAT_STEP
		_label(panel,["VIT","INF","RES","SPD","LUK"][k],Rect2(x,312,70,25),15,status_colors[k])
		var spin=SpinBox.new()
		spin.position=Vector2(x,344)
		spin.size=Vector2(70,46)
		spin.add_theme_font_size_override("font_size",22)
		spin.get_line_edit().add_theme_constant_override("minimum_character_width",2)
		spin.min_value=1
		spin.max_value=96
		spin.step=1
		spin.value=b.core[k]
		panel.add_child(spin)
		core_controls.append(spin)
		spin.value_changed.connect(func(value):_core_change(k,int(value)))
	_prose_label(panel,"MIN 1 / AUTOMATIC REDISTRIBUTION",Rect2(left,408,400,27),14,MUTED)
	for r in range(2):
		var key="arms" if r==0 else "gear"
		var y=T.BUILD_EQUIPMENT_ROWS[r]
		_icon(panel,key,Rect2(Vector2(middle,y)+T.BUILD_EQUIPMENT_ICON.position,T.BUILD_EQUIPMENT_ICON.size),MUTED)
		_label(panel,key.to_upper(),Rect2(middle+32,y,T.BUILD_EQUIPMENT_WIDTH-32,28),17,WHITE)
		var view=Control.new()
		view.position=Vector2(middle,y+99)
		view.size=Vector2(T.BUILD_EQUIPMENT_WIDTH,62)
		view.mouse_filter=Control.MOUSE_FILTER_IGNORE
		view.set_meta("before",b[key].duplicate())
		panel.add_child(view)
		equipment_views[key]=view
		view.draw.connect(func():
			var values=_equipment_values(b[key],view.get_meta("before"))
			for status in range(5):
				var x=status*T.BUILD_EQUIPMENT_STAT_STEP
				view.draw_string(font,Vector2(x,16),["VIT","INF","RES","SPD","LUK"][status],HORIZONTAL_ALIGNMENT_LEFT,-1,T.BUILD_EQUIPMENT_LABEL_FONT,status_colors[status])
				view.draw_string(mono,Vector2(x,40),values[status],HORIZONTAL_ALIGNMENT_LEFT,-1,T.BUILD_EQUIPMENT_VALUE_FONT,WHITE)
				view.draw_line(Vector2(x,54),Vector2(x+minf(b[key][status],100)*0.6,54),status_colors[status],2))
		_choice_button(panel,key,C.serial(key.to_upper(),b[key]),Rect2(middle,y+39,T.BUILD_EQUIPMENT_WIDTH,44))
		var mutation_title=_label(panel,"MUTATION",Rect2(middle,y+176,100,24),14,MUTED)
		var mutation_field=_choice_button(panel,key+"_mutation",b[key+"_mutation"],Rect2(middle+116,y+176,T.BUILD_EQUIPMENT_WIDTH-116,40))
		_align_layout_text(mutation_field,mutation_title)
	_prose_wrapped_label(panel,"Choose equipment to compare rings and stat values.",Rect2(middle,656,T.BUILD_EQUIPMENT_WIDTH,42),13,MUTED)
	_label(panel,"SKILLS / 3 SLOTS",Rect2(right,136,342,30),15,MUTED)
	for i in range(3):
		var current: String=b.skills[i] if i<b.skills.size() else "NONE"
		_choice_button(panel,"skill",C.SKILLS[current].label if C.SKILLS.has(current) else "NONE",Rect2(right,176+i*53,342,43),i)
	_label(panel,"OPERATION",Rect2(right,390,342,26),15,MUTED)
	_choice_button(panel,"operation",C.stages()[collection.stage_index].name,Rect2(right,432,342,44))
	_objective_label(panel,C.stages()[collection.stage_index].brief,Rect2(right,496,342,52),17,WHITE)
	var stage_hint=C.stages()[collection.stage_index].hint
	if cpu_enabled and collection.stage_index==0:
		stage_hint="Compare routes. The CPU controls A, B and C."
	_objective_label(panel,stage_hint,Rect2(right,564,342,120),16,MUTED)
	build_preview=Control.new()
	build_preview.position=Vector2(left,456)
	build_preview.size=Vector2(400,220)
	build_preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_child(build_preview)
	var preview=build_preview
	preview.draw.connect(func():
		var u=C.unit("%02d" % (edit_unit+1),"PLAYER",Vector2i.ZERO,collection.builds[edit_unit],collection.unit_names[edit_unit])
		_ring(preview,Vector2(90,100),79,u,true)
		preview.draw_string(mono,Vector2(205,55),"HP %s" % _hp(u.max_hp),HORIZONTAL_ALIGNMENT_LEFT,-1,20,WHITE)
		preview.draw_string(mono,Vector2(205,92),"MOVE %d" % battle.movement(u),HORIZONTAL_ALIGNMENT_LEFT,-1,18,WHITE)
		preview.draw_string(mono,Vector2(205,140),"DELAY %.1f" % M.delay(u),HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED)
		preview.draw_string(mono,Vector2(205,173),"INF %.1f%%" % (M.sync(u,1).factor*100),HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED))
	for row in [["SAVE",36,108,_save],["LOAD",158,108,_load],["HELP",280,108,_help],["SETTINGS",402,150,_settings],["QUIT",566,108,_quit]]:
		var button=_button(panel,row[0],Rect2(row[1],730,row[2],44),row[3])
		button.disabled=collection.temporary and row[0] in ["SAVE","LOAD"]
	var start=_button(panel,"START",Rect2(934,730,342,48),_start_battle)
	start.alignment=HORIZONTAL_ALIGNMENT_CENTER
	start.icon_alignment=HORIZONTAL_ALIGNMENT_LEFT
	# 中央アイコンは文字と重なるため、通常の左アイコンのまま合計幅を中央へ収める。
	var content_width=start.get_theme_font("font").get_string_size(start.text,HORIZONTAL_ALIGNMENT_LEFT,-1,start.get_theme_font_size("font_size")).x+start.get_theme_constant("icon_max_width")+start.get_theme_constant("h_separation")
	var padding=maxf(0,(start.size.x-content_width)/2)
	for state in ["normal","hover","pressed","focus","disabled"]:
		var style=start.get_theme_stylebox(state).duplicate()
		style.content_margin_left=padding
		style.content_margin_right=padding
		start.add_theme_stylebox_override(state,style)
	_refresh_build()

func _assembly_profile(camp: String) -> Dictionary:
	return collection.assembly if camp=="PLAYER" else opponent_assembly

func _assembly_emblem(canvas: CanvasItem,center: Vector2,radius: float,profile: Dictionary,camp: String) -> void:
	V.assembly_emblem(canvas,center,radius,profile,camp)

func _build_assembly_entry(panel: Control) -> void:
	_label(panel,"ASSEMBLY",Rect2(934,83,92,26),13,MUTED)
	assembly_button=_button(panel,_fit_text(A.label(collection.assembly),192,17),T.ASSEMBLY_BUILD_ENTRY,_open_assembly)
	assembly_button.icon=null
	assembly_button.alignment=HORIZONTAL_ALIGNMENT_LEFT;assembly_button.add_theme_font_size_override("font_size",17)
	assembly_button.tooltip_text="Assembly / "+A.label(collection.assembly)+" / "+collection.assembly.color
	for state in ["normal","hover","pressed","focus","disabled"]:
		var style=assembly_button.get_theme_stylebox(state).duplicate();style.content_margin_left=42
		if state=="normal":style.border_width_bottom=T.UI_FIELD_LINE;style.border_color=EDGE
		assembly_button.add_theme_stylebox_override(state,style)
	var emblem=Control.new();emblem.position=Vector2(4,3);emblem.size=Vector2(30,30);emblem.mouse_filter=Control.MOUSE_FILTER_IGNORE;assembly_button.add_child(emblem)
	emblem.draw.connect(func():_assembly_emblem(emblem,Vector2(15,15),12,collection.assembly,"PLAYER"))

func _open_assembly() -> void:
	if not build_open:return
	_close_aux()
	var panel=_modal(T.ASSEMBLY_DIALOG_RECT,true)
	assembly_dialog=ASSEMBLY_DIALOG.new();panel.add_child(assembly_dialog);assembly_dialog.configure(self,collection)
	assembly_dialog.cancelled.connect(_close_aux)
	assembly_dialog.applied.connect(func():_close_aux();_build();_focus_assembly.call_deferred())

func _focus_assembly() -> void:
	if is_instance_valid(assembly_button):assembly_button.grab_focus()

func _name_changed(value: String) -> void:
	if not build_open:return
	collection.unit_names[edit_unit]=I.normalize(value)
	_update_name_hint()
	_refresh_build()

func _update_name_hint() -> void:
	if is_instance_valid(name_hint):_set_prose(name_hint,"32 characters / blank uses a default")

func _finish_name_edit() -> void:
	if not is_instance_valid(name_edit) or not build_open:return
	name_edit.text=collection.unit_names[edit_unit]

func _name_key(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		collection.unit_names[edit_unit]=name_before_edit
		name_edit.text=name_before_edit
		name_edit.release_focus();name_edit.accept_event()
		_refresh_build()

func _toggle_debug(enabled: bool) -> bool:
	if enabled:
		if not build_open:return false
		var sandbox=debug_session.begin(collection)
		if sandbox==null:return false
		debug_ui_state={"palette":palette_colors.duplicate(),"motion":reduced_motion,"language":copy_language.selection,"unit":edit_unit,"cpu":cpu_enabled,"fast":cpu_fast,"loot":loot_rng.state,"panels":panel_rng.state,"last_seed":last_panel_seed}
		collection=sandbox
		edit_unit=0
	else:
		if not debug_session.active():return false
		collection=debug_session.end()
		palette_colors=debug_ui_state.palette
		reduced_motion=debug_ui_state.motion
		copy_language.selection=debug_ui_state.language
		notice.text=_explain(message)
		edit_unit=debug_ui_state.unit
		cpu_enabled=debug_ui_state.cpu
		cpu_fast=debug_ui_state.fast
		loot_rng.state=debug_ui_state.loot
		panel_rng.state=debug_ui_state.panels
		last_panel_seed=debug_ui_state.last_seed
		debug_ui_state={}
		_set_theme()
	debug_notice.add_theme_color_override("font_color",CYAN)
	notice.add_theme_color_override("font_color",CYAN)
	debug_notice.visible=collection.temporary
	cpu_turn.reset()
	cpu_memory=[]
	cpu_paused=false
	_close_aux()
	_build()
	return true

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
	battle.start(collection.stage_index,collection.builds,0,collection.unit_names)
	queue_redraw()
	if is_instance_valid(build_preview):
		build_preview.queue_redraw()
	for view in equipment_views.values():
		if is_instance_valid(view):
			view.queue_redraw()

func _equipment_values(candidate: Array, _previous: Array) -> Array:
	return candidate.map(func(value):return str(int(value)))

func _equipment_comparison(candidate: Array, equipped: Array) -> String:
	return "CURRENT / "+BUILD_CHOICES._stats_text(equipped)+"\nCANDIDATE / "+BUILD_CHOICES._stats_text(candidate)

func _toggle(parent: Control,text: String,rect: Rect2,value: bool,callback: Callable) -> CheckButton:
	var button=CheckButton.new()
	button.text=text
	button.position=rect.position
	button.size=rect.size
	button.button_pressed=value
	button.add_theme_font_size_override("font_size",17)
	parent.add_child(button)
	button.alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var state_font=button.get_theme_font("font")
	var state_width=ceilf(maxf(state_font.get_string_size("ON",HORIZONTAL_ALIGNMENT_LEFT,-1,13).x,state_font.get_string_size("OFF",HORIZONTAL_ALIGNMENT_LEFT,-1,13).x))
	button.add_theme_constant_override("h_separation",ceili(state_width+2*T.BUILD_TOGGLE_CONTENT_GAP))
	var switch_left=rect.size.x-button.get_theme_stylebox("normal").content_margin_right-button.get_theme_icon("unchecked").get_width()
	button.toggled.connect(callback)
	var state=_label(button,"ON" if value else "OFF",Rect2(switch_left-T.BUILD_TOGGLE_CONTENT_GAP-state_width,8,state_width,28),13,CYAN if value else MUTED)
	# Labelの初期テーマで広がった幅を、適用後の文字幅へ戻す。
	state.size.x=state_width
	return button

func _choice_button(parent: Control,kind: String,text: String,rect: Rect2,slot: int=0) -> Button:
	var layout=kind=="class_name" or kind.ends_with("_mutation")
	var displayed=M.layout_code(text) if layout else text
	var button=_button(parent,displayed,rect,func():_open_build_choice(kind,slot))
	button.set_meta("build_choice",kind)
	button.set_meta("skill_slot",slot)
	button.alignment=HORIZONTAL_ALIGNMENT_LEFT
	_set_prose(button,"Choose "+kind.replace("_"," ").to_upper(),"tooltip_text")
	var style=StyleBoxFlat.new()
	style.bg_color=Color.TRANSPARENT
	style.border_color=EDGE
	style.border_width_bottom=T.UI_FIELD_LINE
	if layout:
		style.content_margin_left=12
		style.content_margin_right=12
		var interactive=button.get_theme_stylebox("hover")
		style.content_margin_top=interactive.content_margin_top
		style.content_margin_bottom=interactive.content_margin_bottom
	button.add_theme_stylebox_override("normal",style)
	if layout and displayed=="VIRSL":
		var width=button.get_theme_font("font").get_string_size(displayed,HORIZONTAL_ALIGNMENT_LEFT,-1,button.get_theme_font_size("font_size")).x
		var caption=_label(button,"STANDARD",Rect2(12+width+T.LAYOUT_STANDARD_GAP,0,110,24),T.LAYOUT_STANDARD_FONT,MUTED)
		_align_layout_text(button,caption)
	return button

func _align_layout_text(button: Button,label: Label) -> void:
	# 単行Buttonの中央揃えと同じ基準線へ、寸法の違うタイトルと補足を合わせる。
	var face=button.get_theme_font("font")
	var size_px=button.get_theme_font_size("font_size")
	var style=button.get_theme_stylebox("normal")
	var baseline=style.content_margin_top+(button.size.y-style.content_margin_top-style.content_margin_bottom-face.get_height(size_px))/2+face.get_ascent(size_px)
	label.vertical_alignment=VERTICAL_ALIGNMENT_TOP
	label.global_position.y=button.global_position.y+baseline-label.get_theme_font("font").get_ascent(label.get_theme_font_size("font_size"))

func _open_build_choice(kind: String,slot: int=0) -> void:
	if not build_open:return
	_close_aux()
	var panel=_modal(T.CHOICE_RECT,true)
	build_dialog=BUILD_DIALOG.new()
	panel.add_child(build_dialog)
	build_dialog.configure(self,collection,edit_unit,kind,slot)
	build_dialog.applied.connect(func():_apply_build_choice(kind,slot))
	build_dialog.cancelled.connect(_close_aux)

func _apply_build_choice(kind: String,slot: int) -> void:
	_close_aux()
	_build()
	_focus_build_choice.call_deferred(kind,slot)

func _focus_build_choice(kind: String,slot: int) -> void:
	if not is_instance_valid(overlay):return
	for button in overlay.find_children("*","Button",true,false):
		if button.get_meta("build_choice","")==kind and button.get_meta("skill_slot",-1)==slot:
			button.grab_focus()
			return

func _start_battle() -> void:
	convergences=[]
	planning.reset();playback_command={}
	movement.reset()
	for b in collection.builds:
		if not collection.valid_build(b):
			_notify("Invalid build. Check unlocked elements and the CORE total.")
			return
	build_open=false
	cpu_turn.reset()
	cpu_memory=[]
	cpu_paused=false
	selected=-1
	timeline_hover=-1
	timeline_hover_event={}
	timeline_selected_event={}
	result_awarded=false
	var layout_seed=int(panel_seed_override) if panel_seed_override!=null else panel_rng.randi()
	while panel_seed_override==null and layout_seed==last_panel_seed:
		layout_seed=panel_rng.randi()
	last_panel_seed=layout_seed
	battle.start(collection.stage_index,collection.builds,layout_seed,collection.unit_names)
	_follow_turn()
	_clear_overlay()
	_hud()
	_notify("Click adjacent empty cells, then double-click the endpoint.")

func _result() -> void:
	planning.reset();playback_command={}
	movement.reset()
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
	_label(panel,"DEBUG / NOT SAVED" if collection.temporary else "ARCHIVE / NEW SIGNALS",Rect2(40,187,780,27),16,MUTED)
	var y=235
	if drops.is_empty():
		_prose_label(panel,"NO REWARDS IN DEBUG" if collection.temporary else "0 / NO NEW SIGNALS",Rect2(40,y,780,40),23,WHITE)
	for drop in drops:
		if drop.has("skill"):
			_label(panel,C.SKILLS[drop.skill].label,Rect2(40,y,780,33),22,CYAN)
			_label(panel,drop.skill,Rect2(40,y+36,780,30),14,MUTED)
		else:
			var title=C.serial(drop.kind,drop.stats,drop.mutation) if drop.new_item else "MUTATION / "+M.layout_code(drop.mutation)
			_label(panel,title,Rect2(40,y,780,33),20,CYAN)
			var values=[]
			for i in range(5):
				values.append("%s %d" % [["VIT","INF","RES","SPD","LUK"][i],drop.stats[i]])
			_label(panel," / ".join(values)+(" / "+M.layout_code(drop.mutation) if drop.new_mutation else ""),Rect2(40,y+36,780,35),16,MUTED)
		y+=91
	_button(panel,"RETURN TO BUILD",Rect2(40,440,780,54),_build)

func _help() -> void:
	_close_aux()
	var panel=_modal(Rect2(400,135,1120,810),true)
	_label(panel,"HELP",Rect2(36,25,1048,48),32,WHITE)
	_prose_wrapped_label(panel,"ENEMY CPU automates enemy turns. OFF lets you play both sides.\nSPEED accelerates; PAUSE stops. Help and focus loss pause the CPU.",Rect2(36,85,1048,56),17,MUTED)
	var steps=[
		["move","01 / ROUTE","Focus follows the acting unit.\nClick route cells to undo later steps.\nScroll over a panel for long details."],
		["target","02 / ALIGN","3 contours move at different rates.\nTheir colors follow the actual phase.\nAnimation does not change combat."],
		["check","03 / ACT","Double-click to plan an action.\nPick skill and target, then CONFIRM.\nORTHO = cardinal; DIAGONAL = diagonal.\n1 / 2 = exact cell distance."]
	]
	for i in range(3):
		var x=36+i*354
		_icon(panel,steps[i][0],Rect2(x,153,28,28),CYAN)
		_label(panel,steps[i][1],Rect2(x+42,149,298,32),20,WHITE)
		_prose_label(panel,steps[i][2],Rect2(x,201,340,96 if i==2 else 76),16 if i==2 else 18,MUTED)
	_separator(panel,Rect2(36,300,1048,1))
	_label(panel,"MOVEMENT",Rect2(36,329,490,28),16,CYAN)
	_prose_label(panel,"Move to cardinal neighbors; avoid occupied cells.\nAt least 1 step per turn; no-move WAIT if trapped.\nOrigin / Esc clears the route. No revisits.\nAction BACK / Esc edits the route; target BACK keeps it.\nWhite = progress; gray = wait, scaled to the visible maximum.\nNot a per-unit timer; full circle = zero wait, even if queued.\nVertical spacing is order, not time.",Rect2(36,377,500,174),18,WHITE)
	_label(panel,"PHASE",Rect2(580,329,500,28),16,CYAN)
	_prose_label(panel,"More alignment makes a larger contour.\nINF / RES: final LUK-assisted factors, up to 200%.\nEvery cell turns GEAR anticlockwise, ARMS clockwise.\nCORE: SPD x 1.5 deg; RESET: battle-start angle.\nx5: exact raw INF match and CORE INF <= 10.",Rect2(580,377,510,152),18,WHITE)
	var panel_kinds=["CLOCKWISE","RESET","COUNTERCLOCKWISE"]
	for i in range(panel_kinds.size()):
		var view=PANEL_VIEWS[panel_kinds[i]]
		_icon(panel,view.icon,Rect2(580+i*172,514,20,20),CYAN)
		_label(panel,view.short,Rect2(608+i*172,512,140,28),14,WHITE)
	if not build_open:
		_label(panel,"%s / SEED %d" % [battle.stage.name,battle.panel_seed],Rect2(200,40,884,24),13,MUTED)
	_separator(panel,Rect2(36,560,1048,1))
	_label(panel,"BUILD / ARCHIVE",Rect2(36,589,490,28),16,CYAN)
	_prose_label(panel,"Name 3 PLAYER slots. Max 3 skills; NONE allowed.\nCLASS: CORE order; MUTATION: one equipment ring.\nVIRSL = STANDARD; VLSRI is free. Others: MUTATION unlocks.\nUNLOCK ALL: temporary, debug only, never saved.",Rect2(36,631,500,98),16,WHITE)
	_label(panel,"READING THE SIGNAL",Rect2(580,589,500,28),16,CYAN)
	_prose_label(panel,"Minus = damage; plus = healing.\nINF powers damage and healing; RES resists damage.\nSAVE / LOAD are explicit. Old saves are backed up.",Rect2(580,631,510,66),18,WHITE)
	_prose_label(panel,"Crests identify units and assemblies. A small assembly crest marks your units.",Rect2(580,706,510,22),13,MUTED)
	_button(panel,"CLOSE / ESC",Rect2(36,736,800,44),_close_aux)
	_button(panel,"SKILLS",Rect2(856,736,228,44),_skill_help)

func _skill_help() -> void:
	_close_aux()
	var panel=_modal(Rect2(400,160,1120,760),true)
	_label(panel,"SKILLS",Rect2(36,25,1048,48),32,WHITE)
	_label(panel,"SWAP / PUSH",Rect2(36,102,1048,32),20,CYAN)
	_prose_label(panel,"SWAP: exchange positions with one cardinally adjacent ally.\nPUSH: move one adjacent enemy 1 cell outward into an empty cell. No damage, edges or chain pushes.",Rect2(36,147,1048,68),19,WHITE)
	_label(panel,"GUARD",Rect2(36,245,1048,32),20,CYAN)
	_prose_label(panel,"After moving, target yourself. Reduce the next attack by %d%%; even zero damage consumes it.\nThe octagon means guarded. No stacking. Moving / healing keeps it; a new battle clears it." % roundi((1-T.GUARD_DAMAGE_MULTIPLIER)*100),Rect2(36,290,1048,68),19,WHITE)
	_label(panel,"PANEL IGNORE",Rect2(36,388,1048,32),20,CYAN)
	_prose_label(panel,"Ignore special CORE panels only. GEAR and ARMS still turn normally.\nSWAP moves both units; PUSH moves its target. Each receives one normal entry and its own passives.",Rect2(36,433,1048,68),19,WHITE)
	_prose_label(panel,"These actions replace damage or healing; moving first is still required.\nHover a valid target to preview positions and rings.\nForced movement keeps the target clock. All landings resolve before objectives.",Rect2(36,536,1048,88),18,MUTED)
	_button(panel,"BACK",Rect2(36,670,552,44),_help)
	_button(panel,"FIELDS",Rect2(608,670,228,44),_field_help)
	_button(panel,"CLOSE / ESC",Rect2(856,670,228,44),_close_aux)

func _field_help() -> void:
	_close_aux()
	var panel=_modal(Rect2(400,160,1120,760),true)
	_label(panel,"FIELDS",Rect2(36,25,1048,48),32,WHITE)
	_label(panel,"PASSIVE / SURROUNDING",Rect2(36,88,1048,28),16,MUTED)
	var names=["SLOW","FAST"]
	for i in range(names.size()):
		_label(panel,"%s FIELD x%.1f" % [names[i],C.FIELD_FACTORS[names[i]]],Rect2(36+i*524,153,510,40),24,CYAN)
		_prose_label(panel,["Half equipment rotation.","Speed up equipment rotation."][i],Rect2(36+i*524,204,510,40),18,WHITE)
	_prose_label(panel,"Affects the 8 surrounding cells, including diagonals. Both camps, excluding the source.\nChanges only the GEAR and ARMS rotation for each step.\nCORE, stat values and turn speed stay unchanged.",Rect2(36,285,1048,88),19,WHITE)
	_prose_label(panel,"Same type applies once. SLOW + FAST cancel to normal x1.\nChecked on each landing; no lingering effect outside the field. Standing still does not rotate rings.\nSWAP and PUSH use the same entry rule after all landing positions are set.",Rect2(36,400,1048,90),19,WHITE)
	_prose_label(panel,"Clouds drift around the source. Faint broken clouds preview a moved source.\nHover cells to inspect the exact multiplier and source units.\nPANEL IGNORE skips CORE panels, not fields.",Rect2(36,515,1048,88),18,MUTED)
	_button(panel,"BACK",Rect2(36,670,800,44),_skill_help)
	_button(panel,"CLOSE / ESC",Rect2(856,670,228,44),_close_aux)

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
	check.size=Vector2(470,46)
	check.button_pressed=reduced_motion
	check.toggled.connect(func(value):reduced_motion=value)
	panel.add_child(check)
	_label(panel,"Language",T.SETTINGS_LANGUAGE_LABEL,16,MUTED)
	language_selector=OptionButton.new();language_selector.name="Language"
	language_selector.position=T.SETTINGS_LANGUAGE_CHOICE.position;language_selector.size=T.SETTINGS_LANGUAGE_CHOICE.size
	for title in ["System","English","日本語"]:language_selector.add_item(title)
	language_selector.selected=LANGUAGE.CHOICES.find(copy_language.selection)
	language_selector.item_selected.connect(func(index):_change_language(LANGUAGE.CHOICES[index]))
	panel.add_child(language_selector)
	language_note=_prose_label(panel,"Descriptions only. Names and labels stay unchanged.",T.SETTINGS_LANGUAGE_NOTE,13,MUTED)
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
		_set_prose(picker,"Choose color / "+["ACCENT","VIT","INF","RES","SPD","LUK"][i],"tooltip_text")
		panel.add_child(picker)
		var editor=picker.get_picker()
		editor.sampler_visible=false
		editor.color_modes_visible=false
		editor.sliders_visible=false
		editor.presets_visible=false
		palette_pickers.append(picker)
	_prose_label(panel,"RINGS: VIVID PRESETS / CUSTOM COLORS AS CHOSEN",Rect2(36,558,988,30),15,MUTED)
	palette_error=_label(panel,"",Rect2(36,600,988,52),17,status_colors[1])
	for item in [["APPLY COLORS",Rect2(36,676,988,48),_apply_colors,"check"],["CLOSE / ESC",Rect2(36,742,988,42),_close_aux,"close"]]:
		var button=_button(panel,item[0],item[1],item[2],item[3])
		button.alignment=HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment=VERTICAL_ALIGNMENT_CENTER
		# 設定の2操作だけ、既存の間隔を保ったアイコンと文字を一組で中央へ置く。
		var content_width=button.get_theme_font("font").get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,button.get_theme_font_size("font_size")).x+button.get_theme_constant("icon_max_width")+button.get_theme_constant("h_separation")
		var padding=maxf(0,(button.size.x-content_width)/2)
		for state in ["normal","hover","pressed","focus","disabled"]:
			var style=button.get_theme_stylebox(state).duplicate()
			style.content_margin_left=padding;style.content_margin_right=padding
			button.add_theme_stylebox_override(state,style)

func _apply_colors() -> void:
	var colors=[]
	for picker in palette_pickers:
		colors.append(picker.color)
	var error=P.validate(colors)
	if not error.is_empty():
		_set_prose(palette_error,error)
		return
	error="" if collection.temporary else P.save_to(settings_path,colors)
	if not error.is_empty():
		_set_prose(palette_error,error)
		return
	palette_colors=colors
	_set_theme()
	if is_instance_valid(notice):
		notice.add_theme_color_override("font_color",CYAN)
	debug_notice.add_theme_color_override("font_color",CYAN)
	_close_aux()
	if build_open:
		_build()
	elif battle.mode=="CHOICE":
		_action_dialog()
	elif battle.mode=="RESULT":
		_result()
	_hud()
	_settings()
	_set_prose(palette_error,"APPLIED / DEBUG / NOT SAVED" if collection.temporary else "APPLIED / Saved separately from your build.")
	palette_error.add_theme_color_override("font_color",CYAN)
	queue_redraw()

func _explain(source: String) -> String:
	return copy_language.text(source)

func _set_prose(control: Control,source: String,property: String="text") -> void:
	var fields: Dictionary=control.get_meta("prose_fields",{})
	fields[property]=source;control.set_meta("prose_fields",fields)
	control.set(property,_explain(source))
	if control is Label and property=="text":
		if not control.has_meta("prose_wrap"):control.set_meta("prose_wrap",control.autowrap_mode)
		if not control.has_meta("prose_spacing"):control.set_meta("prose_spacing",control.get_theme_constant("line_spacing"))
		control.add_theme_constant_override("line_spacing",T.JAPANESE_PROSE_SPACING if copy_language.locale()=="ja" else control.get_meta("prose_spacing"))
		control.language=copy_language.locale()
		control.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART if copy_language.locale()=="ja" else control.get_meta("prose_wrap")

func _prose_label(parent: Control,source: String,rect: Rect2,pixels: int=20,color: Color=WHITE,wrap: bool=false) -> Label:
	var label=_label(parent,source,rect,pixels,color,wrap)
	label.set_meta("prose_bounds",rect)
	_set_prose(label,source)
	return label

func _prose_wrapped_label(parent: Control,source: String,rect: Rect2,pixels: int,color: Color) -> Label:
	return _prose_label(parent,source,rect,pixels,color,true)

func _refresh_explanations(node: Node) -> void:
	if node is Control and node.has_meta("prose_fields"):
		for property in node.get_meta("prose_fields"):_set_prose(node,node.get_meta("prose_fields")[property],property)
	if node.has_method("refresh_language"):node.refresh_language()
	for child in node.get_children():_refresh_explanations(child)

func _change_language(choice: String) -> bool:
	var value=choice if LANGUAGE.CHOICES.has(choice) else "system"
	var error="" if collection.temporary else LANGUAGE.write_to(settings_path+".language.json",value)
	if not error.is_empty():
		if is_instance_valid(language_selector):language_selector.selected=LANGUAGE.CHOICES.find(copy_language.selection)
		if is_instance_valid(language_note):_set_prose(language_note,error)
		return false
	copy_language.selection=value
	_refresh_explanations(self)
	if is_instance_valid(language_selector):language_selector.selected=LANGUAGE.CHOICES.find(value)
	if is_instance_valid(language_note):_set_prose(language_note,"Descriptions only. Names and labels stay unchanged.")
	if is_instance_valid(notice):notice.text=_explain(message)
	_update_panel_hint();queue_redraw()
	return true

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
			style.bg_color=PANEL if state=="panel" else (P.INTERACTIVE if state in ["hover","pressed"] else Color.TRANSPARENT)
			style.border_color=WHITE if state=="focus" else EDGE
			style.set_border_width_all(0)
			if state=="focus":
				style.border_width_bottom=T.UI_FOCUS_LINE
			elif type in ["OptionButton","LineEdit"]:
				style.border_width_bottom=T.UI_FIELD_LINE
			style.content_margin_left=12
			style.content_margin_right=12
			style.content_margin_top=4
			style.content_margin_bottom=4
			skin.set_stylebox(state,type,style)
	for type in ["PopupPanel","PanelContainer","TooltipPanel"]:
		var surface=StyleBoxFlat.new()
		surface.bg_color=PANEL
		surface.border_color=EDGE
		surface.set_border_width_all(0)
		surface.content_margin_left=10
		surface.content_margin_right=10
		surface.content_margin_top=10
		surface.content_margin_bottom=10
		skin.set_stylebox("panel",type,surface)
	skin.set_color("font_color","TooltipLabel",WHITE)
	skin.set_font_size("font_size","TooltipLabel",18)
	self.theme=skin

func _fit_text(value: String,width: float,size_px: int,face: Font=null) -> String:
	var typeface=font if face==null else face
	if typeface.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px).x<=width:return value
	var shown=value
	while not shown.is_empty() and typeface.get_string_size(shown+"…",HORIZONTAL_ALIGNMENT_LEFT,-1,size_px).x>width:shown=shown.substr(0,shown.length()-1)
	return shown+"…"

func _unit_badge(parent: Control,center: Vector2,radius: float,u: Dictionary) -> Control:
	var badge=Control.new();badge.position=center-Vector2.ONE*radius;badge.size=Vector2.ONE*radius*2;badge.mouse_filter=Control.MOUSE_FILTER_IGNORE
	badge.accessibility_name=V.unit_name(u);badge.set_meta("unit_id",u.id);badge.set_meta("unit_camp",u.camp)
	parent.add_child(badge);badge.draw.connect(func():V.unit_emblem(badge,Vector2.ONE*radius,radius,u,_assembly_profile(u.camp)))
	return badge

func _unit_action_heading(panel: Control,text: String,u: Dictionary) -> void:
	_unit_badge(panel,Vector2(43,32),14,u)
	_label(panel,text,Rect2(70,16,325,32),18,WHITE)

func _reference_unit(id: String) -> Dictionary:
	var camp="PLAYER" if id.begins_with("0") else "ENEMY"
	var index=I.PLAYER_IDS.find(id) if camp=="PLAYER" else I.ENEMY_IDS.find(id)
	return C.unit(id,camp,Vector2i.ZERO,collection.builds[index] if camp=="PLAYER" else C.default_build(),collection.unit_names[index] if camp=="PLAYER" else "")

func _objective_label(parent: Control,text: String,rect: Rect2,font_px: int,color: Color) -> Control:
	var view=load("res://ui/unit_reference_text.gd").new();parent.add_child(view);view.configure(self,text,rect,font_px,color)
	return view

func _ownership_marker(center: Vector2,u: Dictionary) -> void:
	if not A.owns(u,view_camp):return
	_assembly_emblem(self,center+T.OWNER_MARK_OFFSET,T.OWNER_MARK_RADIUS,_assembly_profile(u.camp),u.camp)

func _ring(canvas: CanvasItem,center: Vector2,radius: float,u: Dictionary,active: bool=false) -> void:
	V.ring(canvas,center,radius,u,active,ring_colors,CYAN,mono,_assembly_profile(u.camp))

func _restart() -> void:
	cpu_turn.reset()
	cpu_memory=[]
	cpu_paused=false
	_close_aux()
	_build()
	_hud()

func _cpu_locked() -> bool:
	return cpu_enabled and not build_open and battle.result.is_empty() and (cpu_turn.active or (battle.actor>=0 and battle.units[battle.actor].camp=="ENEMY"))

func _cpu_tick(delta: float) -> void:
	_follow_turn()
	if movement.active or not cpu_enabled or build_open or is_instance_valid(auxiliary) or not window_focused or cpu_paused:
		return
	if not battle.result.is_empty():
		cpu_turn.reset()
		return
	if not cpu_turn.active:
		if battle.actor<0 or battle.units[battle.actor].camp!="ENEMY":
			return
		var plan=cpu_policy.choose(battle,cpu_memory)
		if plan.is_empty():
			cpu_paused=true
			_notify("CPU paused / No legal plan. RESTART returns to BUILD.")
			return
		cpu_turn.begin(battle,plan)
		_hud()
	var actor=cpu_turn.actor
	var command=cpu_turn.command.duplicate(true)
	var before=battle.units[actor].duplicate(true)
	var event=cpu_turn.advance(battle,delta,false,T.CPU_FAST_SPEED if cpu_fast else 1.0)
	_follow_turn()
	if event=="act":
		_feedback()
	if event in ["act","wait"] or (event=="commit" and not battle.result.is_empty()):
		cpu_memory.append({"actor":actor,"pos":battle.units[actor].pos,"skill":command.skill,"target":command.target})
		cpu_memory=cpu_memory.slice(-T.CPU_MEMORY_LIMIT)
	if event=="commit":
		command.actor=actor
		playback_command=command
		_begin_movement(before,command.path,true)
		return
	if not battle.result.is_empty():
		cpu_turn.reset()
		_result()
		_hud()
	elif event in ["done","cancel"]:
		if event=="cancel":
			cpu_paused=true
			_notify("CPU paused / State changed. RESTART returns to BUILD.")
		_hud()

func _save() -> void:
	var error=collection.save_to(save_path)
	_notify("SAVED / Previous save is backed up." if error.is_empty() else error)

func _load() -> void:
	var error=collection.load_from(save_path)
	if error.is_empty():
		_build()
	_notify("LOADED / Builds and shared archive restored." if error.is_empty() else error)

func _quit() -> void:
	convergences=[]
	planning.reset();playback_command={}
	movement.reset()
	if debug_session.active():_toggle_debug(false)
	get_tree().quit()

func _close_aux() -> void:
	var previous=null
	if is_instance_valid(auxiliary):
		previous=auxiliary.get_meta("previous_focus") if auxiliary.has_meta("previous_focus") else null
		auxiliary.queue_free()
	auxiliary=null
	build_dialog=null
	assembly_dialog=null
	_restore_focus.call_deferred(previous)

func _clear_overlay() -> void:
	if is_instance_valid(overlay):
		overlay.hide()
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
	style.bg_color=BG
	style.set_border_width_all(0)
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
		elif text.begins_with("GUARD"):
			key="gear"
		elif text.begins_with("SWAP") or text.begins_with("PUSH"):
			key="move"
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
		selected_style.bg_color=Color.TRANSPARENT
		selected_style.border_color=CYAN
		selected_style.set_border_width_all(0)
		selected_style.border_width_bottom=T.UI_FOCUS_LINE
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

func _label(parent: Control, text: String, rect: Rect2, size_px: int=20, color: Color=WHITE, wrap: bool=false) -> Label:
	var label=Label.new()
	if wrap:
		label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.text=text
	label.position=rect.position
	label.size=rect.size
	label.add_theme_font_size_override("font_size",size_px)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _wrapped_label(parent: Control, text: String, rect: Rect2, size_px: int, color: Color) -> Label:
	return _label(parent,text,rect,size_px,color,true)

func _notify(text: String) -> void:
	message=text
	message_time=7.0
	if is_instance_valid(notice):
		notice.text=_explain(text)
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
	return str(ceili(value))

static func _effect_text(value: float,kind: String) -> String:
	var amount=_hp(absf(value))
	return amount if amount=="0" else ("-" if kind=="DAMAGE" else "+")+amount

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

func _focus_modal(layer) -> void:
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
