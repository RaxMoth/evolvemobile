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
## Not usable below this monster stage (cooldown parked at LOCKED_COOLDOWN).
## A skill node can lower it (Grount "Early Slam"); an early unlock uses the
## numbers of the first stage that has data in the per-stage tables.
@export var unlock_stage: int = 1
const LOCKED_COOLDOWN: float = 999999.0

# Ability-specific properties (set by subclasses)
@export_group("Ability Properties")
@export var speed_modifier: float = 1.0
@export var damage_modifier: float = 1.0
@export var attack_speed_modifier: float = 1.0

# Permanent (meta-skill) modifiers on this INSTANCE. Abilities are duplicated
# per entity before any modifier is applied (AbilitySystem.make_abilities_unique /
# MonsterBase), so the shared .tres is never mutated.
# prop -> multiplier / additive delta. apply_stage_stats() re-applies them to the
# four stage-driven properties after reading the stage values.
var meta_mults: Dictionary = {}
var meta_adds: Dictionary = {}
## Unmodified value of each property a modifier touched, so stacked nodes and
## re-applied stage stats never compound (base + a1 + a2, not base + 2*a1 + a2).
var _base_values: Dictionary = {}


## Record and apply a permanent modifier to one property (cooldown, damage,
## ability_range, area_of_effect, duration, heal_amount or any subclass export
## such as dash_distance / cone_range / slam_radius).
func apply_meta_modifier(prop: String, value: float, multiplicative: bool) -> void:
	if not (prop in self):
		push_warning("%s has no property '%s' for a meta-skill modifier" % [ability_name, prop])
		return
	var base: float = _base_of(prop)
	if multiplicative:
		meta_mults[prop] = float(meta_mults.get(prop, 1.0)) * value
	else:
		meta_adds[prop] = float(meta_adds.get(prop, 0.0)) + value
	_set_number(prop, _modified(prop, base))


func _base_of(prop: String) -> float:
	if not _base_values.has(prop):
		_base_values[prop] = float(get(prop))
	return float(_base_values[prop])


## Int and bool exports (extra_targets, unlock_stage, flags) keep their type.
func _set_number(prop: String, value: float) -> void:
	match typeof(get(prop)):
		TYPE_INT:
			set(prop, roundi(value))
		TYPE_BOOL:
			set(prop, value > 0.5)
		_:
			set(prop, value)


func _modified(prop: String, base_value: float) -> float:
	return (base_value + float(meta_adds.get(prop, 0.0))) * float(meta_mults.get(prop, 1.0))


## One F3 overlay line: the name, the cooldown this instance starts and the
## skill-tree modifiers it carries ("Trap Cage  cd 4.00 s  tree cooldown x0.80").
func debug_line() -> String:
	var line := "%s  cd %.2f s" % [ability_name, cooldown]
	var mods := PackedStringArray()
	for prop: String in meta_mults:
		mods.append("%s x%.2f" % [prop, float(meta_mults[prop])])
	for prop: String in meta_adds:
		mods.append("%s %+.2f" % [prop, float(meta_adds[prop])])
	if not mods.is_empty():
		line += "  tree " + ", ".join(mods)
	return line


## Range a range-checked attack should accept: the larger of the ability's own
## range and the caster's effective attack range (HeroStats + skill nodes).
## Keeps the Fight gate (EntityBase.attack_range) and the hit check in step.
func effective_range(caster: Node2D) -> float:
	if caster != null and "attack_range" in caster:
		return maxf(ability_range, float(caster.get("attack_range")))
	return ability_range


## True while the ability is still moving/acting on the caster (a dash or a
## leap in progress). The monster's combo logic waits for it.
func is_channeling() -> bool:
	return false


## How far this ability reaches from the caster (gap-close / slam checks).
func get_reach() -> float:
	return ability_range


## The icon a HUD slot shows. Presentational and read-only: an ability whose
## look follows its caster's state (River's basic attack, by weapon mode)
## overrides it; without a caster it is the resource's own `icon`.
func get_display_icon(_caster: Node = null) -> Texture2D:
	return icon


# Override these in specific ability scripts
func execute(_caster: Node2D, _target: Node2D = null, _override_damage: float = -1.0) -> void:
	push_warning("Ability.execute() not implemented for: " + ability_name)

func can_use(_caster: Node2D) -> bool:
	return true

func on_passive_update(_caster: Node2D, _delta: float) -> void:
	pass

func get_damage_multiplier(_caster: Node2D) -> float:
	return damage_modifier

func get_attack_speed_multiplier(_caster: Node2D) -> float:
	return attack_speed_modifier

# Get stat for specific stage (an empty table falls back to the unmodified base).
func get_damage_for_stage(stage: int) -> float:
	if damage_per_stage.size() >= stage and stage > 0:
		return damage_per_stage[stage - 1]
	return _base_of("damage")

func get_cooldown_for_stage(stage: int) -> float:
	if cooldown_per_stage.size() >= stage and stage > 0:
		return cooldown_per_stage[stage - 1]
	return _base_of("cooldown")

func get_range_for_stage(stage: int) -> float:
	if range_per_stage.size() >= stage and stage > 0:
		return range_per_stage[stage - 1]
	return _base_of("ability_range")

func get_aoe_for_stage(stage: int) -> float:
	if aoe_per_stage.size() >= stage and stage > 0:
		return aoe_per_stage[stage - 1]
	return _base_of("area_of_effect")


func is_unlocked_at(stage: int) -> bool:
	return stage >= unlock_stage


## First stage whose damage table entry is set (Ground Slam: stage 2).
func _first_stage_with_data() -> int:
	for i in range(damage_per_stage.size()):
		if damage_per_stage[i] > 0.0:
			return i + 1
	return 1

# Apply stage-specific stats to this ability
func apply_stage_stats(stage: int) -> void:
	var data_stage: int = maxi(stage, _first_stage_with_data())
	damage = _modified("damage", get_damage_for_stage(data_stage))
	cooldown = _modified("cooldown", get_cooldown_for_stage(data_stage))
	ability_range = _modified("ability_range", get_range_for_stage(data_stage))
	area_of_effect = _modified("area_of_effect", get_aoe_for_stage(data_stage))
	if not is_unlocked_at(stage):
		cooldown = LOCKED_COOLDOWN
