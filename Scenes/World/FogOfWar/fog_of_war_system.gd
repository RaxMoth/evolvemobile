extends Node2D
class_name FogOfWarSystem

@export var tile_size: int = 32
## The unexplored fog: a palette token (UiPalette, the warm near-black
## `bg_void`) at fog_alpha.
@export var fog_token: StringName = &"bg_void"
@export_range(0.0, 1.0) var fog_alpha: float = 0.85
## Snapped up to a whole number of tiles in _ready, so the exploration texture
## covers exactly this rectangle (the shader and the minimap both map by it).
@export var world_size: Vector2 = Vector2(9200, 5185)
@export var world_offset: Vector2 = Vector2(0, 0)
## How far the fog quad extends past the world on every side, so the camera
## never sees its edge. The GPU only shades on-screen fragments, so a large
## static quad costs the same as a viewport-sized one.
@export var fog_border: float = 8192.0

var exploration_texture: ImageTexture
## What the PLAYER has seen (drawn by the fog shader and the minimap).
var exploration_image: Image
## What the AI heroes have explored (is_tile_explored): their reveals land
## here even when they must not clear the player's fog (monster-side play),
## so the hero AI keeps a correct memory.
var _ai_image: Image
var grid_width: int
var grid_height: int
var fog_sprite: Sprite2D

# Batch flag: any reveal_area() call that mutated pixels sets this. The actual
# GPU upload happens at most once per frame in _process(). This way 4 heroes
# revealing in the same frame cause ONE GPU upload, not four.
var _texture_dirty: bool = false

func _ready() -> void:
	# NOTE: Group "FogOfWar" is declared in FogOfWarSystem.tscn (`groups=["FogOfWar"]`),
	# so no add_to_group() call is needed here.
	grid_width = maxi(1, ceili(world_size.x / tile_size))
	grid_height = maxi(1, ceili(world_size.y / tile_size))
	# A world size that is not a whole number of tiles stretched the texture
	# over a slightly different rectangle than the tiles reveal_area() writes:
	# revealed squares sat up to a tile off and shimmered at texel edges.
	world_size = Vector2(grid_width, grid_height) * tile_size

	exploration_image = Image.create(grid_width, grid_height, false, Image.FORMAT_R8)
	exploration_image.fill(Color.BLACK)
	_ai_image = Image.create(grid_width, grid_height, false, Image.FORMAT_R8)
	_ai_image.fill(Color.BLACK)

	exploration_texture = ImageTexture.create_from_image(exploration_image)

	_setup_fog_sprite()

func _process(_delta: float) -> void:
	# Batched GPU upload: one per frame at most, regardless of how many vision
	# sources called reveal_area() this frame. The fog quad itself is static
	# (it used to chase the camera from _process, which ran a frame behind the
	# camera on some frames and flashed unfogged strips at the screen edge).
	if _texture_dirty:
		_texture_dirty = false
		exploration_texture.update(exploration_image)

## The fog's colour: fog_token at fog_alpha.
func fog_color() -> Color:
	var c := UiPalette.get_default().color(fog_token)
	c.a = fog_alpha
	return c


func _setup_fog_sprite() -> void:
	fog_sprite = Sprite2D.new()
	fog_sprite.name = "FogSprite"
	add_child(fog_sprite)

	# 1x1 white pixel: the shader writes COLOR directly and never samples this
	# texture. The sprite is one static quad covering the world plus fog_border.
	var canvas_image: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	canvas_image.fill(Color.WHITE)
	fog_sprite.texture = ImageTexture.create_from_image(canvas_image)
	fog_sprite.centered = false
	fog_sprite.position = world_offset - Vector2(fog_border, fog_border)
	fog_sprite.scale = world_size + Vector2(fog_border, fog_border) * 2.0
	fog_sprite.z_index = 100

	var fog_material := ShaderMaterial.new()
	fog_material.shader = load("res://Scenes/World/FogOfWar/fog_of_war.gdshader")
	fog_material.set_shader_parameter("exploration_map", exploration_texture)
	fog_material.set_shader_parameter("fog_color", fog_color())
	fog_material.set_shader_parameter("tile_size", float(tile_size))
	fog_material.set_shader_parameter("world_offset", world_offset)
	fog_material.set_shader_parameter("grid_size", Vector2(grid_width, grid_height))
	fog_sprite.material = fog_material

## The fog tile under world_position, the centre of a reveal_area() there.
## VisionArea keys its skip on it, so it must stay the same math.
func grid_cell(world_position: Vector2) -> Vector2i:
	# floori, not int(): int() truncates toward zero, so a point just left of
	# or above the map revealed column/row 0.
	return Vector2i(
		floori((world_position.x - world_offset.x) / tile_size),
		floori((world_position.y - world_offset.y) / tile_size))

## Reveals every tile whose centre offset from the source's tile lies within
## radius. Which tiles that is depends only on grid_cell(world_position), the
## radius and the two flags, and pixels only ever turn from fog to revealed.
func reveal_area(world_position: Vector2, radius: float, display: bool = true, memory: bool = true) -> void:
	var cell: Vector2i = grid_cell(world_position)
	var grid_x: int = cell.x
	var grid_y: int = cell.y

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
				if memory and _ai_image.get_pixel(x, y).r < 0.5:
					_ai_image.set_pixel(x, y, Color.WHITE)
				if display and exploration_image.get_pixel(x, y).r < 0.5:
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

	return _ai_image.get_pixel(grid_x, grid_y).r > 0.5


## True where the PLAYER's fog is cleared (the display image, not the AI
## heroes' memory that is_tile_explored reads). Outside the map is always
## fogged. Presentation only: the HUD asks it before it reports on an enemy.
func is_revealed(world_position: Vector2) -> bool:
	var cell: Vector2i = grid_cell(world_position)
	if cell.x < 0 or cell.x >= grid_width or cell.y < 0 or cell.y >= grid_height:
		return false
	return exploration_image.get_pixel(cell.x, cell.y).r > 0.5
