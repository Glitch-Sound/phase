## 実ボタンの生成音と確定移動、実HP変化、撃破の余韻を扱う。
extends Node
const T=preload("res://game/tuning.gd")
const SOURCES={
	"ring_rotate1":preload("res://assets/sfx/ring_rotate1.ogg"),
	"ring_rotate2":preload("res://assets/sfx/ring_rotate2.ogg"),
	"attack":preload("res://assets/sfx/attack.ogg"),
	"heal":preload("res://assets/sfx/heal.ogg"),
	"defeated":preload("res://assets/sfx/defeated.ogg")
}
signal played(kind: String)
var enabled=true
var streams: Dictionary={}
var players: Dictionary={}
var _movement_context: Array=[]
var _completed_pulses=0
var _effect_context: Array=[]
var defeat_voices: Array[AudioStreamPlayer]=[]
var _defeats: Array=[]
var _defeat_contexts: Array=[]
var _button_root: WeakRef

func _ready() -> void:
	for key in SOURCES:
		var stream=SOURCES[key].duplicate();stream.loop=false;streams[key]=stream
	streams["button"]=_button_tone()
	for lane in ["ring_rotate","effect","button"]:
		var player=AudioStreamPlayer.new();player.name="SFX_"+lane;player.bus="Master";player.max_polyphony=1;add_child(player);players[lane]=player

	for index in range(T.SFX_DEFEAT_MAX_VOICES):
		var player=AudioStreamPlayer.new();player.name="SFX_defeated_"+str(index);player.bus="Master";player.max_polyphony=1;add_child(player);defeat_voices.append(player)

func _process(delta: float) -> void:
	advance_defeats(delta)

func _exit_tree() -> void:
	for player in players.values()+defeat_voices:player.stop();player.stream=null
	players.clear();defeat_voices.clear();streams.clear();_movement_context=[];_effect_context=[];_defeats=[];_defeat_contexts=[];_button_root=null

## ボタンの入力を共通に接続する。root_uiは画面の所有者。戻り値なし。後から加わる候補も監視し、同じ部品を二重接続しない。
func bind_buttons(root_ui: Control) -> void:
	_button_root=weakref(root_ui)
	var tree=root_ui.get_tree()
	if not tree.node_added.is_connected(_bind_input_node):tree.node_added.connect(_bind_input_node)
	_scan_buttons(root_ui)

func _scan_buttons(node: Node) -> void:
	_bind_input_node(node)
	for child in node.get_children(true):_scan_buttons(child)

func _owns_button(node: Node) -> bool:
	var root_ui=_button_root.get_ref() if _button_root!=null else null
	return is_instance_valid(root_ui) and (node==root_ui or root_ui.is_ancestor_of(node))

func _bind_input_node(node: Node) -> void:
	if not _owns_button(node) or not (node is BaseButton or node is PopupMenu):return
	if node.get_meta("phase_sfx_binding",0)==get_instance_id():return
	node.set_meta("phase_sfx_binding",get_instance_id())
	if node is BaseButton:
		node.gui_input.connect(_arm_button_input.bind(node))
		node.pressed.connect(_button_pip.bind(node))
	else:
		node.window_input.connect(_arm_button_input.bind(node))
		# PopupMenuの入力通知は確定信号の後にも届く。同じ更新の末尾で一度だけ照合する。
		node.id_pressed.connect(func(_id):_button_pip.call_deferred(node))

func _arm_button_input(event: InputEvent,node: Node) -> void:
	if not _owns_button(node):return
	if node is BaseButton and (node.disabled or not node.is_visible_in_tree()):return
	if event is InputEventKey and event.echo:return
	if (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT) or event.is_action("ui_accept"):
		node.set_meta("phase_sfx_input_frame",Engine.get_process_frames())

func _button_pip(node: Node) -> void:
	if not is_instance_valid(node) or not _owns_button(node):return
	if node.get_meta("phase_sfx_input_frame",-1)!=Engine.get_process_frames():return
	node.set_meta("phase_sfx_input_frame",-1)
	_play("button")

func _button_tone() -> AudioStreamWAV:
	var stream=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=T.SFX_BUTTON_SAMPLE_RATE;stream.stereo=false
	var count=maxi(2,roundi(T.SFX_BUTTON_SAMPLE_RATE*T.SFX_BUTTON_SECONDS));var data=PackedByteArray();data.resize(count*2)
	for index in range(count):
		var time=float(index)/T.SFX_BUTTON_SAMPLE_RATE
		var envelope=smoothstep(0,T.SFX_BUTTON_ATTACK_SECONDS,time)*smoothstep(0,T.SFX_BUTTON_RELEASE_SECONDS,T.SFX_BUTTON_SECONDS-time)
		var sample=0 if index==0 or index==count-1 else roundi(sin(TAU*T.SFX_BUTTON_FREQUENCY*time)*envelope*32767)
		data.encode_s16(index*2,sample)
	stream.data=data;return stream

