extends Resource
class_name AbilityBase

enum AbilityType {
	PASSIVE,
	ACTIVE,
	BASIC_ATTACK,
	ULTIMATE
}

@export var ability_name: String = "Unnamed Ability"
@export var ability_type: AbilityType = AbilityType.ACTIVE
@export var icon: Texture2D
@export var description: String = ""

# Base stats (used if stage stats not provided)
@export_group("Base Stats")
@export var damage: float = 0.0
@export var cooldown: float = 1.0
@export var ability_range: float = 100.0
@export var duration: float = 0.0
@export var heal_amount: float = 0.0
@export var area_of_effect: float = 0.0

# Stage-based stats (for monsters with evolution)
@export_group("Stage Stats (Monster Evolution)")
@export var damage_per_stage: Array[float] = [] # [stage1, stage2, stage3]
@export var cooldown_per_stage: Array[float] = []
@export var range_per_stage: Array[float] = []
@export var aoe_per_stage: Array[float] = []

# Ability-specific properties (set by subclasses)
@export_group("Ability Properties")
@export var speed_modifier: float = 1.0
@export var damage_modifier: float = 1.0
@export var attack_speed_modifier: float = 1.0

# Override these in specific ability scripts
func execute(_caster: Node2D, _target: Node2D = null, _override_damage: float = -1.0) -> void:
	push_warning("Ability.execute() not implemented for: " + ability_name)

func can_use(_caster: Node2D) -> bool:
	return true

func on_passive_update(_caster: Node2D, _delta: float) -> void:
	pass

func get_cooldown_remaining(_caster: Node2D) -> float:
	return 0.0

func get_damage_multiplier(_caster: Node2D) -> float:
	return damage_modifier

func get_attack_speed_multiplier(_caster: Node2D) -> float:
	return attack_speed_modifier

# Get stat for specific stage
func get_damage_for_stage(stage: int) -> float:
	if damage_per_stage.size() >= stage and stage > 0:
		return damage_per_stage[stage - 1]
	return damage

func get_cooldown_for_stage(stage: int) -> float:
	if cooldown_per_stage.size() >= stage and stage > 0:
		return cooldown_per_stage[stage - 1]
	return cooldown

func get_range_for_stage(stage: int) -> float:
	if range_per_stage.size() >= stage and stage > 0:
		return range_per_stage[stage - 1]
	return ability_range

func get_aoe_for_stage(stage: int) -> float:
	if aoe_per_stage.size() >= stage and stage > 0:
		return aoe_per_stage[stage - 1]
	return area_of_effect

# Apply stage-specific stats to this ability
func apply_stage_stats(stage: int) -> void:
	damage = get_damage_for_stage(stage)
	cooldown = get_cooldown_for_stage(stage)
	ability_range = get_range_for_stage(stage)
	area_of_effect = get_aoe_for_stage(stage)