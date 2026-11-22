## 確定移動の2拍と実HP変化だけを短く鳴らす。
extends Node
const T=preload("res://game/tuning.gd")
const SOURCES={
	"ring_rotate1":preload("res://assets/sfx/ring_rotate1.ogg"),
	"ring_rotate2":preload("res://assets/sfx/ring_rotate2.ogg"),
	"attack":preload("res://assets/sfx/attack.ogg"),
	"heal":preload("res://assets/sfx/heal.ogg")
}
signal played(kind: String)
var enabled=true
var streams: Dictionary={}
var players: Dictionary={}
var _movement_context: Array=[]
var _completed_pulses=0
var _effect_context: Array=[]

func _ready() -> void:
	for key in SOURCES:
		var stream=SOURCES[key].duplicate();stream.loop=false;streams[key]=stream
	for lane in ["ring_rotate","effect"]:
		var player=AudioStreamPlayer.new();player.name="SFX_"+lane;player.bus="Master";player.max_polyphony=1;add_child(player);players[lane]=player

func _exit_tree() -> void:
	for player in players.values():player.stop();player.stream=null
	players.clear();streams.clear();_movement_context=[];_effect_context=[]

## 実移動の半歩を観測する。motionは既存の確定移動表示。戻り値なし。等間隔の2音を同じ量だけ早め、表示時間とモデルは変更しない。
func movement_tick(motion: RefCounted) -> void:
	if motion.owner==null or motion.route.is_empty():return
	var context=[motion,motion.owner,motion.turn,motion.actor,motion.route]
	if context!=_movement_context:
		_movement_context=context.duplicate();_completed_pulses=0
	if motion.duration<=0:
		_completed_pulses=motion.route.size()*2;return
	if motion.elapsed<=0:return
	var total=motion.route.size()*2
	var lead=clampf(T.SFX_MOVEMENT_LEAD_SECONDS,0,motion.duration/total)
	var completed=clampi(floori((motion.elapsed+lead)/motion.duration*total+0.00000001),0,total)
	for index in range(_completed_pulses,completed):_play("ring_rotate1" if index%2==0 else "ring_rotate2")
	_completed_pulses=maxi(_completed_pulses,completed)

## 実効果の音を出す。ownerは戦闘、historyは確定履歴番号、kindは作用、actualは実HP変化量。戻り値なし。同じ結果と実変化ゼロを重複再生しない。
func effect(owner: RefCounted,history: int,kind: String,actual: float) -> void:
	if kind not in ["DAMAGE","HEAL"]:return
	var context=[owner,history]
	if context==_effect_context:return
	_effect_context=context
	if is_finite(actual) and actual>0:_play("attack" if kind=="DAMAGE" else "heal")

## 戦闘音の尾だけを止める。戻り値なし。完了済みの歩と効果の記録は保持し、再開で再発音しない。
func suspend() -> void:
	for lane in ["ring_rotate","effect"]:
		if players.has(lane):players[lane].stop()

## 戦闘の音を破棄する。戻り値なし。再戦に古い音と重複判定を持ち越さず、保存を変更しない。
func reset_battle() -> void:
	suspend();_movement_context=[];_completed_pulses=0;_effect_context=[]

func _play(kind: String) -> void:
	var lane="effect" if kind in ["attack","heal"] else ("ring_rotate" if kind in ["ring_rotate1","ring_rotate2"] else kind)
	if not enabled or not is_inside_tree() or not streams.has(kind) or not players.has(lane):return
	var player: AudioStreamPlayer=players[lane]
	player.stop();player.stream=streams[kind];player.volume_db=T.SFX_VOLUME_DB[kind]
	# Dummyは無出力。高速終了時の非同期音声の参照残りを避け、動画の音声出力は維持する。
	if AudioServer.get_driver_name()!="Dummy" or not Engine.get_write_movie_path().is_empty():player.play()
	played.emit(kind)
