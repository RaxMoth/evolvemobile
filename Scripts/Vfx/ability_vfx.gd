class_name AbilityVfx
extends Node2D

## AbilityVfx - what makes each ability recognisable in the match: slashes,
## claws, tracers, blasts, shield wards, taunt tethers, cage stakes, heal hops
## and rally marks. An ability's look is its AbilityFxRecipe (AbilityBase.fx):
## the recipe's `cue` picks a program below, its UiPalette tokens and sizes
## parameterise it, and the FxEvents the ability emits take their colours
## from it. VfxManager keeps the generic hit feedback (impact star, damage and
## heal numbers, kill puffs, trauma) and the ground telegraphs.
##
## The "Abilities" node under World.tscn's Vfx (group "ability_vfx", `camera`
## and `ground` wired scene-side), not an autoload: it lives and dies with the
## match. It draws over the characters at absolute z 45 (under VfxManager's
## numbers at 50, the fog at 100); its FxGroundLayer child ("Ground", absolute
## z 0) draws the ground half (rings, wards, halos, the cage ring, decals and
## the back half of a cage's stakes) after the ground layers and under every
## character.
##
## Hooks, connected in _ready (an autoload cannot be the source of a scene
## [connection]):
##   EventBus.ability_cast   -> cast programs (shield, taunt, rally,
##                              weapon_swap, mine, blood_bomb)
##   EventBus.damage_applied -> hit programs (strike, claw, sniper)
##   EventBus.ability_event  -> moments inside an ability (FxEvents): wards,
##                              tethers, rally marks, mines, cages, supply
##                              drops, heal hops, Last Stand
##   EventBus.entity_died    -> marks, tethers, wards and halos on the fallen end
##
## Toning-down rules (the anim prototype's previews were too busy):
##   - rings at most MAX_RING_WIDTH (3) world px wide, ink included, and on
##     the ground;
##   - at most MAX_PUFFS (6) puffs or dust clouds per cast or event;
##   - nothing covers a character's head longer than HEAD_COVER (0.15) s:
##     slashes, blasts and stars over a body live no longer, lasting marks
##     float above the head (CharacterRig.head_top_of), lasting wards and
##     halos ring the feet;
##   - areas shown for a while (a mine's trigger, a supply drop's pickup) at
##     VfxManager.TELEGRAPH_ALPHA (35%).
##
## Budget: fixed pools (sprite buffers, primitives, tethers, wards, halos,
## cage rings); a full pool recycles its oldest entry, and lasting effects
## (marks, stakes) have pools of their own so a burst never recycles them.
## One-shot programs outside the camera view are skipped (lasting ones start
## anyway: they may come into view). Nothing is allocated per frame. The F3
## overlay shows the pools and the node's script time (debug_line()).
##
## DETERMINISM (tools/sim_trace.sh stays byte-identical): it never writes
## gameplay state (abilities, shields and cages are only READ) and draws every
## random number from its private `_rng`.

## The programs a recipe's cue can name.
const CUES: Array[StringName] = [&"strike", &"claw", &"sniper", &"shield", &"taunt", &"rally",
		&"weapon_swap", &"mine", &"blood_bomb", &"cage", &"supply_drop", &"last_stand"]
## The cues played on each hit the ability lands (EventBus.damage_applied).
const HIT_CUES: Array[StringName] = [&"strike", &"claw", &"sniper"]
## The cues played on the cast (EventBus.ability_cast). The others play only
## the ability's FxEvents.
const CAST_CUES: Array[StringName] = [&"shield", &"taunt", &"rally", &"weapon_swap", &"mine", &"blood_bomb"]

const OVER_CAP: int = 96
const UNDER_CAP: int = 24
const MARK_CAP: int = 16
## Per half of a cage (front, back): room for four cages at once.
const STAKE_CAP: int = 64
const PRIM_CAP: int = 40
const TETHER_CAP: int = 6
const WARD_CAP: int = 6
const HALO_CAP: int = 4
const CAGE_CAP: int = 4
## Widest ring line, ink included (world px).
const MAX_RING_WIDTH: float = 3.0
## Most puffs or dust clouds one cast or event spawns.
const MAX_PUFFS: int = 6
## Longest an effect may sit over a character's head (s).
const HEAD_COVER: float = 0.15
## Life of the slashes, stars and blasts drawn over a body (s).
const FLASH_LIFE: float = 0.14
## World px around the camera view that still counts as in view.
const CULL_MARGIN: float = 96.0
## A shield ward pops in over WARD_POP s, pulses WARD_PULSE s on an absorbed
## hit, fades over WARD_FADE s when it expires and over WARD_BREAK s when it
## breaks.
const WARD_POP: float = 0.2
const WARD_PULSE: float = 0.2
const WARD_FADE: float = 0.3
const WARD_BREAK: float = 0.06
## Smallest ward and halo half-width (world px, before the character's scale).
const FOOT_RING_MIN: float = 12.0
## Height over width of the ellipses at the feet (wards, halos).
const FOOT_SQUASH: float = 0.45
## A cage's stakes sink over STAKE_SINK s once it opens; one stake every
## STAKE_SPACING px of its rim, between STAKES_MIN and STAKES_MAX.
const STAKE_SINK: float = 0.22
const STAKE_SPACING: float = 34.0
const STAKES_MIN: int = 10
const STAKES_MAX: int = 28
## Smallest cage drawn (world px).
const CAGE_MIN_RADIUS: float = 40.0
## Tether and mark fade at their end (s); tether dashes (px) and their drift.
const TETHER_FADE: float = 0.3
const TETHER_DASH: float = 8.0
const TETHER_PERIOD: float = 14.0
const TETHER_SPEED: float = 40.0
## Segments of a curved heal beam.
const BEAM_STEPS: int = 12

enum Prim { NONE, RING, DISC, TRACER, BEAM }

## The match camera (World.tscn): a recipe's trauma goes to it.
@export var camera: GameCamera
## The ground canvas (World.tscn's Vfx/Abilities/Ground).
@export var ground: FxGroundLayer

## Short-lived sprites over the characters: slashes, claws, sparks, stars,
## pluses, puffs, dust, shards, drops, rocks, leaves.
var over := FxSpriteBuffer.new(OVER_CAP)
## Ground decals (blood splat, blast scorch), drawn by the ground layer.
var under := FxSpriteBuffer.new(UNDER_CAP)
## Lasting marks riding a character (a "!", a taunt's anger vein), tagged with
## the instance id of the character.
var marks := FxSpriteBuffer.new(MARK_CAP)
## A cage's stakes, tagged with the cage's instance id: the front half over
## the characters, the back half on the ground (the trapped stand inside).
var stakes_front := FxSpriteBuffer.new(STAKE_CAP)
var stakes_back := FxSpriteBuffer.new(STAKE_CAP)

# F3 counters since the match began.
var programs_played: int = 0
var culled: int = 0

var _rng := RandomNumberGenerator.new()
var _palette: UiPalette
var _ink: Color
var _view_rect := Rect2()
var _drew: bool = false
var _ground_drew: bool = false
var _cost_usec: int = 0

