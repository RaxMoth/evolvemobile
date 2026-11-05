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
@export var target_reeval_interval_approach: float = 0.5
@export var target_reeval_interval_fight: float = 1.0
@export var switch_threshold_approach: float = 30.0
@export var switch_threshold_fight: float = 50.0
@export var max_chase_distance: float = 1000.0
## Keep a valid current target even when it is outside my own detection circle,
## as long as it is within this radius. 0 = drop it the moment nothing is in
## detection (mobs, monster). Heroes set it scene-side so a teammate summoned by
## the call-for-help (alert_allies_radius) does not abandon the fight on its
## first re-evaluation, 0.5 s before it even arrives.
@export var pursue_out_of_sight_radius: float = 0.0
@export var priority_hero_monster: int = 100
@export var priority_mob: int = 50
## How much weight to give the team blackboard's threat-against-me when scoring
## targets. 0 = pure positional/HP scoring (old behavior). 1.0 = same weight as
## a hero/monster priority bonus. Tanks naturally pull aggro because they
## generate more threat per damage point (taunt_strength).
@export var threat_score_weight: float = 1.5
## Focus fire: score bonus for wounded targets, scaled by missing HP
## (bonus = weight × (1 - hp%)). 0 = off (mobs, monster). Heroes set it
## scene-side so the team finishes one enemy instead of spreading damage.
@export var low_hp_focus_weight: float = 0.0

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
@onready var hud: Node2D = %Hud
@onready var health_bar: HpBar2D = %HealthBar
@onready var detection_area: Area2D = %DetectionArea
## Only hero / monster scenes carry a level label; mob scenes resolve null.
@onready var lv_label: Label = get_node_or_null("%LVLabel") as Label
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var screen_notifier: VisibleOnScreenNotifier2D = %ScreenNotifier

# ============================================
# SECTION 3: INSTANCE VARIABLES
# ============================================

# Combat state
## Which side I fight on, from my scene groups: set in _enter_tree, before
## the registries read it; every targeting rule reads it from here.
var faction: GameUtils.Faction = GameUtils.Faction.NONE
var target: Node2D = null
var target_entity: Node = null
var last_attacker: Node2D = null

# Movement & positioning
var strafe_direction: int = 1
var strafe_timer: float = 0.0
var strafe_change_interval: float = 2.0

# Lazy navigation - only update target if moved significantly
var _last_nav_target_pos: Vector2 = Vector2(INF, INF)  # INF = "never set" so the first lazy call always paths
var _nav_update_threshold: float = 20.0  # Only update if target moves > 20 pixels

# Idle behavior
var _idle_timer: float = 0.0
var _idle_goal: Vector2 = Vector2.ZERO

# Smart targeting
var _target_reeval_timer: float = 0.0

# Phase A polish
var _personal_distance_offset: float = 0.0  ## Picked once in _ready: ± distance_jitter
var _flinch_timer: float = 0.0               ## > 0 while flinching from a recent hit
var _stun_timer: float = 0.0                 ## > 0 while stunned: no movement, attacks or casts
var _facing_angle: float = 0.0               ## Smoothed sprite rotation target

# TickScheduler (AI LOD)
var _tick_delta: float = 0.0   ## Wall time since our last _tick; handed to the state handlers
var _ready_done: bool = false  ## No step() before _ready finished its awaited frames

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
	var tree := get_tree()
	await tree.physics_frame
	await tree.physics_frame
	# A fresh mob can be parked by the pool inside this window (killed on its
	# first frames, or its camp deactivated). Finish setup on re-entry instead
	# of running it out of the tree and never reaching _ready_done.
	if not is_inside_tree():
		await tree_entered

	_update_detection_radius()

	set_hp_display(get_health(), get_max_health())
	if lv_label:
		lv_label.text = str(_get_entity_level())

	_setup_navigation()
	_apply_ui_counter_scale()

	# Personal distance jitter — each entity orbits at a slightly different
	# preferred distance so a group fighting one target doesn't stack.
	if distance_jitter > 0.0:
		_personal_distance_offset = randf_range(-distance_jitter, distance_jitter)

	# Initial facing matches the sprite's current rotation so smoothed
	# turning starts at the right place.
	if sprite:
		_facing_angle = sprite.rotation

	# Visual LOD: a mob that spawned off screen starts with its animation
	# paused (the notifier only emits on CHANGES, so seed the initial state).
	if screen_notifier and not screen_notifier.is_on_screen():
		_on_screen_exited()

	_ready_done = true

