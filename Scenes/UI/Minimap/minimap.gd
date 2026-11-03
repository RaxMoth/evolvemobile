class_name Minimap
extends Control

## Minimap — fog exploration map + entity dots, refreshed at refresh_hz.
## The FogOfWarSystem's R8 exploration texture is drawn by %FogView through
## minimap_fog.gdshader; this Control draws the dots and the camera frame.
##
## Fairness: the hero side only sees the monster while it is inside a hero's
## vision radius; the monster side only sees heroes inside its own vision.
## Tapping the map focuses the camera on the hero closest to that point.

@export var refresh_hz: float = 4.0
@export var hero_color: Color = Color(0.35, 0.85, 1.0)
@export var pet_color: Color = Color(0.7, 0.9, 1.0, 0.8)
@export var monster_color: Color = Color(1.0, 0.35, 0.3)
@export var frame_color: Color = Color(1.0, 1.0, 1.0, 0.55)
## Monster-side vision radius used to decide which heroes it can see while
## the monster has no VisionArea (World gives it one, sized by World's
## monster_vision_radius, once it stands at its match spawn).
@export var monster_vision_radius: float = 350.0

@onready var fog_view: TextureRect = %FogView

var _world_offset: Vector2 = Vector2.ZERO
var _world_size: Vector2 = Vector2(7500, 6000)
var _fog: Node = null
var _timer: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bind_fog()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = 1.0 / maxf(1.0, refresh_hz)
		if _fog == null or not is_instance_valid(_fog):
			_bind_fog()
		queue_redraw()


func _bind_fog() -> void:
	_fog = EntityRegistry.singleton(&"FogOfWar")
	if _fog == null:
		return
	set_world_bounds(_fog.get("world_offset"), _fog.get("world_size"))
	var tex: Texture2D = _fog.get("exploration_texture")
	if fog_view and tex:
		fog_view.texture = tex


func set_world_bounds(offset: Vector2, world_size: Vector2) -> void:
	_world_offset = offset
	_world_size = world_size


# ---------- mapping ----------

func world_to_map(world_pos: Vector2) -> Vector2:
	var n := (world_pos - _world_offset) / _world_size
	return Vector2(clampf(n.x, 0.0, 1.0) * size.x, clampf(n.y, 0.0, 1.0) * size.y)


func map_to_world(local_pos: Vector2) -> Vector2:
	var n := Vector2(local_pos.x / maxf(size.x, 1.0), local_pos.y / maxf(size.y, 1.0))
	return _world_offset + Vector2(clampf(n.x, 0.0, 1.0), clampf(n.y, 0.0, 1.0)) * _world_size


# ---------- visibility rules ----------
# Both read the viewer's VisionArea radius, i.e. exactly what clears the fog
# around it (heroes: HeroStats, applied by HeroBase._ready).

func monster_visible_to_heroes(monster_pos: Vector2) -> bool:
	for h in EntityRegistry.heroes:
		if is_instance_valid(h) and _sees(h, monster_pos, 0.0):
			return true
	return false


func hero_visible_to_monster(hero_pos: Vector2) -> bool:
	for m in EntityRegistry.monsters:
		if is_instance_valid(m) and _sees(m, hero_pos, monster_vision_radius):
			return true
	return false


## True when `pos` lies within the viewer's VisionArea radius, or within
## `fallback` when the viewer has no VisionArea.
func _sees(viewer: Node2D, pos: Vector2, fallback: float) -> bool:
	var vision := viewer.get_node_or_null(^"VisionArea") as VisionArea
	var r: float = vision.vision_radius if vision else fallback
	return viewer.global_position.distance_squared_to(pos) <= r * r


# ---------- drawing ----------

func _draw() -> void:
	var hero_side := GameManager.chosen_side == MatchRewards.Side.HEROES
	for h in EntityRegistry.hero_side:
		if not is_instance_valid(h):
			continue
		if not hero_side and not hero_visible_to_monster(h.global_position):
			continue
		var is_hero := h is HeroBase
		draw_circle(world_to_map(h.global_position), 3.0 if is_hero else 2.0, hero_color if is_hero else pet_color)
	for m in EntityRegistry.monsters:
		if not is_instance_valid(m):
			continue
		if hero_side and not monster_visible_to_heroes(m.global_position):
			continue
		draw_circle(world_to_map(m.global_position), 4.0, monster_color)
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("get_viewport_rect_in_world"):
		var r: Rect2 = cam.get_viewport_rect_in_world()
		var tl := world_to_map(r.position)
		var br := world_to_map(r.end)
		draw_rect(Rect2(tl, br - tl), frame_color, false, 1.0)


# ---------- input ----------

func _gui_input(event: InputEvent) -> void:
	var tapped := false
	var at := Vector2.ZERO
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		tapped = true
		at = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		tapped = true
		at = (event as InputEventMouseButton).position
	if not tapped:
		return
	accept_event()
	var world_pos := map_to_world(at)
	var best: Node2D = EntityRegistry.nearest(EntityRegistry.heroes, world_pos)
	if best == null:
		return
	var cam := get_viewport().get_camera_2d()
	if cam and "hero_ui" in cam and cam.get("hero_ui") != null:
		cam.get("hero_ui").select_hero(best)
	elif cam and cam.has_method("switch_to_hero"):
		cam.switch_to_hero(best)
