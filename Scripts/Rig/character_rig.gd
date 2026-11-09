class_name CharacterRig
extends Node2D

## Animates one RigBody from what its entity DOES. It is the "Rig" node of
## NPCBaseClass.tscn: every entity has one, and a character scene migrated to
## SVG art adds its <id>_body.tscn under it and sets `body` and `profile`. A rig
## without a body (a character still on its AnimatedSprite2D) stays inert: it
## never wakes, draws nothing and ignores every event.
##
## Read-only towards gameplay: it reads the entity's position, its facing
## carrier (the hidden Sprite2D whose rotation the abilities aim with) and
## listens to the entity's presentation signals (wired scene-side in
## NPCBaseClass.tscn and monster_base_class.tscn). It never writes entity
## state and never touches the global RNG, so tools/sim_trace.sh stays
## byte-identical with every rig awake (RIGS_AWAKE=1).
##
## Not a state machine: the pose is a pure function of
##   - locomotion: distance travelled (step phase, feet never slide) and speed,
##   - time (breathing, wing beats; per-instance phase from a private RNG),
##   - decaying one-shot timers started by events (hurt, procedural attack),
##   - an authored move playing on `moves` (AnimationPlayer; limbs are left to
##     it while it plays, the root keeps flipping and hovering).
## The entity's state chart stays the only state machine.
##
## LOD: it processes only while the entity's ScreenNotifier reports it on
## screen (seeded in _ready, toggled by the scene-wired signals). BUDGETED rigs
## (mobs) animate every other frame, staggered, while more than BUDGET rigs are
## awake, so a zoomed-out view of 200+ mobs stays cheap. Heroes and the
## monster set tier FULL. No allocation per frame, and only the pose channels
## that changed are written (an idle camp mostly holds still).
##
## A character that is not an EntityBase (Ted's pet) points `mover` at itself
## and gives the rig the same three things scene-side: the hidden facing
## "Sprite2D", a unique ScreenNotifier wired to the rig, and optionally
## ability_cast / damaged signals wired to the event handlers.
##
## Without an entity (menus, previews) it runs in puppet mode: always awake,
## facing right, `puppet_speed` walks it in place, play_move() for emotes.

enum Tier { FULL, BUDGETED }

const BUDGET := 48
## A frame step longer than this is a teleport, not a walk.
const MAX_STEP := 64.0

@export var body: RigBody
@export var profile: RigProfile
## Optional authored one-shots (AnimationLibrary tracks on "%part:prop").
@export var moves: AnimationPlayer
@export var tier: Tier = Tier.BUDGETED
## The character it animates when that is not an EntityBase parent (Ted's pet:
## ".." in TedsPet.tscn). Empty: the parent if it is an EntityBase, else puppet
## mode.
@export var mover: Node2D
## Ground shadow radius in world px (0 = none), drawn once under the body in
## the palette's ink at shadow_alpha.
@export var shadow_radius: float = 14.0
@export_range(0.0, 1.0) var shadow_alpha: float = 0.28
## Hit flash: the body's modulate at the start of a hurt reaction is the
## palette's white times this gain (an over-bright modulate).
@export var hurt_flash_gain: float = 2.1
## Puppet mode only: world px/s it walks in place (0 = idle).
@export var puppet_speed: float = 0.0

static var _awake: int = 0
## Every rig animates whatever the notifiers say. Tool switch (tools/sim_trace.sh
## RIGS_AWAKE=1, tools/bench.sh rigs_awake=1): awake rigs must leave the match
## byte-identical.
static var force_awake: bool = false

var _active := false
## The character whose position and facing carrier drive the pose (null = puppet).
var _entity: Node2D = null
var _facing: Node2D = null
var _on_screen := false
var _t := 0.0
var _phase := 0.0
var _rate := 1.0
var _size := 1.0
var _stagger := 0
var _skipped := 0.0
var _walk := 0.0
var _walk_phase := 0.0
var _flip := 1.0
var _last_pos := Vector2.ZERO
var _hurt := 0.0
var _act := 0.0
var _flashing := false
var _flash_color := Color.WHITE
var _shadow_color := Color.TRANSPARENT

