class_name VfxManager
extends Node2D

## VfxManager - the match's pooled hit feedback: for every damage packet that
## lands in view, an outlined cartoon impact star with sparks and a
## hand-lettered damage number (the fx_digits.svg glyph atlas); on a killing
## blow a puff burst, and camera trauma when a hero or the monster goes down
## or takes a heavy hit. telegraph() draws the ground warning of an ability
## that winds up (pooled RingPulse rings), and a running Night Swarm shows as a
## pooled ground ring that follows its caster at the swarm's radius, with a
## bite ring sweeping out once per bite (_on_ability_cast, _step_swarms). The
## per-ability looks come later (AbilityFxRecipe, Phase 7).
##
## A node of World.tscn (group "vfx", `camera` wired there), not an autoload:
## it lives and dies with the match. It sits right after the ground layers, so
## its telegraph rings (absolute z 0) draw on the ground under the characters,
## while its own sprites and numbers draw above them (z_index 50, below the
## fog's 100). Its hooks are EventBus.damage_applied and ability_cast,
## connected in _ready (an autoload cannot be the source of a scene
## [connection]). The hit flash is not drawn here: the CharacterRig's hurt
## reaction (wired scene-side to `damaged`) drives it, and the shared
## hit_flash shader on every rig body turns it into a white silhouette.
##
## Budget (the anim prototype measured 23 ms frames at p95): fixed pools
## (SPRITE_CAP sprites, NUMBER_CAP numbers, TELEGRAPH_CAP telegraphs,
## SWARM_CAP swarms; a full pool recycles its oldest entry), hits outside the
## camera view are skipped, at most MAX_HITS_PER_FRAME hits per frame spawn
## sprites, hits on one target within MERGE_WINDOW add up in one number and a
## target shows at most NUMBERS_PER_TARGET numbers. Nothing is allocated per frame. The F3 overlay
## shows the pools (debug_line()).
##
## DETERMINISM (tools/sim_trace.sh stays byte-identical): it never writes
## gameplay state (a swarm is only READ: is_active, time_left, the radius) and
## draws every random number from its private `_rng`.

const SPRITE_CAP: int = 64
const NUMBER_CAP: int = 32
const NUMBERS_PER_TARGET: int = 3
## Hits on one target closer together than this (s) add up in one number.
const MERGE_WINDOW: float = 0.15
const TELEGRAPH_CAP: int = 4
## Night Swarms shown at once (one per monster; a second covers a recast).
const SWARM_CAP: int = 2
## Alpha of a swarm's ground ring at full strength; it fades in and out over
## SWARM_FADE seconds.
const SWARM_ALPHA: float = 0.55
const SWARM_FADE: float = 0.25
## The bite ring sweeps from this share of the swarm's radius out to it.
const SWARM_BITE_FROM: float = 0.55
## Hits past this in one frame still count in the numbers but spawn no sprites.
const MAX_HITS_PER_FRAME: int = 8
const MAX_KILLS_PER_FRAME: int = 2
## World px around the camera view that still counts as in view.
const CULL_MARGIN: float = 64.0
const NUMBER_LIFE: float = 0.8
## Seconds of a number's pop (also after a merge adds to it).
const NUMBER_POP: float = 0.12
const SPARKS_PER_HIT: int = 2
## At most 6 puffs per effect (the Phase 7 toning-down rules).
const PUFFS_PER_KILL: int = 4
## Alpha of a ground telegraph's rings (the toning-down rules).
const TELEGRAPH_ALPHA: float = 0.35
## Longest value a number shows (digits).
const MAX_DIGITS: int = 9

## The match camera (World.tscn): kills and heavy hits add trauma to it.
@export var camera: GameCamera

@export_group("Damage numbers")
## On-screen glyph height (px) of a number at any zoom.
@export var number_px: float = 22.0
## On-screen glyph height (px) of a big hit's number.
@export var number_px_big: float = 30.0
## World px a number floats up over its life.
@export var number_rise: float = 18.0
## World px above the target's HP bar where a number starts.
@export var number_lift: float = 6.0
## World px a target's second number starts right of its first, its third
## left of it, so numbers close together in time do not overlap.
@export var number_spread: float = 16.0
## A hit of at least this much is big: a larger gold number, a bigger star and
## trauma when it hits a hero or the monster.
@export var big_hit: float = 30.0

