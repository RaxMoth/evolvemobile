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
## Not an export: _apply_match_config sets it from MatchConfig in _ready.
var exploration_update_interval: float = 3.0

@export_group("Exploration Settings")
@export var exploration_tile_size: int = 32
## How far ahead the group looks for unexplored ground (the pre-round
## forecast's "scanning N px ahead", 300-600 px by the Exploration dial).
## _sample_distances and the random fallback are built around it.
## Not an export: _apply_match_config sets it from MatchConfig in _ready.
var search_radius_per_check: float = 450.0
@export var waypoint_reached_distance: float = 100.0
@export var stuck_detection_time: float = 5.0
## A hero that stays inside this radius for stuck_detection_time (out of combat,
## away from its goal) is stuck. 5 px missed heroes jittering in a corner.
@export var stuck_radius: float = 24.0
## How long a stuck hero follows its detour before formation takes over again.
@export var detour_time: float = 4.0
@export var prefer_forward_exploration: bool = true # NEW: Prefer exploring forward

@export_group("Movement Smoothing")
@export var use_formation: bool = true
## Not an export: _apply_match_config sets it from MatchConfig in _ready.
var formation_spread: float = 100.0
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
## hero -> [detour target, seconds left]: honoured by _apply_cached_boids, which
## otherwise rewrites every exploration target 10x per second.
var _detours: Dictionary = {}

## Waypoints the group reached, newest last. Only the last
## recent_target_memory are kept (and read by _is_recently_explored): with 5
## the group cycled over the same explored edge points for minutes.
var explored_targets: Array[Vector2] = []
@export var recent_target_memory: int = 12
## _disc_grid's cache: the in-disc grid offsets for _disc_radius/_disc_step.
var _disc_offsets: PackedVector2Array = PackedVector2Array()
var _disc_radius: float = -1.0
var _disc_step: int = 0
## Waypoints the group stopped making progress toward (walled-off fog,
## unreachable pockets): skipped from then on so exploration moves on.
var _unreachable_targets: Array[Vector2] = []
var _stall_time: float = 0.0
var _last_group_center: Vector2 = Vector2.INF
## Seconds of < 60 px group progress (out of combat) before a waypoint is
## abandoned. The group used to sit in a corner for minutes.
@export var waypoint_stall_timeout: float = 9.0

@export_group("Walk Mask")
## Wall-clock time the walk mask may take to fill per frame
## (Time.get_ticks_usec), so the fill spreads over the first frames of a
## match instead of one load hitch.
@export var walk_mask_budget_usec: int = 500
## Which fog is ground the group can walk on (README Hero Exploration AI
## "Walkable fog"): one byte per WALK_CELL px cell over the fog rect, WALK_YES
## when the navigation mesh lies within WALK_REACH px of the cell's centre,
## else WALK_NO (walls, water, the void past the map's walkable edge, which
## stays fog for good and outscored every real waypoint). It is rasterized
## from the polygons of the map's NavigationRegion2Ds, one polygon after the
## other: a closest-point query costs about 60 us on the world's 2,056
## polygons, 0.65 s for the 11,092 cells. _process fills it within
## walk_mask_budget_usec a frame; the AI reads it from its second exploration
## update on (_walk_ready), when _prepare_walk_mask completes it if the
## frames did not, so its decisions never depend on how fast the frames were.
const WALK_CELL: float = 64.0
const WALK_REACH: float = 32.0
const WALK_NO: int = 0
const WALK_YES: int = 1
var _walk_mask: PackedByteArray = PackedByteArray()
var _walk_cols: int = 0
var _walk_rows: int = 0
var _walk_origin: Vector2 = Vector2.ZERO
## The regions the mask is rasterized from, the one being rasterized (its
## polygon cursor and global vertices) and the polygons done of them all.
var _walk_regions: Array[NavigationRegion2D] = []
var _walk_region_i: int = 0
var _walk_poly_i: int = 0
var _walk_verts: PackedVector2Array = PackedVector2Array()
var _walk_polys_total: int = 0
var _walk_polys_done: int = 0
var _walk_done: bool = false
## The WALK_YES cells, in index order (once done).
var _walk_cells: PackedInt32Array = PackedInt32Array()
var _walk_ready: bool = false
## Exploration updates so far: the first one (match start) runs without the
## mask, every later one with the complete mask.
var _exploration_updates: int = 0
## F3: the walkable unexplored cells, counted at most once a second.
var _debug_fog_cells: int = 0
var _debug_fog_at_msec: int = -1000000

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

