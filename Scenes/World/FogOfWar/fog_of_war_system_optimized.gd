extends CanvasLayer
class_name FogOfWarSystemOptimized

## Optimized Fog of War using shader and texture
## Much better performance than individual ColorRect tiles

signal area_revealed(position: Vector2)

@export var tile_size: int = 32  # Smaller tiles for more detail
@export var fog_color: Color = Color(0, 0, 0, 0.85)
@export var world_size: Vector2 = Vector2(2000, 2000)
@export var world_offset: Vector2 = Vector2(0, 0)
@export var reveal_smoothness: float = 1.5  # Smooth reveal radius multiplier

var exploration_texture: ImageTexture
var exploration_image: Image
var grid_width: int
var grid_height: int

@onready var fog_rect: ColorRect = $FogRect

func _ready() -> void:
	# Calculate grid size
	grid_width = int(ceil(world_size.x / tile_size))
	grid_height = int(ceil(world_size.y / tile_size))
	
	# Create exploration texture (black = unexplored, white = explored)
	exploration_image = Image.create(grid_width, grid_height, false, Image.FORMAT_R8)
	exploration_image.fill(Color.BLACK)  # Start all unexplored
	
	exploration_texture = ImageTexture.create_from_image(exploration_image)
	
	# Setup fog rect with shader
	_setup_fog_rect()

func _setup_fog_rect() -> void:
	if not fog_rect:
		fog_rect = ColorRect.new()
		fog_rect.name = "FogRect"
		add_child(fog_rect)
	
	# Load shader
	var shader = load("res://Scenes/World/FogOfWar/fog_of_war.gdshader")
	var material = ShaderMaterial.new()
	material.shader = shader
	
	# Set shader parameters
	material.set_shader_parameter("exploration_map", exploration_texture)
	material.set_shader_parameter("fog_color", fog_color)
	material.set_shader_parameter("tile_size", tile_size)
	material.set_shader_parameter("world_offset", world_offset)
	
	fog_rect.material = material
	
	# Cover entire world
	fog_rect.position = world_offset
	fog_rect.size = world_size
	fog_rect.z_index = 100

func reveal_area(world_position: Vector2, radius: float) -> void:
	# Convert world position to grid coordinates
	var grid_x = int(floor((world_position.x - world_offset.x) / tile_size))
	var grid_y = int(floor((world_position.y - world_offset.y) / tile_size))
	
	# Calculate tile radius
	var tile_radius = int(ceil(radius / tile_size * reveal_smoothness))
	
	var any_revealed = false
	
	# Reveal tiles in circular area
	for x in range(grid_x - tile_radius, grid_x + tile_radius + 1):
		for y in range(grid_y - tile_radius, grid_y + tile_radius + 1):
			# Check bounds
			if x < 0 or x >= grid_width or y < 0 or y >= grid_height:
				continue
			
			# Check if within circular radius
			var tile_center_x = (x + 0.5) * tile_size + world_offset.x
			var tile_center_y = (y + 0.5) * tile_size + world_offset.y
			var tile_center = Vector2(tile_center_x, tile_center_y)
			
			var distance = world_position.distance_to(tile_center)
			if distance <= radius * reveal_smoothness:
				# Check if tile was previously unexplored
				var current_value = exploration_image.get_pixel(x, y).r
				
				if current_value < 0.5:  # Was unexplored
					exploration_image.set_pixel(x, y, Color.WHITE)
					any_revealed = true
					area_revealed.emit(Vector2(tile_center_x, tile_center_y))
	
	# Update texture if anything changed
	if any_revealed:
		exploration_texture.update(exploration_image)

func is_tile_explored(world_position: Vector2) -> bool:
	var grid_x = int(floor((world_position.x - world_offset.x) / tile_size))
	var grid_y = int(floor((world_position.y - world_offset.y) / tile_size))
	
	if grid_x < 0 or grid_x >= grid_width or grid_y < 0 or grid_y >= grid_height:
		return false
	
	return exploration_image.get_pixel(grid_x, grid_y).r > 0.5

func get_exploration_percentage() -> float:
	var total_tiles = grid_width * grid_height
	var explored_tiles = 0
	
	for x in range(grid_width):
		for y in range(grid_height):
			if exploration_image.get_pixel(x, y).r > 0.5:
				explored_tiles += 1
	
	return (float(explored_tiles) / float(total_tiles)) * 100.0

func clear_fog() -> void:
	# Reveal entire map
	exploration_image.fill(Color.WHITE)
	exploration_texture.update(exploration_image)

func reset_fog() -> void:
	# Hide entire map
	exploration_image.fill(Color.BLACK)
	exploration_texture.update(exploration_image)

func save_exploration_state() -> PackedByteArray:
	# Save the exploration state to bytes
	return exploration_image.get_data()

func load_exploration_state(data: PackedByteArray) -> void:
	# Restore exploration state from bytes
	var loaded_image = Image.create_from_data(grid_width, grid_height, false, Image.FORMAT_R8, data)
	if loaded_image:
		exploration_image = loaded_image
		exploration_texture.update(exploration_image)
