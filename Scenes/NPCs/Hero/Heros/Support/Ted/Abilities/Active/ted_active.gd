extends AbilityBase
class_name TedActiveRally

## Rally Cry - Boosts attack speed for Ted and his pet

@export var attack_speed_boost: float = 1.5 # 50% faster attacks
@export var boost_duration: float = 5.0

func _init() -> void:
	ability_name = "Rally Cry"
	ability_type = AbilityType.ACTIVE
	cooldown = 10.0
	description = "Ted and his pet gain 50% attack speed for 5 seconds"

func execute(caster: Node2D, _target: Node2D = null, _override_damage: float = -1.0) -> void:
	if not caster:
		return
	
	# Apply boost to Ted
	if caster.has_method("apply_attack_speed_boost"):
		caster.apply_attack_speed_boost(attack_speed_boost, boost_duration)
	
	# Apply boost to pet if it exists
	if caster.has_method("get_pet"):
		var pet = caster.get_pet()
		if is_instance_valid(pet) and pet.has_method("set_attack_speed_boost"):
			pet.set_attack_speed_boost(attack_speed_boost)
	
	# Visual feedback
	_create_rally_effect(caster)
	
	print(caster.name + " used Rally Cry!")

func _create_rally_effect(caster: Node2D) -> void:
	# Create expanding orange ring effect
	var effect = Node2D.new()
	caster.get_parent().add_child(effect)
	effect.global_position = caster.global_position
	effect.z_index = 10
	
	# Draw expanding circle
	var circle_visual = Node2D.new()
	effect.add_child(circle_visual)
	circle_visual.z_index = 10
	
	# Animate
	var tween = effect.create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "scale", Vector2(3, 3), 0.4)
	tween.tween_property(effect, "modulate:a", 0.0, 0.4)
	tween.tween_callback(effect.queue_free)
	
	# Flash Ted orange
	var original_modulate = caster.modulate
	var flash_tween = caster.create_tween()
	flash_tween.tween_property(caster, "modulate", Color.ORANGE, 0.2)
	flash_tween.tween_property(caster, "modulate", original_modulate, 0.2)
