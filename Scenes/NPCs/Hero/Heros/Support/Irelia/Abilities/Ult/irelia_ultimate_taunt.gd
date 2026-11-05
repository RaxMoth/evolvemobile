extends AbilityBase
class_name IreliaUltimateTaunt

func execute(caster: Node2D, _target: Node2D = null, _override_damage: float = -1.0) -> void:
	var monsters = caster.get_tree().get_nodes_in_group("Monster")
	var taunted_count = 0
	
	for monster in monsters:
		if not is_instance_valid(monster) or not (monster is EntityBase) or not (monster as EntityBase).is_alive():
			continue
		
		var distance = caster.global_position.distance_to(monster.global_position)
		if distance <= ability_range:
			_apply_taunt(monster, caster)
			taunted_count += 1
	
	# Also taunt regular enemies if no monsters
	if taunted_count == 0:
		var enemies = caster.get_tree().get_nodes_in_group("Enemy")
		for enemy in enemies:
			if not is_instance_valid(enemy) or not (enemy is EntityBase) or not (enemy as EntityBase).is_alive():
				continue
			
			if enemy.is_in_group("Hero"): # Don't taunt heroes
				continue
			
			var distance = caster.global_position.distance_to(enemy.global_position)
			if distance <= ability_range:
				_apply_taunt(enemy, caster)
				taunted_count += 1
	
	_create_taunt_effect(caster)

func _apply_taunt(enemy: Node2D, caster: Node2D) -> void:
	# CRITICAL: Validate both enemy and caster before proceeding
	if not is_instance_valid(enemy) or not is_instance_valid(caster):
		return
	
	# Force enemy to target Irelia
	if enemy is EntityBase:
		(enemy as EntityBase).set_target(caster)
	
	# Create taunt component to maintain the effect
	if not enemy.has_node("TauntEffect"):
		var taunt = Node.new()
		taunt.name = "TauntEffect"
		taunt.add_to_group(&"TransientEffect")  # scrubbed by MobBase.prepare_for_pool
		taunt.set_meta("taunter", caster)
		taunt.set_meta("duration", duration)
		enemy.add_child(taunt)
		
		# FIXED: Start timer, but validate before cleanup
		_schedule_taunt_cleanup(enemy, taunt, duration)
	
	# Visual feedback - validate before creating link
	if is_instance_valid(enemy) and is_instance_valid(caster):
		_create_taunt_link(enemy, caster)

# FIXED: Separate timer function with validation
func _schedule_taunt_cleanup(enemy: Node2D, taunt: Node, duration_time: float) -> void:
	await enemy.get_tree().create_timer(duration_time).timeout
	
	# CRITICAL: Validate before cleanup
	if is_instance_valid(taunt) and is_instance_valid(enemy):
		taunt.queue_free()

func _create_taunt_link(enemy: Node2D, caster: Node2D) -> void:
	# CRITICAL: Validate both objects before proceeding
	if not is_instance_valid(enemy) or not is_instance_valid(caster):
		return
	
	# Red line connecting enemy to Irelia, in world space, every frame
	TauntLink.spawn(enemy, caster, duration)

func _create_taunt_effect(caster: Node2D) -> void:
	# CRITICAL: Validate caster
	if not is_instance_valid(caster):
		return
	
	# Red expanding ring around Irelia, out to the taunt range
	RingPulse.spawn(caster.get_parent(), caster.global_position, Color.RED, 50.0, ability_range / 50.0, 3.0, 0.5, 10)