# Primitives (structure of arrays): RING on the ground, DISC, TRACER and BEAM
# over the characters. a/b: RING and DISC radii from/to, TRACER and BEAM
# width (a) and BEAM bow (b); w: RING width.
var _p_kind := PackedInt32Array()
var _p_age := PackedFloat32Array()
var _p_life := PackedFloat32Array()
var _p_delay := PackedFloat32Array()
var _p_pos := PackedVector2Array()
var _p_pos2 := PackedVector2Array()
var _p_a := PackedFloat32Array()
var _p_b := PackedFloat32Array()
var _p_w := PackedFloat32Array()
var _p_col := PackedColorArray()
var _p_col2 := PackedColorArray()
var _p_next: int = 0
var _p_live_ground: int = 0
var _p_live_over: int = 0

# Taunt tethers: the taunted enemy's and the taunter's instance ids.
var _t_from := PackedInt64Array()
var _t_to := PackedInt64Array()
var _t_age := PackedFloat32Array()
var _t_life := PackedFloat32Array()
var _t_col := PackedColorArray()
var _t_next: int = 0
var _t_live: int = 0

# Shield wards: the hero's and its Shield's instance ids (hero 0 = free slot).
var _w_hero := PackedInt64Array()
var _w_shield := PackedInt64Array()
var _w_age := PackedFloat32Array()
var _w_out := PackedFloat32Array()
var _w_out_len := PackedFloat32Array()
var _w_pulse := PackedFloat32Array()
var _w_rx := PackedFloat32Array()
var _w_col := PackedColorArray()
var _w_live: int = 0

# Last Stand halos.
var _h_hero := PackedInt64Array()
var _h_age := PackedFloat32Array()
var _h_life := PackedFloat32Array()
var _h_rx := PackedFloat32Array()
var _h_col := PackedColorArray()
var _h_next: int = 0
var _h_live: int = 0

# Cage rings: the cage's instance id, centre and radius.
var _c_key := PackedInt64Array()
var _c_pos := PackedVector2Array()
var _c_r := PackedFloat32Array()
var _c_age := PackedFloat32Array()
var _c_life := PackedFloat32Array()
var _c_col := PackedColorArray()
var _c_next: int = 0
var _c_live: int = 0


func _ready() -> void:
	_palette = UiPalette.get_default()
	_ink = _palette.ink
	_alloc()
	_update_view()
	# Code-side: an autoload cannot be the source of a scene [connection].
	EventBus.ability_cast.connect(_on_ability_cast)
	EventBus.damage_applied.connect(_on_damage_applied)
	EventBus.ability_event.connect(_on_ability_event)
	EventBus.entity_died.connect(_on_entity_died)


## Sizes every pool once (packed arrays are values: each is resized itself).
func _alloc() -> void:
	_p_kind.resize(PRIM_CAP)
	_p_age.resize(PRIM_CAP)
	_p_life.resize(PRIM_CAP)
	_p_delay.resize(PRIM_CAP)
	_p_pos.resize(PRIM_CAP)
	_p_pos2.resize(PRIM_CAP)
	_p_a.resize(PRIM_CAP)
	_p_b.resize(PRIM_CAP)
	_p_w.resize(PRIM_CAP)
	_p_col.resize(PRIM_CAP)
	_p_col2.resize(PRIM_CAP)
	_t_from.resize(TETHER_CAP)
	_t_to.resize(TETHER_CAP)
	_t_age.resize(TETHER_CAP)
	_t_life.resize(TETHER_CAP)
	_t_col.resize(TETHER_CAP)
	_w_hero.resize(WARD_CAP)
	_w_shield.resize(WARD_CAP)
	_w_age.resize(WARD_CAP)
	_w_out.resize(WARD_CAP)
	_w_out_len.resize(WARD_CAP)
	_w_pulse.resize(WARD_CAP)
	_w_rx.resize(WARD_CAP)
	_w_col.resize(WARD_CAP)
	_h_hero.resize(HALO_CAP)
	_h_age.resize(HALO_CAP)
	_h_life.resize(HALO_CAP)
	_h_rx.resize(HALO_CAP)
	_h_col.resize(HALO_CAP)
	_c_key.resize(CAGE_CAP)
	_c_pos.resize(CAGE_CAP)
	_c_r.resize(CAGE_CAP)
	_c_age.resize(CAGE_CAP)
	_c_life.resize(CAGE_CAP)
	_c_col.resize(CAGE_CAP)


# ============================================
# Event routing
# ============================================

func _on_ability_cast(caster: Node, ability: AbilityBase, _target: Node) -> void:
	if ability == null or ability.fx == null:
		return
	var c := caster as Node2D
	if c == null:
		return
	var fx := ability.fx
	if fx.cue not in CAST_CUES:
		return
	if not in_view(c.global_position):
		culled += 1
		return
	var t0: int = Time.get_ticks_usec()
	programs_played += 1
	match fx.cue:
		&"shield":
			_play_shield_cast(c, fx)
		&"taunt":
			_play_taunt_cast(c, ability, fx)
		&"rally":
			_play_rally(c, fx)
		&"weapon_swap":
			_play_swap(c, fx)
		&"mine":
			_dust(c.global_position, 2, 8.0 * fx.size, 18.0)
		&"blood_bomb":
			_play_blood_bomb(c, ability, fx)
	_cost_usec += Time.get_ticks_usec() - t0


func _on_damage_applied(packet: DamagePacket) -> void:
	if packet == null or packet.ability == null or packet.ability.fx == null:
		return
	var fx := packet.ability.fx
	if fx.cue not in HIT_CUES:
		return
	var target: Node2D = packet.target as Node2D if is_instance_valid(packet.target) else null
	var source: Node2D = packet.source as Node2D if is_instance_valid(packet.source) else null
	if target == null or source == null:
		return
	if not in_view(target.global_position):
		culled += 1
		return
	var t0: int = Time.get_ticks_usec()
	programs_played += 1
	match fx.cue:
		&"strike":
			_play_strike(source, target, fx)
		&"claw":
			_play_claw(source, target, fx)
		&"sniper":
			_play_tracer(source, target, fx)
	_cost_usec += Time.get_ticks_usec() - t0


func _on_ability_event(source: Node, ability: AbilityBase, event: StringName, pos: Vector2, value: float) -> void:
	var t0: int = Time.get_ticks_usec()
	var fx: AbilityFxRecipe = ability.fx if ability != null else null
	var s := source as Node2D
	match event:
		# Lasting effects start even out of view.
		FxEvents.SHIELD_UP:
			_start_ward(source as Shield, fx)
		FxEvents.SHIELD_HIT:
			_ward_hit(s)
		FxEvents.SHIELD_BROKEN:
			_ward_break(s)
		FxEvents.SHIELD_EXPIRED:
			_end_ward(s, WARD_FADE)
		FxEvents.TAUNTED:
			_play_taunted(s, pos, value, fx)
		FxEvents.CAGE_CLOSED:
			_play_cage(source, pos, value, fx)
		FxEvents.CAGE_OPENED:
			_end_cage(source, pos)
		FxEvents.LAST_STAND:
			_play_last_stand(s, value, fx)
		# One-shot effects only in view.
		FxEvents.RALLIED, FxEvents.KIT_PICKED, FxEvents.HEAL_SHOT, FxEvents.CHAIN_HEAL:
			if s == null or not in_view(s.global_position):
				culled += 1
				return
			programs_played += 1
			match event:
				FxEvents.RALLIED:
					_play_rallied(s, fx)
				FxEvents.KIT_PICKED:
					_play_heal_burst(s, fx)
				FxEvents.HEAL_SHOT:
					_play_heal_shot(s, pos, fx)
				FxEvents.CHAIN_HEAL:
					_play_chain_heal(s, pos, fx)
		FxEvents.MINE_ARMED, FxEvents.MINE_EXPLODED, FxEvents.KIT_LANDED:
			if not in_view(pos):
				culled += 1
				return
			programs_played += 1
			match event:
				FxEvents.MINE_ARMED:
					_play_mine_armed(pos, value, fx)
				FxEvents.MINE_EXPLODED:
					_play_mine_blast(pos, value, fx)
				FxEvents.KIT_LANDED:
					_play_kit_landed(pos, value, fx)
	_cost_usec += Time.get_ticks_usec() - t0


