extends AbilityBase
class_name RiverHealStaffAttack

func _init() -> void:
	ability_name = "Healing Wave"
	ability_type = AbilityType.BASIC_ATTACK
	heal_amount = 8.0
	ability_range = 150.0  # Medium range
	cooldown = 1.2  # Faster than sniper
	description = "Heal nearby allies"

func can_use(caster: Node2D) -> bool:
	if not caster.has_method("is_alive"):
		return false
	if not caster.is_alive():
		return false
	
	# Check if in heal staff mode
	if caster.has_node("AbilitySystem"):
		var ability_system = caster.get_node("AbilitySystem")
		var active_ability = ability_system.active_ability
		if active_ability and active_ability.has_method("is_heal_mode"):
			return active_ability.is_heal_mode()
	
	return false

func execute(caster: Node2D, target: Node2D = null) -> void:
	# If no target specified, find nearest ally
	if not target:
		target = _find_nearest_ally(caster)
	
	if not target or not target.has_method("heal"):
		return
	
	var distance = caster.global_position.distance_to(target.global_position)
	if distance <= ability_range:
		# Don't heal self
		if target == caster:
			return
		
		# Apply healing
		if target.has_method("heal"):
			target.heal(heal_amount)
		elif target.has_node("HeroStats"):
			var stats = target.get_node("HeroStats")
			stats.heal(heal_amount)
		
		# Visual feedback
		_create_heal_effect(caster, target)

func _find_nearest_ally(caster: Node2D) -> Node2D:
	var heroes = caster.get_tree().get_nodes_in_group("Hero")
	var nearest: Node2D = null
	var nearest_distance := INF
	
	for hero in heroes:
		if hero == caster:
			continue
		
		if not hero.has_method("is_alive") or not hero.is_alive():
			continue
		
		var distance = caster.global_position.distance_to(hero.global_position)
		if distance < nearest_distance and distance <= ability_range:
			nearest_distance = distance
			nearest = hero
	
	return nearest

func _create_heal_effect(caster: Node2D, target: Node2D) -> void:
	# Green healing beam
	var line = Line2D.new()
	caster.get_parent().add_child(line)
	line.add_point(caster.global_position)
	line.add_point(target.global_position)
	line.default_color = Color.GREEN
	line.width = 3.0
	line.z_index = 10
	
	# Fade out
	var tween = line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.4)
	tween.tween_callback(line.queue_free)
	
	# Healing particle on target
	var particles = Node2D.new()
	target.add_child(particles)
	particles.modulate = Color.GREEN
	
	await caster.get_tree().create_timer(0.5).timeout
	if is_instance_valid(particles):
		particles.queue_free()
