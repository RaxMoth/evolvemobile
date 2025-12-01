extends AbilityBase
class_name TedBasicAttacks
## Ted's basic melee attack - simple and straightforward

func _init() -> void:
	ability_name = "Claw Swipe"
	ability_type = AbilityType.BASIC_ATTACK
	damage = 8.0
	ability_range = 55.0
	cooldown = 1.2
	description = "A quick melee attack"

func can_use(caster: Node2D) -> bool:
	return caster.has_method("is_alive") and caster.is_alive()

func execute(caster: Node2D, target: Node2D = null, _override_damage: float = -1.0) -> void:
	if not target or not target.has_method("take_damage"):
		return
	
	var distance = caster.global_position.distance_to(target.global_position)
	if distance <= ability_range:
		# Apply damage with modifier
		var damage_mult = 1.0
		if caster.has_node("AbilitySystem"):
			var ability_system = caster.get_node("AbilitySystem")
			damage_mult = ability_system.get_damage_multiplier()
		
		# Also apply attack speed boost if active
		var attack_speed_mult = 1.0
		if caster.has_method("get_attack_speed_boost"):
			attack_speed_mult = caster.get_attack_speed_boost()
		
		var final_damage = damage * damage_mult
		target.take_damage(final_damage)
		
		# Visual effect
		_create_attack_effect(caster, target)

func _create_attack_effect(caster: Node2D, target: Node2D) -> void:
	# Brown/orange slash line
	var line = Line2D.new()
	caster.get_parent().add_child(line)
	line.add_point(caster.global_position)
	line.add_point(target.global_position)
	line.default_color = Color(0.8, 0.5, 0.2) # Brown-orange
	line.width = 2.5
	line.z_index = 10
	
	var tween = line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.2)
	tween.tween_callback(line.queue_free)
