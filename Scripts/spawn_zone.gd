@tool
class_name SpawnZone
extends Node2D

## SpawnZone - a visual, named, color-coded radius indicator.
##
## Used as a child of MobSpawnArea (and anything else that needs a "ring" of
## influence). Each zone OWNS its radius — designers can edit it in the
## inspector or via the tool draw, and the parent reads from it. This means
## one source of truth: the zone node.
##
## In-editor, draws a labeled outline so you can see all the spawn zones
## stacked at once. At runtime, drawing is off by default (no per-frame cost)
## but can be toggled on for debug.

@export var radius: float = 200.0:
	set(value):
		radius = max(0.0, value)
		queue_redraw()

@export var color: Color = Color(1.0, 0.85, 0.2, 0.9):
	set(value):
		color = value
		queue_redraw()

@export var label: String = "":
	set(value):
		label = value
		queue_redraw()

## Draw the outline at runtime (not just in editor). Default off — keeps
## the game clean. Flip to true for visual debugging.
@export var visible_in_game: bool = false:
	set(value):
		visible_in_game = value
		queue_redraw()

## Outline thickness. The fill is intentionally just a faint tint.
@export_range(0.5, 8.0) var line_width: float = 2.0:
	set(value):
		line_width = value
		queue_redraw()


func _ready() -> void:
	# Always queue a redraw so editor-time shape stays current.
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint() and not visible_in_game:
		return
	if radius <= 0.0:
		return

	# Outline ring.
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, color, line_width)

	# Faint fill so overlapping zones are still legible.
	var fill := Color(color.r, color.g, color.b, color.a * 0.08)
	draw_circle(Vector2.ZERO, radius, fill)

	# Label at the top of the circle.
	if not label.is_empty():
		var font := ThemeDB.fallback_font
		if font:
			var font_size := 12
			var text := "%s  (%d)" % [label, int(radius)]
			# Approximate text centering — fallback_font doesn't expose width
			# cheaply; close enough for a debug label.
			draw_string(font, Vector2(-text.length() * 3.0, -radius - 6.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


# ============================================
# Public API
# ============================================

## Is `world_pos` inside this zone? Uses global_position as the center.
func contains(world_pos: Vector2) -> bool:
	return global_position.distance_squared_to(world_pos) <= radius * radius

## Distance from this zone's center to `world_pos`. Cheap squared-distance
## variant available via `distance_squared_to` if you need it.
func distance_to(world_pos: Vector2) -> float:
	return global_position.distance_to(world_pos)
