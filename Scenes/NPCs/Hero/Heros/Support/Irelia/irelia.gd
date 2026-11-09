extends HeroBase
class_name Irelia

## Tank archetype: taunt_strength (Irelia.tscn) multiplies the threat of her
## damage, and her basic attack adds a flat taunt on top (taunt_threat on the
## attack resource) so mobs actually turn to her.
## Shield absorption lives on the Shield node itself (it listens to
## EventBus.damage_requested for its owner), so Divine Shield protects every
## hero it is applied to — not only Irelia — and survives Irelia dying.


## Last Stand (hero_irelia capstone ir_laststand, on her own Regeneration
## copy): once per match the lethal hit leaves her at 1 HP and she cannot be
## hurt for the passive's last_stand_duration (HeroBase._invulnerable_timer).
func _survives_lethal_hit() -> bool:
	var regen: IreliaPassiveRegeneration = (ability_system.passive_ability as IreliaPassiveRegeneration) if ability_system else null
	if regen == null or not regen.claim_last_stand():
		return false
	make_invulnerable(regen.last_stand_duration)
	EventBus.notify_ability_event(self, regen, FxEvents.LAST_STAND, global_position, regen.last_stand_duration)
	GameUtils.flash_modulate(self, UiPalette.get_default().amber_light, 0.1, regen.last_stand_duration)
	return true


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

	var threatened_ally := _find_threatened_ally()
	if threatened_ally:
		var attacker := _find_enemy_attacking(threatened_ally)
		if attacker:
			set_target(attacker)

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
	# Attackers on a hero's threat row are mobs or the monster (EntityBase).
	var top_attacker := team.highest_threat_target_for(ally) as EntityBase
	if top_attacker == null or not top_attacker.is_alive():
		return null
	var d2 := global_position.distance_squared_to(top_attacker.global_position)
	if d2 > 200.0 * 200.0:
		return null
	return top_attacker

## With group exploration running, the formation keeps Irelia with the team
## (she leads it as formation_rank 0): she idles like every hero. Wandering
## around the allies' centre then stalled the group.
func _follows_exploration() -> bool:
	return use_exploration_target and exploration_target != Vector2.ZERO

## Idle goal: the exploration target, else a point near the allies' centre
## (or around herself when she is alone).
func _get_smart_idle_destination() -> Vector2:
	if _follows_exploration():
		return super._get_smart_idle_destination()
	var ally_center := _get_ally_center()
	if ally_center != Vector2.ZERO:
		var angle := randf() * TAU
		var dir := Vector2.from_angle(angle)
		var dist := randf_range(30.0, 80.0)
		return ally_center + dir * dist
	else:
		var angle := randf() * TAU
		var dir := Vector2.from_angle(angle)
		var dist := randf_range(idle_wander_radius * 0.2, idle_wander_radius)
		return global_position + dir * dist

## Away from the exploring group she waits out the retarget timer.
func _idle_repick_on_path_end() -> bool:
	return _follows_exploration()

func _get_ally_center() -> Vector2:
	## Use the team blackboard membership instead of a group scan.
	var team := TeamRegistry.get_team(TeamRegistry.HEROES)
	if team == null:
		return Vector2.ZERO
	var total := Vector2.ZERO
	var count := 0
	for ally in team.members:
		if ally == self or not is_instance_valid(ally) or not ally.is_alive():
			continue
		total += ally.global_position
		count += 1
	return total / count if count > 0 else Vector2.ZERO
