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

## What each faction may hit: the physics-layer mirror of CAN_HIT below (the
## one source of the targeting rules). Keep the two in sync.
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


## True when `pos` lies on the navigation mesh (within 2 px). True as well
## when the map cannot answer yet, so callers keep their pre-nav behaviour.
func is_on_nav(world: World2D, pos: Vector2) -> bool:
	var nav_map: RID = usable_nav_map(world)
	if not nav_map.is_valid():
		return true
	return NavigationServer2D.map_get_closest_point(nav_map, pos).distance_squared_to(pos) <= 4.0


## Closest point of the navigation mesh to `pos` (`pos` itself when the map
## cannot answer yet).
func snap_to_nav(world: World2D, pos: Vector2) -> Vector2:
	var nav_map: RID = usable_nav_map(world)
	if not nav_map.is_valid():
		return pos
	return NavigationServer2D.map_get_closest_point(nav_map, pos)


## True when a path from `from` actually arrives within `tolerance` of `to`.
## A goal on another part of the mesh (a sealed pocket, a tile island) gets a
## path that stops at the closest reachable point — often right where the
## walker already stands. True when the map cannot answer yet.
func nav_path_reaches(world: World2D, from: Vector2, to: Vector2, tolerance: float = 32.0) -> bool:
	var nav_map: RID = usable_nav_map(world)
	if not nav_map.is_valid():
		return true
	var path: PackedVector2Array = NavigationServer2D.map_get_path(nav_map, from, to, true)
	if path.is_empty():
		return false
	return path[path.size() - 1].distance_squared_to(to) <= tolerance * tolerance


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

## Which side an entity fights on. Read from its scene groups by faction_of()
## (Hero: HeroBaseClass.tscn and TedsPet.tscn; Enemy: Bat, Hog; Enemy +
## Monster: monster_base_class.tscn).
enum Faction { NONE, HERO, MOB, MONSTER }

## Who may hit whom: CAN_HIT[attacker] is the set of factions that attacker
## may target, one bit per Faction (1 << target). The one source of the
## targeting rules; EntityRegistry.targets_for and MASK_* mirror it.
## can_entity_target adds the one per-entity exception, a warband mob and its
## monster (Call of the Herd).
const CAN_HIT: Array[int] = [
	0,                                            # NONE: nothing
	(1 << Faction.MOB) | (1 << Faction.MONSTER),  # HERO: every enemy
	(1 << Faction.HERO) | (1 << Faction.MONSTER), # MOB: heroes and the monster, never other mobs
	(1 << Faction.HERO) | (1 << Faction.MOB),     # MONSTER: heroes and mobs
]


## The faction from `n`'s scene groups (static: assigned at instantiation),
## with precedence Hero > Monster > Enemy. EntityBase caches it as `faction`
## in _enter_tree; per-candidate code goes through cached_faction_of().
func faction_of(n: Node) -> Faction:
	if n.is_in_group("Hero"):
		return Faction.HERO
	if n.is_in_group("Monster"):
		return Faction.MONSTER
	if n.is_in_group("Enemy"):
		return Faction.MOB
	return Faction.NONE


## faction_of() through EntityBase's cached `faction` (no group lookups);
## other nodes (Ted's pet) read their groups.
func cached_faction_of(n: Node) -> Faction:
	var entity := n as EntityBase
	if entity:
		return entity.faction
	return faction_of(n)


func can_hit(attacker: Faction, target: Faction) -> bool:
	return (CAN_HIT[attacker] & (1 << target)) != 0


func can_entity_target(attacker: Node, target: Node) -> bool:
	var a: Faction = cached_faction_of(attacker)
	var t: Faction = cached_faction_of(target)
	if not can_hit(a, t):
		return false
	# Gorrak's Call of the Herd (MobBase.ally_monster): a recruited mob and the
	# monster it fights for spare each other; heroes stay its targets.
	if a == Faction.MOB and t == Faction.MONSTER:
		return not _fights_for(attacker, target)
	if a == Faction.MONSTER and t == Faction.MOB:
		return not _fights_for(target, attacker)
	return true


