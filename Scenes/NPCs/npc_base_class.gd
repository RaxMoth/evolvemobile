extends Node2D
class_name EntityBase

## EntityBase - Base class for all NPCs (Heroes, Monsters, Mobs)
## Handles combat, movement, targeting, and state management
## Uses godotstatecharts for AI state machine (Idle → Approach → Fight → Dead)

# ============================================
# SECTION 1: EXPORTS & CONFIGURATION
# ============================================
signal died

@export_group("Detection")
@export var detection_radius: float = 172.0
@export var show_detection_radius: bool = false

@export_group("XP System")
@export var xp_value: float = 0.0

@export_group("Combat Behavior")
@export var combat_role: Types.CombatRole = Types.CombatRole.MELEE
@export var preferred_distance: float = 50.0
@export var min_distance: float = 30.0
@export var max_distance: float = 150.0
@export var strafe_enabled: bool = true
@export var strafe_speed: float = 60.0

@export_group("Smart Targeting")
@export var enable_smart_targeting: bool = true
@export var target_reeval_interval_approach: float = 0.5
@export var target_reeval_interval_fight: float = 1.0
@export var switch_threshold_approach: float = 30.0
@export var switch_threshold_fight: float = 50.0
@export var max_chase_distance: float = 1000.0
@export var priority_hero_monster: int = 100
@export var priority_mob: int = 50
## How much weight to give the team blackboard's threat-against-me when scoring
## targets. 0 = pure positional/HP scoring (old behavior). 1.0 = same weight as
## a hero/monster priority bonus. Tanks naturally pull aggro because they
## generate more threat per damage point (taunt_strength).
@export var threat_score_weight: float = 1.5

@export_group("Aggro / Tanking")
## Multiplier on damage→threat. Tanks set 2.0–3.0 to pull aggro from DPS.
## Healers may set <1.0 so healing doesn't accidentally pull aggro.
@export var taunt_strength: float = 1.0

@export_group("Awareness")
## Broadcast my current target to allies within this radius when I aggro.
## 0 disables. Mobs default to 200; heroes don't usually need it (they
## coordinate via the team blackboard).
@export var alert_allies_radius: float = 0.0

@export_group("Feel & Polish")
## Higher = snappier rotation. ~12 feels natural; 0 = instant (old behavior).
@export var rotation_smooth_speed: float = 12.0
## On taking damage, briefly block attacks for this many seconds (flinch).
## 0 disables. ~0.15 feels weighty without breaking combat flow.
@export var flinch_duration: float = 0.15
## Personal preferred-distance jitter at runtime: each entity picks a random
## offset on _ready so a group fighting one target doesn't all stand on the
## same circle. Expressed as a fraction (0.15 = ±15%).
@export var distance_jitter: float = 0.15

# ============================================
# SECTION 2: ONREADY REFERENCES
# ============================================

@onready var sprite: Node2D = $Sprite2D
@onready var state_chart: StateChart = %StateChart
@onready var navigation_agent_2d: NavigationAgent2D = %NavigationAgent2D
@onready var health_bar: ProgressBar = %HealthBar
@onready var detection_area: Area2D = %DetectionArea
@onready var lv_label: Label = %LVLabel

# ============================================
# SECTION 3: INSTANCE VARIABLES
# ============================================

# Combat state
var target: Node2D = null
var target_entity: Node = null
var is_on_cooldown: bool = false
var last_attacker: Node2D = null

# Movement & positioning
var strafe_direction: int = 1
var strafe_timer: float = 0.0
var strafe_change_interval: float = 2.0

# Lazy navigation - only update target if moved significantly
var _last_nav_target_pos: Vector2 = Vector2.ZERO
var _nav_update_threshold: float = 20.0  # Only update if target moves > 20 pixels

# Idle behavior
var _idle_timer: float = 0.0
var _idle_goal: Vector2 = Vector2.ZERO

# Smart targeting
var _target_reeval_timer: float = 0.0

# Phase A polish
var _personal_distance_offset: float = 0.0  ## Picked once in _ready: ± distance_jitter
var _flinch_timer: float = 0.0               ## > 0 while flinching from a recent hit
var _facing_angle: float = 0.0               ## Smoothed sprite rotation target

