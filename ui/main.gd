## PHASEの一画面UIと手動操作を提供する。
extends Control
const C = preload("res://game/catalog.gd")
const M = preload("res://game/phase_math.gd")
const B = preload("res://game/battle.gd")
const L = preload("res://game/collection.gd")
const V = preload("res://ui/visuals.gd")
const T = preload("res://game/tuning.gd")
const CYAN = V.CYAN
const WHITE = V.TEXT
const MUTED = V.MUTED
const BG = Color("080c13")
const PANEL = Color("0d141f")
const EDGE = Color("253443")
const MAGENTA = Color("c47aff")
const BOARD = Vector2(560,100)
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

func _ready() -> void:
	loot_rng.randomize()
	font=SystemFont.new()
	font.font_names=PackedStringArray(["Helvetica Neue","Hiragino Sans","Arial"])
	mono=SystemFont.new()
	mono.font_names=PackedStringArray(["Menlo","Monaco","monospace"])
	var theme=Theme.new()
	theme.default_font=font
	theme.default_font_size=20
	theme.set_color("font_color","Label",WHITE)
	theme.set_color("font_color","Button",WHITE)
	theme.set_color("font_hover_color","Button",CYAN)
	theme.set_color("font_color","OptionButton",WHITE)
	for name in ["normal","hover","pressed","focus","disabled"]:
		var style=StyleBoxFlat.new()
		style.bg_color=Color("111e2a") if name=="normal" else Color("18323a")
		if name=="disabled":
			style.bg_color=Color("0e151d")
		style.border_color=EDGE if name=="normal" else CYAN
		style.set_border_width_all(1)
		style.set_corner_radius_all(3)
		style.content_margin_left=16
		style.content_margin_right=16
		theme.set_stylebox(name,"Button",style)
		theme.set_stylebox(name,"OptionButton",style)
	self.theme=theme
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
	for y in range(0,1080,4):
		draw_line(Vector2(0,y),Vector2(1920,y),Color(0.1,0.16,0.2,0.035))
	_text("TACTICAL PHASE LABORATORY",Vector2(150,38),14,MUTED,mono)
	_text("MANUAL CONTROL / BOTH FACTIONS",Vector2(1390,38),14,MUTED,mono)
	_panel(Rect2(150,64,370,740))
	_panel(Rect2(1300,64,470,740))
	_draw_left()
	_draw_board()
	_draw_info()
	_draw_preview()
	_text("PHASE  /  4.7  /  NO COMBAT RNG",Vector2(150,1053),13,MUTED,mono)
	if message_time>0 and not build_open:
		_text(message,Vector2(150,1028),18,CYAN)
	for t in toasts:
		var color: Color=t.color
		color.a=clampf((2.4-t.age)/0.7,0,1)
		var p: Vector2=BOARD+Vector2(t.cell)*70+Vector2(35,3-t.age*24)
		_center(t.text,p,24,color,mono)

