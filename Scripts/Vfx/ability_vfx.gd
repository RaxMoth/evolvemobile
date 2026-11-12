class_name AbilityVfx
extends Node2D

## AbilityVfx - what makes each ability recognisable in the match: slashes,
## claws, tracers, blasts, shield wards, taunt tethers, cage stakes, heal hops
## and rally marks for the heroes; cleave smears, screech ripples, dash trails,
## slam craters, the spinning Tusk Axe, Night Swarm's bats, stun stars and the
## capstone cues for the monsters; the generic bite and claw of the mobs and
## Ted's fox. An ability's look is its AbilityFxRecipe
## (AbilityBase.fx): the recipe's `cue` picks a program below, its UiPalette
## tokens and sizes parameterise it, and the FxEvents the ability emits take
## their colours from it (a monster's capstone moments from its passive's
## recipe). VfxManager keeps the generic hit feedback (impact star, damage and
## heal numbers, kill puffs, trauma) and draws the ground telegraphs the
## monster programs ask for (`telegraphs`: circle, cone, lane).
##
## The "Abilities" node under World.tscn's Vfx (group "ability_vfx", `camera`
## and `ground` wired scene-side), not an autoload: it lives and dies with the
## match. It draws over the characters at absolute z 45 (under VfxManager's
## numbers at 50, the fog at 100); its FxGroundLayer child ("Ground", absolute
## z 0) draws the ground half (rings, wards, halos, the cage ring, swarm rings,
## warband rings, decals and the back half of a cage's stakes) after the
## ground layers and under every character. `camera`, `ground` and
## `telegraphs` (the parent VfxManager) are wired scene-side.
##
## Hooks, connected in _ready (an autoload cannot be the source of a scene
## [connection]):
##   EventBus.ability_cast   -> cast programs (shield, taunt, rally,
##                              weapon_swap, mine, blood_bomb, cleave,
##                              screech, axe, swarm)
##   EventBus.damage_applied -> hit programs (strike, claw, sniper, bite);
##                              a hit without an ability (a mob's or the
##                              fox's swing) plays its rig's swing_fx while
##                              that rig plays_moves() (on screen, inside the
##                              rig budget), else nothing
##   EventBus.ability_event  -> moments inside an ability (FxEvents): wards,
##                              tethers, rally marks, mines, cages, supply
##                              drops, heal hops, Last Stand; dashes, slams,
##                              stuns, recruits, Rampage, Vampiric Rebirth,
##                              Unstoppable
##   EventBus.entity_died    -> marks, tethers, wards, halos, stun stars and
##                              warband rings on the fallen end (and on
##                              Nyxa's body when it scatters, SCATTERED)
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
## cage rings, dash trails, swarms, axes, stun stars, warband rings); a full
## pool recycles its oldest entry, and lasting effects (marks, stakes) have
## pools of their own so a burst never recycles them.
## One-shot programs outside the camera view are skipped (lasting ones start
## anyway: they may come into view). Nothing is allocated per frame. The F3
## overlay shows the pools and the node's script time (debug_line()).
##
## DETERMINISM (tools/sim_trace.sh stays byte-identical): it never writes
## gameplay state (abilities, shields, cages, dashes, swarms and axes are only
## READ; the one write is presentation: a recipe's prop_part, a rig sprite,
## hidden while the axe flies) and draws every random number from its
## private `_rng`.

## The programs a recipe's cue can name.
const CUES: Array[StringName] = [&"strike", &"claw", &"sniper", &"shield", &"taunt", &"rally",
		&"weapon_swap", &"mine", &"blood_bomb", &"cage", &"supply_drop", &"last_stand",
		&"cleave", &"screech", &"ram_dash", &"swoop", &"slam", &"stomp", &"axe", &"swarm",
		&"rampage", &"rebirth", &"unstoppable", &"bite"]
## The cues played on each hit the ability lands (EventBus.damage_applied),
## and the ones a rig's swing_fx can name.
const HIT_CUES: Array[StringName] = [&"strike", &"claw", &"sniper", &"bite"]
## The cues played on the cast (EventBus.ability_cast). The others play only
## the ability's FxEvents.
const CAST_CUES: Array[StringName] = [&"shield", &"taunt", &"rally", &"weapon_swap", &"mine", &"blood_bomb",
		&"cleave", &"screech", &"axe", &"swarm"]
## Cast cues that last (they follow the ability while it flies or runs):
## started even out of view, drawn only in view.
const LASTING_CAST_CUES: Array[StringName] = [&"axe", &"swarm"]

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

## Monster pools: dashes trailed, Night Swarms, thrown axes, stun stars and
## warband rings shown at once (one monster; a second slot covers a recast).
const TRAIL_CAP: int = 2
const SWARM_CAP: int = 2
const AXE_CAP: int = 2
const STUN_CAP: int = 8
const BAND_CAP: int = 8
## A Swoop's streak: path points kept per trail, sampled every TRAIL_SAMPLE px.
const TRAIL_POINTS: int = 10
const TRAIL_SAMPLE: float = 10.0
## Px between two trail sprites (a dust puff, a peeling bat).
const TRAIL_STEP_DUST: float = 44.0
const TRAIL_STEP_BATS: float = 60.0
## Most bats one Swoop pass peels off (a dash's dust counts against MAX_PUFFS).
const TRAIL_BATS: int = 4
## Seconds a trail fades after its dash ended.
const TRAIL_FADE: float = 0.22
## Bats a Night Swarm circles with, more under Brood Mother (a never-ending
## swarm), the most a slot holds.
const SWARM_BATS: int = 8
const SWARM_BATS_BROOD: int = 12
## A swarm fades in and out over SWARM_FADE s; its bats dive to SWARM_DIVE of
## the radius over the first SWARM_DIVE_SHARE of every bite.
const SWARM_FADE: float = 0.25
const SWARM_DIVE: float = 0.6
const SWARM_DIVE_SHARE: float = 0.35
## Stun stars: radians a second they circle, their orbit half-width and
## their size (world px; smaller and they read as dust on a phone).
const STUN_SPIN: float = 7.0
const STUN_ORBIT: float = 12.0
const STUN_STAR_SIZE: float = 13.0
## World px the stars' orbit centre floats above the head's top: at least
## STUN_ORBIT * 0.35 + STUN_STAR_SIZE * 0.5 (10.7), so the front star never
## dips over the head (with 6 it did, 4 px, for a third of each turn).
const STUN_LIFT: float = 12.0
## A swarm's bats circle this share of the way from the caster's feet (its
## ground ring's centre) up to its body: over the ring, at flying height.
const SWARM_LIFT_SHARE: float = 0.5
## A cleave's crescent sits at least the caster's drawn half-width plus this
## fraction of the reach out from its swing point.
const CLEAVE_CLEAR: float = 0.1
## Seconds a cleave's or a screech's cone telegraph shows.
const CONE_FLASH: float = 0.22
## Seconds Vampiric Rebirth's bats take to fly to the re-form point.
const REFORM_TRAVEL: float = 0.35
## A bite's jaws: width (world px, x the recipe's size), how far apart they
## start (share of the width, each side of the target's body), how hard they
## snap together (1/s: their speed over the gap, and their drag) and the
## most they tilt toward the biter's side (radians).
const BITE_WIDTH: float = 22.0
const BITE_GAP: float = 0.3
const BITE_SNAP: float = 9.0
const BITE_TILT: float = 0.5

enum Prim { NONE, RING, DISC, TRACER, BEAM, ARC }

## The match camera (World.tscn): a recipe's trauma goes to it.
@export var camera: GameCamera
## The ground canvas (World.tscn's Vfx/Abilities/Ground).
@export var ground: FxGroundLayer
## The match's VfxManager (World.tscn: this node's parent): the monster
## programs' ground telegraphs. null = none drawn (tests, previews).
@export var telegraphs: VfxManager

@export_group("Thrown axe")
## World px of the spinning Tusk Axe along its longest side.
@export var axe_size: float = 44.0
## Turns per second of the spinning axe (clockwise thrown right, else counter).
@export var axe_turns_per_second: float = 2.5