## Pre-round strategy (PreRoundScreen → MatchConfig): the only writer of
## exploration_update_interval, search_radius_per_check and formation_spread.
func _apply_match_config(cfg: MatchConfig) -> void:
	exploration_update_interval = cfg.exploration_update_interval()
	search_radius_per_check = cfg.search_radius()
	formation_spread = cfg.formation_spread_px()


func _process(delta: float) -> void:
	if not group_exploration_enabled or heroes.is_empty():
		return
	_cleanup_freed_heroes()
	
	_fill_walk_mask(walk_mask_budget_usec)
	exploration_timer -= delta
	
	if exploration_timer <= 0.0:
		# Keep the overshoot so the updates keep their interval at any step
		# size (one huge step still fires once).
		exploration_timer += exploration_update_interval
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
	_exploration_updates += 1
	if _exploration_updates > 1:
		_prepare_walk_mask()
	
	# Check if we reached the current target
	if group_center.distance_to(current_group_target) < waypoint_reached_distance:
		explored_targets.append(current_group_target)
		while explored_targets.size() > recent_target_memory:
			explored_targets.pop_front()
	else:
		_track_stall(group_center)

	# Find next target preferring forward direction
	var unexplored_target = _find_next_exploration_zone(group_center)

	if unexplored_target != Vector2.ZERO:
		current_group_target = unexplored_target
	else:
		# Fallback: random unexplored area, then the nearest walkable fog
		# anywhere on the map, then any reachable point
		current_group_target = _get_random_unexplored_position(group_center)
	# The slots turn to the new target at once; make the leader re-pick its
	# idle goal now instead of walking to the old one for idle_retarget_time.
	if is_instance_valid(_formation_leader):
		var lead := _formation_leader as HeroBase  # _setup_formation ranks HeroBase only
		lead.set_exploration_target(current_group_target)
		lead.request_idle_retarget()

func _find_next_exploration_zone(from_position: Vector2) -> Vector2:
	if not fog_system:
		return Vector2.ZERO
	
	var candidates: Array = []  # [score, sample position], best first after sorting
	var fog_rect: Rect2 = _fog_rect()

	# Determine forward direction from group movement
	var group_velocity = _calculate_group_velocity()
	var forward_angle = group_velocity.angle() if group_velocity.length() > 1.0 else 0.0

	# Sample in a cone ahead if prefer_forward is enabled
	var angles = 12
	var distances: Array[float] = _sample_distances()
	
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
			if _is_recently_explored(check_pos) or _is_abandoned(check_pos) or not fog_rect.has_point(check_pos):
				continue
			
			# Count unexplored tiles
			var unexplored_count = _count_unexplored_in_area(check_pos, 150.0, fog_rect)
			
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
				candidates.append([score, check_pos])

	# Best first; equal scores keep sampling order (the old strict ">" kept the first).
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	return _first_reachable(candidates.map(func(c: Array) -> Vector2: return c[1]))


## The three distances _find_next_exploration_zone samples at, from the
## Exploration dial's search_radius_per_check r: r - 150, r + 50 and r + 250
## px. The default dial (r = 450) gives the 300 / 500 / 700 px the group
## always sampled; Methodical (300) looks 150 px nearer, Roam wide (600)
## 150 px further.
func _sample_distances() -> Array[float]:
	var r: float = search_radius_per_check
	return [r - 150.0, r + 50.0, r + 250.0]


## How many candidate waypoints may cost a path query per exploration update.
const MAX_REACH_CHECKS: int = 8