@export_group("Screen shake (trauma)")
@export_range(0.0, 1.0) var trauma_big_hit: float = 0.12
@export_range(0.0, 1.0) var trauma_hero_down: float = 0.35
@export_range(0.0, 1.0) var trauma_monster_down: float = 0.6

@export_group("Telegraphs")
## Line width (world px) of a telegraph's rings at any radius (at most 3).
@export_range(0.5, 3.0) var telegraph_width: float = 2.0

@export_group("Swarm ring")
## Line width (world px) of a swarm's rings at any radius (at most 3).
@export_range(0.5, 3.0) var swarm_width: float = 3.0

## The impact stars, sparks and puffs.
var sprites := FxSpriteBuffer.new(SPRITE_CAP)

# F3 counters since the match began.
var hits_shown: int = 0
var hits_culled: int = 0
var hits_over_budget: int = 0

var _rng := RandomNumberGenerator.new()
var _view_rect := Rect2()
var _view_zoom: float = 1.0
var _hits_this_frame: int = 0
var _kills_this_frame: int = 0
## Hits on this group are the player's losses (red numbers and stars).
var _player_group: StringName = &"Hero"
var _drew: bool = false
var _cost_usec: int = 0

# Damage numbers: NUMBER_CAP slots (structure of arrays); a slot with
# age >= NUMBER_LIFE is free.
var _n_value := PackedFloat32Array()
var _n_age := PackedFloat32Array()
var _n_pop := PackedFloat32Array()
var _n_pos := PackedVector2Array()
var _n_target := PackedInt64Array()
var _n_ours := PackedByteArray()
var _n_next: int = 0
var _numbers_live: int = 0
var _digits := PackedInt32Array()
var _digit_cell := Vector2.ONE

# Telegraphs: an outline ring and a fill ring growing inside it per slot.
var _t_outline: Array[RingPulse] = []
var _t_fill: Array[RingPulse] = []
var _t_age := PackedFloat32Array()
var _t_life := PackedFloat32Array()
var _t_radius := PackedFloat32Array()
var _t_next: int = 0
var _telegraphs_live: int = 0

# Swarms: per slot the running ability (null = free), its caster's instance
# id, the seconds shown, an outline ring at the radius and a bite ring. The
# rings sit under _swarm_layer (built in _ready), drawn on the ground.
var _swarm_layer: Node2D = null
var _s_ability: Array[NightSwarm] = []
var _s_caster := PackedInt64Array()
var _s_age := PackedFloat32Array()
var _s_outline: Array[RingPulse] = []
var _s_bite: Array[RingPulse] = []
var _s_next: int = 0
var _swarms_live: int = 0

# Palette colours (UiPalette), read once.
var _c_number: Color
var _c_number_big: Color
var _c_ours: Color
var _c_star: Color
var _c_spark: Color
var _c_puff: Color
var _c_swarm: Color


