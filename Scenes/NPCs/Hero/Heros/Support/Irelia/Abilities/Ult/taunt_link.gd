class_name TauntLink
extends Line2D

## Monster Taunt's red link from a taunted enemy to Irelia. A child of the
## enemy (in the TransientEffect group, so MobBase.prepare_for_pool scrubs it
## when a mob is pooled) but top_level, so its points are global positions:
## an evolved or Titan monster's root scale neither stretches the line past
## Irelia nor thickens it. Both ends are followed every frame. It frees itself
## when either end is gone, and fades out after the taunt's duration.
## Create it with `TauntLink.spawn(...)`.

const COLOR := Color(1.0, 0.3, 0.3, 0.6)
const WIDTH: float = 2.0
const FADE_TIME: float = 0.3

var _enemy: Node2D = null
var _caster: Node2D = null


static func spawn(enemy: Node2D, caster: Node2D, duration: float) -> TauntLink:
	var link := TauntLink.new()
	link._enemy = enemy
	link._caster = caster
	link.top_level = true
	link.z_index = 11
	link.default_color = COLOR
	link.width = WIDTH
	link.points = PackedVector2Array([enemy.global_position, caster.global_position])
	link.add_to_group(&"TransientEffect")  # scrubbed by MobBase.prepare_for_pool
	enemy.add_child(link)
	var tween := link.create_tween()
	tween.tween_interval(duration)
	tween.tween_property(link, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(link.queue_free)
	return link


func _process(_delta: float) -> void:
	if not is_instance_valid(_enemy) or not is_instance_valid(_caster):
		queue_free()
		return
	set_point_position(0, _enemy.global_position)
	set_point_position(1, _caster.global_position)