# ============================================
# SECTION 4: COMPUTED PROPERTIES
# ============================================

var move_speed: float:
	get: return _get_move_speed()

var attack_range: float:
	get: return _get_attack_range()

var idle_retarget_time: float:
	get: return _get_idle_retarget_time()

var idle_wander_radius: float:
	get: return _get_idle_wander_radius()

var keep_distance: float:
	get: return _get_keep_distance()

# ============================================
# SECTION 5: LIFECYCLE METHODS
# ============================================

func _ready() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame

	_update_detection_radius()

	if health_bar:
		health_bar.max_value = get_health()
		health_bar.value = get_health()
		_pin_health_bar_visuals()

	if lv_label:
		lv_label.text = str(_get_entity_level())
		_pin_lv_label()

	_setup_navigation()
	_apply_ui_counter_scale()

	# Register with the team blackboard so threat / coordination work.
	TeamRegistry.register(self, TeamRegistry.team_name_of(self))

	# Personal distance jitter — each entity orbits at a slightly different
	# preferred distance so a group fighting one target doesn't stack.
	if distance_jitter > 0.0:
		_personal_distance_offset = randf_range(-distance_jitter, distance_jitter)

	# Initial facing matches the sprite's current rotation so smoothed
	# turning starts at the right place.
	if sprite:
		_facing_angle = sprite.rotation

	# Hook the global damage pipeline so we flinch when hit.
	EventBus.damage_applied.connect(_on_damage_applied_global)

	# NOTE: A global state-chart event bridge used to live here, forwarding
	# every chart event into EventBus.entity_state_event. It's removed for now
	# because there are no consumers yet and the per-event emit overhead
	# adds up across many entities. Re-enable per-entity (or via an opt-in
	# flag) when an actual consumer ships.

func _exit_tree() -> void:
	# Clean up team membership so dead entities don't linger in threat tables.
	TeamRegistry.unregister(self, TeamRegistry.team_name_of(self))


# ============================================
# SECTION 5b: HUD-PIN HELPERS (in-world HP bar consistency)
# ============================================

# Pixel dimensions every entity's floating HP bar is forced to. This is
# what guarantees all heroes (and the monster across stages) display the
# same-looking bar regardless of their max HP or sprite scale.
const HP_BAR_SIZE := Vector2(50, 6)
const LV_LABEL_MIN_SIZE := Vector2(22, 0)

func _pin_health_bar_visuals() -> void:
	## Forces a fixed pixel size + a visible background StyleBox onto the
	## floating HP bar. Without this:
	##  • size_flags_horizontal=EXPAND lets the LVLabel (whose width depends
	##    on level digit count) squeeze the bar.
	##  • the default ProgressBar background is often nearly transparent,
	##    making the empty portion invisible — so a 30% HP bar LOOKS 30%
	##    as wide as a full one.
	health_bar.custom_minimum_size = HP_BAR_SIZE
	health_bar.size_flags_horizontal = Control.SIZE_FILL  # no EXPAND
	health_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	health_bar.show_percentage = false

	# Visible background — empty portion of the bar.
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.10, 0.85)
	bg.corner_radius_top_left = 2
	bg.corner_radius_top_right = 2
	bg.corner_radius_bottom_left = 2
	bg.corner_radius_bottom_right = 2
	bg.border_width_left = 1
	bg.border_width_right = 1
	bg.border_width_top = 1
	bg.border_width_bottom = 1
	bg.border_color = Color(0, 0, 0, 0.7)
	health_bar.add_theme_stylebox_override("background", bg)

	# Visible fill — green by default; subclasses can swap colors via theme.
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.35, 0.85, 0.35, 1.0)
	fill.corner_radius_top_left = 2
	fill.corner_radius_top_right = 2
	fill.corner_radius_bottom_left = 2
	fill.corner_radius_bottom_right = 2
	health_bar.add_theme_stylebox_override("fill", fill)