func _ready() -> void:
	var palette := UiPalette.get_default()
	_c_number = palette.text
	_c_number_big = palette.gold
	_c_ours = palette.danger
	_c_star = palette.gold
	_c_spark = palette.text
	_c_puff = palette.parchment
	_c_swarm = palette.monster2_light
	_digit_cell = FxTex.digit_cell()
	_digits.resize(MAX_DIGITS)
	_n_value.resize(NUMBER_CAP)
	_n_age.resize(NUMBER_CAP)
	_n_age.fill(NUMBER_LIFE)
	_n_pop.resize(NUMBER_CAP)
	_n_pos.resize(NUMBER_CAP)
	_n_target.resize(NUMBER_CAP)
	_n_ours.resize(NUMBER_CAP)
	_t_age.resize(TELEGRAPH_CAP)
	_t_life.resize(TELEGRAPH_CAP)
	_t_radius.resize(TELEGRAPH_CAP)
	for i in TELEGRAPH_CAP:
		_t_outline.append(_make_ring(self, telegraph_width))
		_t_fill.append(_make_ring(self, telegraph_width))
	_swarm_layer = Node2D.new()
	_swarm_layer.name = "Swarms"
	add_child(_swarm_layer)
	_s_ability.resize(SWARM_CAP)
	_s_caster.resize(SWARM_CAP)
	_s_age.resize(SWARM_CAP)
	for i in SWARM_CAP:
		_s_outline.append(_make_ring(_swarm_layer, swarm_width))
		_s_bite.append(_make_ring(_swarm_layer, swarm_width))
	if GameManager.chosen_side == MatchRewards.Side.MONSTER:
		_player_group = &"Monster"
	_update_view()
	# Code-side: an autoload cannot be the source of a scene [connection].
	EventBus.damage_applied.connect(_on_damage_applied)
	EventBus.ability_cast.connect(_on_ability_cast)


## A unit-radius ring on the ground under `parent`: absolute z 0 (this node
## draws at 50), so it lands after the ground layers and under the characters.
func _make_ring(parent: Node, line_width: float) -> RingPulse:
	var ring := RingPulse.make_pooled(1.0, line_width)
	ring.z_as_relative = false
	ring.z_index = 0
	parent.add_child(ring)
	return ring


# ============================================
# Damage feedback
# ============================================

func _on_damage_applied(packet: DamagePacket) -> void:
	if packet == null or packet.amount <= 0.0 or not is_instance_valid(packet.target):
		return
	var target := packet.target as Node2D
	if target == null:
		return
	var entity := target as EntityBase
	show_hit(target, packet.amount, entity != null and not entity.is_alive())


## The feedback of one landed hit on `target`: an impact star with sparks and
## a damage number, and on a killing blow a puff burst; trauma when a hero or
## the monster goes down or takes a big hit. Skipped outside the camera view;
## past MAX_HITS_PER_FRAME only the number counts.
func show_hit(target: Node2D, amount: float, killed: bool = false) -> void:
	var at: Vector2 = target.global_position
	if not _view_rect.has_point(at):
		hits_culled += 1
		return
	hits_shown += 1
	var ours: bool = target.is_in_group(_player_group)
	var big: bool = amount >= big_hit
	var s: float = absf(target.scale.y)
	_add_number(target, _number_anchor(target), amount, ours)
	if _hits_this_frame < MAX_HITS_PER_FRAME:
		_hits_this_frame += 1
		_spawn_impact(at + Vector2(_rng.randf_range(-5.0, 5.0), _rng.randf_range(-16.0, -8.0)) * s, big, ours)
	else:
		hits_over_budget += 1
	if killed and _kills_this_frame < MAX_KILLS_PER_FRAME:
		_kills_this_frame += 1
		_spawn_kill(at + Vector2(0.0, -6.0 * s), 1.6 if target is MonsterBase else 1.0)
	_add_trauma(target, big, killed)


func _spawn_impact(p: Vector2, big: bool, ours: bool) -> void:
	var star: int = sprites.spawn(FxTex.STAR, p, 20.0 if big else 14.0, 10.0, 0.22,
			_c_ours if ours else _c_star, FxSpriteBuffer.Anim.POP, _rng.randf() * TAU)
	sprites.spin[star] = _rng.randf_range(-4.0, 4.0)
	for _k in SPARKS_PER_HIT:
		var sp: int = sprites.spawn(FxTex.SPARK, p, 7.0, 4.0, 0.24, _c_spark,
				FxSpriteBuffer.Anim.POP, _rng.randf() * TAU)
		sprites.vel[sp] = Vector2.from_angle(_rng.randf_range(-PI, 0.0)) * _rng.randf_range(40.0, 80.0)
		sprites.drag[sp] = 5.0


