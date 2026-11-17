extends "res://tests/unit_information_capture.gd"
## REQ-019-S01、REQ-019-S07、REQ-019-S09、REQ-019-S10、REQ-033-S01、REQ-033-S02
func _run() -> void:
	var policy=_mutual(1.1,160,true,128)
	game=load("res://tests/side_info_audit.gd").new()
	game.battle=RUNTIME_B.new()
	game.settings_path="res://artifacts/runtime/aligned-preview-no-settings-"+stamp+".json"
	root.add_child(game)
	root.size=Vector2i(1920,1080)
	root.grab_focus()
	await process_frame
	await create_timer(0.2).timeout
	game.panel_seed_override=128
	game._start_battle()
	await process_frame
	for attempt in range(60):
		if root.has_focus() and game.window_focused:
			break
		root.grab_focus()
		await create_timer(0.02).timeout
	for command in policy.commands.slice(0,17):
		_check(game.battle.units[game.battle.actor].id==command.unit,"aligned scene replay actor "+command.unit)
		for pair in command.path:
			_click_cell(Vector2i(pair[0],pair[1]))
		if not command.path.is_empty():
			var last=command.path[-1]
			_click_cell(Vector2i(last[0],last[1]),true)
			await process_frame
		if command.skill=="":
			_click_button(game.hud if command.path.is_empty() else game.overlay,"WAIT")
		else:
			_click_button(game.overlay,game.C.SKILLS[command.skill].label)
			await process_frame
			_click_cell(game.battle.units[command.target].pos)
		await process_frame
		_check(game.battle.result.is_empty(),"all 17 actual actions precede battle end")
	_check(game.battle.history==policy.history.slice(0,game.battle.history.size()),"actual GUI history matches model replay")
	_check(game.battle.turn==18 and game.battle.actor==0 and game.battle.units.map(func(unit):return unit.hp)==[80.0,29.0,60.0,42.0],"TURN18 is a progressed four-survivor battle")
	var current=game.battle.units.duplicate(true)
	var history=game.battle.history.duplicate()
	var path=[Vector2i(4,7),Vector2i(5,7),Vector2i(6,7)]
	for cell in path:
		_click_cell(cell)
		await process_frame
	_check(game.battle.path==path and game.battle.units==current and game.battle.history==history,"three real legal clicks create an uncommitted prediction without changing state")
	var preview=game.battle.preview()
	_check([preview.core_angle,preview.gear_angle,preview.arms_angle]==[0.0,0.0,0.0] and game.M.sync(preview,1).raw==1.0 and game.M.sync(preview,1).factor==2.0,"actual route preview completely aligns INF with 200 percent final factor")
	var card=game._timeline_view().cards[0]
	_click(root.get_final_transform()*card.center)
	await process_frame
	_check(game.selected==0 and game.battle.path==path,"current unit inspection keeps aligned preview")
	await _capture("inf-aligned-turn18")
	var red_samples=0
	for color in game.preview_contours[3].colors:
		if color.r>color.g*1.5 and color.r>color.b*1.2 and color.a>0.7:
			red_samples+=1
	_check(red_samples>0,"result contour contains clear actual INF red samples")
	var report={"seed":128,"turn":game.battle.turn,"actor":game.battle.units[game.battle.actor].id,"selected":game.selected,"path":path,"hp":game.battle.units.map(func(unit):return unit.hp),"actual_angles":current.map(func(unit):return [unit.core_angle,unit.gear_angle,unit.arms_angle]),"preview_angles":[preview.core_angle,preview.gear_angle,preview.arms_angle],"inf_sectors":[game.M.sector(preview,0,1),game.M.sector(preview,1,1),game.M.sector(preview,2,1)],"inf_sync":game.M.sync(preview,1),"red_result_samples":red_samples,"history":history}
	var file=FileAccess.open("res://artifacts/runtime/aligned-preview-state-"+stamp+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("ALIGNED PREVIEW STATE ",JSON.stringify(report))
	game._restart()
	await process_frame
	_check(game.build_open,"aligned capture returns BUILD without saving")
	print("ALIGNED PREVIEW GPU: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
