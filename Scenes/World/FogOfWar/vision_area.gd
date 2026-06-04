extends Area2D
class_name VisionArea

signal area_revealed(cells: Array)

@export var vision_radius: float = 200.0
@export var reveal_update_interval: float = 0.7  # Update every 0.2s

var revealed_cells: Dictionary = {}  # Track what this hero has revealed
var update_timer: float = 0.0

func _ready() -> void:
	# CollisionShape2D + Area2D collision flags (layer 0, mask 0, monitoring
	# off, monitorable off) are all declared in VisionArea.tscn. We just
	# sync the shape's radius to the @export vision_radius — callers
	# (FogOfWarHelper.add_vision_to_hero) override the radius per-hero.
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision and collision.shape is CircleShape2D:
		(collision.shape as CircleShape2D).radius = vision_radius

func _process(delta: float) -> void:
	update_timer -= delta
	
	if update_timer <= 0.0:
		update_timer = reveal_update_interval
		_update_vision()

func _update_vision() -> void:
	if not get_parent():
		return
	
	# Get fog of war system
	var fog_system = get_tree().get_first_node_in_group("FogOfWar") 
	if not fog_system:
		return
	
	# Reveal area around hero
	fog_system.reveal_area(global_position, vision_radius)

func set_vision_radius(radius: float) -> void:
	vision_radius = radius
	
	# Update collision shape
	if has_node("CollisionShape2D"):
		var collision = get_node("CollisionShape2D")
		if collision.shape is CircleShape2D:
			collision.shape.radius = vision_radius
