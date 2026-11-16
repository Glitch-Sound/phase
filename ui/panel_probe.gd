## 盤面のホバー説明だけを提供し、既存の盤面入力へ接続し、フォーカスを取得しない。
extends Control
var host: Control
func _get_tooltip(at_position: Vector2) -> String:
	if not is_instance_valid(host) or host.build_open or not host.window_focused or is_instance_valid(host.overlay) or is_instance_valid(host.auxiliary):
		return ""
	var cell=Vector2i(floori(at_position.x/host.CELL),floori(at_position.y/host.CELL))
	return host.panel_description(cell)

func _gui_input(event: InputEvent) -> void:
	if not is_instance_valid(host) or not (event is InputEventMouseButton or event is InputEventMouseMotion):
		return
	# GodotがGUIの局所座標へ変換済みなので、親の論理座標へ戻して既存入力へ一度だけ渡す。
	var forwarded=event.duplicate()
	forwarded.position=position+event.position
	forwarded.global_position=forwarded.position
	host._unhandled_input(forwarded)
	accept_event()
