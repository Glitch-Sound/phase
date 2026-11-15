extends SceneTree
const B=preload("res://game/battle.gd")
const C=preload("res://game/catalog.gd")
const M=preload("res://game/phase_math.gd")

func _initialize() -> void:
	var examples=[]
	for phase_steps in range(0,12,2):
		var b=B.new()
		b.start(0,[C.default_build(),C.default_build()])
		for i in range(phase_steps):
			M.enter_panel(b.units[0],"NORMAL")
		var routes=[]
		_paths(b,b.units[0].pos,[],routes)
		var endpoints={}
		for path in routes:
			var key=str(path.back())
			var u=b.units[0].duplicate(true)
			for cell in path:
				M.enter_panel(u,b.panels.get(cell,"NORMAL"))
			var row={"path":str(path),"length":path.size(),"inf":M.sync(u,1).factor,"res":M.sync(u,2).factor}
			if not endpoints.has(key):
				endpoints[key]=[]
			endpoints[key].append(row)
		for endpoint in endpoints:
			var rows: Array=endpoints[endpoint]
			var shortest=99
			for row in rows:
				shortest=mini(shortest,row.length)
			var short_best={"inf":-1.0}
			var long_best={"inf":-1.0}
			for row in rows:
				if row.length==shortest and row.inf>short_best.inf:
					short_best=row
				elif row.length>shortest and row.inf>long_best.inf:
					long_best=row
			if long_best.inf>short_best.inf+0.2:
				examples.append({"normal_steps_before":phase_steps,"gear_before":b.units[0].gear_angle,"arms_before":b.units[0].arms_angle,"destination":endpoint,"short":short_best,"long":long_best})
	var f=FileAccess.open("res://artifacts/route-study.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(examples,"\t"))
	f.close()
	print("ROUTE STUDY: %d endpoints where a longer path improves INF by >20 percentage points" % examples.size())
	if not examples.is_empty():
		print(JSON.stringify(examples[0]))
	quit(0 if not examples.is_empty() else 1)

func _paths(b: RefCounted, cell: Vector2i, path: Array, result: Array) -> void:
	if not path.is_empty():
		result.append(path.duplicate())
	if path.size()>=b.movement(b.units[b.actor]):
		return
	for d in B.DIRS:
		var next: Vector2i=cell+d
		if next.x<0 or next.y<0 or next.x>=10 or next.y>=10 or b.at(next)>=0 or path.has(next):
			continue
		path.append(next)
		_paths(b,next,path,result)
		path.pop_back()
