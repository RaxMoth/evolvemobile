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
			pet.set_attack_speed_boost(attack_speed_boost, boost_duration)
	
	# Visual feedback
	_create_rally_effect(caster)

func _create_rally_effect(caster: Node2D) -> void:
	# Flash Ted orange
	var original_modulate = caster.modulate
	var flash_tween = caster.create_tween()
	flash_tween.tween_property(caster, "modulate", Color.ORANGE, 0.2)
	flash_tween.tween_property(caster, "modulate", original_modulate, 0.2)
