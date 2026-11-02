extends AbilityBase
class_name IreliaBasicAttack

## Taunting strike: flat threat added on the struck enemy's threat table per
## hit (on top of damage × taunt_strength). Without it a 5-damage tank never
## out-threatened the DPS, so mob packs stayed on whoever pulled them.
@export var taunt_threat: float = 40.0

func can_use(caster: Node2D) -> bool:
	return caster.has_method("is_alive") and caster.is_alive()

func execute(caster: Node2D, target: Node2D = null, _override_damage: float = -1.0) -> void:
	if not is_instance_valid(target) or not is_instance_valid(caster):
		return

	var distance = caster.global_position.distance_to(target.global_position)
	if distance <= effective_range(caster):
		var damage_mult = 1.0
		if caster.has_node("AbilitySystem"):
			var ability_system = caster.get_node("AbilitySystem")
			damage_mult = ability_system.get_damage_multiplier()

		var final_damage = damage * damage_mult
		EventBus.deal_damage(caster, target, final_damage, self)
		if taunt_threat > 0.0 and is_instance_valid(target):
			var team: TeamBlackboard = TeamRegistry.team_of(target)
			if team:
				team.bump_threat(target, caster, taunt_threat)

		_create_attack_effect(caster, target)

func _create_attack_effect(caster: Node2D, target: Node2D) -> void:
	var line = Line2D.new()
	caster.get_parent().add_child(line)
	line.add_point(caster.global_position)
	line.add_point(target.global_position)
	line.default_color = Color(0.7, 0.7, 1.0)  # Light blue
	line.width = 1.5
	line.z_index = 10
	
	var tween = line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.25)
	tween.tween_callback(line.queue_free)