## First candidate the group can actually walk to, snapped onto the mesh.
## Samples inside a wall snapped to the closest walkable point — often one of
## the map's sealed one-tile islands — and the leader (with the whole group
## behind it) stood at the wall facing it for half a minute. Unreachable
## candidates are remembered so later samples around them are skipped too.
## A sample whose closest walkable point is ground the group stands on or
## reached lately is no waypoint either: past the map's walkable edge the fog
## stays unexplored for good, every sample out there snapped back onto the
## group's own spot, the group "reached" it at once and stood there for the
## rest of the match (Nyxa seed 15: 490 s at the east edge).
func _first_reachable(positions: Array, max_checks: int = MAX_REACH_CHECKS) -> Vector2:
	var world: World2D = get_viewport().world_2d if get_viewport() else null
	var from: Vector2 = _formation_leader.global_position if is_instance_valid(_formation_leader) else _calculate_group_center()
	var center: Vector2 = _calculate_group_center()
	var checks: int = 0
	for p: Vector2 in positions:
		var on_mesh: Vector2 = _snap_to_nav(p)
		if _is_abandoned(on_mesh) or _is_recently_explored(on_mesh) \
				or on_mesh.distance_to(center) < waypoint_reached_distance:
			continue
		if GameUtils.nav_path_reaches(world, from, on_mesh):
			return on_mesh
		_mark_unreachable(on_mesh)
		checks += 1
		if checks >= max_checks:
			break
	return Vector2.ZERO


func _mark_unreachable(pos: Vector2) -> void:
	_unreachable_targets.append(pos)
	if _unreachable_targets.size() > 32:
		_unreachable_targets.remove_at(0)


## Group made < 60 px of progress for waypoint_stall_timeout seconds while
## nobody fought: give the current waypoint up.
func _track_stall(group_center: Vector2) -> void:
	var fighting: bool = false
	for hero in heroes:
		if not is_instance_valid(hero):
			continue
		var h := hero as HeroBase
		if h and h.is_target_valid():
			fighting = true
			break
	if fighting or not _last_group_center.is_finite() or group_center.distance_to(_last_group_center) > 60.0:
		_stall_time = 0.0
		_last_group_center = group_center
		return
	_stall_time += exploration_update_interval
	if _stall_time >= waypoint_stall_timeout:
		_mark_unreachable(current_group_target)
		_stall_time = 0.0
		_last_group_center = group_center


func _is_abandoned(pos: Vector2) -> bool:
	for t in _unreachable_targets:
		if t.distance_squared_to(pos) < 250.0 * 250.0:
			return true
	return false


## The fog's world rectangle: samples and tiles outside it are off the map.
## Callers check fog_system first.
func _fog_rect() -> Rect2:
	return Rect2(fog_system.world_offset, fog_system.world_size)


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
	
	# Try 10 random points within 150 px of the dial's scan radius (300-600 px
	# at the default); the first unexplored one the group can reach wins
	var fog_rect: Rect2 = _fog_rect()
	var candidates: Array = []
	for i in range(10):
		var angle = randf() * TAU
		var distance = randf_range(search_radius_per_check - 150.0, search_radius_per_check + 150.0)
		var candidate = near_position + Vector2.from_angle(angle) * distance

		if fog_rect.has_point(candidate) and not _is_abandoned(candidate) and not fog_system.is_tile_explored(candidate) \
				and _is_walkable(candidate):
			candidates.append(candidate)
	var reachable: Vector2 = _first_reachable(candidates)
	if reachable != Vector2.ZERO:
		return reachable
	# No walkable fog around: the nearest anywhere on the map (the west third
	# stayed unexplored all match while the group paced the explored east).
	reachable = _nearest_walkable_unexplored(near_position)
	if reachable != Vector2.ZERO:
		return reachable

	# Fallback: anywhere on the map the group can walk to
	var world: World2D = get_viewport().world_2d if get_viewport() else null
	return GameUtils.random_reachable_point(world, fog_rect, near_position, _get_random_map_position())

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
			_detours.erase(hero)
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
	var world: World2D = get_viewport().world_2d if get_viewport() else null
	var lead: Vector2 = _formation_leader.global_position
	for hero in _formation_slots:
		var slot: Vector2 = _formation_slots[hero]
		var offset: Vector2 = (_heading * slot.x + right * slot.y) * formation_spread
		# A slot inside a wall sent its hero to the closest walkable point —
		# often across the wall, in another corridor — where it stood for half
		# a minute. Pull the slot back along the line to the leader instead.
		if not GameUtils.is_on_nav(world, lead + offset):
			offset = GameUtils.clamp_to_nav_segment(world, lead, lead + offset, 16.0) - lead
		hero_formation_offset[hero] = offset