func _spawn_kill(p: Vector2, size_k: float) -> void:
	for k in PUFFS_PER_KILL:
		var a: float = TAU * float(k) / float(PUFFS_PER_KILL) + _rng.randf_range(-0.3, 0.3)
		var puff: int = sprites.spawn(FxTex.PUFF, p + Vector2.from_angle(a) * 6.0, 12.0 * size_k, 22.0 * size_k,
				0.5, _c_puff, FxSpriteBuffer.Anim.GROW, _rng.randf() * TAU)
		sprites.vel[puff] = Vector2.from_angle(a) * 34.0 * size_k + Vector2(0.0, -12.0)
		sprites.drag[puff] = 3.0
	var star: int = sprites.spawn(FxTex.STAR, p, 18.0 * size_k, 12.0 * size_k, 0.28, _c_spark,
			FxSpriteBuffer.Anim.POP, _rng.randf() * TAU)
	sprites.spin[star] = 3.0


func _add_trauma(target: Node2D, big: bool, killed: bool) -> void:
	if camera == null:
		return
	var hero: bool = target is HeroBase
	var monster: bool = target is MonsterBase
	if killed and monster:
		camera.add_trauma(trauma_monster_down)
	elif killed and hero:
		camera.add_trauma(trauma_hero_down)
	elif big and (hero or monster):
		camera.add_trauma(trauma_big_hit)


## Where a number on `target` starts: just above its HP bar (the entity's
## Hud), else above its origin.
func _number_anchor(target: Node2D) -> Vector2:
	var entity := target as EntityBase
	if entity != null and entity.hud != null:
		return entity.hud.global_position + Vector2(0.0, -number_lift)
	return target.global_position + Vector2(0.0, -28.0 - number_lift)


## A hit within MERGE_WINDOW of the target's youngest number, or one past its
## NUMBERS_PER_TARGET, adds up in that number (which pops again); otherwise it
## takes the oldest slot, beside the target's other numbers (number_spread).
func _add_number(target: Node2D, at: Vector2, amount: float, ours: bool) -> void:
	var id: int = target.get_instance_id()
	var youngest: int = -1
	var on_target: int = 0
	for i in NUMBER_CAP:
		if _n_age[i] >= NUMBER_LIFE or _n_target[i] != id:
			continue
		on_target += 1
		if youngest < 0 or _n_age[i] < _n_age[youngest]:
			youngest = i
	if youngest >= 0 and (_n_age[youngest] < MERGE_WINDOW or on_target >= NUMBERS_PER_TARGET):
		_n_value[youngest] += amount
		_n_pop[youngest] = 0.0
		return
	var j: int = _n_next
	_n_next = (_n_next + 1) % NUMBER_CAP
	if _n_age[j] >= NUMBER_LIFE:
		_numbers_live += 1
	_n_value[j] = amount
	_n_age[j] = 0.0
	_n_pop[j] = 0.0
	var side: float = 0.0 if on_target == 0 else (1.0 if on_target == 1 else -1.0)
	_n_pos[j] = at + Vector2(side * number_spread + _rng.randf_range(-2.0, 2.0), 0.0)
	_n_target[j] = id
	_n_ours[j] = 1 if ours else 0


# ============================================
# Ground telegraph
# ============================================

## Warns of a hit landing at `pos` within `radius` in `windup` seconds: an
## outline ring at the radius and a ring growing from the centre that reaches
## it as the hit lands, both `color` at TELEGRAPH_ALPHA. A full pool recycles
## the oldest telegraph.
func telegraph(pos: Vector2, radius: float, windup: float, color: Color) -> void:
	var i: int = _t_next
	_t_next = (_t_next + 1) % TELEGRAPH_CAP
	if _t_age[i] >= _t_life[i]:
		_telegraphs_live += 1
	_t_age[i] = 0.0
	_t_life[i] = maxf(windup, 0.05)
	_t_radius[i] = maxf(radius, 1.0)
	var c := Color(color, TELEGRAPH_ALPHA)
	for ring: RingPulse in [_t_outline[i], _t_fill[i]]:
		ring.position = pos
		ring.default_color = c
		ring.visible = true
	_set_ring_radius(_t_outline[i], _t_radius[i], telegraph_width)
	_set_ring_radius(_t_fill[i], 1.0, telegraph_width)