@export_group("Night Swarm")
## World px of one bat of a swarm (along its wingspan).
@export var swarm_bat_size: float = 20.0
## Radians a second the swarm's bats circle (each a little off it).
@export var swarm_orbit_speed: float = 2.2

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
## Swings without an ability that played their rig's swing_fx (counted in
## programs_played too).
var swings_played: int = 0

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
## The shield's strength (0..1) as last seen alive: a ward fading after its
## shield expired or broke (freed that frame) keeps it.
var _w_strength := PackedFloat32Array()
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

# ARC primitives (screech ripples): the facing (radians) and the half spread.
var _p_ang := PackedFloat32Array()
var _p_span := PackedFloat32Array()

# Dash trails: per slot the dashing caster (0 = free), its dash and recipe,
# bats (Shadow Swoop) or dust (Ram Dash), the sprites spawned this cast and
# where the last one was, the fade left once the dash ended (0 = dashing),
# and TRAIL_POINTS path points (a ring per slot) for a Swoop's streak.
var _r_caster := PackedInt64Array()
var _r_dash: Array[BullRamDash] = []
var _r_fx: Array[AbilityFxRecipe] = []
var _r_bats := PackedByteArray()
var _r_spawned := PackedInt32Array()
var _r_last := PackedVector2Array()
var _r_fade := PackedFloat32Array()
var _r_path := PackedVector2Array()
var _r_head := PackedInt32Array()
var _r_count := PackedInt32Array()
var _r_next: int = 0
var _r_live: int = 0

# Night Swarms: per slot the running ability (null = free), its caster, the
# seconds shown, the fade-out left once it ended (0 = running) and per bat
# (SWARM_BATS_BROOD a slot) its orbit phase, speed factor and radius share.
var _s_swarm: Array[NightSwarm] = []
var _s_caster := PackedInt64Array()
var _s_fx: Array[AbilityFxRecipe] = []
var _s_age := PackedFloat32Array()
var _s_out := PackedFloat32Array()
var _s_phase := PackedFloat32Array()
var _s_speed := PackedFloat32Array()
var _s_reach := PackedFloat32Array()
var _s_next: int = 0
var _s_live: int = 0

# Thrown axes: per slot the flying ability (null = free), its caster, the
# sprite's spin angle and turn rate, and the rig part hidden meanwhile (its
# instance id, 0 = none).
var _a_axe: Array[ThrownAxe] = []
var _a_fx: Array[AbilityFxRecipe] = []
var _a_caster := PackedInt64Array()
var _a_angle := PackedFloat32Array()
var _a_spin := PackedFloat32Array()
var _a_prop := PackedInt64Array()
var _a_next: int = 0
var _a_live: int = 0

# Stun stars: the stunned entity's instance id (0 = free), age, life, colour.
var _st_host := PackedInt64Array()
var _st_age := PackedFloat32Array()
var _st_life := PackedFloat32Array()
var _st_col := PackedColorArray()
var _st_next: int = 0
var _st_live: int = 0

# Warband rings: the recruited mob's instance id (0 = free), age, life, ring
# half-width and colour.
var _b_mob := PackedInt64Array()
var _b_age := PackedFloat32Array()
var _b_life := PackedFloat32Array()
var _b_rx := PackedFloat32Array()
var _b_col := PackedColorArray()
var _b_next: int = 0
var _b_live: int = 0


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
	_w_strength.resize(WARD_CAP)
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
	_p_ang.resize(PRIM_CAP)
	_p_span.resize(PRIM_CAP)
	_r_caster.resize(TRAIL_CAP)
	_r_dash.resize(TRAIL_CAP)
	_r_fx.resize(TRAIL_CAP)
	_r_bats.resize(TRAIL_CAP)
	_r_spawned.resize(TRAIL_CAP)
	_r_last.resize(TRAIL_CAP)
	_r_fade.resize(TRAIL_CAP)
	_r_path.resize(TRAIL_CAP * TRAIL_POINTS)
	_r_head.resize(TRAIL_CAP)
	_r_count.resize(TRAIL_CAP)
	_s_swarm.resize(SWARM_CAP)
	_s_caster.resize(SWARM_CAP)
	_s_fx.resize(SWARM_CAP)
	_s_age.resize(SWARM_CAP)
	_s_out.resize(SWARM_CAP)
	_s_phase.resize(SWARM_CAP * SWARM_BATS_BROOD)
	_s_speed.resize(SWARM_CAP * SWARM_BATS_BROOD)
	_s_reach.resize(SWARM_CAP * SWARM_BATS_BROOD)
	_a_axe.resize(AXE_CAP)
	_a_fx.resize(AXE_CAP)
	_a_caster.resize(AXE_CAP)
	_a_angle.resize(AXE_CAP)
	_a_spin.resize(AXE_CAP)
	_a_prop.resize(AXE_CAP)
	_st_host.resize(STUN_CAP)
	_st_age.resize(STUN_CAP)
	_st_life.resize(STUN_CAP)
	_st_col.resize(STUN_CAP)
	_b_mob.resize(BAND_CAP)
	_b_age.resize(BAND_CAP)
	_b_life.resize(BAND_CAP)
	_b_rx.resize(BAND_CAP)
	_b_col.resize(BAND_CAP)


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
	var t0: int = Time.get_ticks_usec()
	# Lasting programs start even out of view (they may come into view).
	if fx.cue in LASTING_CAST_CUES:
		programs_played += 1
		match fx.cue:
			&"axe":
				_start_axe(c, ability as ThrownAxe, fx)
			&"swarm":
				_start_swarm(c, ability as NightSwarm, fx)
		_cost_usec += Time.get_ticks_usec() - t0
		return
	if not in_view(c.global_position):
		culled += 1
		return
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
		&"cleave":
			_play_cleave(c, ability as BullFrontCleave, fx)
		&"screech":
			_play_screech(c, ability as BullFrontCleave, fx)
	_cost_usec += Time.get_ticks_usec() - t0


func _on_damage_applied(packet: DamagePacket) -> void:
	if packet == null:
		return
	if packet.ability == null:
		_on_swing_landed(packet)
		return
	var fx := packet.ability.fx
	if fx == null or fx.cue not in HIT_CUES:
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
	_play_hit(source, target, fx)
	_cost_usec += Time.get_ticks_usec() - t0


## A hit that carries no ability (a mob's bite or claw, Ted's fox's bite):
## the swinging character's CharacterRig.swing_fx over the target, only while
## that rig plays_moves() (on screen, inside the rig budget: the attack move
## plays with it). Off screen or over the budget nothing is drawn and nothing
## is counted; VfxManager's impact star stays either way.
func _on_swing_landed(packet: DamagePacket) -> void:
	var target: Node2D = packet.target as Node2D if is_instance_valid(packet.target) else null
	var source: Node2D = packet.source as Node2D if is_instance_valid(packet.source) else null
	if target == null or source == null or not in_view(target.global_position):
		return
	var rig := source.get_node_or_null(^"Rig") as CharacterRig
	if rig == null or rig.swing_fx == null or rig.swing_fx.cue not in HIT_CUES or not rig.plays_moves():
		return
	var t0: int = Time.get_ticks_usec()
	programs_played += 1
	swings_played += 1
	_play_hit(source, target, rig.swing_fx)
	_cost_usec += Time.get_ticks_usec() - t0


func _play_hit(source: Node2D, target: Node2D, fx: AbilityFxRecipe) -> void:
	match fx.cue:
		&"strike":
			_play_strike(source, target, fx)
		&"claw":
			_play_claw(source, target, fx)
		&"sniper":
			_play_tracer(source, target, fx)
		&"bite":
			_play_bite(source, target, fx)


