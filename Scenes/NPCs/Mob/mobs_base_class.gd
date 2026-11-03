extends EntityBase
class_name MobBase

@export_group("Mob Stats")
@export var max_health: float = 50.0
@export var base_move_speed: float = 70.0
@export var base_attack_range: float = 40.0
@export var base_attack_damage: float = 5.0
@export var attack_cooldown: float = 1.5

@export_group("Mob Rewards")
## In-round XP shared by heroes near the kill (README mob table "Hero XP").
## `xp_value` (EntityBase) stays the MONSTER's XP for the kill.
@export var hero_xp_value: float = 6.0
## Heroes within this distance of the kill share hero_xp_value: 100% at the
## kill, falling to 50% at the edge (README "XP Radius: 800 units").
@export var hero_xp_radius: float = 800.0

@export_group("Mob Behavior")
@export var base_idle_retarget_time: float = 1.2
@export var base_idle_wander_radius: float = 120.0
@export var base_keep_distance: float = 20.0
@export var chase_distance: float = 400.0

@onready var attack_timer: Timer = %AttackTimer

var current_health: float
var attacking: bool = false
var spawn_area: Node = null
var spawn_position: Vector2 = Vector2.ZERO

# Pooling (SpawnManager.acquire_mob / release_mob)
var pool_key: String = ""            ## scene resource_path; "" = never pooled, free on death
var spawn_manager: SpawnManager = null
var is_parked: bool = false          ## true while out of the tree in the pool
var _spawn_scale: Vector2 = Vector2.ONE
## Incremented per life. Outside holders (trap cage, taunt) compare it before
## acting so a reused node never inherits an old effect.
var life_id: int = 0

# ============================================
# STATE TRACKING - Instead of get_active_state()
# ============================================
var is_in_combat: bool = false

func _ready() -> void:
	_setup_mob_combat_role()
	current_health = max_health
	attack_timer.wait_time = attack_cooldown
	_spawn_scale = scale
	set_hp_display(current_health, max_health)

	# Mobs alert nearby pack-mates when they spot a hero. EntityBase reads
	# alert_allies_radius and broadcasts on aggro. Default 200 = pack feels
	# coordinated without crossing the map.
	if alert_allies_radius == 0.0:
		alert_allies_radius = 200.0

	super._ready()

# ============================================
# STATE TRACKING - Set flags when entering states
# ============================================

func _on_idle_state_entered() -> void:
	is_in_combat = false
	super._on_idle_state_entered()

func _on_approach_state_entered() -> void:
	is_in_combat = true
	super._on_approach_state_entered()

func _on_fight_state_entered() -> void:
	is_in_combat = true
	super._on_fight_state_entered()

func _on_dead_state_entered() -> void:
	is_in_combat = false
	_on_mob_death()
	super._on_dead_state_entered()

# ============================================
# FIXED: Only enforce boundaries when NOT in combat
# ============================================

func _pre_tick(_delta: float) -> void:
	# Runs at this mob's LOD rate (TickScheduler), not every frame.
	# A corpse ticks once more in its death frame (release is deferred): never
	# leash-clamp or heal it.
	if is_parked or not is_alive():
		return
	# Only check boundaries if we're NOT in combat
	if not is_in_combat:
		if spawn_area and spawn_area.has_method("is_position_in_area"):
			if not spawn_area.is_position_in_area(global_position):
				_handle_out_of_bounds()

func _handle_out_of_bounds() -> void:
	# Clamp to spawn area during idle wandering
	if spawn_area and spawn_area.has_method("clamp_position_to_area"):
		global_position = spawn_area.clamp_position_to_area(global_position)
	
	# Check if too far from spawn (even during combat)
	if spawn_position != Vector2.ZERO:
		var distance_from_spawn = global_position.distance_to(spawn_position)
		
		# If beyond chase distance, force reset
		if distance_from_spawn > chase_distance:
			_reset_to_spawn()

func _reset_to_spawn() -> void:
	if not is_alive():
		return
	global_position = spawn_position
	target = null
	target_entity = null
	attacking = false
	attack_timer.stop()
	is_in_combat = false
	
	# Heal to full on reset
	_restore_full_health()
	
	# Return to idle
	if state_chart:
		state_chart.send_event(CombatEvents.ENEMY_EXITED)

# ============================================
# Combat Role
# ============================================

func _setup_mob_combat_role() -> void:
	combat_role = Types.CombatRole.MELEE
	preferred_distance = base_attack_range * 0.8
	# Never let the melee floor exceed half the reach: a scene that sets a tiny
	# attack range (old Hog = 10) would otherwise make the Fight gate
	# `distance <= attack_range and distance >= min_distance` unsatisfiable.
	min_distance = minf(20.0, base_attack_range * 0.5)
	max_distance = base_attack_range * 1.5
	strafe_enabled = true
	strafe_speed = 40.0
	strafe_change_interval = 3.0

func _is_attack_ready() -> bool:
	return not attacking

# ============================================
# EntityBase Overrides
# ============================================
func _get_entity_level() -> int:
	return 1
func _get_move_speed() -> float:
	return base_move_speed

func _get_attack_range() -> float:
	return base_attack_range

func _get_idle_retarget_time() -> float:
	return base_idle_retarget_time

func _get_idle_wander_radius() -> float:
	return base_idle_wander_radius

func _get_keep_distance() -> float:
	return base_keep_distance

func is_alive() -> bool:
	return current_health > 0.0

func get_health() -> float:
	return current_health

func get_max_health() -> float:
	return max_health

