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
## Path search budget for every NavigationAgent2D. World.tscn's TileMapLayer
## makes one navigation region PER TILE (~38k), and at the engine default
## (4096 polygons) any path longer than ~2500 px stopped half-way: an agent
## that fell behind its group walked to the cut-off point and stayed there.
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
## `min_reach` px. (Long paths on the per-tile map stop at the path search's
## polygon limit, so "the path arrives" alone would reject the far side of
## the map.) Returns `fallback` when the map cannot answer yet or no sample
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


func angle_difference(from: float, to: float) -> float:
	var diff = fmod(to - from, TAU)
	if diff > PI:
		diff -= TAU
	elif diff < -PI:
		diff += TAU
	return diff

func normalize_angle(angle: float) -> float:
	var normalized = fmod(angle, TAU)
	if normalized > PI:
		normalized -= TAU
	elif normalized < -PI:
		normalized += TAU
	return normalized

func lerp_angle(from: float, to: float, weight: float) -> float:
	var diff = angle_difference(from, to)
	return from + diff * weight

func angle_to_vector(angle: float) -> Vector2:
	return Vector2(cos(angle), sin(angle))

# ============================================
# VECTOR UTILITIES
# ============================================

func get_perpendicular(vec: Vector2, clockwise: bool = true) -> Vector2:
	return Vector2(vec.y, -vec.x) if clockwise else Vector2(-vec.y, vec.x)

func rotate_vector_towards(
	current: Vector2,
	target: Vector2,
	max_angle_delta: float
) -> Vector2:
	if current.length_squared() < 0.0001 or target.length_squared() < 0.0001:
		return current
	
	var current_angle = current.angle()
	var target_angle = target.angle()
	var angle_diff = angle_difference(current_angle, target_angle)
	
	var rotation = clampf(angle_diff, -max_angle_delta, max_angle_delta)
	return current.rotated(rotation)

func point_direction(from: Vector2, to: Vector2) -> Vector2:
	var dir = to - from
	return dir.normalized() if dir.length_squared() > 0.0001 else Vector2.ZERO

# ============================================
# SPATIAL QUERIES - Wall Detection
# ============================================

## NOTE: the wall helpers below raycast against physics BODIES on `collision_mask`.
## The World TileSet has no physics layer, so they currently hit nothing but
## Ted's pet; EntityBase idle scoring uses NavigationServer2D instead.
func is_point_too_close_to_wall(
	world: World2D,
	point: Vector2,
	min_radius: float = 32.0,
	collision_mask: int = 1,
	samples: int = 8
) -> bool:
	var space_state = world.direct_space_state
	
	for i in range(samples):
		var angle = i * TAU / samples
		var offset = Vector2.from_angle(angle) * min_radius
		var check_point = point + offset
		
		var query = PhysicsRayQueryParameters2D.create(point, check_point)
		query.collision_mask = collision_mask
		query.collide_with_areas = false
		query.collide_with_bodies = true
		
		var result = space_state.intersect_ray(query)
		if result:
			return true  # Wall too close!
	
	return false

func count_walls_in_radius(
	world: World2D,
	point: Vector2,
	radius: float = 50.0,
	collision_mask: int = 1,
	samples: int = 12
) -> int:
	var space_state = world.direct_space_state
	var count = 0
	
	for i in range(samples):
		var angle = i * TAU / samples
		var check_point = point + Vector2.from_angle(angle) * radius
		
		var query = PhysicsRayQueryParameters2D.create(point, check_point)
		query.collision_mask = collision_mask
		query.collide_with_areas = false
		query.collide_with_bodies = true
		
		var result = space_state.intersect_ray(query)
		if result:
			count += 1
	
	return count

# ============================================
# SPATIAL QUERIES - Position Sampling
# ============================================

func sample_random_point_around(
	origin: Vector2,
	min_radius: float,
	max_radius: float
) -> Vector2:
	var angle = randf() * TAU
	var dist = randf_range(min_radius, max_radius)
	return origin + Vector2.from_angle(angle) * dist

