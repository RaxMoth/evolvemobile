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
##   - the authored move playing, if any, and its elapsed time.
## The entity's state chart stays the only state machine.
##
## Moves: authored one-shots (attack, cast, ultimate, hurt, cheer and the
## signature moves) from the body plan's AnimationLibrary, the profile's
## `moves` (Assets/Characters/_moves/<plan>_moves.tres). Their tracks address
## the body's parts ("%arm_f:rotation"; rest rotation is 0 in every generated
## body) and, through "..", this rig's root channels: `move_offset`,
## `move_scale`, `move_tilt`, `arm_f_reach` and `arm_b_reach`, so one library
## fits every character of the plan (a channel or part the body lacks is
## skipped). The rig samples the move itself (Animation.value_track_interpolate),
## after the procedural layer, and blends it over that layer: in over
## MOVE_BLEND_IN, out over the last MOVE_BLEND_OUT seconds, and only on the
## channels the move keys, so a cast that keys the arms leaves the legs walking.
## Which move a cast plays is the ability's get_move_name() (its `move_name`),
## falling back to attack, cast or ultimate by its slot; a mob's swing (no
## ability) plays attack. A move the library lacks falls back to the
## procedural swing.
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
##
## mid_body() (and the static mid_body_of) is the middle of the drawn body, the
## origin and end of line, beam and projectile EFFECTS: the entity's position
## is its feet. head_top() (head_top_of) is the top of the drawn body, where a
## lasting status mark floats.

enum Tier { FULL, BUDGETED }

const BUDGET := 48
## The shadow blob's full width over its dense core's (shadow_radius x 2).
const SHADOW_SPREAD := 1.5
## A frame step longer than this is a teleport, not a walk.
const MAX_STEP := 64.0
## head_top_of() of a node without an active rig: px above its position.
const HEAD_FALLBACK := 32.0
## Seconds an authored move takes to blend in over the procedural pose, and to
## hand back to it at its end.
const MOVE_BLEND_IN := 0.06
const MOVE_BLEND_OUT := 0.12
## The parts a move can rotate, in channel order ("legs" = a flyer's dangling
## feet, which only moves animate).
const LIMB_NAMES: Array[StringName] = [&"body", &"head", &"arm_f", &"arm_b", &"leg_f", &"leg_b",
	&"wing_f", &"wing_b", &"tail", &"legs"]
## Root channels after the limbs: "..:<name>" tracks of a move.
const ROOT_CHANNELS: Array[StringName] = [&"move_offset", &"move_scale", &"move_tilt", &"arm_f_reach", &"arm_b_reach"]
const CH_OFFSET := 10
const CH_SCALE := 11
const CH_TILT := 12
const CH_REACH_F := 13
const CH_REACH_B := 14

@export var body: RigBody
@export var profile: RigProfile
@export var tier: Tier = Tier.BUDGETED
## The character it animates when that is not an EntityBase parent (Ted's pet:
## ".." in TedsPet.tscn). Empty: the parent if it is an EntityBase, else puppet
## mode.
@export var mover: Node2D
## The ground contact shadow: a Sprite2D child drawn before the body (the
## "Shadow" of NPCBaseClass.tscn, wired scene-side) holding the white blob
## Assets/Characters/shadow_blob.svg. _ready tints it with the palette's ink at
## shadow_alpha and sizes it to shadow_radius once; it stays on the ground
## while the body bounces or hovers. Hidden while the rig is inert.
@export var shadow: Sprite2D
## The ink's alpha at the shadow's core.
@export_range(0.0, 1.0) var shadow_alpha: float = 0.55
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
## Root channels of the move playing (sampled from its "..:" tracks; rest
## values otherwise). Art units, x forward and y down; a squash about the
## feet; a forward lean in radians; the front and back arms' offsets from their
## rest positions (a weapon thrust to the sky).
var move_offset := Vector2.ZERO
var move_scale := Vector2.ONE
var move_tilt := 0.0
var arm_f_reach := Vector2.ZERO
var arm_b_reach := Vector2.ZERO

