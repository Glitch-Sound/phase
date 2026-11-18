extends SceneTree
var checks=0
var failures=0
func _initialize() -> void:
	_run.call_deferred()
## REQ-018-S03
func _run() -> void:
	var game=load("res://tests/panel_audit.gd").new()
	game.settings_path="res://artifacts/runtime/panel-ui-lab-"+str(Time.get_ticks_usec())+".json"
	root.add_child(game)
	await process_frame
	game.panel_seed_override=128
	game._start_battle()
	await create_timer(0.08).timeout
	_check(not game.drawn_text.any(func(t):return t.text in ["S+","L=","R-"]),"panel abbreviations are removed")
	_check(game.has_method("panel_description"),"panel explanation is available on demand")
	await _test_icons(game)
	await _test_focus(game)
	await _test_seed(game)
	await _test_input(game)
	game.queue_free()
	await process_frame
	print("PANEL INTERFACE: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
## REQ-018-S03、NREQ-002-S02
func _test_icons(game) -> void:
	_check(FileAccess.get_file_as_string("res://assets/lucide/diamond.svg").contains('fill="none"'),"RESET diamond returns to its unfilled outline")
	var paths={"CLOCKWISE":"rotate-cw.svg","RESET":"diamond.svg","COUNTERCLOCKWISE":"rotate-ccw.svg"}
	var meanings={"CLOCKWISE":"CORE CLOCKWISE\nCORE +SPD x 1.5 deg. Equipment turns normally.","RESET":"CORE RESET\nRestore the battle-start CORE angle. Equipment still turns.","COUNTERCLOCKWISE":"CORE COUNTERCLOCKWISE\nCORE -SPD x 1.5 deg. Equipment turns normally."}
	_check(game.drawn_icons.size()==game.battle.panels.size(),"exactly one icon per effect cell")
	var current_kinds=game.battle.panels.values().all(func(kind):return paths.has(kind))
	_check(current_kinds,"only the three CORE effect kinds exist")
	if not current_kinds:
		return
	var observed={}
	for icon in game.drawn_icons:
		var cell=Vector2i((icon.rect.position-game.BOARD)/game.CELL)
		observed[cell]=icon.kind
		_check(icon.texture.ends_with(paths[game.battle.panels[cell]]) and icon.kind==game.battle.panels[cell],"glyph matches actual cell effect "+str(cell))
		_check(icon.rect==Rect2(game.BOARD+Vector2(cell)*game.CELL+game.T.PANEL_ICON_OFFSET,Vector2.ONE*game.T.PANEL_ICON_SIZE),"icon uses configured corner size "+str(cell))
		_check(game.panel_description(cell)==meanings[icon.kind],"correct targeted ring meaning "+icon.kind)
		var point=Vector2(cell)*game.CELL+Vector2.ONE*game.CELL/2
		_check(game.panel_probe._get_tooltip(point)=="","native tooltip stays suppressed so panel focus remains visible "+icon.kind)
	_check(observed==game.battle.panels and observed.size()==game.drawn_icons.size(),"complete cell-to-effect set, with no duplicate or normal-cell icon")
	var colors={"CLOCKWISE":game.CYAN,"RESET":game.status_colors[3],"COUNTERCLOCKWISE":game.MAGENTA}
	_check(game.drawn_icons.all(func(icon):return icon.color==colors[icon.kind]),"all glyphs retain configured role colors")
	_check(game.panel_description(Vector2i(-1,-1))=="" and game.panel_description(game.battle.units[0].pos)=="","no invented effect on outside or normal cell")
	_check(game.panel_probe.mouse_filter==Control.MOUSE_FILTER_PASS and game.panel_probe.focus_mode==Control.FOCUS_NONE,"hover probe has no focus and forwards board input")
	var before=game.battle.path.duplicate()
	game._help()
	await process_frame
	var labels=game.auxiliary.find_children("*","Label",true,false)
	_check(["CORE ↷","CORE RESET","CORE ↶"].all(func(s):return labels.any(func(l):return l.text==s)),"HELP maps all three icon meanings")
	_check(labels.any(func(l):return l.text=="%s / SEED 128" % game.battle.stage.name),"HELP discloses exact seed")
	var legend_icons=game.auxiliary.find_children("*","TextureRect",true,false).map(func(icon):return icon.texture.resource_path.get_file()).filter(func(name):return name in ["diamond.svg","undo-2.svg","rotate-cw.svg","rotate-ccw.svg"])
	legend_icons.sort()
	_check(legend_icons==["diamond.svg","rotate-ccw.svg","rotate-cw.svg"],"HELP uses exactly the same three distinct panel glyphs")
	_check(game.panel_probe._get_tooltip(Vector2(450,450))=="" and game.battle.path==before,"modal suppresses tooltip without changing route")
	game._close_aux()
	var notice=FileAccess.get_file_as_string("res://assets/lucide/NOTICE.md")
	_check(notice.contains("diamond") and notice.contains("rotate-cw") and FileAccess.get_file_as_string("res://assets/lucide/LICENSE").contains("ISC License"),"bundled icon sources and licenses retained")
## REQ-018-S04
func _test_focus(game) -> void:
	game.panel_seed_override=128
	game._start_battle()
	for cell in [Vector2i(0,0),Vector2i(9,0),Vector2i(0,9),Vector2i(9,9),Vector2i(4,4)]:
		game.battle.units[0].pos=cell
		game.battle.panels[cell]="RESET"
		game.selected=0
		game.timeline_hover=-1
		game.battle.path=[]
		game.queue_redraw()
		await create_timer(0.04).timeout
		var expected=Rect2(game.BOARD+Vector2(cell)*game.CELL+Vector2.ONE*game.T.CELL_BORDER_INSET*game.BOARD_SCALE,Vector2.ONE*(game.CELL-2*game.T.CELL_BORDER_INSET*game.BOARD_SCALE))
		_check(game.drawn_brackets==[{"rect":expected,"color":game.MAGENTA}],"exact unit focus lies on its own cell border "+str(cell))
		game.selected=-1
		game.battle.path=[cell]
		game.queue_redraw()
		await create_timer(0.04).timeout
		_check(game.drawn_brackets==[{"rect":expected,"color":game.CYAN}],"exact endpoint focus lies on cell border "+str(cell))
	game._start_battle()
	game.battle.units[0].pos=Vector2i(4,4)
	game.battle.units[3].pos=Vector2i(5,4)
	game.battle.mode="TARGET"
	game.battle.selected_skill=game.C.DAMAGE
	game.selected=-1
	game.queue_redraw()
	await create_timer(0.04).timeout
	var origin=game.BOARD+Vector2(4,4)*game.CELL
	var expected=[]
	# 行の順番を含む全体集合。隣接4マスと有効対象の追加強調だけである。
	for cell in [Vector2i(4,3),Vector2i(3,4),Vector2i(5,4),Vector2i(5,4),Vector2i(4,5)]:
		expected.append(Rect2(game.BOARD+Vector2(cell)*game.CELL+Vector2.ONE*game.T.CELL_BORDER_INSET*game.BOARD_SCALE,Vector2.ONE*(game.CELL-2*game.T.CELL_BORDER_INSET*game.BOARD_SCALE)))
	_check(game.full_focus.map(func(item):return item.rect)==expected,"all target outlines use the cell border with no inset duplicates")
## REQ-034-S06
func _test_seed(game) -> void:
	game.panel_seed_override=null
	game.panel_rng.seed=734
	var state=game.panel_rng.state
	game._build()
	await process_frame
	game._refresh_build()
	_check(game.panel_rng.state==state,"editing BUILD does not consume map RNG")
	var loot_state=game.loot_rng.state
	game._start_battle()
	var first=game.battle.panel_seed
	var panels=game.battle.panels.duplicate(true)
	game._start_battle()
	_check(game.battle.panel_seed!=first and game.battle.panels!=panels,"next actual START uses a different seed and layout")
	_check(game.loot_rng.state==loot_state,"starting maps never consumes reward RNG")
## REQ-018-S03
func _test_input(game) -> void:
	game.panel_seed_override=128
	for dimensions in [Vector2i(1152,648),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(1200,1600)]:
		root.size=dimensions
		await process_frame
		game._start_battle()
		await process_frame
		var cell=Vector2i(4,4)
		var point=root.get_final_transform()*(game.BOARD+(Vector2(cell)+Vector2.ONE/2)*game.CELL)
		var before=game.battle.panels.duplicate(true)
		for pressed in [true,false]:
			var event=InputEventMouseButton.new()
			event.position=point
			event.global_position=point
			event.button_index=MOUSE_BUTTON_LEFT
			event.pressed=pressed
			root.push_input(event,false)
		await process_frame
		_check(game.battle.path==[cell] and game.battle.panels==before,"tooltip overlay passes scaled board clicks "+str(dimensions))
	game._restart()
	await process_frame
	_check(game.build_open and game.panel_probe._get_tooltip(Vector2(450,450))=="","BUILD hides effect hover")

func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
