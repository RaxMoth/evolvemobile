extends AbilityBase
class_name IreliaActiveShield

@export var shield_scene: PackedScene

func execute(caster: Node2D, _target: Node2D = null, _override_damage: float = -1.0) -> void:
	var heroes = caster.get_tree().get_nodes_in_group("Hero")
	var shielded_count = 0
	
	for hero in heroes:
		if not hero.has_method("is_alive") or not hero.is_alive():
			continue
		
		_apply_shield(hero)
		shielded_count += 1
	
	_create_shield_wave_effect(caster)

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
	
	# Override take_damage to use shield
	if not hero.has_method("_original_take_damage"):
		_hook_damage_function(hero, shield)
	
	# Visual feedback
	_create_shield_applied_effect(hero)

func _hook_damage_function(hero: Node2D, shield: Node) -> void:
	# Store original take_damage
	if hero.has_meta("original_take_damage"):
		return # Already hooked
	
	hero.set_meta("original_take_damage", true)
	
	# The shield will intercept damage in its absorb_damage method
	# We need to modify the hero's take_damage to check for shield

func _create_shield_applied_effect(hero: Node2D) -> void:
	# Blue expanding circle
	var effect = Node2D.new()
	hero.add_child(effect)
	effect.z_index = 10
	
	var circle = Sprite2D.new()
	effect.add_child(circle)
	circle.modulate = Color(0.3, 0.5, 1.0, 0.5)
	
	var tween = effect.create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "scale", Vector2(2, 2), 0.3)
	tween.tween_property(circle, "modulate:a", 0.0, 0.3)
	tween.tween_callback(effect.queue_free)

func _create_shield_wave_effect(caster: Node2D) -> void:
	# Expanding blue wave from caster
	var wave = Node2D.new()
	caster.get_parent().add_child(wave)
	wave.global_position = caster.global_position
	wave.z_index = 9
	
	var tween = wave.create_tween()
	tween.set_parallel(true)
	tween.tween_property(wave, "scale", Vector2(10, 10), 0.6)
	tween.tween_property(wave, "modulate:a", 0.0, 0.6)
	tween.tween_callback(wave.queue_free)
