extends AbilityBase
class_name UltimateAreaDamage

func _init() -> void:
	ability_name = "Shockwave"
	ability_type = AbilityType.ULTIMATE
	damage = 20.0
	range = 200.0  
	cooldown = 15.0

func execute(caster: Node2D, target: Node2D = null) -> void:
	# Find all enemies in range
	var space_state = caster.get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = range
	query.shape = shape
	query.transform = Transform2D(0, caster.global_position)
	query.collision_mask = 1  # Adjust based on your collision layers
	
	var results = space_state.intersect_shape(query, 32)
	
	for result in results:
		var collider = result.collider
		if collider != caster and collider.has_method("take_damage"):
			collider.take_damage(damage)
	
	print(caster.name + " used ultimate! Hit " + str(results.size()) + " targets")
