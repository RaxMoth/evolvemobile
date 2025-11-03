extends AbilityBase
class_name VladPassiveBloodlust

@export var max_damage_bonus: float = 1.5  # 150% damage at low health
@export var max_attack_speed_bonus: float = 2.0  # 200% attack speed at low health
@export var health_threshold: float = 0.3  # Bonus starts ramping up below 30% health

var current_damage_mult: float = 1.0
var current_attack_speed_mult: float = 1.0

func _init() -> void:
	ability_name = "Bloodlust"
	ability_type = AbilityType.PASSIVE
	description = "The lower Vlad's health, the more damage and attack speed he gains"

func on_passive_update(caster: Node2D, delta: float) -> void:
	if not caster.has_method("get_health"):
		return
	
	var current_health = caster.get_health()
	var max_health = caster.max_health if "max_health" in caster else 100.0
	var health_percent = current_health / max_health
	
	# Calculate bonus based on missing health
	if health_percent <= health_threshold:
		# Linear scaling from threshold to 0% health
		var bonus_intensity = 1.0 - (health_percent / health_threshold)
		current_damage_mult = 1.0 + (max_damage_bonus - 1.0) * bonus_intensity
		current_attack_speed_mult = 1.0 + (max_attack_speed_bonus - 1.0) * bonus_intensity
	else:
		current_damage_mult = 1.0
		current_attack_speed_mult = 1.0

func get_damage_multiplier(caster: Node2D) -> float:
	return current_damage_mult

func get_attack_speed_multiplier(caster: Node2D) -> float:
	return current_attack_speed_mult