func _enter_tree() -> void:
	# Registration lives here (not _ready) so a pooled mob re-registers on
	# every add_child and drops out on remove_child. Groups are assigned at
	# instantiation, so the faction can already be read from them.
	faction = GameUtils.faction_of(self)
	TeamRegistry.register(self, TeamRegistry.team_name_of(self))
	EntityRegistry.register(self, faction)
	TickScheduler.register(self, _is_always_full_rate())

func _exit_tree() -> void:
	# Clean up team membership so dead entities don't linger in threat tables.
	TeamRegistry.unregister(self, TeamRegistry.team_name_of(self))
	EntityRegistry.unregister(self, faction)
	TickScheduler.unregister(self)


# ============================================
# SECTION 5a: TICK SCHEDULER / AI LOD
# ============================================

func _is_always_full_rate() -> bool:
	"""Heroes and the monster anchor the camera and must animate at 60 Hz.
	Mobs return false and get bucketed by distance to the action."""
	return false

func _tick(delta: float) -> void:
	"""Called by TickScheduler at this entity's LOD rate. `delta` is the wall
	time since OUR last tick (clamped), so every handler keeps its
	`speed * delta` / `timer -= delta` math unchanged. Drives the state chart
	through the addon's step() API — the active leaf emits state_stepped,
	wired scene-side to the _on_*_state_stepped handlers below."""
	if not _ready_done or not is_instance_valid(state_chart) or not state_chart.is_node_ready():
		return
	_tick_delta = delta
	if _stun_timer > 0.0:
		# Stunned: the AI does not step at all (no steering, swings or casts).
		_stun_timer = maxf(_stun_timer - delta, 0.0)
		return
	_pre_tick(delta)
	state_chart.step()


## Freeze this entity's AI for `duration` seconds (Ram Dash stun node). A
## shorter stun never cuts a running one short.
func apply_stun(duration: float) -> void:
	if duration <= 0.0 or not is_alive():
		return
	_stun_timer = maxf(_stun_timer, duration)


func is_stunned() -> bool:
	return _stun_timer > 0.0


## Re-pick the idle goal on the next idle tick (a new exploration target).
func request_idle_retarget() -> void:
	_idle_timer = 0.0


## Move instantly (match setup) and drop the old path so the AI re-plans from here.
func teleport_to(pos: Vector2) -> void:
	global_position = pos
	_idle_goal = pos
	_idle_timer = 0.0
	_last_nav_target_pos = Vector2(INF, INF)
	if is_instance_valid(navigation_agent_2d):
		navigation_agent_2d.target_position = pos


## Moved by an outside force (Gravity Slam pull): keep the state, goals and any
## stun, but re-path from the new spot (teleport_to would drop the idle goal).
## A MobBase that is not in combat and lands outside its camp is put back on
## the camp's edge by its own leash on the next _pre_tick.
func displace_to(pos: Vector2) -> void:
	global_position = pos
	_last_nav_target_pos = Vector2(INF, INF)

func _pre_tick(_delta: float) -> void:
	"""Per-tick work independent of the active state (MobBase: leash check)."""
	pass

func _on_idle_state_stepped() -> void:
	_on_idle_state_processing(_tick_delta)

func _on_approach_state_stepped() -> void:
	_on_approach_state_processing(_tick_delta)

func _on_fight_state_stepped() -> void:
	_on_fight_state_processing(_tick_delta)

func _on_screen_entered() -> void:
	TickScheduler.set_on_screen(self, true)
	if animated_sprite and not animated_sprite.is_playing():
		animated_sprite.play()

func _on_screen_exited() -> void:
	TickScheduler.set_on_screen(self, false)
	if animated_sprite and animated_sprite.is_playing():
		animated_sprite.pause()


