extends HeroBase
class_name Irelia

func _ready() -> void:
	super._ready()

# Override take_damage to check for shield
func take_damage(amount: float) -> void:
	if not is_alive() or not stats:
		return
	
	# Check if we have a shield good outside day 
	if has_node("Shield"):
		var shield = get_node("Shield")
		var remaining_damage = shield.absorb_damage(amount)
		
		if remaining_damage > 0:
			# Shield broken, take remaining damage
			stats.take_damage(remaining_damage)
		# else: Shield absorbed all damage
	else:
		# No shield, take full damage
		stats.take_damage(amount)
	
	# Check death
	if not stats.is_alive():
		state_chart.send_event("self_dead")

# Override to prioritize enemies attacking allies
func _on_fight_logic(delta: float) -> void:
	if not ability_system:
		return
	
	# Check if any ally is under attack
	var threatened_ally = _find_threatened_ally()
	
	if threatened_ally:
		# Find enemy attacking the ally
		var attacker = _find_enemy_attacking(threatened_ally)
		if attacker:
			# Override target to protect ally
			target_entity = attacker
			if attacker.has_node("Body"):
				target = attacker.get_node("Body")
	
	# Attack current target
	if is_target_valid():
		ability_system.use_basic_attack(target_entity)

func _find_threatened_ally() -> Node2D:
	var heroes = get_tree().get_nodes_in_group("Hero")

	
	for hero in heroes:
		if hero == self:
			continue
		
		if not hero.has_method("is_alive") or not hero.is_alive():
			continue
		
		# Check if hero is at low health
		if hero.has_method("get_health"):
			var health_percent = hero.get_health() / hero.max_health
			if health_percent < 0.4: # Below 40% health
				return hero
	
	return null

func _find_enemy_attacking(ally: Node2D) -> Node2D:
	var enemies = get_tree().get_nodes_in_group("Enemy")
	
	for enemy in enemies:
		if enemy.is_in_group("Hero"):
			continue
		
		if not enemy.has_method("is_alive") or not enemy.is_alive():
			continue
		
		# Check if enemy is targeting this ally
		if "target_entity" in enemy and enemy.target_entity == ally:
			var distance = global_position.distance_to(enemy.global_position)
			if distance <= 200.0: # Within reasonable range
				return enemy
	
	return null

# Irelia stays close to allies to protect them
func _get_idle_wander_radius() -> float:
	return 80.0 # Stay closer to team

func _on_idle_state_processing(delta: float) -> void:
	if not is_instance_valid(navigation_agent_2d):
		return
	
	# Wander near allies instead of random
	_idle_timer -= delta
	if _idle_timer <= 0.0 or global_position.distance_squared_to(_idle_goal) < 64.0:
		_idle_timer = idle_retarget_time
		
		# Find center of allied heroes
		var ally_center = _get_ally_center()
		if ally_center != Vector2.ZERO:
			# Wander near allies
			var angle := randf() * TAU
			var dir := Vector2.from_angle(angle)
			var dist := randf_range(30.0, 80.0)
			_idle_goal = ally_center + dir * dist
		else:
			# No allies, wander normally
			var angle := randf() * TAU
			var dir := Vector2.from_angle(angle)
			var dist := randf_range(idle_wander_radius * 0.2, idle_wander_radius)
			_idle_goal = global_position + dir * dist
		
		navigation_agent_2d.target_position = _idle_goal
	
	_steer_along_nav(move_speed, delta)

func _get_ally_center() -> Vector2:
	var heroes = get_tree().get_nodes_in_group("Hero")
	var total := Vector2.ZERO
	var count := 0
	
	for hero in heroes:
		if hero == self:
			continue
		if not hero.has_method("is_alive") or not hero.is_alive():
			continue
		
		total += hero.global_position
		count += 1
	
	return total / count if count > 0 else Vector2.ZERO
