## 版付きの表示名と円形紋章を管理し、戦闘の識別と計算へ依存しない。
extends RefCounted
const VERSION=1
const MAX_NAME_LENGTH=32
const PREFIX="PHASE/identicon/v1\n"
const PLAYER_IDS=["01","02","03"]
const ENEMY_IDS=["A","B","C"]
const PLAYER_NAMES=["Kestrel","Vesper","Lyra"]
const ENEMY_NAMES=["Onyx","Cipher","Sable"]
const ROTATIONS=[Vector2i(1024,0),Vector2i(724,724),Vector2i(0,1024),Vector2i(-724,724),Vector2i(-1024,0),Vector2i(-724,-724),Vector2i(0,-1024),Vector2i(724,-724)]
const SYMMETRIES={2:[Vector2i(1024,0),Vector2i(-1024,0)],3:[Vector2i(1024,0),Vector2i(-512,887),Vector2i(-512,-887)],4:[Vector2i(1024,0),Vector2i(0,1024),Vector2i(-1024,0),Vector2i(0,-1024)]}
static var _cache: Dictionary={}

## 名前を正規化する。valueは任意のUnicode入力。戻り値は版1の空白と制御処理後の最大32コードポイント、空欄は空文字。入力を変更しない。
static func normalize(value: String) -> String:
	var result="";var space=false
	for character in value:
		var cp=character.unicode_at(0)
		if _whitespace(cp):
			space=not result.is_empty();continue
		if cp<32 or (cp>=127 and cp<=159) or cp in [0x061c,0x200b,0x200e,0x200f,0x2060,0xfeff] or (cp>=0x202a and cp<=0x202e) or (cp>=0x2066 and cp<=0x2069):continue
		if space:
			result+=" ";space=false
		if result.length()>=MAX_NAME_LENGTH:break
		result+=character
		if result.length()>=MAX_NAME_LENGTH:break
	return result.trim_suffix(" ")

static func _whitespace(cp: int) -> bool:
	return (cp>=9 and cp<=13) or cp in [32,0x85,0xa0,0x1680,0x2028,0x2029,0x202f,0x205f,0x3000] or (cp>=0x2000 and cp<=0x200a)

## 枠の既定名を返す。idは不変ID、campは陣営。戻り値は固定の初期名、不明な枠はUnit。副作用なし。
static func default_name(id: String,camp: String) -> String:
	var ids=PLAYER_IDS if camp=="PLAYER" else ENEMY_IDS
	var names=PLAYER_NAMES if camp=="PLAYER" else ENEMY_NAMES
	var index=ids.find(id)
	return names[index] if index>=0 else "Unit"

## 表示名を解決する。valueは入力、idとcampは既定名の枠。戻り値は正規化した非空の名前。副作用なし。
static func effective_name(value: String,id: String,camp: String) -> String:
	var name=normalize(value)
	return default_name(id,camp) if name.is_empty() else name

## 枠の参照を返す。uは不変IDと陣営、shortは短い参照か。戻り値はP1かE1の形式、または陣営と枠番号。副作用なし。
static func slot(u: Dictionary,short: bool=true) -> String:
	var player=u.camp=="PLAYER";var ids=PLAYER_IDS if player else ENEMY_IDS
	var index=ids.find(u.id);var number=str(index+1) if index>=0 else "?"
	return ("P" if player else "E")+number if short else u.camp+" / "+number

## 固定ハッシュを返す。valueは解決済みの表示名。戻り値は版1の接頭辞と正規化名のUTF-8によるSHA-256の小文字16進数。副作用なし。
static func digest(value: String) -> String:
	return (PREFIX+normalize(value)).sha256_text()

## 紋章を記述する。valueは解決済みの名前、versionは方式の版。戻り値は固定パラメーターと単位円内の多角形、未知版は空。入力と返却後の変更はキャッシュと戦闘へ影響しない。
static func recipe(value: String,version: int=VERSION) -> Dictionary:
	if version!=VERSION:return {}
	var name=normalize(value)
	if _cache.has(name):return _cache[name].duplicate(true)
	var bytes=(PREFIX+name).sha256_buffer()
	var family=int(bytes[0])%6;var count=[4,3,2][family%3];var rotation=int(bytes[1])%8
	var width=12+4*(int(bytes[2])%3);var inner=20+6*(int(bytes[3])%3);var center=(int(bytes[4])&1)==1
	var base=[Vector2i(inner,0),Vector2i(42,-width),Vector2i(60,0),Vector2i(42,width)]
	if family>=3:base=[Vector2i(inner,-width),Vector2i(48,-width),Vector2i(60,0),Vector2i(48,width),Vector2i(inner,width),Vector2i(inner+width*3/4,0)]
	var polygons=[]
	for symmetry in SYMMETRIES[count]:
		var polygon=PackedVector2Array()
		for point in base:polygon.append(Vector2(_rotate(_rotate(point,symmetry),ROTATIONS[rotation]))/float(64*1024*1024))
		polygons.append(polygon)
	if center:
		var polygon=PackedVector2Array()
		for point in [Vector2i(0,-8),Vector2i(8,0),Vector2i(0,8),Vector2i(-8,0)]:polygon.append(Vector2(_rotate(point,ROTATIONS[rotation]))/float(64*1024))
		polygons.append(polygon)
	var result={"version":VERSION,"digest":bytes.hex_encode(),"family":family,"count":count,"rotation":rotation,"width":width,"inner":inner,"center":center,"polygons":polygons}
	if _cache.size()>=256:_cache.clear()
	_cache[name]=result
	return result.duplicate(true)

static func _rotate(point: Vector2i,rotation: Vector2i) -> Vector2i:
	return Vector2i(point.x*rotation.x-point.y*rotation.y,point.x*rotation.y+point.y*rotation.x)