## Unexplored fog tiles on a grid (two tiles apart) inside the disc around
## center. Only points inside fog_rect count: off-map tiles read as
## "unexplored" and dragged the group into the map's edge for minutes. With
## the walk mask ready only walkable ones count: fog on walls and in the void
## past the walkable edge stays unexplored for good.
func _count_unexplored_in_area(center: Vector2, radius: float, fog_rect: Rect2) -> int:
	if not fog_system:
		return 0
	
	var count: int = 0
	var offsets: PackedVector2Array = _disc_grid(radius, exploration_tile_size * 2)
	if _walk_ready:
		for off: Vector2 in offsets:
			var p: Vector2 = center + off
			var i: int = _walk_index(p)
			if i >= 0 and _walk_mask[i] != WALK_NO and not fog_system.is_tile_explored(p):
				count += 1
	# The whole disc on the map (the usual case): no per-point bounds test.
	elif fog_rect.encloses(Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0)):
		for off: Vector2 in offsets:
			if not fog_system.is_tile_explored(center + off):
				count += 1
	else:
		for off: Vector2 in offsets:
			var check_pos: Vector2 = center + off
			if fog_rect.has_point(check_pos) and not fog_system.is_tile_explored(check_pos):
				count += 1
	
	return count


# ============================================
# Walk mask (README Hero Exploration AI "Walkable fog")
# ============================================

## Rasterize navigation polygons into the walk mask until budget_usec of
## wall-clock time have passed (at least one polygon a call), once the nav map
## is usable. Its cells only reach a decision through _prepare_walk_mask, so
## the budget never changes what the AI does.
func _fill_walk_mask(budget_usec: int) -> void:
	if _walk_done or fog_system == null:
		return
	if _walk_regions.is_empty():
		if not _start_walk_mask():
			return
		if budget_usec < 1 << 62:
			return  # the set-up has this frame's budget; polygons from the next
	var start: int = Time.get_ticks_usec()
	while _walk_region_i < _walk_regions.size():
		var region: NavigationRegion2D = _walk_regions[_walk_region_i]
		var poly_count: int = region.navigation_polygon.get_polygon_count() if is_instance_valid(region) else 0
		if _walk_poly_i >= poly_count:
			_walk_region_i += 1
			_walk_poly_i = 0
			if _walk_region_i < _walk_regions.size() and is_instance_valid(_walk_regions[_walk_region_i]):
				var next: NavigationRegion2D = _walk_regions[_walk_region_i]
				_walk_verts = next.global_transform * next.navigation_polygon.get_vertices()
			continue
		_rasterize_polygon(region.navigation_polygon.get_polygon(_walk_poly_i))
		_walk_poly_i += 1
		_walk_polys_done += 1
		if Time.get_ticks_usec() - start >= budget_usec:
			return
	_walk_done = true
	for i in _walk_mask.size():
		if _walk_mask[i] == WALK_YES:
			_walk_cells.append(i)


