class_name HpBar2D
extends Node2D

## In-world HP bar drawn by ONE Node2D (`_draw`) instead of the old
## Control > HBoxContainer > ProgressBar (+ Label) subtree per entity.
## Redraws only when a value changes; mobs set `hide_when_full` so idle camps
## draw nothing at all. Write through `set_values()` / EntityBase.set_hp_display().
##
## Colours are palette tokens (UiPalette), resolved once in _ready: the
## trough is `panel_inset`, the outline `ink`, the fill `heal` for the hero
## side (the palette's "hero HP") and `danger` on the mob and monster scenes
## ("enemy HP", set scene-side on their base scenes).

@export var bar_size: Vector2 = Vector2(50, 6)
@export var fill_token: StringName = &"heal"
@export var bg_token: StringName = &"panel_inset"
@export var border_token: StringName = &"ink"
## The trough lets a little of the ground through; the fill is opaque.
@export_range(0.0, 1.0) var bg_alpha: float = 0.85
@export_range(0.0, 1.0) var border_alpha: float = 0.8

## Hide the bar while value >= max_value (mobs: only show once damaged).
@export var hide_when_full: bool = false:
	set(v):
		hide_when_full = v
		_refresh()

## The tokens' colours (_ready); magenta until then, like an unknown token.
var _fill_color: Color = Color.MAGENTA
var _bg_color: Color = Color.MAGENTA
var _border_color: Color = Color.MAGENTA

var max_value: float = 100.0:
	set(v):
		max_value = maxf(v, 0.0)
		_refresh()

var value: float = 100.0:
	set(v):
		value = clampf(v, 0.0, max_value) if max_value > 0.0 else 0.0
		_refresh()


func _ready() -> void:
	var palette := UiPalette.get_default()
	_fill_color = palette.color(fill_token)
	_bg_color = palette.color(bg_token)
	_bg_color.a = bg_alpha
	_border_color = palette.color(border_token)
	_border_color.a = border_alpha


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
	draw_rect(full, _bg_color)
	var fill_w := bar_size.x * ratio()
	if fill_w > 0.0:
		draw_rect(Rect2(Vector2.ZERO, Vector2(fill_w, bar_size.y)), _fill_color)
	draw_rect(full, _border_color, false, 1.0)