func find_valid_position_near(
	world: World2D,
	origin: Vector2,
	radius: float,
	samples: int = 5,
	collision_mask: int = 1,
	wall_check_radius: float = 32.0,
	prefer_forward: bool = false,
	forward_direction: Vector2 = Vector2.ZERO
) -> Vector2:
	var best_point = origin
	var best_score = -INF
	
	for i in range(samples):
		var candidate: Vector2
		
		# If preferring forward, 60% chance to sample in forward cone
		if prefer_forward and forward_direction.length_squared() > 0.01 and randf() < 0.6:
			var forward_angle = forward_direction.angle()
			var angle_offset = randf_range(-PI/3, PI/3)  # 120° cone
			var angle = forward_angle + angle_offset
			var dist = randf_range(radius * 0.3, radius)
			candidate = origin + Vector2.from_angle(angle) * dist
		else:
			# Random sampling
			candidate = sample_random_point_around(origin, radius * 0.3, radius)
		
		# Score this candidate
		var score = score_position(
			world,
			origin,
			candidate,
			collision_mask,
			wall_check_radius,
			forward_direction if prefer_forward else Vector2.ZERO
		)
		
		if score > best_score:
			best_score = score
			best_point = candidate
	
	# If no good point found (all had negative scores), return origin
	return best_point if best_score > -500.0 else origin

func score_position(
	world: World2D,
	origin: Vector2,
	point: Vector2,
	collision_mask: int,
	wall_check_radius: float,
	forward_hint: Vector2
) -> float:
	var score = 0.0
	
	# 1. CRITICAL: Reject if too close to walls
	if is_point_too_close_to_wall(world, point, wall_check_radius, collision_mask, 8):
		return -1000.0  # Reject entirely
	
	# 2. PREFER forward direction (if provided)
	if forward_hint.length_squared() > 0.01:
		var to_point = (point - origin).normalized()
		var angle_diff = abs(angle_difference(forward_hint.angle(), to_point.angle()))
		score += (PI - angle_diff) * 50.0 / PI  # 0 to 50 points
	
	# 3. PREFER open spaces (fewer walls nearby)
	var nearby_walls = count_walls_in_radius(world, point, 50.0, collision_mask, 12)
	score -= nearby_walls * 30.0
	
	return score

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

func get_valid_targets_in_area(attacker: Node, detection_area: Area2D) -> Array[Node]:
	var valid_targets: Array[Node] = []
	
	if not is_instance_valid(detection_area):
		return valid_targets
	
	for area in detection_area.get_overlapping_areas():
		# Get the root entity (Area2D's owner)
		var target_entity = area.get_owner()
		
		# Skip if invalid or same entity
		if not is_instance_valid(target_entity):
			continue
		if target_entity == attacker:
			continue
		
		# Check targeting rules
		if can_entity_target(attacker, target_entity):
			valid_targets.append(target_entity)
	
	return valid_targets

func find_nearest_valid_target(attacker: Node, detection_area: Area2D) -> Node:
	var targets = get_valid_targets_in_area(attacker, detection_area)
	if targets.is_empty():
		return null
	
	# Find closest
	var closest: Node = null
	var closest_dist = INF
	
	for target in targets:
		var dist = attacker.global_position.distance_squared_to(target.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = target
	
	return closest

# ============================================
# COMBAT UTILITIES
# ============================================

func calculate_kite_direction(
	entity_pos: Vector2,
	target_pos: Vector2,
	strafe_direction: int = 1
) -> Vector2:
	var away_dir = (entity_pos - target_pos).normalized()
	var perpendicular = get_perpendicular(away_dir, true) * strafe_direction
	return (away_dir + perpendicular * 0.3).normalized()

func is_in_attack_range(
	attacker_pos: Vector2,
	target_pos: Vector2,
	min_range: float,
	max_range: float
) -> bool:
	var dist_sq = attacker_pos.distance_squared_to(target_pos)
	return dist_sq >= min_range * min_range and dist_sq <= max_range * max_range

# ============================================
# FOG OF WAR UTILITIES
# ============================================

func is_position_explored(fog_system: Node, position: Vector2) -> bool:
	if not is_instance_valid(fog_system):
		return false
	
	if fog_system.has_method("is_tile_explored"):
		return fog_system.is_tile_explored(position)
	
	return false

# ============================================
# DISTANCE UTILITIES
# ============================================

func get_distance_category(distance: float, thresholds: Dictionary) -> String:
	var sorted_keys = thresholds.keys()
	sorted_keys.sort_custom(func(a, b): return thresholds[a] < thresholds[b])
	
	for key in sorted_keys:
		if distance <= thresholds[key]:
			return key
	
	return "extreme"