func _on_ability_event(source: Node, ability: AbilityBase, event: StringName, pos: Vector2, value: float) -> void:
	var t0: int = Time.get_ticks_usec()
	var fx: AbilityFxRecipe = ability.fx if ability != null else null
	var s := source as Node2D
	if event == FxEvents.SCATTERED:
		# The scattered bats shed what rode her body, in view or not: the
		# taunt's tether and anger vein (the chart dropped the taunt and the
		# stun), stun stars. Its one-shot burst plays below, in view only.
		_end_riders(source)
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
		FxEvents.DASH_STARTED:
			_start_trail(s, ability as BullRamDash, pos, value, fx)
		FxEvents.DASH_TURNED:
			_turn_trail(s, pos, value, fx)
		FxEvents.DASH_ENDED:
			_end_trail(s, fx)
		FxEvents.STUNNED:
			_start_stun(s, value, fx)
		FxEvents.RECRUITED:
			_start_band(s as MobBase, value, fx)
		FxEvents.SLAM_LEAP:
			_play_slam_leap(s, ability as BullGroundSlam, pos, value, fx)
		# One-shot monster moments only in view (a re-form where the bats were
		# or where she lands).
		FxEvents.SLAM_LANDED, FxEvents.RAMPAGE, FxEvents.SCATTERED, FxEvents.REFORMED, FxEvents.CC_SHRUGGED:
			if s == null or not (in_view(s.global_position) or (event == FxEvents.REFORMED and in_view(pos))):
				culled += 1
				return
			programs_played += 1
			match event:
				FxEvents.SLAM_LANDED:
					if fx != null and fx.cue == &"stomp":
						_play_stomp_landed(pos, value, fx)
					else:
						_play_slam_landed(pos, value, fx)
				FxEvents.RAMPAGE:
					_play_rampage(s, fx)
				FxEvents.SCATTERED:
					_play_scatter(s, fx)
				FxEvents.REFORMED:
					_play_reform(s, pos, fx)
				FxEvents.CC_SHRUGGED:
					_play_shrug(s, fx)
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
	_end_riders(entity)


## Ends everything that rides `entity` (marks, tethers to or from it, its
## ward, halo, stun stars and warband ring): it died, or its body scattered
## into bats (Vampiric Rebirth).
func _end_riders(entity: Node) -> void:
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
	for i in STUN_CAP:
		if _st_host[i] == id:
			_st_life[i] = minf(_st_life[i], _st_age[i] + 0.1)
	for i in BAND_CAP:
		if _b_mob[i] == id:
			_b_life[i] = minf(_b_life[i], _b_age[i] + 0.1)


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


## A bite (the generic one of the Bat and Ted's fox): two jaws snap shut over
## the target's body, from above and below, tilted toward the biter's side
## (at most BITE_TILT), their fangs interlocking; gone within FLASH_LIFE.
func _play_bite(source: Node2D, target: Node2D, fx: AbilityFxRecipe) -> void:
	var to := CharacterRig.mid_body_of(target)
	var dir := (to - CharacterRig.mid_body_of(source)).normalized()
	var tilt: float = clampf(dir.y * signf(dir.x if dir.x != 0.0 else 1.0) + _rng.randf_range(-0.15, 0.15),
			-BITE_TILT, BITE_TILT)
	var w: float = BITE_WIDTH * fx.size
	var down := Vector2.DOWN.rotated(tilt)
	var gap: float = BITE_GAP * w
	var col: Color = _palette.color(fx.accent)
	for k in 2:
		var side: float = -1.0 if k == 0 else 1.0
		var jaw: int = over.spawn(FxTex.BITE, to + down * gap * side, w, w, FLASH_LIFE, col,
				FxSpriteBuffer.Anim.POP, tilt if side < 0.0 else tilt + PI)
		over.vel[jaw] = -down * side * gap * BITE_SNAP
		over.drag[jaw] = BITE_SNAP


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
	_w_strength[slot] = shield.get_shield_percent()
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
	_rocks(pos, 3, 8.0)
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
# Monster cast programs (EventBus.ability_cast)
# ============================================

## Front Cleave / Cleaver Chop: the cone flashes on the ground (a cone
## telegraph), a big slash crescent cuts through it at body height
## (FLASH_LIFE) and dust kicks up at its far edge. Whirlwind (a full-circle
## cleave): a circle telegraph, four slashes spinning all around, a ring at
## the reach and dust at the rim. The crescents sit outside the caster's
## drawn body (_body_edge plus CLEAVE_CLEAR of the reach): the reach stays
## 80 px while a Stage III body grows to 50 px either side and 133 px tall,
## so the old spot at half the reach was the monster's own face.
func _play_cleave(c: Node2D, cleave: BullFrontCleave, fx: AbilityFxRecipe) -> void:
	if cleave == null:
		return
	var ang: float = _facing(c)
	var monster := c as MonsterBase
	var reach: float = (cleave.cone_range + (monster.get_range_bonus() if monster != null else 0.0)) * fx.size
	var accent := _palette.color(fx.accent)
	var feet := c.global_position
	var swing := feet.lerp(CharacterRig.mid_body_of(c), 0.6)
	var clear: float = _body_edge(c, swing, ang) + reach * CLEAVE_CLEAR
	_telegraph_cone(feet, ang, cleave.cone_angle, reach, CONE_FLASH, accent)
	if cleave.cone_angle >= BullFrontCleave.FULL_CIRCLE:
		for k in 4:
			var a: float = ang + TAU * float(k) / 4.0
			var out: float = maxf(reach * 0.55, _body_edge(c, swing, a) + reach * CLEAVE_CLEAR)
			var slash: int = over.spawn(FxTex.SLASH, swing + Vector2.from_angle(a) * out, reach * 0.6,
					reach * 0.6, FLASH_LIFE, accent, FxSpriteBuffer.Anim.SWEEP, a)
			over.spin[slash] = 9.0
		_ring(feet, reach * 0.4, reach, 3.0, accent, 0.3)
		_dust(feet, 3, 10.0 * fx.size, reach * 0.9)
	else:
		var slash: int = over.spawn(FxTex.SLASH, swing + Vector2.from_angle(ang) * maxf(reach * 0.5, clear), reach * 0.85,
				reach * 0.85, FLASH_LIFE, accent, FxSpriteBuffer.Anim.SWEEP, ang + _rng.randf_range(-0.15, 0.15))
		over.flip[slash] = 1.0 if _rng.randf() < 0.5 else -1.0
		_dust(feet + Vector2.from_angle(ang) * reach * 0.8, 2, 9.0 * fx.size, 18.0)
	_shake(fx.trauma)


## How far `c`'s drawn body reaches from `from` (a point inside it, the
## swing point) along `angle`: its half-width to either side and downward
## (targets in front of its feet stand close), growing to the way up to its
## head top as the angle turns upward (a quarter ellipse), where a target
## stands behind the tall body. 0 for a node without a rig.
func _body_edge(c: Node2D, from: Vector2, angle: float) -> float:
	var half: float = CharacterRig.half_width_of(c)
	var d := Vector2.from_angle(angle)
	if half <= 0.0 or d.y >= 0.0:
		return half
	var up: float = maxf(from.y - CharacterRig.head_top_of(c).y, half)
	return 1.0 / sqrt(d.x * d.x / (half * half) + d.y * d.y / (up * up))


## Sonic Screech: three ink-rimmed sound arcs roll out of Nyxa's body
## through the cone (staggered, gone in 0.3 s each) over its cone telegraph.
func _play_screech(c: Node2D, cone: BullFrontCleave, fx: AbilityFxRecipe) -> void:
	if cone == null:
		return
	var ang: float = _facing(c)
	var reach: float = cone.cone_range * fx.size
	var half: float = deg_to_rad(minf(cone.cone_angle, 359.0)) * 0.5
	var from := CharacterRig.mid_body_of(c)
	_telegraph_cone(c.global_position, ang, cone.cone_angle, reach, CONE_FLASH, _palette.color(fx.accent))
	for k in 3:
		var i: int = _prim(Prim.ARC, 0.3, 0.07 * float(k))
		_p_pos[i] = from
		_p_a[i] = reach * 0.15
		_p_b[i] = reach * (0.75 + 0.1 * float(k))
		_p_w[i] = minf(3.0 - 0.5 * float(k), MAX_RING_WIDTH)
		_p_ang[i] = ang
		_p_span[i] = half
		_p_col[i] = _palette.color(fx.accent)
		_p_col2[i] = _palette.color(fx.core)
	_shake(fx.trauma)


# ============================================
# Monster event programs (EventBus.ability_event)
# ============================================

