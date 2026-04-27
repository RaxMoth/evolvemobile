extends HeroBase
class_name Irelia

func _ready() -> void:
	# Tank archetype: pull aggro hard. Threat = damage * taunt_strength, so
	# 2.5× makes mobs strongly prefer Irelia over the rest of the squad.
	taunt_strength = 2.5
	super._ready()
	# Hook into the damage pipeline so the shield can absorb hits BEFORE the
	# packet reaches our _receive_damage. This is the canonical pattern for
	# damage modifiers (shields, lifesteal, skill-tree mods all work the same way).
	EventBus.damage_requested.connect(_on_damage_requested)

func _on_damage_requested(packet: DamagePacket) -> void:
	# Only intercept hits aimed at us
	if packet.target != self:
		return
	if not has_node("Shield"):
		return
	# Explicit type annotation: get_node returns generic Node so := cannot
	# infer absorb_damage's return type at parse time.
	var shield: Shield = get_node("Shield")
	var remaining: float = shield.absorb_damage(packet.amount)
	# absorb_damage returns the leftover after the shield ate what it could.
	packet.amount = remaining
	packet.add_tag("shielded")
	if remaining <= 0.0:
		packet.canceled = true

# Tank behavior: peel for the most-threatened ally. Reads from the team
# blackboard instead of walking groups manually — same logic, but now uses
# real damage threat, not just HP%.
func _on_fight_logic(_delta: float) -> void:
	if not ability_system:
		return

	var threatened_ally = _find_threatened_ally()
	if threatened_ally:
		var attacker = _find_enemy_attacking(threatened_ally)
		if attacker:
			target_entity = attacker
			if attacker.has_node("Body"):
				target = attacker.get_node("Body")

	if is_target_valid():
		ability_system.use_basic_attack(target_entity)

func _find_threatened_ally() -> Node2D:
	## Use the team blackboard's threat table — the ally currently soaking
	## the most damage is the one Irelia should peel for. Falls back to
	## "ally below 40% HP" if no threat data yet.
	var team := TeamRegistry.get_team(TeamRegistry.HEROES)
	if team:
		var most_threatened := team.find_most_threatened_ally(1.0, self)
		if most_threatened and most_threatened is Node2D:
			return most_threatened
		# Fallback: low-HP ally
		var wounded := team.find_lowest_hp_ally(0.4, self)
		if wounded and wounded is Node2D:
			return wounded
	return null

func _find_enemy_attacking(ally: Node2D) -> Node2D:
	## Find the enemy currently doing the most threat to `ally`, within range.
	var team := TeamRegistry.get_team(TeamRegistry.HEROES)
	if team == null:
		return null
	var top_attacker: Node = team.highest_threat_target_for(ally)
	if top_attacker == null or not (top_attacker is Node2D):
		return null
	if not top_attacker.has_method("is_alive") or not top_attacker.is_alive():
		return null
	var d2 := global_position.distance_squared_to((top_attacker as Node2D).global_position)
	if d2 > 200.0 * 200.0:
		return null
	return top_attacker as Node2D

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
	## Use the team blackboard membership instead of a group scan.
	var team := TeamRegistry.get_team(TeamRegistry.HEROES)
	if team == null:
		return Vector2.ZERO
	var total := Vector2.ZERO
	var count := 0
	for ally in team.members:
		if ally == self or not is_instance_valid(ally):
			continue
		if not ally.has_method("is_alive") or not ally.call("is_alive"):
			continue
		if not (ally is Node2D):
			continue
		total += (ally as Node2D).global_position
		count += 1
	return total / count if count > 0 else Vector2.ZERO
