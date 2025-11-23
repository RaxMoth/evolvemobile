extends Node2D
class_name FogOfWarSystem

## Fog of War System
## Manages fog tiles that cover unexplored areas
## Reveals areas when heroes get close with their vision

signal area_revealed(position: Vector2)
signal area_hidden(position: Vector2)

@export var tile_size: int = 64  # Size of each fog tile
@export var fog_color: Color = Color(0, 0, 0, 0.8)  # Dark fog
@export var revealed_permanently: bool = true  # Once revealed, stays revealed
@export var fog_texture: Texture2D  # Optional texture for fog

# Grid of fog tiles
var fog_grid: Dictionary = {}  # Key: Vector2i (grid_pos), Value: FogTile
var grid_bounds: Rect2i = Rect2i()

# Track which areas are explored
var explored_tiles: Dictionary = {}  # Key: Vector2i, Value: bool

func _ready() -> void:
	# Create fog tiles to cover the world
	_initialize_fog_grid()

func _initialize_fog_grid() -> void:
	# You'll need to call setup_fog_for_world() from outside with world bounds
	pass

## Call this from your world/level to set up fog coverage
func setup_fog_for_world(world_rect: Rect2) -> void:
	# Calculate grid bounds
	var min_x = int(floor(world_rect.position.x / tile_size))
	var min_y = int(floor(world_rect.position.y / tile_size))
	var max_x = int(ceil((world_rect.position.x + world_rect.size.x) / tile_size))
	var max_y = int(ceil((world_rect.position.y + world_rect.size.y) / tile_size))
	
	grid_bounds = Rect2i(min_x, min_y, max_x - min_x, max_y - min_y)
	
	# Create fog tiles for entire grid
	for x in range(min_x, max_x):
		for y in range(min_y, max_y):
			var grid_pos = Vector2i(x, y)
			_create_fog_tile(grid_pos)

func _create_fog_tile(grid_pos: Vector2i) -> void:
	var fog_tile = ColorRect.new()
	fog_tile.name = "FogTile_%d_%d" % [grid_pos.x, grid_pos.y]
	add_child(fog_tile)
	
	# Position and size
	fog_tile.position = Vector2(grid_pos.x * tile_size, grid_pos.y * tile_size)
	fog_tile.size = Vector2(tile_size, tile_size)
	fog_tile.color = fog_color
	fog_tile.z_index = 100  # Draw above everything
	
	# Store in grid
	fog_grid[grid_pos] = fog_tile
	explored_tiles[grid_pos] = false

## Check for hero vision and reveal tiles
func _process(_delta: float) -> void:
	if not revealed_permanently:
		# Re-fog areas not in vision
		_update_fog_visibility()

func reveal_area(world_position: Vector2, radius: float) -> void:
	# Convert world position to grid
	var center_grid = _world_to_grid(world_position)
	
	# Calculate how many tiles the radius covers
	var tile_radius = int(ceil(radius / tile_size))
	
	# Reveal tiles in radius
	for x in range(center_grid.x - tile_radius, center_grid.x + tile_radius + 1):
		for y in range(center_grid.y - tile_radius, center_grid.y + tile_radius + 1):
			var grid_pos = Vector2i(x, y)
			
			# Check if within actual radius
			var tile_center = _grid_to_world(grid_pos) + Vector2(tile_size / 2.0, tile_size / 2.0)
			if world_position.distance_to(tile_center) <= radius + (tile_size * 0.7):
				_reveal_tile(grid_pos)

func hide_area(world_position: Vector2, radius: float) -> void:
	if revealed_permanently:
		return  # Don't hide if permanent
	
	var center_grid = _world_to_grid(world_position)
	var tile_radius = int(ceil(radius / tile_size))
	
	for x in range(center_grid.x - tile_radius, center_grid.x + tile_radius + 1):
		for y in range(center_grid.y - tile_radius, center_grid.y + tile_radius + 1):
			var grid_pos = Vector2i(x, y)
			var tile_center = _grid_to_world(grid_pos) + Vector2(tile_size / 2.0, tile_size / 2.0)
			if world_position.distance_to(tile_center) <= radius + (tile_size * 0.7):
				_hide_tile(grid_pos)

func _reveal_tile(grid_pos: Vector2i) -> void:
	if not fog_grid.has(grid_pos):
		return
	
	var fog_tile = fog_grid[grid_pos]
	
	if fog_tile.visible:
		# Fade out animation
		var tween = create_tween()
		tween.tween_property(fog_tile, "modulate:a", 0.0, 0.5)
		tween.tween_callback(func(): fog_tile.visible = false)
		
		explored_tiles[grid_pos] = true
		area_revealed.emit(_grid_to_world(grid_pos))

func _hide_tile(grid_pos: Vector2i) -> void:
	if not fog_grid.has(grid_pos):
		return
	
	var fog_tile = fog_grid[grid_pos]
	
	if not fog_tile.visible:
		fog_tile.visible = true
		fog_tile.modulate.a = 0.0
		
		# Fade in
		var tween = create_tween()
		tween.tween_property(fog_tile, "modulate:a", fog_color.a, 0.5)
		
		area_hidden.emit(_grid_to_world(grid_pos))

func _update_fog_visibility() -> void:
	# Find all heroes with vision
	var heroes = get_tree().get_nodes_in_group("Hero")
	
	# First, hide all tiles
	for grid_pos in fog_grid.keys():
		if explored_tiles.get(grid_pos, false):
			_hide_tile(grid_pos)
	
	# Then reveal based on current vision
	for hero in heroes:
		if hero.has_method("is_alive") and hero.is_alive():
			if hero.has_node("VisionArea"):
				var vision_area = hero.get_node("VisionArea")
				if "vision_radius" in vision_area:
					reveal_area(hero.global_position, vision_area.vision_radius)

func is_tile_explored(world_position: Vector2) -> bool:
	var grid_pos = _world_to_grid(world_position)
	return explored_tiles.get(grid_pos, false)

func get_exploration_percentage() -> float:
	if explored_tiles.is_empty():
		return 0.0
	
	var total = explored_tiles.size()
	var explored = 0
	
	for is_explored in explored_tiles.values():
		if is_explored:
			explored += 1
	
	return (float(explored) / float(total)) * 100.0

func clear_fog() -> void:
	# Reveal entire map (cheat/debug)
	for grid_pos in fog_grid.keys():
		_reveal_tile(grid_pos)

func reset_fog() -> void:
	# Hide entire map
	for grid_pos in fog_grid.keys():
		var fog_tile = fog_grid[grid_pos]
		fog_tile.visible = true
		fog_tile.modulate.a = fog_color.a
		explored_tiles[grid_pos] = false

# Utility functions
func _world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / tile_size)),
		int(floor(world_pos.y / tile_size))
	)

func _grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x * tile_size, grid_pos.y * tile_size)
