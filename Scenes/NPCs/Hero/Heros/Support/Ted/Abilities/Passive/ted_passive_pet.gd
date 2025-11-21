extends AbilityBase
class_name TedPassivePet

@export var pet_scene: PackedScene

var pet_instance: Node2D = null
var respawn_timer: float = 0.0
var respawn_time: float = 10.0

func on_passive_update(caster: Node2D, delta: float) -> void:
	# Check if pet exists and is alive
	if not is_instance_valid(pet_instance):
		respawn_timer -= delta
		
		if respawn_timer <= 0.0:
			_spawn_pet(caster)
	
	# Update pet's attack speed if boosted
	if is_instance_valid(pet_instance) and caster.has_method("get_attack_speed_boost"):
		var boost = caster.get_attack_speed_boost()
		if pet_instance.has_method("set_attack_speed_boost"):
			pet_instance.set_attack_speed_boost(boost)

func _spawn_pet(caster: Node2D) -> void:
	if not pet_scene:
		return
	
	pet_instance = pet_scene.instantiate()
	caster.get_parent().add_child(pet_instance)
	pet_instance.global_position = caster.global_position + Vector2(30, 0)
	
	if "owner" in pet_instance:
		pet_instance.owner = caster
	
	# Connect to pet death
	if pet_instance.has_signal("pet_died"):
		pet_instance.pet_died.connect(_on_pet_died)

func _on_pet_died() -> void:
	pet_instance = null
	respawn_timer = respawn_time