func _draw_left() -> void:
	_text("P H A S E",Vector2(172,125),47,WHITE)
	_text("MOVE / ALIGN / INTERFERE",Vector2(174,153),13,CYAN,mono)
	var y=191.0
	for camp in ["PLAYER","ENEMY"]:
		var hp=0.0
		var max_hp=0.0
		for u in battle.units:
			if u.camp==camp:
				hp+=u.hp
				max_hp+=u.max_hp
		var color=CYAN if camp=="PLAYER" else V.COLORS[1]
		_text(camp,Vector2(174,y),17,color,mono)
		_text("%s / %s" % [_hp(hp),_hp(max_hp)],Vector2(332,y),17,WHITE,mono)
		_bar(Rect2(174,y+12,318,5),hp/maxf(1,max_hp),color)
		y+=57
	_text("TURN ORDER",Vector2(174,328),14,MUTED,mono)
	_text("T / %.1f" % battle.units[battle.actor].next_time,Vector2(367,328),14,CYAN,mono)
	var rows=battle.timeline(6)
	for k in range(rows.size()):
		var row: Dictionary=rows[k]
		var u: Dictionary=battle.units[row.index]
		y=345+k*64
		var rect=Rect2(164,y,342,58)
		draw_rect(rect,Color("10282d") if k==0 else Color("0b111b"))
		draw_rect(rect,CYAN if k==0 else EDGE,false,1)
		_text("%02d" % (k+1),Vector2(174,y+34),15,CYAN if k==0 else MUTED,mono)
		V.ring(self,Vector2(223,y+29),22,u,k==0)
		_text(u.id,Vector2(257,y+22),21,WHITE,mono)
		_bar(Rect2(257,y+31,59,3),u.hp/u.max_hp,CYAN if u.camp=="PLAYER" else V.COLORS[1])
		_text("I %3.0f%%" % (M.sync(u,1).factor*100),Vector2(331,y+23),13,V.COLORS[1],mono)
		_text("R %3.0f%%" % (M.sync(u,2).factor*100),Vector2(331,y+43),13,V.COLORS[2],mono)
	_text("TURN %03d" % battle.turn,Vector2(174,762),15,CYAN,mono)
	_text("ALL UNITS: YOU",Vector2(322,762),13,MUTED,mono)

func _draw_board() -> void:
	_text(battle.stage.name,Vector2(560,77),18,WHITE,mono)
	_text(battle.stage.type,Vector2(1090,77),14,CYAN,mono)
	for x in range(10):
		_text(str(x),BOARD+Vector2(x*70+32,-7),12,MUTED,mono)
	for y in range(10):
		_text(str(y),BOARD+Vector2(-19,y*70+40),12,MUTED,mono)
	for y in range(10):
		for x in range(10):
			var cell=Vector2i(x,y)
			var pos=BOARD+Vector2(cell)*70
			var rect=Rect2(pos+Vector2.ONE,Vector2(68,68))
			var panel=battle.panels.get(cell,"NORMAL")
			var color=Color("101923") if (x+y)%2==0 else Color("0c141e")
			if panel!="NORMAL":
				color=Color("19182a") if panel=="REVERSE" else Color("102229")
			if battle.path.has(cell):
				color=Color("16424a")
			if cell==hover_cell and not is_instance_valid(overlay):
				color=color.lightened(0.12)
			draw_rect(rect,color)
			draw_rect(rect,EDGE,false,1)
			if panel!="NORMAL":
				var pc=MAGENTA if panel=="REVERSE" else (V.COLORS[3] if panel=="LOCK" else CYAN)
				_text({"SHIFT":"S+","LOCK":"L=","REVERSE":"R-"}[panel],pos+Vector2(5,14),11,Color(pc,0.8),mono)
			if cell==battle.stage.goal:
				draw_rect(rect.grow(-4),Color(MAGENTA,0.6),false,1)
				_text("GOAL",pos+Vector2(6,62),11,MAGENTA,mono)
			if battle.mode=="TARGET" and _distance(cell,battle.units[battle.actor].pos)==1:
				var tc=V.COLORS[1] if battle.selected_skill==C.DAMAGE else V.COLORS[2]
				draw_rect(rect,Color(tc,0.12))
				draw_rect(rect.grow(-3),Color(tc,0.7),false,1.5)
			var i=battle.at(cell)
			if i>=0:
				var u: Dictionary=battle.units[i]
				var center=pos+Vector2(35,29)
				if i==battle.actor:
					draw_circle(center,29,Color(CYAN,0.07))
				V.ring(self,center,24,u,i==battle.actor)
				_center(u.id,pos+Vector2(35,35),14,WHITE,mono)
				_bar(Rect2(pos+Vector2(15,59),Vector2(40,3)),u.hp/u.max_hp,CYAN if u.camp=="PLAYER" else V.COLORS[1])
				if i==selected:
					_brackets(Rect2(pos+Vector2(5,5),Vector2(60,60)),MAGENTA)
				if battle.mode=="TARGET" and battle.valid_target(battle.actor,i,battle.selected_skill):
					var tc=V.COLORS[1] if battle.selected_skill==C.DAMAGE else V.COLORS[2]
					draw_rect(rect.grow(-1),tc,false,2)
					var amount=M.effect(battle.units[battle.actor],u,C.SKILLS[battle.selected_skill].effect)
					if battle.selected_skill==C.HEAL:
						amount=mini(amount,ceili(u.max_hp-u.hp))
					_center(("-" if battle.selected_skill==C.DAMAGE else "+")+str(amount),pos+Vector2(35,76),17,tc,mono)
	if battle.mode=="MOVE":
		var prev: Vector2=BOARD+Vector2(battle.units[battle.actor].pos)*70+Vector2(35,35)
		for cell in battle.path:
			var now=BOARD+Vector2(cell)*70+Vector2(35,35)
			var direction=(now-prev).normalized()
			draw_line(prev+direction*15,now-direction*15,CYAN,2,true)
			prev=now
		for i in range(battle.path.size()):
			var center=BOARD+Vector2(battle.path[i])*70+Vector2(35,35)
			draw_circle(center,14,WHITE)
			_center(str(i+1),center+Vector2(0,6),17,BG,mono)
		if not battle.path.is_empty():
			_brackets(Rect2(BOARD+Vector2(battle.path.back())*70+Vector2(3,3),Vector2(64,64)),CYAN)
	_text(battle.stage.brief,Vector2(560,828),15,MAGENTA,mono)

