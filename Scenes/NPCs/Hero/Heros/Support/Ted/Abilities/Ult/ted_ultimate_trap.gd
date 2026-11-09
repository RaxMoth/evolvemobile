extends AbilityBase
class_name TedUltimateTrapCage

@export var trap_scene: PackedScene
## hero_ted capstone "Spiked Cage": enemies inside the cage take this much
## damage per second (TrapCage ticks once a second, through deal()). 0 = off.
@export var cage_dps: float = 0.0

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
	# Before add_child: the cage's _ready starts its expiry timer from
	# `duration`, so Sturdy Cage's longer duration has to be there by then.
	if "duration" in cage:
		cage.duration = duration
	var trap := cage as TrapCage
	if trap:
		trap.cage_dps = cage_dps
		trap.source = caster
		trap.source_ability = self
	caster.get_parent().add_child(cage)
	cage.global_position = spawn_pos
	
	# Set cage properties
	if "cage_radius" in cage:
		cage.cage_radius = area_of_effect
