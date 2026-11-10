extends AbilityBase
class_name IreliaUltimateTaunt

@export_group("Rallying Taunt")
## hero_irelia capstone "Rallying Taunt": every living hero within this many px
## of Irelia (herself included) gets Rally Cry's attack-speed boost,
## rally_attack_speed, for the taunt's duration. 0 = off.
@export var rally_radius: float = 0.0
@export var rally_attack_speed: float = 1.25

func execute(caster: Node2D, _target: Node2D = null, _override_damage: float = -1.0) -> void:
	var monsters = caster.get_tree().get_nodes_in_group("Monster")
	var taunted_count = 0
	
	for monster in monsters:
		if not is_instance_valid(monster) or not (monster is EntityBase) or not (monster as EntityBase).is_alive():
			continue
		if _is_cc_immune(monster):
			_shrugged(monster as MonsterBase, caster)
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
			if _is_cc_immune(enemy):
				continue
			
			var distance = caster.global_position.distance_to(enemy.global_position)
			if distance <= ability_range:
				_apply_taunt(enemy, caster)
				taunted_count += 1
	
	# The war-cry ring and the "!" are the cast's recipe (AbilityVfx).
	if rally_radius > 0.0:
		_rally_heroes(caster)

## Gorrak's Unstoppable (MonsterBase.is_cc_immune): the taunt skips him, in
## both passes (a monster is in the "Enemy" group too).
func _is_cc_immune(enemy: Node) -> bool:
	return enemy is MonsterBase and (enemy as MonsterBase).is_cc_immune()


## Presentation: an Unstoppable monster within the taunt's range shrugs it
## off (AbilityVfx, in the colours of its passive's recipe).
func _shrugged(monster: MonsterBase, caster: Node2D) -> void:
	if caster.global_position.distance_to(monster.global_position) <= ability_range:
		EventBus.notify_ability_event(monster, monster.passive_ability, FxEvents.CC_SHRUGGED, caster.global_position)


## Rallying Taunt: the heroes around Irelia attack faster while the taunt lasts.
func _rally_heroes(caster: Node2D) -> void:
	var team := TeamRegistry.get_team(TeamRegistry.HEROES)
	if team == null:
		return
	var r_sq: float = rally_radius * rally_radius
	for ally in team.members:
		var hero := ally as HeroBase
		if hero == null or not hero.is_alive() or hero.global_position.distance_squared_to(caster.global_position) > r_sq:
			continue
		hero.apply_attack_speed_boost(rally_attack_speed, duration)
		EventBus.notify_ability_event(hero, self, FxEvents.RALLIED, caster.global_position, duration)

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
	
	# Presentation: the anger vein and the tether to Irelia (AbilityVfx).
	if is_instance_valid(enemy) and is_instance_valid(caster):
		EventBus.notify_ability_event(enemy, self, FxEvents.TAUNTED, caster.global_position, duration)

# FIXED: Separate timer function with validation
func _schedule_taunt_cleanup(enemy: Node2D, taunt: Node, duration_time: float) -> void:
	await enemy.get_tree().create_timer(duration_time).timeout
	
	# CRITICAL: Validate before cleanup
	if is_instance_valid(taunt) and is_instance_valid(enemy):
		taunt.queue_free()
