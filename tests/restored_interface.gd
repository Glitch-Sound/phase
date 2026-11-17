extends SceneTree
var checks=0
var failures=0
func _initialize() -> void:
	_run.call_deferred()
## REQ-019-S01、REQ-020-S01、NREQ-001-S01、NREQ-002-S01
func _run() -> void:
	var game=load("res://tests/fixture_main.gd").new()
	game.settings_path="res://artifacts/runtime/restore-test-no-settings.json"
	root.add_child(game)
	await process_frame
	_check(game.P.BG==Color("040506"),"restore original dark background")
	_check(game.P.SURFACE==Color("090b0e"),"restore original surfaces")
	_check(game.P.TEXT==Color("e8ebed"),"restore original readable text")
	_check(game.overlay.find_children("*","OptionButton",true,false).size()==9,"BUILD exposes all original selectors")
	_check(game.core_controls.size()==5,"BUILD exposes all five core values")
	game._help()
	await process_frame
	var guides=[]
	for label in game.auxiliary.find_children("*","Label",true,false):
		if label.text.contains("SAVE / LOADは"):
			guides.append(label.text)
	_check(guides==["−はダメージ、＋は回復。\nINFは攻撃と回復、RESは抵抗。\nSAVE / LOADは明示操作。以前の保存は退避する。"],"keep corrected INF and RES explanation")
	game._close_aux()
	game._start_battle()
	game._cell_input(Vector2i(4,4))
	game._cell_input(Vector2i(5,4))
	game._cell_input(Vector2i(5,4),true)
	await process_frame
	_check(game.overlay.get_child(1).position==Vector2(700,330),"restore centered ACTION")
	_check(game.overlay.get_child(1).size.x==420,"restore original ACTION width")
	_check(game.overlay.get_child(0).color.a==0,"keep readable context behind ACTION")
	var names=[]
	for button in game.overlay.find_children("*","Button",true,false):
		names.append(button.text)
	_check(names==["WAIT","DAMAGE / ADJACENT","HEAL / ADJACENT","BACK"],"original actions plus the authorized movement BACK")
	# 効果量の式はモデルで検査し、この層は実行とHP更新の接続を確かめる。
	var expected_hp=game.battle.units[2].hp-game.M.effect(game.battle.units[0],game.battle.units[2],"DAMAGE")
	game.battle.choose_skill(game.C.DAMAGE)
	game._clear_overlay()
	game._cell_input(Vector2i(6,4))
	_check(game.battle.actor==1 and game.battle.units[2].hp==expected_hp,"real attack applies the current exact model effect once and reaches comparison state")
	game._cell_input(Vector2i(4,6))
	game._cell_input(Vector2i(5,6))
	_check(game.battle.path==[Vector2i(4,6),Vector2i(5,6)] and game.battle.preview().id=="02","restore comparison route without changing actor")
	print("RESTORED INTERFACE: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
