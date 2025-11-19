extends Area2D
class_name MediKit

@export var heal_amount: float = 30.0
@export var detection_radius: float = 50.0
@export var lifetime: float = 20.0

var owner_entity: Node2D = null
var healed_heroes: Array[Node2D] = []

func _ready() -> void:
	# Setup collision shape
	var collision_shape = $CollisionShape2D
	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = detection_radius
	
	# Visual representation
	queue_redraw()
	
	# Connect signals
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	# Auto-destroy after lifetime
	await get_tree().create_timer(lifetime).timeout
	_fade_out()

func _draw() -> void:
	# Draw medikit visual (green cross)
	draw_circle(Vector2.ZERO, 12, Color.WHITE)
	draw_circle(Vector2.ZERO, 10, Color.GREEN)
	
	# Draw cross
	draw_line(Vector2(-6, 0), Vector2(6, 0), Color.WHITE, 3.0)
	draw_line(Vector2(0, -6), Vector2(0, 6), Color.WHITE, 3.0)
	
	# Draw detection radius (faint circle)
	draw_arc(Vector2.ZERO, detection_radius, 0, TAU, 32, Color(0, 1, 0, 0.3), 1.0)

func _on_area_entered(area: Area2D) -> void:
	_check_healing(area)

func _on_body_entered(body: Node2D) -> void:
	_check_healing(body)

func _check_healing(node: Node) -> void:
	var entity = node
	if node.has_method("get_parent"):
		entity = node.get_parent()
	if node.has_method("get_owner"):
		entity = node.get_owner()
	
	# Only heal heroes
	if entity and entity.is_in_group("Hero"):
		_heal_hero(entity)

func _heal_hero(hero: Node2D) -> void:
	# Don't heal same hero twice
	if healed_heroes.has(hero):
		return
	
	# Don't heal dead heroes
	if hero.has_method("is_alive") and not hero.is_alive():
		return
	
	# Apply healing
	if hero.has_node("HeroStats"):
		var stats = hero.get_node("HeroStats")
		stats.heal(heal_amount)
		healed_heroes.append(hero)
		
		# Visual feedback
		_create_heal_effect(hero)
		
		# Check if we should disappear (all nearby heroes healed)
		_check_if_should_disappear()

func _create_heal_effect(hero: Node2D) -> void:
	# Green flash on hero
	var original_modulate = hero.modulate
	var tween = hero.create_tween()
	tween.tween_property(hero, "modulate", Color.GREEN, 0.1)
	tween.tween_property(hero, "modulate", original_modulate, 0.2)

func _check_if_should_disappear() -> void:
	# Find all heroes in range
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = detection_radius
	query.shape = shape
	query.transform = Transform2D(0, global_position)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var results = space_state.intersect_shape(query, 32)
	var heroes_in_range = 0
	
	for result in results:
		var entity = result.collider
		if entity.has_method("get_parent"):
			entity = entity.get_parent()
		
		if entity and entity.is_in_group("Hero"):
			heroes_in_range += 1
			if not healed_heroes.has(entity):
				# Still heroes to heal
				return
	
	# All nearby heroes healed, fade out
	if heroes_in_range > 0 and heroes_in_range == healed_heroes.size():
		_fade_out()

func _fade_out() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