## Half the width of the shadow's dense core in world px, before the entity's
## own scale (the shadow grows with an evolving monster like the body); the
## soft rim reaches SHADOW_SPREAD times further. Set in _ready from the body
## and profile (shadow_radius_for): 0 while the rig is inert or the profile
## asks for no shadow.
var shadow_radius := 0.0
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
## The authored move playing (null = none), its name and elapsed seconds.
var _move: Animation = null
var _move_name: StringName = &""
var _move_t := 0.0
var _move_channels: PackedInt32Array = PackedInt32Array()
## The move's limb rotations this frame (NAN = the move does not key it).
var _move_rot: PackedFloat32Array = PackedFloat32Array()

var _torso: Node2D
var _head: Node2D
var _arm_f: Node2D
var _arm_b: Node2D
var _leg_f: Node2D
var _leg_b: Node2D
var _wing_f: Node2D
var _wing_b: Node2D
var _tail: Node2D
var _legs: Node2D
var _rest_rot: PackedFloat32Array = PackedFloat32Array()
var _rest_pos: PackedVector2Array = PackedVector2Array()
var _limbs: Array[Node2D] = []
# What _pose last wrote (NAN = unknown: write next time). Most of a camp idles,
# where most channels hold still, and every write re-propagates a part's
# transform, so unchanged values are not written again. 64-bit so a held value
# compares equal to the one computed again.
var _cur_rot: PackedFloat64Array = PackedFloat64Array()
var _cur_body_pos := Vector2(NAN, NAN)
var _cur_body_scale := Vector2(NAN, NAN)
var _cur_body_rot := NAN
var _cur_torso_x := NAN
var _cur_head_y := NAN


func _ready() -> void:
	if body == null:
		for c in get_children():
			if c is RigBody:
				body = c
				break
	_active = body != null and profile != null
	if _active:
		shadow_radius = shadow_radius_for(body, profile)
	if shadow:
		shadow.visible = _active and shadow_radius > 0.0
	if not _active:
		# NOTIFICATION_READY switched processing on (the script has a _process).
		set_process(false)
		return
	var palette := UiPalette.get_default()
	_flash_color = palette.white * hurt_flash_gain
	_flash_color.a = 1.0
	if shadow and shadow.texture:
		shadow.modulate = Color(palette.ink, shadow_alpha)
		shadow.scale = Vector2.ONE * (2.0 * shadow_radius * SHADOW_SPREAD / shadow.texture.get_width())
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


## The contact shadow's core radius for a body drawn with `p`: the art's width
## (RigBody.bounds) in world px x the profile's shadow_per_width. One rule for
## the match and the menus' RigView, so a new character needs no hand-tuned
## number.
static func shadow_radius_for(b: RigBody, p: RigProfile) -> float:
	return b.bounds.size.x * p.world_scale * p.shadow_per_width


## World px the entity travels per full step cycle: the profile's stride (at
## world_scale) x the rig's own +-4 % size x the entity's scale, because the
## legs grow with both (an evolved Grount at 1.5x takes 1.5x longer steps).
## Read every frame, so a growing monster's feet stay planted mid-tween.
func walk_stride() -> float:
	return profile.stride * _size * maxf(absf(global_scale.x), 0.01)


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
	if _move:
		_end_move()
	if _flashing:
		body.modulate = Color.WHITE
		_flashing = false


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
	_legs = body.part(&"legs")
	# LIMB_NAMES order: a move's limb channel is the index into _limbs.
	_limbs = [_torso, _head, _arm_f, _arm_b, _leg_f, _leg_b, _wing_f, _wing_b, _tail, _legs]
	_move_rot.resize(_limbs.size())
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
	_cur_body_pos = Vector2(NAN, NAN)
	_cur_body_scale = Vector2(NAN, NAN)
	_cur_body_rot = NAN


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
## A cast always replaces the move playing (the latest action wins).
func _on_entity_ability_cast(ability: AbilityBase, _target: Node) -> void:
	if not _on_screen:
		return
	if not _start_move(move_for(ability, _entity)):
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


## Puppet / emote entry point (menus, result screen, previews): the move
## `move` from `at` seconds in (a pose sheet freezes a puppet there with
## set_process(false)). A move the library lacks plays the procedural swing.
func play_move(move: StringName, at: float = 0.0) -> void:
	if not _active:
		return
	if not _start_move(move, at):
		_act = profile.attack_time


