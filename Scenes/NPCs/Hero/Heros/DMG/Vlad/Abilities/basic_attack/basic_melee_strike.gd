extends AbilityBase
class_name BasicStrike
## Single-target basic attack shared by the heroes (Vlad, Ted; Irelia extends
## it): hits a target within effective_range for `damage` × the caster's
## AbilitySystem damage multiplier, then flashes an optional trail. Each hero's
## numbers and trail live in its .tres. Damage goes through deal(), so a
## lifesteal_pct (Vlad's Sanguine Feast) heals the striker.

@export_group("Execute")
## hero_vlad capstone "Executioner's Mark": a target below this HP fraction
## takes execute_mult x the strike's damage. 0 = off.
@export var execute_threshold: float = 0.0
@export var execute_mult: float = 2.0

@export_group("Trail")
## Flash a fading line from the caster to the struck target on each hit.
@export var trail_enabled: bool = false
@export var trail_color: Color = Color.WHITE
@export var trail_width: float = 2.0
## Seconds until the trail has faded out.
@export var trail_fade: float = 0.2

func can_use(caster: Node2D) -> bool:
	return caster is EntityBase and (caster as EntityBase).is_alive()

func execute(caster: Node2D, target: Node2D = null, _override_damage: float = -1.0) -> void:
	if not is_instance_valid(target) or not is_instance_valid(caster):
		return

	var distance: float = caster.global_position.distance_to(target.global_position)
	if distance <= effective_range(caster):
		# Passive × hero level/upgrade damage scale. (Attack-speed buffs such as
		# Ted's Rally Cry shorten the cooldown in AbilitySystem instead.)
		var damage_mult: float = 1.0
		var ability_system := caster.get_node_or_null("AbilitySystem") as AbilitySystem
		if ability_system:
			damage_mult = ability_system.get_damage_multiplier()

		var final_damage: float = damage * damage_mult
		if _is_execute_target(target):
			final_damage *= execute_mult
		deal(caster, target, final_damage)
		_on_hit(caster, target)

		if trail_enabled:
			GameUtils.flash_line(caster.get_parent(), caster.global_position, target.global_position,
					trail_color, trail_width, trail_fade)

## Executioner's Mark: the target's HP fraction is below execute_threshold.
func _is_execute_target(target: Node2D) -> bool:
	if execute_threshold <= 0.0:
		return false
	var entity := target as EntityBase
	if entity == null or entity.get_max_health() <= 0.0:
		return false
	return entity.get_health() / entity.get_max_health() < execute_threshold

## Extra on-hit effect for subclasses: runs after the damage, before the trail.
func _on_hit(_caster: Node2D, _target: Node2D) -> void:
	pass