## SLAM_LEAP (Ground Slam, Warcry Stomp): the landing circle fills over the
## airtime (VfxManager.telegraph), dust kicks up where he takes off; the
## stomp's war cry pops a "!" over his head for the airtime.
func _play_slam_leap(c: Node2D, slam: BullGroundSlam, landing: Vector2, airtime: float, fx: AbilityFxRecipe) -> void:
	if c == null or not (in_view(landing) or in_view(c.global_position)):
		culled += 1
		return
	programs_played += 1
	var r: float = fx.radius if fx != null and fx.radius > 0.0 else (slam.slam_radius if slam != null else 120.0)
	var accent := _palette.color(fx.accent if fx != null else &"danger")
	if telegraphs != null:
		telegraphs.telegraph(landing, r, airtime, accent)
	_dust(c.global_position, 2, 10.0, 22.0)
	if fx != null and fx.cue == &"stomp":
		_mark(c, FxTex.BANG, 16.0, maxf(airtime, 0.3), accent, Vector2(0.0, -10.0))


## SLAM_LANDED (Ground Slam): a crack left in the ground, a shockwave ring out
## to the radius and a darker one after it, four dust clouds rolling out,
## four rocks thrown up, a star at the centre (FLASH_LIFE) and the trauma.
func _play_slam_landed(pos: Vector2, radius: float, fx: AbilityFxRecipe) -> void:
	var accent := _palette.color(fx.accent if fx != null else &"danger")
	var core := _palette.color(fx.core if fx != null else &"text")
	_decal(FxTex.CRACK, pos, minf(radius * 0.9, 150.0), fx.decal_life if fx != null else 3.0, Color(_ink, 0.5))
	_ring(pos, radius * 0.15, radius, 3.0, accent, 0.35)
	_ring(pos, radius * 0.1, radius * 0.75, 2.0, _palette.color(fx.shade if fx != null else &"ink"), 0.4, 0.06)
	_dust(pos, 4, 12.0, radius * 0.9)
	_rocks(pos, 4, 8.0)
	over.spawn(FxTex.STAR, pos + Vector2(0.0, -6.0), 26.0, 16.0, FLASH_LIFE, core, FxSpriteBuffer.Anim.POP, _rng.randf() * TAU)
	_shake(fx.trauma if fx != null else 0.0)


## SLAM_LANDED (Warcry Stomp): a double war-cry ring out to the stun radius,
## a small crack, three dust clouds; every stunned target gets its stars from
## STUNNED.
func _play_stomp_landed(pos: Vector2, radius: float, fx: AbilityFxRecipe) -> void:
	_ring(pos, radius * 0.2, radius, 3.0, _palette.color(fx.accent), 0.35)
	_ring(pos, radius * 0.15, radius * 0.7, 2.0, _palette.color(fx.shade), 0.35, 0.08)
	_decal(FxTex.CRACK, pos, minf(radius * 0.5, 80.0), fx.decal_life, Color(_ink, 0.4))
	_dust(pos, 3, 11.0, radius * 0.7)
	_rocks(pos, 2, 7.0)
	_shake(fx.trauma)


## RAMPAGE (Grount): a hero kill reset his cooldowns and healed him: a blood
## ring and a darker one at his feet, an anger vein over his head, four sparks
## rising (the cooldowns back) and a star on his body; the "+N" is
## VfxManager's.
func _play_rampage(m: Node2D, fx: AbilityFxRecipe) -> void:
	var accent := _palette.color(fx.accent if fx != null else &"danger")
	var feet := m.global_position
	_ring(feet, 10.0, 60.0, 3.0, accent, 0.4)
	_ring(feet, 8.0, 44.0, 2.0, _palette.color(fx.shade if fx != null else &"ink"), 0.4, 0.08)
	_mark(m, FxTex.ANGER, 18.0, 0.9, accent, Vector2(10.0, -2.0))
	_sparks_up(CharacterRig.mid_body_of(m), 4, _palette.color(fx.alt if fx != null else &"amber"), 16.0)
	over.spawn(FxTex.STAR, CharacterRig.mid_body_of(m), 22.0, 14.0, FLASH_LIFE,
			_palette.color(fx.core if fx != null else &"text"), FxSpriteBuffer.Anim.POP, _rng.randf() * TAU)
	_shake(fx.trauma if fx != null else 0.0)


## SCATTERED (Vampiric Rebirth): the lethal hit bursts her into six bats that
## fly off, three shade puffs where her body was and a ring at her feet.
func _play_scatter(m: Node2D, fx: AbilityFxRecipe) -> void:
	var mid := CharacterRig.mid_body_of(m)
	var accent := _palette.color(fx.accent if fx != null else &"monster2")
	for k in 6:
		var a: float = TAU * float(k) / 6.0 + _rng.randf_range(-0.3, 0.3)
		var b: int = over.spawn(FxTex.BAT, mid + Vector2.from_angle(a) * 6.0, swarm_bat_size, swarm_bat_size,
				0.6, accent, FxSpriteBuffer.Anim.FLY, 0.0)
		over.vel[b] = Vector2.from_angle(a) * _rng.randf_range(90.0, 140.0) + Vector2(0.0, -50.0)
		over.flip[b] = 1.0 if cos(a) >= 0.0 else -1.0
		over.drag[b] = 1.5
	_puffs(m.global_position, 3, 10.0, 20.0, 30.0, Color(_palette.color(fx.shade if fx != null else &"monster2_dark"), 0.8))
	_ring(m.global_position, 6.0, 40.0, 2.0, accent, 0.3)


## REFORMED (Vampiric Rebirth): six bats fly from where the bats were
## (`from`) into her body at the re-form point, a streak bows along the jump
## when she moved; as they arrive a ring, a star and three puffs.
func _play_reform(m: Node2D, from: Vector2, fx: AbilityFxRecipe) -> void:
	var to := CharacterRig.mid_body_of(m)
	var start := from + (to - m.global_position)
	var accent := _palette.color(fx.accent if fx != null else &"monster2")
	for k in 6:
		var a: float = TAU * float(k) / 6.0 + _rng.randf_range(-0.3, 0.3)
		var p: Vector2 = start + Vector2.from_angle(a) * _rng.randf_range(18.0, 30.0)
		var b: int = over.spawn(FxTex.BAT, p, swarm_bat_size, swarm_bat_size, REFORM_TRAVEL, accent,
				FxSpriteBuffer.Anim.FLY, 0.0, 0.03 * float(k))
		over.vel[b] = (to - p) / REFORM_TRAVEL
		over.flip[b] = 1.0 if to.x >= p.x else -1.0
	if start.distance_to(to) > 24.0:
		var i: int = _prim(Prim.BEAM, REFORM_TRAVEL + 0.1)
		_p_pos[i] = start
		_p_pos2[i] = to
		_p_a[i] = 2.0
		_p_b[i] = clampf(start.distance_to(to) * 0.2, 8.0, 40.0)
		_p_col[i] = accent
		_p_col2[i] = _palette.color(fx.core if fx != null else &"text")
	var arrive: float = REFORM_TRAVEL + 0.03 * 5.0
	_ring(m.global_position, 6.0, 46.0, 3.0, accent, 0.35, arrive)
	over.spawn(FxTex.STAR, to, 20.0, 12.0, FLASH_LIFE, _palette.color(fx.core if fx != null else &"text"),
			FxSpriteBuffer.Anim.POP, _rng.randf() * TAU, arrive)
	_puffs(m.global_position, 3, 10.0, 18.0, 26.0, Color(_palette.color(fx.shade if fx != null else &"monster2_dark"), 0.8), arrive)


## CC_SHRUGGED (Unstoppable): a taunt or a cage that cannot hold him breaks
## off: five shards fly off his body, a ring at his feet, a star.
func _play_shrug(m: Node2D, fx: AbilityFxRecipe) -> void:
	var accent := _palette.color(fx.accent if fx != null else &"monster3_light")
	var mid := CharacterRig.mid_body_of(m)
	for k in 5:
		var a: float = TAU * float(k) / 5.0 + _rng.randf_range(-0.25, 0.25)
		var sh: int = over.spawn(FxTex.SHARD, mid + Vector2.from_angle(a) * 10.0, 9.0, 7.0, 0.4, accent,
				FxSpriteBuffer.Anim.FLY, a)
		over.vel[sh] = Vector2.from_angle(a) * 90.0 + Vector2(0.0, -40.0)
		over.grav[sh] = 260.0
		over.spin[sh] = 9.0
	_ring(m.global_position, 8.0, _foot_radius(m) * 2.2, 3.0, accent, 0.35)
	over.spawn(FxTex.STAR, mid, 18.0, 12.0, FLASH_LIFE, _palette.color(fx.core if fx != null else &"text"),
			FxSpriteBuffer.Anim.POP, _rng.randf() * TAU)


