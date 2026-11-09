extends Node
class_name HeroStatsComponent

signal stat_changed(stat_name: String, old_value: float, new_value: float)
signal health_changed(current: float, max: float)
signal leveled_up(new_level: int)

@export var base_stats: HeroStats

var level: int = 1
## In-round XP toward the next level (README: ~80 XP per level).
var current_xp: float = 0.0
const XP_PER_LEVEL: float = 80.0
const MAX_LEVEL: int = 10

var current_stats := {
	"max_health": 0.0,
	"current_health": 0.0,
	"move_speed": 0.0,
	"attack_range": 0.0,
	"attack_damage": 0.0,
}

var stat_modifiers := {
	"max_health_mult": 1.0,
	"max_health_add": 0.0,
	"move_speed_mult": 1.0,
	"move_speed_add": 0.0,
	"attack_damage_mult": 1.0,
	"attack_damage_add": 0.0,
	"attack_speed_mult": 1.0,
}

func _ready() -> void:
	if not base_stats:
		push_error("HeroStatsComponent requires base_stats resource!")
		return
	
	_initialize_stats()

func _initialize_stats() -> void:
	_recalculate_all_stats()
	current_stats.current_health = current_stats.max_health

func _recalculate_all_stats() -> void:
	_recalculate_stat("max_health", base_stats.base_max_health, base_stats.health_per_level)
	_recalculate_stat("move_speed", base_stats.base_move_speed, base_stats.speed_per_level)
	_recalculate_stat("attack_range", base_stats.base_attack_range, 0.0)
	_recalculate_stat("attack_damage", base_stats.base_attack_damage, base_stats.damage_per_level)

func _recalculate_stat(stat_name: String, base_value: float, per_level: float) -> void:
	var old_value = current_stats.get(stat_name, 0.0)
	
	var level_bonus = per_level * (level - 1)
	var additive = stat_modifiers.get(stat_name + "_add", 0.0)
	var multiplicative = stat_modifiers.get(stat_name + "_mult", 1.0)
	
	var new_value = (base_value + level_bonus + additive) * multiplicative
	current_stats[stat_name] = new_value
	
	if old_value != new_value:
		stat_changed.emit(stat_name, old_value, new_value)


func get_max_health() -> float:
	return current_stats.max_health

func get_current_health() -> float:
	return current_stats.current_health

func get_move_speed() -> float:
	return current_stats.move_speed


func get_attack_range() -> float:
	return current_stats.attack_range

func get_attack_damage() -> float:
	return current_stats.attack_damage

## Everything that scales basic/ability damage beyond the ability's own number:
## per-level growth, additive and multiplicative upgrades, relative to level 1.
func get_damage_scale() -> float:
	if base_stats == null or base_stats.base_attack_damage <= 0.0:
		return float(stat_modifiers.get("attack_damage_mult", 1.0))
	return float(current_stats.attack_damage) / base_stats.base_attack_damage

func get_attack_speed_multiplier() -> float:
	return stat_modifiers.attack_speed_mult


## A permanent modifier as add_stat_modifier stacked it: the product of every
## multiplier on `stat_name` (1.0 = none) or the sum of every delta (0.0 = none).
func get_modifier(stat_name: String, multiplicative: bool) -> float:
	if multiplicative:
		return float(stat_modifiers.get(stat_name + "_mult", 1.0))
	return float(stat_modifiers.get(stat_name + "_add", 0.0))


## Skill-tree keys that are not a stat of their own (README "Generic stat
## keys"); each has one apply site and is neutral on a fresh save.
## damage_taken_mult (Tempered Mail, Plated): HeroBase._receive_damage scales
## every hit by it.
func get_damage_taken_multiplier() -> float:
	return get_modifier("damage_taken_mult", true)


## cooldown_mult (Battle Drills): AbilitySystem scales the active and the
## ultimate cooldown by it when they start.
func get_cooldown_multiplier() -> float:
	return get_modifier("cooldown_mult", true)


## start_level (Veteran Squad): the in-round level HeroBase._ready levels the
## hero up to once the tree is applied; 1 without the node.
func get_start_level() -> int:
	return clampi(roundi(get_modifier("start_level", false)), 1, MAX_LEVEL)


func add_stat_modifier(stat_name: String, value: float, is_multiplicative: bool = false) -> void:
	var modifier_key := stat_name + ("_mult" if is_multiplicative else "_add")
	
	# Read with a default: only a few keys are pre-seeded, and a stat that was
	# never modified before (e.g. attack_range) has no entry yet.
	if is_multiplicative:
		stat_modifiers[modifier_key] = float(stat_modifiers.get(modifier_key, 1.0)) * value # Stack multiplicatively
	else:
		stat_modifiers[modifier_key] = float(stat_modifiers.get(modifier_key, 0.0)) + value # Stack additively
	
	_recalculate_all_stats()

## Spawn-time refill after permanent max-HP upgrades were applied (the
## component initialised current_health before the modifiers existed).
func refill_health() -> void:
	current_stats.current_health = current_stats.max_health

func take_damage(amount: float) -> void:
	current_stats.current_health = max(0.0, current_stats.current_health - amount)
	health_changed.emit(current_stats.current_health, current_stats.max_health)

## health_changed only feeds the HP bars, so a heal announces itself only when
## the whole-HP value changes or HP reaches max: Irelia's per-frame regen would
## otherwise redraw both bars every frame for a fraction of a point.
func heal(amount: float) -> void:
	var old_hp: float = current_stats.current_health
	var max_hp: float = current_stats.max_health
	var new_hp: float = minf(max_hp, old_hp + amount)
	current_stats.current_health = new_hp
	if floori(old_hp) != floori(new_hp) or new_hp >= max_hp:
		health_changed.emit(new_hp, max_hp)

func is_alive() -> bool:
	return current_stats.current_health > 0.0

## In-round XP. Levels up as often as the amount allows (capped at MAX_LEVEL).
func add_xp(amount: float) -> void:
	if amount <= 0.0 or level >= MAX_LEVEL or not is_alive():
		return
	current_xp += amount
	while current_xp >= XP_PER_LEVEL and level < MAX_LEVEL:
		current_xp -= XP_PER_LEVEL
		level_up()
	if level >= MAX_LEVEL:
		current_xp = 0.0

func level_up() -> void:
	level += 1
	var old_max_health: float = current_stats.max_health
	_recalculate_all_stats()
	
	# The max-HP gained this level is also healed (README: slow growth).
	var health_gained: float = current_stats.max_health - old_max_health
	current_stats.current_health = minf(current_stats.max_health, current_stats.current_health + health_gained)
	
	leveled_up.emit(level)
	health_changed.emit(current_stats.current_health, current_stats.max_health)