func _pin_lv_label() -> void:
	## Pin LV label so its text width doesn't pull pixels from the HP bar
	## when the level reaches double digits.
	lv_label.custom_minimum_size = LV_LABEL_MIN_SIZE
	lv_label.size_flags_horizontal = Control.SIZE_FILL
	lv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _apply_ui_counter_scale() -> void:
	## The HUD Control inherits the entity's transform — when the monster
	## grows per evolution stage, its HP bar would grow with it. Counter-
	## scaling the parent Control by 1 / entity.scale keeps the bar at a
	## fixed visual size. Heroes (scale=1) get an effective no-op.
	## MonsterBase calls this again after each stage tween completes so
	## the bar stays pinned through evolution.
	var hud: Control = get_node_or_null("Control") as Control
	if hud == null:
		return
	var sx: float = scale.x if scale.x != 0.0 else 1.0
	var sy: float = scale.y if scale.y != 0.0 else 1.0
	hud.scale = Vector2(1.0 / sx, 1.0 / sy)

func _on_damage_applied_global(packet: DamagePacket) -> void:
	# Ignore damage that wasn't dealt to me.
	if packet.target != self:
		return
	if flinch_duration > 0.0:
		_flinch_timer = flinch_duration
	# Subclasses that want to broadcast a "help!" or react can override this
	# to add behavior, then call super._on_damage_applied_global(packet).

func _update_detection_radius() -> void:
	"""Update DetectionArea collision shape radius from export variable"""
	if not is_instance_valid(detection_area):
		return
	
	var collision_shape = detection_area.get_node_or_null("CollisionShape2D")
	if not collision_shape:
		return
	
	if collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = detection_radius
		
		# Visual debug
		if show_detection_radius:
			detection_area.visible = true
	else:
		push_warning(name + " DetectionArea is not using CircleShape2D!")

func _setup_navigation() -> void:
	"""Configure navigation agent with tilemap navigation"""
	var tilemap_layer := get_parent().get_node_or_null("Ground")
	if not tilemap_layer or not tilemap_layer.has_method("get_navigation_map"):
		return
	
	var nav_map = tilemap_layer.get_navigation_map()
	if not nav_map.is_valid():
		return
	
	navigation_agent_2d.set_navigation_map(nav_map)
	navigation_agent_2d.path_desired_distance = 6.0
	navigation_agent_2d.simplify_path = true
	navigation_agent_2d.target_desired_distance = 4.0
	navigation_agent_2d.avoidance_enabled = false

# ============================================
# SECTION 6: VIRTUAL METHODS (TO OVERRIDE)
# ============================================

func _is_attack_ready() -> bool:
	"""Check if attack is off cooldown. Override in child classes.
	NOTE: flinch is checked separately at the fight-loop call site (so
	subclass overrides don't accidentally bypass it)."""
	return not is_on_cooldown

func _can_act() -> bool:
	"""Composite gate: attack ready AND not flinching. Used by the fight loop."""
	return _flinch_timer <= 0.0 and _is_attack_ready()

func is_alive() -> bool:
	"""Check if entity is alive. Must override in child classes."""
	push_error("is_alive() not implemented in " + name)
	return false

func _receive_damage(_packet: DamagePacket) -> void:
	"""Apply a fully-resolved DamagePacket. Must override in child classes.
	Called by EventBus._route_packet after damage_requested listeners have run."""
	push_error("_receive_damage() not implemented in " + name)

func get_health() -> float:
	"""Get current health. Must override in child classes."""
	push_error("get_health() not implemented in " + name)
	return 0.0

func _get_entity_level() -> int:
	"""Get entity level. Override in child classes."""
	return 1

func _get_move_speed() -> float:
	"""Get movement speed. Override in child classes."""
	return 80.0

func _get_attack_range() -> float:
	"""Get attack range. Override in child classes."""
	return 50.0

func _get_idle_retarget_time() -> float:
	"""Get idle retarget interval. Override in child classes."""
	return 1.2

func _get_idle_wander_radius() -> float:
	"""Get idle wander radius. Override in child classes."""
	return 160.0

func _get_keep_distance() -> float:
	"""Get minimum keep distance. Override in child classes."""
	return 24.0

# ============================================
# SECTION 7: UTILITY & HELPER METHODS
# ============================================

func is_target_valid() -> bool:
	"""Check if current target is valid and alive"""
	return is_instance_valid(target) and is_instance_valid(target_entity)

func distance_to_target() -> float:
	"""Get distance to current target"""
	return target.global_position.distance_to(global_position) if is_target_valid() else INF

