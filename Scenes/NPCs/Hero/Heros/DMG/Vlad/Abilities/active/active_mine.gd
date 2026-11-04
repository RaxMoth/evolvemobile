extends AbilityBase
class_name VladActiveMine

@export var mine_scene: PackedScene # Assign the mine scene in the resource

func can_use(_caster: Node2D) -> bool:
	return mine_scene != null

func execute(caster: Node2D, _target: Node2D = null, _override_damage: float = -1.0) -> void:
	if not mine_scene:
		push_error("Mine scene not assigned!")
		return
	
	# Spawn mine at caster's position
	var mine = mine_scene.instantiate()
	caster.get_parent().add_child(mine)
	mine.global_position = caster.global_position
	
	# Set mine properties
	if "damage" in mine:
		mine.damage = damage
	if "detection_radius" in mine:
		mine.detection_radius = ability_range  # was bare `range` (GDScript builtin Callable)
	if "owner_entity" in mine:
		mine.owner_entity = caster
