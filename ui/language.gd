## 説明文の言語と独立設定を扱い、ゲームの名称と状態を変更しない。
extends RefCounted
const STORE=preload("res://game/storage.gd")
const COPY=preload("res://ui/japanese.gd").TEXT
const CHOICES=["system","en","ja"]
var selection="system"
var preferred_locale="en"
var _formats: Array=[]

## 選択言語を解決する。valueは設定値、preferredは環境由来のロケール。戻り値はenかja。副作用なし。
static func resolve(value: Variant,preferred: String) -> String:
	if value in ["en","ja"]:return value
	return "ja" if preferred.to_lower().replace("-","_").get_slice("_",0).get_slice("@",0)=="ja" else "en"

## 設定を読む。pathは言語専用のパス。戻り値はsystem、en、ja。不明と破損はsystemで、書込は行わない。
static func read_from(path: String) -> String:
	if not STORE.exists(path):return "system"
	var parser=JSON.new()
	if parser.parse(STORE.read_text(path).text)!=OK:return "system"
	var value=parser.data
	if not value is Dictionary:return "system"
	var choice=value.get("language","system")
	return choice if choice is String and CHOICES.has(choice) else "system"

## 明示設定を保存する。pathは保存先、valueは選択値。戻り値はエラー、正常時空文字。一時書込と退避以外のファイルを変更しない。
static func write_to(path: String,value: String) -> String:
	return STORE.write_text(path,JSON.stringify({"language":value if CHOICES.has(value) else "system"})).error

## 現在の表示言語を返す。戻り値はenかja。副作用なし。
func locale() -> String:
	return resolve(selection,preferred_locale)

## 説明の対訳を返す。sourceは明示された説明の英語原文。戻り値は選択言語の文、未知の文は原文。名称や状態を変更しない。
func text(source: String) -> String:
	if locale()=="en" or source.is_empty():return source
	if COPY.has(source):return _japanese(COPY[source])
	if _formats.is_empty():_prepare_formats()
	var lines=[]
	for line in source.split("\n"):
		if COPY.has(line):lines.append(_japanese(COPY[line]));continue
		var translated=line
		for row in _formats:
			var matched=row.regex.search(line)
			if matched==null:continue
			var values=[]
			for i in range(row.types.size()):
				var captured=matched.get_string(i+1)
				values.append(int(captured) if row.types[i]=="d" else (float(captured) if row.types[i]=="f" else captured))
			translated=_japanese(row.target) % values;break
		lines.append(translated)
	return "\n".join(lines)

static func _japanese(template: String) -> String:
	# 入力値を代入する前の対訳だけを整える。名前や原文へ置換を広げない。
	return "\n".join(template.replace("。","\n").split("\n",false))

func _prepare_formats() -> void:
	# 登録したprintfの書式だけを認識する。任意の部分置換や入力名の翻訳は行わない。
	var tokens=RegEx.create_from_string("%(?:\\.[0-9]+)?[dfs%]")
	for source in COPY:
		if not source.contains("%d") and not source.contains("%s") and not source.contains("%."):continue
		var pattern="^";var types=[];var cursor=0
		for token in tokens.search_all(source):
			pattern+=_escape(source.substr(cursor,token.get_start()-cursor))
			var kind=token.get_string().right(1)
			if kind=="%":pattern+="%"
			else:
				types.append(kind)
				pattern+="(-?[0-9]+)" if kind=="d" else ("(-?[0-9]+(?:\\.[0-9]+)?)" if kind=="f" else "(.+?)")
			cursor=token.get_end()
		pattern+=_escape(source.substr(cursor))+"$"
		_formats.append({"regex":RegEx.create_from_string(pattern),"types":types,"target":COPY[source]})

static func _escape(value: String) -> String:
	var result=""
	for character in value:result+=("\\" if character in "\\.^$*+?()[]{}|" else "")+character
	return result
