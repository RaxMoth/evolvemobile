extends Node
class_name HeroExplorationController

signal exploration_target_reached(position: Vector2)
signal monster_detected(monster: Node2D)

@export_group("Group Behavior")
@export var group_exploration_enabled: bool = true
@export var group_cohesion_radius: float = 200.0
@export var personal_space_radius: float = 80.0  # Heroes avoid getting too close
@export var exploration_update_interval: float = 3.0

@export_group("Exploration Settings")
@export var exploration_tile_size: int = 32
@export var search_radius_per_check: float = 400.0
@export var waypoint_reached_distance: float = 100.0  # More forgiving
@export var stuck_detection_time: float = 5.0  # Detect if hero is stuck

@export_group("Movement Smoothing")
@export var use_formation: bool = true  # Heroes move in formation
@export var formation_spread: float = 100.0  # Distance between formation positions
@export var wander_while_moving: bool = true  # Add organic movement
@export var wander_strength: float = 50.0

var heroes: Array[Node2D] = []
var fog_system: FogOfWarSystem = null
var current_group_target: Vector2 = Vector2.ZERO
var exploration_timer: float = 0.0

# Individual hero data
var hero_solo_mode: Dictionary = {}
var hero_formation_offset: Dictionary = {}  # hero -> Vector2
var hero_last_positions: Dictionary = {}  # Track for stuck detection
var hero_stuck_timers: Dictionary = {}

# Exploration memory
var explored_targets: Array[Vector2] = []  # Remember where we've been
var current_exploration_zone: Vector2 = Vector2.ZERO

func _ready() -> void:
	await get_tree().process_frame
	_find_heroes()
	_find_fog_system()
	_setup_formation()
	
	if heroes.size() > 0:
		current_group_target = _calculate_group_center()

func _process(delta: float) -> void:
	if not group_exploration_enabled or heroes.is_empty():
		return
	
	exploration_timer -= delta
	
	if exploration_timer <= 0.0:
		exploration_timer = exploration_update_interval
		_update_exploration_targets()
	
	# Update hero targets with flow and avoidance
	_update_hero_flow(delta)
	
	# Check for stuck heroes
	_check_stuck_heroes(delta)
	
	# Check for monsters
	_check_for_monsters()

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
	# Assign formation positions (diamond shape)
	if heroes.size() == 0:
		return
	
	var formations = [
		Vector2(0, 0),           # Leader (center)
		Vector2(-1, -1),         # Back left
		Vector2(1, -1),          # Back right
		Vector2(0, 1),           # Front
	]
	
	for i in range(heroes.size()):
		var hero = heroes[i]
		var formation_index = i % formations.size()
		hero_formation_offset[hero] = formations[formation_index] * formation_spread

func _update_exploration_targets() -> void:
	if not fog_system:
		return
	
	var group_center = _calculate_group_center()
	
	# Check if we've reached current target
	if group_center.distance_to(current_group_target) < waypoint_reached_distance:
		explored_targets.append(current_group_target)
	
	# Find next unexplored area
	var unexplored_target = _find_next_exploration_zone(group_center)
	
	if unexplored_target != Vector2.ZERO:
		current_group_target = unexplored_target
		current_exploration_zone = unexplored_target
		exploration_target_reached.emit(unexplored_target)
		print("New exploration zone: ", unexplored_target)
	else:
		# Map fully explored, pick random area
		current_group_target = _get_random_map_position()

func _find_next_exploration_zone(from_position: Vector2) -> Vector2:
	if not fog_system:
		return Vector2.ZERO
	
	var best_target = Vector2.ZERO
	var best_score = -INF
	
	# Sample in a larger pattern
	var angles = 8  # Check 8 directions
	var distances = [200, 400, 600]  # Check at different distances
	
	for angle_step in angles:
		var angle = (angle_step / float(angles)) * TAU
		var direction = Vector2.from_angle(angle)
		
		for distance in distances:
			var check_pos = from_position + direction * distance
			
			# Skip if we've recently been here
			if _is_recently_explored(check_pos):
				continue
			
			# Check unexplored tiles in this area
			var unexplored_count = _count_unexplored_in_area(check_pos, 150.0)
			
			if unexplored_count > 0:
				# Score based on unexplored count and distance
				var score = unexplored_count * 10.0 - (distance * 0.1)
				
				if score > best_score:
					best_score = score
					best_target = check_pos
	
	return best_target

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
	var recent_memory = 5  # Remember last 5 targets
	var check_count = min(recent_memory, explored_targets.size())
	
	for i in range(explored_targets.size() - check_count, explored_targets.size()):
		if explored_targets[i].distance_to(position) < 200.0:
			return true
	
	return false

