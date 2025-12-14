extends AbilityBase
class_name BasicRangedAttack

@export var projectile_scene: PackedScene

func _init() -> void:
	ability_name = "Fire Arrow"
	ability_type = AbilityType.BASIC_ATTACK
	damage = 3.0
	cooldown = 1.0

func execute(caster: Node2D, target: Node2D = null, _override_damage: float = -1.0) -> void:
	if not target:
		return
	
	# Spawn projectile
	if projectile_scene:
		var projectile = projectile_scene.instantiate()
		caster.get_parent().add_child(projectile)
		projectile.global_position = caster.global_position
		
		# Setup projectile (assuming it has these properties)
		if "damage" in projectile:
			projectile.damage = damage
		if "target" in projectile:
			projectile.target = target
		if "direction" in projectile:
			var dir = (target.global_position - caster.global_position).normalized()
			projectile.direction = dir