var _torso: Node2D
var _head: Node2D
var _arm_f: Node2D
var _arm_b: Node2D
var _leg_f: Node2D
var _leg_b: Node2D
var _wing_f: Node2D
var _wing_b: Node2D
var _tail: Node2D
var _rest_rot: PackedFloat32Array = PackedFloat32Array()
var _rest_pos: PackedVector2Array = PackedVector2Array()
var _limbs: Array[Node2D] = []
# What _pose last wrote (NAN = unknown: write next time). Most of a camp idles,
# where most channels hold still, and every write re-propagates a part's
# transform, so unchanged values are not written again. 64-bit so a held value
# compares equal to the one computed again.
var _cur_rot: PackedFloat64Array = PackedFloat64Array()
var _cur_body_y := NAN
var _cur_body_scale := Vector2(NAN, NAN)
var _cur_torso_x := NAN
var _cur_head_y := NAN


func _ready() -> void:
	if body == null:
		for c in get_children():
			if c is RigBody:
				body = c
				break
	_active = body != null and profile != null
	if not _active:
		# NOTIFICATION_READY switched processing on (the script has a _process).
		set_process(false)
		return
	var palette := UiPalette.get_default()
	_flash_color = palette.white * hurt_flash_gain
	_flash_color.a = 1.0
	_shadow_color = Color(palette.ink, shadow_alpha)
	# Individuality: phase, breathing rate and a +-4 % size, from a private RNG
	# (the global one drives gameplay).
	var rng := RandomNumberGenerator.new()
	rng.seed = get_instance_id()
	_phase = rng.randf() * TAU
	_rate = rng.randf_range(0.9, 1.1)
	_size = rng.randf_range(0.96, 1.04)
	_stagger = rng.randi() & 1
	_cache_parts()
	_entity = mover
	if _entity == null:
		_entity = get_parent() as EntityBase
	if _entity:
		_facing = _entity.get_node_or_null(^"Sprite2D") as Node2D
		_last_pos = _entity.global_position
		var notifier := _entity.get_node_or_null(^"%ScreenNotifier") as VisibleOnScreenNotifier2D
		set_on_screen(force_awake or (notifier != null and notifier.is_on_screen()))
	else:
		set_on_screen(true)
	_pose()
	queue_redraw()


## A pooled mob re-enters the tree without a new _ready: under the tools'
## force_awake switch nothing else would wake its rig again (on a device the
## notifier's screen_entered does).
func _enter_tree() -> void:
	if _active and force_awake:
		set_on_screen(true)


## Leaving the tree is either the end or a pooled mob being parked: drop the
## reactions in flight so the next life does not start mid-flash or mid-swing.
func _exit_tree() -> void:
	set_on_screen(false)
	if not _active:
		return
	_hurt = 0.0
	_act = 0.0
	_walk = 0.0
	_skipped = 0.0
	if moves and moves.is_playing():
		moves.stop()
		body.reset_pose()
		_forget_pose()
	if _flashing:
		body.modulate = Color.WHITE
		_flashing = false


func _draw() -> void:
	if not _active or shadow_radius <= 0.0:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.36))
	draw_circle(Vector2.ZERO, shadow_radius, _shadow_color)


func _cache_parts() -> void:
	_torso = body.part(&"body")
	_head = body.part(&"head")
	_arm_f = body.part(&"arm_f")
	_arm_b = body.part(&"arm_b")
	_leg_f = body.part(&"leg_f")
	_leg_b = body.part(&"leg_b")
	_wing_f = body.part(&"wing_f")
	_wing_b = body.part(&"wing_b")
	_tail = body.part(&"tail")
	_limbs = [_torso, _head, _arm_f, _arm_b, _leg_f, _leg_b, _wing_f, _wing_b, _tail]
	_rest_rot.resize(_limbs.size())
	_rest_pos.resize(_limbs.size())
	_cur_rot.resize(_limbs.size())
	for i in _limbs.size():
		if _limbs[i]:
			_rest_rot[i] = _limbs[i].rotation
			_rest_pos[i] = _limbs[i].position
	_forget_pose()