func _draw_info() -> void:
	var index=selected if selected>=0 else battle.actor
	var u: Dictionary=battle.units[index]
	var camp_color=CYAN if u.camp=="PLAYER" else V.COLORS[1]
	_text("UNIT INFORMATION",Vector2(1324,94),14,MUTED,mono)
	_text(u.id,Vector2(1324,147),44,WHITE,mono)
	_text(u.camp+" / "+u.class_name,Vector2(1420,140),17,camp_color,mono)
	V.ring(self,Vector2(1535,245),81,u,index==battle.actor)
	_text("CORE / GEAR / ARMS",Vector2(1438,348),13,MUTED,mono)
	_text("HP",Vector2(1324,385),15,MUTED,mono)
	_text("%s / %s" % [_hp(u.hp),_hp(u.max_hp)],Vector2(1390,385),21,WHITE,mono)
	_text("MOVE %d / %d" % [u.moved,battle.movement(u)],Vector2(1588,385),16,CYAN,mono)
	_bar(Rect2(1324,397,422,4),u.hp/u.max_hp,camp_color)
	for k in range(5):
		_text(["VIT","INF","RES","SPD","LUK"][k],Vector2(1410+k*68,432),14,V.COLORS[k],mono)
	for r in range(3):
		var y=461+r*27
		_text(["CORE","GEAR","ARMS"][r],Vector2(1324,y),14,MUTED,mono)
		for k in range(5):
			_text("%02d" % u[M.KEYS[r]][k],Vector2(1415+k*68,y),17,WHITE,mono)
	_text(C.serial("ARMS",u.arms),Vector2(1324,558),15,WHITE,mono)
	_text("MUTATION / "+u.arms_mutation,Vector2(1324,580),12,MUTED,mono)
	_text(C.serial("GEAR",u.gear),Vector2(1324,611),15,WHITE,mono)
	_text("MUTATION / "+u.gear_mutation,Vector2(1324,633),12,MUTED,mono)
	for k in range(u.skills.size()):
		var skill: Dictionary=C.SKILLS[u.skills[k]]
		var y=648+k*43
		draw_rect(Rect2(1324,y,422,37),Color("111f2b"))
		draw_rect(Rect2(1324,y,2,37),CYAN if skill.type=="ACTIVE" else MAGENTA)
		_text(skill.type,Vector2(1335,y+24),12,MUTED,mono)
		_text(skill.effect+" / "+skill.area,Vector2(1418,y+24),15,WHITE,mono)