# ============================================
# Monster lasting programs (followed every frame)
# ============================================

## DASH_STARTED (Ram Dash, Shadow Swoop): the lane to the end point at the
## hit radius (VfxManager.telegraph_lane; Trample's 70 px lane reads wider)
## and a trail that follows the caster while it dashes: dust and speed lines
## for the bull, a streak and peeling bats for Nyxa (the recipe's cue).
func _start_trail(c: Node2D, dash: BullRamDash, end: Vector2, hit_radius: float, fx: AbilityFxRecipe) -> void:
	if c == null or dash == null:
		return
	var id: int = c.get_instance_id()
	var slot: int = -1
	for i in TRAIL_CAP:
		if _r_caster[i] == id:
			slot = i
	if slot < 0:
		slot = _r_next
		_r_next = (_r_next + 1) % TRAIL_CAP
	if _r_caster[slot] == 0:
		_r_live += 1
	var bats: bool = fx != null and fx.cue == &"swoop"
	_r_caster[slot] = id
	_r_dash[slot] = dash
	_r_fx[slot] = fx
	_r_bats[slot] = 1 if bats else 0
	_r_spawned[slot] = 0
	_r_last[slot] = c.global_position
	_r_fade[slot] = 0.0
	_r_head[slot] = 0
	_r_count[slot] = 0
	_trail_point(slot, CharacterRig.mid_body_of(c))
	if not (in_view(c.global_position) or in_view(end)):
		culled += 1
		return
	programs_played += 1
	var accent := _palette.color(fx.accent if fx != null else &"danger")
	if telegraphs != null:
		telegraphs.telegraph_lane(c.global_position, end, hit_radius,
				c.global_position.distance_to(end) / maxf(dash.dash_speed, 1.0), accent)
	if not bats:
		_dust(c.global_position, 2, 10.0, 20.0)
		_r_spawned[slot] = 2


## DASH_TURNED (Echo Strike): the swoop turns at its end and runs back along
## its lane: a new lane telegraph back, a small ring and two bats at the turn.
func _turn_trail(c: Node2D, end: Vector2, hit_radius: float, fx: AbilityFxRecipe) -> void:
	var slot: int = _trail_of(c)
	if slot < 0 or not (in_view(c.global_position) or in_view(end)):
		return
	programs_played += 1
	var dash: BullRamDash = _r_dash[slot]
	var accent := _palette.color(fx.accent if fx != null else &"monster2")
	if telegraphs != null:
		telegraphs.telegraph_lane(c.global_position, end, hit_radius,
				c.global_position.distance_to(end) / maxf(dash.dash_speed, 1.0), accent)
	_ring(c.global_position, 6.0, 30.0, 2.0, accent, 0.3)
	if _r_bats[slot] == 1:
		_r_spawned[slot] = 0  # TRAIL_BATS a pass
	for k in 2:
		var side: float = -1.0 if k == 0 else 1.0
		var b: int = over.spawn(FxTex.BAT, CharacterRig.mid_body_of(c), swarm_bat_size, swarm_bat_size, 0.45, accent,
				FxSpriteBuffer.Anim.FLY)
		over.vel[b] = Vector2(side * 80.0, -60.0)
		over.flip[b] = side
	_r_last[slot] = c.global_position


## DASH_ENDED: the bull skids to a stop (a last dust cloud within the cast's
## MAX_PUFFS, the recipe's trauma); Nyxa's streak just fades. The trail fades
## once its dash no longer runs (_step_trails).
func _end_trail(c: Node2D, fx: AbilityFxRecipe) -> void:
	var slot: int = _trail_of(c)
	if slot < 0 or _r_bats[slot] == 1 or not in_view(c.global_position):
		return
	if _r_spawned[slot] < MAX_PUFFS:
		_dust(c.global_position, 1, 12.0, 16.0)
		_r_spawned[slot] += 1
	_shake(fx.trauma if fx != null else 0.0)


func _trail_of(c: Node2D) -> int:
	if c == null:
		return -1
	var id: int = c.get_instance_id()
	for i in TRAIL_CAP:
		if _r_caster[i] == id:
			return i
	return -1


## Appends a point to the slot's path ring (TRAIL_POINTS, oldest dropped).
func _trail_point(slot: int, p: Vector2) -> void:
	_r_path[slot * TRAIL_POINTS + _r_head[slot]] = p
	_r_head[slot] = (_r_head[slot] + 1) % TRAIL_POINTS
	_r_count[slot] = mini(_r_count[slot] + 1, TRAIL_POINTS)


## Night Swarm cast: the swarm takes its caster's slot if it has one (a
## recast), else the next one round robin; every bat gets its own orbit phase,
## speed and radius share from the private RNG.
func _start_swarm(c: Node2D, swarm: NightSwarm, fx: AbilityFxRecipe) -> void:
	if swarm == null or not swarm.is_active():
		return
	var id: int = c.get_instance_id()
	var slot: int = -1
	for i in SWARM_CAP:
		if _s_swarm[i] != null and _s_caster[i] == id:
			slot = i
	if slot < 0:
		slot = _s_next
		_s_next = (_s_next + 1) % SWARM_CAP
	if _s_swarm[slot] == null:
		_s_live += 1
	_s_swarm[slot] = swarm
	_s_caster[slot] = id
	_s_fx[slot] = fx
	_s_age[slot] = 0.0
	_s_out[slot] = 0.0
	for k in SWARM_BATS_BROOD:
		var j: int = slot * SWARM_BATS_BROOD + k
		_s_phase[j] = TAU * float(k) / float(SWARM_BATS_BROOD) + _rng.randf_range(-0.25, 0.25)
		_s_speed[j] = _rng.randf_range(0.8, 1.25)
		_s_reach[j] = _rng.randf_range(0.75, 1.0)


## Tusk Axe cast: the axe takes its caster's slot if it has one, else the next
## one round robin. It spins clockwise thrown to the right, counter-clockwise
## to the left; the recipe's prop_part (the axe in his hand) hides meanwhile.
func _start_axe(c: Node2D, axe: ThrownAxe, fx: AbilityFxRecipe) -> void:
	if axe == null or not axe.is_flying():
		return
	var id: int = c.get_instance_id()
	var slot: int = -1
	for i in AXE_CAP:
		if _a_axe[i] != null and _a_caster[i] == id:
			slot = i
	if slot < 0:
		slot = _a_next
		_a_next = (_a_next + 1) % AXE_CAP
	if _a_axe[slot] == null:
		_a_live += 1
	else:
		_show_prop(slot)
	_a_axe[slot] = axe
	_a_fx[slot] = fx
	_a_caster[slot] = id
	_a_angle[slot] = axe.direction().angle()
	_a_spin[slot] = TAU * axe_turns_per_second * (1.0 if axe.direction().x >= 0.0 else -1.0)
	_a_prop[slot] = 0
	var prop := _prop_of(c, fx.prop_part)
	if prop != null and prop.visible:
		prop.visible = false
		_a_prop[slot] = prop.get_instance_id()


## The rig sprite `part` of `c`'s body (RigBody.part), or null.
func _prop_of(c: Node2D, part: StringName) -> Node2D:
	if part == &"":
		return null
	var rig := c.get_node_or_null(^"Rig") as CharacterRig
	return rig.body.part(part) if rig != null and rig.body != null else null


## Shows the slot's hidden rig part again (the axe is back in his hand).
func _show_prop(slot: int) -> void:
	var prop := instance_from_id(_a_prop[slot]) as Node2D
	if prop != null:
		prop.visible = true
	_a_prop[slot] = 0


## STUNNED (Stunning Charge, Disorienting Dive, Concussive Axe, Warcry
## Stomp): three stars circle above the stunned entity's head while the stun
## lasts; a longer stun on it extends its stars.
func _start_stun(e: Node2D, seconds: float, fx: AbilityFxRecipe) -> void:
	var entity := e as EntityBase
	if e == null or (entity != null and not entity.is_alive()):
		return
	var id: int = e.get_instance_id()
	var col := _palette.color(fx.alt if fx != null else &"gold")
	for i in STUN_CAP:
		if _st_host[i] == id:
			_st_life[i] = maxf(_st_life[i], _st_age[i] + seconds)
			return
	var slot: int = _st_next
	_st_next = (_st_next + 1) % STUN_CAP
	if _st_host[slot] == 0:
		_st_live += 1
	_st_host[slot] = id
	_st_age[slot] = 0.0
	_st_life[slot] = maxf(seconds, 0.3)
	_st_col[slot] = col