# ============================================
# SECTION 8: TARGETING SYSTEM
# ============================================

func _find_best_target() -> Area2D:
	"""Find the best target area among all valid targets in detection area.
	Returns the Area2D node (not the entity)."""
	if not enable_smart_targeting:
		return _find_first_valid_target()
	
	if not is_instance_valid(detection_area):
		return null
	
	var best_area: Area2D = null
	var best_score: float = - INF
	
	for area in detection_area.get_overlapping_areas():
		if not _can_target_area(area):
			continue
		
		var entity = area.get_owner()
		if not is_instance_valid(entity):
			continue
		
		var score = _score_target(entity)
		if score > best_score:
			best_score = score
			best_area = area
	
	return best_area if best_score > 0.0 else null

func _find_first_valid_target() -> Area2D:
	"""Fallback: Find first valid target area (old behavior)"""
	if not is_instance_valid(detection_area):
		return null
	
	var areas = detection_area.get_overlapping_areas()
	for area in areas:
		if _can_target_area(area):
			return area
	return null

func _score_target(target_node: Node2D) -> float:
	"""Calculate score for a target (higher = better).
	Considers priority, distance, threat level, and engagement penalty."""
	if not is_instance_valid(target_node):
		return -1000.0
	
	var score = 0.0
	var distance = global_position.distance_to(target_node.global_position)
	
	score += _get_target_priority(target_node)
	score += _get_distance_score(distance)
	score += _get_threat_score(target_node)
	
	# Penalty for switching targets (prevents flip-flopping)
	if target_entity != target_node:
		score -= 20.0
	
	# Heavy penalty for too-distant targets
	if distance > max_chase_distance:
		score -= 100.0
	
	return score

func _get_target_priority(target_node: Node2D) -> float:
	"""Get base priority score based on target type"""
	if target_node.is_in_group("Hero") or target_node.is_in_group("Monster"):
		return priority_hero_monster
	elif target_node.is_in_group("Enemy"):
		return priority_mob
	return 0.0

func _get_distance_score(distance: float) -> float:
	"""Calculate score based on distance (closer = better)"""
	if distance < 50.0:
		return 50.0
	elif distance < 150.0:
		return 30.0
	elif distance < 300.0:
		return 10.0
	elif distance < 500.0:
		return -10.0
	else:
		return -50.0

func _get_threat_score(target_node: Node2D) -> float:
	"""Calculate threat score based on target behavior + team blackboard threat."""
	var threat = 0.0

	# Is target attacking me?
	if "target_entity" in target_node:
		var their_target = target_node.get("target_entity")
		if their_target == self:
			threat += 30.0

	# Is target low health?
	if target_node.has_method("get_health") and target_node.has_method("is_alive"):
		if target_node.call("is_alive"):
			var current_hp = target_node.call("get_health")
			var max_hp = target_node.get_health() if target_node.has_method("get_health") else 100.0
			var health_percent = current_hp / max_hp if max_hp > 0 else 1.0
			if health_percent < 0.3:
				threat += 15.0

	# Is target far away (likely fleeing)?
	var distance = global_position.distance_to(target_node.global_position)
	if distance > 400.0 and is_target_valid() and target_entity == target_node:
		threat -= 20.0

	# Team blackboard threat — pulls aggro toward whoever has been hitting me
	# the hardest. Tanks generate extra threat per damage point via taunt_strength,
	# so a tank's attacks naturally drag mob targeting onto them.
	if threat_score_weight > 0.0:
		var team := TeamRegistry.team_of(self)
		if team:
			var bb_threat: float = team.get_threat_against(self, target_node)
			threat += bb_threat * threat_score_weight

	return threat

func _should_switch_target(new_target_area: Area2D, threshold: float) -> bool:
	"""Determine if should switch from current target to new target.
	Uses provided threshold to prevent excessive switching."""
	if not enable_smart_targeting:
		return not is_target_valid()
	
	if not is_target_valid():
		return true
	
	var new_target_node = new_target_area.get_owner()
	if not is_instance_valid(new_target_node):
		return false
	
	var current_score = _score_target(target_entity)
	var new_score = _score_target(new_target_node)
	
	return new_score > current_score + threshold

