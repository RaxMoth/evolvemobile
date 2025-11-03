extends AbilityBase
class_name VladActiveMine

@export var mine_scene: PackedScene  # Assign the mine scene in the resource

func _init() -> void:
	ability_name = "Land Mine"
	ability_type = AbilityType.ACTIVE
	damage = 15.0
	cooldown = 8.0
	range = 100.0  # Detection radius of mine
	description = "Place a mine that explodes when enemies walk over it"

func can_use(caster: Node2D) -> bool:
	return mine_scene != null

func execute(caster: Node2D, target: Node2D = null) -> void:
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
		mine.detection_radius = range
	if "owner_entity" in mine:
		mine.owner_entity = caster
	
	print(caster.name + " placed a mine!")
