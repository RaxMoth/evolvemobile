extends Area2D
class_name Mine

@export var damage: float = 15.0
@export var detection_radius: float = 100.0
@export var explosion_delay: float = 0.1  # Small delay before explosion
@export var lifetime: float = 30.0  # Mine disappears after 30 seconds

var owner_entity: Node2D = null
var has_exploded: bool = false

func _ready() -> void:
	# Setup collision shape
	var collision_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = detection_radius
	collision_shape.shape = circle
	add_child(collision_shape)
	
	# Visual representation (simple red circle for now)
	queue_redraw()
	
	# Connect signals
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	# Auto-destroy after lifetime
	await get_tree().create_timer(lifetime).timeout
	if not has_exploded:
		queue_free()

func _draw() -> void:
	# Draw mine visual (red circle with black outline)
	draw_circle(Vector2.ZERO, 8, Color.DARK_RED)
	draw_arc(Vector2.ZERO, 8, 0, TAU, 16, Color.BLACK, 2.0)
	
	# Draw detection radius (faint circle)
	if not has_exploded:
		draw_arc(Vector2.ZERO, detection_radius, 0, TAU, 32, Color(1, 0, 0, 0.2), 1.0)

func _on_area_entered(area: Area2D) -> void:
	_check_explosion(area)

func _on_body_entered(body: Node2D) -> void:
	_check_explosion(body)

func _check_explosion(node: Node) -> void:
	if has_exploded:
		return
	
	# Don't explode on owner
	var entity = node
	if node.has_method("get_parent"):
		entity = node.get_parent()
	if node.has_method("get_owner"):
		entity = node.get_owner()
	
	if entity == owner_entity:
		return
	
	# Check if it's an enemy
	if entity and entity.is_in_group("Enemy"):
		_explode()

func _explode() -> void:
	if has_exploded:
		return
	
	has_exploded = true
	
	# Visual explosion effect
	modulate = Color.ORANGE_RED
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(3, 3), 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	
	# Wait a tiny bit for visual effect
	await get_tree().create_timer(explosion_delay).timeout
	
	# Deal damage to all enemies in range
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = detection_radius
	query.shape = shape
	query.transform = Transform2D(0, global_position)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var results = space_state.intersect_shape(query, 32)
	
	for result in results:
		var collider = result.collider
		var entity = null
		
		if collider.has_method("get_parent"):
			entity = collider.get_parent()
		elif collider.has_method("get_owner"):
			entity = collider.get_owner()
		else:
			entity = collider
		
		if entity == owner_entity:
			continue
		
		if entity and entity.is_in_group("Enemy") and entity.has_method("take_damage"):
			entity.take_damage(damage)
			print("Mine hit " + entity.name + " for " + str(damage) + " damage")
	
	# Destroy mine
	await get_tree().create_timer(0.2).timeout
	queue_free()