## RECRUITED (Call of the Herd): a ring at the mob's feet in the stomp's
## accent while it fights in the warband (MobBase.is_in_warband), and a "!"
## over its head as it joins.
func _start_band(mob: MobBase, seconds: float, fx: AbilityFxRecipe) -> void:
	if mob == null:
		return
	var id: int = mob.get_instance_id()
	var slot: int = -1
	for i in BAND_CAP:
		if _b_mob[i] == id:
			slot = i
	if slot < 0:
		slot = _b_next
		_b_next = (_b_next + 1) % BAND_CAP
	if _b_mob[slot] == 0:
		_b_live += 1
	var col := _palette.color(fx.accent if fx != null else &"monster3_light")
	_b_mob[slot] = id
	_b_age[slot] = 0.0
	_b_life[slot] = maxf(seconds, 0.3)
	_b_rx[slot] = _foot_radius(mob) * 1.1
	_b_col[slot] = col
	if in_view(mob.global_position):
		programs_played += 1
		_mark(mob, FxTex.BANG, 14.0, 0.5, col, Vector2(0.0, -8.0))


func _telegraph_cone(apex: Vector2, angle: float, spread_deg: float, reach: float, life: float, col: Color) -> void:
	if telegraphs != null:
		telegraphs.telegraph_cone(apex, angle, spread_deg, reach, life, col)


## The facing of `c` in radians: an entity's hidden facing carrier (the
## Sprite2D its abilities aim with), else 0 (right).
func _facing(c: Node2D) -> float:
	var e := c as EntityBase
	return e.sprite.rotation if e != null and e.sprite != null else 0.0


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


## `n` rocks (in their own stone colours) thrown up from `p`, falling back.
func _rocks(p: Vector2, n: int, size: float) -> void:
	for k in n:
		var a: float = -PI * 0.5 + _rng.randf_range(-1.1, 1.1)
		var rock: int = over.spawn(FxTex.ROCK, p, size, size, 0.5, Color.WHITE, FxSpriteBuffer.Anim.FLY, _rng.randf() * TAU)
		over.vel[rock] = Vector2.from_angle(a) * _rng.randf_range(90.0, 150.0)
		over.grav[rock] = 380.0
		over.spin[rock] = _rng.randf_range(-9.0, 9.0)



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
	_step_trails(delta)
	_step_swarms(delta)
	_step_axes(delta)
	_step_stuns(delta)
	_step_bands(delta)
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
	return _p_live_over > 0 or _t_live > 0 or over.live > 0 or marks.live > 0 or stakes_front.live > 0 \
			or _r_live > 0 or _s_live > 0 or _a_live > 0 or _st_live > 0


func _ground_live() -> bool:
	return _p_live_ground > 0 or _w_live > 0 or _h_live > 0 or _c_live > 0 or under.live > 0 or stakes_back.live > 0 \
			or _s_live > 0 or _b_live > 0


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
		var shield := instance_from_id(_w_shield[i]) as Shield
		if shield != null:
			_w_strength[i] = shield.get_shield_percent()
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


## Follows every trailed dash: a path point every TRAIL_SAMPLE px and, in
## view, a dust cloud and two speed lines (the bull) or a peeling bat (Nyxa)
## every TRAIL_STEP_* px; once the dash stopped the trail fades over
## TRAIL_FADE and frees its slot.
func _step_trails(delta: float) -> void:
	if _r_live == 0:
		return
	_r_live = 0
	for i in TRAIL_CAP:
		if _r_caster[i] == 0:
			continue
		var c := instance_from_id(_r_caster[i]) as Node2D
		if c == null or not c.is_inside_tree():
			_free_trail(i)
			continue
		_r_live += 1
		if _r_fade[i] > 0.0:
			_r_fade[i] -= delta
			if _r_fade[i] <= 0.0:
				_free_trail(i)
				_r_live -= 1
			continue
		var dash: BullRamDash = _r_dash[i]
		if dash == null or not dash.is_dashing:
			_r_fade[i] = TRAIL_FADE
			continue
		var mid := CharacterRig.mid_body_of(c)
		var newest: Vector2 = _r_path[i * TRAIL_POINTS + (_r_head[i] + TRAIL_POINTS - 1) % TRAIL_POINTS]
		if mid.distance_squared_to(newest) >= TRAIL_SAMPLE * TRAIL_SAMPLE:
			_trail_point(i, mid)
		var feet := c.global_position
		var step: float = TRAIL_STEP_BATS if _r_bats[i] == 1 else TRAIL_STEP_DUST
		if feet.distance_squared_to(_r_last[i]) < step * step:
			continue
		var back: Vector2 = (_r_last[i] - feet).normalized()
		_r_last[i] = feet
		if not in_view(feet):
			continue
		if _r_bats[i] == 1:
			_trail_bat(i, mid, back)
		else:
			_trail_dust(i, feet, mid, back, dash)


func _free_trail(i: int) -> void:
	_r_caster[i] = 0
	_r_dash[i] = null
	_r_fx[i] = null


## One step of the bull's trail: a dust cloud behind him (under Trample at the
## wide lane's edges, side to side) within the cast's MAX_PUFFS, one kept for
## the skid, and two speed lines at body height.
func _trail_dust(i: int, feet: Vector2, mid: Vector2, back: Vector2, dash: BullRamDash) -> void:
	var fx: AbilityFxRecipe = _r_fx[i]
	if _r_spawned[i] < MAX_PUFFS - 1:
		var side := Vector2.ZERO
		if dash.trample:
			side = back.orthogonal() * dash.get_hit_radius() * 0.6 * (1.0 if _r_spawned[i] % 2 == 0 else -1.0)
		var d: int = over.spawn(FxTex.DUST, feet + back * 10.0 + side, 10.0, 21.0 if dash.trample else 17.0,
				_rng.randf_range(0.35, 0.5), Color.WHITE, FxSpriteBuffer.Anim.GROW, _rng.randf() * TAU)
		over.vel[d] = back * 20.0 + Vector2(0.0, -8.0)
		over.drag[d] = 3.0
		_r_spawned[i] += 1
	var accent := _palette.color(fx.accent if fx != null else &"danger")
	var core := _palette.color(fx.core if fx != null else &"text")
	for k in 2:
		var off: Vector2 = back.orthogonal() * (9.0 if k == 0 else -9.0)
		var l: int = _prim(Prim.TRACER, 0.16)
		_p_pos[l] = mid + off + back * 36.0
		_p_pos2[l] = mid + off + back * 16.0
		_p_a[l] = 2.0
		_p_col[l] = accent
		_p_col2[l] = core


## One step of a Swoop's streak: a bat peels off it, TRAIL_BATS a pass.
func _trail_bat(i: int, mid: Vector2, back: Vector2) -> void:
	if _r_spawned[i] >= TRAIL_BATS:
		return
	var fx: AbilityFxRecipe = _r_fx[i]
	var side: float = 1.0 if _r_spawned[i] % 2 == 0 else -1.0
	var b: int = over.spawn(FxTex.BAT, mid + back * 14.0, swarm_bat_size * 0.8, swarm_bat_size * 0.8, 0.5,
			_palette.color(fx.accent if fx != null else &"monster2"), FxSpriteBuffer.Anim.FLY)
	over.vel[b] = back.orthogonal() * side * 70.0 + back * 30.0 + Vector2(0.0, -40.0)
	over.flip[b] = 1.0 if over.vel[b].x >= 0.0 else -1.0
	_r_spawned[i] += 1


## Follows each swarm's caster; a swarm that ended fades out over SWARM_FADE
## (its bats flying wider), then frees its slot, as does a lost caster.
func _step_swarms(delta: float) -> void:
	if _s_live == 0:
		return
	_s_live = 0
	for i in SWARM_CAP:
		var swarm: NightSwarm = _s_swarm[i]
		if swarm == null:
			continue
		var c := instance_from_id(_s_caster[i]) as Node2D
		if c == null or not c.is_inside_tree():
			_free_swarm(i)
			continue
		_s_age[i] += delta
		if _s_out[i] > 0.0:
			_s_out[i] -= delta
			if _s_out[i] <= 0.0:
				_free_swarm(i)
				continue
		elif not swarm.is_active():
			_s_out[i] = SWARM_FADE
		_s_live += 1