# ============================================
# SECTION 5b: HUD-PIN HELPERS (in-world HP bar consistency)
# ============================================

func set_hp_display(current: float, maximum: float) -> void:
	"""Single writer for the in-world HP bar (HpBar2D). Every HP change in
	the subclasses routes through here so the bar API lives in one place."""
	if health_bar:
		health_bar.set_values(current, maximum)

func _apply_ui_counter_scale() -> void:
	## The Hud group (HP bar + level label) inherits the entity's transform — when
	## the monster grows per evolution stage it would grow with it. Counter-scaling
	## the ONE group node by 1 / entity.scale keeps bar and label at a fixed pixel
	## size and keeps them together (scaling them separately drifted the label).
	## Heroes (scale=1) get an effective no-op. MonsterBase calls this again
	## on every step of its stage scale tween.
	if hud == null:
		return
	var sx: float = scale.x if scale.x != 0.0 else 1.0
	var sy: float = scale.y if scale.y != 0.0 else 1.0
	hud.scale = Vector2(1.0 / sx, 1.0 / sy)

func _on_damage_taken(_packet: DamagePacket) -> void:
	"""Per-target reaction hook, called directly by EventBus._route_packet after
	_receive_damage applied the HP change (only while still alive). Replaces
	the old per-entity damage_applied subscription that every entity used to
	filter with `packet.target != self`. Override to add behavior (e.g. a
	"help!" broadcast) and call super._on_damage_taken(packet)."""
	if flinch_duration > 0.0:
		_flinch_timer = flinch_duration

func _update_detection_radius() -> void:
	"""Update DetectionArea collision shape radius from export variable"""
	if not is_instance_valid(detection_area):
		return
	
	var collision_shape = detection_area.get_node_or_null("CollisionShape2D")
	if not collision_shape:
		return
	
	if collision_shape.shape is CircleShape2D:
		# The shape is resource_local_to_scene (NPCBaseClass.tscn) so this only
		# touches this entity. Still skip identical writes: set_radius always
		# emits `changed` and re-syncs the physics server.
		var circle := collision_shape.shape as CircleShape2D
		var radius: float = _get_detection_shape_radius()
		if not is_equal_approx(circle.radius, radius):
			circle.radius = radius
		
		# Visual debug
		if show_detection_radius:
			detection_area.visible = true
	else:
		push_warning(name + " DetectionArea is not using CircleShape2D!")

## Radius written to the DetectionArea shape, in the entity's local units (the
## shape scales with the entity). MonsterBase divides Titan Form's size out.
func _get_detection_shape_radius() -> float:
	return detection_radius

func _setup_navigation() -> void:
	"""Put the navigation agent on the world's default navigation map and
	raise its polygon search budget. The tuned path distances, simplify_path
	and the disabled avoidance live on the NPCBaseClass.tscn agent node."""
	if not is_instance_valid(navigation_agent_2d) or not is_inside_tree():
		return
	var nav_map: RID = get_world_2d().navigation_map
	if nav_map.is_valid():
		navigation_agent_2d.set_navigation_map(nav_map)
	GameUtils.configure_nav_agent(navigation_agent_2d)

# ============================================
# SECTION 6: VIRTUAL METHODS (TO OVERRIDE)
# ============================================

## Attack off cooldown? HeroBase, MobBase and MonsterBase override this.
## NOTE: flinch is checked separately at the fight-loop call site (so
## subclass overrides don't accidentally bypass it).
func _is_attack_ready() -> bool:
	return true

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

func get_max_health() -> float:
	"""Max health for HP-ratio math (HUD bars, low-HP targeting). Override in
	child classes; defaults to get_health() so a 1.0 ratio is the fallback."""
	return get_health()

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
	"""Target area + entity exist, the entity is in the tree (not parked in the
	spawn pool) and alive."""
	return is_instance_valid(target) and is_instance_valid(target_entity) \
		and target_entity.is_inside_tree() and EntityRegistry.is_entity_alive(target_entity)

func distance_to_target() -> float:
	"""Get distance to current target"""
	return target.global_position.distance_to(global_position) if is_target_valid() else INF

