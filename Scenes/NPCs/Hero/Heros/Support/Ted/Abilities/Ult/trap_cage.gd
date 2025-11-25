extends Area2D
class_name TrapCage

@export var duration: float = 6.0
@export var cage_radius: float = 150.0

var trapped_enemies: Array[Node2D] = []  # Already typed correctly
var cage_active: bool = true

func _ready() -> void:
	# Setup collision
	var collision_shape = $CollisionShape2D
	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = cage_radius
	
	# Visual
	queue_redraw()
	
	# Connect signals
	body_exited.connect(_on_body_exited)
	area_exited.connect(_on_area_exited)
	
	# Initial scan for enemies
	_scan_for_enemies()
	
	# Expire after duration
	await get_tree().create_timer(duration).timeout
	_expire()

func _draw() -> void:
	if not cage_active:
		return
	
	# Draw cage bars
	var num_bars = 16
	for i in range(num_bars):
		var angle = i * TAU / num_bars
		var start = Vector2(cos(angle), sin(angle)) * (cage_radius - 10)
		var end = Vector2(cos(angle), sin(angle)) * cage_radius
		draw_line(start, end, Color(0.8, 0.3, 0.3), 4.0)
	
	# Draw circle outline
	draw_arc(Vector2.ZERO, cage_radius, 0, TAU, 64, Color.RED, 2.0)
	draw_arc(Vector2.ZERO, cage_radius - 10, 0, TAU, 64, Color(1, 0.5, 0.5, 0.5), 1.0)

func _process(_delta: float) -> void:
	if not cage_active:
		return
	
	# Force trapped enemies to stay inside
	for enemy in trapped_enemies:
		if not is_instance_valid(enemy):
			continue
		
		var dist = enemy.global_position.distance_to(global_position)
		if dist > cage_radius - 15:
			# Push back inside
			var dir: Vector2 = (global_position - enemy.global_position).normalized()
			var push_pos = global_position + dir * (cage_radius - 20)
			enemy.global_position = push_pos

func _scan_for_enemies() -> void:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = cage_radius
	query.shape = shape
	query.transform = Transform2D(0, global_position)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var results = space_state.intersect_shape(query, 32)
	
	for result in results:
		var entity = _get_entity(result.collider)
		if entity and _is_valid_target(entity):
			trapped_enemies.append(entity)
			_apply_trap_effect(entity)

func _on_body_exited(body: Node2D) -> void:
	_prevent_exit(body)

func _on_area_exited(area: Area2D) -> void:
	_prevent_exit(area.get_parent() if area.get_parent() is Node2D else null)

func _prevent_exit(node: Node) -> void:
	if not cage_active or not node:
		return
	
	var entity = _get_entity(node)
	
	# FIXED: Check if entity is Node2D before checking array
	if entity and entity is Node2D and trapped_enemies.has(entity):
		# Teleport back to center of cage
		entity.global_position = global_position

func _apply_trap_effect(entity: Node2D) -> void:
	# Visual indicator that enemy is trapped
	if entity.has_node("Sprite2D"):
		var sprite = entity.get_node("Sprite2D")
		var original_modulate = sprite.modulate
		
		var tween = sprite.create_tween()
		tween.set_loops()
		tween.tween_property(sprite, "modulate", Color(1, 0.5, 0.5), 0.5)
		tween.tween_property(sprite, "modulate", original_modulate, 0.5)

func _is_valid_target(entity: Node) -> bool:
	if not entity.has_method("is_alive") or not entity.is_alive():
		return false
	
	# Trap monsters and enemies, not heroes
	if entity.is_in_group("Enemy") and not entity.is_in_group("Hero"):
		return true
	
	if entity.is_in_group("Monster"):
		return true
	
	return false

func _get_entity(node: Node) -> Node2D:
	# Return as Node2D if valid, otherwise null
	if node is Node2D:
		return node
	elif node.has_method("get_parent") and node.get_parent() is Node2D:
		return node.get_parent()
	elif node.has_method("get_owner") and node.get_owner() is Node2D:
		return node.get_owner()
	return null

func _expire() -> void:
	cage_active = false
	
	# Clear visual effects on trapped enemies
	for enemy in trapped_enemies:
		if is_instance_valid(enemy) and enemy.has_node("Sprite2D"):
			var sprite = enemy.get_node("Sprite2D")
			sprite.modulate = Color.WHITE
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
