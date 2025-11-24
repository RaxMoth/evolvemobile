extends Node2D
class_name FogOfWarSystemWorld

signal area_revealed(position: Vector2)

@export var tile_size: int = 32
@export var fog_color: Color = Color(0, 0, 0, 0.85)
@export var world_size: Vector2 = Vector2(2000, 2000)
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
	
	# Create a white texture that covers the world
	var white_image = Image.create(int(world_size.x), int(world_size.y), false, Image.FORMAT_RGBA8)
	white_image.fill(Color.WHITE)
	var white_texture = ImageTexture.create_from_image(white_image)
	fog_sprite.texture = white_texture
	
	# Position and center
	fog_sprite.position = world_offset + world_size / 2
	fog_sprite.centered = true
	fog_sprite.z_index = 100  # Above everything
	
	# Apply shader
	var shader = load("res://Scenes/World/FogOfWar/fog_of_war.gdshader")
	var material = ShaderMaterial.new()
	material.shader = shader
	
	material.set_shader_parameter("exploration_map", exploration_texture)
	material.set_shader_parameter("fog_color", fog_color)
	material.set_shader_parameter("tile_size", tile_size)
	material.set_shader_parameter("world_offset", world_offset)
	material.set_shader_parameter("grid_size", Vector2(grid_width, grid_height))
	material.set_shader_parameter("world_size", world_size)
	
	fog_sprite.material = material

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