# ============================================
# SECTION 8: TARGETING SYSTEM
# ============================================

## Aim at `entity`: `target` is its "Body" Area2D, `target_entity` its root.
## The only way other systems (taunts, peels, resets) should retarget.
func set_target(entity: Node2D) -> void:
	target = entity.get_node_or_null(^"Body") as Area2D
	target_entity = entity

## Aim at the entity that owns `area` (a detection hit).
func set_target_area(area: Area2D) -> void:
	target = area
	target_entity = area.get_owner()

func clear_target() -> void:
	target = null
	target_entity = null

## Find the best target area among all valid targets in detection area.
## Returns the Area2D node (not the entity).
func _find_best_target() -> Area2D:
	if not is_instance_valid(detection_area):
		return null

	var best_area: Area2D = null
	var best_score: float = - INF

	for area in detection_area.get_overlapping_areas():
		if not _can_target_area(area):
			continue

		var entity: Node = area.get_owner()
		if not is_instance_valid(entity):
			continue

		var score: float = _score_target(entity)
		if score > best_score:
			best_score = score
			best_area = area

	return best_area if best_score > 0.0 else null

## Calculate score for a target (higher = better).
## Considers priority, distance, threat level, and engagement penalty.
func _score_target(target_node: Node2D) -> float:
	if not is_instance_valid(target_node):
		return -1000.0

	var score: float = 0.0
	var distance: float = global_position.distance_to(target_node.global_position)
	
	score += _get_target_priority(target_node)
	score += _get_distance_score(distance)
	score += _get_threat_score(target_node, distance)
	
	# Penalty for switching targets (prevents flip-flopping)
	if target_entity != target_node:
		score -= 20.0
	
	# Heavy penalty for too-distant targets
	if distance > max_chase_distance:
		score -= 100.0
	
	return score

func _get_target_priority(target_node: Node2D) -> float:
	"""Get base priority score based on target type"""
	match GameUtils.cached_faction_of(target_node):
		GameUtils.Faction.HERO, GameUtils.Faction.MONSTER:
			return priority_hero_monster
		GameUtils.Faction.MOB:
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

## Calculate threat score based on target behavior + team blackboard threat.
## `distance` is the distance to `target_node` when the caller already has it
## (_score_target); a negative value means "measure it here".
func _get_threat_score(target_node: Node2D, distance: float = -1.0) -> float:
	var threat: float = 0.0

	# Only entities carry a target pair and health; the pet does not.
	if target_node is EntityBase:
		var other := target_node as EntityBase
		# Is target attacking me?
		if other.target_entity == self:
			threat += 30.0
		# Is target low health? (was dead code: both numbers came from get_health())
		if other.is_alive():
			var max_hp: float = other.get_max_health()
			if max_hp > 0.0:
				var hp_frac: float = clampf(other.get_health() / max_hp, 0.0, 1.0)
				if hp_frac < 0.3:
					threat += 15.0
				threat += low_hp_focus_weight * (1.0 - hp_frac)

	# Is my current target far away (likely fleeing)? Cheapest test first.
	if distance < 0.0:
		distance = global_position.distance_to(target_node.global_position)
	if target_entity == target_node and distance > 400.0 and is_target_valid():
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

## Determine if should switch from current target to new target.
## Uses provided threshold to prevent excessive switching.
func _should_switch_target(new_target_area: Area2D, threshold: float) -> bool:
	if not is_target_valid():
		return true

	var new_target_node: Node = new_target_area.get_owner()
	if not is_instance_valid(new_target_node):
		return false

	var current_score: float = _score_target(target_entity)
	var new_score: float = _score_target(new_target_node)

	return new_score > current_score + threshold

func _reevaluate_current_target(threshold: float) -> void:
	var best_target_area: Area2D = _find_best_target()

	if not best_target_area:
		if is_target_valid() and pursue_out_of_sight_radius > 0.0 \
				and global_position.distance_squared_to(target_entity.global_position) <= pursue_out_of_sight_radius * pursue_out_of_sight_radius:
			return  # still pursuing what we were sent after
		if is_target_valid():
			clear_target()
			state_chart.send_event(CombatEvents.ENEMY_EXITED)
		return
	
	if is_target_valid() and target_entity == best_target_area.get_owner():
		return
	
	if _should_switch_target(best_target_area, threshold):
		set_target_area(best_target_area)