func _draw_preview() -> void:
	var u=battle.preview()
	_panel(Rect2(150,850,1620,163))
	_text("PHASE PREVIEW",Vector2(174,879),14,MUTED,mono)
	var length=battle.path.size() if battle.mode=="MOVE" else u.moved
	_text("PATH %d / DESTINATION (%d, %d)" % [length,u.pos.x,u.pos.y],Vector2(415,879),15,CYAN,mono)
	V.ring(self,Vector2(225,947),48,u)
	_center(u.id,Vector2(225,953),19,WHITE,mono)
	_text("G %05.1f" % u.gear_angle,Vector2(293,933),14,MUTED,mono)
	_text("A %05.1f" % u.arms_angle,Vector2(293,958),14,MUTED,mono)
	V.wave(self,Rect2(415,895,932,98),u,clock)
	_text("0°",Vector2(415,1005),10,MUTED,mono)
	_text("180°",Vector2(860,1005),10,MUTED,mono)
	_text("360°",Vector2(1316,1005),10,MUTED,mono)
	_text("RESONANCE",Vector2(1380,879),14,MUTED,mono)
	_text("INF SYNC",Vector2(1380,916),14,V.COLORS[1],mono)
	_text("%5.1f%%" % (M.sync(u,1).factor*100),Vector2(1618,916),22,V.COLORS[1],mono)
	_text("RES SYNC",Vector2(1380,948),14,V.COLORS[2],mono)
	_text("%5.1f%%" % (M.sync(u,2).factor*100),Vector2(1618,948),22,V.COLORS[2],mono)
	_text("SINGULARITY",Vector2(1380,984),14,MUTED,mono)
	_text("READY ×5" if M.singularity(u) else "OFFLINE",Vector2(1618,984),17,MAGENTA if M.singularity(u) else MUTED,mono)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_F1:
			_help()
		elif event.keycode==KEY_ESCAPE:
			if is_instance_valid(auxiliary):
				auxiliary.queue_free()
				auxiliary=null
			elif battle.mode=="TARGET":
				battle.back()
				_action_dialog()
			elif battle.mode=="MOVE" and not build_open:
				battle.path=[]
		return
	if is_instance_valid(auxiliary) or is_instance_valid(overlay):
		return
	if event is InputEventMouseMotion:
		var p=get_global_mouse_position()-BOARD
		hover_cell=Vector2i(floori(p.x/70),floori(p.y/70))
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var p=get_global_mouse_position()
		if Rect2(560,100,700,700).has_point(p):
			_cell_input(Vector2i(floori((p.x-560)/70),floori((p.y-100)/70)),event.double_click)
		else:
			for k in range(6):
				if Rect2(164,345+k*64,342,58).has_point(p):
					selected=battle.timeline(6)[k].index

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
	toasts.append({"cell":u.pos,"text":("-" if e.kind=="DAMAGE" else "+")+shown,"color":V.COLORS[1] if e.kind=="DAMAGE" else V.COLORS[2],"age":0.0})
	if e.dead:
		toasts.append({"cell":u.pos,"text":"DEFEATED","color":V.COLORS[1],"age":-0.65})

func _hud() -> void:
	if is_instance_valid(hud):
		hud.queue_free()
	hud=Control.new()
	hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	for row in [["HELP",1218,_help],["SETTINGS",1346,_settings],["RESTART",1492,_restart],["QUIT",1640,_quit]]:
		_button(hud,row[0],Rect2(row[1],1025,118,40),row[2])
	var hint="Click adjacent cells • Double-click endpoint to confirm • Esc clears route"
	if battle.mode=="TARGET":
		hint="SELECT TARGET / "+C.SKILLS[battle.selected_skill].label
		_button(hud,"BACK",Rect2(1024,802,236,37),func():battle.back();_action_dialog())
	elif battle.mode=="MOVE" and battle.trapped():
		hint="NO LEGAL MOVEMENT / WAIT AVAILABLE"
		_button(hud,"WAIT",Rect2(1024,802,236,37),func():battle.wait_turn();_after_action())
	_label(hud,hint,Rect2(560,55,700,27),14,MUTED).visible=false
	if not build_open:
		_label(hud,hint,Rect2(560,14,720,30),14,CYAN)