func _reevaluate_current_target(threshold: float) -> void:
	if not enable_smart_targeting:
		return
	
	var best_target_area = _find_best_target()
	
	if not best_target_area:
		if is_target_valid():
			target = null
			target_entity = null
			state_chart.send_event(CombatEvents.ENEMY_EXITED)
		return
	
	var best_target_node = best_target_area.get_owner() if best_target_area else null
	
	if is_target_valid() and target_entity == best_target_node:
		return
	
	if _should_switch_target(best_target_area, threshold):
		target = best_target_area
		target_entity = best_target_node

func _check_for_nearby_enemies() -> void:
	"""Check detection area for any remaining enemies and re-engage"""
	if not is_instance_valid(detection_area):
		return

	var best_target_area = _find_best_target()
	if best_target_area:
		target = best_target_area
		target_entity = best_target_area.get_owner()
		state_chart.send_event(CombatEvents.ENEMY_ENTERED)
		_broadcast_aggro(target_entity)

func _broadcast_aggro(spotted: Node) -> void:
	"""Tell allies within alert_allies_radius about this target. Mobs use this
	to make a pack engage together when one of them spots a hero."""
	if alert_allies_radius <= 0.0 or not is_instance_valid(spotted):
		return
	var team := TeamRegistry.team_of(self)
	if team == null:
		return
	var r_sq := alert_allies_radius * alert_allies_radius
	for ally in team.members:
		if ally == self or not is_instance_valid(ally) or not (ally is EntityBase):
			continue
		# Only nudge allies that aren't already engaged.
		var ally_entity := ally as EntityBase
		if ally_entity.is_target_valid():
			continue
		if ally.global_position.distance_squared_to(global_position) > r_sq:
			continue
		# Set their target — but only if they CAN target this entity.
		if not GameUtils.can_entity_target(ally_entity, spotted):
			continue
		# Find the spotted entity's body Area2D so the existing target/target_entity
		# pair is consistent (target = Area2D, target_entity = root entity).
		var spotted_area: Area2D = null
		if spotted.has_node("Body"):
			spotted_area = spotted.get_node("Body") as Area2D
		ally_entity.target = spotted_area
		ally_entity.target_entity = spotted
		if ally_entity.state_chart:
			ally_entity.state_chart.send_event(CombatEvents.ENEMY_ENTERED)

func _can_target_area(area: Area2D) -> bool:
	"""Check if we can target this area based on group rules"""
	if area.get_owner() == self or area.get_parent() == self:
		return false
	
	var root := area.get_owner()
	if not root:
		return false
	
	return GameUtils.can_entity_target(self, root)

# ============================================
# SECTION 9: DETECTION AREA SIGNALS
# ============================================

func _on_detection_area_area_entered(area: Area2D) -> void:
	"""Called when an area enters detection range"""
	if area.get_owner() == self or area.get_parent() == self:
		return
	
	var root := area.get_owner()
	if not root:
		return
	
	var can_target := _can_target_area(area)
	if not can_target:
		return
	
	if enable_smart_targeting:
		var best_target_area = _find_best_target()
		if best_target_area:
			var best_target_node = best_target_area.get_owner()
			if is_instance_valid(best_target_node):
				target = best_target_area
				target_entity = best_target_node
				state_chart.send_event(CombatEvents.ENEMY_ENTERED)
				_broadcast_aggro(best_target_node)
	else:
		target = area
		target_entity = area.get_parent()
		state_chart.send_event(CombatEvents.ENEMY_ENTERED)
		_broadcast_aggro(target_entity)

func _on_detection_area_area_exited(area: Area2D) -> void:
	"""Called when an area exits detection range"""
	if target == area:
		if enable_smart_targeting:
			_reevaluate_current_target(switch_threshold_approach)
		else:
			target = null
			target_entity = null
			state_chart.send_event(CombatEvents.ENEMY_EXITED)

# ============================================
# SECTION 10: COMBAT BEHAVIORS
# ============================================

func _melee_combat_behavior(delta: float, distance: float, dir: Vector2) -> void:
	"""Melee combat: Close distance and strafe while on cooldown"""
	if _is_attack_ready() and distance <= attack_range:
		return

	var pref := _effective_preferred_distance()
	if distance > pref + 10.0:
		_move_toward_target(move_speed, delta)
	elif distance < pref - 10.0:
		_move_away_from_target(move_speed * 0.5, delta)
	else:
		if strafe_enabled:
			_strafe_around_target(delta, dir)

