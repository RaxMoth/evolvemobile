class_name FormationGlyph
extends Control

## A formation drawn as a picture (the pre-round's FormationTiles): four dots
## in the heroes' signature colours (UiPalette tokens), each with an ink rim
## and a soft highlight, placed as MatchConfig.Formation spaces the squad, under
## an amber arrow pointing where the squad walks. The arrow has its own band
## (ARROW_BAND) along the top edge and the dots their field below it, so no
## formation's top dot hides the arrow. Procedural (_draw): no texture, and
## every colour comes from the palette.

## Unit offsets of the four dots from the centre, per MatchConfig.Formation:
## Tight, Spread, Line.
const OFFSETS := [
	[Vector2(0.0, -0.22), Vector2(-0.2, 0.0), Vector2(0.2, 0.0), Vector2(0.0, 0.22)],
	[Vector2(0.0, -0.4), Vector2(-0.38, 0.0), Vector2(0.38, 0.0), Vector2(0.0, 0.4)],
	[Vector2(-0.42, 0.1), Vector2(-0.14, 0.1), Vector2(0.14, 0.1), Vector2(0.42, 0.1)],
]
## Opacity of the highlight on each dot (palette text colour).
const HIGHLIGHT_ALPHA := 0.35
## Ink rim around each dot, in px.
const RIM := 3.0
## The heading arrow: its size (base width, height) and the band it takes at
## the top of the glyph (arrow plus a gap), above the dots' field.
const ARROW_SIZE := Vector2(16.0, 12.0)
const ARROW_BAND := 16.0
## How far the dots spread across the field, in units of its half size.
const SPREAD := 1.6

@export var formation: MatchConfig.Formation = MatchConfig.Formation.SPREAD:
	set(v):
		formation = v
		queue_redraw()
@export var dot_radius: float = 9.0:
	set(v):
		dot_radius = v
		queue_redraw()
## UiPalette tokens of the four dots, in squad order.
@export var dot_tokens: Array[StringName] = [&"irelia", &"vlad", &"ted", &"river"]:
	set(v):
		dot_tokens = v
		queue_redraw()


func _draw() -> void:
	var palette := UiPalette.get_default()
	draw_colored_polygon(arrow_points(size), palette.amber)
	var dots := dot_centres(size, formation)
	var highlight := Color(palette.text, HIGHLIGHT_ALPHA)
	for i in dots.size():
		var token: StringName = dot_tokens[i] if i < dot_tokens.size() else &"hero"
		draw_circle(dots[i], dot_radius + RIM, palette.ink)
		draw_circle(dots[i], dot_radius, palette.color(token))
		draw_circle(dots[i] + Vector2(-2.5, -2.5), dot_radius * 0.35, highlight)


## The heading arrow's corners (tip first) in a glyph of `glyph_size`:
## centred at the top, inside ARROW_BAND.
static func arrow_points(glyph_size: Vector2) -> PackedVector2Array:
	var tip := Vector2(glyph_size.x * 0.5, (ARROW_BAND - ARROW_SIZE.y) * 0.5)
	var half_w := ARROW_SIZE.x * 0.5
	return PackedVector2Array([tip, tip + Vector2(-half_w, ARROW_SIZE.y), tip + Vector2(half_w, ARROW_SIZE.y)])


## The four dot centres of `f` in a glyph of `glyph_size`: spread over the
## field under the arrow's band.
static func dot_centres(glyph_size: Vector2, f: MatchConfig.Formation) -> PackedVector2Array:
	var field := Vector2(glyph_size.x, maxf(glyph_size.y - ARROW_BAND, 0.0))
	var centre := Vector2(field.x * 0.5, ARROW_BAND + field.y * 0.5)
	var half := minf(field.x, field.y) * 0.5
	var out := PackedVector2Array()
	for offset: Vector2 in OFFSETS[clampi(int(f), 0, OFFSETS.size() - 1)]:
		out.append(centre + offset * half * SPREAD)
	return out
