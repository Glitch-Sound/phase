extends "res://tests/aligned_preview_capture.gd"
## REQ-014-S02、REQ-019-S12、NREQ-002-S01、NREQ-002-S03、NREQ-002-S06
func _capture(suffix: String) -> void:
	await super._capture(suffix)
	await _shot("battle")
	var actual=game.battle
	var state=game.collection.snapshot().duplicate(true)
	var palette=game.palette_colors.duplicate()
	# 実再生した状態を複製し、添付する行動選択でも同じ進行場面を使う。
	game.battle=actual.get_script().new()
	for property in actual.get_property_list():
		if property.usage&PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value=actual.get(property.name)
			game.battle.set(property.name,value.duplicate(true) if value is Array or value is Dictionary else value)
	# 同じ実戦の経路を2歩へ戻し、隣接する敵への攻撃も選べる状態で確認する。
	_click_cell(Vector2i(5,7))
	await process_frame
	_click_cell(Vector2i(5,7),true)
	await process_frame
	_check(game.battle.mode=="CHOICE" and game.battle.valid_target(game.battle.actor,3,game.C.DAMAGE),"progressed dialog exposes a real available attack")
	await _shot("action")
	for dimensions in [Vector2i(1152,648),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(1200,1600)]:
		root.size=dimensions
		await process_frame
		_key(KEY_TAB)
		await process_frame
		var focus=root.gui_get_focus_owner()
		_check(is_instance_valid(focus) and game.overlay.is_ancestor_of(focus),"scaled action keeps keyboard focus "+str(dimensions))
		await _shot("action-"+str(dimensions.x))
	root.size=Vector2i(1920,1080)
	await process_frame
	game.result_awarded=true
	game.battle.mode="RESULT"
	game.battle.result="VICTORY"
	game.drops=[{"kind":"ARMS","stats":[25,15,20,30,10],"mutation":"LSRIV","new_item":true,"new_mutation":true},{"skill":game.C.MOVE}]
	game._result()
	await _shot("result")
	game.battle.result="DEFEAT"
	game.drops=[]
	game._result()
	await _shot("defeat-empty")
	game._build()
	await _shot("build")
	for i in range(game.C.stages().size()):
		game.collection.stage_index=i
		game._build()
		await _shot("build-stage-"+str(i))
	game.collection.stage_index=0
	game._build()
	game._help()
	await _shot("help")
	game._close_aux()
	game._settings()
	await _shot("settings")
	game._close_aux()
	game.collection.mutations=["NORMAL","IVRSL","LSRIV"]
	game.collection.skills=game.C.SKILLS.keys()
	game.collection.builds[0].class_name="REVERSE"
	game.collection.builds[0].arms=[96,1,1,1,1]
	game.collection.items.ARMS[game.C.serial("ARMS",[96,1,1,1,1])]=[96,1,1,1,1]
	game.collection.builds[0].arms_mutation="LSRIV"
	game.collection.builds[0].gear_mutation="IVRSL"
	game.collection.builds[0].skills=[game.C.DAMAGE,game.C.HEAL,game.C.MOVE]
	game._build()
	game.equipment_views.arms.set_meta("before",[1,96,1,1,1])
	for dimensions in [Vector2i(1152,648),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(1200,1600)]:
		root.size=dimensions
		await process_frame
		await _shot("build-long-"+str(dimensions.x))
		var buttons=game.overlay.find_children("*","Button",true,false).filter(func(b):return b.text=="SLOT 2")
		_click(root.get_final_transform()*buttons[0].get_global_rect().get_center())
		await process_frame
		_check(game.edit_unit==1,"scaled unit switch "+str(dimensions))
		var first=game.overlay.find_children("*","Button",true,false).filter(func(b):return b.text=="SLOT 1")[0]
		_click(root.get_final_transform()*first.get_global_rect().get_center())
		await process_frame
		_check(game.edit_unit==0,"scaled switch returns "+str(dimensions))
		var options=game.overlay.get_child(1).find_children("*","OptionButton",true,false)
		_click(root.get_final_transform()*options[1].get_global_rect().get_center())
		await process_frame
		_check(options[1].get_popup().visible,"equipment popup opens at scale "+str(dimensions))
		await _shot("popup-"+str(dimensions.x))
		_key(KEY_ESCAPE)
		await process_frame
	root.size=Vector2i(1920,1080)
	game.palette_colors=game.P.PRESETS.AMBER.duplicate()
	game._set_theme()
	game._build()
	await _shot("build-AMBER")
	# 初期の実戦と共有一覧を復元し、親の実戦報告とBUILD復帰へ渡す。
	game.collection.builds=state.builds.duplicate(true)
	game.collection.items=state.items.duplicate(true)
	game.collection.skills=state.skills.duplicate()
	game.collection.mutations=state.mutations.duplicate()
	game.collection.stage_index=state.stage_index
	game.palette_colors=palette
	game._set_theme()
	game.battle=actual
	game.edit_unit=0
	game.build_open=false
	game._clear_overlay()
	game._hud()
	await process_frame
func _shot(tag: String) -> void:
	_move(root.get_final_transform()*Vector2(1900,1000))
	game.queue_redraw()
	await create_timer(0.08).timeout
	await RenderingServer.frame_post_draw
	var layer=game.auxiliary if is_instance_valid(game.auxiliary) else game.overlay
	if is_instance_valid(layer):
		var panel=layer.get_child(1)
		var controls=panel.find_children("*","Control",true,false).filter(func(c):return c is BaseButton or c is SpinBox or c is Label)
		for control in controls:
			if not control.is_visible_in_tree() or control.get_parent() is SpinBox:
				continue
			_check(panel.get_global_rect().grow(1).encloses(control.get_global_rect()),"content within modal "+tag+" / "+str(control.name))
			if control is OptionButton:
				var text=control.get_item_text(control.selected)
				_check(control.get_theme_font("font").get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,control.get_theme_font_size("font_size")).x<control.size.x-36,"complete option text fits "+tag+" / "+text)
	var path="res://artifacts/runtime/PHASE-hierarchy-"+stamp+"-"+tag+".png"
	_check(not FileAccess.file_exists(path) and root.get_texture().get_image().save_png(path)==OK,"real hierarchy frame "+tag)
	print("HIERARCHY FRAME ",ProjectSettings.globalize_path(path))
func _key(code: Key) -> void:
	for down in [true,false]:
		var event=InputEventKey.new()
		event.keycode=code
		event.pressed=down
		root.push_input(event,false)