## The parts were moved by something else (an authored move, reset_pose):
## the next _pose writes every part channel again.
func _forget_pose() -> void:
	_cur_rot.fill(NAN)
	_cur_torso_x = NAN
	_cur_head_y = NAN


# ---------------------------------------------------------------- LOD ----

func set_on_screen(on: bool) -> void:
	var awake := on and _active
	# Always (re)apply: NOTIFICATION_READY switched processing on before _ready
	# (the script has a _process) while _on_screen still said false, so every
	# rig used to animate off screen.
	set_process(awake)
	if awake == _on_screen:
		return
	_on_screen = awake
	_awake += 1 if awake else -1
	if awake and _entity:
		_last_pos = _entity.global_position


func _on_screen_entered() -> void:
	set_on_screen(true)


func _on_screen_exited() -> void:
	if not force_awake:
		set_on_screen(false)


## Rigs animating right now (the bench's rigs_awake_mean).
static func awake_count() -> int:
	return _awake


## The half-rate rule: while more than BUDGET rigs are awake, a BUDGETED rig
## animates only on the frames of its stagger parity (it catches the skipped
## time up on the next one).
static func skips_frame(rig_tier: Tier, awake: int, frame: int, stagger: int) -> bool:
	return rig_tier == Tier.BUDGETED and awake > BUDGET and ((frame + stagger) & 1) == 1


# ------------------------------------------------------------- events ----

## EntityBase.ability_cast (scene-wired). `ability` null = a mob's basic swing.
func _on_entity_ability_cast(ability: AbilityBase, _target: Node) -> void:
	if not _on_screen:
		return
	var move := _move_for(ability)
	if moves and moves.has_animation(move):
		body.reset_pose()
		_forget_pose()
		moves.play(move)
		moves.seek(0.0, true)
		return
	_act = profile.attack_time


## EntityBase.damaged (scene-wired).
func _on_entity_damaged(_packet: DamagePacket) -> void:
	if _on_screen:
		play_hurt()


## MonsterBase.evolved (scene-wired in monster_base_class.tscn): the stage's
## parts, and on screen the evolution flash (the rig's take on the sprite's
## old stage tint; the stage SIZE stays the entity's root scale, which the rig
## inherits). Evolving off screen does not flash later when it wakes.
func set_stage(stage: int) -> void:
	if body == null:
		return
	body.set_stage(stage)
	if profile and _on_screen:
		_hurt = profile.hurt_time


## Puppet / emote entry point (menus, result screen, previews).
func play_move(move: StringName) -> void:
	if not _active:
		return
	if moves and moves.has_animation(move):
		body.reset_pose()
		_forget_pose()
		moves.play(move)
	else:
		_act = profile.attack_time


## The hurt reaction (flash and squash), for entities via `damaged` and for
## puppets directly.
func play_hurt() -> void:
	if _active:
		_hurt = profile.hurt_time


func _move_for(ability: AbilityBase) -> StringName:
	if ability == null:
		return &"attack"
	match ability.ability_type:
		AbilityBase.AbilityType.BASIC_ATTACK:
			return &"attack"
		AbilityBase.AbilityType.ULTIMATE:
			return &"ultimate"
	return &"cast"


# -------------------------------------------------------------- frame ----

func _process(delta: float) -> void:
	if skips_frame(tier, _awake, Engine.get_process_frames(), _stagger):
		_skipped += delta
		return
	var dt := delta + _skipped
	_skipped = 0.0
	_t += dt * _rate
	var speed := puppet_speed
	if _entity:
		var pos := _entity.global_position
		var step := pos.distance_to(_last_pos)
		_last_pos = pos
		if step > MAX_STEP:
			step = 0.0
		speed = step / maxf(dt, 0.0001)
		_walk_phase += step / profile.stride * PI
		if _facing:
			var c := cos(_facing.rotation)
			if c > 0.25:
				_flip = 1.0
			elif c < -0.25:
				_flip = -1.0
	else:
		_walk_phase += speed * dt / profile.stride * PI
	_walk = move_toward(_walk, clampf(speed / profile.full_speed, 0.0, 1.0), dt * 6.0)
	_hurt = maxf(_hurt - dt, 0.0)
	_act = maxf(_act - dt, 0.0)
	_pose()


