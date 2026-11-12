extends AbilityBase
class_name RiverUltimateMediKit

@export var medikit_scene: PackedScene
## The kit's pickup radius (MediKit.detection_radius).
@export var pickup_radius: float = 60.0

func can_use(_caster: Node2D) -> bool:
	return medikit_scene != null


## Hero AI (River's auto-ultimate): the heroes the kit would heal where it
## lands, at River's feet: living heroes within pickup_radius of her (herself
## included) who miss at least the kit's heal_amount; counted up to `cap`.
## A target does not matter.
func count_reached(caster: Node2D, _target: Node2D, cap: int) -> int:
	var n: int = 0
	var r_sq: float = pickup_radius * pickup_radius
	for node in EntityRegistry.heroes:
		var hero := node as HeroBase
		if hero == null or not hero.is_alive() \
				or hero.global_position.distance_squared_to(caster.global_position) > r_sq:
			continue
		if hero.get_max_health() - hero.get_health() >= heal_amount:
			n += 1
			if n >= cap:
				break
	return n


## Drops the kit at River's feet. Everything MediKit._ready reads is set
## before add_child (its trigger used to be sized with the scene's 50 px
## while the ring showed 60); the kit plays its own fall and heals only once it
## has landed.
func execute(caster: Node2D, _target: Node2D = null, _override_damage: float = -1.0) -> void:
	if not medikit_scene:
		push_error("MediKit scene not assigned!")
		return
	var node: Node = medikit_scene.instantiate()
	var kit := node as MediKit
	if kit == null:
		node.free()
		push_error("Supply Drop: medikit_scene must be a MediKit scene")
		return
	kit.heal_amount = heal_amount
	kit.detection_radius = pickup_radius
	kit.owner_entity = caster
	kit.source_ability = self
	var parent: Node = caster.get_parent()
	# Outside the tree global_position is plain position: place it in the
	# parent's space instead.
	var parent_2d := parent as Node2D
	kit.position = parent_2d.to_local(caster.global_position) if parent_2d else caster.global_position
	parent.add_child(kit)