## Re-engage the best enemy still in the detection area (Idle / Approach entry).
func _check_for_nearby_enemies() -> void:
	if not is_instance_valid(detection_area):
		return

	var best_target_area := _find_best_target()
	if best_target_area:
		_engage(best_target_area)

## Take the detected `area` as the target, start the approach and call allies in.
func _engage(area: Area2D) -> void:
	set_target_area(area)
	state_chart.send_event(CombatEvents.ENEMY_ENTERED)
	_broadcast_aggro(target_entity)

## Tell allies within alert_allies_radius about this target. Mobs use this
## to make a pack engage together when one of them spots a hero.
func _broadcast_aggro(spotted: Node) -> void:
	if alert_allies_radius <= 0.0 or not is_instance_valid(spotted):
		return
	var team := TeamRegistry.team_of(self)
	if team == null:
		return
	var r_sq := alert_allies_radius * alert_allies_radius
	# The ally's pair matches set_target(spotted): Body area + root entity.
	# Resolved once here instead of once per nudged ally.
	var spotted_area := spotted.get_node_or_null(^"Body") as Area2D
	for ally in team.members:
		if ally == self or not is_instance_valid(ally):
			continue
		var a := ally as EntityBase
		if a == null:
			continue
		# Cheapest test first. Only nudge idle allies (already engaged ones
		# keep their target) that CAN target this entity.
		if a.global_position.distance_squared_to(global_position) > r_sq:
			continue
		if a.is_target_valid():
			continue
		if not GameUtils.can_entity_target(a, spotted):
			continue
		a.target = spotted_area
		a.target_entity = spotted
		if a.state_chart:
			a.state_chart.send_event(CombatEvents.ENEMY_ENTERED)

## Group rules: never myself, only areas owned by an entity I may attack.
func _can_target_area(area: Area2D) -> bool:
	var root: Node = area.get_owner()
	if root == self or area.get_parent() == self:
		return false
	if not root:
		return false
	return GameUtils.can_entity_target(self, root)

# ============================================
# SECTION 9: DETECTION AREA SIGNALS
# ============================================

## Called when an area enters detection range
func _on_detection_area_area_entered(area: Area2D) -> void:
	if not _can_target_area(area):
		return

	var best_target_area := _find_best_target()
	if best_target_area:
		_engage(best_target_area)

## Called when an area exits detection range
func _on_detection_area_area_exited(area: Area2D) -> void:
	if target == area:
		_reevaluate_current_target(switch_threshold_approach)

# ============================================
# SECTION 10: MOVEMENT & NAVIGATION
# ============================================

## Rotate the sprite toward `dir` smoothly. Replaces the old
## instant `sprite.rotation = dir.angle()` — entities now turn instead of snap.
func _face(dir: Vector2, delta: float) -> void:
	if not sprite or dir.length_squared() < 0.0001:
		return
	var aim := dir.angle()
	if rotation_smooth_speed <= 0.0:
		# Opt-out: instant rotation
		sprite.rotation = aim
		_facing_angle = aim
		return
	# Exponential weight: frame-rate independent. The old linear weight
	# (speed * delta, clamped) hit 1.0 at <= 12 Hz, i.e. snapped at low LOD rates.
	_facing_angle = lerp_angle(_facing_angle, aim, 1.0 - exp(-rotation_smooth_speed * delta))
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
	var to_next := next_pos - global_position
	var dist := to_next.length()
	if dist < 0.001:
		return
	var dir := to_next / dist
	# Clamp the step to the remaining distance: at 3 Hz a 150 px/s mob would
	# otherwise overshoot a 6 px path point by ~45 px every tick.
	position += dir * minf(speed * delta, dist)
	_face(dir, delta)

