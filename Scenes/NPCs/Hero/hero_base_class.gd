extends EntityBase
class_name HeroBase

@export_group("Ultimate Auto-Cast")
@export var auto_use_ultimate: bool = true
## Don't auto-fire the ult unless at least this many enemies are within
## auto_ult_radius. Prevents Vlad from nuking a single bat with Blood Bomb.
## Not an export: _apply_match_config sets it from MatchConfig in _ready.
var auto_ult_min_enemies: int = 3
@export var auto_ult_radius: float = 200.0
## OR: auto-fire if any ally is below this HP fraction (panic ult).
## Not an export: _apply_match_config sets it from MatchConfig in _ready.
var auto_ult_panic_hp_pct: float = 0.25
## How often to evaluate the auto-ult conditions. 4 Hz is plenty.
@export var auto_ult_check_interval: float = 0.25

@export_group("Active Auto-Cast")
## Heroes are AI-controlled: without this the active ability (Irelia's shield,
## Ted's Rally Cry, Vlad's mine, River's weapon swap) was never used at all.
@export var auto_use_active: bool = true

@onready var stats: HeroStatsComponent = %HeroStats
@onready var ability_system: AbilitySystem = %AbilitySystem

var max_health: float:
	get: return stats.get_max_health() if stats else 100.0

var health: float:
	get: return stats.get_current_health() if stats else 0.0

var _auto_ult_timer: float = 0.0
var _auto_active_timer: float = 0.0
# Temporary attack-speed boost (Rally Cry etc.); read by AbilitySystem.
var _attack_speed_boost: float = 1.0
var _attack_speed_boost_timer: float = 0.0

func _ready() -> void:
	if not stats or not stats.base_stats:
		push_error(name + " requires HeroStatsComponent with base_stats!")
		return

	stats.health_changed.connect(_on_health_changed)
	stats.leveled_up.connect(_on_level_changed)
	_setup_combat_role_from_stats()
	_apply_match_config(MatchConfig.for_current_match())
	# The scene VisionArea (HeroBaseClass.tscn) takes its radius from
	# HeroStats in both play modes: it is also the hero AI's exploration
	# memory, which must not depend on the side the player chose.
	var vision := get_node_or_null(^"VisionArea") as VisionArea
	if vision:
		vision.set_vision_radius(stats.base_stats.vision_radius)

	# Apply permanent meta-skill upgrades to this hero's stats BEFORE
	# super._ready() so the EntityBase HUD setup reads the post-bonus
	# max_health for the floating HP bar.
	MetaSkillManager.apply_unlocked_to_hero(self)

	super._ready()

func _process(delta: float) -> void:
	if _attack_speed_boost_timer > 0.0:
		_attack_speed_boost_timer -= delta
		if _attack_speed_boost_timer <= 0.0:
			_attack_speed_boost = 1.0
	if is_stunned():
		return
	if auto_use_active and is_alive():
		_auto_active_timer -= delta
		if _auto_active_timer <= 0.0:
			_auto_active_timer = auto_ult_check_interval
			if is_active_ready() and _should_auto_use_active():
				_use_active_now()
	if not auto_use_ultimate:
		return
	# Throttle the ult-check; it scans the enemy registry.
	_auto_ult_timer -= delta
	if _auto_ult_timer > 0.0:
		return
	_auto_ult_timer = auto_ult_check_interval
	if is_ultimate_ready() and _should_auto_use_ultimate():
		use_ultimate()


## Default: fire the active once actually fighting (target within reach).
## Heroes override for support logic (River swaps weapons, Irelia shields).
func _should_auto_use_active() -> bool:
	if not is_target_valid():
		return false
	return distance_to_target() <= maxf(attack_range * 1.5, 120.0)


func _use_active_now() -> void:
	use_active_ability()


## Temporary attack-speed multiplier (e.g. Rally Cry). Folded into basic-attack
## cooldown recovery by AbilitySystem.get_attack_speed_multiplier.
func apply_attack_speed_boost(multiplier: float, duration: float) -> void:
	_attack_speed_boost = maxf(multiplier, 0.01)
	_attack_speed_boost_timer = duration


func get_attack_speed_boost() -> float:
	return _attack_speed_boost

## Pre-round strategy (PreRoundSetup → MatchConfig). Called from _ready, so
## MatchConfig owns these values for every hero (the player's sliders, or the
## neutral defaults when the heroes are the AI opponent). priority_mob stays
## an EntityBase export because mobs and the monster use their scene value.
func _apply_match_config(cfg: MatchConfig) -> void:
	auto_ult_min_enemies = cfg.auto_ult_min_enemies()
	auto_ult_panic_hp_pct = cfg.auto_ult_panic_hp_pct()
	priority_mob = int(cfg.priority_mob())