## The hurt reaction (flash and squash), for entities via `damaged` and for
## puppets directly, plus the hurt move when no other move is playing (a
## flinch never cuts a swing or a cast short).
func play_hurt() -> void:
	if not _active:
		return
	_hurt = profile.hurt_time
	if _move == null:
		_start_move(&"hurt")


## True when this rig's library has `move`.
func has_move(move: StringName) -> bool:
	return _active and profile.moves != null and profile.moves.has_animation(move)


## The move playing (&"" = none).
func current_move() -> StringName:
	return _move_name


## The move a cast of `ability` plays: its get_move_name() when the library
## has it, else attack, cast or ultimate by its slot (null = a mob's swing:
## attack). The caster lets an ability pick by its state (River's weapon).
func move_for(ability: AbilityBase, caster: Node = null) -> StringName:
	if ability == null:
		return &"attack"
	var named := ability.get_move_name(caster)
	if named != &"" and has_move(named):
		return named
	return default_move(ability.ability_type)


## The body plan's generic move for an ability slot.
static func default_move(ability_type: AbilityBase.AbilityType) -> StringName:
	match ability_type:
		AbilityBase.AbilityType.BASIC_ATTACK:
			return &"attack"
		AbilityBase.AbilityType.ULTIMATE:
			return &"ultimate"
	return &"cast"


## Starts `move` at `at` seconds (replacing any move playing); false when the
## library lacks it.
func _start_move(move: StringName, at: float = 0.0) -> bool:
	if not has_move(move):
		return false
	if _move:
		_end_move()
	_move = profile.moves.get_animation(move)
	_move_name = move
	_move_t = clampf(at, 0.0, _move.length)
	_move_channels = channels_of(_move)
	_act = 0.0
	_pose()
	return true


## The move is over (or cut): the root channels back at rest, every part back
## at its generated pose, and the procedural layer writes all of them again.
func _end_move() -> void:
	_move = null
	_move_name = &""
	_move_t = 0.0
	move_offset = Vector2.ZERO
	move_scale = Vector2.ONE
	move_tilt = 0.0
	arm_f_reach = Vector2.ZERO
	arm_b_reach = Vector2.ZERO
	body.reset_pose()
	_forget_pose()


## The channel each track of `anim` drives: a LIMB_NAMES index for a
## "%<part>:rotation" track, CH_OFFSET.. for a "..:<root channel>" track, -1
## for anything else (ignored). Parsed when a move starts (a dozen tracks).
static func channels_of(anim: Animation) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(anim.get_track_count())
	for i in anim.get_track_count():
		out[i] = -1
		if anim.track_get_type(i) != Animation.TYPE_VALUE:
			continue
		var path := anim.track_get_path(i)
		if path.get_name_count() != 1:
			continue
		var node_name := String(path.get_name(0))
		var prop := StringName(path.get_concatenated_subnames())
		if node_name.begins_with("%") and prop == &"rotation":
			out[i] = LIMB_NAMES.find(StringName(node_name.substr(1)))
		elif node_name == "..":
			var root := ROOT_CHANNELS.find(prop)
			if root >= 0:
				out[i] = CH_OFFSET + root
	return out


## Weight of the move over the procedural pose at its time: eases in over
## MOVE_BLEND_IN, out over the last MOVE_BLEND_OUT seconds.
func _move_weight() -> float:
	if _move == null:
		return 0.0
	var w := minf(clampf(_move_t / MOVE_BLEND_IN, 0.0, 1.0), clampf((_move.length - _move_t) / MOVE_BLEND_OUT, 0.0, 1.0))
	return w * w * (3.0 - 2.0 * w)


## Samples the move at its time: the root channels into the move_* vars, the
## limbs into _move_rot (NAN = not keyed).
func _sample_move() -> void:
	_move_rot.fill(NAN)
	for i in _move_channels.size():
		var ch := _move_channels[i]
		if ch < 0:
			continue
		var v: Variant = _move.value_track_interpolate(i, _move_t)
		if ch < CH_OFFSET:
			_move_rot[ch] = float(v)
		elif ch == CH_OFFSET:
			move_offset = v
		elif ch == CH_SCALE:
			move_scale = v
		elif ch == CH_TILT:
			move_tilt = float(v)
		elif ch == CH_REACH_F:
			arm_f_reach = v
		elif ch == CH_REACH_B:
			arm_b_reach = v