func _pose() -> void:
	var p := profile
	var breathe := sin(_t * p.breathe_hz * TAU + _phase)
	var hurt_k := _hurt / p.hurt_time if p.hurt_time > 0.0 else 0.0
	var squash := breathe * p.breathe_amount * (1.0 - _walk) + hurt_k * p.hurt_squash
	var lift := 0.0
	if p.body_plan == RigProfile.BodyPlan.FLYER:
		lift = -p.hover * (1.0 + 0.35 * sin(_t * p.flap_hz * PI + _phase))
	else:
		lift = -absf(sin(_walk_phase)) * p.bounce * _walk
	var k := p.world_scale * _size
	var body_y := lift * k
	if body_y != _cur_body_y:
		_cur_body_y = body_y
		body.position = Vector2(0.0, body_y)
	var body_scale := Vector2(_flip * (1.0 + squash), 1.0 - squash) * (k / body.sheet_scale)
	if body_scale != _cur_body_scale:
		_cur_body_scale = body_scale
		body.scale = body_scale
	if hurt_k > 0.0:
		body.modulate = Color.WHITE.lerp(_flash_color, hurt_k)
		_flashing = true
	elif _flashing:
		body.modulate = Color.WHITE
		_flashing = false
	if moves and moves.is_playing():
		body.sync_proxies()
		_forget_pose()
		return
	var s := body.sheet_scale
	var step := sin(_walk_phase * 2.0)
	var atk := _attack_curve() if _act > 0.0 else 0.0
	# Only the parts this body has (a call per missing limb adds up over a
	# camp); `moved` = some part changed, so its proxies need a sync.
	var moved := false
	if _torso:
		moved = _rot(0, p.lean * _walk + atk * 0.15)
		var lunge := sin((1.0 - _act / maxf(p.attack_time, 0.001)) * PI) * p.attack_lunge * s if _act > 0.0 else 0.0
		var torso_x := _rest_pos[0].x + lunge
		if torso_x != _cur_torso_x:
			_cur_torso_x = torso_x
			_torso.position.x = torso_x
			moved = true
	if _head:
		var head_y := _rest_pos[1].y + breathe * p.head_bob * s * (1.0 - _walk)
		if head_y != _cur_head_y:
			_cur_head_y = head_y
			_head.position.y = head_y
			moved = true
	if _arm_f:
		moved = _rot(2, -step * p.arm_swing * _walk + atk) or moved
	if _arm_b:
		moved = _rot(3, step * p.arm_swing * _walk) or moved
	if _leg_f:
		moved = _rot(4, step * p.leg_swing * _walk) or moved
	if _leg_b:
		moved = _rot(5, -step * p.leg_swing * _walk) or moved
	if _wing_f or _wing_b:
		var flap := sin(_t * p.flap_hz * TAU + _phase) * p.flap_amount
		if _wing_f:
			moved = _rot(6, flap) or moved
		if _wing_b:
			moved = _rot(7, flap * 0.8) or moved
	if _tail:
		moved = _rot(8, sin(_t * 2.0 + _phase) * 0.12 + step * 0.2 * _walk) or moved
	if moved:
		body.sync_proxies()


## Limb i (it exists) at its rest angle + delta_rot; false when it already is.
func _rot(i: int, delta_rot: float) -> bool:
	var r := _rest_rot[i] + delta_rot
	if r == _cur_rot[i]:
		return false
	_cur_rot[i] = r
	_limbs[i].rotation = r
	return true


## Front-arm angle of the procedural attack: wind-up, strike, recover.
func _attack_curve() -> float:
	if _act <= 0.0:
		return 0.0
	var p := profile
	var k := 1.0 - _act / p.attack_time
	if k < 0.35:
		return lerpf(0.0, p.attack_windup, k / 0.35)
	if k < 0.6:
		return lerpf(p.attack_windup, p.attack_strike, (k - 0.35) / 0.25)
	return lerpf(p.attack_strike, 0.0, (k - 0.6) / 0.4)
