extends AbilityBase
class_name IreliaPassiveRegeneration

func on_passive_update(caster: Node2D, delta: float) -> void:
	if not caster.has_method("get_health"):
		return
	
	var current_health = caster.get_health()
	var max_health = caster.max_health if "max_health" in caster else 100.0
	
	if current_health < max_health and current_health > 0:
		if caster.has_node("HeroStats"):
			var stats = caster.get_node("HeroStats")
			stats.heal(heal_amount * delta)