## Whatever rides a character that died ends with it (a pooled mob comes back
## as the same node).
func _on_entity_died(entity: Node, _killer: Node) -> void:
	if entity == null:
		return
	var id: int = entity.get_instance_id()
	marks.end_tag(id, 0.1)
	for i in TETHER_CAP:
		if _t_age[i] < _t_life[i] and (_t_from[i] == id or _t_to[i] == id):
			_t_life[i] = minf(_t_life[i], _t_age[i] + TETHER_FADE)
	_end_ward(entity as Node2D, WARD_BREAK)
	for i in HALO_CAP:
		if _h_hero[i] == id:
			_h_life[i] = minf(_h_life[i], _h_age[i] + 0.1)


func in_view(p: Vector2) -> bool:
	return _view_rect.has_point(p)


# ============================================
# Hit programs (EventBus.damage_applied)
# ============================================

## A melee strike (Vlad's Blood Strike, Irelia's Shield Bash): one slash
## crescent sweeping through the target's body, from the striker's side.
func _play_strike(source: Node2D, target: Node2D, fx: AbilityFxRecipe) -> void:
	var to := CharacterRig.mid_body_of(target)
	var dir := (to - CharacterRig.mid_body_of(source)).normalized()
	var slash: int = over.spawn(FxTex.SLASH, to - dir * 4.0, 30.0 * fx.size, 30.0 * fx.size, FLASH_LIFE,
			_palette.color(fx.accent), FxSpriteBuffer.Anim.SWEEP, dir.angle() + _rng.randf_range(-0.25, 0.25))
	over.flip[slash] = 1.0 if _rng.randf() < 0.5 else -1.0


## A claw swipe (Ted): three raking marks over the target's body.
func _play_claw(source: Node2D, target: Node2D, fx: AbilityFxRecipe) -> void:
	var to := CharacterRig.mid_body_of(target)
	var dir := (to - CharacterRig.mid_body_of(source)).normalized()
	over.spawn(FxTex.CLAW, to, 24.0 * fx.size, 20.0 * fx.size, FLASH_LIFE, _palette.color(fx.accent),
			FxSpriteBuffer.Anim.POP, dir.angle() + _rng.randf_range(-0.4, 0.4))


## River's rifle: an ink-rimmed tracer whipping from her muzzle to the target's
## body, and a small muzzle star (the hit's star is VfxManager's).
func _play_tracer(source: Node2D, target: Node2D, fx: AbilityFxRecipe) -> void:
	var from := CharacterRig.mid_body_of(source)
	var to := CharacterRig.mid_body_of(target)
	var dir := (to - from).normalized()
	from += dir * 10.0
	var i: int = _prim(Prim.TRACER, 0.12)
	_p_pos[i] = from
	_p_pos2[i] = to
	_p_a[i] = 2.5 * fx.size
	_p_col[i] = _palette.color(fx.accent)
	_p_col2[i] = _palette.color(fx.core)
	over.spawn(FxTex.STAR, from, 12.0, 7.0, 0.1, _palette.color(fx.core), FxSpriteBuffer.Anim.POP, dir.angle())


# ============================================
# Cast programs (EventBus.ability_cast)
# ============================================

## Divine Shield: a holy ring rolls out from Irelia's feet and a glint pops
## over her head. Every shielded hero gets its ward from SHIELD_UP.
func _play_shield_cast(c: Node2D, fx: AbilityFxRecipe) -> void:
	_ring(c.global_position, 6.0, 54.0 * fx.size, 2.5, _palette.color(fx.accent), 0.35)
	var glint: int = over.spawn(FxTex.SPARK, CharacterRig.head_top_of(c) + Vector2(0.0, -6.0), 14.0, 8.0, 0.3,
			_palette.color(fx.core), FxSpriteBuffer.Anim.POP)
	over.spin[glint] = 5.0


## Monster Taunt: a war-cry ring rolls out to the taunt's range and a "!" pops
## above Irelia. Each taunted enemy gets its mark and tether from TAUNTED.
func _play_taunt_cast(c: Node2D, ability: AbilityBase, fx: AbilityFxRecipe) -> void:
	var r: float = fx.radius if fx.radius > 0.0 else ability.ability_range
	_ring(c.global_position, 10.0, r, 3.0, _palette.color(fx.accent), 0.45)
	_ring(c.global_position, 6.0, r * 0.6, 2.0, _palette.color(fx.shade), 0.4, 0.08)
	_mark(c, FxTex.BANG, 16.0, 0.5, _palette.color(fx.accent), Vector2(0.0, -10.0))


## Rally Cry: two horn-blast rings at Ted's feet, a "!" above him and three
## sparks bursting upward. Every boosted ally gets RALLIED.
func _play_rally(c: Node2D, fx: AbilityFxRecipe) -> void:
	var col := _palette.color(fx.accent)
	_ring(c.global_position, 8.0, 42.0 * fx.size, 3.0, col, 0.32)
	_ring(c.global_position, 8.0, 56.0 * fx.size, 2.0, _palette.color(fx.shade), 0.32, 0.09)
	_mark(c, FxTex.BANG, 16.0, 0.5, col, Vector2(0.0, -10.0))
	_sparks_up(CharacterRig.mid_body_of(c), 3, col, 12.0)


## Weapon Swap: a twinkle at River's hands and a small ring at her feet, in the
## colour of the weapon she now holds (the cast lands after the swap: `alt` for
## the heal staff, `accent` for the rifle).
func _play_swap(c: Node2D, fx: AbilityFxRecipe) -> void:
	var staff: bool = c.has_method(&"get_weapon_mode") \
			and int(c.call(&"get_weapon_mode")) == RiverActiveWeaponSwap.WeaponMode.HEAL_STAFF
	var col := _palette.color(fx.alt if staff else fx.accent)
	var twinkle: int = over.spawn(FxTex.SPARK, CharacterRig.mid_body_of(c), 16.0, 8.0, 0.3, col, FxSpriteBuffer.Anim.POP)
	over.spin[twinkle] = 9.0
	_ring(c.global_position, 4.0, 20.0, 2.0, col, 0.25)


