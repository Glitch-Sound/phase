extends SceneTree
const B=preload("res://game/battle.gd")
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
		_test_current()
		_test_lifecycle()
		await _test_input()
	else:
		_check(false,"relative-time view model is implemented")
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
		_check(absf(e.point.y-(T.TIMELINE_TOP+expected[i]/150.0*(T.TIMELINE_BOTTOM-T.TIMELINE_TOP)))<0.0001,"linear unshifted position "+str(i))
	_check(view.events[0].point==view.events[1].point and view.events[2].point.y>view.events[1].point.y,"equal shared point, near distinct point")
	_check(view.groups[0].events.map(func(e):return e.index)==[0,1,2],"near group preserves actual order")
	_check(view.events[3].repeated and view.events[5].repeated,"future repeats have their own IDs")
	_check(model.caption(view.events[0],0)=="1  0 / ACTING" and model.caption(view.events[1],0)=="2  0 / QUEUED","zero acting and queued are different")
	_check(model.caption(view.events[2],0)=="A  +0.01","small relative wait is exact and compact")
	_check(b.units==before and rows[0]=={"index":0,"time":100.0},"layout is pure")
	for i in range(4):
		b.units[i].next_time=100.0
	b.next_actor()
	view=model.layout(b.units,b.actor,b.timeline(6))
	_check(view.events.slice(0,4).map(func(e):return e.index)==[0,1,2,3],"same time processing order is 1 2 A B")
	_check(view.groups[0].labels.map(func(l):return l.event.index)==[0,1,2,3],"group labels expose equal-time order")
	for label in view.groups[0].labels:
		_check(model.hit(view,label.rect.get_center()).index==label.event.index,"each grouped ID has distinct input")
	b.units[3].next_time=2000.0
	view=model.layout(b.units,0,b.timeline(6))
	_check(view.events.size()==7 and view.events[-1].index==3 and view.events[-1].extra and view.events[-1].rank==-1,"slow missing unit gets truthful NEXT marker, not fake rank")
	_check(view.events[-1].point.y==T.TIMELINE_BOTTOM,"slow unit extends shared range")
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
	_check(view.events.is_empty() and view.groups.is_empty() and view.cards.all(func(c):return c.event.is_empty()),"result contains no hypothetical future")
## REQ-019-S07、REQ-027-S01、REQ-027-S02
func _test_input() -> void:
	var game=load("res://tests/phase_preview_audit.gd").new()
	game.settings_path="res://artifacts/runtime/time-axis-no-settings-"+str(Time.get_ticks_usec())+".json"
	root.add_child(game)
	await process_frame
	game._start_battle()
	_check(game.mono.get_string_size("11059.2/11059.2",HORIZONTAL_ALIGNMENT_LEFT,-1,T.TIMELINE_HP_FONT).x<=T.TIMELINE_CARD_SIZE.x,"maximum legal HP fits without reducing the state font")
	game._cell_input(Vector2i(4,4))
	game.selected=0
	await create_timer(0.08).timeout
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
