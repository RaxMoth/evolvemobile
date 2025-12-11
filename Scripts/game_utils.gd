extends Node 

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