## Blood Bomb: blood drops are sucked into Vlad for a beat, then a short
## crimson blast low on his body (FLASH_LIFE), a ring out to the bomb's radius on
## the ground, four mist puffs rolling out along the ground (never up over a
## head), flying drops and a splat left behind.
func _play_blood_bomb(c: Node2D, ability: AbilityBase, fx: AbilityFxRecipe) -> void:
	var r: float = fx.radius if fx.radius > 0.0 else ability.area_of_effect
	var feet := c.global_position
	var mid := CharacterRig.mid_body_of(c)
	var accent := _palette.color(fx.accent)
	var core := _palette.color(fx.core)
	var gather: float = 0.12
	for k in 6:
		var a: float = TAU * float(k) / 6.0 + _rng.randf_range(-0.2, 0.2)
		var from := mid + Vector2.from_angle(a) * r * 0.3
		var drop: int = over.spawn(FxTex.DROP, from, 9.0, 9.0, gather, accent, FxSpriteBuffer.Anim.FLY, a - PI * 0.5)
		over.vel[drop] = (mid - from) / gather
	var disc: int = _prim(Prim.DISC, FLASH_LIFE, gather)
	_p_pos[disc] = feet.lerp(mid, 0.5)  # low on the body: the head stays clear
	_p_a[disc] = r * 0.06
	_p_b[disc] = minf(r * 0.14, 22.0)
	_p_col[disc] = Color(accent, 0.85)
	_p_col2[disc] = core
	_ring(feet, r * 0.15, r, 3.0, accent, 0.35, gather)
	_puffs(feet, 4, 10.0, 20.0, r * 0.8, Color(_palette.color(fx.core).lerp(accent, 0.5), 0.8), gather)
	for k in 4:
		var a2: float = TAU * float(k) / 4.0 + _rng.randf_range(-0.5, 0.5)
		var d: int = over.spawn(FxTex.DROP, mid, 8.0, 8.0, 0.45, accent, FxSpriteBuffer.Anim.FLY, a2 + PI * 0.5, gather)
		over.vel[d] = Vector2.from_angle(a2) * _rng.randf_range(70.0, 120.0) + Vector2(0.0, -60.0)
		over.grav[d] = 320.0
	_decal(FxTex.SPLAT, feet, minf(r * 0.35, 56.0), fx.decal_life, Color(_palette.color(fx.shade), 0.4), gather)
	_shake(fx.trauma)


# ============================================
# Event programs (EventBus.ability_event)
# ============================================

## SHIELD_UP: a ward ellipse at the shielded hero's feet for as long as the
## shield lasts (its strength in its alpha), after a short bubble pop around
## the hero. A recast on the same hero restarts that hero's ward.
func _start_ward(shield: Shield, fx: AbilityFxRecipe) -> void:
	if shield == null or not is_instance_valid(shield.owner_hero):
		return
	var hero: Node2D = shield.owner_hero
	var id: int = hero.get_instance_id()
	var slot: int = -1
	for i in WARD_CAP:
		if _w_hero[i] == id:
			slot = i
			break
		if slot < 0 and _w_hero[i] == 0:
			slot = i
	if slot < 0:
		return
	if _w_hero[slot] == 0:
		_w_live += 1
	_w_hero[slot] = id
	_w_shield[slot] = shield.get_instance_id()
	_w_age[slot] = 0.0
	_w_out[slot] = 0.0
	_w_pulse[slot] = 0.0
	_w_rx[slot] = _foot_radius(hero)
	_w_col[slot] = _palette.color(fx.accent if fx != null else &"shield")
	if in_view(hero.global_position):
		over.spawn(FxTex.BUBBLE, CharacterRig.mid_body_of(hero), 20.0, 34.0, FLASH_LIFE,
				Color(_w_col[slot], 0.8), FxSpriteBuffer.Anim.GROW)


## SHIELD_HIT: the hero's ward pulses white and wider.
func _ward_hit(hero: Node2D) -> void:
	var i: int = _ward_of(hero)
	if i >= 0:
		_w_pulse[i] = WARD_PULSE


## SHIELD_BROKEN: the ward snaps and six shards burst from the hero's body.
func _ward_break(hero: Node2D) -> void:
	var i: int = _ward_of(hero)
	if i < 0:
		return
	var col: Color = _w_col[i]
	_end_ward(hero, WARD_BREAK)
	var p := CharacterRig.mid_body_of(hero)
	if not in_view(p):
		return
	for k in 6:
		var a: float = TAU * float(k) / 6.0 + _rng.randf_range(-0.2, 0.2)
		var s: int = over.spawn(FxTex.SHARD, p + Vector2.from_angle(a) * 8.0, 8.0, 6.0, 0.4, col,
				FxSpriteBuffer.Anim.FLY, a)
		over.vel[s] = Vector2.from_angle(a) * 80.0 + Vector2(0.0, -40.0)
		over.grav[s] = 260.0
		over.spin[s] = 9.0


## Fades the ward on `hero` out over `fade` s.
func _end_ward(hero: Node2D, fade: float) -> void:
	var i: int = _ward_of(hero)
	if i < 0:
		return
	if _w_out[i] <= 0.0 or _w_out[i] > fade:
		_w_out[i] = fade
		_w_out_len[i] = fade


func _ward_of(hero: Node2D) -> int:
	if hero == null:
		return -1
	var id: int = hero.get_instance_id()
	for i in WARD_CAP:
		if _w_hero[i] == id:
			return i
	return -1


## TAUNTED: an anger vein above the enemy's head and a dashed tether from its
## body to the taunter's for the taunt's duration. The taunter is the hero
## standing at `taunter_pos` (the event fires on the cast's frame).
func _play_taunted(enemy: Node2D, taunter_pos: Vector2, duration: float, fx: AbilityFxRecipe) -> void:
	if enemy == null:
		return
	_mark(enemy, FxTex.ANGER, 16.0, duration, _palette.danger, Vector2(10.0, -2.0))
	var taunter: Node2D = null
	for node in get_tree().get_nodes_in_group(&"Hero"):
		var hero := node as Node2D
		if hero != null and hero.global_position.distance_squared_to(taunter_pos) < 1.0:
			taunter = hero
			break
	if taunter == null:
		return
	var i: int = _t_next
	_t_next = (_t_next + 1) % TETHER_CAP
	_t_from[i] = enemy.get_instance_id()
	_t_to[i] = taunter.get_instance_id()
	_t_age[i] = 0.0
	_t_life[i] = maxf(duration, TETHER_FADE)
	_t_col[i] = _palette.color(fx.accent if fx != null else &"copper_light")


## RALLIED (War Cry, Rallying Taunt, Rally Cry's pets): a small ring at the
## ally's feet and three sparks rising off it, in the recipe's `alt`.
func _play_rallied(ally: Node2D, fx: AbilityFxRecipe) -> void:
	var col := _palette.color(fx.alt if fx != null else &"amber")
	_ring(ally.global_position, 4.0, 18.0, 2.0, col, 0.3)
	_sparks_up(CharacterRig.mid_body_of(ally), 3, col, 10.0)


