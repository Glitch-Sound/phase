## 黒い計測面の配色、判読性検証、独立した表示設定を扱う。
extends RefCounted
const STORE=preload("res://game/storage.gd")
const T=preload("res://game/tuning.gd")
const BG=Color("040506")
const SURFACE=Color("090b0e")
const INTERACTIVE=Color("151c21")
const EDGE=Color("30363d")
const TEXT=Color("e8ebed")
const MUTED=Color("9ba4ad")
const MIN_CONTRAST=4.5
const MIN_DISTANCE=0.12
# ACTIONはHPと同期の比較に使うため、背後の有効な配色を暗くしない。
const ACTION_SCRIM_ALPHA=0.0
const PRESETS={
	"DEFAULT":[Color("b8d8d0"),Color("bec4ce"),Color("ee95a0"),Color("9ad4b5"),Color("9ebbe8"),Color("dfcb94")],
	"AMBER":[Color("e6c78f"),Color("c4c8d0"),Color("f2a9a2"),Color("b8d8a2"),Color("a7cbe5"),Color("dcc0ed")],
	"ICE":[Color("a8cce9"),Color("bfc6d4"),Color("e8a5bd"),Color("a3d5c7"),Color("aaa9ee"),Color("e8d0a0")]
}

## リングの表示色を返す。colorsは検証済みのアクセントと5色。戻り値はプリセットだけ彩度を強めた5色、カスタムは元のRGB。副作用なし。
static func ring_colors(colors: Array) -> Array:
	var source=colors.slice(1)
	if not PRESETS.values().has(colors):
		return source
	var result=[]
	for color in source:
		result.append(Color.from_hsv(color.h,1-pow(1-color.s,T.UNIT_RING_SATURATION_POWER),color.v,color.a))
	return result

## 配色を検証する。colorsはアクセントと5色。戻り値はエラー、正常時空文字。副作用なし。
static func validate(colors: Array) -> String:
	if colors.size()!=6:
		return "Choose an accent and all five status colors."
	for color in colors:
		if not color is Color or color.a!=1.0:
			return "Colors must be fully opaque."
		for channel in [color.r,color.g,color.b]:
			if not is_finite(channel) or channel<0 or channel>1:
				return "Choose a color inside the standard RGB range."
		if _contrast(color,INTERACTIVE)<MIN_CONTRAST:
			return "Color contrast is too low. Choose a lighter color."
	for i in range(1,6):
		for j in range(i+1,6):
			var a: Color=colors[i]
			var b: Color=colors[j]
			if Vector3(a.r,a.g,a.b).distance_to(Vector3(b.r,b.g,b.b))<MIN_DISTANCE:
				return "Status colors are too similar. Keep all five distinct."
	return ""

## 設定を読む。pathは独立設定のパス。戻り値は有効な6色、不正時既定値。副作用なし。
static func load_from(path: String) -> Array:
	if not STORE.exists(path):
		return PRESETS.DEFAULT.duplicate()
	var parser=JSON.new()
	if parser.parse(STORE.read_text(path).text)!=OK:
		return PRESETS.DEFAULT.duplicate()
	var data=parser.data
	if not data is Array or data.size()!=6:
		return PRESETS.DEFAULT.duplicate()
	var colors=[]
	for value in data:
		if not value is String or not Color.html_is_valid(value):
			return PRESETS.DEFAULT.duplicate()
		colors.append(Color.html(value))
	return colors if validate(colors).is_empty() else PRESETS.DEFAULT.duplicate()

## 設定を保存する。pathは保存先、colorsは6色。戻り値はエラー、正常時空文字。副作用は明示保存と既存設定の退避。
static func save_to(path: String, colors: Array) -> String:
	var error=validate(colors)
	if not error.is_empty():
		return error
	var data=[]
	for color in colors:data.append(color.to_html(false))
	return STORE.write_text(path,JSON.stringify(data)).error

static func _contrast(a: Color,b: Color) -> float:
	return (_luminance(a)+0.05)/(_luminance(b)+0.05)

static func _luminance(color: Color) -> float:
	var values=[]
	for channel in [color.r,color.g,color.b]:
		values.append(channel/12.92 if channel<=0.04045 else pow((channel+0.055)/1.055,2.4))
	return 0.2126*values[0]+0.7152*values[1]+0.0722*values[2]
