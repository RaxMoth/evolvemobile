class_name BullFrontCleave
extends AbilityBase

@export var cone_angle: float = 60.0
@export var cone_range: float = 80.0

func _init() -> void:
	ability_name = "Front Cleave"
	ability_type = AbilityType.ACTIVE
	damage = 15.0
	cooldown = 3.0
	description = "Attacks enemies in a frontal cone"

func execute(caster: Node2D, target: Node2D = null, override_damage: float = -1.0) -> void:
	if not caster or not caster.has_node("Sprite2D"):
		return
	
	# Use override damage if provided
	var effective_damage = override_damage if override_damage >= 0.0 else damage
	
	var sprite = caster.get_node("Sprite2D")
	var forward_dir = Vector2.from_angle(sprite.rotation)
	
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
		
		if not entity or entity == caster or not entity is Node2D:
			continue
		
		var to_entity = (entity.global_position - caster.global_position).normalized()
		var angle_to_entity = forward_dir.angle_to(to_entity)
		
		if abs(angle_to_entity) <= deg_to_rad(cone_angle / 2.0):
			var can_hit = false
			if entity.is_in_group("Hero"):
				can_hit = true
			elif entity.is_in_group("Enemy") and not entity.is_in_group("Monster"):
				can_hit = true
			
			if can_hit and entity.has_method("take_damage"):
				entity.take_damage(effective_damage)
				hit_count += 1
	
	if hit_count > 0:
		print(caster.name + " cleaved " + str(hit_count) + " enemies for " + str(effective_damage) + " damage!")
	
	_create_cleave_effect(caster, forward_dir)

func _get_entity(collider: Node) -> Node2D:
	if collider is Node2D:
		return collider
	elif collider.has_method("get_parent") and collider.get_parent() is Node2D:
		return collider.get_parent()
	elif collider.has_method("get_owner") and collider.get_owner() is Node2D:
		return collider.get_owner()
	return null

func _create_cleave_effect(caster: Node2D, direction: Vector2) -> void:
	var effect = Node2D.new()
	caster.get_parent().add_child(effect)
	effect.global_position = caster.global_position
	effect.rotation = direction.angle()
	
	var tween = effect.create_tween()
	tween.tween_property(effect, "modulate:a", 0.0, 0.3)
	tween.tween_callback(effect.queue_free)