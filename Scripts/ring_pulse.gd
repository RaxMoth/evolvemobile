class_name RingPulse
extends Line2D

## One-shot expanding ring VFX: a circle outline that scales up and fades out
## (monster stage evolution, Irelia's taunt, River's supply-drop impact).
## Create it with `RingPulse.spawn(...)`; it frees itself.

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
	for i in range(SEGMENTS + 1):
		var angle: float = i * TAU / SEGMENTS
		ring.add_point(Vector2(cos(angle), sin(angle)) * start_radius)

	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE * end_scale, duration)
	tween.tween_property(ring, "modulate:a", 0.0, duration)
	tween.tween_callback(ring.queue_free)
	return ring