## Size the mask to the fog rect and list the enabled NavigationRegion2Ds of
## the world's map (the World's one baked region; the tests' baked rects).
## False while the map is not usable yet or has no polygons (then
## _walk_regions stays empty and the next call tries again).
func _start_walk_mask() -> bool:
	var world: World2D = get_viewport().world_2d if get_viewport() else null
	var nav_map: RID = GameUtils.usable_nav_map(world)
	if not nav_map.is_valid():
		return false
	for node: Node in get_tree().root.find_children("*", "NavigationRegion2D", true, false):
		var region := node as NavigationRegion2D
		if region.enabled and region.navigation_polygon != null and region.get_navigation_map() == nav_map:
			_walk_regions.append(region)
			_walk_polys_total += region.navigation_polygon.get_polygon_count()
	if _walk_polys_total == 0:
		_walk_regions.clear()
		return false
	var rect: Rect2 = _fog_rect()
	_walk_origin = rect.position
	_walk_cols = ceili(rect.size.x / WALK_CELL)
	_walk_rows = ceili(rect.size.y / WALK_CELL)
	_walk_mask.resize(_walk_cols * _walk_rows)
	_walk_mask.fill(WALK_NO)
	_walk_verts = _walk_regions[0].global_transform * _walk_regions[0].navigation_polygon.get_vertices()
	return true


## Mark WALK_YES every cell whose centre lies in the polygon (indices into
## _walk_verts) or within WALK_REACH px of its outline.
func _rasterize_polygon(indices: PackedInt32Array) -> void:
	var n: int = indices.size()
	if n < 3:
		return
	var poly := PackedVector2Array()
	poly.resize(n)
	var lo: Vector2 = _walk_verts[indices[0]]
	var hi: Vector2 = lo
	for k in n:
		var v: Vector2 = _walk_verts[indices[k]]
		poly[k] = v
		lo = lo.min(v)
		hi = hi.max(v)
	var c0: int = maxi(0, floori((lo.x - WALK_REACH - _walk_origin.x) / WALK_CELL - 0.5))
	var c1: int = mini(_walk_cols - 1, ceili((hi.x + WALK_REACH - _walk_origin.x) / WALK_CELL - 0.5))
	var r0: int = maxi(0, floori((lo.y - WALK_REACH - _walk_origin.y) / WALK_CELL - 0.5))
	var r1: int = mini(_walk_rows - 1, ceili((hi.y + WALK_REACH - _walk_origin.y) / WALK_CELL - 0.5))
	for row in range(r0, r1 + 1):
		for col in range(c0, c1 + 1):
			var i: int = row * _walk_cols + col
			if _walk_mask[i] == WALK_YES:
				continue
			var c: Vector2 = _walk_origin + (Vector2(col, row) + Vector2(0.5, 0.5)) * WALK_CELL
			if c.x < lo.x - WALK_REACH or c.x > hi.x + WALK_REACH or c.y < lo.y - WALK_REACH or c.y > hi.y + WALK_REACH:
				continue
			if Geometry2D.is_point_in_polygon(c, poly) or _near_outline(c, poly):
				_walk_mask[i] = WALK_YES


func _near_outline(c: Vector2, poly: PackedVector2Array) -> bool:
	var prev: Vector2 = poly[poly.size() - 1]
	for v: Vector2 in poly:
		if Geometry2D.get_closest_point_to_segment(c, prev, v).distance_squared_to(c) <= WALK_REACH * WALK_REACH:
			return true
		prev = v
	return false


## Complete the walk mask now if the frames did not (the AI's second
## exploration update on; tests). True when it is ready.
func _prepare_walk_mask() -> bool:
	if not _walk_ready:
		_fill_walk_mask(1 << 62)
		_walk_ready = _walk_done
	return _walk_ready


func _walk_cell_center(i: int) -> Vector2:
	var row: int = floori(float(i) / float(_walk_cols))
	return _walk_origin + (Vector2(i - row * _walk_cols, row) + Vector2(0.5, 0.5)) * WALK_CELL


## The walk-mask cell of `pos`, -1 off the mask.
func _walk_index(pos: Vector2) -> int:
	var col: int = floori((pos.x - _walk_origin.x) / WALK_CELL)
	var row: int = floori((pos.y - _walk_origin.y) / WALK_CELL)
	if col < 0 or col >= _walk_cols or row < 0 or row >= _walk_rows:
		return -1
	return row * _walk_cols + col