## A unit ring scaled to `radius`, its line kept `line_width` world px wide.
func _set_ring_radius(ring: RingPulse, radius: float, line_width: float) -> void:
	ring.scale = Vector2(radius, radius)
	ring.width = line_width / radius


func _step_telegraphs(delta: float) -> void:
	if _telegraphs_live == 0:
		return
	_telegraphs_live = 0
	for i in TELEGRAPH_CAP:
		if _t_age[i] >= _t_life[i]:
			continue
		_t_age[i] += delta
		if _t_age[i] >= _t_life[i]:
			_t_outline[i].visible = false
			_t_fill[i].visible = false
			continue
		_telegraphs_live += 1
		_set_ring_radius(_t_fill[i], maxf(_t_radius[i] * _t_age[i] / _t_life[i], 1.0), telegraph_width)


# ============================================
# Night Swarm ring (minimal; the full look is Phase 7)
# ============================================

## A cast that starts a Night Swarm takes a swarm slot: its caster's slot if
## it has one (a recast), else the next one round robin (a full pool recycles
## the oldest). Everything after reads the ability's own copy.
func _on_ability_cast(caster: Node, ability: AbilityBase, _target: Node) -> void:
	var swarm := ability as NightSwarm
	var c := caster as Node2D
	if swarm == null or c == null or not swarm.is_active():
		return
	var id: int = c.get_instance_id()
	var slot: int = -1
	for i in SWARM_CAP:
		if _s_ability[i] != null and _s_caster[i] == id:
			slot = i
	if slot < 0:
		slot = _s_next
		_s_next = (_s_next + 1) % SWARM_CAP
	if _s_ability[slot] == null:
		_swarms_live += 1
	_s_ability[slot] = swarm
	_s_caster[slot] = id
	_s_age[slot] = 0.0
	_place_swarm(slot, c)


## Follows each running swarm's caster: the outline at the swarm's radius
## (it grows with the stage and the tree), the bite ring sweeping from
## SWARM_BITE_FROM of it to the edge once per tick_interval, both fading in
## and out over SWARM_FADE. A swarm that ended or lost its caster frees its
## slot (rings hidden, kept).
func _step_swarms(delta: float) -> void:
	if _swarms_live == 0:
		return
	for i in SWARM_CAP:
		var swarm: NightSwarm = _s_ability[i]
		if swarm == null:
			continue
		var c := instance_from_id(_s_caster[i]) as Node2D
		if c == null or not c.is_inside_tree() or not swarm.is_active():
			_free_swarm(i)
			continue
		_s_age[i] += delta
		_place_swarm(i, c)


func _place_swarm(i: int, c: Node2D) -> void:
	var swarm: NightSwarm = _s_ability[i]
	var radius: float = maxf(swarm.area_of_effect, 1.0)
	var fade: float = clampf(_s_age[i] / SWARM_FADE, 0.0, 1.0) * clampf(swarm.time_left() / SWARM_FADE, 0.0, 1.0)
	var bite: float = fposmod(_s_age[i], maxf(swarm.tick_interval, 0.05)) / maxf(swarm.tick_interval, 0.05)
	var outline := _s_outline[i]
	var bite_ring := _s_bite[i]
	outline.position = c.global_position
	bite_ring.position = c.global_position
	outline.default_color = Color(_c_swarm, SWARM_ALPHA * fade)
	bite_ring.default_color = Color(_c_swarm, SWARM_ALPHA * fade * (1.0 - bite))
	_set_ring_radius(outline, radius, swarm_width)
	_set_ring_radius(bite_ring, radius * lerpf(SWARM_BITE_FROM, 1.0, bite), swarm_width)
	outline.visible = true
	bite_ring.visible = true


func _free_swarm(i: int) -> void:
	_s_ability[i] = null
	_s_outline[i].visible = false
	_s_bite[i].visible = false
	_swarms_live -= 1


# ============================================
# Per frame
# ============================================