func _action_dialog() -> void:
	_clear_overlay()
	_hud()
	var active=[]
	for skill in battle.units[battle.actor].skills:
		if C.SKILLS[skill].type=="ACTIVE":
			active.append(skill)
	var height=122+active.size()*63
	var panel=_modal(Rect2(700,330,420,height),false)
	_label(panel,"UNIT "+battle.units[battle.actor].id+" / ACTION",Rect2(25,20,370,25),17,CYAN)
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
	_label(panel,"BUILD / PHASE CONFIGURATION",Rect2(36,25,920,45),30,WHITE)
	_label(panel,"Every route changes your phase. Every faction is controlled by you.",Rect2(36,78,1100,29),19,MUTED)
	for i in range(2):
		_button(panel,"PLAYER %02d" % (i+1),Rect2(36+i*200,126,185,43),func():edit_unit=i;_build())
	_label(panel,"SHARED ARCHIVE / %d ARMS / %d GEAR / %d MUTATIONS" % [collection.items.ARMS.size(),collection.items.GEAR.size(),collection.mutations.size()],Rect2(36,187,1150,22),14,CYAN)
	var b: Dictionary=collection.builds[edit_unit]
	_label(panel,"CLASS",Rect2(36,237,160,30),16,MUTED)
	_option(panel,["STANDARD","REVERSE"],b.class_name,Rect2(210,230,390,43),func(value):b.class_name=value;_refresh_build())
	_label(panel,"CORE / TOTAL 100",Rect2(36,292,560,27),16,MUTED)
	core_controls=[]
	for k in range(5):
		_label(panel,["VIT","INF","RES","SPD","LUK"][k],Rect2(36+k*116,326,100,25),17,V.COLORS[k])
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
	_label(panel,"Changing one value redistributes the others. All stats stay ≥ 1.",Rect2(36,414,570,27),14,MUTED)
	for r in range(2):
		var key="arms" if r==0 else "gear"
		var y=460+r*110
		_label(panel,key.to_upper(),Rect2(36,y,170,28),17,WHITE)
		var choices: Array=collection.items[key.to_upper()].keys()
		_option(panel,choices,C.serial(key.to_upper(),b[key]),Rect2(210,y-5,390,40),func(value):b[key]=collection.items[key.to_upper()][value].duplicate();_refresh_build())
		_label(panel,"MUTATION",Rect2(36,y+46,170,24),14,MUTED)
		_option(panel,collection.mutations,b[key+"_mutation"],Rect2(210,y+39,390,36),func(value):b[key+"_mutation"]=value;_refresh_build())
	_label(panel,"SKILLS / UP TO 3 / NONE ALLOWED",Rect2(688,328,580,30),15,MUTED)
	for i in range(3):
		var choices=["NONE"]
		choices.append_array(collection.skills)
		var current: String=b.skills[i] if i<b.skills.size() else "NONE"
		_option(panel,choices,current,Rect2(688,368+i*49,588,41),func(value):_skill_change(i,value))
	_label(panel,"STAGE / OBJECTIVE",Rect2(688,536,570,26),16,MUTED)
	var stages=[]
	for s in C.stages():
		stages.append(s.name)
	_option(panel,stages,C.stages()[collection.stage_index].name,Rect2(688,573,588,42),func(value):collection.stage_index=stages.find(value);_build())
	_label(panel,C.stages()[collection.stage_index].brief,Rect2(688,626,588,27),17,MAGENTA)
	_label(panel,C.stages()[collection.stage_index].hint,Rect2(688,660,588,48),16,MUTED)
	build_preview=Control.new()
	build_preview.position=Vector2(688,218)
	build_preview.size=Vector2(588,96)
	build_preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_child(build_preview)
	build_preview.draw.connect(func():
		var u=C.unit("%02d" % (edit_unit+1),"PLAYER",Vector2i.ZERO,collection.builds[edit_unit])
		V.ring(build_preview,Vector2(65,46),46,u,true)
		build_preview.draw_string(mono,Vector2(135,28),"HP %s / MOVE %d" % [_hp(u.max_hp),battle.movement(u)],HORIZONTAL_ALIGNMENT_LEFT,-1,20,WHITE)
		build_preview.draw_string(mono,Vector2(135,62),"DELAY %.1f / INF %.1f%%" % [M.delay(u),M.sync(u,1).factor*100],HORIZONTAL_ALIGNMENT_LEFT,-1,16,CYAN))
	for row in [["SAVE",36,_save],["LOAD",151,_load],["HELP",266,_help],["SETTINGS",381,_settings],["QUIT",526,_quit]]:
		_button(panel,row[0],Rect2(row[1],730,106 if row[0]!="SETTINGS" else 136,44),row[2])
	_button(panel,"BATTLE START →",Rect2(934,730,342,48),_start_battle)
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

