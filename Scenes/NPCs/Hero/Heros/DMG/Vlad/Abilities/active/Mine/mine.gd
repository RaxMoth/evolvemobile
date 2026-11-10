extends Area2D
class_name Mine

@export var damage: float = 15.0
@export var detection_radius: float = 100.0
@export var explosion_delay: float = 0.1  # Small delay before explosion
@export var lifetime: float = 30.0  # Mine disappears after 30 seconds

var owner_entity: Node2D = null
## The Land Mine copy that placed it (presentation: its recipe colours the
## blast).
var source_ability: AbilityBase = null
var has_exploded: bool = false


func _ready() -> void:
	# CollisionShape2D, the Pod and Lamp sprites, the Blink AnimationPlayer
	# and the signal connections all live in Mine.tscn. This script only
	# handles runtime state. We still sync the shape's radius to the @export
	# detection_radius at spawn so callers can customize it (active_mine.gd
	# does this).
	var cs := $CollisionShape2D as CollisionShape2D
	if cs and cs.shape is CircleShape2D:
		(cs.shape as CircleShape2D).radius = detection_radius

	$Pod/Lamp.self_modulate = UiPalette.get_default().danger
	queue_redraw()  # for the runtime _draw overlay

	# Auto-destroy after lifetime.
	await get_tree().create_timer(lifetime).timeout
	if not has_exploded:
		queue_free()

## The trigger radius: a dashed ink and vlad ring at the telegraph alpha
## (VfxManager.TELEGRAPH_ALPHA), at most 3 px wide. Nothing once it went off.
func _draw() -> void:
	if has_exploded:
		return
	var palette := UiPalette.get_default()
	var ink := Color(palette.ink, VfxManager.TELEGRAPH_ALPHA)
	var col := Color(palette.vlad, VfxManager.TELEGRAPH_ALPHA)
	var dashes: int = 20
	var step: float = TAU / float(dashes)
	for i in dashes:
		var a0: float = step * float(i)
		draw_arc(Vector2.ZERO, detection_radius, a0, a0 + step * 0.5, 4, ink, 3.0)
		draw_arc(Vector2.ZERO, detection_radius, a0, a0 + step * 0.5, 4, col, 1.5)

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
	# The blast is AbilityVfx's; the mine itself goes out of sight. Its node
	# still grows 3x over 0.2 s (and its trigger shape with it), as it always
	# has: only the look changed.
	visible = false
	EventBus.notify_ability_event(self, source_ability, FxEvents.MINE_EXPLODED, global_position, detection_radius)
	create_tween().tween_property(self, "scale", Vector2(3, 3), 0.2)
	await get_tree().create_timer(explosion_delay).timeout
	
	# Every enemy in range, once each (never the placer). owner_entity is
	# freed once the placer dies, and a freed object is no valid typed argument.
	var placer: Node2D = owner_entity if is_instance_valid(owner_entity) else null
	for entity in GameUtils.entities_in_circle(get_world_2d(), global_position, detection_radius,
			GameUtils.MASK_HERO_TARGETS, false, placer):
		if entity.is_in_group("Enemy"):
			# The mine acts as the source — owner_entity is the placer for attribution
			EventBus.deal_damage(owner_entity, entity, damage, null)
	
	# Destroy mine
	await get_tree().create_timer(0.2).timeout
	queue_free()
