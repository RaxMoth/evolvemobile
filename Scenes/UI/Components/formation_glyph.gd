class_name FormationGlyph
extends Control

## A formation drawn as a picture (the pre-round's FormationTiles): four dots
## in the heroes' signature colours (UiPalette tokens), each with an ink rim
## and a soft highlight, placed as MatchConfig.Formation spaces the squad, under
## an amber arrow pointing where the squad walks. Procedural (_draw): no
## texture, and every colour comes from the palette.

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
	var centre := size * 0.5
	var half := minf(size.x, size.y) * 0.5
	var tip := centre + Vector2(0.0, -half * 0.95)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-8.0, 12.0), tip + Vector2(8.0, 12.0)]), palette.amber)
	var offsets: Array = OFFSETS[clampi(int(formation), 0, OFFSETS.size() - 1)]
	var highlight := Color(palette.text, HIGHLIGHT_ALPHA)
	for i in offsets.size():
		var p := centre + (offsets[i] as Vector2) * half * 1.6
		var token: StringName = dot_tokens[i] if i < dot_tokens.size() else &"hero"
		draw_circle(p, dot_radius + RIM, palette.ink)
		draw_circle(p, dot_radius, palette.color(token))
		draw_circle(p + Vector2(-2.5, -2.5), dot_radius * 0.35, highlight)
