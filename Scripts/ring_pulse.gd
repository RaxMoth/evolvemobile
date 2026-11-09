class_name RingPulse
extends Line2D

## Expanding ring VFX: a circle outline.
## - One-shot: `RingPulse.spawn(...)` scales it up and fades it out, then it
##   frees itself (monster stage evolution, Irelia's taunt, River's
##   supply-drop impact).
## - Pooled: `RingPulse.make_pooled(...)` builds a hidden ring once that its
##   owner shows, moves, scales and fades and never frees (VfxManager's ground
##   telegraphs).

const SEGMENTS: int = 32

## Adds a ring of `start_radius` at `pos` under `parent`, scaling to
## `end_scale` while fading out over `duration`.
## NOTE: kept from the per-ability copies this replaced: the free callback is
## parallel to the tweens, so it runs on the tween's first step and the ring
## is freed in the frame it spawns, before it is ever drawn.
static func spawn(parent: Node, pos: Vector2, color: Color, start_radius: float, end_scale: float, line_width: float, duration: float, z: int) -> RingPulse:
	var ring := RingPulse.new()
	parent.add_child(ring)
	ring.global_position = pos
	ring.z_index = z
	ring.default_color = color
	ring.width = line_width
	ring._add_circle(start_radius)

	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE * end_scale, duration)
	tween.tween_property(ring, "modulate:a", 0.0, duration)
	tween.tween_callback(ring.queue_free)
	return ring


## A hidden ring of `radius` for a pool: the owner adds it as a child and
## drives it (visible, position, scale, default_color, width); it never frees
## itself.
static func make_pooled(radius: float, line_width: float) -> RingPulse:
	var ring := RingPulse.new()
	ring.visible = false
	ring.width = line_width
	ring._add_circle(radius)
	return ring


func _add_circle(radius: float) -> void:
	for i in range(SEGMENTS + 1):
		var angle: float = i * TAU / SEGMENTS
		add_point(Vector2(cos(angle), sin(angle)) * radius)
