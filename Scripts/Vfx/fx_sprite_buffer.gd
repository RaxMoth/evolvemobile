class_name FxSpriteBuffer
extends RefCounted

## Fixed ring of animated effect sprites (structure of arrays), drawn by the
## owner's _draw in one pass: impact stars, sparks, puffs (and, from Phase 7,
## slash crescents, stakes and "!" pops). It never grows: every array is sized
## once in _init, and a spawn into a full ring overwrites the oldest sprite.
## No allocation per spawn or per frame.

enum Anim {
	POP,   ## overshoot in (0 -> 1.2 -> 1), hold, shrink + fade over the last 35%
	GROW,  ## eases from size_a to size_b, fades over the second half (puffs, rings)
	HOLD,  ## quick pop in, hold, fade over the last 0.15 s (marks, badges)
	RISE,  ## scale.y springs up from the ground, sinks over the last 0.22 s (stakes)
	FLY,   ## constant size, fades over the last 30% (thrown props)
	SWEEP, ## slash: grows along x while spinning, thins and fades (weapon swing)
}

var capacity: int = 0
## Sprites alive or waiting on their delay (never above capacity).
var live: int = 0
var tex: Array[Texture2D] = []
var pos := PackedVector2Array()
var vel := PackedVector2Array()
var grav := PackedFloat32Array()
var drag := PackedFloat32Array()
var rot := PackedFloat32Array()
var spin := PackedFloat32Array()
var size_a := PackedFloat32Array()
var size_b := PackedFloat32Array()
var col := PackedColorArray()
var age := PackedFloat32Array()
var life := PackedFloat32Array()
var delay := PackedFloat32Array()
var anim := PackedInt32Array()
var flip := PackedFloat32Array()
## Instance id of a node the sprite rides on (pos is then an offset), 0 = world.
var follow := PackedInt64Array()
## Free grouping key (e.g. the cage a stake belongs to), 0 = none.
var tag := PackedInt64Array()
var _next: int = 0


func _init(n: int) -> void:
	capacity = n
	tex.resize(n)
	pos.resize(n)
	vel.resize(n)
	grav.resize(n)
	drag.resize(n)
	rot.resize(n)
	spin.resize(n)
	size_a.resize(n)
	size_b.resize(n)
	col.resize(n)
	age.resize(n)
	life.resize(n)
	delay.resize(n)
	anim.resize(n)
	flip.resize(n)
	follow.resize(n)
	tag.resize(n)


## Starts a sprite and returns its slot (set vel/grav/drag/spin/follow/tag on
## it afterwards). Sizes are world px along the texture's longest side. The
## slot is the oldest one: a full ring recycles its oldest sprite.
func spawn(t: Texture2D, p: Vector2, a: float, b: float, life_s: float, c: Color,
		kind: Anim = Anim.POP, angle: float = 0.0, wait: float = 0.0) -> int:
	var i: int = _next
	_next = (_next + 1) % capacity
	if tex[i] == null:
		live += 1
	tex[i] = t
	pos[i] = p
	vel[i] = Vector2.ZERO
	grav[i] = 0.0
	drag[i] = 0.0
	rot[i] = angle
	spin[i] = 0.0
	size_a[i] = a
	size_b[i] = b
	col[i] = c
	age[i] = 0.0
	life[i] = maxf(life_s, 0.01)
	delay[i] = wait
	anim[i] = kind
	flip[i] = 1.0
	follow[i] = 0
	tag[i] = 0
	return i


## Ends every sprite with this tag after `tail` more seconds (RISE sinks).
func end_tag(key: int, tail: float) -> void:
	for i in capacity:
		if tex[i] != null and tag[i] == key:
			life[i] = minf(life[i], age[i] + tail)


func clear() -> void:
	for i in capacity:
		tex[i] = null
	live = 0


func step(delta: float) -> void:
	if live == 0:
		return
	live = 0
	for i in capacity:
		if tex[i] == null:
			continue
		if delay[i] > 0.0:
			delay[i] -= delta
			live += 1
			continue
		age[i] += delta
		if age[i] >= life[i]:
			tex[i] = null
			continue
		var v: Vector2 = vel[i]
		if drag[i] > 0.0:
			v *= maxf(0.0, 1.0 - drag[i] * delta)
		v.y += grav[i] * delta
		vel[i] = v
		pos[i] += v * delta
		rot[i] += spin[i] * delta
		live += 1


func draw(ci: CanvasItem) -> void:
	if live == 0:
		return
	for i in capacity:
		var t: Texture2D = tex[i]
		if t == null or delay[i] > 0.0:
			continue
		var p: Vector2 = pos[i]
		if follow[i] != 0:
			var host := instance_from_id(follow[i]) as Node2D
			if host == null or not host.is_inside_tree():
				continue
			p += host.global_position
		var k: float = age[i] / life[i]
		var sx: float = 1.0
		var sy: float = 1.0
		var a: float = 1.0
		var sz: float = size_a[i]
		match anim[i]:
			Anim.POP:
				var e: float = FxEase.pop(minf(age[i] / 0.14, 1.0))
				sx = e
				sy = e
				if k > 0.65:
					var f: float = (k - 0.65) / 0.35
					sx *= 1.0 - 0.4 * f
					sy = sx
					a = 1.0 - f
				sz = lerpf(size_a[i], size_b[i], k)
			Anim.GROW:
				sz = lerpf(size_a[i], size_b[i], FxEase.out_cubic(k))
				a = 1.0 if k < 0.35 else 1.0 - (k - 0.35) / 0.65
			Anim.HOLD:
				var e2: float = FxEase.pop(minf(age[i] / 0.12, 1.0))
				sx = e2
				sy = e2
				var left: float = life[i] - age[i]
				if left < 0.15:
					a = left / 0.15
				p.y += sin(age[i] * 9.0) * 1.5   # alive: a little bob
			Anim.RISE:
				sy = FxEase.pop(minf(age[i] / 0.2, 1.0))
				var left2: float = life[i] - age[i]
				if left2 < 0.22:
					sy *= left2 / 0.22
			Anim.FLY:
				if k > 0.7:
					a = 1.0 - (k - 0.7) / 0.3
			Anim.SWEEP:
				sx = 0.55 + 0.6 * FxEase.out_cubic(minf(k / 0.5, 1.0))
				sy = 1.0 - 0.45 * k
				a = 1.0 if k < 0.55 else 1.0 - (k - 0.55) / 0.45
		var ts: Vector2 = t.get_size()
		var sc: float = sz / maxf(ts.x, ts.y)
		var c: Color = col[i]
		c.a *= a
		ci.draw_set_transform(p, rot[i], Vector2(sc * sx * flip[i], sc * sy))
		if anim[i] == Anim.RISE:
			ci.draw_texture(t, Vector2(-ts.x * 0.5, -ts.y), c)   # pivot at the foot
		else:
			ci.draw_texture(t, -ts * 0.5, c)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
