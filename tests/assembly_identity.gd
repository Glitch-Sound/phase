extends SceneTree
const I=preload("res://game/unit_identity.gd")
const L=preload("res://game/collection.gd")
const C=preload("res://game/catalog.gd")
var A
var checks=0
var failures=0
func _initialize() -> void:
	_check(ResourceLoader.exists("res://game/assembly_identity.gd"),"assembly identity component exists")
	if failures==0:
		A=load("res://game/assembly_identity.gd");_profiles();_geometry();_colors();_ownership();_storage()
	print("ASSEMBLY IDENTITY: %d checks / %d failures" % [checks,failures]);quit(0 if failures==0 else 1)
## REQ-050-S01、REQ-050-S02、REQ-051-S02
func _profiles() -> void:
	var p=A.default_profile("PLAYER");var e=A.default_profile("ENEMY")
	_check(p=={"name":"ORBIT","color":"PEARL","version":1} and e=={"name":"VECTOR","color":"RED","version":1},"fixed defaults are independent of player identity")
	p.name="";_check(A.valid(p) and A.label(p,"PLAYER")=="ORBIT" and A.label(p,"ENEMY")=="VECTOR","blank names resolve per assembly without changing data")
	var cases=[{"name":"星環","color":"ICE","version":1},{"name":"bad\nname","color":"ICE","version":1},{"name":"星環","color":"UNKNOWN","version":1},{"name":"星環","color":"ICE","version":2}]
	_check(cases.map(func(v):return A.valid(v))==[true,false,false,false],"profile validation rejects noncanonical names, unknown keys and versions")
## REQ-050-S01
func _geometry() -> void:
	var a=A.recipe("ORBIT");var j=A.recipe("星環")
	_check(a.digest=="e5cd404250724dca9fc0847869da64577ac945f9765157b038e1e867919af1ac" and j.digest=="90564b735ee9e54a688ecfaf41bce6569920df2668b96af9533e877de05eeb14","independent assembly SHA-256 vectors use a separate prefix")
	var expected=PackedVector2Array([Vector2(-0.75,-0.1875),Vector2(-0.75,-0.53125),Vector2(-0.53125,-0.75),Vector2(-0.1875,-0.75),Vector2(-0.1875,-0.53125),Vector2(-0.4375,-0.53125),Vector2(-0.53125,-0.4375),Vector2(-0.53125,-0.1875)])
	_check([a.family,a.rotation,a.cut]==[1,5,16] and [j.family,j.rotation,j.cut]==[0,6,12] and a.polygons.size()==2 and j.polygons.size()==4 and j.polygons[0]==expected and a.polygons[0][0]==Vector2(-37648.0/65536,14480.0/65536),"fixed assembly parameters and independently specified polygon coordinates")
	_check(A.recipe("ORBIT",999).is_empty() and [a,j].all(func(r):return r.polygons.all(func(poly):return Array(poly).all(func(p):return p.length()<=1))),"bounded geometry refuses unknown version")
	var unit=I.recipe("Aster");_check(unit.digest=="14cc16f47046a92573e5e2212de006cf70ee7ccbbcf325b6c15d7e6b237ca5b0" and unit.polygons[0]==PackedVector2Array([Vector2(-0.40625,0),Vector2(-0.65625,0.25),Vector2(-0.9375,0),Vector2(-0.65625,-0.25)]),"unit v1 geometry remains unchanged")
	var p=A.default_profile("PLAYER");p.name="Same";var q=p.duplicate(true);q.color="ICE"
	_check(A.recipe(A.label(p))==A.recipe(A.label(q)),"color and camp collisions never rewrite a chosen shape")
## REQ-050-S02
func _colors() -> void:
	var palette={"PEARL":"c9d2dc","JADE":"a1d9c3","ICE":"9ec8ed","AMBER":"e5c38c","LILAC":"c7b1e6","ROSE":"e3adbd","RED":"ed8b8b"}
	_check(A.PALETTE.keys()==palette.keys() and palette.keys().all(func(k):return A.color({"color":k})==Color(palette[k])),"all stable palette keys have fixed colors")
	var T=load("res://game/tuning.gd")
	var bg=_luminance(Color("13181d"))
	_check(palette.keys().all(func(k):
		var color=A.color({"color":k});var hp=A.health({"color":k});var light=_luminance(hp)
		return is_equal_approx(color.h,hp.h) and hp.a==1 and light>=T.ASSEMBLY_HP_LUMINANCE_MIN and (light+0.05)/(bg+0.05)>=T.ASSEMBLY_HP_CONTRAST_MIN),"every HP color preserves hue with high luminance and contrast")
## REQ-052-S01
func _ownership() -> void:
	var units=[{"id":"01","camp":"PLAYER","display_name":"Same"},{"id":"A","camp":"ENEMY","display_name":"Same"},{"id":"A","camp":"PLAYER","display_name":"Same"}]
	_check(units.map(func(u):return A.owns(u,"PLAYER"))==[true,false,false] and units.map(func(u):return A.owns(u,"ENEMY"))==[false,true,false] and units.all(func(u):return not A.owns(u,"UNKNOWN")),"ownership uses valid camp and immutable slot, independent of names")
## REQ-016-S01、REQ-016-S02、REQ-051-S02
func _storage() -> void:
	var a=L.new();a.assembly={"name":"星環","color":"ICE","version":1};var b=L.new()
	var path="res://artifacts/runtime/assembly-identity/roundtrip.json"
	_check(a.save_to(path)=="" and b.load_from(path)=="" and b.assembly==a.assembly and b.snapshot().assembly==a.assembly,"new save restores assembly profile")
	var saved=b.snapshot();var invalid=saved.duplicate(true);invalid.assembly.color="UNKNOWN"
	var f=FileAccess.open(path+".invalid",FileAccess.WRITE);f.store_string(JSON.stringify(invalid));f.close()
	_check(not b.load_from(path+".invalid").is_empty() and b.snapshot()==saved,"bad assembly load preserves the complete current data")
	var normal=a.snapshot();var session=load("res://game/debug_session.gd").new();var temp=session.begin(a);temp.assembly.name="Temporary"
	_check(temp.save_to(path+".temporary")!="" and not FileAccess.file_exists(path+".temporary") and session.end().snapshot()==normal,"temporary assembly does not pollute normal data or save")
func _luminance(color: Color) -> float:
	var rgb=[]
	for v in [color.r,color.g,color.b]:rgb.append(v/12.92 if v<=0.04045 else pow((v+0.055)/1.055,2.4))
	return rgb[0]*0.2126+rgb[1]*0.7152+rgb[2]*0.0722
func _check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",note)
