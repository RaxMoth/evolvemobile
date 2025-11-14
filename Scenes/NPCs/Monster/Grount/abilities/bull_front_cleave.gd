class_name BullFrontCleave
extends AbilityBase

@export var cone_angle: float = 60.0  # Degrees
@export var cone_range: float = 80.0

# Don't use _init(), set values directly as exports or in _ready()
# OR set them in the .tres resource file

func execute(caster: Node2D, target: Node2D = null) -> void:
	if not caster:
		return
	
	# Get direction bull is facing
	var forward_dir = Vector2.from_angle(caster.sprite.rotation)
	
	# Find all entities in cone
	var space_state = caster.get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = cone_range
	query.shape = shape
	query.transform = Transform2D(0, caster.global_position)
	query.collide_with_areas = true
	
	var results = space_state.intersect_shape(query, 32)
	var hit_count = 0
	
	for result in results:
		var collider = result.collider
		var entity = _get_entity(collider)
		
		if entity == caster or not entity:
			continue
		
		# Check if entity is in front cone
		var to_entity = (entity.global_position - caster.global_position).normalized()
		var angle_to_entity = forward_dir.angle_to(to_entity)
		
		# Convert cone angle to radians and check if in cone
		if abs(angle_to_entity) <= deg_to_rad(cone_angle / 2.0):
			if entity.is_in_group("Enemy") and entity.has_method("take_damage"):
				entity.take_damage(damage)
				hit_count += 1
	
	if hit_count > 0:
		print(caster.name + " cleaved " + str(hit_count) + " enemies!")
	
	# Visual effect (optional)
	_create_cleave_effect(caster, forward_dir)

func _get_entity(collider: Node) -> Node:
	if collider.has_method("get_parent"):
		return collider.get_parent()
	elif collider.has_method("get_owner"):
		return collider.get_owner()
	return collider

func _create_cleave_effect(caster: Node2D, direction: Vector2) -> void:
	# Simple visual feedback
	var effect = Node2D.new()
	caster.get_parent().add_child(effect)
	effect.global_position = caster.global_position
	effect.rotation = direction.angle()
	
	# Animate and cleanup
	var tween = effect.create_tween()
	tween.tween_property(effect, "modulate:a", 0.0, 0.3)
	tween.tween_callback(effect.queue_free)
