## 実表示の確定と独立保存を扱い、非同期復元中の旧値を書き戻さない。
extends RefCounted
const SETTLE_SECONDS=preload("res://game/tuning.gd").DISPLAY_SETTLE_SECONDS
var _pending=-1
var _explicit=false
var _observed=-1
var _elapsed=0.0

## 起動時の復元を待つ。modeは正規化済みのモード。保存イベントは発生させない。
func restore(mode: int) -> void:
	_pending=mode;_explicit=false;_observed=-1;_elapsed=0.0

## 明示操作を待つ。modeはWINDOWEDかFULLSCREEN。安定するまで保存しない。
func request(mode: int) -> void:
	restore(mode);_explicit=true

## 実モードを観測する。modeは実モード、deltaは秒。戻り値は保存すべき明示モードを一度だけ返し、それ以外は-1。
func observe(mode: int,delta: float) -> int:
	if _pending<0 or mode!=_pending:_observed=-1;_elapsed=0.0;return -1
	if _observed!=mode:_observed=mode;_elapsed=0.0
	else:_elapsed+=delta
	if _elapsed<SETTLE_SECONDS:return -1
	_pending=-1
	return mode if _explicit else -1

## 表示設定を読む。pathは専用JSON。戻り値はモード。未指定、不明、破損はWINDOWEDとし、書き込まない。
static func read_from(path: String) -> int:
	if not FileAccess.file_exists(path):return DisplayServer.WINDOW_MODE_WINDOWED
	var value=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary:return DisplayServer.WINDOW_MODE_WINDOWED
	var mode=value.get("mode")
	return DisplayServer.WINDOW_MODE_FULLSCREEN if (mode is int or mode is float) and mode==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_WINDOWED

## 明示モードを独立保存する。pathは専用JSON、modeはモード。戻り値は正常時空文字、失敗時の説明。
static func write_to(path: String,mode: int) -> String:
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir())!=OK:return "Could not create display settings directory."
	var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:return "Could not save display settings."
	file.store_string(JSON.stringify({"mode":mode}));file.close()
	if FileAccess.file_exists(path) and DirAccess.copy_absolute(path,path+".backup-"+str(Time.get_ticks_usec()))!=OK:return "Could not back up display settings."
	if DirAccess.rename_absolute(path+".tmp",path)!=OK:return "Could not replace display settings."
	return ""