# ---------------------------------------------------------- anchors ----

## The middle of the drawn body in global coordinates (the art's box centre,
## raised by a flyer's mean hover, at the rig's size and the entity's scale):
## where a line, beam or projectile EFFECT starts or ends on this character.
## Presentation only; gameplay positions stay the entity's (its feet).
func mid_body() -> Vector2:
	var y := body.bounds.get_center().y
	if profile.body_plan == RigProfile.BodyPlan.FLYER:
		y -= profile.hover
	return to_global(Vector2(0.0, y * profile.world_scale * _size))


## mid_body() of `node`'s Rig when it has an active one (heroes, monsters,
## mobs, Ted's pet), else the node's own position (a trap, a mine).
static func mid_body_of(node: Node2D) -> Vector2:
	var rig := node.get_node_or_null(^"Rig") as CharacterRig
	if rig and rig._active:
		return rig.mid_body()
	return node.global_position


## The top of the drawn body in global coordinates (the art box's top edge,
## raised by a flyer's mean hover, at the rig's size and the entity's scale):
## where a lasting status mark (a taunt's anger vein, a "!") floats, clear of
## the head. Presentation only.
func head_top() -> Vector2:
	var y := body.bounds.position.y
	if profile.body_plan == RigProfile.BodyPlan.FLYER:
		y -= profile.hover
	return to_global(Vector2(0.0, y * profile.world_scale * _size))


## head_top() of `node`'s Rig when it has an active one, else HEAD_FALLBACK
## px above the node's own position.
static func head_top_of(node: Node2D) -> Vector2:
	var rig := node.get_node_or_null(^"Rig") as CharacterRig
	if rig and rig._active:
		return rig.head_top()
	return node.global_position + Vector2(0.0, -HEAD_FALLBACK)


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
		if step > 0.0:
			_walk_phase += step / walk_stride() * PI
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
	if _move:
		_move_t += dt
		if _move_t >= _move.length:
			_end_move()
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
	# The move's root channels at its blend weight (rest when none plays).
	var w := _move_weight()
	if _move:
		_sample_move()
		# Every part channel is rewritten this frame: the procedural value
		# first, then the move blended over the channels it keys.
		_forget_pose()
	var off := move_offset * w
	var body_pos := Vector2(off.x * _flip, lift + off.y) * k
	if body_pos != _cur_body_pos:
		_cur_body_pos = body_pos
		body.position = body_pos
	var body_scale := Vector2(_flip * (1.0 + squash), 1.0 - squash) * (k / body.sheet_scale) * Vector2.ONE.lerp(move_scale, w)
	if body_scale != _cur_body_scale:
		_cur_body_scale = body_scale
		body.scale = body_scale
	var body_rot := move_tilt * w * _flip
	if body_rot != _cur_body_rot:
		_cur_body_rot = body_rot
		body.rotation = body_rot
	if hurt_k > 0.0:
		body.modulate = Color.WHITE.lerp(_flash_color, hurt_k)
		_flashing = true
	elif _flashing:
		body.modulate = Color.WHITE
		_flashing = false
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
	if _legs:
		moved = _rot(9, 0.0) or moved
	if _move:
		_blend_move(w, s)
		moved = true
	if moved:
		body.sync_proxies()


## The move over the procedural pose just written: each limb it keys toward
## its sampled angle, the arms' reach offsets, all at weight `w`.
func _blend_move(w: float, s: float) -> void:
	for i in _limbs.size():
		var a := _move_rot[i]
		var limb := _limbs[i]
		if limb == null or is_nan(a):
			continue
		limb.rotation = lerpf(limb.rotation, a, w)
	if _arm_f:
		_arm_f.position = _rest_pos[2] + arm_f_reach * (s * w)
	if _arm_b:
		_arm_b.position = _rest_pos[3] + arm_b_reach * (s * w)


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
