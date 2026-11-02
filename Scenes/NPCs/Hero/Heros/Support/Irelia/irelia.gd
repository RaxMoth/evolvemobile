extends HeroBase
class_name Irelia

func _ready() -> void:
	# Tank archetype: taunt_strength (Irelia.tscn) multiplies the threat of her
	# damage, and her basic attack adds a flat taunt on top (taunt_threat on the
	# attack resource) so mobs actually turn to her.
	super._ready()
	# Shield absorption lives on the Shield node itself (it listens to
	# EventBus.damage_requested for its owner), so Divine Shield protects every
	# hero it is applied to — not only Irelia — and survives Irelia dying.


## Divine Shield when someone close to Irelia (including herself) is hurt and
## she is in a fight.
func _should_auto_use_active() -> bool:
	if not is_target_valid():
		return false
	var team := TeamRegistry.get_team(TeamRegistry.HEROES)
	if team == null:
		return false
	for ally in team.members:
		if not is_instance_valid(ally) or not (ally is HeroBase):
			continue
		var h := ally as HeroBase
		if h.is_alive() and h.global_position.distance_squared_to(global_position) <= 400.0 * 400.0 \
				and h.get_max_health() > 0.0 and h.get_health() / h.get_max_health() < 0.85:
			return true
	return false

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
	# With group exploration running, the formation keeps Irelia with the team
	# (she leads it as formation_rank 0): follow the controller's target like
	# every hero. Wandering around the allies' centre here stalled the group.
	if use_exploration_target and exploration_target != Vector2.ZERO:
		super._on_idle_state_processing(delta)
		return

	# Wander near allies instead of random
	_idle_timer -= delta
	if _idle_timer <= 0.0 or global_position.distance_squared_to(_idle_goal) < 64.0:
		_idle_timer = idle_retarget_time + minf(_idle_timer, 0.0)
		
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
		
		_set_nav_target(_idle_goal)
	
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