## LAST_STAND: a burst ring, a star and four sparks at Irelia, then a halo at
## her feet for the invulnerable seconds.
func _play_last_stand(hero: Node2D, seconds: float, fx: AbilityFxRecipe) -> void:
	if hero == null:
		return
	var col := _palette.color(fx.accent if fx != null else &"gold")
	var i: int = _h_next
	_h_next = (_h_next + 1) % HALO_CAP
	if _h_age[i] >= _h_life[i]:
		_h_live += 1
	_h_hero[i] = hero.get_instance_id()
	_h_age[i] = 0.0
	_h_life[i] = maxf(seconds, 0.3)
	_h_rx[i] = _foot_radius(hero) * 1.15
	_h_col[i] = col
	if not in_view(hero.global_position):
		return
	programs_played += 1
	var mid := CharacterRig.mid_body_of(hero)
	_ring(hero.global_position, 8.0, 46.0, 3.0, col, 0.35)
	over.spawn(FxTex.STAR, mid, 20.0, 12.0, FLASH_LIFE, _palette.color(fx.core if fx != null else &"text"),
			FxSpriteBuffer.Anim.POP, _rng.randf() * TAU)
	_sparks_up(mid, 4, col, 14.0)


## MINE_ARMED: a small ring and one dust cloud where a mine was set.
func _play_mine_armed(pos: Vector2, trigger_radius: float, fx: AbilityFxRecipe) -> void:
	_ring(pos, 4.0, maxf(trigger_radius * 0.3, 10.0), 2.0, _palette.color(fx.alt if fx != null else &"vlad"), 0.3)
	_dust(pos, 1, 8.0, 12.0)


## MINE_EXPLODED: a short fireball, a ring out to the blast radius, three
## dust clouds, three rocks and a scorch crack left on the ground.
func _play_mine_blast(pos: Vector2, radius: float, fx: AbilityFxRecipe) -> void:
	var accent := _palette.color(fx.accent if fx != null else &"amber")
	var core := _palette.color(fx.core if fx != null else &"text")
	var disc: int = _prim(Prim.DISC, FLASH_LIFE)
	_p_pos[disc] = pos + Vector2(0.0, -4.0)
	_p_a[disc] = 5.0
	_p_b[disc] = minf(radius * 0.22, 26.0)
	_p_col[disc] = accent
	_p_col2[disc] = core
	_ring(pos, 6.0, radius, 3.0, accent, 0.3)
	_dust(pos, 3, 10.0, 40.0)
	over.spawn(FxTex.STAR, pos + Vector2(0.0, -6.0), 24.0, 14.0, FLASH_LIFE, core, FxSpriteBuffer.Anim.POP,
			_rng.randf() * TAU)
	for k in 3:
		var a: float = -PI * 0.5 + _rng.randf_range(-1.1, 1.1)
		var rock: int = over.spawn(FxTex.ROCK, pos, 8.0, 8.0, 0.5, Color.WHITE, FxSpriteBuffer.Anim.FLY, _rng.randf() * TAU)
		over.vel[rock] = Vector2.from_angle(a) * _rng.randf_range(90.0, 150.0)
		over.grav[rock] = 380.0
		over.spin[rock] = _rng.randf_range(-9.0, 9.0)
	_decal(FxTex.CRACK, pos, radius * 0.45, fx.decal_life if fx != null else 3.0, Color(_ink, 0.45))
	_shake(fx.trauma if fx != null else 0.0)


## CAGE_CLOSED: sharpened stakes spring up around the cage's rim one after
## another (the back half on the ground, the front half over the characters,
## so the trapped stand inside the ring), a trampled ring on the ground and
## dust at the rim, for the cage's duration.
func _play_cage(cage: Node, pos: Vector2, radius: float, fx: AbilityFxRecipe) -> void:
	var key: int = cage.get_instance_id() if cage != null else 1
	var duration: float = float(cage.get(&"duration")) if cage != null and &"duration" in cage else 6.0
	var r: float = maxf(fx.radius if fx != null and fx.radius > 0.0 else radius, CAGE_MIN_RADIUS)
	var size: float = fx.size if fx != null else 1.0
	var n: int = clampi(int(r * TAU / STAKE_SPACING), STAKES_MIN, STAKES_MAX)
	for k in n:
		var a: float = TAU * float(k) / float(n)
		var wait: float = 0.012 * float(k)
		var buf: FxSpriteBuffer = stakes_front if sin(a) > 0.0 else stakes_back
		var s: int = buf.spawn(FxTex.STAKE, pos + Vector2.from_angle(a) * r, 26.0 * size, 26.0 * size,
				duration + 0.3 - wait, Color.WHITE, FxSpriteBuffer.Anim.RISE, _rng.randf_range(-0.1, 0.1), wait)
		buf.tag[s] = key
	var i: int = _c_next
	_c_next = (_c_next + 1) % CAGE_CAP
	if _c_age[i] >= _c_life[i]:
		_c_live += 1
	_c_key[i] = key
	_c_pos[i] = pos
	_c_r[i] = r
	_c_age[i] = 0.0
	_c_life[i] = duration + 0.3
	_c_col[i] = _palette.color(fx.accent if fx != null else &"wood_light")
	if not in_view(pos):
		return
	programs_played += 1
	for k in MAX_PUFFS:
		var a2: float = _rng.randf() * TAU
		var d: int = over.spawn(FxTex.DUST, pos + Vector2.from_angle(a2) * r, 10.0, 18.0, 0.45, Color.WHITE,
				FxSpriteBuffer.Anim.GROW, _rng.randf() * TAU, 0.012 * float(n) * float(k) / float(MAX_PUFFS))
		over.vel[d] = Vector2.from_angle(a2) * 14.0 + Vector2(0.0, -8.0)
		over.drag[d] = 3.0


## CAGE_OPENED: the stakes sink, the ring fades, three dust clouds.
func _end_cage(cage: Node, pos: Vector2) -> void:
	var key: int = cage.get_instance_id() if cage != null else 1
	stakes_front.end_tag(key, STAKE_SINK)
	stakes_back.end_tag(key, STAKE_SINK)
	for i in CAGE_CAP:
		if _c_key[i] == key and _c_age[i] < _c_life[i]:
			_c_life[i] = minf(_c_life[i], _c_age[i] + STAKE_SINK)
	if in_view(pos):
		_dust(pos, 3, 10.0, 30.0)


## KIT_LANDED: dust rings the supply drop, a ring rolls out to its pickup
## radius and three leaves drift off the chute.
func _play_kit_landed(pos: Vector2, radius: float, fx: AbilityFxRecipe) -> void:
	_dust(pos, 5, 10.0, maxf(radius, 20.0))
	_ring(pos, 6.0, radius, 2.5, _palette.color(fx.accent if fx != null else &"heal"), 0.35)
	for k in 3:
		var leaf: int = over.spawn(FxTex.LEAF, pos + Vector2(_rng.randf_range(-14.0, 14.0), -36.0), 9.0, 9.0, 0.9,
				Color.WHITE, FxSpriteBuffer.Anim.FLY, _rng.randf() * TAU, 0.05 * float(k))
		over.vel[leaf] = Vector2(_rng.randf_range(-30.0, 30.0), -10.0)
		over.grav[leaf] = 40.0
		over.spin[leaf] = _rng.randf_range(-4.0, 4.0)


