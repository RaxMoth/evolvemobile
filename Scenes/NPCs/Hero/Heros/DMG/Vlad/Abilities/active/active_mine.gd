extends AbilityBase
class_name VladActiveMine

@export var mine_scene: PackedScene # Assign the mine scene in the resource
## hero_vlad capstone "Cluster Mines": mines placed per cast, at the corners of
## a regular polygon around Vlad with mine_spacing px between neighbours (3 =
## a triangle). 1 = the single mine under him.
@export var mine_count: int = 1
@export var mine_spacing: float = 40.0

func can_use(_caster: Node2D) -> bool:
	return mine_scene != null

func execute(caster: Node2D, _target: Node2D = null, _override_damage: float = -1.0) -> void:
	if not mine_scene:
		push_error("Mine scene not assigned!")
		return

	for i in maxi(mine_count, 1):
		_place_mine(caster, caster.global_position + mine_offset(i))


## Where mine `index` of a cast lies relative to Vlad: under him for a single
## mine, else on a circle whose chord between neighbours is mine_spacing, the
## first corner straight up.
func mine_offset(index: int) -> Vector2:
	if mine_count <= 1:
		return Vector2.ZERO
	var radius: float = mine_spacing / (2.0 * sin(PI / mine_count))
	return Vector2.UP.rotated(TAU * index / mine_count) * radius


func _place_mine(caster: Node2D, at: Vector2) -> void:
	var mine = mine_scene.instantiate()
	caster.get_parent().add_child(mine)
	mine.global_position = at

	# Set mine properties
	if "damage" in mine:
		mine.damage = damage
	if "detection_radius" in mine:
		mine.detection_radius = ability_range  # was bare `range` (GDScript builtin Callable)
	if "owner_entity" in mine:
		mine.owner_entity = caster
