extends Node2D
class_name FogOfWarSystem

@export var tile_size: int = 32
@export var fog_color: Color = Color(0, 0, 0, 0.85)
@export var world_size: Vector2 = Vector2(9200, 5185)
@export var world_offset: Vector2 = Vector2(0, 0)

var exploration_texture: ImageTexture
var exploration_image: Image
var grid_width: int
var grid_height: int
var fog_sprite: Sprite2D
var _camera: Camera2D = null

# Batch flag: any reveal_area() call that mutated pixels sets this. The actual
# GPU upload happens at most once per frame in _process(). This way 4 heroes
# revealing in the same frame cause ONE GPU upload, not four.
var _texture_dirty: bool = false

func _ready() -> void:
	# NOTE: Group "FogOfWar" is declared in FogOfWarSystem.tscn (`groups=["FogOfWar"]`),
	# so no add_to_group() call is needed here.
	grid_width = int(ceil(world_size.x / tile_size))
	grid_height = int(ceil(world_size.y / tile_size))

	exploration_image = Image.create(grid_width, grid_height, false, Image.FORMAT_R8)
	exploration_image.fill(Color.BLACK)

	exploration_texture = ImageTexture.create_from_image(exploration_image)

	_setup_fog_sprite()

func _process(_delta: float) -> void:
	# 1) Make the fog sprite track the visible viewport. This way the
	#    rendered quad is always viewport-sized, never a giant 7500×6000
	#    region. The shader still maps UVs to world space via MODEL_MATRIX.
	_update_fog_sprite_to_viewport()

	# 2) Batched GPU upload — one per frame at most, regardless of how many
	#    vision sources called reveal_area() this frame.
	if _texture_dirty:
		_texture_dirty = false
		exploration_texture.update(exploration_image)

func _update_fog_sprite_to_viewport() -> void:
	if not is_instance_valid(fog_sprite):
		return
	if not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_2d()
		if not is_instance_valid(_camera):
			return

	# Viewport size in world units = pixel size / zoom (Godot 4: zoom > 1 zooms in).
	var view_size_px: Vector2 = get_viewport_rect().size
	var view_size_world: Vector2 = view_size_px / _camera.zoom

	# Add a small margin so we don't see a hard edge at extreme camera moves.
	var margin: Vector2 = view_size_world * 0.05
	var fog_size: Vector2 = view_size_world + margin * 2.0

	# Top-left of visible area in world space.
	var top_left: Vector2 = _camera.global_position - view_size_world * 0.5 - margin

	fog_sprite.global_position = top_left
	fog_sprite.scale = fog_size

func _setup_fog_sprite() -> void:
	fog_sprite = Sprite2D.new()
	fog_sprite.name = "FogSprite"
	add_child(fog_sprite)

	# 1×1 white pixel — the shader writes COLOR directly and never samples
	# this texture. The sprite is purely a quad we move/scale to follow the
	# camera. Initial scale is just 1; _update_fog_sprite_to_viewport()
	# resizes it every frame.
	var canvas_image: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	canvas_image.fill(Color.WHITE)
	var canvas_texture: ImageTexture = ImageTexture.create_from_image(canvas_image)

	fog_sprite.texture = canvas_texture
	fog_sprite.centered = false
	fog_sprite.position = world_offset
	fog_sprite.scale = Vector2.ONE
	fog_sprite.z_index = 100

	var shader = load("res://Scenes/World/FogOfWar/fog_of_war.gdshader")
	var materials = ShaderMaterial.new()
	materials.shader = shader

	# Only world_offset + world_size matter to the new shader (it reads
	# world_pos via MODEL_MATRIX in vertex and divides by world_size for
	# the exploration_map UV). Other uniforms kept for compat.
	materials.set_shader_parameter("exploration_map", exploration_texture)
	materials.set_shader_parameter("fog_color", fog_color)
	materials.set_shader_parameter("tile_size", tile_size)
	materials.set_shader_parameter("world_offset", world_offset)
	materials.set_shader_parameter("grid_size", Vector2(grid_width, grid_height))
	materials.set_shader_parameter("world_size", world_size)

	fog_sprite.material = materials

func reveal_area(world_position: Vector2, radius: float) -> void:
	var grid_x: int = int((world_position.x - world_offset.x) / tile_size)
	var grid_y: int = int((world_position.y - world_offset.y) / tile_size)

	if grid_x < 0 or grid_x >= grid_width or grid_y < 0 or grid_y >= grid_height:
		return

	var tile_radius: int = int(radius / tile_size)
	var radius_sq: float = radius * radius
	var ts: int = tile_size
	var dirty_local: bool = false

	var x_start: int = maxi(grid_x - tile_radius, 0)
	var x_end: int = mini(grid_x + tile_radius + 1, grid_width)
	var y_start: int = maxi(grid_y - tile_radius, 0)
	var y_end: int = mini(grid_y + tile_radius + 1, grid_height)

	for x in range(x_start, x_end):
		var dx: int = (x - grid_x) * ts
		var dx_sq: int = dx * dx
		for y in range(y_start, y_end):
			var dy: int = (y - grid_y) * ts
			if float(dx_sq + dy * dy) <= radius_sq:
				if exploration_image.get_pixel(x, y).r < 0.5:
					exploration_image.set_pixel(x, y, Color.WHITE)
					dirty_local = true

	# Just flag — the actual GPU upload happens at most once per frame in _process().
	if dirty_local:
		_texture_dirty = true

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
	_texture_dirty = true

func reset_fog() -> void:
	exploration_image.fill(Color.BLACK)
	_texture_dirty = true

func save_exploration_state() -> PackedByteArray:
	return exploration_image.get_data()

func load_exploration_state(data: PackedByteArray) -> void:
	var loaded_image = Image.create_from_data(grid_width, grid_height, false, Image.FORMAT_R8, data)
	if loaded_image:
		exploration_image = loaded_image
		_texture_dirty = true
