extends Node
class_name HeroExplorationController

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
@export var prefer_forward_exploration: bool = true # NEW: Prefer exploring forward

@export_group("Movement Smoothing")
@export var use_formation: bool = true
@export var formation_spread: float = 100.0
## Followers keep their slot around the formation leader (HeroStats
## formation_rank 0, the tank), so the slowest hero sets the pace and the
## fastest melee no longer reaches every camp alone.
@export var formation_follow_leader: bool = true
@export var wander_while_moving: bool = true
@export var wander_strength: float = 50.0

var heroes: Array[Node2D] = []
var fog_system: FogOfWarSystem = null
var current_group_target: Vector2 = Vector2.ZERO
var exploration_timer: float = 0.0

var hero_formation_offset: Dictionary = {}
## Slot per hero in the leader's frame (x = forward, y = right), in units of
## formation_spread. Pets have no slot (they follow their owner).
var _formation_slots: Dictionary = {}
var _formation_leader: Node2D = null
var _heading: Vector2 = Vector2.RIGHT
## Diamond by formation rank: leader, two flanks a little behind, rear guard.
const FORMATION_SLOTS = [Vector2(0, 0), Vector2(-0.6, -1), Vector2(-0.6, 1), Vector2(-1.4, 0)]
var hero_last_positions: Dictionary = {}
var hero_stuck_timers: Dictionary = {}
var hero_stuck_anchor: Dictionary = {}

## Waypoints the group reached, newest last. Only the last
## RECENT_TARGET_MEMORY are kept (and read by _is_recently_explored).
var explored_targets: Array[Vector2] = []
const RECENT_TARGET_MEMORY: int = 5
## Waypoints the group stopped making progress toward (walled-off fog,
## unreachable pockets): skipped from then on so exploration moves on.
var _unreachable_targets: Array[Vector2] = []
var _stall_time: float = 0.0
var _last_group_center: Vector2 = Vector2.INF
## Seconds of < 60 px group progress (out of combat) before a waypoint is
## abandoned. The group used to sit in a corner for minutes.
@export var waypoint_stall_timeout: float = 9.0

func _ready() -> void:
	# NOTE: Group "HeroExplorationController" is declared in
	# HeroExplorationController.tscn (`groups=[...]`) so no add_to_group()
	# call is needed here. world.gd instantiates that scene.
	_apply_match_config(MatchConfig.for_current_match())
	await get_tree().process_frame
	_find_heroes()
	_find_fog_system()
	_setup_formation()

	if heroes.size() > 0:
		current_group_target = _calculate_group_center()

## Pre-round strategy (PreRoundSetup → MatchConfig) overrides the scene defaults.
func _apply_match_config(cfg: MatchConfig) -> void:
	exploration_update_interval = cfg.exploration_update_interval()
	search_radius_per_check = cfg.search_radius()
	formation_spread = cfg.formation_spread_px()


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

# ============================================
# PUBLIC API FOR HEROES TO USE
# ============================================

func get_current_group_target() -> Vector2:
	"""Get the current exploration target for heroes to use in idle"""
	return current_group_target

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
		if explored_targets.size() > RECENT_TARGET_MEMORY:
			explored_targets.pop_front()
	else:
		_track_stall(group_center)

	# Find next target preferring forward direction
	var unexplored_target = _find_next_exploration_zone(group_center)

	if unexplored_target != Vector2.ZERO:
		current_group_target = unexplored_target
	else:
		# Fallback: random unexplored area
		current_group_target = _get_random_unexplored_position(group_center)
	# The slots turn to the new target at once; make the leader re-pick its
	# idle goal now instead of walking to the old one for idle_retarget_time.
	if is_instance_valid(_formation_leader):
		if _formation_leader.has_method("set_exploration_target"):
			_formation_leader.set_exploration_target(current_group_target)
		if _formation_leader.has_method("request_idle_retarget"):
			_formation_leader.request_idle_retarget()

func _find_next_exploration_zone(from_position: Vector2) -> Vector2:
	if not fog_system:
		return Vector2.ZERO
	
	var best_target = Vector2.ZERO
	var best_score = - INF
	
	# Determine forward direction from group movement
	var group_velocity = _calculate_group_velocity()
	var forward_angle = group_velocity.angle() if group_velocity.length() > 1.0 else 0.0

	# Sample in a cone ahead if prefer_forward is enabled
	var angles = 12
	var distances = [300, 500, 700] # Explore further ahead
	
	for angle_step in angles:
		var base_angle = (angle_step / float(angles)) * TAU
		
		# Bias toward forward direction
		if prefer_forward_exploration and group_velocity.length() > 1.0:
			# Focus 60% of samples in forward 120-degree cone
			if randf() < 0.6:
				base_angle = forward_angle + randf_range(-PI / 3, PI / 3)
		
		var direction = Vector2.from_angle(base_angle)
		
		for distance in distances:
			var check_pos = from_position + direction * distance
			
			# Skip recently explored, abandoned and off-map points
			if _is_recently_explored(check_pos) or _is_abandoned(check_pos) or not _in_fog_bounds(check_pos):
				continue
			
			# Count unexplored tiles
			var unexplored_count = _count_unexplored_in_area(check_pos, 150.0)
			
			if unexplored_count > 0:
				# Calculate score
				var score = unexplored_count * 10.0
				
				# Bonus for forward direction
				if prefer_forward_exploration:
					var to_target = (check_pos - from_position).normalized()
					var angle_diff = abs(GameUtils.wrapped_angle_delta(forward_angle, to_target.angle()))
					score += (PI - angle_diff) * 50.0
				
				# Slight penalty for distance (prefer closer if equally good)
				score -= distance * 0.05
				
				if score > best_score:
					best_score = score
					best_target = check_pos
	
	return _snap_to_nav(best_target) if best_target != Vector2.ZERO else best_target