func _free_swarm(i: int) -> void:
	_s_swarm[i] = null
	_s_fx[i] = null
	_s_caster[i] = 0


## A swarm's alpha: fading in over SWARM_FADE, out once it ended.
func _swarm_alpha(i: int) -> float:
	var a: float = clampf(_s_age[i] / SWARM_FADE, 0.0, 1.0)
	if _s_out[i] > 0.0:
		a *= _s_out[i] / SWARM_FADE
	return a


## 0..1: how far the bats dive in, peaking on each bite (one every
## tick_interval from the cast) over SWARM_DIVE_SHARE of the interval.
func _swarm_bite(i: int, swarm: NightSwarm) -> float:
	var tick: float = maxf(swarm.tick_interval, 0.05)
	var phase: float = fposmod(_s_age[i], tick) / tick
	var d: float = clampf(1.0 - minf(phase, 1.0 - phase) / (SWARM_DIVE_SHARE * 0.5), 0.0, 1.0)
	return d * d * (3.0 - 2.0 * d)


## Where bat `k` of swarm slot `i` flies: circling `center` (swarm_center) at
## its share of `radius`, diving in on a bite, flying wider while
## the swarm fades out.
func _swarm_bat(i: int, k: int, center: Vector2, radius: float, bite: float) -> Vector2:
	var j: int = i * SWARM_BATS_BROOD + k
	var a: float = _s_phase[j] + _s_age[i] * swarm_orbit_speed * _s_speed[j]
	var r: float = radius * _s_reach[j] * lerpf(1.0, SWARM_DIVE, bite)
	if _s_out[i] > 0.0:
		r *= 1.0 + 0.6 * (1.0 - _s_out[i] / SWARM_FADE)
	return center + Vector2.from_angle(a) * r


## Spins every flying axe. One back in his hand (or dropped, or whose thrower
## is gone) shows his hand's axe again, a catch spark at his body, and frees
## its slot.
func _step_axes(delta: float) -> void:
	if _a_live == 0:
		return
	_a_live = 0
	for i in AXE_CAP:
		var axe: ThrownAxe = _a_axe[i]
		if axe == null:
			continue
		var c := instance_from_id(_a_caster[i]) as Node2D
		if c == null or not c.is_inside_tree() or not axe.is_flying():
			_show_prop(i)
			if c != null and c.is_inside_tree() and in_view(c.global_position):
				var fx: AbilityFxRecipe = _a_fx[i]
				over.spawn(FxTex.SPARK, CharacterRig.mid_body_of(c), 14.0, 8.0, 0.2,
						_palette.color(fx.core if fx != null else &"text"), FxSpriteBuffer.Anim.POP)
			_a_axe[i] = null
			_a_fx[i] = null
			continue
		_a_live += 1
		_a_angle[i] = wrapf(_a_angle[i] + _a_spin[i] * delta, -PI, PI)


## Stun stars end with the stun (it may be cleared early: Guardian Angel),
## their entity or their life.
func _step_stuns(delta: float) -> void:
	if _st_live == 0:
		return
	_st_live = 0
	for i in STUN_CAP:
		if _st_host[i] == 0:
			continue
		_st_age[i] += delta
		var e := instance_from_id(_st_host[i]) as Node2D
		var entity := e as EntityBase
		if e == null or not e.is_inside_tree() or _st_age[i] >= _st_life[i] \
				or (entity != null and not entity.is_stunned()):
			_st_host[i] = 0
			continue
		_st_live += 1


## Warband rings end when the mob leaves the warband, dies or is pooled.
func _step_bands(delta: float) -> void:
	if _b_live == 0:
		return
	_b_live = 0
	for i in BAND_CAP:
		if _b_mob[i] == 0:
			continue
		_b_age[i] += delta
		var mob := instance_from_id(_b_mob[i]) as MobBase
		if mob == null or not mob.is_inside_tree() or _b_age[i] >= _b_life[i] or not mob.is_in_warband():
			_b_mob[i] = 0
			continue
		_b_live += 1


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
			Prim.ARC:
				_draw_arc(i, k)
	_draw_tethers()
	_draw_trails()
	stakes_front.draw(self)
	over.draw(self)
	_draw_swarms()
	_draw_axes()
	marks.draw(self)
	_draw_stuns()
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
	_paint_swarms(ci)
	_paint_bands(ci)
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


## A sound arc rolling out through its cone: ink under the accent, at most
## MAX_RING_WIDTH wide.
func _draw_arc(i: int, k: float) -> void:
	var r: float = lerpf(_p_a[i], _p_b[i], FxEase.out_cubic(k))
	var w: float = _p_w[i] * (1.0 - 0.4 * k)
	var a: float = 1.0 if k < 0.6 else (1.0 - k) / 0.4
	var half: float = _p_span[i] * (0.6 + 0.4 * k)
	var ang: float = _p_ang[i]
	draw_arc(_p_pos[i], r, ang - half, ang + half, 18, Color(_ink, a * 0.85), w, true)
	draw_arc(_p_pos[i], r, ang - half, ang + half, 18, Color(_p_col[i], a), w * 0.55, true)


## Each Swoop's streak: a tapered, ink-rimmed ribbon along its last path
## points (the newest widest), fading with the trail. While the dash runs it
## reaches her body where she is drawn: the monster moves in its own _process,
## after this node sampled the path.
func _draw_trails() -> void:
	if _r_live == 0:
		return
	for i in TRAIL_CAP:
		if _r_caster[i] == 0 or _r_bats[i] == 0 or _r_count[i] < 1:
			continue
		var n: int = _r_count[i]
		var base: int = i * TRAIL_POINTS
		var oldest: int = (_r_head[i] + TRAIL_POINTS - n) % TRAIL_POINTS
		var newest: Vector2 = _r_path[base + (_r_head[i] + TRAIL_POINTS - 1) % TRAIL_POINTS]
		var head := newest
		var c := instance_from_id(_r_caster[i]) as Node2D
		if _r_fade[i] <= 0.0 and c != null:
			head = CharacterRig.mid_body_of(c)
		var segs: int = n - 1 + (1 if head.distance_squared_to(newest) > 1.0 else 0)
		if segs < 1 or not in_view(head):
			continue
		var fx: AbilityFxRecipe = _r_fx[i]
		var a: float = 1.0 if _r_fade[i] <= 0.0 else _r_fade[i] / TRAIL_FADE
		var col := _palette.color(fx.accent if fx != null else &"monster2")
		for pass_i in 2:
			for k in segs:
				var t: float = float(k + 1) / float(segs)
				var w: float = 1.0 + 6.0 * t
				var p0: Vector2 = _r_path[base + (oldest + k) % TRAIL_POINTS]
				var p1: Vector2 = head if k == n - 1 else _r_path[base + (oldest + k + 1) % TRAIL_POINTS]
				if pass_i == 0:
					draw_line(p0, p1, Color(_ink, a * t * 0.8), w + 2.0, true)
				else:
					draw_line(p0, p1, Color(col, a * t), w, true)


## Each swarm in view: its bats circling over its ring (swarm_center),
## flapping (their height squashed in a beat), in the recipe's accent; more
## under Brood Mother.
func _draw_swarms() -> void:
	if _s_live == 0:
		return
	var tex: Texture2D = FxTex.BAT
	var ts: Vector2 = tex.get_size()
	var sc: float = swarm_bat_size / maxf(ts.x, ts.y)
	for i in SWARM_CAP:
		var swarm: NightSwarm = _s_swarm[i]
		if swarm == null:
			continue
		var c := instance_from_id(_s_caster[i]) as Node2D
		if c == null or not in_view(c.global_position):
			continue
		var fx: AbilityFxRecipe = _s_fx[i]
		var col := Color(_palette.color(fx.accent if fx != null else &"monster2"), _swarm_alpha(i))
		var center := swarm_center(c)
		var radius: float = maxf(swarm.area_of_effect, 1.0)
		var bite: float = _swarm_bite(i, swarm)
		for k in (SWARM_BATS_BROOD if swarm.is_permanent() else SWARM_BATS):
			var j: int = i * SWARM_BATS_BROOD + k
			var flap: float = 0.55 + 0.45 * absf(sin(_s_age[i] * 20.0 + _s_phase[j] * 3.0))
			draw_set_transform(_swarm_bat(i, k, center, radius, bite), 0.0, Vector2(sc, sc * flap))
			draw_texture(tex, -ts * 0.5, col)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Each flying axe at its axe_position, axe_size px, untinted, after two
