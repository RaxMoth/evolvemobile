extends Node
class_name HeroStatsComponent

signal stat_changed(stat_name: String, old_value: float, new_value: float)
signal health_changed(current: float, max: float)
signal leveled_up(new_level: int)

@export var base_stats: HeroStats

var level: int = 1

var current_stats := {
	"max_health": 0.0,
	"current_health": 0.0,
	"move_speed": 0.0,
	"approach_speed": 0.0,
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
	_recalculate_stat("approach_speed", base_stats.base_approach_speed, base_stats.speed_per_level)
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

func get_approach_speed() -> float:
	return current_stats.approach_speed

func get_attack_range() -> float:
	return current_stats.attack_range

func get_attack_damage() -> float:
	return current_stats.attack_damage

func get_attack_speed_multiplier() -> float:
	return stat_modifiers.attack_speed_mult


func add_stat_modifier(stat_name: String, value: float, is_multiplicative: bool = false) -> void:
	var modifier_key = stat_name + ("_mult" if is_multiplicative else "_add")
	
	if is_multiplicative:
		stat_modifiers[modifier_key] *= value  # Stack multiplicatively
	else:
		stat_modifiers[modifier_key] += value  # Stack additively
	
	_recalculate_all_stats()

func remove_stat_modifier(stat_name: String, value: float, is_multiplicative: bool = false) -> void:
	var modifier_key = stat_name + ("_mult" if is_multiplicative else "_add")
	
	if is_multiplicative:
		stat_modifiers[modifier_key] /= value
	else:
		stat_modifiers[modifier_key] -= value
	
	_recalculate_all_stats()

func clear_all_modifiers() -> void:
	for key in stat_modifiers.keys():
		if key.ends_with("_mult"):
			stat_modifiers[key] = 1.0
		else:
			stat_modifiers[key] = 0.0
	_recalculate_all_stats()

# ============================================
# HEALTH MANAGEMENT
# ============================================

func take_damage(amount: float) -> void:
	var old_health = current_stats.current_health
	current_stats.current_health = max(0.0, current_stats.current_health - amount)
	health_changed.emit(current_stats.current_health, current_stats.max_health)
	
	if current_stats.current_health <= 0.0:
		_on_death()

func heal(amount: float) -> void:
	var old_health = current_stats.current_health
	current_stats.current_health = min(current_stats.max_health, current_stats.current_health + amount)
	health_changed.emit(current_stats.current_health, current_stats.max_health)

func is_alive() -> bool:
	return current_stats.current_health > 0.0

func _on_death() -> void:
	# Override in subclass or connect to signal
	pass

# ============================================
# LEVEL PROGRESSION
# ============================================

func level_up() -> void:
	level += 1
	var old_max_health = current_stats.max_health
	_recalculate_all_stats()
	
	# Heal to full on level up
	var health_gained = current_stats.max_health - old_max_health
	current_stats.current_health += health_gained
	
	leveled_up.emit(level)
	print(base_stats.hero_name + " leveled up to " + str(level) + "!")

func set_level(new_level: int) -> void:
	level = max(1, new_level)
	_recalculate_all_stats()

# ============================================
# SAVE/LOAD SUPPORT
# ============================================

func get_save_data() -> Dictionary:
	return {
		"level": level,
		"current_health": current_stats.current_health,
		"stat_modifiers": stat_modifiers.duplicate(),
	}

func load_save_data(data: Dictionary) -> void:
	level = data.get("level", 1)
	stat_modifiers = data.get("stat_modifiers", {}).duplicate()
	_recalculate_all_stats()
	current_stats.current_health = data.get("current_health", current_stats.max_health)