## Group made < 60 px of progress for waypoint_stall_timeout seconds while
## nobody fought: give the current waypoint up.
func _track_stall(group_center: Vector2) -> void:
	var fighting: bool = false
	for hero in heroes:
		if is_instance_valid(hero) and hero.has_method("is_target_valid") and hero.call("is_target_valid"):
			fighting = true
			break
	if fighting or not _last_group_center.is_finite() or group_center.distance_to(_last_group_center) > 60.0:
		_stall_time = 0.0
		_last_group_center = group_center
		return
	_stall_time += exploration_update_interval
	if _stall_time >= waypoint_stall_timeout:
		_unreachable_targets.append(current_group_target)
		if _unreachable_targets.size() > 32:
			_unreachable_targets.remove_at(0)
		_stall_time = 0.0
		_last_group_center = group_center


func _is_abandoned(pos: Vector2) -> bool:
	for t in _unreachable_targets:
		if t.distance_squared_to(pos) < 250.0 * 250.0:
			return true
	return false


func _in_fog_bounds(pos: Vector2) -> bool:
	if not fog_system:
		return true
	return Rect2(fog_system.world_offset, fog_system.world_size).has_point(pos)


## Closest walkable point (exploration samples land in walls and water).
func _snap_to_nav(pos: Vector2) -> Vector2:
	var nav_map: RID = GameUtils.usable_nav_map(get_viewport().world_2d if get_viewport() else null)
	if not nav_map.is_valid():
		return pos
	var on_mesh: Vector2 = NavigationServer2D.map_get_closest_point(nav_map, pos)
	return on_mesh if on_mesh != Vector2.ZERO else pos

func _get_random_unexplored_position(near_position: Vector2) -> Vector2:
	"""Find random unexplored position near group"""
	if not fog_system:
		return _get_random_map_position()
	
	# Try 10 random points, pick first unexplored one
	for i in range(10):
		var angle = randf() * TAU
		var distance = randf_range(300, 600)
		var candidate = near_position + Vector2.from_angle(angle) * distance
		
		if _in_fog_bounds(candidate) and not _is_abandoned(candidate) and not fog_system.is_tile_explored(candidate):
			return _snap_to_nav(candidate)
	
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
		
		if velocity.length() > 1.0: # Only count if actually moving
			total_velocity += velocity.normalized()
			count += 1
	
	return total_velocity / count if count > 0 else Vector2.ZERO


# ============================================
# REST OF EXISTING METHODS
# ============================================

func _cleanup_freed_heroes() -> void:
	var reslot: bool = false
	for i in range(heroes.size() - 1, -1, -1):
		var hero = heroes[i]
		
		if not is_instance_valid(hero):
			heroes.remove_at(i)
			hero_formation_offset.erase(hero)
			if _formation_slots.has(hero) or hero == _formation_leader:
				_formation_slots.erase(hero)
				reslot = true
			hero_last_positions.erase(hero)
			hero_stuck_timers.erase(hero)
			hero_stuck_anchor.erase(hero)
			cached_boids_data.erase(hero)
	# Re-rank the survivors in the same frame: until then followers fell back
	# to the far group target and ran ahead of the slow leader.
	if reslot:
		_setup_formation()

func _find_heroes() -> void:
	heroes.clear()
	# Same set the "Hero" group scan returned (heroes + pets present right now).
	var found_heroes := EntityRegistry.hero_side
	
	for hero in found_heroes:
		if hero is Node2D:
			heroes.append(hero)
			hero_last_positions[hero] = hero.global_position
			hero_stuck_timers[hero] = 0.0

func _find_fog_system() -> void:
	fog_system = EntityRegistry.singleton(&"FogOfWar") as FogOfWarSystem
	if not fog_system:
		push_warning("HeroExplorationController: No FogOfWar system found!")