func _should_auto_use_ultimate() -> bool:
	"""Smarter ult auto-cast: fire when worth it, not just because it's ready.
	Subclasses (River, Ted) can override for healer/support semantics."""
	# Panic case: any ally critically low → fire even on a single enemy.
	var team := TeamRegistry.get_team(TeamRegistry.HEROES)
	if team and team.find_lowest_hp_ally(auto_ult_panic_hp_pct, self) != null:
		return true
	# Otherwise: need enough enemies clustered to be worth the cooldown.
	if not is_target_valid():
		return false
	# Cached registry list, squared distances, stops counting at the threshold.
	var nearby_enemies := EntityRegistry.count_within(
		EntityRegistry.enemies, target_entity.global_position, auto_ult_radius, auto_ult_min_enemies)
	return nearby_enemies >= auto_ult_min_enemies
# Add to HeroBase class
var exploration_target: Vector2 = Vector2.ZERO
var use_exploration_target: bool = false

func set_exploration_target(new_target: Vector2) -> void:
	exploration_target = new_target
	use_exploration_target = true

func _setup_combat_role_from_stats() -> void:
	if not stats or not stats.base_stats:
		return
	
	# Read from HeroStats resource
	combat_role = stats.base_stats.combat_role
	preferred_distance = stats.base_stats.preferred_distance
	min_distance = stats.base_stats.min_distance
	max_distance = stats.base_stats.max_distance
	strafe_enabled = stats.base_stats.strafe_enabled
	strafe_speed = stats.base_stats.strafe_speed
	strafe_change_interval = stats.base_stats.strafe_change_interval
	# The Fight gate is `min_distance <= distance <= attack_range`. A minimum at
	# or above the range (Vlad shipped 80 vs 50) means the hero NEVER attacks.
	var reach: float = stats.get_attack_range() if stats.get_attack_range() > 0.0 else stats.base_stats.base_attack_range
	# (Ranged heroes legitimately kite at ~60% of their range; only a band too
	# thin to stand in is a data error.)
	if min_distance > reach * 0.8:
		push_warning("%s: min_distance %.0f leaves no attack band below range %.0f — clamped" % [name, min_distance, reach])
		min_distance = reach * 0.5
	preferred_distance = clampf(preferred_distance, min_distance, maxf(reach, min_distance))


func _is_attack_ready() -> bool:
	if not ability_system:
		return true
	return ability_system.cooldowns[AbilityBase.AbilityType.BASIC_ATTACK] <= 0.0

func _get_entity_level() -> int:
	if stats:
		return stats.level
	return 1

## In-round XP from mob kills nearby (MobBase._share_hero_xp).
func gain_xp(amount: float) -> void:
	if stats:
		stats.add_xp(amount)

func _on_level_changed(new_level: int) -> void:
	if lv_label:
		lv_label.text = str(new_level)

func _get_move_speed() -> float:
	return stats.get_move_speed() if stats else 80.0

func _get_attack_range() -> float:
	return stats.get_attack_range() if stats else 50.0

func _get_idle_retarget_time() -> float:
	return stats.base_stats.idle_retarget_time if stats and stats.base_stats else 1.2

func _get_idle_wander_radius() -> float:
	return stats.base_stats.idle_wander_radius if stats and stats.base_stats else 160.0

func _get_keep_distance() -> float:
	return stats.base_stats.keep_distance if stats and stats.base_stats else 24.0

func _is_always_full_rate() -> bool:
	return true  # camera anchor: never LOD-throttled

func is_alive() -> bool:
	return stats.is_alive() if stats else false

func get_health() -> float:
	return stats.get_current_health() if stats else 0.0

func get_max_health() -> float:
	return stats.get_max_health() if stats else 0.0

func _receive_damage(packet: DamagePacket) -> void:
	if not is_alive() or not stats:
		return

	last_attacker = packet.source if packet.source is Node2D else null
	stats.take_damage(packet.amount)

	if not stats.is_alive():
		state_chart.send_event(CombatEvents.SELF_DEAD)

func _on_health_changed(current: float, max_hp: float) -> void:
	set_hp_display(current, max_hp)

func _on_fight_logic(_delta: float) -> void:
	if ability_system:
		ability_system.use_basic_attack(target_entity)

func use_active_ability() -> bool:
	if not ability_system:
		return false
		
	if not is_target_valid():
		return false
	return ability_system.use_active(target_entity)

func use_ultimate() -> bool:
	if not ability_system or ability_system.is_on_cooldown(AbilityBase.AbilityType.ULTIMATE):
		return false
		
	if not is_target_valid():
		return false
		
	return ability_system.use_ultimate(target_entity)

func is_active_ready() -> bool:
	return ability_system and not ability_system.is_on_cooldown(AbilityBase.AbilityType.ACTIVE)

func is_ultimate_ready() -> bool:
	return ability_system and not ability_system.is_on_cooldown(AbilityBase.AbilityType.ULTIMATE)
