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


## Everything Mine._ready reads is set before add_child: it sizes its trigger
## from detection_radius (the scene's 100 used to win, latent while the Land
## Mine's range is 100 too). An enemy already inside the trigger sets it off at
## once: the README's "explosion when an enemy steps on it" with Vlad standing
## next to his target.
func _place_mine(caster: Node2D, at: Vector2) -> void:
	var mine = mine_scene.instantiate()
	if "damage" in mine:
		mine.damage = damage
	if "detection_radius" in mine:
		mine.detection_radius = ability_range  # was bare `range` (GDScript builtin Callable)
	if "owner_entity" in mine:
		mine.owner_entity = caster
	if "source_ability" in mine:
		mine.source_ability = self
	var parent: Node = caster.get_parent()
	var parent_2d := parent as Node2D
	mine.position = parent_2d.to_local(at) if parent_2d else at
	parent.add_child(mine)
	# Presentation: the arming ring and dust (AbilityVfx).
	EventBus.notify_ability_event(mine, self, FxEvents.MINE_ARMED, at, ability_range)
