extends AbilityBase
class_name IreliaActiveShield

## hero_irelia capstone "Guardian Angel": the shield also ends every stun on
## the heroes it lands on (EntityBase.clear_stun).
@export var cleanse_stuns: bool = false

func execute(caster: Node2D, _target: Node2D = null, _override_damage: float = -1.0) -> void:
	var heroes = caster.get_tree().get_nodes_in_group("Hero")
	
	for hero in heroes:
		if not (hero is HeroBase) or not hero.is_alive():
			continue
		
		_apply_shield(hero)
		if cleanse_stuns:
			(hero as HeroBase).clear_stun()

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
	# Presentation: the hero's ward (AbilityVfx, coloured by this recipe).
	EventBus.notify_ability_event(shield, self, FxEvents.SHIELD_UP, hero.global_position, shield.shield_amount)
