class_name HpBar2D
extends Node2D

## In-world HP bar drawn by ONE Node2D (`_draw`) instead of the old
## Control > HBoxContainer > ProgressBar (+ Label) subtree per entity.
## Redraws only when a value changes; mobs set `hide_when_full` so idle camps
## draw nothing at all. Write through `set_values()` / EntityBase.set_hp_display().

@export var bar_size: Vector2 = Vector2(50, 6)
@export var bg_color: Color = Color(0.08, 0.08, 0.10, 0.85)
@export var fill_color: Color = Color(0.35, 0.85, 0.35, 1.0)
@export var border_color: Color = Color(0, 0, 0, 0.7)
## Hide the bar while value >= max_value (mobs: only show once damaged).
@export var hide_when_full: bool = false:
	set(v):
		hide_when_full = v
		_refresh()

var max_value: float = 100.0:
	set(v):
		max_value = maxf(v, 0.0)
		_refresh()

var value: float = 100.0:
	set(v):
		value = clampf(v, 0.0, max_value) if max_value > 0.0 else 0.0
		_refresh()


func set_values(current: float, maximum: float) -> void:
	max_value = maximum
	value = current


func ratio() -> float:
	return value / max_value if max_value > 0.0 else 0.0


func _refresh() -> void:
	visible = not (hide_when_full and value >= max_value)
	queue_redraw()


func _draw() -> void:
	var full := Rect2(Vector2.ZERO, bar_size)
	draw_rect(full, bg_color)
	var fill_w := bar_size.x * ratio()
	if fill_w > 0.0:
		draw_rect(Rect2(Vector2.ZERO, Vector2(fill_w, bar_size.y)), fill_color)
	draw_rect(full, border_color, false, 1.0)
