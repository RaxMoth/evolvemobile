extends Camera2D
class_name GameCamera

@export_group("Target Following")
@export var follow_target: Node2D 
@export var follow_smoothing: float = 5.0
@export var follow_offset: Vector2 = Vector2.ZERO

@export_group("Debug Mode")
@export var debug_mode: bool = false 
@export var debug_move_speed: float = 500.0 
@export var debug_fast_move_multiplier: float = 3.0 

@export_group("Zoom")
@export var min_zoom: float = 0.5
@export var max_zoom: float = 3.0
@export var zoom_speed: float = 0.1
@export var default_zoom: float = 1.0

@export_group("Camera Limits")
@export var enable_limits: bool = false
@export var limit_left_value: int = -10000
@export var limit_top_value: int = -10000
@export var limit_right_value: int = 10000
@export var limit_bottom_value: int = 10000

@export_group("Screen Shake")
@export var shake_enabled: bool = true
@onready var hero_ui: Control = %HeroContainer

var is_shaking: bool = false
var shake_amount: float = 0.0
var shake_duration: float = 0.0

func _ready() -> void:
	enabled = true
	zoom = Vector2(default_zoom, default_zoom)

	if enable_limits:
		limit_left = limit_left_value
		limit_top = limit_top_value
		limit_right = limit_right_value
		limit_bottom = limit_bottom_value
	
	if not follow_target:
		_auto_find_target()
	
	# Get reference to hero UI
	if has_node("CanvasLayer/HeroContainer"):
		hero_ui = $CanvasLayer/HeroContainer

func _process(delta: float) -> void:
	if debug_mode:
		_handle_debug_controls(delta)
	else:
		_follow_target(delta)
	
	if is_shaking:
		_update_shake(delta)
	
	_handle_zoom_controls(delta)

func _follow_target(delta: float) -> void:
	if not follow_target or not is_instance_valid(follow_target):
		return
	
	var target_pos = follow_target.global_position + follow_offset
	
	if follow_smoothing > 0:
		global_position = global_position.lerp(target_pos, follow_smoothing * delta)
	else:
		global_position = target_pos

func set_follow_target(target: Node2D) -> void:
	follow_target = target
	if target:
		print("Camera now following: " + target.name)

func _auto_find_target() -> void:
	var heroes = get_tree().get_nodes_in_group("Hero")
	if heroes.size() > 0:
		follow_target = heroes[0]
		print("Camera auto-found target: " + follow_target.name)

func _handle_debug_controls(delta: float) -> void:
	var move_direction = Vector2.ZERO
	var speed = debug_move_speed
	
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= debug_fast_move_multiplier
	
	if Input.is_key_pressed(KEY_UP):
		move_direction.y -= 1
	if Input.is_key_pressed(KEY_DOWN):
		move_direction.y += 1
	if Input.is_key_pressed(KEY_LEFT):
		move_direction.x -= 1
	if Input.is_key_pressed(KEY_RIGHT):
		move_direction.x += 1
	
	if move_direction != Vector2.ZERO:
		move_direction = move_direction.normalized()
		global_position += move_direction * speed * delta

func toggle_debug_mode() -> void:
	debug_mode = !debug_mode
	if debug_mode:
		print("Camera Debug Mode: ON (Use arrow keys to move)")
	else:
		print("Camera Debug Mode: OFF (Following target)")

func _handle_zoom_controls(delta: float) -> void:
	var zoom_change = 0.0
	
	if Input.is_action_just_pressed("zoom_in"):
		zoom_change = zoom_speed
	elif Input.is_action_just_pressed("zoom_out"):
		zoom_change = -zoom_speed
	
	if Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_PLUS):
		zoom_change = zoom_speed * delta * 2
	if Input.is_key_pressed(KEY_MINUS):
		zoom_change = -zoom_speed * delta * 2
	
	if zoom_change != 0:
		var new_zoom = zoom.x + zoom_change
		new_zoom = clamp(new_zoom, min_zoom, max_zoom)
		zoom = Vector2(new_zoom, new_zoom)

func set_zoom_level(level: float) -> void:
	level = clamp(level, min_zoom, max_zoom)
	zoom = Vector2(level, level)

func reset_zoom() -> void:
	zoom = Vector2(default_zoom, default_zoom)

func shake(amount: float, duration: float) -> void:
	if not shake_enabled:
		return
	
	shake_amount = amount
	shake_duration = duration
	is_shaking = true

func _update_shake(delta: float) -> void:
	if shake_duration > 0:
		shake_duration -= delta

		offset = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
	else:
		is_shaking = false
		offset = Vector2.ZERO

func center_on_position(pos: Vector2, instant: bool = false) -> void:
	if instant:
		global_position = pos
	else:
		var tween = create_tween()
		tween.tween_property(self, "global_position", pos, 0.5)

func get_viewport_rect_in_world() -> Rect2:
	var viewport_size = get_viewport_rect().size
	var world_size = viewport_size / zoom
	var top_left = global_position - world_size / 2
	return Rect2(top_left, world_size)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_camera_debug"):
		toggle_debug_mode()
	
	if event.is_action_pressed("reset_camera_zoom"):
		reset_zoom()
	
	if event.is_action_pressed("center_camera") and follow_target:
		center_on_position(follow_target.global_position, true)
