extends AbilityBase
class_name IreliaActiveShield

func execute(caster: Node2D, _target: Node2D = null, _override_damage: float = -1.0) -> void:
	var heroes = caster.get_tree().get_nodes_in_group("Hero")
	
	for hero in heroes:
		if not (hero is HeroBase) or not hero.is_alive():
			continue
		
		_apply_shield(hero)

func _apply_shield(hero: Node2D) -> void:
	# Remove existing shield if any
	if hero.has_node("Shield"):
		hero.get_node("Shield").queue_free()
	
	# Create new shield
	var shield = preload("res://Scenes/NPCs/Hero/Heros/Support/Irelia/Abilities/Active/shield.gd").new()
	shield.name = "Shield"
	shield.shield_amount = heal_amount # Using heal_amount as shield amount
	shield.duration = duration
	shield.owner_hero = hero
	hero.add_child(shield)
