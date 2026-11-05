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
	
	# area_entered / body_entered are wired in MediKit.tscn.
	
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
	# Only HeroBase heroes have HP to heal: Ted's pet (group Hero) is neither
	# healed nor recorded. Don't heal the same hero twice.
	if not hero is HeroBase or healed_heroes.has(hero):
		return

	# Don't heal dead heroes
	var hero_base := hero as HeroBase
	if not hero_base.is_alive():
		return

	# Apply healing
	hero_base.heal(heal_amount)
	healed_heroes.append(hero)

	# Visual feedback
	_create_heal_effect(hero)

	# Check if we should disappear (all nearby heroes healed)
	_check_if_should_disappear()

func _create_heal_effect(hero: Node2D) -> void:
	# Green flash on hero
	GameUtils.flash_modulate(hero, Color.GREEN, 0.1, 0.2)

func _check_if_should_disappear() -> void:
	# Every hero in range, once each.
	var heroes_in_range: int = 0
	for entity in GameUtils.entities_in_circle(get_world_2d(), global_position, detection_radius,
			GameUtils.MASK_HEROES, false):
		# Only heroes the kit can heal (Ted's pet has a hitbox on the hero
		# layer now and kept the kit alive for its whole lifetime).
		if entity is HeroBase:
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
