extends SceneTree
const C=preload("res://game/catalog.gd")
const B=preload("res://game/battle.gd")
const L=preload("res://game/collection.gd")
var I
var checks=0
var failures=0
func _initialize() -> void:
	_check(ResourceLoader.exists("res://game/unit_identity.gd"),"versioned identity component exists")
	if failures==0:
		I=load("res://game/unit_identity.gd")
		_names();_vectors();_independence();_storage()
	print("UNIT IDENTITY: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
## REQ-047-S01
func _names() -> void:
	var cases=[[" \tAster\n  Vale\u3000","Aster Vale"],["\u0001星屑\u202e\u0007","星屑"],["[b]Aster[/b]","[b]Aster[/b]"],["  \n\t",""],["界".repeat(33),"界".repeat(32)],["a".repeat(31)+"  z","a".repeat(31)],["e\u0301","e\u0301"]]
	_check(cases.all(func(pair):return I.normalize(pair[0])==pair[1]),"portable whitespace, controls, codepoint boundary and plain text")
	_check(I.normalize("Aster")!="aster" and I.normalize("e\u0301")!="é","case and Unicode composition are preserved")
	_check(I.effective_name("", "01","PLAYER")=="Kestrel" and I.effective_name(" ","A","ENEMY")=="Onyx","blank names resolve to meaningful fixed slot defaults")
## REQ-048-S01
func _vectors() -> void:
	var a=I.recipe("Aster");var j=I.recipe("星屑")
	_check(I.digest("Aster")=="14cc16f47046a92573e5e2212de006cf70ee7ccbbcf325b6c15d7e6b237ca5b0" and I.digest("星屑")=="4567b521a7020c6ba22eff69d428267de39000b2faff6708196f66465f8835d8","independent UTF-8 SHA-256 vectors")
	_check([a.family,a.count,a.rotation,a.width,a.inner,a.center]==[2,2,4,16,26,false] and [j.family,j.count,j.rotation,j.width,j.inner,j.center]==[3,4,7,16,20,true],"fixed v1 parameter vectors")
	_check(a.polygons[0]==PackedVector2Array([Vector2(-0.40625,0),Vector2(-0.65625,0.25),Vector2(-0.9375,0),Vector2(-0.65625,-0.25)]),"integer matrix geometry has a fixed independent vector")
	_check([a,j].all(func(r):return r.polygons.size()<=5 and r.polygons.all(func(poly):return Array(poly).all(func(p):return p.length()<=1))),"few geometric shapes remain inside their unit circle")
	a.polygons.clear()
	_check(I.recipe("Aster").polygons.size()==2 and I.recipe("Aster",999).is_empty(),"callers cannot mutate cached geometry; unknown version is refused")
## REQ-031-S01
func _independence() -> void:
	var b: Variant=B.new();b.start(0,C.player_builds(),128,["Aster","Aster","星屑"])
	_check(b.units.map(func(u):return u.id)==["01","02","03","A","B","C"] and b.units[0].display_name==b.units[1].display_name and b.units[3].display_name=="Onyx","same names keep all six stable identities and fixed enemies")
	for u in b.units:u.next_time=100.0
	b.next_actor();_check(b.timeline(6).map(func(e):return e.index)==[0,1,2,3,4,5],"duplicate names never reorder equal-time turns")
	var policy=load("res://game/cpu_policy.gd").new();b.actor=3
	var plan=policy.choose(b)
	for u in b.units:u.display_name="Aster"
	_check(policy.choose(b)==plan,"CPU choices ignore cosmetic names")
	b.units[3].pos=Vector2i(5,4);b.units[0].pos=Vector2i(4,4);b.units[1].pos=Vector2i(6,4);b.mode="CHOICE";b.units[b.actor].moved=1;b.units[3].skills=[C.DAMAGE]
	var before=b.units.duplicate(true)
	_check(b.choose_skill(C.DAMAGE) and b.act(1) and b.last_effect.target==1 and b.units[0].hp==before[0].hp and b.units[1].hp==before[1].hp-b.last_effect.actual,"target indices remain independent for identical names")
## REQ-016-S01、REQ-016-S02
func _storage() -> void:
	var a=L.new();a.unit_names=["Aster","Aster","星屑"]
	var path="res://artifacts/runtime/unit-identity/roundtrip.json";var b=L.new()
	_check(a.save_to(path)=="" and b.load_from(path)=="" and b.unit_names==["Aster","Aster","星屑"] and b.snapshot().identicon_version==1,"fresh save and fresh instance restore names and version")
	var data=b.snapshot();data.unit_names[0]="bad\nname"
	var f=FileAccess.open(path+".invalid",FileAccess.WRITE);f.store_string(JSON.stringify(data));f.close()
	var original=b.snapshot()
	_check(not b.load_from(path+".invalid").is_empty() and b.snapshot()==original,"noncanonical saved names are rejected atomically")
func _check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",note)
