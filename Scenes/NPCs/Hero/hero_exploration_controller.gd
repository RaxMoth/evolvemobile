extends Node
class_name HeroExplorationController

signal exploration_target_reached(position: Vector2)
signal monster_detected(monster: Node2D)

@export_group("Performance")
@export var boids_update_interval: float = 0.1
@export var max_separation_checks: int = 3
var boids_timer: float = 0.0
var cached_boids_data: Dictionary = {}

@export_group("Group Behavior")
@export var group_exploration_enabled: bool = true
@export var group_cohesion_radius: float = 200.0
@export var personal_space_radius: float = 80.0
@export var exploration_update_interval: float = 3.0

@export_group("Exploration Settings")
@export var exploration_tile_size: int = 32
@export var search_radius_per_check: float = 400.0
@export var waypoint_reached_distance: float = 100.0
@export var stuck_detection_time: float = 5.0
@export var prefer_forward_exploration: bool = true  # NEW: Prefer exploring forward

@export_group("Movement Smoothing")
@export var use_formation: bool = true
@export var formation_spread: float = 100.0
@export var wander_while_moving: bool = true
@export var wander_strength: float = 50.0

var heroes: Array[Node2D] = []
var fog_system: FogOfWarSystem = null
var current_group_target: Vector2 = Vector2.ZERO
var exploration_timer: float = 0.0

var hero_solo_mode: Dictionary = {}
var hero_formation_offset: Dictionary = {}
var hero_last_positions: Dictionary = {}
var hero_stuck_timers: Dictionary = {}

var explored_targets: Array[Vector2] = []
var current_exploration_zone: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("HeroExplorationController")  # NEW: Add to group so it can be found
	await get_tree().process_frame
	_find_heroes()
	_find_fog_system()
	_setup_formation()
	
	if heroes.size() > 0:
		current_group_target = _calculate_group_center()

func _process(delta: float) -> void:
	if not group_exploration_enabled or heroes.is_empty():
		return
	_cleanup_freed_heroes()
	
	exploration_timer -= delta
	
	if exploration_timer <= 0.0:
		exploration_timer = exploration_update_interval
		_update_exploration_targets()
	
	_update_hero_flow(delta)
	_check_stuck_heroes(delta)
	_check_for_monsters()

# ============================================
# NEW: PUBLIC API FOR HEROES TO USE
# ============================================

func get_current_group_target() -> Vector2:
	"""Get the current exploration target for heroes to use in idle"""
	return current_group_target

func get_hero_exploration_target(hero: Node2D) -> Vector2:
	"""Get specific target for a hero including formation offset"""
	if not is_instance_valid(hero):
		return Vector2.ZERO
	
	var formation_offset = hero_formation_offset.get(hero, Vector2.ZERO)
	return current_group_target + formation_offset

func is_hero_in_group_mode(hero: Node2D) -> bool:
	"""Check if hero is following group exploration"""
	return not hero_solo_mode.get(hero, false)

# ============================================
# IMPROVED EXPLORATION TARGET SELECTION
# ============================================

func _update_exploration_targets() -> void:
	if not fog_system:
		return
	
	var group_center = _calculate_group_center()
	
	# Check if we reached the current target
	if group_center.distance_to(current_group_target) < waypoint_reached_distance:
		explored_targets.append(current_group_target)
	
	# Find next target preferring forward direction
	var unexplored_target = _find_next_exploration_zone(group_center)
	
	if unexplored_target != Vector2.ZERO:
		current_group_target = unexplored_target
		current_exploration_zone = unexplored_target
		exploration_target_reached.emit(unexplored_target)
	else:
		# Fallback: random unexplored area
		current_group_target = _get_random_unexplored_position(group_center)

func _find_next_exploration_zone(from_position: Vector2) -> Vector2:
	if not fog_system:
		return Vector2.ZERO
	
	var best_target = Vector2.ZERO
	var best_score = -INF
	
	# Determine forward direction from group movement
	var group_velocity = _calculate_group_velocity()
	var forward_angle = group_velocity.angle() if group_velocity.length() > 1.0 else 0.0

	# Sample in a cone ahead if prefer_forward is enabled
	var angles = 12
	var distances = [300, 500, 700]  # Explore further ahead
	
	for angle_step in angles:
		var base_angle = (angle_step / float(angles)) * TAU
		
		# Bias toward forward direction
		if prefer_forward_exploration and group_velocity.length() > 1.0:
			# Focus 60% of samples in forward 120-degree cone
			if randf() < 0.6:
				base_angle = forward_angle + randf_range(-PI/3, PI/3)
		
		var direction = Vector2.from_angle(base_angle)
		
		for distance in distances:
			var check_pos = from_position + direction * distance
			
			# Skip recently explored
			if _is_recently_explored(check_pos):
				continue
			
			# Count unexplored tiles
			var unexplored_count = _count_unexplored_in_area(check_pos, 150.0)
			
			if unexplored_count > 0:
				# Calculate score
				var score = unexplored_count * 10.0
				
				# Bonus for forward direction
				if prefer_forward_exploration:
					var to_target = (check_pos - from_position).normalized()
					var angle_diff = abs(angle_difference(forward_angle, to_target.angle()))
					score += (PI - angle_diff) * 50.0
				
				# Slight penalty for distance (prefer closer if equally good)
				score -= distance * 0.05
				
				if score > best_score:
					best_score = score
					best_target = check_pos
	
	return best_target

