extends SceneTree

## Bakes World.tscn's walkable area into Scenes/World/world_navigation.tres:
## one NavigationRegion2D ("Navigation") instead of one navigation region per
## Ground tile (~38,000), which made every path / closest-point query cost
## milliseconds. Source: the tiles' navigation polygons of every node in the
## "navigation_source" group (the Ground TileMapLayer, whose own navigation is
## disabled). Same as the editor's "Bake NavigationPolygon" button on the
## Navigation node. Use through tools/bake_nav.sh (temp copy).

const WORLD := "res://Scenes/World/World.tscn"
const OUT := "res://Scenes/World/world_navigation.tres"
## Walkable pockets smaller than this (px²) are dropped: the Ground layer has
## ~40 lone walkable tiles inside walls (14 x 14 px each after the 1 px agent
## radius) that no one can reach, yet closest-point snaps landed on them and
## sent heroes / the monster to stand at the wall facing them. Two touching
## tiles (~420 px²) are kept. test_world_navigation mirrors the rule.
const MIN_ISLAND_AREA := 400.0


func _initialize() -> void:
	process_frame.connect(_bake, CONNECT_ONE_SHOT)


func _bake() -> void:
	var world := (load(WORLD) as PackedScene).instantiate()
	root.add_child(world)
	var region := world.get_node("Navigation") as NavigationRegion2D
	var t0 := Time.get_ticks_msec()
	region.bake_navigation_polygon(false)
	var navpoly := region.navigation_polygon
	var dropped := _drop_small_islands(navpoly)
	print("BAKE polygons=%d vertices=%d islands_dropped=%d ms=%d" % [navpoly.get_polygon_count(), navpoly.vertices.size(), dropped, Time.get_ticks_msec() - t0])
	if navpoly.get_polygon_count() == 0:
		push_error("bake produced no polygons")
		quit(1)
		return
	var err := ResourceSaver.save(navpoly, OUT)
	quit(0 if err == OK else 1)


## Removes every connected group of polygons (connected = sharing an edge, as
## the navigation map links them) whose total area is below MIN_ISLAND_AREA.
## Returns how many groups were dropped.
func _drop_small_islands(navpoly: NavigationPolygon) -> int:
	var verts: PackedVector2Array = navpoly.vertices
	var count: int = navpoly.get_polygon_count()
	var parent: PackedInt32Array = PackedInt32Array()
	parent.resize(count)
	for i in range(count):
		parent[i] = i
	var edge_owner: Dictionary = {}  # edge key -> first polygon index
	for i in range(count):
		var poly: PackedInt32Array = navpoly.get_polygon(i)
		for k in range(poly.size()):
			var a: Vector2 = verts[poly[k]]
			var b: Vector2 = verts[poly[(k + 1) % poly.size()]]
			var key: String = str(a) + str(b) if a < b else str(b) + str(a)
			if edge_owner.has(key):
				_union(parent, i, int(edge_owner[key]))
			else:
				edge_owner[key] = i
	var area: Dictionary = {}  # root -> px²
	for i in range(count):
		var root: int = _find(parent, i)
		area[root] = float(area.get(root, 0.0)) + _polygon_area(verts, navpoly.get_polygon(i))
	var kept: Array[PackedInt32Array] = []
	var dropped_roots: Dictionary = {}
	for i in range(count):
		var root: int = _find(parent, i)
		if float(area[root]) < MIN_ISLAND_AREA:
			dropped_roots[root] = true
		else:
			kept.append(navpoly.get_polygon(i))
	# Rebuild with only the vertices the kept polygons use.
	var remap: Dictionary = {}
	var new_verts := PackedVector2Array()
	var new_polys: Array[PackedInt32Array] = []
	for poly in kept:
		var np := PackedInt32Array()
		for idx in poly:
			if not remap.has(idx):
				remap[idx] = new_verts.size()
				new_verts.append(verts[idx])
			np.append(int(remap[idx]))
		new_polys.append(np)
	navpoly.clear_polygons()
	navpoly.vertices = new_verts
	for np in new_polys:
		navpoly.add_polygon(np)
	return dropped_roots.size()


func _find(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


func _union(parent: PackedInt32Array, a: int, b: int) -> void:
	var ra: int = _find(parent, a)
	var rb: int = _find(parent, b)
	if ra != rb:
		parent[ra] = rb


func _polygon_area(verts: PackedVector2Array, poly: PackedInt32Array) -> float:
	var sum: float = 0.0
	for k in range(poly.size()):
		var a: Vector2 = verts[poly[k]]
		var b: Vector2 = verts[poly[(k + 1) % poly.size()]]
		sum += a.x * b.y - b.x * a.y
	return absf(sum) * 0.5