func _ranged_combat_behavior(delta: float, distance: float, dir: Vector2) -> void:
	"""Ranged combat: Kite and maintain distance"""
	if _is_attack_ready():
		if distance >= min_distance and distance <= attack_range:
			return

	var pref := _effective_preferred_distance()
	if distance < min_distance:
		_kite_away_from_target(move_speed, delta)
	elif distance < pref - 20.0:
		_kite_away_from_target(move_speed, delta)
	elif distance > pref + 30.0:
		_move_toward_target(move_speed * 0.7, delta)
	else:
		if strafe_enabled:
			_strafe_around_target(delta, dir)

func _support_combat_behavior(delta: float, distance: float, dir: Vector2) -> void:
	"""Support combat: Default to ranged behavior"""
	_ranged_combat_behavior(delta, distance, dir)

# ============================================
# SECTION 11: MOVEMENT & NAVIGATION
# ============================================

func _face(dir: Vector2, delta: float) -> void:
	"""Rotate the sprite toward `dir` smoothly. Replaces the old
	instant `sprite.rotation = dir.angle()` — entities now turn instead of snap."""
	if not sprite or dir.length_squared() < 0.0001:
		return
	var target := dir.angle()
	if rotation_smooth_speed <= 0.0:
		# Opt-out: instant rotation
		sprite.rotation = target
		_facing_angle = target
		return
	_facing_angle = lerp_angle(_facing_angle, target, clamp(rotation_smooth_speed * delta, 0.0, 1.0))
	sprite.rotation = _facing_angle

## Effective preferred distance including this entity's personal jitter.
## Used by all repositioning code so a group of melees orbits at slightly
## different radii instead of stacking on top of each other.
func _effective_preferred_distance() -> float:
	return preferred_distance * (1.0 + _personal_distance_offset)

func _steer_along_nav(speed: float, delta: float) -> void:
	"""Follow navigation path at given speed"""
	if not is_instance_valid(navigation_agent_2d) or navigation_agent_2d.is_navigation_finished():
		return

	var next_pos := navigation_agent_2d.get_next_path_position()
	var dir := (next_pos - global_position).normalized()

	if dir.length_squared() < 0.000001:
		return

	position += dir * speed * delta
	_face(dir, delta)

func _set_nav_target_lazy(target_pos: Vector2) -> void:
	"""Set navigation target only if it moved significantly (lazy update optimization)"""
	if not is_instance_valid(navigation_agent_2d):
		return
	
	var distance_moved = target_pos.distance_to(_last_nav_target_pos)
	if distance_moved > _nav_update_threshold:
		navigation_agent_2d.target_position = target_pos
		_last_nav_target_pos = target_pos

func move_toward_point(target_pos: Vector2, speed: float, delta: float) -> void:
	"""Move directly toward point (no navigation)"""
	var dir := (target_pos - global_position).normalized()
	if dir.length_squared() < 0.000001:
		return

	position += dir * speed * delta
	_face(dir, delta)

func _move_toward_target(speed: float, delta: float) -> void:
	"""Navigate toward current target"""
	if not is_target_valid():
		return
	_set_nav_target_lazy(target.global_position)
	_steer_along_nav(speed, delta)

func _move_away_from_target(speed: float, delta: float) -> void:
	"""Navigate away from current target"""
	if not is_target_valid():
		return
	var away_dir = (global_position - target.global_position).normalized()
	var away_point = global_position + away_dir * 100.0
	_set_nav_target_lazy(away_point)
	_steer_along_nav(speed, delta)

func _kite_away_from_target(speed: float, delta: float) -> void:
	"""Kite away from target with lateral movement"""
	if not is_target_valid():
		return
	var away_dir = (global_position - target.global_position).normalized()
	var perpendicular = Vector2(-away_dir.y, away_dir.x) * strafe_direction
	var kite_dir = (away_dir + perpendicular * 0.3).normalized()
	var kite_point = global_position + kite_dir * 80.0
	_set_nav_target_lazy(kite_point)
	_steer_along_nav(speed, delta)

