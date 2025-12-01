extends AbilityBase
class_name VladBasicAttack

func _init() -> void:
	ability_name = "Blood Strike"
	ability_type = AbilityType.BASIC_ATTACK
	damage = 10.0
	ability_range = 50.0
	cooldown = 1.0
	description = "A simple melee attack that strikes nearby enemies"

func can_use(caster: Node2D) -> bool:
	return caster.has_method("is_alive") and caster.is_alive()

func execute(caster: Node2D, target: Node2D = null, _override_damage: float = -1.0) -> void:
	if not target or not target.has_method("take_damage"):
		return
	
	var distance = caster.global_position.distance_to(target.global_position)
	if distance <= ability_range:
		# Apply damage with modifier from passive
		var damage_mult = 1.0
		if caster.has_node("AbilitySystem"):
			var ability_system = caster.get_node("AbilitySystem")
			damage_mult = ability_system.get_damage_multiplier()
		
		var final_damage = damage * damage_mult
		target.take_damage(final_damage)
