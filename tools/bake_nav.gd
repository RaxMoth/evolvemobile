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


func _initialize() -> void:
	process_frame.connect(_bake, CONNECT_ONE_SHOT)


func _bake() -> void:
	var world := (load(WORLD) as PackedScene).instantiate()
	root.add_child(world)
	var region := world.get_node("Navigation") as NavigationRegion2D
	var t0 := Time.get_ticks_msec()
	region.bake_navigation_polygon(false)
	var navpoly := region.navigation_polygon
	print("BAKE polygons=%d vertices=%d ms=%d" % [navpoly.get_polygon_count(), navpoly.vertices.size(), Time.get_ticks_msec() - t0])
	if navpoly.get_polygon_count() == 0:
		push_error("bake produced no polygons")
		quit(1)
		return
	var err := ResourceSaver.save(navpoly, OUT)
	quit(0 if err == OK else 1)