## Ground the group may explore: any point until the mask is ready, then a
## walkable cell's.
func _is_walkable(pos: Vector2) -> bool:
	if not _walk_ready:
		return true
	var i: int = _walk_index(pos)
	return i >= 0 and _walk_mask[i] != WALK_NO


## How many cells' worth of nearest walkable fog _nearest_walkable_unexplored
## hands to _first_reachable, and how many path checks it may cost.
const NEAREST_FOG_CELLS: int = 24
const NEAREST_FOG_CHECKS: int = 4


## The nearest walkable cell anywhere on the map whose centre is still fog
## and that the group can walk to (at most NEAREST_FOG_CHECKS path checks),
## snapped onto the mesh; ZERO when the mask is not ready or nothing is left.
func _nearest_walkable_unexplored(center: Vector2) -> Vector2:
	if not _walk_ready or fog_system == null:
		return Vector2.ZERO
	# The NEAREST_FOG_CELLS nearest, kept sorted (nearest first) as they come.
	var dists := PackedFloat32Array()
	var nearest: Array[Vector2] = []
	for i: int in _walk_cells:
		var c: Vector2 = _walk_cell_center(i)
		var d: float = center.distance_squared_to(c)
		if nearest.size() >= NEAREST_FOG_CELLS and d >= dists[dists.size() - 1]:
			continue
		if fog_system.is_tile_explored(c) or _is_abandoned(c):
			continue
		var at: int = dists.bsearch(d, false)
		dists.insert(at, d)
		nearest.insert(at, c)
		if nearest.size() > NEAREST_FOG_CELLS:
			dists.resize(NEAREST_FOG_CELLS)
			nearest.resize(NEAREST_FOG_CELLS)
	return _first_reachable(nearest, NEAREST_FOG_CHECKS)


## F3 (debug_overlay): how much of the walk mask is filled, and how many of
## its walkable cells are still fog ("mask 87%  walkable fog 1234").
func debug_line() -> String:
	if _walk_mask.is_empty():
		return "Explore: mask -"
	var now: int = Time.get_ticks_msec()
	if now - _debug_fog_at_msec >= 1000 and fog_system != null:
		_debug_fog_at_msec = now
		_debug_fog_cells = 0
		for i in _walk_mask.size():
			if _walk_mask[i] == WALK_YES and not fog_system.is_tile_explored(_walk_cell_center(i)):
				_debug_fog_cells += 1
	return "Explore: mask %d%%%s  walkable fog %d" % [roundi(100.0 * _walk_polys_done / maxi(1, _walk_polys_total)),
			"" if _walk_ready else " (not used yet)", _debug_fog_cells]


## Grid offsets (step apart) within radius of the origin, built once per
## radius and step: every exploration update counts 36 discs of 16 points.
func _disc_grid(radius: float, step: int) -> PackedVector2Array:
	if radius == _disc_radius and step == _disc_step:
		return _disc_offsets
	_disc_radius = radius
	_disc_step = step
	_disc_offsets = PackedVector2Array()
	for x in range(-radius, radius, step):
		for y in range(-radius, radius, step):
			var off := Vector2(x, y)
			if off.length() <= radius:
				_disc_offsets.append(off)
	return _disc_offsets

func _is_recently_explored(pos: Vector2) -> bool:
	for t in explored_targets:
		if t.distance_squared_to(pos) < 200.0 * 200.0:
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
	# Nobody moves during the pass: one group centre serves every hero.
	var center: Vector2 = _calculate_group_center()
	for hero in heroes:
		if not is_instance_valid(hero):
			continue
		
		var separation = _calculate_separation(hero)
		var cohesion = _calculate_cohesion(hero, center)
		var alignment = _calculate_alignment(hero)
		
		cached_boids_data[hero] = {
			"separation": separation,
			"cohesion": cohesion,
			"alignment": alignment
		}