func _set_nav_target_lazy(target_pos: Vector2) -> void:
	"""Set navigation target only if it moved significantly (lazy update optimization)"""
	if not is_instance_valid(navigation_agent_2d):
		return
	
	var distance_moved = target_pos.distance_to(_last_nav_target_pos)
	if distance_moved > _nav_update_threshold:
		navigation_agent_2d.target_position = target_pos
		_last_nav_target_pos = target_pos

func _set_nav_target(target_pos: Vector2) -> void:
	"""Set the navigation target unconditionally and keep the lazy cache in
	sync (idle goals, kiting points — anything that is not a moving target)."""
	if not is_instance_valid(navigation_agent_2d):
		return
	navigation_agent_2d.target_position = target_pos
	_last_nav_target_pos = target_pos

## Move straight toward a point (no path), never through a wall: the step ends
## where the navigation mesh does (fighters strafing in a fight walked through
## walls). An entity already off the mesh moves freely so it is never frozen.
## Returns false when a wall blocked the whole step.
func move_toward_point(target_pos: Vector2, speed: float, delta: float) -> bool:
	var to_target := target_pos - global_position
	var dist := to_target.length()
	if dist < 0.001:
		return true
	var dir := to_target / dist
	var wanted: Vector2 = global_position + dir * minf(speed * delta, dist)
	var world := get_world_2d()
	if GameUtils.is_on_nav(world, global_position):
		wanted = GameUtils.clamp_to_nav_segment(world, global_position, wanted)
	_face(dir, delta)
	if wanted.distance_squared_to(global_position) < 0.0001:
		return false
	global_position = wanted
	return true

func _move_toward_target(speed: float, delta: float) -> void:
	"""Navigate toward current target"""
	if not is_target_valid():
		return
	_set_nav_target_lazy(target.global_position)
	_steer_along_nav(speed, delta)

## Navigate away from current target
func _move_away_from_target(speed: float, delta: float) -> void:
	if not is_target_valid():
		return
	var away_dir: Vector2 = (global_position - target.global_position).normalized()
	var away_point: Vector2 = global_position + away_dir * 100.0
	_set_nav_target_lazy(away_point)
	_steer_along_nav(speed, delta)

## Kite away from target with lateral movement
func _kite_away_from_target(speed: float, delta: float) -> void:
	if not is_target_valid():
		return
	var away_dir: Vector2 = (global_position - target.global_position).normalized()
	var perpendicular: Vector2 = Vector2(-away_dir.y, away_dir.x) * strafe_direction
	var kite_dir: Vector2 = (away_dir + perpendicular * 0.3).normalized()
	var kite_point: Vector2 = global_position + kite_dir * 80.0
	_set_nav_target_lazy(kite_point)
	_steer_along_nav(speed, delta)

func _strafe_around_target(delta: float, dir: Vector2) -> void:
	"""Circle strafe around target"""
	if not is_target_valid():
		return
	
	strafe_timer += delta
	if strafe_timer >= strafe_change_interval:
		strafe_timer -= strafe_change_interval
		if randf() > 0.5:
			strafe_direction *= -1
	
	# Direct move: the old code pushed a ~1 px nav target that the lazy helper
	# swallowed, so strafing barely moved. Rate-independent now (no delta in
	# the aim point; move_toward_point applies speed * delta).
	var perpendicular := Vector2(-dir.y, dir.x) * strafe_direction
	if not move_toward_point(global_position + perpendicular * 32.0, strafe_speed, delta):
		strafe_direction *= -1  # a wall: circle the other way instead of grinding on it

# ============================================
# SECTION 11: IDLE EXPLORATION
# ============================================

## The next idle goal, picked by _on_idle_state_processing on each re-pick.
## Default: the best of a few random samples around me (avoids off-mesh
## points). HeroBase (the exploration goal), MobBase (its camp), MonsterBase
## (its strategy) and Irelia (her allies) override it.
func _get_smart_idle_destination() -> Vector2:
	return _get_valid_random_destination()

## Sample multiple random points and pick the best one. Off-mesh samples
## (score -1000) never win; the fallback is staying put, which re-rolls on
## the next tick.
func _get_valid_random_destination() -> Vector2:
	var best_point: Vector2 = global_position
	var best_score: float = -999.0
	var samples: int = 5

	for i in range(samples):
		var candidate: Vector2 = _generate_random_point()
		var score: float = _score_destination(candidate)
		
		if score > best_score:
			best_score = score
			best_point = candidate
	
	return best_point