## KIT_PICKED: three pluses rise off the healed hero and a ring at its feet.
func _play_heal_burst(hero: Node2D, fx: AbilityFxRecipe) -> void:
	var col := _palette.color(fx.accent if fx != null else &"heal")
	var mid := CharacterRig.mid_body_of(hero)
	for k in 3:
		var p: int = over.spawn(FxTex.PLUS, mid + Vector2(-10.0 + 10.0 * float(k), 0.0), 10.0, 7.0, 0.5, col,
				FxSpriteBuffer.Anim.POP, 0.0, 0.05 * float(k))
		over.vel[p] = Vector2(0.0, -36.0)
	_ring(hero.global_position, 4.0, 20.0, 2.0, col, 0.3)


## HEAL_SHOT (River's staff): three pluses hop from River's hands to the
## ally's body, then two rise off it.
func _play_heal_shot(ally: Node2D, from: Vector2, fx: AbilityFxRecipe) -> void:
	var col := _palette.color(fx.alt if fx != null else &"heal")
	var to := CharacterRig.mid_body_of(ally)
	var travel: float = 0.22
	for k in 3:
		var hop: int = over.spawn(FxTex.PLUS, from, 10.0, 8.0, travel, col, FxSpriteBuffer.Anim.FLY, 0.0, 0.05 * float(k))
		over.vel[hop] = (to - from) / travel + Vector2(0.0, -55.0)
		over.grav[hop] = 110.0 / travel
	for k in 2:
		var up: int = over.spawn(FxTex.PLUS, to + Vector2(-6.0 + 12.0 * float(k), 0.0), 9.0, 6.0, 0.45, col,
				FxSpriteBuffer.Anim.POP, 0.0, travel + 0.06 * float(k))
		over.vel[up] = Vector2(0.0, -34.0)


## CHAIN_HEAL (River's capstone): a curved heal beam jumps from the healed
## ally to the chained one, and a plus pops where it lands.
func _play_chain_heal(ally: Node2D, from: Vector2, fx: AbilityFxRecipe) -> void:
	var col := _palette.color(fx.alt if fx != null else &"heal")
	var to := CharacterRig.mid_body_of(ally)
	var i: int = _prim(Prim.BEAM, 0.3)
	_p_pos[i] = from
	_p_pos2[i] = to
	_p_a[i] = 2.5
	_p_b[i] = clampf(from.distance_to(to) * 0.25, 8.0, 40.0)
	_p_col[i] = col
	_p_col2[i] = _palette.color(fx.core if fx != null else &"text")
	var up: int = over.spawn(FxTex.PLUS, to, 10.0, 7.0, 0.45, col, FxSpriteBuffer.Anim.POP, 0.0, 0.1)
	over.vel[up] = Vector2(0.0, -34.0)


# ============================================
# Spawn helpers
# ============================================

func _prim(kind: Prim, life: float, delay: float = 0.0) -> int:
	var i: int = _p_next
	_p_next = (_p_next + 1) % PRIM_CAP
	_p_kind[i] = kind
	_p_age[i] = 0.0
	_p_life[i] = maxf(life, 0.01)
	_p_delay[i] = delay
	if kind == Prim.RING:
		_p_live_ground += 1
	else:
		_p_live_over += 1
	return i


## A ring on the ground growing from r0 to r1 px, at most MAX_RING_WIDTH wide.
func _ring(p: Vector2, r0: float, r1: float, w: float, col: Color, life: float, delay: float = 0.0) -> void:
	var i: int = _prim(Prim.RING, life, delay)
	_p_pos[i] = p
	_p_a[i] = r0
	_p_b[i] = r1
	_p_w[i] = minf(w, MAX_RING_WIDTH)
	_p_col[i] = col


## A lasting mark above `host`'s head (offset px right / up of its head top),
## riding it and tagged with it.
func _mark(host: Node2D, tex: Texture2D, size: float, life: float, col: Color, offset: Vector2) -> void:
	var s: int = marks.spawn(tex, CharacterRig.head_top_of(host) - host.global_position + offset - Vector2(0.0, size * 0.5),
			size, size, life, col, FxSpriteBuffer.Anim.HOLD)
	marks.follow[s] = host.get_instance_id()
	marks.tag[s] = host.get_instance_id()


func _decal(tex: Texture2D, p: Vector2, size: float, life: float, col: Color, delay: float = 0.0) -> void:
	under.spawn(tex, p, size, size, life, col, FxSpriteBuffer.Anim.FLY, _rng.randf() * TAU, delay)


## `n` (at most MAX_PUFFS) dust clouds at the feet, drifting outwards
## (`spread` px/s).
func _dust(p: Vector2, n: int, size: float, spread: float) -> void:
	for k in mini(n, MAX_PUFFS):
		var a: float = TAU * float(k) / float(maxi(n, 1)) + _rng.randf_range(-0.4, 0.4)
		var d := Vector2(cos(a), sin(a) * 0.55)
		var s: int = over.spawn(FxTex.DUST, p + d * 4.0, size, size * 1.9, _rng.randf_range(0.35, 0.5),
				Color.WHITE, FxSpriteBuffer.Anim.GROW, _rng.randf() * TAU)
		over.vel[s] = d * spread + Vector2(0.0, -8.0)
		over.drag[s] = 3.0


## `n` (at most MAX_PUFFS) tinted puffs rolling out of `p` (the feet) along
## the ground at `speed` px/s.
func _puffs(p: Vector2, n: int, s0: float, s1: float, speed: float, col: Color, delay: float = 0.0) -> void:
	for k in mini(n, MAX_PUFFS):
		var a: float = TAU * float(k) / float(maxi(n, 1)) + _rng.randf_range(-0.3, 0.3)
		var d := Vector2(cos(a), sin(a) * 0.5)
		var s: int = over.spawn(FxTex.PUFF, p + d * 6.0, s0, s1, 0.45, col,
				FxSpriteBuffer.Anim.GROW, _rng.randf() * TAU, delay)
		over.vel[s] = d * speed
		over.drag[s] = 4.0


## `n` sparks rising off `p`, spread `spread` px sideways.
func _sparks_up(p: Vector2, n: int, col: Color, spread: float) -> void:
	for k in n:
		var x: float = spread * (float(k) / float(maxi(n - 1, 1)) * 2.0 - 1.0)
		var s: int = over.spawn(FxTex.SPARK, p + Vector2(x, 0.0), 8.0, 5.0, 0.4, col, FxSpriteBuffer.Anim.POP,
				0.0, 0.04 * float(k))
		over.vel[s] = Vector2(x * 1.5, -60.0)
		over.drag[s] = 2.0


## Half-width (world px) of a ring around `node`'s feet: its rig's shadow, at
## the node's scale.
func _foot_radius(node: Node2D) -> float:
	var rig := node.get_node_or_null(^"Rig") as CharacterRig
	var r: float = rig.shadow_radius * CharacterRig.SHADOW_SPREAD if rig != null else 0.0
	return maxf(r, FOOT_RING_MIN) * absf(node.global_scale.x)


func _shake(amount: float) -> void:
	if camera != null and amount > 0.0:
		camera.add_trauma(amount)


