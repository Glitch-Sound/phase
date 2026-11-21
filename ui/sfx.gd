## 成立した手動選択と、確定表示の回転と実HP変化だけを短く鳴らす。
extends Node
const T=preload("res://game/tuning.gd")
const SOURCES={
	"select":preload("res://assets/sfx/select.ogg"),
	"ring_rotate":preload("res://assets/sfx/ring_rotate.ogg"),
	"attack":preload("res://assets/sfx/attack.ogg"),
	"heal":preload("res://assets/sfx/heal.ogg")
}
signal played(kind: String)
class SelectionButton:
	extends Button
	var audio: Node
	func _pressed() -> void:
		if is_instance_valid(audio):audio.selection(not disabled and not is_queued_for_deletion())
var enabled=true
var streams: Dictionary={}
var players: Dictionary={}
var _input_ticket=0
var _manual=false
var _used=false
var _movement_context: Array=[]
var _completed_steps=0
var _effect_context: Array=[]

func _ready() -> void:
	for key in SOURCES:
		var stream=SOURCES[key].duplicate();stream.loop=false;streams[key]=stream
	for lane in ["select","ring_rotate","effect"]:
		var player=AudioStreamPlayer.new();player.name="SFX_"+lane;player.bus="Master";player.max_polyphony=1;add_child(player);players[lane]=player

func _input(event: InputEvent) -> void:
	input_event(event)

func _exit_tree() -> void:
	for player in players.values():player.stop();player.stream=null
	players.clear();streams.clear();_movement_context=[];_effect_context=[]

## 手動入力の配送を記録する。eventは通常またはポップアップの入力。戻り値なし。発音せず、現在の配送だけを有効にする。
func input_event(event: InputEvent) -> void:
	_input_ticket+=1;_used=false
	_manual=event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT
	if event is InputEventKey:
		_manual=not event.echo and event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_HOME,KEY_END,KEY_PAGEUP,KEY_PAGEDOWN]
	_finish_input.call_deferred(_input_ticket)

func _finish_input(ticket: int) -> void:
	if ticket==_input_ticket:_manual=false

## 成立した選択を知らせる。acceptedは選択の成否。戻り値なし。手動入力中の成功だけに1音を再生する。
func selection(accepted: bool=true) -> void:
	if accepted and _manual and not _used:
		_used=true;_play("select")

## 選択メニューの入力元を接続する。optionはポップアップを持つ選択部品。戻り値なし。自動選択や開閉だけでは発音しない。
func watch_option(option: OptionButton) -> void:
	option.get_popup().window_input.connect(input_event)

## 実移動の歩を観測する。motionは既存の確定移動表示。戻り値なし。回転した歩ごとに1音を出し、表示時間とモデルは変更しない。
func movement_tick(motion: RefCounted) -> void:
	if motion.owner==null or motion.route.is_empty():return
	var context=[motion,motion.owner,motion.turn,motion.actor,motion.route]
	if context!=_movement_context:
		_movement_context=context.duplicate();_completed_steps=0
	if motion.duration<=0:
		_completed_steps=motion.route.size();return
	var completed=clampi(floori(motion.elapsed/motion.duration*motion.route.size()+0.00000001),0,motion.route.size())
	for index in range(_completed_steps,completed):
		if motion.deltas[index].any(func(value):return is_finite(value) and absf(value)>0.00000001):_play("ring_rotate")
	_completed_steps=maxi(_completed_steps,completed)

## 実効果の音を出す。ownerは戦闘、historyは確定履歴番号、kindは作用、actualは実HP変化量。戻り値なし。同じ結果と実変化ゼロを重複再生しない。
func effect(owner: RefCounted,history: int,kind: String,actual: float) -> void:
	if kind not in ["DAMAGE","HEAL"]:return
	var context=[owner,history]
	if context==_effect_context:return
	_effect_context=context
	if is_finite(actual) and actual>0:_play("attack" if kind=="DAMAGE" else "heal")

## 戦闘音の尾だけを止める。戻り値なし。入力の短い音と完了済みの歩と効果の記録は保持し、再開で再発音しない。
func suspend() -> void:
	for lane in ["ring_rotate","effect"]:
		if players.has(lane):players[lane].stop()

## 戦闘の音を破棄する。戻り値なし。再戦に古い音と重複判定を持ち越さず、保存を変更しない。
func reset_battle() -> void:
	suspend();_movement_context=[];_completed_steps=0;_effect_context=[]

func _play(kind: String) -> void:
	var lane="effect" if kind in ["attack","heal"] else kind
	if not enabled or not is_inside_tree() or not streams.has(kind) or not players.has(lane):return
	var player: AudioStreamPlayer=players[lane]
	player.stop();player.stream=streams[kind];player.volume_db=T.SFX_VOLUME_DB[kind]
	# Dummyは無出力。高速終了時の非同期音声の参照残りを避け、動画の音声出力は維持する。
	if AudioServer.get_driver_name()!="Dummy" or not Engine.get_write_movie_path().is_empty():player.play()
	played.emit(kind)