func _setup_formation() -> void:
	hero_formation_offset.clear()
	_formation_slots.clear()
	_formation_leader = null
	var ordered: Array[Node2D] = []
	for hero in heroes:
		if is_instance_valid(hero) and hero is HeroBase:
			ordered.append(hero)
	if ordered.is_empty():
		return
	# Stable by rank: insertion keeps roster order among equal ranks.
	var ranked: Array[Node2D] = []
	for rank in range(3):
		for hero in ordered:
			if _formation_rank_of(hero) == rank:
				ranked.append(hero)
	for hero in ordered:
		if hero not in ranked:
			ranked.append(hero)
	for i in range(ranked.size()):
		var slot: Vector2 = FORMATION_SLOTS[i] if i < FORMATION_SLOTS.size() \
				else Vector2(-1.4 - 0.8 * (i - FORMATION_SLOTS.size() + 1), 0.0)
		_formation_slots[ranked[i]] = slot
	_formation_leader = ranked[0]
	_update_formation_offsets()


func _formation_rank_of(hero: Node2D) -> int:
	var stats := hero.get_node_or_null(^"HeroStats") as HeroStatsComponent
	if stats and stats.base_stats:
		return stats.base_stats.formation_rank
	return 1


func get_formation_leader() -> Node2D:
	return _formation_leader


## Rotate the slots into the direction of travel (leader -> group target).
func _update_formation_offsets() -> void:
	if not is_instance_valid(_formation_leader):
		return
	var to_target: Vector2 = current_group_target - _formation_leader.global_position
	if to_target.length_squared() > 40.0 * 40.0:
		_heading = to_target.normalized()
	var right: Vector2 = _heading.orthogonal()
	for hero in _formation_slots:
		var slot: Vector2 = _formation_slots[hero]
		hero_formation_offset[hero] = (_heading * slot.x + right * slot.y) * formation_spread


func _count_unexplored_in_area(center: Vector2, radius: float) -> int:
	if not fog_system:
		return 0
	
	var count = 0
	var step = exploration_tile_size * 2
	
	for x in range(-radius, radius, step):
		for y in range(-radius, radius, step):
			var check_pos = center + Vector2(x, y)
			
			if check_pos.distance_to(center) <= radius and _in_fog_bounds(check_pos):
				# Off-map tiles read as "unexplored" and dragged the group into
				# the map's edge for minutes.
				if not fog_system.is_tile_explored(check_pos):
					count += 1
	
	return count

func _is_recently_explored(pos: Vector2) -> bool:
	for t in explored_targets:
		if t.distance_to(pos) < 200.0:
			return true
	return false

func _update_hero_flow(delta: float) -> void:
	boids_timer -= delta
	
	if boids_timer <= 0.0:
		boids_timer = boids_update_interval
		_recalculate_boids()
	
	for hero in heroes:
		if is_instance_valid(hero):
			_apply_cached_boids(hero)

func _recalculate_boids() -> void:
	if not is_instance_valid(_formation_leader) and not heroes.is_empty():
		_setup_formation()
	_update_formation_offsets()
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
	if use_formation and formation_follow_leader and hero == _formation_leader:
		# The leader heads for the bare group target. Boids terms (separation
		# from a flank or the pet) pushed its goal past the target, the heading
		# reversed, and the whole formation shuttled around every waypoint.
		if hero.has_method("set_exploration_target"):
			hero.set_exploration_target(current_group_target)
		return
	var formation_offset: Vector2 = hero_formation_offset.get(hero, Vector2.ZERO)
	var base_target: Vector2 = current_group_target + formation_offset
	if use_formation and formation_follow_leader and is_instance_valid(_formation_leader) \
			and hero != _formation_leader and _formation_slots.has(hero):
		base_target = _formation_leader.global_position + formation_offset
	
	var final_target = base_target + data.separation * 1.5 + data.cohesion * 0.5 + data.alignment * 0.3
	
	if hero.has_method("set_exploration_target"):
		hero.set_exploration_target(final_target)

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
		
		# Stuck = not left a 5 px circle around an anchor for stuck_detection_time.
		# (Comparing with the previous FRAME flagged every walking hero: they
		# move ~1.3 px per frame.) Heroes fighting or parked at their goal are
		# not stuck.
		if not hero_stuck_anchor.has(hero):
			hero_stuck_anchor[hero] = current_pos
		var anchor: Vector2 = hero_stuck_anchor[hero]
		var busy: bool = hero.has_method("is_target_valid") and hero.call("is_target_valid")
		var goal: Variant = hero.get("exploration_target")
		var parked: bool = goal is Vector2 and current_pos.distance_to(goal) <= waypoint_reached_distance
		if busy or parked or current_pos.distance_to(anchor) > 5.0:
			hero_stuck_anchor[hero] = current_pos
			hero_stuck_timers[hero] = 0.0
		else:
			hero_stuck_timers[hero] += delta
			if hero_stuck_timers[hero] > stuck_detection_time:
				_unstuck_hero(hero)
				hero_stuck_timers[hero] = 0.0
				hero_stuck_anchor[hero] = current_pos

		hero_last_positions[hero] = current_pos  # per-frame: velocity / alignment

func _unstuck_hero(hero: Node2D) -> void:
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
