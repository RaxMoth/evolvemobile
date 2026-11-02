extends Node
class_name AbilitySystem

signal ability_used(ability: AbilityBase)
signal cooldown_updated(ability_type: AbilityBase.AbilityType, time_remaining: float)

@export var passive_ability: AbilityBase
@export var active_ability: AbilityBase
@export var basic_attack: AbilityBase
@export var ultimate_ability: AbilityBase

var owner_entity: Node2D
var _hero_stats: HeroStatsComponent = null  # cached; monsters have none
var cooldowns: Dictionary = {} # AbilityType -> time_remaining
var _last_emitted_cooldowns: Dictionary = {} # Track last emitted values to reduce signal spam
## The cooldown each ability started at on its last cast, so the HUD can draw
## remaining / total (the remaining time shrinks faster than wall time when
## attack speed is boosted, and freezes while the tree is paused).
var _cooldown_totals: Dictionary = {} # AbilityType -> float

func _ready() -> void:
	owner_entity = get_parent()
	_initialize_cooldowns()


## Replace the shared .tres abilities with per-entity copies so permanent
## modifiers (and per-use state) never leak between heroes or matches.
## Idempotent: copies have no resource_path.
func make_abilities_unique() -> void:
	if passive_ability and not passive_ability.resource_path.is_empty():
		passive_ability = passive_ability.duplicate()
	if active_ability and not active_ability.resource_path.is_empty():
		active_ability = active_ability.duplicate()
	if basic_attack and not basic_attack.resource_path.is_empty():
		basic_attack = basic_attack.duplicate()
	if ultimate_ability and not ultimate_ability.resource_path.is_empty():
		ultimate_ability = ultimate_ability.duplicate()


func all_abilities() -> Array[AbilityBase]:
	var out: Array[AbilityBase] = []
	for a in [passive_ability, active_ability, basic_attack, ultimate_ability]:
		if a != null:
			out.append(a)
	return out

func _initialize_cooldowns() -> void:
	cooldowns[AbilityBase.AbilityType.PASSIVE] = 0.0
	cooldowns[AbilityBase.AbilityType.ACTIVE] = 0.0
	cooldowns[AbilityBase.AbilityType.BASIC_ATTACK] = 0.0
	cooldowns[AbilityBase.AbilityType.ULTIMATE] = 0.0
	
	_last_emitted_cooldowns = cooldowns.duplicate()

func _process(delta: float) -> void:
	# Update cooldowns (apply attack speed modifier from passive)
	var attack_speed_mult = get_attack_speed_multiplier()
	
	for ability_type in cooldowns.keys():
		if cooldowns[ability_type] > 0.0:
			var cooldown_reduction = delta
			# Apply attack speed modifier to basic attack cooldown
			if ability_type == AbilityBase.AbilityType.BASIC_ATTACK:
				cooldown_reduction *= attack_speed_mult
			
			cooldowns[ability_type] -= cooldown_reduction
			if cooldowns[ability_type] < 0.0:
				cooldowns[ability_type] = 0.0
			
			# Only emit signal when cooldown completes or changes significantly
			var last_value = _last_emitted_cooldowns.get(ability_type, 0.0)
			if cooldowns[ability_type] <= 0.0 and last_value > 0.0:
				# Ability just became ready
				cooldown_updated.emit(ability_type, 0.0)
				_last_emitted_cooldowns[ability_type] = 0.0
	
	# Update passive ability
	if passive_ability:
		passive_ability.on_passive_update(owner_entity, delta)

func use_passive() -> bool:
	return _use_ability(passive_ability, AbilityBase.AbilityType.PASSIVE)

func use_active(target: Node2D = null) -> bool:
	return _use_ability(active_ability, AbilityBase.AbilityType.ACTIVE, target)

func use_basic_attack(target: Node2D = null) -> bool:
	return _use_ability(basic_attack, AbilityBase.AbilityType.BASIC_ATTACK, target)

func use_ultimate(target: Node2D = null) -> bool:
	return _use_ability(ultimate_ability, AbilityBase.AbilityType.ULTIMATE, target)

func _use_ability(ability: AbilityBase, ability_type: AbilityBase.AbilityType, target: Node2D = null) -> bool:
	if not ability:
		return false

	if not is_on_cooldown(ability_type) and ability.can_use(owner_entity):
		ability.execute(owner_entity, target)
		cooldowns[ability_type] = ability.cooldown
		_cooldown_totals[ability_type] = ability.cooldown
		# Arms the "ready again" emit in _process (it never fired before:
		# this entry stayed 0 forever).
		_last_emitted_cooldowns[ability_type] = ability.cooldown
		ability_used.emit(ability)
		EventBus.notify_ability_cast(owner_entity, ability, target)
		return true

	return false

func is_on_cooldown(ability_type: AbilityBase.AbilityType) -> bool:
	return cooldowns.get(ability_type, 0.0) > 0.0

func get_cooldown_remaining(ability_type: AbilityBase.AbilityType) -> float:
	return cooldowns.get(ability_type, 0.0)

## 0.0 right after a cast, 1.0 when ready. Polled by the hero panel overlay.
func get_cooldown_progress(ability_type: AbilityBase.AbilityType) -> float:
	var remaining: float = cooldowns.get(ability_type, 0.0)
	var total: float = _cooldown_totals.get(ability_type, 0.0)
	if remaining <= 0.0 or total <= 0.0:
		return 1.0
	return clampf(1.0 - remaining / total, 0.0, 1.0)

func get_ability_by_type(ability_type: AbilityBase.AbilityType) -> AbilityBase:
	match ability_type:
		AbilityBase.AbilityType.PASSIVE:
			return passive_ability
		AbilityBase.AbilityType.ACTIVE:
			return active_ability
		AbilityBase.AbilityType.BASIC_ATTACK:
			return basic_attack
		AbilityBase.AbilityType.ULTIMATE:
			return ultimate_ability
	return null

func _get_hero_stats() -> HeroStatsComponent:
	if _hero_stats == null and is_instance_valid(owner_entity):
		_hero_stats = owner_entity.get_node_or_null("HeroStats") as HeroStatsComponent
	return _hero_stats

# Total damage multiplier: passive ability × hero damage scale (level + upgrades).
func get_damage_multiplier() -> float:
	var multiplier: float = 1.0
	if passive_ability:
		multiplier *= passive_ability.get_damage_multiplier(owner_entity)
	var stats := _get_hero_stats()
	if stats:
		# Level growth + permanent attack_damage upgrades, relative to level 1.
		multiplier *= stats.get_damage_scale()
	return multiplier

# Total attack speed multiplier: passive × permanent attack_speed upgrades × temporary boosts.
func get_attack_speed_multiplier() -> float:
	var multiplier: float = 1.0
	if passive_ability:
		multiplier *= passive_ability.get_attack_speed_multiplier(owner_entity)
	var stats := _get_hero_stats()
	if stats:
		multiplier *= stats.get_attack_speed_multiplier()
	if owner_entity is HeroBase:
		multiplier *= (owner_entity as HeroBase).get_attack_speed_boost()
	return multiplier