func _process(delta: float) -> void:
	var t0: int = Time.get_ticks_usec()
	_hits_this_frame = 0
	_kills_this_frame = 0
	_update_view()
	sprites.step(delta)
	_step_numbers(delta)
	_step_telegraphs(delta)
	_step_swarms(delta)
	if sprites.live > 0 or _numbers_live > 0 or _drew:
		queue_redraw()
	_cost_usec = Time.get_ticks_usec() - t0


## The camera's view in world px, grown by CULL_MARGIN.
func _update_view() -> void:
	var vp := get_viewport()
	var xf: Transform2D = vp.get_canvas_transform()
	_view_zoom = maxf(xf.get_scale().x, 0.01)
	_view_rect = (xf.affine_inverse() * vp.get_visible_rect()).grow(CULL_MARGIN)


func _step_numbers(delta: float) -> void:
	if _numbers_live == 0:
		return
	_numbers_live = 0
	for i in NUMBER_CAP:
		if _n_age[i] >= NUMBER_LIFE:
			continue
		_n_age[i] += delta
		_n_pop[i] += delta
		if _n_age[i] < NUMBER_LIFE:
			_numbers_live += 1


func _draw() -> void:
	_drew = sprites.live > 0 or _numbers_live > 0
	sprites.draw(self)
	if _numbers_live > 0:
		_draw_numbers()


## Numbers keep their on-screen size at any zoom: each is drawn in screen px
## (a 1 / zoom transform) from the fx_digits.svg glyph cells.
func _draw_numbers() -> void:
	var cell: Vector2 = _digit_cell
	for i in NUMBER_CAP:
		var k: float = _n_age[i] / NUMBER_LIFE
		if k >= 1.0:
			continue
		var value: int = maxi(int(roundf(_n_value[i])), 1)
		var big: bool = _n_value[i] >= big_hit
		var n: int = 0
		while value > 0 and n < MAX_DIGITS:
			_digits[n] = value % 10
			value = floori(value / 10.0)
			n += 1
		var pop: float = 1.0 + 0.5 * maxf(0.0, 1.0 - _n_pop[i] / NUMBER_POP)
		var gh: float = (number_px_big if big else number_px) * pop
		var gw: float = gh * cell.x / cell.y
		var advance: float = gw * 0.78
		var x: float = -(advance * float(n - 1) + gw) * 0.5
		var rise: float = number_rise * FxEase.out_cubic(minf(k * 1.6, 1.0))
		var c: Color = _c_ours if _n_ours[i] == 1 else (_c_number_big if big else _c_number)
		if k > 0.7:
			c.a *= (1.0 - k) / 0.3
		draw_set_transform(_n_pos[i] + Vector2(0.0, -rise), 0.0, Vector2.ONE / _view_zoom)
		for d in range(n - 1, -1, -1):
			draw_texture_rect_region(FxTex.DIGITS, Rect2(x, -gh * 0.5, gw, gh),
					Rect2(float(_digits[d]) * cell.x, 0.0, cell.x, cell.y), c)
			x += advance
	draw_set_transform_matrix(Transform2D.IDENTITY)


# ============================================
# Pools (tests, F3)
# ============================================

func numbers_live() -> int:
	return _numbers_live


func telegraphs_live() -> int:
	return _telegraphs_live


func swarms_live() -> int:
	return _swarms_live


## The values of the live numbers on `target` (oldest slot first).
func numbers_on(target: Node) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var id: int = target.get_instance_id()
	for i in NUMBER_CAP:
		if _n_age[i] < NUMBER_LIFE and _n_target[i] == id:
			out.append(_n_value[i])
	return out


## F3 overlay line: pool use against the caps, hit counters and this node's
## script time last frame.
func debug_line() -> String:
	return "VFX sprites %d/%d  numbers %d/%d  telegraphs %d/%d  swarms %d/%d\n    hits %d  culled %d  over budget %d  %.2f ms" % [
			sprites.live, SPRITE_CAP, _numbers_live, NUMBER_CAP, _telegraphs_live, TELEGRAPH_CAP,
			_swarms_live, SWARM_CAP, hits_shown, hits_culled, hits_over_budget, float(_cost_usec) / 1000.0]
