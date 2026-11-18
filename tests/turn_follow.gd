extends SceneTree
var game
var checks=0
var failures=0
func _initialize()->void:
	_run.call_deferred()
## REQ-019-S01、REQ-019-S07、REQ-019-S13、REQ-018-S05
func _run()->void:
	game=load("res://tests/side_info_audit.gd").new()
	game.battle=game.B.new()
	game.settings_path="res://artifacts/runtime/turn-follow-no-settings.json"
	game.save_path="res://artifacts/runtime/turn-follow-no-save.json"
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.panel_seed_override=1
	game._start_battle()
	game._process(0)
	game.selected=2
	game.timeline_hover=3
	game.timeline_hover_event={"index":3,"time":200.0}
	game.timeline_selected_event={"index":2,"time":200.0}
	game.hover_cell=Vector2i(9,9)
	game._process(0.1)
	_check(game.selected==2 and game.timeline_hover==3,"same turn preserves explicit inspection and hover")
	game.battle.actor=1
	game.battle.turn+=1
	game._process(0)
	_check(game.selected==-1 and game.timeline_hover==-1 and game.timeline_hover_event.is_empty() and game.timeline_selected_event.is_empty() and game.hover_cell==Vector2i(-1,-1),"new actual turn clears every stale inspection exactly once")
	game.queue_redraw()
	await process_frame
	await process_frame
	_check(not game.info_rings.is_empty() and game.info_rings[0].unit.id=="02","actual INFORMATION draw follows new actor")
	_check(not game.preview_rings.is_empty() and game.preview_rings[0].unit.id=="02","actual PREVIEW draw follows same new actor")
	game.selected=0
	game.battle.path=[Vector2i(4,6)]
	var before=game.battle.preview().duplicate(true)
	game._process(0.1)
	_check(game.selected==0 and game.battle.path==[Vector2i(4,6)] and game.battle.preview()==before,"inspection is not overwritten within the turn and never changes route prediction")
	game._cell_input(Vector2i(4,7))
	_check(game.selected==-1 and game.battle.path==[Vector2i(4,6),Vector2i(4,7)],"editing a route returns INFORMATION to its actor")
	game.selected=2
	game.battle.turn+=1
	game._process(0)
	_check(game.selected==-1,"same actor in a new turn still follows once")
	game.cpu_enabled=true
	game.battle.path=[]
	game.battle.actor=3
	game.battle.turn+=1
	game._process(0)
	game.selected=0
	game.cpu_turn.phase="RESULT"
	game.battle.actor=4
	game.battle.turn+=1
	game._process(0)
	_check(game.cpu_turn.active and game.cpu_turn.actor==3 and game.selected==-1,"CPU result hold follows real next actor despite old presentation owner")
	game._cell_input(game.battle.units[1].pos)
	game.cpu_paused=true
	var snapshot=[game.battle.turn,game.battle.actor,game.battle.units.duplicate(true)]
	game._process(5)
	_check(game.selected==1 and snapshot==[game.battle.turn,game.battle.actor,game.battle.units],"paused CPU permits inspection without forcing selection or progressing")
	game._restart()
	game._start_battle()
	game._process(0)
	_check(game.selected==-1 and game.battle.actor==0,"restart discards old observation key and selection")
	game.cpu_enabled=false
	game.battle.turn+=1
	game._cell_input(game.battle.units[2].pos)
	game._process(0)
	_check(game.selected==2,"inspection on the first input frame follows the boundary before accepting a new selection")
	game._restart()
	_check(game.build_open,"follow verification ends BUILD without saving")
	print("TURN FOLLOW: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
func _check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