func _generate_random_point() -> Vector2:
	"""Generate a random point around current position"""
	var angle := randf() * TAU
	var dir := Vector2.from_angle(angle)
	
	var radius: float = _idle_sample_radius()
	var dist := randf_range(radius * 0.3, radius)
	return global_position + dir * dist

## Nav-mesh validity instead of raycasts: the TileSet has no physics layer,
## so the old wall rays (5 samples x 20 rays per retarget) could only ever
## hit Ted's pet. A point further than 16 px from the nav mesh is unreachable.
## Only asked when the map can answer (synced and has regions): before the
## first sync the query logs an engine error, and a region-less map would
## reject every point, so without a usable map every point counts as on it.
func _is_on_nav_mesh(point: Vector2) -> bool:
	var nav_map: RID = GameUtils.usable_nav_map(get_world_2d())
	if not nav_map.is_valid():
		return true
	var on_mesh: Vector2 = NavigationServer2D.map_get_closest_point(nav_map, point)
	return on_mesh.distance_squared_to(point) <= 16.0 * 16.0

## Score a destination point (higher = better); -1000 when it is off the nav mesh.
func _score_destination(point: Vector2) -> float:
	if not _is_on_nav_mesh(point):
		return -1000.0

	var score: float = 0.0
	var current_facing: float = sprite.rotation if sprite else 0.0
	var to_point: Vector2 = (point - global_position).normalized()
	var point_angle: float = to_point.angle()
	var angle_diff: float = absf(GameUtils.wrapped_angle_delta(current_facing, point_angle))
	score += (PI - angle_diff) * 50.0
	score += _destination_bonus(point)
	return score

## Outer radius of the random idle samples. HeroBase widens it.
func _idle_sample_radius() -> float:
	return idle_wander_radius

## Extra score for an idle sample point on top of the facing term. HeroBase
## prefers unexplored fog.
func _destination_bonus(_point: Vector2) -> float:
	return 0.0

# ============================================
# SECTION 12: XP SYSTEM
# ============================================

func _grant_xp_to_killer() -> void:
	"""Grant the MONSTER its XP for this kill (xp_value) when it landed the
	blow — falls back to my current target so a mob killed by an AoE while
	chasing a hero still feeds the monster. Heroes level from the shared
	mob XP instead (MobBase._share_hero_xp), never from xp_value."""
	if xp_value <= 0.0:
		return
	for candidate in [last_attacker, target_entity]:
		if is_instance_valid(candidate) and candidate is MonsterBase:
			candidate.gain_xp(xp_value)
			return

# ============================================
# SECTION 13: STATE CHART HANDLERS
# ============================================

## Idle State - Wandering and waiting for targets

func _on_idle_state_entered() -> void:
	"""Entered Idle state - reset idle timers and check for enemies"""
	_idle_timer = 0.0
	_idle_goal = global_position
	_check_for_nearby_enemies()

## The one idle-wander loop for every entity: subclasses change only where it
## goes (_get_smart_idle_destination) and whether a path that ended short of
## the goal re-picks early (_idle_repick_on_path_end).
func _on_idle_state_processing(delta: float) -> void:
	if not is_instance_valid(navigation_agent_2d):
		return

	_idle_timer -= delta
	# Also re-pick when the path ended far short of the goal (unreachable goal,
	# e.g. a pocket of the nav mesh) instead of waiting out the retarget timer.
	# The hook goes first: is_navigation_finished() refreshes the agent, so an
	# entity that opts out must not call it.
	var reached: bool = global_position.distance_squared_to(_idle_goal) < 64.0
	var gave_up: bool = _idle_repick_on_path_end() and navigation_agent_2d.is_navigation_finished() and not reached
	if _idle_timer <= 0.0 or reached or gave_up:
		# Keep the overshoot so intervals don't round up to whole LOD ticks.
		_idle_timer = idle_retarget_time + minf(_idle_timer, 0.0)
		_idle_goal = _get_smart_idle_destination()
		# Standing exactly on a goal the agent already targets (MonsterBase rest,
		# the random-destination fallback): a new path cannot move us, and
		# set_target_position always re-queries the path.
		if _idle_goal != global_position or _idle_goal != _last_nav_target_pos:
			_set_nav_target(_idle_goal)

	_steer_along_nav(move_speed, delta)

