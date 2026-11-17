extends SceneTree
const B=preload("res://tests/fixture_battle.gd")
const C=preload("res://game/catalog.gd")
const T=preload("res://game/tuning.gd")
var checks=0
var failures=0
var model
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	if ResourceLoader.exists("res://ui/timeline.gd"):
		model=load("res://ui/timeline.gd").new()
		_test_times()
		_test_progress()
		_test_current()
		_test_lifecycle()
		await _test_input()
	else:
		_check(false,"turn-order view model is implemented")
	print("TIME AXIS: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
func _battle():
	var b=B.new()
	b.start(0,[C.starter_build(),C.starter_build()])
	return b
## REQ-019-S06
func _test_times() -> void:
	var b=_battle()
	for i in range(4):
		b.units[i].next_time=[100.0,100.0,100.01,200.0][i]
	b.next_actor()
	var before=b.units.duplicate(true)
	var rows=[{"index":0,"time":100.0},{"index":1,"time":100.0},{"index":2,"time":100.01},{"index":0,"time":150.0},{"index":3,"time":200.0},{"index":1,"time":250.0}]
	var view=model.layout(b.units,0,rows)
	_check(view.now==100.0 and view.span==150.0,"actor time is origin, not clock or next queued actor")
	var expected=[0.0,0.0,0.01,50.0,100.0,150.0]
	for i in range(6):
		var e=view.events[i]
		_check(absf(e.remaining-expected[i])<0.000000001,"exact relative time "+str(i))
		_check(absf(e.point.y-(T.TIMELINE_TOP+i/5.0*(T.TIMELINE_BOTTOM-T.TIMELINE_TOP)))<0.0001,"equal ordered spacing independent of wait "+str(i))
	_check(view.events[0].point!=view.events[1].point and view.events[2].point.y>view.events[1].point.y,"same and near times remain distinct points")
	_check(not view.has("groups"),"no central grouped IDs")
	for i in range(6):
		_check(absf(view.events[i].get("wait_fraction",-1.0)-expected[i]/150.0)<0.000000001,"gray share keeps actual remaining wait "+str(i))
	var expected_progress=[1.0,1.0,1.0-0.01/150.0,2.0/3.0,1.0/3.0,0.0]
	for i in range(6):
		_check(absf(view.events[i].get("progress_fraction",-1.0)-expected_progress[i])<0.000000001,"white progress reverses remaining fraction "+str(i))
	var links=view.get("links",[])
	_check(links.size()==6,"exactly one leader per action")
	for i in range(links.size()):
		_check(links[i].index==rows[i].index and links[i].event==view.events[i],"each point connects only its own unit")
	_check(view.events[3].repeated and view.events[5].repeated,"future repeats have their own action points")
	_check(model.caption(view.events[0],0)=="1  0 / ACTING" and model.caption(view.events[1],0)=="2  0 / QUEUED","zero acting and queued are different")
	_check(model.caption(view.events[2],0)=="A  +0.01","small relative wait is exact and compact")
	_check(b.units==before and rows[0]=={"index":0,"time":100.0},"layout is pure")
	for i in range(4):
		b.units[i].next_time=100.0
	b.next_actor()
	view=model.layout(b.units,b.actor,b.timeline(6))
	_check(view.events.slice(0,4).map(func(e):return e.index)==[0,1,2,3],"same time processing order is 1 2 A B")
	for i in range(4):
		_check(absf(view.events[i].point.y-(T.TIMELINE_TOP+[0.0,0.2,0.4,0.6][i]*(T.TIMELINE_BOTTOM-T.TIMELINE_TOP)))<0.0001,"same-time actions have separate equally spaced slots "+str(i))
	for event in view.events:
		_check(model.hit(view,event.point).index==event.index and model.hit(view,event.point).time==event.time,"each action point has unambiguous input")
	if model.has_method("rows"):
		for i in range(4):
			b.units[i].core=[1,1,1,96,1] if i<3 else [25,25,25,1,24]
			b.units[i].next_time=50.0 if i<3 else 450.0
			b.units[i].max_hp=b.M.max_hp(b.units[i])
			b.units[i].hp=b.units[i].max_hp
		b.next_actor()
		var projected=model.rows(b)
		view=model.layout(b.units,b.actor,projected)
		var expected_indices=[]
		for repeat in range(9):
			expected_indices.append_array([0,1,2])
		expected_indices.append(3)
		_check(view.events.map(func(e):return e.index)==expected_indices,"slow unit keeps all 28 actual actions, with none skipped or appended as fake NEXT")
		for i in range(view.events.size()):
			_check(view.events[i].rank==i+1 and absf(view.events[i].point.y-(T.TIMELINE_TOP+i/27.0*(T.TIMELINE_BOTTOM-T.TIMELINE_TOP)))<0.0001,"dense exact ordinal position "+str(i))
			_check(model.hit(view,view.events[i].point).rank==i+1,"dense points have disjoint input "+str(i))
	else:
		_check(false,"projection includes complete sequence through slowest unit")

## REQ-019-S06
func _test_progress() -> void:
	var b=_battle()
	for i in range(4):
		b.units[i].next_time=[100.0,150.0,200.0,300.0][i]
	b.next_actor()
	var rows=[{"index":0,"time":100.0},{"index":1,"time":150.0},{"index":2,"time":200.0},{"index":3,"time":300.0}]
	var initial=model.layout(b.units,0,rows)
	_check(initial.events[1].get("progress_fraction",-1.0)==0.75,"wait50 with max200 gives white75 percent")
	b.units[0].next_time=125.0
	rows[0].time=125.0
	var later=model.layout(b.units,0,rows)
	_check(absf(later.events[1].get("progress_fraction",-1.0)-6.0/7.0)<0.000000001,"closer action has more white within same schedule")
	b.units[0].next_time=100.0
	rows[0].time=100.0
	b.units[3].next_time=200.0
	rows[3].time=200.0
	var smaller=model.layout(b.units,0,rows)
	_check(smaller.span==100.0 and smaller.events[1].remaining==50.0 and smaller.events[1].get("progress_fraction",-1.0)==0.5,"changed maximum recalculates relative white without changing remaining wait")
	_check(model.caption(initial.events[1],0)=="2  +50" and model.caption(smaller.events[1],0)=="2  +50","precise waiting number stays truthful as range changes")
	for i in range(4):
		b.units[i].next_time=100.0
		rows[i].time=100.0
	var zero=model.layout(b.units,0,rows)
	_check(zero.span==0.0 and zero.events.size()==4 and zero.events.all(func(e):return e.get("progress_fraction",-1.0)==1.0),"zero maximum gives full white without division by zero")
	_check(model.caption(zero.events[0],0)=="1  0 / ACTING" and model.caption(zero.events[1],0)=="2  0 / QUEUED","full white still distinguishes actor and queued zero")

## REQ-019-S07
func _test_current() -> void:
	var b=_battle()
	b.units[0].gear_angle=73.0
	b.units[0].hp=25.0
	var view=model.layout(b.units,b.actor,b.timeline(6))
	_check(view.cards.size()==4 and view.cards.map(func(c):return c.index)==[0,1,2,3],"four current states, no repeated future states")
	for card in view.cards:
		_check(card.center.x==(T.TIMELINE_CARD_X.x if card.index<2 else T.TIMELINE_CARD_X.y),"correct camp side")
		_check(card.rect.position.x>=40 and card.rect.end.x<384 and card.rect.end.y<T.PREVIEW_PANEL.position.y,"cards fit existing left region")
		_check(card.unit==b.units[card.index],"state is exact current data")
		_check(model.hit(view,card.center).index==card.index,"state input selects associated unit")
	for pair in [[0,1],[2,3]]:
		_check(not view.cards[pair[0]].rect.intersects(view.cards[pair[1]].rect),"same side cards cannot overlap")
	_check(view.cards[0].unit.hp==25.0 and view.cards[0].unit.gear_angle==73.0,"current HP and phase retained")
	_check(model.hit(view,Vector2(384,400)).is_empty() and model.hit(view,T.PREVIEW_CENTER).is_empty(),"timeline hit regions exclude board and preview")
## REQ-019-S08
func _test_lifecycle() -> void:
	var b=_battle()
	b.units[2].hp=0.0
	var view=model.layout(b.units,b.actor,b.timeline(6))
	_check(not view.events.any(func(e):return e.index==2) and view.cards[2].event.is_empty(),"dead current state has no future event or leader")
	var old_now=view.now
	b.mode="CHOICE"
	b.wait_turn()
	view=model.layout(b.units,b.actor,b.timeline(6))
	_check(view.now==b.units[b.actor].next_time and view.events[0].index==b.actor,"new actor determines current origin")
	b.mode="CHOICE"
	b.wait_turn()
	b.mode="CHOICE"
	b.wait_turn()
	view=model.layout(b.units,b.actor,b.timeline(6))
	_check(view.now>old_now and view.events[0].remaining==0.0,"reinsertion advances real schedule")
	view=model.layout(b.units,b.actor,b.timeline(6),true)
	_check(view.events.is_empty() and view.get("links",[]).is_empty() and view.cards.all(func(c):return c.event.is_empty()),"result contains no hypothetical future")
## REQ-019-S10、REQ-019-S11
func _test_readouts(game) -> void:
	_check(game.has_method("_factor_field") and game.has_method("_turn_label"),"compact readout formatters are implemented")
	if not game.has_method("_factor_field") or not game.has_method("_turn_label"):
		return
	for pair in [[0.0,"  0"],[1.0,"  1"],[9.0,"  9"],[10.0," 10"],[83.0," 83"],[99.0," 99"],[100.0,"100"],[200.0,"200"],[999.0,"999"],[0.49,"  0"],[0.5,"  1"],[99.5,"100"],[-0.01,"---"],[999.01,"---"],[INF,"---"],[-INF,"---"],[NAN,"---"]]:
		_check(game._factor_field(pair[0])==pair[1],"exact three-character percentage field "+str(pair[0]))
	for pair in [[1,"TURN 01"],[9,"TURN 09"],[10,"TURN 10"],[99,"TURN 99"],[100,"TURN 100"],[999,"TURN 999"],[1000,"TURN 1000"],[9223372036854775807,"TURN 9223372036854775807"],[0,"TURN --"],[-1,"TURN --"]]:
		_check(game._turn_label(pair[0])==pair[1],"minimum two digits and full turn value "+str(pair[0]))
	game.battle.turn=123
	game.queue_redraw()
	await create_timer(0.06).timeout
	var headings=game.drawn_text.filter(func(item):return item.text.begins_with("TURN "))
	_check(headings.size()==1 and headings[0].text=="TURN 123","actual counter is drawn once")
	if headings.size()==1:
		var item=headings[0]
		var height=game.mono.get_height(item.font_size)
		var width=game.mono.get_string_size("TURN 9223372036854775807",HORIZONTAL_ALIGNMENT_LEFT,-1,item.font_size).x
		_check(width<=game.T.PREVIEW_PANEL.size.x and item.position.y-height>game.T.BATTLE_HP_BASELINE+game.T.BATTLE_HP_STEP and item.position.y+height<game.T.TIMELINE_TOP-game.T.TIMELINE_NODE_RADIUS,"even maximum turn fits between HP and nodes")
	var factors=game.drawn_text.filter(func(item):return item.text.begins_with("I:") or item.text.begins_with("R:"))
	_check(factors.map(func(item):return item.text)==["I:200%","R:200%","I:200%","R:200%","I:200%","R:200%","I:200%","R:200%"],"current factors use compact labels")
	for i in range(0,factors.size(),2):
		var left=factors[i]
		var right=factors[i+1]
		var step=game.mono.get_string_size("I:000% ",HORIZONTAL_ALIGNMENT_LEFT,-1,game.T.TIMELINE_FACTOR_FONT).x+game.T.TIMELINE_FACTOR_EXTRA_GAP
		_check(absf(right.position.x-left.position.x-step)<0.001 and left.position.y==right.position.y,"fixed fields keep the configured gap after their separator")
	game.battle.turn=1
## REQ-019-S05、REQ-019-S07、REQ-019-S10
func _test_balance(game) -> void:
	var hp_bottom=T.BATTLE_HP_BASELINE+T.BATTLE_HP_STEP+game.mono.get_height(T.BATTLE_HP_FONT_SIZE)-game.mono.get_ascent(T.BATTLE_HP_FONT_SIZE)
	var heading_top=T.TIMELINE_TURN_CENTER.y-game.mono.get_ascent(T.TIMELINE_TURN_FONT)
	var before=heading_top-hp_bottom
	var orbit_radius=0.0
	for i in range(T.PREVIEW_RADII.size()):
		orbit_radius=maxf(orbit_radius,T.PREVIEW_RADII[i]+T.PREVIEW_AMPLITUDES[i])
	var preview_top=T.PREVIEW_CENTER.y-orbit_radius
	var first_factor=game.drawn_text.filter(func(item):return item.text.begins_with("I:"))[0]
	var factor_offset=first_factor.position.y-game._timeline_view().cards[0].center.y
	var state_bottom=T.TIMELINE_CARD_MAX+factor_offset+game.mono.get_height(T.TIMELINE_FACTOR_FONT)-game.mono.get_ascent(T.TIMELINE_FACTOR_FONT)
	var node_bottom=T.TIMELINE_BOTTOM+T.TIMELINE_NODE_RADIUS+T.TIMELINE_NODE_WIDTH/2
	var after=preview_top-maxf(state_bottom,node_bottom)
	_check(before>0 and after>0 and absf(before-after)<=game.mono.get_height(T.TIMELINE_TURN_FONT),"visible HP-to-TURN and timeline-to-preview gaps balance within one heading height: "+str([before,after]))
	var b=_battle()
	for times in [[100.0,100.0,100.0,100.0],[100.0,800.0,100.0,100.0],[800.0,100.0,100.0,800.0]]:
		for i in range(4):
			b.units[i].next_time=times[i]
		b.next_actor()
		var view=model.layout(b.units,b.actor,model.rows(b))
		for card in view.cards:
			_check(card.rect.position.y>T.TIMELINE_TURN_CENTER.y and card.rect.end.y<T.PREVIEW_PANEL.position.y,"state and full input area fit between TURN and preview for "+str(times))
			_check(not card.rect.intersects(Rect2(T.BATTLE_BOARD_ORIGIN,Vector2.ONE*10*T.BATTLE_CELL)),"shifted state input never overlaps map")
		for event in view.events:
			_check(model.hit(view,event.point)==event,"each shifted node remains individually clickable")
## REQ-019-S07、REQ-027-S01、REQ-027-S02
func _test_input() -> void:
	var game=load("res://tests/order_axis_audit.gd").new()
	game.settings_path="res://artifacts/runtime/time-axis-no-settings-"+str(Time.get_ticks_usec())+".json"
	root.add_child(game)
	await process_frame
	game._start_battle()
	await _test_readouts(game)
	_test_balance(game)
	_check(game.mono.get_string_size("11059.2/11059.2",HORIZONTAL_ALIGNMENT_LEFT,-1,T.TIMELINE_HP_FONT).x<=T.TIMELINE_CARD_SIZE.x,"maximum legal HP fits without reducing the state font")
	game._cell_input(Vector2i(4,4))
	game.selected=0
	await create_timer(0.08).timeout
	_check(not game.axis_centers.any(func(c):return Rect2(180,200,40,440).has_point(c.position)),"no unit names drawn on central timeline; TURN is checked by the text audit")
	var before=game.battle.units.duplicate(true)
	var path=game.battle.path.duplicate()
	var generation=game.preview_generation
	for dimensions in [Vector2i(1152,648),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(1200,1600)]:
		root.size=dimensions
		await process_frame
		var view=game._timeline_view()
		var point=view.cards[2].center
		var motion=InputEventMouseMotion.new()
		motion.position=point
		game._input(motion)
		_check(game.timeline_hover==2 and game.selected==0,"hover highlights without selecting at "+str(dimensions))
		var event=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=true
		event.position=root.get_final_transform()*point
		root.push_input(event,false)
		await process_frame
		_check(game.selected==2 and game.battle.actor==0 and game.battle.units==before and game.battle.path==path,"scaled state click is inspection only at "+str(dimensions))
		_check(game.preview_generation==generation,"inspection never changes cached acting preview")
		game.selected=0
	var view=game._timeline_view()
	var future=view.events.filter(func(e):return e.repeated)[0]
	var click_future=InputEventMouseButton.new()
	click_future.button_index=MOUSE_BUTTON_LEFT
	click_future.pressed=true
	click_future.position=future.point
	game._unhandled_input(click_future)
	_check(game.timeline_selected_event.time==future.time and game.battle.path==path,"selecting recurrence keeps its exact occurrence and route")
	game.clock+=999.0
	_check(game._timeline_view().now==view.now and game._timeline_view().events==view.events,"thinking time never advances game wait")
	game._cell_input(Vector2i(4,4))
	_check(game.timeline_selected_event.is_empty(),"board interaction clears occurrence inspection without stale numbers")
	game.selected=0
	game._window_focus_exited()
	_check(game.timeline_hover==-1 and game.battle.path==path,"focus loss clears hover, retains route")
	game._window_focus_entered()
	var motion=InputEventMouseMotion.new()
	motion.position=game._timeline_view().cards[2].center
	game._input(motion)
	motion.position=Vector2(1260,1045)
	game._input(motion)
	_check(game.timeline_hover==-1,"GUI-consumed pointer motion clears timeline hover")
	motion.position=game._timeline_view().cards[2].center
	game._input(motion)
	root.mouse_exited.emit()
	_check(game.timeline_hover==-1 and game.battle.path==path,"window exit clears hover without changing route")
	game._help()
	await process_frame
	var guide=game.auxiliary.find_children("*","Label",true,false).filter(func(label):return label.text.contains("白は相対進捗"))
	_check(guide.size()==1 and guide[0].text.contains("表示最大の待ち量で再計算") and guide[0].text.contains("個別周期ではない"),"HELP defines relative progress and changing maximum")
	if guide.size()==1:
		_check(Array(guide[0].text.split("\n")).all(func(line):return game.font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x<=guide[0].size.x),"progress explanation stays within HELP column")
	var click=InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=true
	click.position=game._timeline_view().cards[2].center
	game._unhandled_input(click)
	_check(game.selected==0 and game.timeline_hover==-1,"modal blocks underlying timeline")
	game._close_aux()
	game._cell_input(Vector2i(5,4))
	game._cell_input(Vector2i(5,4),true)
	await process_frame
	game.battle.choose_skill(game.C.DAMAGE)
	game._clear_overlay()
	game._hud()
	before=game.battle.units.duplicate(true)
	game._unhandled_input(click)
	_check(game.selected==2 and game.battle.mode=="TARGET" and game.battle.units==before,"timeline inspection never fires selected skill")
	game.queue_free()
	await process_frame
	root.size=Vector2i(1920,1080)
func _check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