## fading ghosts at its last angles (the spin's blur).
func _draw_axes() -> void:
	if _a_live == 0:
		return
	var tex: Texture2D = FxTex.AXE
	var ts: Vector2 = tex.get_size()
	var sc: float = axe_size / maxf(ts.x, ts.y)
	for i in AXE_CAP:
		var axe: ThrownAxe = _a_axe[i]
		if axe == null or not in_view(axe.axe_position):
			continue
		for g in range(2, -1, -1):
			draw_set_transform(axe.axe_position, _a_angle[i] - _a_spin[i] * 0.03 * float(g), Vector2(sc, sc))
			draw_texture(tex, -ts * 0.5, Color(Color.WHITE, 1.0 if g == 0 else 0.4 / float(g * g)))
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Three stars circling above each stunned head (the far ones smaller).
func _draw_stuns() -> void:
	if _st_live == 0:
		return
	var tex: Texture2D = FxTex.STAR
	var ts: Vector2 = tex.get_size()
	var sc: float = STUN_STAR_SIZE / maxf(ts.x, ts.y)
	for i in STUN_CAP:
		if _st_host[i] == 0:
			continue
		var e := instance_from_id(_st_host[i]) as Node2D
		if e == null or not in_view(e.global_position):
			continue
		var top := stun_centre(e)
		var a: float = clampf(_st_age[i] / 0.12, 0.0, 1.0) * clampf((_st_life[i] - _st_age[i]) / 0.15, 0.0, 1.0)
		for k in 3:
			var ang: float = _st_age[i] * STUN_SPIN + TAU * float(k) / 3.0
			var depth: float = 0.75 + 0.25 * sin(ang)
			draw_set_transform(top + Vector2(cos(ang) * STUN_ORBIT, sin(ang) * STUN_ORBIT * 0.35), ang,
					Vector2(sc * depth, sc * depth))
			draw_texture(tex, -ts * 0.5, Color(_st_col[i], a))
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Each swarm's bite area on the ground: an ink and accent ring at the
## swarm's radius at the telegraph alpha, fading with the swarm.
func _paint_swarms(ci: CanvasItem) -> void:
	if _s_live == 0:
		return
	for i in SWARM_CAP:
		var swarm: NightSwarm = _s_swarm[i]
		if swarm == null:
			continue
		var c := instance_from_id(_s_caster[i]) as Node2D
		if c == null or not in_view(c.global_position):
			continue
		var fx: AbilityFxRecipe = _s_fx[i]
		var a: float = _swarm_alpha(i) * VfxManager.TELEGRAPH_ALPHA
		var r: float = maxf(swarm.area_of_effect, 1.0)
		ci.draw_arc(c.global_position, r, 0.0, TAU, 64, Color(_ink, a), 2.0, true)
		ci.draw_arc(c.global_position, r, 0.0, TAU, 64, Color(_palette.color(fx.accent if fx != null else &"monster2"), a * 2.0), 1.0, true)


## Each warband mob: a ring at its feet in the stomp's accent, breathing.
func _paint_bands(ci: CanvasItem) -> void:
	if _b_live == 0:
		return
	for i in BAND_CAP:
		if _b_mob[i] == 0:
			continue
		var mob := instance_from_id(_b_mob[i]) as Node2D
		if mob == null or not in_view(mob.global_position):
			continue
		var a: float = clampf(_b_age[i] / 0.2, 0.0, 1.0) * clampf((_b_life[i] - _b_age[i]) / 0.3, 0.0, 1.0)
		_paint_foot_ring(ci, mob.global_position, _b_rx[i] * (1.0 + 0.06 * sin(_b_age[i] * 5.0)), Color(_b_col[i], 0.9 * a))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


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
		var pulse: float = _w_pulse[i] / WARD_PULSE
		var rx: float = _w_rx[i] * FxEase.pop(minf(_w_age[i] / WARD_POP, 1.0)) * (1.0 + 0.2 * pulse)
		var col: Color = _w_col[i].lerp(_palette.white, pulse)
		_paint_foot_ring(ci, hero.global_position, rx, Color(col, _ward_alpha(i)))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Ward slot `i`'s alpha: the shield's strength, the last one it had while it
## lived (an expired shield is freed the frame it expires: a ward read as 1.0
## from then on brightened just as it faded), times the fade-out.
func _ward_alpha(i: int) -> float:
	var a: float = 0.45 + 0.45 * _w_strength[i]
	if _w_out[i] > 0.0:
		a *= _w_out[i] / maxf(_w_out_len[i], 0.01)
	return a


## The alpha the ward at `hero`'s feet is painted with now (-1 = none).
func ward_alpha(hero: Node2D) -> float:
	var i: int = _ward_of(hero)
	return _ward_alpha(i) if i >= 0 else -1.0


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


## The widest live ring or sound-arc line (world px).
func widest_ring() -> float:
	var w: float = 0.0
	for i in PRIM_CAP:
		if _p_kind[i] == Prim.RING or _p_kind[i] == Prim.ARC:
			w = maxf(w, _p_w[i])
	return w


func trails_live() -> int:
	return _r_live


func swarms_live() -> int:
	return _s_live


func axes_live() -> int:
	return _a_live


func stuns_live() -> int:
	return _st_live


## The centre of the stun stars' orbit over `host`: STUN_LIFT above the top
## of its drawn body.
static func stun_centre(host: Node2D) -> Vector2:
	return CharacterRig.head_top_of(host) + Vector2(0.0, -STUN_LIFT)


## The lowest y (world px) a stun star over `host` reaches: the front of the
## orbit, where a star is drawn at full size.
static func stun_lowest_y(host: Node2D) -> float:
	return stun_centre(host).y + STUN_ORBIT * 0.35 + STUN_STAR_SIZE * 0.5


func bands_live() -> int:
	return _b_live


## The spin angle (radians) of the axe drawn for `axe`; NAN when none is.
func axe_angle(axe: ThrownAxe) -> float:
	for i in AXE_CAP:
		if _a_axe[i] == axe:
			return _a_angle[i]
	return NAN


## Where the bats of `swarm` fly now (empty when it is not shown).
func swarm_bats(swarm: NightSwarm) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in SWARM_CAP:
		if _s_swarm[i] != swarm or swarm == null:
			continue
		var c := instance_from_id(_s_caster[i]) as Node2D
		if c == null:
			continue
		var bite: float = _swarm_bite(i, swarm)
		for k in (SWARM_BATS_BROOD if swarm.is_permanent() else SWARM_BATS):
			out.append(_swarm_bat(i, k, swarm_center(c), maxf(swarm.area_of_effect, 1.0), bite))
	return out


## What a swarm's bats circle: SWARM_LIFT_SHARE of the way from `caster`'s
## feet to its body.
static func swarm_center(caster: Node2D) -> Vector2:
	return caster.global_position.lerp(CharacterRig.mid_body_of(caster), SWARM_LIFT_SHARE)


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


## F3 overlay line: programs played and culled, the mob and fox swings among
## them, pool use against the caps and this node's script time last frame.
func debug_line() -> String:
	return "Ability FX %d  culled %d  swings %d  sprites %d/%d  marks %d/%d  stakes %d  prims %d/%d\n    tethers %d  wards %d  halos %d  cages %d  trails %d  swarms %d  axes %d  stuns %d  warband %d  %.2f ms" % [
			programs_played, culled, swings_played, over.live, OVER_CAP, marks.live, MARK_CAP,
			stakes_front.live + stakes_back.live, _p_live_ground + _p_live_over, PRIM_CAP,
			_t_live, _w_live, _h_live, _c_live, _r_live, _s_live, _a_live, _st_live, _b_live,
			float(_cost_usec) / 1000.0]
