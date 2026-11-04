extends AbilityBase
class_name BasicStrike
## Single-target basic attack shared by the heroes (Vlad, Ted; Irelia extends
## it): hits a target within effective_range for `damage` × the caster's
## AbilitySystem damage multiplier, then flashes an optional trail. Each hero's
## numbers and trail live in its .tres.

@export_group("Trail")
## Flash a fading line from the caster to the struck target on each hit.
@export var trail_enabled: bool = false
@export var trail_color: Color = Color.WHITE
@export var trail_width: float = 2.0
## Seconds until the trail has faded out.
@export var trail_fade: float = 0.2

func can_use(caster: Node2D) -> bool:
	return caster.has_method("is_alive") and caster.is_alive()

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
		EventBus.deal_damage(caster, target, final_damage, self)
		_on_hit(caster, target)

		if trail_enabled:
			GameUtils.flash_line(caster.get_parent(), caster.global_position, target.global_position,
					trail_color, trail_width, trail_fade)

## Extra on-hit effect for subclasses: runs after the damage, before the trail.
func _on_hit(_caster: Node2D, _target: Node2D) -> void:
	pass
