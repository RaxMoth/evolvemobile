extends Camera2D
class_name GameCamera

## GameCamera — follows a Node2D, with smooth target-switching, zoom, shake,
## and a hook for the debug overlay.
##
## Hero selection: click a HeroPanel in the bottom UI, or press 1-4 to focus
## a hero by index, or Tab to cycle. The camera then tweens its follow_target
## to that hero with a brief easing — no instant snap.
##
## Visual debug overlay: F3 toggles on/off. The overlay is a sibling Node2D
## that draws entity AABBs, target lines, state labels, and threat info in
## world space. Replaces the print-spam debugging pattern.

# ============================================
# Exports
# ============================================

@export_group("Target Following")
@export var follow_target: Node2D
@export var follow_smoothing: float = 5.0
@export var follow_offset: Vector2 = Vector2.ZERO
## Duration of the easing tween when switching to a new hero. 0 = no tween
## (camera continues to use follow_smoothing toward the new target).
@export_range(0.0, 2.0) var switch_tween_duration: float = 0.4

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

# ============================================
# OnReady
# ============================================

@onready var hero_ui: HeroContainer = $CanvasLayer/HeroContainer as HeroContainer
@onready var debug_overlay: Node2D = get_node_or_null("CanvasLayer/DebugOverlay") as Node2D

# ============================================
# State
# ============================================

var is_shaking: bool = false
var shake_amount: float = 0.0
var shake_duration: float = 0.0

# Smooth follow tween — null when no switch is in progress.
var _switch_tween: Tween = null
# When true, _follow_target() is overridden by the active switch tween.
var _switching: bool = false


# ============================================
# Lifecycle
# ============================================

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

	# Hook hero-panel clicks → camera switch.
	if hero_ui:
		if not hero_ui.hero_selected.is_connected(_on_hero_selected):
			hero_ui.hero_selected.connect(_on_hero_selected)


func _process(delta: float) -> void:
	if debug_mode:
		_handle_debug_controls(delta)
	elif not _switching:
		_follow_target(delta)

	if is_shaking:
		_update_shake(delta)

	_handle_zoom_controls(delta)


# ============================================
# Following / target switching
# ============================================

func _follow_target(delta: float) -> void:
	if not follow_target or not is_instance_valid(follow_target):
		return
	var target_pos: Vector2 = follow_target.global_position + follow_offset
	if follow_smoothing > 0:
		global_position = global_position.lerp(target_pos, follow_smoothing * delta)
	else:
		global_position = target_pos


func set_follow_target(target: Node2D) -> void:
	"""Hard-set the follow target without easing. Use switch_to_hero() for
	the smooth-pan version."""
	follow_target = target


func switch_to_hero(hero: Node2D) -> void:
	"""Smoothly tween the camera onto a new follow target. Cancels any
	in-progress switch."""
	if not is_instance_valid(hero):
		return

	# Cancel any tween in progress.
	if _switch_tween and _switch_tween.is_valid():
		_switch_tween.kill()
		_switch_tween = null

	follow_target = hero

	if switch_tween_duration <= 0.0:
		# Caller asked for instant switch — just hand control back to _follow_target.
		_switching = false
		return

	# Tween global_position from current to the hero, easing out so the camera
	# decelerates as it arrives. Once done, _follow_target resumes per-frame.
	var target_pos: Vector2 = hero.global_position + follow_offset
	_switching = true
	_switch_tween = create_tween()
	_switch_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_switch_tween.tween_property(self, "global_position", target_pos, switch_tween_duration)
	_switch_tween.tween_callback(func(): _switching = false)


func _on_hero_selected(hero: Node) -> void:
	if hero is Node2D:
		switch_to_hero(hero)


func _auto_find_target() -> void:
	# Follow whoever the player is controlling (set by MainMenu).
	if GameManager.chosen_side == MatchRewards.Side.MONSTER:
		for m in get_tree().get_nodes_in_group("Monster"):
			if m is MonsterBase and is_instance_valid(m):
				follow_target = m
				return
	# Fallback / hero side: first live hero.
	for h in get_tree().get_nodes_in_group("Hero"):
		if h is HeroBase and is_instance_valid(h):
			follow_target = h
			return


# ============================================
# Input — hero cycling, debug toggle
# ============================================

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_camera_debug"):
		toggle_debug_mode()
	if event.is_action_pressed("reset_camera_zoom"):
		reset_zoom()
	if event.is_action_pressed("center_camera") and follow_target:
		center_on_position(follow_target.global_position, true)

	# Numeric hero focus + Tab to cycle. Routes through HeroContainer so the
	# panel highlight stays in sync.
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		match key:
			KEY_1, KEY_2, KEY_3, KEY_4:
				_focus_hero_by_index(key - KEY_1)
			KEY_TAB:
				if hero_ui:
					hero_ui.cycle_to_next_hero()
			KEY_F3:
				_toggle_debug_overlay()


func _focus_hero_by_index(idx: int) -> void:
	if not hero_ui:
		return
	if idx < 0 or idx >= hero_ui.panels.size():
		return
	var p := hero_ui.panels[idx]
	if is_instance_valid(p) and is_instance_valid(p.hero):
		hero_ui.select_hero(p.hero)


# ============================================
# Debug overlay toggle
# ============================================

func _toggle_debug_overlay() -> void:
	if not is_instance_valid(debug_overlay):
		return
	debug_overlay.visible = not debug_overlay.visible
	if debug_overlay.has_method("set_active"):
		debug_overlay.set_active(debug_overlay.visible)


# ============================================
# Camera tools — debug fly-cam, zoom, shake
# ============================================

func _handle_debug_controls(delta: float) -> void:
	var move_direction := Vector2.ZERO
	var speed := debug_move_speed

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
	debug_mode = not debug_mode


func _handle_zoom_controls(delta: float) -> void:
	var zoom_change: float = 0.0

	if Input.is_action_just_pressed("zoom_in"):
		zoom_change = zoom_speed
	elif Input.is_action_just_pressed("zoom_out"):
		zoom_change = -zoom_speed

	if Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_PLUS):
		zoom_change = zoom_speed * delta * 2
	if Input.is_key_pressed(KEY_MINUS):
		zoom_change = -zoom_speed * delta * 2

	if zoom_change != 0.0:
		var new_zoom: float = clamp(zoom.x + zoom_change, min_zoom, max_zoom)
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
		var tween := create_tween()
		tween.tween_property(self, "global_position", pos, 0.5)


func get_viewport_rect_in_world() -> Rect2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var world_size: Vector2 = viewport_size / zoom
	var top_left: Vector2 = global_position - world_size / 2
	return Rect2(top_left, world_size)
