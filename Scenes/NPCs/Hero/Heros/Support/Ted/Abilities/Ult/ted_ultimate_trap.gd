extends AbilityBase
class_name TedUltimateTrapCage

@export var trap_scene: PackedScene

func _init() -> void:
	ability_name = "Trap Cage"
	ability_type = AbilityType.ULTIMATE
	cooldown = 20.0
	duration = 6.0
	area_of_effect = 150.0
	description = "Creates a cage that traps enemies"

func can_use(_caster: Node2D) -> bool:
	return trap_scene != null

func execute(caster: Node2D, target: Node2D = null, _override_damage: float = -1.0) -> void:
	if not trap_scene:
		push_error("Trap scene not assigned!")
		return
	
	# Spawn cage at target or caster position
	var spawn_pos = caster.global_position
	if target and is_instance_valid(target):
		spawn_pos = target.global_position
	
	var cage = trap_scene.instantiate()
	caster.get_parent().add_child(cage)
	cage.global_position = spawn_pos
	
	# Set cage properties
	if "duration" in cage:
		cage.duration = duration
	if "cage_radius" in cage:
		cage.cage_radius = area_of_effect
	
	print(caster.name + " deployed Trap Cage!")