# ============================================
# Per frame
# ============================================

func _process(delta: float) -> void:
	var t0: int = Time.get_ticks_usec()
	_update_view()
	_step_prims(delta)
	over.step(delta)
	under.step(delta)
	marks.step(delta)
	stakes_front.step(delta)
	stakes_back.step(delta)
	_step_tethers(delta)
	_step_wards(delta)
	_step_halos(delta)
	_step_cages(delta)
	if _over_live() or _drew:
		queue_redraw()
	if ground != null and (_ground_live() or _ground_drew):
		ground.queue_redraw()
	_cost_usec = Time.get_ticks_usec() - t0


## The camera's view in world px, grown by CULL_MARGIN.
func _update_view() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	_view_rect = (vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()).grow(CULL_MARGIN)


func _over_live() -> bool:
	return _p_live_over > 0 or _t_live > 0 or over.live > 0 or marks.live > 0 or stakes_front.live > 0


func _ground_live() -> bool:
	return _p_live_ground > 0 or _w_live > 0 or _h_live > 0 or _c_live > 0 or under.live > 0 or stakes_back.live > 0


func _step_prims(delta: float) -> void:
	if _p_live_ground == 0 and _p_live_over == 0:
		return
	_p_live_ground = 0
	_p_live_over = 0
	for i in PRIM_CAP:
		if _p_kind[i] == Prim.NONE:
			continue
		if _p_delay[i] > 0.0:
			_p_delay[i] -= delta
		else:
			_p_age[i] += delta
			if _p_age[i] >= _p_life[i]:
				_p_kind[i] = Prim.NONE
				continue
		if _p_kind[i] == Prim.RING:
			_p_live_ground += 1
		else:
			_p_live_over += 1


func _step_tethers(delta: float) -> void:
	_t_live = 0
	for i in TETHER_CAP:
		if _t_age[i] >= _t_life[i]:
			continue
		_t_age[i] += delta
		if _t_age[i] < _t_life[i]:
			_t_live += 1


func _step_wards(delta: float) -> void:
	if _w_live == 0:
		return
	_w_live = 0
	for i in WARD_CAP:
		if _w_hero[i] == 0:
			continue
		var hero := instance_from_id(_w_hero[i]) as Node2D
		if hero == null or not hero.is_inside_tree():
			_w_hero[i] = 0
			continue
		_w_age[i] += delta
		_w_pulse[i] = maxf(_w_pulse[i] - delta, 0.0)
		if _w_out[i] > 0.0:
			_w_out[i] -= delta
			if _w_out[i] <= 0.0:
				_w_hero[i] = 0
				continue
		_w_live += 1


func _step_halos(delta: float) -> void:
	if _h_live == 0:
		return
	_h_live = 0
	for i in HALO_CAP:
		if _h_age[i] >= _h_life[i]:
			continue
		_h_age[i] += delta
		if _h_age[i] < _h_life[i]:
			_h_live += 1


func _step_cages(delta: float) -> void:
	if _c_live == 0:
		return
	_c_live = 0
	for i in CAGE_CAP:
		if _c_age[i] >= _c_life[i]:
			continue
		_c_age[i] += delta
		if _c_age[i] < _c_life[i]:
			_c_live += 1


# ============================================
# Drawing: over the characters (this node), on the ground (FxGroundLayer)
# ============================================

func _draw() -> void:
	var t0: int = Time.get_ticks_usec()
	_drew = _over_live()
	for i in PRIM_CAP:
		var kind: int = _p_kind[i]
		if kind == Prim.NONE or kind == Prim.RING or _p_delay[i] > 0.0:
			continue
		var k: float = clampf(_p_age[i] / _p_life[i], 0.0, 1.0)
		match kind:
			Prim.DISC:
				_draw_disc(i, k)
			Prim.TRACER:
				_draw_tracer(i, k)
			Prim.BEAM:
				_draw_beam(i, k)
	_draw_tethers()
	stakes_front.draw(self)
	over.draw(self)
	marks.draw(self)
	_cost_usec += Time.get_ticks_usec() - t0


## Called from FxGroundLayer._draw (under the characters).
func paint_ground(ci: CanvasItem) -> void:
	_ground_drew = _ground_live()
	for i in PRIM_CAP:
		if _p_kind[i] == Prim.RING and _p_delay[i] <= 0.0:
			_paint_ring(ci, i, clampf(_p_age[i] / _p_life[i], 0.0, 1.0))
	_paint_cages(ci)
	_paint_wards(ci)
	_paint_halos(ci)
	under.draw(ci)
	stakes_back.draw(ci)


## An ink ring under a colour ring half as wide: MAX_RING_WIDTH at most.
func _paint_ring(ci: CanvasItem, i: int, k: float) -> void:
	var r: float = lerpf(_p_a[i], _p_b[i], FxEase.out_cubic(k))
	var w: float = maxf(_p_w[i] * (1.0 - 0.4 * k), 1.0)
	var a: float = 1.0 if k < 0.5 else (1.0 - k) / 0.5
	var n: int = clampi(int(r * 0.5), 24, 64)
	ci.draw_arc(_p_pos[i], r, 0.0, TAU, n, Color(_ink, a * 0.8), w, true)
	ci.draw_arc(_p_pos[i], r, 0.0, TAU, n, Color(_p_col[i], a), w * 0.5, true)


## A flat outlined blast disc: ink rim, accent body, lighter core up-left,
## all at the body colour's alpha.
func _draw_disc(i: int, k: float) -> void:
	var r: float = lerpf(_p_a[i], _p_b[i], FxEase.out_cubic(minf(k * 1.6, 1.0)))
	var a: float = (1.0 if k < 0.6 else (1.0 - k) / 0.4) * _p_col[i].a
	var p: Vector2 = _p_pos[i]
	draw_circle(p, r + 1.5, Color(_ink, a))
	draw_circle(p, r, Color(_p_col[i], a))
	draw_circle(p + Vector2(-r, -r) * 0.18, r * 0.55 * (1.0 - 0.5 * k), Color(_p_col2[i], a))


## A tracer whose tail catches up with its head: ink, colour, a hot core.
func _draw_tracer(i: int, k: float) -> void:
	var to: Vector2 = _p_pos2[i]
	var from: Vector2 = _p_pos[i].lerp(to, FxEase.in_quad(k))
	var w: float = _p_a[i] * (1.0 - 0.5 * k)
	draw_line(from, to, _ink, w + 2.0, true)
	draw_line(from, to, _p_col[i], w, true)
	draw_line(from, to, _p_col2[i], maxf(w * 0.35, 0.8), true)


## A curved beam that grows from its start to its end, then fades.
func _draw_beam(i: int, k: float) -> void:
	var a0: Vector2 = _p_pos[i]
	var a2: Vector2 = _p_pos2[i]
	var bend: Vector2 = (a2 - a0).orthogonal().normalized() * _p_b[i]
	var mid: Vector2 = (a0 + a2) * 0.5 - bend
	var head: float = minf(k / 0.4, 1.0)
	var alpha: float = 1.0 if k < 0.6 else (1.0 - k) / 0.4
	var w: float = _p_a[i]
	for pass_i in 2:
		var col: Color = Color(_ink, alpha) if pass_i == 0 else Color(_p_col[i], alpha)
		var width: float = w + 2.0 if pass_i == 0 else w
		var prev: Vector2 = a0
		for s in range(1, BEAM_STEPS + 1):
			var t: float = head * float(s) / float(BEAM_STEPS)
			var q: Vector2 = a0.lerp(mid, t).lerp(mid.lerp(a2, t), t)
			draw_line(prev, q, col, width, true)
			prev = q


