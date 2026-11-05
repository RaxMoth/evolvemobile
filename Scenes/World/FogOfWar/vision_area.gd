extends Area2D
class_name VisionArea

@export var vision_radius: float = 200.0
@export var reveal_update_interval: float = 0.7
## False for the AI side's vision when the player plays the other side: it
## still feeds the AI's exploration memory but never clears the player's fog.
@export var reveals_display: bool = true
## False for the monster player's own vision: it clears the player's fog but
## must not count as "explored by the AI heroes" (that steered the heroes away
## from wherever the monster had been).
@export var feeds_ai_memory: bool = true

var update_timer: float = 0.0

# The last reveal's key. reveal_area() writes only by the fog tile, the radius
# and the two flags, and pixels only ever turn from fog to revealed, so the same
# key again (a hero in a fight, a resting monster) would reveal nothing new.
# Fog id 0 is no instance: the first reveal always runs.
var _last_fog_id: int = 0
var _last_cell: Vector2i = Vector2i.ZERO
var _last_radius: float = 0.0
var _last_display: bool = false
var _last_memory: bool = false

func _ready() -> void:
	# CollisionShape2D + Area2D collision flags (layer 0, mask 0, monitoring
	# off, monitorable off) are all declared in VisionArea.tscn. We just
	# sync the shape's radius to the @export vision_radius. set_vision_radius
	# overrides it per entity: HeroBase._ready from HeroStats, and
	# FogOfWarHelper.add_vision_to_hero for the monster player.
	_sync_shape_radius()

func _process(delta: float) -> void:
	update_timer -= delta

	if update_timer <= 0.0:
		update_timer = reveal_update_interval
		_update_vision()

func _update_vision() -> void:
	if not get_parent():
		return

	var fog := EntityRegistry.singleton(&"FogOfWar") as FogOfWarSystem
	if not fog:
		return

	var fog_id: int = fog.get_instance_id()
	var cell: Vector2i = fog.grid_cell(global_position)
	if fog_id == _last_fog_id and cell == _last_cell and vision_radius == _last_radius \
			and reveals_display == _last_display and feeds_ai_memory == _last_memory:
		return
	_last_fog_id = fog_id
	_last_cell = cell
	_last_radius = vision_radius
	_last_display = reveals_display
	_last_memory = feeds_ai_memory

	# Reveal area around hero
	fog.reveal_area(global_position, vision_radius, reveals_display, feeds_ai_memory)

func set_vision_radius(radius: float) -> void:
	vision_radius = radius
	_sync_shape_radius()

func _sync_shape_radius() -> void:
	var collision := get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if collision and collision.shape is CircleShape2D:
		(collision.shape as CircleShape2D).radius = vision_radius
