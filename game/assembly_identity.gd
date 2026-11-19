## アセンブリの版付き表示規約を持ち、戦闘の識別と計算へ渡さない。
extends RefCounted
const I=preload("res://game/unit_identity.gd")
const T=preload("res://game/tuning.gd")
const VERSION=1
const PREFIX="PHASE/assembly/v1\n"
const PALETTE={"PEARL":"c9d2dc","JADE":"a1d9c3","ICE":"9ec8ed","AMBER":"e5c38c","LILAC":"c7b1e6","ROSE":"e3adbd"}
const NAMES={"PLAYER":"ORBIT","ENEMY":"VECTOR"}
const COLORS={"PLAYER":"JADE","ENEMY":"AMBER"}

## 初期設定を返す。campは陣営。戻り値は編集から独立した名前と安定色キー、版の辞書。副作用なし。
static func default_profile(camp: String="PLAYER") -> Dictionary:
	return {"name":NAMES.get(camp,"ORBIT"),"color":COLORS.get(camp,"JADE"),"version":VERSION}

## 設定の適否を返す。profileは入力候補。戻り値は版と名前、色が有効か。入力を変更しない。
static func valid(profile: Variant) -> bool:
	return profile is Dictionary and profile.size()==3 and profile.get("version",-1)==VERSION and profile.get("name") is String and I.normalize(profile.name)==profile.name and profile.get("color") is String and PALETTE.has(profile.color)

## 表示名を返す。profileは設定、campは空欄の既定陣営。戻り値は正規化した非空の名前。副作用なし。
static func label(profile: Dictionary,camp: String="PLAYER") -> String:
	var name=I.normalize(str(profile.get("name","")))
	return NAMES.get(camp,"Assembly") if name.is_empty() else name

## 紋章の色を返す。profileは検証済みの設定。戻り値は安定キーの不透明色、不明時はJADE。副作用なし。
static func color(profile: Dictionary) -> Color:
	return Color(PALETTE.get(profile.get("color","JADE"),PALETTE.JADE))

## HPの明るい色を返す。profileは表示設定。戻り値は同じ色相で彩度を下げた高明度の不透明色。副作用なし。
static func health(profile: Dictionary) -> Color:
	var ink=color(profile)
	return Color.from_hsv(ink.h,ink.s*T.ASSEMBLY_HP_SATURATION,1.0)

## 所有の適否を返す。unitは不変IDと陣営、view_campは視点。戻り値は整合した自軍か。名前と表示設定を参照せず変更しない。
static func owns(unit: Dictionary,view_camp: String) -> bool:
	if not view_camp in ["PLAYER","ENEMY"] or unit.get("camp")!=view_camp:return false
	return unit.get("id") in (I.PLAYER_IDS if view_camp=="PLAYER" else I.ENEMY_IDS)

## 紋章を記述する。nameは解決済みの名前、versionは方式。戻り値は固定の幾何とパラメーター、未知版は空。入力と戦闘を変更しない。
static func recipe(name: String,version: int=VERSION) -> Dictionary:
	if version!=VERSION:return {}
	var bytes=(PREFIX+I.normalize(name)).sha256_buffer()
	var family=int(bytes[0])%4;var rotation=int(bytes[1])%8;var cut=12+4*(int(bytes[2])%3)
	var base=[];var count=4
	match family:
		0:base=[Vector2i(cut,-48),Vector2i(34,-48),Vector2i(48,-34),Vector2i(48,-cut),Vector2i(34,-cut),Vector2i(34,-28),Vector2i(28,-34),Vector2i(cut,-34)]
		1:
			count=2
			base=[Vector2i(cut,-36),Vector2i(44,-36),Vector2i(56,0),Vector2i(44,36),Vector2i(cut,36),Vector2i(cut+10,20),Vector2i(32,20),Vector2i(40,0),Vector2i(32,-20),Vector2i(cut+10,-20)]
		2:
			count=3
			base=[Vector2i(cut,-14),Vector2i(42,-24),Vector2i(56,-10),Vector2i(56,10),Vector2i(42,24),Vector2i(cut,14),Vector2i(30,0)]
		3:base=[Vector2i(cut,0),Vector2i(34,-20),Vector2i(56,0),Vector2i(34,20)]
	var polygons=[]
	for symmetry in I.SYMMETRIES[count]:
		var polygon=PackedVector2Array()
		for point in base:polygon.append(Vector2(_rotate(_rotate(point,symmetry),I.ROTATIONS[rotation]))/float(64*1024*1024))
		polygons.append(polygon)
	return {"version":VERSION,"digest":bytes.hex_encode(),"family":family,"rotation":rotation,"cut":cut,"polygons":polygons}

static func _rotate(point: Vector2i,rotation: Vector2i) -> Vector2i:
	return Vector2i(point.x*rotation.x-point.y*rotation.y,point.x*rotation.y+point.y*rotation.x)