## Dashed ink-rimmed tethers from each taunted enemy's body to the taunter's,
## the dashes drifting toward the taunter.
func _draw_tethers() -> void:
	if _t_live == 0:
		return
	for i in TETHER_CAP:
		if _t_age[i] >= _t_life[i]:
			continue
		var e := instance_from_id(_t_from[i]) as Node2D
		var t := instance_from_id(_t_to[i]) as Node2D
		if e == null or t == null or not e.is_inside_tree() or not t.is_inside_tree():
			continue
		var from := CharacterRig.mid_body_of(e)
		var d: Vector2 = CharacterRig.mid_body_of(t) - from
		var length: float = d.length()
		if length < 1.0:
			continue
		var u: Vector2 = d / length
		var fade: float = clampf((_t_life[i] - _t_age[i]) / TETHER_FADE, 0.0, 1.0) * clampf(_t_age[i] / 0.15, 0.0, 1.0)
		var x: float = fmod(_t_age[i] * TETHER_SPEED, TETHER_PERIOD) - TETHER_PERIOD
		while x < length:
			var x0: float = maxf(x, 0.0)
			var x1: float = minf(x + TETHER_DASH, length)
			if x1 > x0:
				draw_line(from + u * x0, from + u * x1, Color(_ink, 0.8 * fade), 3.0)
				draw_line(from + u * x0, from + u * x1, Color(_t_col[i], fade), 1.5)
			x += TETHER_PERIOD


## Each ward: an ellipse at the hero's feet, its alpha the shield's strength,
## white and wider for a moment after an absorbed hit.
func _paint_wards(ci: CanvasItem) -> void:
	if _w_live == 0:
		return
	for i in WARD_CAP:
		if _w_hero[i] == 0:
			continue
		var hero := instance_from_id(_w_hero[i]) as Node2D
		if hero == null or not hero.is_inside_tree():
			continue
		var strength: float = 1.0
		var shield := instance_from_id(_w_shield[i]) as Shield
		if shield != null:
			strength = shield.get_shield_percent()
		var a: float = 0.45 + 0.45 * strength
		if _w_out[i] > 0.0:
			a *= _w_out[i] / maxf(_w_out_len[i], 0.01)
		var pulse: float = _w_pulse[i] / WARD_PULSE
		var rx: float = _w_rx[i] * FxEase.pop(minf(_w_age[i] / WARD_POP, 1.0)) * (1.0 + 0.2 * pulse)
		var col: Color = _w_col[i].lerp(_palette.white, pulse)
		_paint_foot_ring(ci, hero.global_position, rx, Color(col, a))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Each Last Stand halo: a pulsing ellipse at the hero's feet.
func _paint_halos(ci: CanvasItem) -> void:
	if _h_live == 0:
		return
	for i in HALO_CAP:
		if _h_age[i] >= _h_life[i]:
			continue
		var hero := instance_from_id(_h_hero[i]) as Node2D
		if hero == null or not hero.is_inside_tree():
			continue
		var a: float = clampf(_h_age[i] / 0.15, 0.0, 1.0) * clampf((_h_life[i] - _h_age[i]) / 0.3, 0.0, 1.0)
		var rx: float = _h_rx[i] * (1.0 + 0.08 * sin(_h_age[i] * 9.0))
		_paint_foot_ring(ci, hero.global_position, rx, Color(_h_col[i], a))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## An ink and colour ellipse ring at `feet`, squashed by FOOT_SQUASH.
func _paint_foot_ring(ci: CanvasItem, feet: Vector2, rx: float, col: Color) -> void:
	ci.draw_set_transform(feet, 0.0, Vector2(1.0, FOOT_SQUASH))
	ci.draw_arc(Vector2.ZERO, rx, 0.0, TAU, 32, Color(_ink, col.a * 0.8), 2.5, true)
	ci.draw_arc(Vector2.ZERO, rx, 0.0, TAU, 32, col, 1.5, true)


## Each cage's trampled ring at its rim, under its stakes.
func _paint_cages(ci: CanvasItem) -> void:
	if _c_live == 0:
		return
	for i in CAGE_CAP:
		if _c_age[i] >= _c_life[i]:
			continue
		var a: float = clampf(_c_age[i] / 0.2, 0.0, 1.0) * clampf((_c_life[i] - _c_age[i]) / STAKE_SINK, 0.0, 1.0)
		ci.draw_arc(_c_pos[i], _c_r[i], 0.0, TAU, 64, Color(_ink, 0.35 * a), MAX_RING_WIDTH, true)
		ci.draw_arc(_c_pos[i], _c_r[i], 0.0, TAU, 64, Color(_c_col[i], 0.5 * a), MAX_RING_WIDTH * 0.5, true)


# ============================================
# Pools (tests, F3)
# ============================================

func tethers_live() -> int:
	return _t_live


func wards_live() -> int:
	return _w_live


func halos_live() -> int:
	return _h_live


func cages_live() -> int:
	return _c_live


## Live primitives of `kind` (delayed ones included).
func prims_of(kind: Prim) -> int:
	var n: int = 0
	for i in PRIM_CAP:
		if _p_kind[i] == kind:
			n += 1
	return n


## The widest live ring line (world px).
func widest_ring() -> float:
	var w: float = 0.0
	for i in PRIM_CAP:
		if _p_kind[i] == Prim.RING:
			w = maxf(w, _p_w[i])
	return w


## The longest life of a live primitive of `kind` (s).
func longest_prim(kind: Prim) -> float:
	var life: float = 0.0
	for i in PRIM_CAP:
		if _p_kind[i] == kind:
			life = maxf(life, _p_life[i])
	return life


## The two ends of the live tether from `enemy` (its body, the taunter's),
## or an empty array.
func tether_ends(enemy: Node2D) -> PackedVector2Array:
	var id: int = enemy.get_instance_id()
	for i in TETHER_CAP:
		if _t_age[i] < _t_life[i] and _t_from[i] == id:
			var t := instance_from_id(_t_to[i]) as Node2D
			if t != null:
				return PackedVector2Array([CharacterRig.mid_body_of(enemy), CharacterRig.mid_body_of(t)])
	return PackedVector2Array()


## F3 overlay line: programs played and culled, pool use against the caps and
## this node's script time last frame.
func debug_line() -> String:
	return "Ability FX %d  culled %d  sprites %d/%d  marks %d/%d  stakes %d  prims %d/%d\n    tethers %d  wards %d  halos %d  cages %d  %.2f ms" % [
			programs_played, culled, over.live, OVER_CAP, marks.live, MARK_CAP,
			stakes_front.live + stakes_back.live, _p_live_ground + _p_live_over, PRIM_CAP,
			_t_live, _w_live, _h_live, _c_live, float(_cost_usec) / 1000.0]