func _receive_damage(packet: DamagePacket) -> void:
	if not is_alive():
		return

	last_attacker = packet.source if packet.source is Node2D else null
	current_health = maxf(0.0, current_health - packet.amount)
	set_hp_display(current_health, max_health)

	if current_health <= 0.0:
		state_chart.send_event(CombatEvents.SELF_DEAD)

# ============================================
# Idle Wandering (Restricted to Spawn Area)
# ============================================

func _on_idle_state_processing(delta: float) -> void:
	if not is_instance_valid(navigation_agent_2d):
		return
		
	_idle_timer -= delta
	if _idle_timer <= 0.0 or global_position.distance_squared_to(_idle_goal) < 64.0:
		_idle_timer = idle_retarget_time + minf(_idle_timer, 0.0)
		
		# Get random position within spawn area
		if spawn_area and spawn_area.has_method("get_random_roam_position"):
			_idle_goal = spawn_area.get_random_roam_position()
		else:
			var angle := randf() * TAU
			var dir := Vector2.from_angle(angle)
			var dist := randf_range(base_idle_wander_radius * 0.2, base_idle_wander_radius)
			_idle_goal = global_position + dir * dist
			
			# Clamp to spawn area
			if spawn_area and spawn_area.has_method("clamp_position_to_area"):
				_idle_goal = spawn_area.clamp_position_to_area(_idle_goal)
		
		_set_nav_target(_idle_goal)

	_steer_along_nav(move_speed, delta)

# ============================================
# Combat
# ============================================

func _on_fight_logic(_delta: float) -> void:
	if not attacking:
		attacking = true
		attack_timer.start()

func _perform_basic_attack() -> void:
	if not is_instance_valid(target_entity):
		attacking = false
		return

	var distance = global_position.distance_to(target_entity.global_position)
	if distance <= base_attack_range:
		EventBus.deal_damage(self, target_entity, base_attack_damage)

	attacking = false

func _on_attack_timer_timeout() -> void:
	# Clear the swing flag first: if the target vanished mid-swing the old
	# code left `attacking` stuck at true and the mob never attacked again.
	attacking = false
	if is_target_valid() and not is_stunned():  # a stun interrupts the swing
		_perform_basic_attack()

func _on_mob_death() -> void:
	"""Hook for subclasses (loot, VFX). EntityBase._on_dead_state_entered then
	calls _release_or_free() — pooled mobs are parked, not freed."""
	_share_hero_xp()


## README "Hero Leveling (In-Round)": every hero within hero_xp_radius of the
## kill gets hero_xp_value scaled 100% → 50% by distance, whoever landed the
## blow (so a group clearing a camp levels together).
func _share_hero_xp() -> void:
	if hero_xp_value <= 0.0 or hero_xp_radius <= 0.0:
		return
	var r_sq := hero_xp_radius * hero_xp_radius
	for h in EntityRegistry.heroes:
		if not is_instance_valid(h) or not (h is HeroBase) or not (h as HeroBase).is_alive():
			continue
		var d_sq := h.global_position.distance_squared_to(global_position)
		if d_sq > r_sq:
			continue
		var share: float = lerpf(1.0, 0.5, sqrt(d_sq) / hero_xp_radius)
		(h as HeroBase).gain_xp(hero_xp_value * share)

# ============================================
# Pooling (see SpawnManager.acquire_mob / release_mob)
# ============================================

func _release_or_free() -> void:
	# Deferred: we are usually inside TickScheduler's loop or a damage callback.
	if pool_key != "" and is_instance_valid(spawn_manager):
		spawn_manager.release_mob.call_deferred(self)
	else:
		queue_free()

func prepare_for_pool() -> void:
	"""Scrub per-life state before SpawnManager parks us out of the tree.
	A parked mob is never alive (HP 0) so nobody keeps targeting it;
	on_spawned() restores full health on reuse."""
	is_parked = true
	current_health = 0.0
	life_id += 1
	target = null
	target_entity = null
	last_attacker = null
	attacking = false
	if attack_timer:
		attack_timer.stop()
	is_in_combat = false
	_flinch_timer = 0.0
	_stun_timer = 0.0  # a stun only decays while in the tree; never carry it into the next life
	_idle_timer = 0.0
	_target_reeval_timer = 0.0
	strafe_timer = 0.0
	_last_nav_target_pos = Vector2(INF, INF)
	if is_instance_valid(navigation_agent_2d):
		navigation_agent_2d.target_position = global_position
	_kill_transient_effects()
	# Visual LOD: the ScreenNotifier only reports CHANGES, so a mob parked while
	# on screen would otherwise keep animating off screen after reuse.
	if animated_sprite and animated_sprite.is_playing():
		animated_sprite.pause()
	modulate = Color.WHITE
	if sprite:
		sprite.modulate = Color.WHITE
	scale = _spawn_scale

func reset_for_spawn(area: Node, pos: Vector2, leash: float) -> void:
	"""Per-life setup; valid before add_child for fresh and pooled instances."""
	spawn_area = area
	spawn_position = pos
	chase_distance = leash
	position = pos
	visible = true

func on_spawned(pos: Vector2) -> void:
	"""Called by MobSpawnArea right after add_child (in tree, chart ready).
	A fresh instance starts in Idle with full HP via _ready; a reused one
	needs the heal and the chart driven back to Idle from Dead/Approach/Fight."""
	global_position = pos
	if is_parked:
		is_parked = false
		life_id += 1
		_restore_full_health()
		reset_to_idle()

func _restore_full_health() -> void:
	current_health = max_health
	set_hp_display(current_health, max_health)

func _kill_transient_effects() -> void:
	# Taunt links / markers that abilities attach to us (group set in code
	# by the ability since they are created at runtime).
	for child in get_children():
		if child.is_in_group(&"TransientEffect"):
			remove_child(child)
			child.queue_free()