func _update_hero_flow(delta: float) -> void:
	# Apply smooth flowing movement to each hero
	for hero in heroes:
		if not is_instance_valid(hero):
			continue
		
		if hero_solo_mode.get(hero, false):
			_update_solo_hero(hero, delta)
		else:
			_update_group_hero(hero, delta)

func _update_group_hero(hero: Node2D, delta: float) -> void:
	# Calculate target with formation offset
	var formation_offset = hero_formation_offset.get(hero, Vector2.ZERO)
	var base_target = current_group_target + formation_offset
	
	# Add separation from other heroes (boids-like behavior)
	var separation = _calculate_separation(hero)
	
	# Add cohesion (stay near group)
	var cohesion = _calculate_cohesion(hero)
	
	# Add alignment (move in same direction as group)
	var alignment = _calculate_alignment(hero)
	
	# Add wandering for organic movement
	var wander = Vector2.ZERO
	if wander_while_moving:
		var time = Time.get_ticks_msec() / 1000.0
		wander = Vector2(
			sin(time * 2.0 + hero.get_instance_id()) * wander_strength,
			cos(time * 1.5 + hero.get_instance_id()) * wander_strength
		)
	
	# Combine all forces
	var final_target = base_target + separation * 1.5 + cohesion * 0.5 + alignment * 0.3 + wander
	
	# Smooth target update
	if hero.has_method("set_exploration_target"):
		hero.set_exploration_target(final_target)

func _update_solo_hero(hero: Node2D, delta: float) -> void:
	# Solo heroes explore independently
	var unexplored = _find_next_exploration_zone(hero.global_position)
	
	if unexplored != Vector2.ZERO:
		# Add some wander
		var wander = Vector2(
			randf_range(-wander_strength, wander_strength),
			randf_range(-wander_strength, wander_strength)
		)
		
		if hero.has_method("set_exploration_target"):
			hero.set_exploration_target(unexplored + wander)

func _calculate_separation(hero: Node2D) -> Vector2:
	# Push away from nearby heroes
	var separation = Vector2.ZERO
	var nearby_count = 0
	
	for other_hero in heroes:
		if other_hero == hero or not is_instance_valid(other_hero):
			continue
		
		var distance = hero.global_position.distance_to(other_hero.global_position)
		
		if distance < personal_space_radius and distance > 0:
			var push_away = (hero.global_position - other_hero.global_position).normalized()
			var strength = 1.0 - (distance / personal_space_radius)
			separation += push_away * strength * personal_space_radius
			nearby_count += 1
	
	if nearby_count > 0:
		separation /= nearby_count
	
	return separation

func _calculate_cohesion(hero: Node2D) -> Vector2:
	# Pull toward group center
	var group_center = _calculate_group_center()
	var distance = hero.global_position.distance_to(group_center)
	
	if distance > group_cohesion_radius:
		return (group_center - hero.global_position).normalized() * (distance - group_cohesion_radius)
	
	return Vector2.ZERO

func _calculate_alignment(hero: Node2D) -> Vector2:
	# Move in average direction of group
	var avg_velocity = Vector2.ZERO
	var count = 0
	
	for other_hero in heroes:
		if other_hero == hero or not is_instance_valid(other_hero):
			continue
		
		if hero.global_position.distance_to(other_hero.global_position) < group_cohesion_radius:
			# Estimate velocity from position change
			var current_pos = other_hero.global_position
			var last_pos = hero_last_positions.get(other_hero, current_pos)
			avg_velocity += (current_pos - last_pos)
			count += 1
	
	if count > 0:
		return avg_velocity / count * 50.0  # Scale factor
	
	return Vector2.ZERO

func _check_stuck_heroes(delta: float) -> void:
	for hero in heroes:
		if not is_instance_valid(hero):
			continue
		
		var current_pos = hero.global_position
		var last_pos = hero_last_positions.get(hero, current_pos)
		
		# Check if hero moved significantly
		if current_pos.distance_to(last_pos) < 5.0:  # Barely moved
			hero_stuck_timers[hero] += delta
			
			if hero_stuck_timers[hero] > stuck_detection_time:
				# Hero is stuck! Give them a new target
				print(hero.name, " is stuck! Finding new path...")
				_unstuck_hero(hero)
				hero_stuck_timers[hero] = 0.0
		else:
			hero_stuck_timers[hero] = 0.0
		
		hero_last_positions[hero] = current_pos

func _unstuck_hero(hero: Node2D) -> void:
	# Push hero in a random direction to unstuck
	var random_offset = Vector2(
		randf_range(-150, 150),
		randf_range(-150, 150)
	)
	
	var unstuck_target = hero.global_position + random_offset
	
	if hero.has_method("set_exploration_target"):
		hero.set_exploration_target(unstuck_target)

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