func _start_battle() -> void:
	for b in collection.builds:
		if not collection.valid_build(b):
			_notify("Invalid build. Check unlocked elements and the CORE total.")
			return
	build_open=false
	battle.start(collection.stage_index,collection.builds)
	_clear_overlay()
	_hud()
	_notify("UNIT %s / %s — Click adjacent empty cells, then double-click the endpoint." % [battle.units[battle.actor].id,battle.units[battle.actor].camp])

func _result() -> void:
	_clear_overlay()
	drops=collection.roll_loot(loot_rng)
	var panel=_modal(Rect2(530,240,860,540),false)
	_label(panel,battle.result,Rect2(40,35,780,66),53,CYAN if battle.result=="VICTORY" else V.COLORS[1])
	_label(panel,"%s / %d TURNS" % [battle.stage.name,battle.turn],Rect2(40,120,780,34),19,MUTED)
	_label(panel,"NEWLY UNLOCKED / SHARED BY ALL UNITS",Rect2(40,187,780,27),16,MUTED)
	var y=235
	if drops.is_empty():
		_label(panel,"NO NEW SIGNALS / 0 ITEMS",Rect2(40,y,780,40),23,WHITE)
	for drop in drops:
		if drop.has("skill"):
			_label(panel,drop.skill,Rect2(40,y,780,33),20,CYAN)
		else:
			var title=C.serial(drop.kind,drop.stats,drop.mutation) if drop.new_item else "MUTATION / "+drop.mutation
			_label(panel,title,Rect2(40,y,780,33),20,CYAN)
			_label(panel,str(drop.stats)+(" / NEW MUTATION: "+drop.mutation if drop.new_mutation else ""),Rect2(40,y+36,780,35),16,MUTED)
		y+=91
	_button(panel,"RETURN TO BUILD →",Rect2(40,440,780,54),_build)