func _strafe_around_target(delta: float, dir: Vector2) -> void:
	"""Circle strafe around target"""
	if not is_target_valid():
		return
	
	strafe_timer += delta
	if strafe_timer >= strafe_change_interval:
		strafe_timer = 0.0
		if randf() > 0.5:
			strafe_direction *= -1
	
	var perpendicular = Vector2(-dir.y, dir.x) * strafe_direction
	var strafe_point = global_position + perpendicular * strafe_speed * delta
	_set_nav_target_lazy(strafe_point)
	_steer_along_nav(strafe_speed, delta)

# ============================================
# SECTION 12: IDLE EXPLORATION
# ============================================

func _get_smart_idle_destination() -> Vector2:
	"""Get a smart idle destination that:
	- For heroes: Prefers unexplored areas
	- For all: Avoids walls and obstacles
	- Picks best of multiple samples"""
	if is_in_group("Hero"):
		var exploration_target = _get_exploration_target()
		if exploration_target != Vector2.ZERO:
			return exploration_target
	
	return _get_valid_random_destination()

func _get_exploration_target() -> Vector2:
	"""Get target from HeroExplorationController if available"""
	var exploration_controller = get_tree().get_first_node_in_group("HeroExplorationController")
	if not exploration_controller:
		return Vector2.ZERO
	
	if "exploration_target" in self:
		var hero_target = get("exploration_target")
		if hero_target is Vector2 and hero_target != Vector2.ZERO:
			return hero_target
	
	if exploration_controller.has_method("get_current_group_target"):
		return exploration_controller.get_current_group_target()
	
	return Vector2.ZERO

func _get_valid_random_destination() -> Vector2:
	"""Sample multiple random points and pick the best one"""
	var best_point = global_position
	var best_score = - INF
	var samples = 5
	
	for i in range(samples):
		var candidate = _generate_random_point()
		var score = _score_destination(candidate)
		
		if score > best_score:
			best_score = score
			best_point = candidate
	
	return best_point

func _generate_random_point() -> Vector2:
	"""Generate a random point around current position"""
	var angle := randf() * TAU
	var dir := Vector2.from_angle(angle)
	
	var radius = idle_wander_radius
	if is_in_group("Hero"):
		radius *= 1.5
	
	var dist := randf_range(radius * 0.3, radius)
	return global_position + dir * dist

func _score_destination(point: Vector2) -> float:
	"""Score a destination point (higher = better)"""
	var score = 0.0
	
	if GameUtils.is_point_too_close_to_wall(get_world_2d(), point, 32.0, 1, 8):
		return -1000.0
	
	var current_facing = sprite.rotation if sprite else 0.0
	var to_point = (point - global_position).normalized()
	var point_angle = to_point.angle()
	var angle_diff = abs(GameUtils.angle_difference(current_facing, point_angle))
	score += (PI - angle_diff) * 50.0
	
	if is_in_group("Hero"):
		var fog_system = get_tree().get_first_node_in_group("FogOfWar")
		if GameUtils.is_position_explored(fog_system, point):
			score -= 50.0
		else:
			score += 200.0
	
	var nearby_walls = GameUtils.count_walls_in_radius(get_world_2d(), point, 50.0, 1, 12)
	score -= nearby_walls * 30.0
	
	return score

# ============================================
# SECTION 13: XP SYSTEM
# ============================================

func _grant_xp_to_killer() -> void:
	"""Grant XP to the entity that killed this one"""
	if not is_instance_valid(target_entity):
		return
	
	if not target_entity.has_method("gain_xp"):
		return
	
	if xp_value > 0:
		target_entity.gain_xp(xp_value)

# ============================================
# SECTION 14: STATE CHART HANDLERS
# ============================================

## Idle State - Wandering and waiting for targets

func _on_idle_state_entered() -> void:
	"""Entered Idle state - reset idle timers and check for enemies"""
	_idle_timer = 0.0
	_idle_goal = global_position
	_check_for_nearby_enemies()

