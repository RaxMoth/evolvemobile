extends AbilityBase
class_name VladUltimateBloodBomb

func _init() -> void:
	ability_name = "Blood Bomb"
	ability_type = AbilityType.ULTIMATE
	damage = 40.0
	area_of_effect = 150.0
	cooldown = 20.0
	description = "Creates a devastating explosion that damages all enemies in range"

func execute(caster: Node2D, target: Node2D = null) -> void:
	# Visual effect (optional - add later)
	_create_explosion_effect(caster)
	
	# Find all entities in range
	var space_state = caster.get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = area_of_effect
	query.shape = shape
	query.transform = Transform2D(0, caster.global_position)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var results = space_state.intersect_shape(query, 32)
	var hit_count = 0
	
	for result in results:
		var collider = result.collider
		var entity = null
		
		# Try to find the entity (might be Area2D or body)
		if collider.has_method("get_parent"):
			entity = collider.get_parent()
		elif collider.has_method("get_owner"):
			entity = collider.get_owner()
		else:
			entity = collider
		
		# Don't damage self
		if entity == caster:
			continue
		
		# Check if it's an enemy
		if entity and entity.is_in_group("Enemy") and entity.has_method("take_damage"):
			entity.take_damage(damage)
			hit_count += 1
	
	print(caster.name + " used Blood Bomb! Hit " + str(hit_count) + " targets")

func _create_explosion_effect(caster: Node2D) -> void:
	# Simple visual feedback - could be expanded with particles later
	var circle = Node2D.new()
	caster.get_parent().add_child(circle)
	circle.global_position = caster.global_position
	circle.z_index = 10
	
	# Create a simple expanding circle effect
	var tween = circle.create_tween()
	tween.tween_method(_draw_explosion_circle.bind(circle), 0.0, area_of_effect, 0.3)
	tween.tween_callback(circle.queue_free)

func _draw_explosion_circle(radius: float, circle_node: Node2D) -> void:
	circle_node.queue_redraw()
