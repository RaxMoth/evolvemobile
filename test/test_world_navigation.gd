extends TestCase

## The world's navigation is ONE baked NavigationRegion2D ("Navigation") made
## from the Ground tiles' navigation polygons. With the TileMapLayer's own
## navigation (one region per tile, ~38,000) every path and closest-point
## query cost milliseconds. The bake must match the tiles: after editing
## Ground, re-bake with tools/bake_nav.sh (or the editor's Bake
## NavigationPolygon button on the Navigation node), or this test fails.

const WORLD := "res://Scenes/World/World.tscn"
## Every Nth used Ground cell is checked (a full pass is ~38,000 queries).
const SAMPLE_STRIDE := 5


func test_world_navigation_is_one_baked_region_matching_the_ground_tiles() -> void:
	var world := (load(WORLD) as PackedScene).instantiate()
	var ground := world.get_node("Ground") as TileMapLayer
	var region := world.get_node("Navigation") as NavigationRegion2D
	assert_false(ground.navigation_enabled, "no per-tile navigation regions")
	assert_true(ground.is_in_group(&"navigation_source"), "the bake reads the Ground tiles")
	assert_eq(ground.position, Vector2.ZERO, "tile coordinates are world coordinates")
	var navpoly := region.navigation_polygon
	assert_true(navpoly != null and navpoly.get_polygon_count() > 0, "a baked mesh is assigned")

	# Query the baked mesh on a private map; the scene never enters the tree.
	var map := NavigationServer2D.map_create()
	NavigationServer2D.map_set_active(map, true)
	var rid := NavigationServer2D.region_create()
	NavigationServer2D.region_set_map(rid, map)
	NavigationServer2D.region_set_navigation_polygon(rid, navpoly)
	# Polygons land one map sync after the region, and the sync runs on a
	# worker thread: wait until a known mesh vertex answers (not the origin).
	var probe: Vector2 = navpoly.vertices[0]
	for i in range(600):
		await wait_physics_frames(1)
		if NavigationServer2D.map_get_closest_point(map, probe).distance_to(probe) < 1.0:
			break
	assert_true(NavigationServer2D.map_get_closest_point(map, probe).distance_to(probe) < 1.0, "test map synced")

	var walkable_off_mesh := 0
	var wall_on_mesh := 0
	var checked := 0
	var cells := ground.get_used_cells()
	for i in range(0, cells.size(), SAMPLE_STRIDE):
		var cell: Vector2i = cells[i]
		var data := ground.get_cell_tile_data(cell)
		var tile_nav: NavigationPolygon = data.get_navigation_polygon(0) if data else null
		if tile_nav != null and not _covers_tile_center(tile_nav):
			continue  # partial tile polygon: its centre is legitimately off-mesh
		var center := ground.map_to_local(cell)
		var gap := NavigationServer2D.map_get_closest_point(map, center).distance_to(center)
		if tile_nav != null and gap > 1.5:
			walkable_off_mesh += 1
		elif tile_nav == null and gap <= 1.5:
			wall_on_mesh += 1
		checked += 1
	assert_true(checked > 1000, "sampled enough cells (%d)" % checked)
	assert_eq(walkable_off_mesh, 0, "walkable tiles missing from the baked mesh (stale bake?)")
	assert_eq(wall_on_mesh, 0, "non-walkable tiles on the baked mesh (stale bake?)")

	NavigationServer2D.free_rid(rid)
	NavigationServer2D.free_rid(map)
	world.free()


func _covers_tile_center(tile_nav: NavigationPolygon) -> bool:
	var verts := tile_nav.vertices
	for p in range(tile_nav.get_polygon_count()):
		var ring := PackedVector2Array()
		for idx in tile_nav.get_polygon(p):
			ring.append(verts[idx])
		if Geometry2D.is_point_in_polygon(Vector2.ZERO, ring):
			return true
	return false