func _on_idle_state_processing(delta: float) -> void:
	"""Process Idle state - wander around"""
	if not is_instance_valid(navigation_agent_2d):
		return
	
	_idle_timer -= delta
	if _idle_timer <= 0.0 or global_position.distance_squared_to(_idle_goal) < 64.0:
		_idle_timer = idle_retarget_time
		_idle_goal = _get_smart_idle_destination()
		navigation_agent_2d.target_position = _idle_goal
	
	_steer_along_nav(move_speed, delta)

## Approach State - Chasing target

func _on_approach_state_entered() -> void:
	"""Entered Approach state - initialize re-evaluation timer"""
	_target_reeval_timer = target_reeval_interval_approach
	
	if not is_target_valid():
		_check_for_nearby_enemies()

func _on_approach_state_processing(delta: float) -> void:
	"""Process Approach state - chase target and periodically re-evaluate"""
	if not is_target_valid():
		state_chart.send_event(CombatEvents.ENEMY_EXITED)
		return

	if distance_to_target() <= max(attack_range, keep_distance):
		state_chart.send_event(CombatEvents.ENEMY_FIGHT)
		return
	
	# Periodic target re-evaluation while chasing
	if enable_smart_targeting:
		_target_reeval_timer -= delta
		if _target_reeval_timer <= 0.0:
			_target_reeval_timer = target_reeval_interval_approach
			_reevaluate_current_target(switch_threshold_approach)
	
	if is_instance_valid(navigation_agent_2d):
		navigation_agent_2d.target_position = target.global_position
		_steer_along_nav(move_speed, delta)
	else:
		move_toward_point(target.global_position, move_speed, delta)

## Fight State - In combat with target

func _on_fight_state_entered() -> void:
	"""Entered Fight state - initialize re-evaluation timer"""
	_target_reeval_timer = target_reeval_interval_fight

	if not is_target_valid():
		state_chart.send_event(CombatEvents.TARGET_LOST)

func _on_fight_state_processing(delta: float) -> void:
	"""Process Fight state - combat and periodic re-evaluation"""
	if not is_target_valid():
		state_chart.send_event(CombatEvents.TARGET_LOST)
		return

	var distance = distance_to_target()

	if distance > max_distance:
		state_chart.send_event(CombatEvents.RE_APPROACH)
		return
	
	if enable_smart_targeting:
		_target_reeval_timer -= delta
		if _target_reeval_timer <= 0.0:
			_target_reeval_timer = target_reeval_interval_fight
			_reevaluate_current_target(switch_threshold_fight)

	# Decay flinch timer (blocks attacks while > 0).
	if _flinch_timer > 0.0:
		_flinch_timer -= delta

	var dir := (target.global_position - global_position).normalized()
	_face(dir, delta)

	if _can_act() and distance <= attack_range and distance >= min_distance:
		# Actually attacking - execute fight logic
		_on_fight_logic(delta)
	else:
		# Not ready, flinching, or out of range - reposition
		_reposition_for_attack(delta, distance, dir)

func _reposition_for_attack(delta: float, distance: float, dir: Vector2) -> void:
	"""Move to ideal attack position when not attacking"""
	match combat_role:
		Types.CombatRole.MELEE:
			_melee_reposition(delta, distance)
		Types.CombatRole.RANGED:
			_ranged_reposition(delta, distance, dir)
		Types.CombatRole.SUPPORT:
			_ranged_reposition(delta, distance, dir)

func _melee_reposition(delta: float, distance: float) -> void:
	"""Melee repositioning: get close"""
	if distance > attack_range:
		_move_toward_target(move_speed, delta)
	elif distance < min_distance:
		_move_away_from_target(move_speed * 0.5, delta)

func _ranged_reposition(delta: float, distance: float, dir: Vector2) -> void:
	"""Ranged repositioning: maintain distance"""
	var pref := _effective_preferred_distance()
	if distance < min_distance:
		_kite_away_from_target(move_speed, delta)
	elif distance > pref + 30.0:
		_move_toward_target(move_speed * 0.7, delta)
	elif strafe_enabled:
		_strafe_around_target(delta, dir)

func _on_fight_logic(_delta: float) -> void:
	"""Override in child classes to add custom fight logic"""
	pass

func _on_dead_state_entered() -> void:
	died.emit()
	EventBus.notify_died(self, last_attacker)
	_grant_xp_to_killer()
	queue_free()
