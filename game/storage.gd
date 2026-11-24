## 通常の原子的ファイル保存とWebのページ内メモリを同じ境界で扱う。
extends RefCounted
# nullでは実プラットフォームへ従う。検証だけで保存先を隔離して切り替える。
static var memory_only: Variant=null
static var demo_override: Variant=null
static var _memory: Dictionary={}

## デモかを返す。戻り値は書き出しのdemoタグか検証用指定。副作用なし。
static func is_demo() -> bool:
	return OS.has_feature("demo") if demo_override==null else bool(demo_override)

## メモリ保存かを返す。戻り値はデモ、Webか検証用指定。副作用なし。
static func in_memory() -> bool:
	return is_demo() or (OS.has_feature("web") if memory_only==null else bool(memory_only))

## 保存の存在を返す。pathは保存キー。戻り値は存在のbool。Webでは実ファイルを参照しない。
static func exists(path: String) -> bool:
	return _memory.has(path) if in_memory() else FileAccess.file_exists(path)

## テキストを読む。pathは保存キー、max_bytesは0なら無制限。戻り値はtextとerrorであり、現在のデータを書き換えない。
static func read_text(path: String,max_bytes: int=0) -> Dictionary:
	if in_memory():
		if not _memory.has(path):return {"text":"","error":"No saved build. Use SAVE first."}
		var text: String=_memory[path]
		if max_bytes>0 and text.to_utf8_buffer().size()>max_bytes:return {"text":"","error":"Save is too large. Current build is preserved."}
		return {"text":text,"error":""}
	if not FileAccess.file_exists(path):return {"text":"","error":"No saved build. Use SAVE first."}
	var file=FileAccess.open(path,FileAccess.READ)
	if file==null:return {"text":"","error":"Cannot read save."}
	if max_bytes>0 and file.get_length()>max_bytes:
		file.close();return {"text":"","error":"Save is too large. Current build is preserved."}
	var text=file.get_as_text();file.close()
	return {"text":text,"error":""}

## テキストを保存する。pathは保存キー、textは検証済みの内容。戻り値はerrorとbackup。通常は原子的置換と退避、Webはメモリだけを書き換える。
static func write_text(path: String,text: String) -> Dictionary:
	if in_memory():
		_memory[path]=text
		return {"error":"","backup":""}
	var absolute=ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())!=OK:return {"error":"Cannot create save directory.","backup":""}
	var suffix=".%d-%d" % [int(Time.get_unix_time_from_system()),Time.get_ticks_usec()]
	var temp=absolute+suffix+".tmp"
	var file=FileAccess.open(temp,FileAccess.WRITE)
	if file==null:return {"error":"Cannot write save file.","backup":""}
	file.store_string(text);file.flush();var error=file.get_error();file.close()
	if error!=OK:return {"error":"Save write failed. Original is preserved.","backup":""}
	var backup=""
	if FileAccess.file_exists(absolute):
		backup=absolute+suffix+".backup.json"
		if DirAccess.copy_absolute(absolute,backup)!=OK:return {"error":"Backup failed. Original is preserved.","backup":""}
	if DirAccess.rename_absolute(temp,absolute)!=OK:return {"error":"Cannot replace save. Original or backup is preserved.","backup":backup}
	return {"error":"","backup":backup}
