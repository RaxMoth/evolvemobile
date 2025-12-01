extends Resource
class_name AbilityBase

enum AbilityType {
	PASSIVE, # Always active
	ACTIVE, # User triggered
	BASIC_ATTACK, # Normal attack
	ULTIMATE # Special ability
}

@export var ability_name: String = "Unnamed Ability"
@export var ability_type: AbilityType = AbilityType.ACTIVE
@export var icon: Texture2D
@export var cooldown: float = 1.0
@export var description: String = ""

# Stats that abilities might need
@export_group("Ability Stats")
@export var damage: float = 0.0
@export var ability_range: float = 100.0
@export var duration: float = 0.0
@export var heal_amount: float = 0.0
@export var speed_modifier: float = 1.0
@export var damage_modifier: float = 1.0
@export var attack_speed_modifier: float = 1.0
@export var area_of_effect: float = 0.0

# Override these in specific ability scripts
func execute(_caster: Node2D, _target: Node2D = null, _override_damage: float = -1.0) -> void:
	push_warning("Ability.execute() not implemented for: " + ability_name)

func can_use(_caster: Node2D) -> bool:
	return true

func on_passive_update(_caster: Node2D, _delta: float) -> void:
	# Called every frame for passive abilities
	pass

func get_cooldown_remaining(_caster: Node2D) -> float:
	return 0.0

# Helper to get modifiers from passives
func get_damage_multiplier(_caster: Node2D) -> float:
	return damage_modifier

func get_attack_speed_multiplier(_caster: Node2D) -> float:
	return attack_speed_modifier
