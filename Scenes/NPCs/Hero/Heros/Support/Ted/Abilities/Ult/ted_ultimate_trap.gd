extends AbilityBase
class_name TedUltimateTrapCage

@export var trap_scene: PackedScene
## hero_ted capstone "Spiked Cage": enemies inside the cage take this much
## damage per second (TrapCage ticks once a second, through deal()). 0 = off.
@export var cage_dps: float = 0.0

func can_use(_caster: Node2D) -> bool:
	return trap_scene != null


## Where the cage lands for a throw at `target`: on it, at most ability_range
## (the throw range) from Ted; no target, at Ted's feet.
func get_cast_center(caster: Node2D, target: Node2D) -> Vector2:
	if target == null or not is_instance_valid(target):
		return caster.global_position
	return caster.global_position + (target.global_position - caster.global_position).limit_length(ability_range)


func get_reach() -> float:
	return area_of_effect


## Hero AI: a target beyond the throw range is no throw at all (the cage would
## land short of it); otherwise the enemies the cage would close on.
func count_reached(caster: Node2D, target: Node2D, cap: int) -> int:
	if target == null or not is_instance_valid(target) \
			or caster.global_position.distance_squared_to(target.global_position) > ability_range * ability_range:
		return 0
	return super.count_reached(caster, target, cap)

## Drops the cage on the target, thrown at most ability_range (or on Ted:
## get_cast_center). Everything TrapCage._ready reads
## is set before add_child: _ready sizes the collision shape from cage_radius
## (area_of_effect), traps the enemies around its position and starts the
## expiry timer from duration (Sturdy Cage's longer one). Until 6.3 the cage
## entered the tree first: it scanned at its parent's origin with the scene's
## 150 px, moved onto the target afterwards and then shrank to the ability's
## radius, so it trapped (almost) nothing.
func execute(caster: Node2D, target: Node2D = null, _override_damage: float = -1.0) -> void:
	if not trap_scene:
		push_error("Trap scene not assigned!")
		return
	var node: Node = trap_scene.instantiate()
	var cage := node as TrapCage
	if cage == null:
		node.free()
		push_error("Trap Cage: trap_scene must be a TrapCage scene")
		return
	var spawn_pos: Vector2 = get_cast_center(caster, target)
	var parent: Node = caster.get_parent()
	# Outside the tree global_position is plain position: place it in the
	# parent's space instead.
	var parent_2d := parent as Node2D
	cage.position = parent_2d.to_local(spawn_pos) if parent_2d else spawn_pos
	cage.cage_radius = area_of_effect
	cage.duration = duration
	cage.cage_dps = cage_dps
	cage.source = caster
	cage.source_ability = self
	parent.add_child(cage)
	# Presentation: the stakes spring up around it (AbilityVfx).
	EventBus.notify_ability_event(cage, self, FxEvents.CAGE_CLOSED, cage.global_position, cage.cage_radius)