## Idle: re-pick as soon as the path to the goal ended short of it. MobBase
## and Irelia (away from the exploring group) wait for the retarget timer.
func _idle_repick_on_path_end() -> bool:
	return true

## Approach State - Chasing target

func _on_approach_state_entered() -> void:
	"""Entered Approach state - initialize re-evaluation timer"""
	_target_reeval_timer = target_reeval_interval_approach
	# Force a fresh path on the first approach tick even if the target is
	# within the lazy threshold of wherever we last pathed to.
	_last_nav_target_pos = Vector2(INF, INF)
	
	if not is_target_valid():
		_check_for_nearby_enemies()

## Process Approach state - chase target and periodically re-evaluate
func _on_approach_state_processing(delta: float) -> void:
	if not is_target_valid():
		state_chart.send_event(CombatEvents.ENEMY_EXITED)
		return

	if target.global_position.distance_to(global_position) <= maxf(attack_range, keep_distance):
		state_chart.send_event(CombatEvents.ENEMY_FIGHT)
		return

	# Periodic target re-evaluation while chasing
	_target_reeval_timer -= delta
	if _target_reeval_timer <= 0.0:
		_target_reeval_timer += target_reeval_interval_approach
		_reevaluate_current_target(switch_threshold_approach)
		# Re-eval may have cleared target and sent ENEMY_EXITED. send_event
		# runs the transition synchronously (the addon's step() does not lock
		# the chart and the transitions have 0.0 delay), so re-check before
		# using target.
		if not is_target_valid():
			return

	if is_instance_valid(navigation_agent_2d):
		# Lazy: only re-path when the target moved > _nav_update_threshold.
		# Writing target_position every frame recomputed the path per mob per frame.
		_set_nav_target_lazy(target.global_position)
		_steer_along_nav(move_speed, delta)
	else:
		move_toward_point(target.global_position, move_speed, delta)

## Fight State - In combat with target

func _on_fight_state_entered() -> void:
	"""Entered Fight state - initialize re-evaluation timer"""
	_target_reeval_timer = target_reeval_interval_fight

	if not is_target_valid():
		state_chart.send_event(CombatEvents.TARGET_LOST)

## Process Fight state - combat and periodic re-evaluation
func _on_fight_state_processing(delta: float) -> void:
	if not is_target_valid():
		state_chart.send_event(CombatEvents.TARGET_LOST)
		return

	var distance: float = target.global_position.distance_to(global_position)

	if distance > max_distance:
		state_chart.send_event(CombatEvents.RE_APPROACH)
		return

	_target_reeval_timer -= delta
	if _target_reeval_timer <= 0.0:
		_target_reeval_timer += target_reeval_interval_fight
		_reevaluate_current_target(switch_threshold_fight)
		# Re-eval may have cleared target and sent ENEMY_EXITED. send_event
		# runs the transition synchronously (the addon's step() does not lock
		# the chart and the transitions have 0.0 delay), so re-check before
		# using target.
		if not is_target_valid():
			return

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
	_release_or_free()

func _release_or_free() -> void:
	"""Dead: free the node. MobBase overrides to return to the spawn pool."""
	queue_free()

func reset_to_idle() -> void:
	"""Pooling: drive the chart back to Idle from any state. Approach consumes
	ENEMY_EXITED, Fight consumes TARGET_LOST, Dead consumes RESET; Idle ignores
	all three. Call only while in the tree (Idle's entered handler scans the
	detection area)."""
	if not is_instance_valid(state_chart) or not state_chart.is_node_ready():
		return
	state_chart.send_event(CombatEvents.ENEMY_EXITED)
	state_chart.send_event(CombatEvents.TARGET_LOST)
	state_chart.send_event(CombatEvents.RESET)
