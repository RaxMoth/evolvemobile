extends AbilityBase
class_name IreliaUltimateTaunt

func execute(caster: Node2D, _target: Node2D = null) -> void:
	var monsters = caster.get_tree().get_nodes_in_group("Monster")
	var taunted_count = 0
	
	for monster in monsters:
		if not is_instance_valid(monster) or not monster.has_method("is_alive") or not monster.is_alive():
			continue
		
		var distance = caster.global_position.distance_to(monster.global_position)
		if distance <= ability_range:
			_apply_taunt(monster, caster)
			taunted_count += 1
	
	# Also taunt regular enemies if no monsters
	if taunted_count == 0:
		var enemies = caster.get_tree().get_nodes_in_group("Enemy")
		for enemy in enemies:
			if not is_instance_valid(enemy) or not enemy.has_method("is_alive") or not enemy.is_alive():
				continue
			
			if enemy.is_in_group("Hero"):  # Don't taunt heroes
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
	if "target_entity" in enemy:
		enemy.target_entity = caster
	
	if "target" in enemy and caster.has_node("Body"):
		enemy.target = caster.get_node("Body")
	
	# Create taunt component to maintain the effect
	if not enemy.has_node("TauntEffect"):
		var taunt = Node.new()
		taunt.name = "TauntEffect"
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
	
	# Red line connecting enemy to Irelia
	var line = Line2D.new()
	enemy.add_child(line)
	line.z_index = 11
	
	# Update line position every frame with validation
	var update_timer = Timer.new()
	line.add_child(update_timer)
	update_timer.wait_time = 0.05
	update_timer.timeout.connect(func():
		# CRITICAL: Validate all objects before accessing
		if is_instance_valid(line) and is_instance_valid(enemy) and is_instance_valid(caster):
			line.clear_points()
			line.add_point(Vector2.ZERO)
			line.add_point(caster.global_position - enemy.global_position)
			line.default_color = Color(1.0, 0.3, 0.3, 0.6)
			line.width = 2.0
		else:
			# If any object is freed, stop timer and cleanup
			if is_instance_valid(update_timer):
				update_timer.stop()
			if is_instance_valid(line):
				line.queue_free()
	)
	update_timer.start()
	
	# Remove after duration with validation
	_schedule_line_cleanup(enemy, line, duration)

# FIXED: Separate timer function for line cleanup
func _schedule_line_cleanup(enemy: Node2D, line: Line2D, duration_time: float) -> void:
	await enemy.get_tree().create_timer(duration_time).timeout
	
	# CRITICAL: Validate before cleanup
	if is_instance_valid(line):
		var tween = line.create_tween()
		tween.tween_property(line, "modulate:a", 0.0, 0.3)
		tween.tween_callback(line.queue_free)

func _create_taunt_effect(caster: Node2D) -> void:
	# CRITICAL: Validate caster
	if not is_instance_valid(caster):
		return
	
	# Red expanding ring around Irelia
	var effect = Node2D.new()
	caster.get_parent().add_child(effect)
	effect.global_position = caster.global_position
	effect.z_index = 10
	
	# Draw expanding circle
	var circle = Line2D.new()
	effect.add_child(circle)
	circle.default_color = Color.RED
	circle.width = 3.0
	
	for i in range(33):
		var angle = i * TAU / 32
		circle.add_point(Vector2(cos(angle), sin(angle)) * 50)
	
	var tween = effect.create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "scale", Vector2(ability_range / 50.0, ability_range / 50.0), 0.5)
	tween.tween_property(circle, "modulate:a", 0.0, 0.5)
	tween.tween_callback(effect.queue_free)