## `mob` is in `monster`'s warband (MobBase.ally_monster, while its timer runs).
func _fights_for(mob: Node, monster: Node) -> bool:
	var m := mob as MobBase
	return m != null and m.ally_monster != null and m.ally_monster == monster

# ============================================
# OVERLAP QUERIES
# ============================================

## Shared by every entities_in_circle() call (Ram Dash queries on each dash
## frame): each call overwrites all of their state before its synchronous use.
var _overlap_shape: CircleShape2D = null
var _overlap_query: PhysicsShapeQueryParameters2D = null


## Entities whose collider overlaps the circle, once each, in physics result
## order; never `exclude`. Areas always count; `collide_bodies` adds physics
## bodies: Ted's pet is a CharacterBody2D on LAYER_BODY_HERO (entity roots are
## plain Node2Ds, so it is the only physics body the body layers can return).
## Colliders resolve through Globals.get_entity_from_collider (owner first).
func entities_in_circle(world: World2D, center: Vector2, radius: float, mask: int,
		collide_bodies: bool, exclude: Node = null, max_results: int = 32) -> Array[Node2D]:
	if _overlap_query == null:
		_overlap_shape = CircleShape2D.new()
		_overlap_query = PhysicsShapeQueryParameters2D.new()
		_overlap_query.shape = _overlap_shape
	_overlap_shape.radius = radius
	_overlap_query.transform = Transform2D(0.0, center)
	_overlap_query.collision_mask = mask
	_overlap_query.collide_with_areas = true
	_overlap_query.collide_with_bodies = collide_bodies
	var found: Array[Node2D] = []
	var seen: Dictionary = {}
	for hit: Dictionary in world.direct_space_state.intersect_shape(_overlap_query, max_results):
		var collider: Node = hit["collider"] as Node
		if collider == null:
			continue
		var entity: Node2D = Globals.get_entity_from_collider(collider)
		if entity == null or entity == exclude or seen.has(entity):
			continue
		seen[entity] = true
		found.append(entity)
	return found

# ============================================
# VFX UTILITIES
# ============================================

## A straight trail from `from` to `to` (global positions) under `parent`,
## drawn above the entities (z_index 10), that fades out over `fade` seconds
## and then frees itself. Basic-attack swipes, sniper shots and heal beams.
func flash_line(parent: Node, from: Vector2, to: Vector2, color: Color, width: float, fade: float) -> void:
	var line := Line2D.new()
	parent.add_child(line)
	line.add_point(from)
	line.add_point(to)
	line.default_color = color
	line.width = width
	line.z_index = 10
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, fade)
	tween.tween_callback(line.queue_free)

## Meta key on a flashed CanvasItem: its running flash_modulate tween.
const FLASH_TWEEN_META: StringName = &"flash_tween"

## Tints `item.modulate` to `color` over `t_in` seconds, then back to WHITE
## over `t_out` (Rally Cry, the MediKit heal, the monster's evolution flash).
## It ends at the constant WHITE, never at a value captured when it started:
## that could be another effect's tint (Divine Shield's blue, a flash still
## running) and would then stick for good. A new flash on the same item kills
## the one still running.
func flash_modulate(item: CanvasItem, color: Color, t_in: float, t_out: float) -> void:
	# has_meta first: get_meta with a null default still errors on a missing key.
	if item.has_meta(FLASH_TWEEN_META):
		var running: Variant = item.get_meta(FLASH_TWEEN_META)
		if running is Tween:
			(running as Tween).kill()
	var tween := item.create_tween()
	tween.tween_property(item, "modulate", color, t_in)
	tween.tween_property(item, "modulate", Color.WHITE, t_out)
	item.set_meta(FLASH_TWEEN_META, tween)

# ============================================
# FOG OF WAR UTILITIES
# ============================================

func is_position_explored(fog_system: Node, position: Vector2) -> bool:
	if not is_instance_valid(fog_system):
		return false
	
	if fog_system.has_method("is_tile_explored"):
		return fog_system.is_tile_explored(position)
	
	return false