## 実移動の半歩を観測する。motionは既存の確定移動表示。戻り値なし。最初に位置が進む更新から半区間ごとの2音を要求し、表示時間とモデルは変更しない。
func movement_tick(motion: RefCounted) -> void:
	if motion.owner==null or motion.route.is_empty():return
	var context=[motion,motion.owner,motion.turn,motion.actor,motion.route]
	if context!=_movement_context:
		_movement_context=context.duplicate();_completed_pulses=0
	if motion.duration<=0:
		_completed_pulses=motion.route.size()*2;return
	if motion.elapsed<=0:return
	var total=motion.route.size()*2
	var completed=clampi(floori(motion.elapsed/motion.duration*total+0.00000001)+1,0,total)
	for index in range(_completed_pulses,completed):_play("ring_rotate1" if index%2==0 else "ring_rotate2")
	_completed_pulses=maxi(_completed_pulses,completed)

## 実効果の音を出す。ownerは戦闘、historyは確定履歴番号、kindは作用、actualは実HP変化量、defeatedは実撃破。戻り値なし。同じ結果と実変化ゼロを重複再生しない。
func effect(owner: RefCounted,history: int,kind: String,actual: float,defeated: bool=false) -> void:
	if kind not in ["DAMAGE","HEAL"]:return
	var context=[owner,history]
	if context==_effect_context:return
	_effect_context=context
	if is_finite(actual) and actual>0:
		_play("attack" if kind=="DAMAGE" else "heal")
		if kind=="DAMAGE" and defeated and enabled and context not in _defeat_contexts:
			_defeat_contexts.append(context.duplicate())
			var unused=defeat_voices.filter(func(player):return not _defeats.any(func(entry):return entry.player==player))
			if not unused.is_empty():_defeats.append({"age":0.0,"started":false,"player":unused[0]})

## 撃破の予約と余韻を進める。deltaは実時間の経過秒。戻り値なし。手番と戦闘を待たせず、各声の冒頭を保った後に振幅を滑らかに消す。
func advance_defeats(delta: float) -> void:
	if not enabled:
		if players.has("button"):players.button.stop()
		suspend();return
	if not is_finite(delta) or delta<=0:return
	var finished=[]
	for entry in _defeats:
		entry.age+=delta
		var age=entry.age-T.SFX_DEFEAT_DELAY_SECONDS
		if age<0:continue
		if not entry.started:
			entry.started=true;entry.age=T.SFX_DEFEAT_DELAY_SECONDS;age=0.0;_play("defeated",entry.player)
		var ratio=clampf((age-T.SFX_DEFEAT_HOLD_SECONDS)/T.SFX_DEFEAT_FADE_SECONDS,0,1)
		var gain=1.0-smoothstep(0.0,1.0,ratio)
		entry.player.volume_db=T.SFX_VOLUME_DB.defeated+linear_to_db(maxf(0.000001,gain))
		if ratio>=1:
			entry.player.stop();entry.player.stream=null;finished.append(entry)
	for entry in finished:_defeats.erase(entry)

## 戦闘音の尾だけを止める。戻り値なし。完了済みの歩と効果の記録は保持し、再開で再発音しない。
func suspend() -> void:
	for lane in ["ring_rotate","effect"]:
		if players.has(lane):players[lane].stop()
	for player in defeat_voices:player.stop();player.stream=null
	_defeats=[]

## 戦闘の音を破棄する。戻り値なし。再戦に古い音と重複判定を持ち越さず、保存を変更しない。
func reset_battle() -> void:
	suspend();_movement_context=[];_completed_pulses=0;_effect_context=[];_defeat_contexts=[]

func _play(kind: String,voice: AudioStreamPlayer=null) -> void:
	var lane="effect" if kind in ["attack","heal"] else ("ring_rotate" if kind in ["ring_rotate1","ring_rotate2"] else kind)
	var player: AudioStreamPlayer=voice if voice!=null else players.get(lane)
	if not enabled or not is_inside_tree() or not streams.has(kind) or player==null:return
	player.stop();player.stream=streams[kind];player.volume_db=T.SFX_VOLUME_DB[kind]
	# Dummyは無出力。高速終了時の非同期音声の参照残りを避け、動画の音声出力は維持する。
	if AudioServer.get_driver_name()!="Dummy" or not Engine.get_write_movie_path().is_empty():player.play()
	played.emit(kind)