func _get_random_unexplored_position(near_position: Vector2) -> Vector2:
	"""Find random unexplored position near group"""
	if not fog_system:
		return _get_random_map_position()
	
	# Try 10 random points, pick first unexplored one
	for i in range(10):
		var angle = randf() * TAU
		var distance = randf_range(300, 600)
		var candidate = near_position + Vector2.from_angle(angle) * distance
		
		if not fog_system.is_tile_explored(candidate):
			return candidate
	
	# Fallback
	return _get_random_map_position()

func _calculate_group_velocity() -> Vector2:
	"""Calculate average movement direction of group"""
	var total_velocity = Vector2.ZERO
	var count = 0
	
	for hero in heroes:
		if not is_instance_valid(hero):
			continue
		
		var last_pos = hero_last_positions.get(hero, hero.global_position)
		var velocity = hero.global_position - last_pos
		
		if velocity.length() > 1.0:  # Only count if actually moving
			total_velocity += velocity.normalized()
			count += 1
	
	return total_velocity / count if count > 0 else Vector2.ZERO

func angle_difference(from: float, to: float) -> float:
	"""Calculate shortest angle difference"""
	var diff = fmod(to - from, TAU)
	if diff > PI:
		diff -= TAU
	elif diff < -PI:
		diff += TAU
	return diff

# ============================================
# REST OF EXISTING METHODS
# ============================================

func _cleanup_freed_heroes() -> void:
	for i in range(heroes.size() - 1, -1, -1):
		var hero = heroes[i]
		
		if not is_instance_valid(hero):
			heroes.remove_at(i)
			hero_solo_mode.erase(hero)
			hero_formation_offset.erase(hero)
			hero_last_positions.erase(hero)
			hero_stuck_timers.erase(hero)
			cached_boids_data.erase(hero)

func _find_heroes() -> void:
	heroes.clear()
	var found_heroes = get_tree().get_nodes_in_group("Hero")
	
	for hero in found_heroes:
		if hero is Node2D:
			heroes.append(hero)
			hero_solo_mode[hero] = false
			hero_last_positions[hero] = hero.global_position
			hero_stuck_timers[hero] = 0.0
	
	print("HeroExplorationController: Found ", heroes.size(), " heroes")

func _find_fog_system() -> void:
	fog_system = get_tree().get_first_node_in_group("FogOfWar")
	if not fog_system:
		push_warning("HeroExplorationController: No FogOfWar system found!")

func _setup_formation() -> void:
	if heroes.size() == 0:
		return
	
	var formations = [
		Vector2(0, 0),       # Leader/center
		Vector2(-1, -1),     # Back left
		Vector2(1, -1),      # Back right
		Vector2(0, 1),       # Front
	]
	
	for i in range(heroes.size()):
		var hero = heroes[i]
		var formation_index = i % formations.size()
		hero_formation_offset[hero] = formations[formation_index] * formation_spread

func _count_unexplored_in_area(center: Vector2, radius: float) -> int:
	if not fog_system:
		return 0
	
	var count = 0
	var step = exploration_tile_size * 2
	
	for x in range(-radius, radius, step):
		for y in range(-radius, radius, step):
			var check_pos = center + Vector2(x, y)
			
			if check_pos.distance_to(center) <= radius:
				if not fog_system.is_tile_explored(check_pos):
					count += 1
	
	return count

func _is_recently_explored(position: Vector2) -> bool:
	var recent_memory = 5
	var check_count = min(recent_memory, explored_targets.size())
	
	for i in range(explored_targets.size() - check_count, explored_targets.size()):
		if explored_targets[i].distance_to(position) < 200.0:
			return true
	
	return false

func _update_hero_flow(delta: float) -> void:
	boids_timer -= delta
	
	if boids_timer <= 0.0:
		boids_timer = boids_update_interval
		_recalculate_boids()
	
	for hero in heroes:
		if not is_instance_valid(hero):
			continue
		
		if hero_solo_mode.get(hero, false):
			_update_solo_hero(hero, delta)
		else:
			_apply_cached_boids(hero)

func _recalculate_boids() -> void:
	for hero in heroes:
		if not is_instance_valid(hero):
			continue
		
		var separation = _calculate_separation(hero)
		var cohesion = _calculate_cohesion(hero)
		var alignment = _calculate_alignment(hero)
		
		cached_boids_data[hero] = {
			"separation": separation,
			"cohesion": cohesion,
			"alignment": alignment
		}