func _apply_cached_boids(hero: Node2D) -> void:
	# Ted's pet follows its owner: it has no exploration target to set.
	var h := hero as HeroBase
	if h == null or not cached_boids_data.has(hero):
		return
	
	var data = cached_boids_data[hero]
	if _detours.has(hero):
		var detour: Vector2 = _detours[hero][0]
		h.set_exploration_target(detour)
		return
	if use_formation and formation_follow_leader and hero == _formation_leader:
		# The leader heads for the bare group target. Boids terms (separation
		# from a flank or the pet) pushed its goal past the target, the heading
		# reversed, and the whole formation shuttled around every waypoint.
		h.set_exploration_target(current_group_target)
		return
	var formation_offset: Vector2 = hero_formation_offset.get(hero, Vector2.ZERO)
	var base_target: Vector2 = current_group_target + formation_offset
	if use_formation and formation_follow_leader and is_instance_valid(_formation_leader) \
			and hero != _formation_leader and _formation_slots.has(hero):
		base_target = _formation_leader.global_position + formation_offset
	
	var final_target: Vector2 = base_target + data.separation * 1.5 + data.cohesion * 0.5 + data.alignment * 0.3
	h.set_exploration_target(final_target)

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

## center: the group centre (_recalculate_boids computes it once per pass).
func _calculate_cohesion(hero: Node2D, center: Vector2) -> Vector2:
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
		
		_tick_detour(hero, current_pos, delta)
		# Stuck = not left a stuck_radius circle around an anchor for
		# stuck_detection_time. (Comparing with the previous FRAME flagged every
		# walking hero: they move ~1.3 px per frame.) Heroes fighting or parked
		# at their goal are not stuck.
		if not hero_stuck_anchor.has(hero):
			hero_stuck_anchor[hero] = current_pos
		var anchor: Vector2 = hero_stuck_anchor[hero]
		# Ted's pet (no HeroBase) is never busy or parked.
		var h := hero as HeroBase
		var busy: bool = h != null and h.is_target_valid()
		var parked: bool = h != null and current_pos.distance_to(h.exploration_target) <= waypoint_reached_distance
		if busy or parked or current_pos.distance_to(anchor) > stuck_radius:
			hero_stuck_anchor[hero] = current_pos
			hero_stuck_timers[hero] = 0.0
		else:
			hero_stuck_timers[hero] += delta
			if hero_stuck_timers[hero] > stuck_detection_time:
				_unstuck_hero(hero)
				hero_stuck_timers[hero] = 0.0
				hero_stuck_anchor[hero] = current_pos

		hero_last_positions[hero] = current_pos  # per-frame: velocity / alignment

## A stuck leader means the group target cannot be reached from here: give it
## up and pick a new (reachable) one at once. A stuck follower — or a leader
## with nothing better to go to — walks a reachable detour for detour_time.
func _unstuck_hero(hero: Node2D) -> void:
	if hero == _formation_leader and fog_system:
		var old_target: Vector2 = current_group_target
		_mark_unreachable(old_target)
		_update_exploration_targets()
		if current_group_target.distance_to(old_target) > waypoint_reached_distance:
			return
	var world: World2D = get_viewport().world_2d if get_viewport() else null
	var pos: Vector2 = hero.global_position
	var detour: Vector2 = GameUtils.random_reachable_point(world, Rect2(pos - Vector2(200, 200), Vector2(400, 400)), pos, Vector2.INF)
	if not detour.is_finite():
		# No navigation to ask (yet): any point clearly away from here.
		detour = pos + Vector2.from_angle(randf() * TAU) * randf_range(120.0, 200.0)
	_detours[hero] = [detour, detour_time]
	var h := hero as HeroBase
	if h:
		h.set_exploration_target(detour)
		h.request_idle_retarget()


func _tick_detour(hero: Node2D, pos: Vector2, delta: float) -> void:
	if not _detours.has(hero):
		return
	var d: Array = _detours[hero]
	d[1] = float(d[1]) - delta
	if float(d[1]) <= 0.0 or pos.distance_to(d[0]) <= stuck_radius:
		_detours.erase(hero)


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
