extends AbilityBase
class_name RiverSniperAttack

func _init() -> void:
	ability_name = "Sniper Shot"
	ability_type = AbilityType.BASIC_ATTACK
	damage = 15.0
	ability_range = 300.0  # Long range
	cooldown = 2.0  # Slow fire rate
	description = "Long-range, slow but powerful shots"

func can_use(caster: Node2D) -> bool:
	if not caster.has_method("is_alive"):
		return false
	if not caster.is_alive():
		return false
	
	# Check if in sniper mode
	if caster.has_node("AbilitySystem"):
		var ability_system = caster.get_node("AbilitySystem")
		var active_ability = ability_system.active_ability
		if active_ability and active_ability.has_method("is_sniper_mode"):
			return active_ability.is_sniper_mode()
	
	return true

func execute(caster: Node2D, target: Node2D = null) -> void:
	if not target or not target.has_method("take_damage"):
		return
	
	var distance = caster.global_position.distance_to(target.global_position)
	if distance <= ability_range:
		# Apply damage with modifier
		var damage_mult = 1.0
		if caster.has_node("AbilitySystem"):
			var ability_system = caster.get_node("AbilitySystem")
			damage_mult = ability_system.get_damage_multiplier()
		
		var final_damage = damage * damage_mult
		target.take_damage(final_damage)
		
		# Visual feedback
		_create_shot_effect(caster, target)

func _create_shot_effect(caster: Node2D, target: Node2D) -> void:
	# Simple line effect from caster to target
	var line = Line2D.new()
	caster.get_parent().add_child(line)
	line.add_point(caster.global_position)
	line.add_point(target.global_position)
	line.default_color = Color.ORANGE
	line.width = 2.0
	line.z_index = 10
	
	# Fade out and remove
	var tween = line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.3)
	tween.tween_callback(line.queue_free)