func _apply_cached_boids(hero: Node2D) -> void:
	if not cached_boids_data.has(hero):
		return
	
	var data = cached_boids_data[hero]
	var formation_offset = hero_formation_offset.get(hero, Vector2.ZERO)
	var base_target = current_group_target + formation_offset
	
	var final_target = base_target + data.separation * 1.5 + data.cohesion * 0.5 + data.alignment * 0.3
	
	if hero.has_method("set_exploration_target"):
		hero.set_exploration_target(final_target)

func _update_solo_hero(hero: Node2D, _delta: float) -> void:
	# Solo heroes just explore on their own
	pass

func _calculate_separation(hero: Node2D) -> Vector2:
	var separation = Vector2.ZERO
	var count = 0
	
	for other in heroes:
		if other == hero or not is_instance_valid(other):
			continue
		
		var distance = hero.global_position.distance_to(other.global_position)
		if distance < personal_space_radius and distance > 0:
			var away = (hero.global_position - other.global_position).normalized()
			separation += away / distance
			count += 1
			
			if count >= max_separation_checks:
				break
	
	return separation.normalized() * 50.0 if count > 0 else Vector2.ZERO

func _calculate_cohesion(hero: Node2D) -> Vector2:
	var center = _calculate_group_center()
	var to_center = center - hero.global_position
	var distance = to_center.length()
	
	if distance > group_cohesion_radius:
		return to_center.normalized() * 100.0
	
	return Vector2.ZERO

func _calculate_alignment(hero: Node2D) -> Vector2:
	var avg_velocity = Vector2.ZERO
	var count = 0
	
	for other in heroes:
		if other == hero or not is_instance_valid(other):
			continue
		
		var distance = hero.global_position.distance_to(other.global_position)
		if distance < group_cohesion_radius:
			var last_pos = hero_last_positions.get(other, other.global_position)
			var velocity = other.global_position - last_pos
			avg_velocity += velocity
			count += 1
	
	return avg_velocity.normalized() * 30.0 if count > 0 else Vector2.ZERO

func _check_stuck_heroes(delta: float) -> void:
	for hero in heroes:
		if not is_instance_valid(hero):
			continue
		
		var current_pos = hero.global_position
		
		if not hero_last_positions.has(hero):
			hero_last_positions[hero] = current_pos
			hero_stuck_timers[hero] = 0.0
			continue
		
		var last_pos = hero_last_positions[hero]

		if current_pos.distance_to(last_pos) < 5.0:
			hero_stuck_timers[hero] += delta
			
			if hero_stuck_timers[hero] > stuck_detection_time:
				_unstuck_hero(hero)
				hero_stuck_timers[hero] = 0.0
		else:
			hero_stuck_timers[hero] = 0.0
		
		hero_last_positions[hero] = current_pos

func _unstuck_hero(hero: Node2D) -> void:
	print(hero.name + " is stuck! Finding new path...")
	
	# Try to find an unexplored area nearby
	var new_target = Vector2.ZERO
	
	if fog_system:
		for i in range(8):
			var angle = i * TAU / 8.0
			var offset = Vector2.from_angle(angle) * 200.0
			var check_pos = hero.global_position + offset
			
			if not fog_system.is_tile_explored(check_pos):
				new_target = check_pos
				break
	
	# Fallback to random offset
	if new_target == Vector2.ZERO:
		new_target = hero.global_position + Vector2(
			randf_range(-200, 200),
			randf_range(-200, 200)
		)
	
	if hero.has_method("set_exploration_target"):
		hero.set_exploration_target(new_target)

func _calculate_group_center() -> Vector2:
	if heroes.is_empty():
		return Vector2.ZERO
	
	var total = Vector2.ZERO
	var count = 0
	
	for hero in heroes:
		if is_instance_valid(hero):
			total += hero.global_position
			count += 1
	
	return total / count if count > 0 else Vector2.ZERO

func _get_random_map_position() -> Vector2:
	if not fog_system:
		return Vector2.ZERO
	
	return Vector2(
		randf_range(0, fog_system.world_size.x),
		randf_range(0, fog_system.world_size.y)
	) + fog_system.world_offset

func _check_for_monsters() -> void:
	var monsters = get_tree().get_nodes_in_group("Monster")
	
	for monster in monsters:
		if not monster is Node2D or not monster.has_method("is_alive"):
			continue
		
		if not monster.is_alive():
			continue
		
		for hero in heroes:
			if not is_instance_valid(hero):
				continue
			
			var distance = hero.global_position.distance_to(monster.global_position)
			if distance < 400.0:
				monster_detected.emit(monster)
				return

func set_hero_mode(hero: Node2D, solo_mode: bool) -> void:
	if hero in hero_solo_mode:
		hero_solo_mode[hero] = solo_mode
		print(hero.name, " set to ", "SOLO" if solo_mode else "GROUP", " mode")

func get_hero_mode(hero: Node2D) -> bool:
	return hero_solo_mode.get(hero, false)

func get_exploration_progress() -> float:
	if fog_system:
		return fog_system.get_exploration_percentage()
	return 0.0

func force_update_targets() -> void:
	exploration_timer = 0.0
