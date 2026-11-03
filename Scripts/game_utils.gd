extends Node

## 2D physics layer bits — keep in sync with project.godot [layer_names].
## Entities expose ONE monitorable Area2D ("Body", r≈31) on their faction
## layer; their DetectionArea is on no layer and masks only enemy bodies, so
## mob-vs-mob areas never pair up and AoE queries see each entity once.
## Ted's pet is a CharacterBody2D with its own "Body" Area2D on LAYER_BODY_HERO,
## so DetectionAreas (which only react to areas) can aggro it and AoE queries
## resolve it through that area (its physics body maps to its parent node).
const LAYER_WORLD: int = 1
const LAYER_BODY_HERO: int = 2
const LAYER_BODY_MOB: int = 4
const LAYER_BODY_MONSTER: int = 8
const LAYER_ABILITY_ZONE: int = 16
## Path search budget for every NavigationAgent2D: above the polygon count of
## the baked world mesh (~2,100, Scenes/World/world_navigation.tres), so no
## path is ever cut short. (With the old one-region-per-tile map, ~38,000
## polygons, paths longer than ~2500 px stopped half-way at the engine default
## of 4096.)
const NAV_MAX_SEARCH_POLYGONS: int = 16384

## Apply the project's path search budget (property exists since Godot 4.5).
func configure_nav_agent(agent: NavigationAgent2D) -> void:
	if agent and "path_search_max_polygons" in agent:
		agent.set("path_search_max_polygons", NAV_MAX_SEARCH_POLYGONS)

## What each faction may hit (mirrors can_entity_target below).
const MASK_HERO_TARGETS: int = LAYER_BODY_MOB | LAYER_BODY_MONSTER
const MASK_MOB_TARGETS: int = LAYER_BODY_HERO | LAYER_BODY_MONSTER
const MASK_MONSTER_TARGETS: int = LAYER_BODY_HERO | LAYER_BODY_MOB
const MASK_HEROES: int = LAYER_BODY_HERO


## The world's navigation map when it can answer queries: synchronised at
## least once AND containing regions. A synced map without regions answers
## every closest-point query with the origin, which would mark every point as
## off-mesh. Returns an invalid RID otherwise (callers then skip nav checks).
func usable_nav_map(world: World2D) -> RID:
	if world == null:
		return RID()
	var nav_map: RID = world.navigation_map
	if not nav_map.is_valid() or NavigationServer2D.map_get_iteration_id(nav_map) == 0:
		return RID()
	if NavigationServer2D.map_get_regions(nav_map).is_empty():
		return RID()
	return nav_map


## A random point inside `rect` that lies on the navigation mesh and is not on
## an isolated nav island (the map has one-tile islands): a path from it
## toward `from` must either arrive or leave the point by at least
## `min_reach` px. (A path can stop at the path search's polygon limit, so
## "the path arrives" alone could reject the far side of the map.) Returns
## `fallback` when the map cannot answer yet or no sample
## qualifies. A region's polygons arrive one map sync after the region itself
## (queries return the origin until then), so callers at startup retry.
func random_reachable_point(world: World2D, rect: Rect2, from: Vector2, fallback: Vector2,
		tries: int = 32, min_reach: float = 256.0) -> Vector2:
	var nav_map: RID = usable_nav_map(world)
	if not nav_map.is_valid():
		return fallback
	var start: Vector2 = NavigationServer2D.map_get_closest_point(nav_map, from)
	if start.distance_to(from) > 64.0:
		return fallback  # the map has regions but no queryable polygons yet
	for i in range(tries):
		var p := Vector2(randf_range(rect.position.x, rect.end.x), randf_range(rect.position.y, rect.end.y))
		var on_mesh: Vector2 = NavigationServer2D.map_get_closest_point(nav_map, p)
		if not rect.grow(8.0).has_point(on_mesh):
			continue
		var path: PackedVector2Array = NavigationServer2D.map_get_path(nav_map, on_mesh, start, true)
		if path.is_empty():
			continue
		var end: Vector2 = path[path.size() - 1]
		if end.distance_to(start) <= 8.0 or end.distance_to(on_mesh) >= min_reach:
			return on_mesh
	return fallback


## Walk from `from` toward `to` in `step` px increments and return the last
## point that is still on the navigation mesh. Dashes and leaps move the entity
## directly (no pathing); without this they ended inside wall tiles — and on one
## of the map's isolated one-tile nav islands the next path never left the
## island ("monster stuck in a corner"). Returns `to` unchanged when the map has
## not synchronised yet (no navigation available to check against).
func clamp_to_nav_segment(world: World2D, from: Vector2, to: Vector2, step: float = 8.0) -> Vector2:
	var nav_map: RID = usable_nav_map(world)
	if not nav_map.is_valid():
		return to
	var offset: Vector2 = to - from
	var length: float = offset.length()
	if length < 0.001:
		return from
	var dir: Vector2 = offset / length
	var last_ok: Vector2 = from
	var travelled: float = 0.0
	while travelled < length:
		travelled = minf(travelled + step, length)
		var p: Vector2 = from + dir * travelled
		if NavigationServer2D.map_get_closest_point(nav_map, p).distance_squared_to(p) > 4.0:
			break
		last_ok = p
	return last_ok


## Signed shortest turn from angle `from` to angle `to`, in [-PI, PI].
## Not the engine's angle_difference(): that uses different float operations,
## and a last-bit change would perturb seeded sims.
func wrapped_angle_delta(from: float, to: float) -> float:
	var diff = fmod(to - from, TAU)
	if diff > PI:
		diff -= TAU
	elif diff < -PI:
		diff += TAU
	return diff

# ============================================
# TARGETING UTILITIES
# ============================================

func can_entity_target(attacker: Node, target: Node) -> bool:
	if attacker.is_in_group("Monster"):
		# Monsters attack Heroes and Mobs (but not other Monsters)
		if target.is_in_group("Hero"):
			return true
		elif target.is_in_group("Enemy") and not target.is_in_group("Monster"):
			return true  # It's a Mob
	
	elif attacker.is_in_group("Enemy"):
		# Mobs attack Heroes and Monsters (but not other Mobs)
		if target.is_in_group("Hero"):
			return true
		elif target.is_in_group("Monster"):
			return true
	
	elif attacker.is_in_group("Hero"):
		# Heroes attack all enemies (Mobs and Monsters)
		if target.is_in_group("Enemy"):
			return true
	
	return false

# ============================================
# FOG OF WAR UTILITIES
# ============================================

func is_position_explored(fog_system: Node, position: Vector2) -> bool:
	if not is_instance_valid(fog_system):
		return false
	
	if fog_system.has_method("is_tile_explored"):
		return fog_system.is_tile_explored(position)
	
	return false