func _help() -> void:
	_close_aux()
	var panel=_modal(Rect2(445,155,1030,770),true)
	_label(panel,"HELP / THINK IN ROUTES",Rect2(36,26,950,53),32,CYAN)
	var text="両陣営を自分で操作する検証用の戦術ゲームです。敵CPUはありません。\n\n1  BUILDでPLAYER 01 / 02を編集し、ステージを選びます。\n2  シアンの手番ユニットから、空いている隣接マスを順番にクリックします。\n3  下のPHASE PREVIEWで経路後の位相と効果補正を比較します。\n4  最終マスをダブルクリックして確定し、WAITかACTIVEを選びます。\n5  赤 / 緑の対象をクリックして実行します。BACKは移動を保持します。\n\n選択済み経路のマスで後続を取消。開始マスまたはEscで経路を全取消。\n生存ユニットのマス、斜め、範囲外、同じマスへの再進入は禁止です。\n毎手番1マス以上の移動が必須です。閉塞時だけ無移動WAITが可能です。\nユニットや手番一覧をクリックすると右側の詳細を調べられます。\n\nNORMAL : GEAR ↶ / ARMS ↷     SHIFT S+ : ARMSの回転2倍\nLOCK L= : GEARを固定         REVERSE R- : ARMSを逆回転\n\nINFは赤、RESは緑。表示SYNCはベルカーブ適用後の効果補正(最大200%)。\nRAWの重なり率とASSISTEDの中間値は計算上で区別しています。\nSINGULARITYは生INF領域が完全一致し、CORE:INF≤10のときだけ5倍。\n\n装備と変異は共有されます。SAVEはビルドと開放一覧を保存します。\nLOADは明示的に行います。再保存時は以前のデータを別名で残します。"
	_label(panel,text,Rect2(36,100,958,591),19,WHITE)
	_button(panel,"CLOSE / ESC",Rect2(36,704,958,43),_close_aux)

func _settings() -> void:
	_close_aux()
	var panel=_modal(Rect2(650,335,620,380),true)
	_label(panel,"SETTINGS",Rect2(30,24,560,45),32,CYAN)
	_button(panel,"WINDOWED",Rect2(30,95,270,55),func():DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED))
	_button(panel,"FULLSCREEN",Rect2(320,95,270,55),func():DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN))
	var check=CheckButton.new()
	check.text="REDUCED MOTION"
	check.position=Vector2(30,180)
	check.size=Vector2(560,50)
	check.button_pressed=reduced_motion
	check.toggled.connect(func(value):reduced_motion=value)
	panel.add_child(check)
	_button(panel,"CLOSE / ESC",Rect2(30,285,560,51),_close_aux)

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
	if is_instance_valid(auxiliary):
		auxiliary.queue_free()
	auxiliary=null

func _clear_overlay() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay=null
	build_preview=null

func _modal(rect: Rect2, is_aux: bool) -> Control:
	var layer=Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(layer)
	var dim=ColorRect.new()
	dim.color=Color(0.015,0.025,0.045,0.90 if build_open else 0.56)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var panel=Panel.new()
	panel.position=rect.position
	panel.size=rect.size
	var style=StyleBoxFlat.new()
	style.bg_color=Color("0d1722")
	style.border_color=Color("325462")
	style.set_border_width_all(1)
	style.shadow_color=Color(0,0,0,0.5)
	style.shadow_size=24
	panel.add_theme_stylebox_override("panel",style)
	layer.add_child(panel)
	if is_aux:
		auxiliary=layer
	else:
		overlay=layer
	return panel

func _button(parent: Control, text: String, rect: Rect2, callback: Callable) -> Button:
	var button=Button.new()
	button.text=text
	button.position=rect.position
	button.size=rect.size
	button.add_theme_font_size_override("font_size",17)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _option(parent: Control, values: Array, current: String, rect: Rect2, callback: Callable) -> OptionButton:
	var option=OptionButton.new()
	option.position=rect.position
	option.size=rect.size
	option.add_theme_font_size_override("font_size",16)
	for value in values:
		option.add_item(str(value))
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
	draw_rect(rect,EDGE,false,1)
	draw_line(rect.position,rect.position+Vector2(40,0),CYAN,2)

func _text(text: String, position_px: Vector2, font_size: int, color: Color=WHITE, typeface: Font=null) -> void:
	draw_string(font if typeface==null else typeface,position_px,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _center(text: String, position_px: Vector2, font_size: int, color: Color=WHITE, typeface: Font=null) -> void:
	var f=font if typeface==null else typeface
	var width=f.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	draw_string(f,position_px-Vector2(width/2,0),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _bar(rect: Rect2, ratio: float, color: Color) -> void:
	draw_rect(rect,Color("25313b"))
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
