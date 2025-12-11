extends Node2D
class_name FogOfWarSystem

signal area_revealed(position: Vector2)

@export var tile_size: int = 32
@export var fog_color: Color = Color(0, 0, 0, 0.85)
@export var world_size: Vector2 = Vector2(9200,5185)
@export var world_offset: Vector2 = Vector2(0, 0)

var exploration_texture: ImageTexture
var exploration_image: Image
var grid_width: int
var grid_height: int
var fog_sprite: Sprite2D

func _ready() -> void:
	add_to_group("FogOfWar")
	grid_width = int(ceil(world_size.x / tile_size))
	grid_height = int(ceil(world_size.y / tile_size))
	
	exploration_image = Image.create(grid_width, grid_height, false, Image.FORMAT_R8)
	exploration_image.fill(Color.BLACK)
	
	exploration_texture = ImageTexture.create_from_image(exploration_image)
	
	_setup_fog_sprite()

func _setup_fog_sprite() -> void:
	fog_sprite = Sprite2D.new()
	fog_sprite.name = "FogSprite"
	add_child(fog_sprite)
	
	# Create a white texture the size of your world
	var fog_texture_image = Image.create(int(world_size.x), int(world_size.y), false, Image.FORMAT_RGBA8)
	fog_texture_image.fill(Color.WHITE)
	var fog_texture = ImageTexture.create_from_image(fog_texture_image)
	
	fog_sprite.texture = fog_texture
	fog_sprite.centered = false  # Don't center, position from top-left
	fog_sprite.position = world_offset
	fog_sprite.z_index = 100  # Above everything else
	
	# Apply shader material
	var shader = load("res://Scenes/World/FogOfWar/fog_of_war.gdshader")
	var materials = ShaderMaterial.new()
	materials.shader = shader
	
	materials.set_shader_parameter("exploration_map", exploration_texture)
	materials.set_shader_parameter("fog_color", fog_color)
	materials.set_shader_parameter("tile_size", tile_size)
	materials.set_shader_parameter("world_offset", world_offset)
	materials.set_shader_parameter("grid_size", Vector2(grid_width, grid_height))
	materials.set_shader_parameter("world_size", world_size)
	
	fog_sprite.material = materials

func reveal_area(world_position: Vector2, radius: float) -> void:
	var grid_x = int((world_position.x - world_offset.x) / tile_size)
	var grid_y = int((world_position.y - world_offset.y) / tile_size)

	if grid_x < 0 or grid_x >= grid_width or grid_y < 0 or grid_y >= grid_height:
		return

	var tile_radius = int(radius / tile_size)
	var dirty = false

	for x in range(grid_x - tile_radius, grid_x + tile_radius + 1):
		for y in range(grid_y - tile_radius, grid_y + tile_radius + 1):
			
			if x < 0 or x >= grid_width or y < 0 or y >= grid_height:
				continue

			var dx = (x - grid_x) * tile_size
			var dy = (y - grid_y) * tile_size

			if dx * dx + dy * dy <= radius * radius:
				if exploration_image.get_pixel(x, y).r < 0.5:
					exploration_image.set_pixel(x, y, Color.WHITE)
					dirty = true

	if dirty:
		exploration_texture = ImageTexture.create_from_image(exploration_image)
		
		if fog_sprite and fog_sprite.material:
			fog_sprite.material.set_shader_parameter("exploration_map", exploration_texture)

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
	exploration_image.fill(Color.WHITE)
	exploration_texture = ImageTexture.create_from_image(exploration_image)
	if fog_sprite and fog_sprite.material:
		fog_sprite.material.set_shader_parameter("exploration_map", exploration_texture)

func reset_fog() -> void:
	exploration_image.fill(Color.BLACK)
	exploration_texture = ImageTexture.create_from_image(exploration_image)
	if fog_sprite and fog_sprite.material:
		fog_sprite.material.set_shader_parameter("exploration_map", exploration_texture)

func save_exploration_state() -> PackedByteArray:
	return exploration_image.get_data()

func load_exploration_state(data: PackedByteArray) -> void:
	var loaded_image = Image.create_from_data(grid_width, grid_height, false, Image.FORMAT_R8, data)
	if loaded_image:
		exploration_image = loaded_image
		exploration_texture = ImageTexture.create_from_image(exploration_image)
		if fog_sprite and fog_sprite.material:
			fog_sprite.material.set_shader_parameter("exploration_map", exploration_texture)
