extends Node
class_name AbilitySystem

signal ability_used(ability: AbilityBase)
signal cooldown_updated(ability_type: AbilityBase.AbilityType, time_remaining: float)

@export var passive_ability: AbilityBase
@export var active_ability: AbilityBase
@export var basic_attack: AbilityBase
@export var ultimate_ability: AbilityBase

var owner_entity: Node2D
var cooldowns: Dictionary = {}  # AbilityType -> time_remaining

func _ready() -> void:
	owner_entity = get_parent()
	_initialize_cooldowns()

func _initialize_cooldowns() -> void:
	cooldowns[AbilityBase.AbilityType.PASSIVE] = 0.0
	cooldowns[AbilityBase.AbilityType.ACTIVE] = 0.0
	cooldowns[AbilityBase.AbilityType.BASIC_ATTACK] = 0.0
	cooldowns[AbilityBase.AbilityType.ULTIMATE] = 0.0

func _process(delta: float) -> void:
	# Update cooldowns
	for ability_type in cooldowns.keys():
		if cooldowns[ability_type] > 0.0:
			cooldowns[ability_type] -= delta
			if cooldowns[ability_type] < 0.0:
				cooldowns[ability_type] = 0.0
			cooldown_updated.emit(ability_type, cooldowns[ability_type])
	
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
		ability_used.emit(ability)
		return true
	
	return false

func is_on_cooldown(ability_type: AbilityBase.AbilityType) -> bool:
	return cooldowns.get(ability_type, 0.0) > 0.0

func get_cooldown_remaining(ability_type: AbilityBase.AbilityType) -> float:
	return cooldowns.get(ability_type, 0.0)

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
