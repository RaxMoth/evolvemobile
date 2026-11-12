extends TestCase

## The authored rig moves (Assets/Characters/_moves, CharacterRig): one
## AnimationLibrary per body plan, picked by every motion profile's body plan
## (Grount and Gorrak stand upright: HUMANOID); every library has the generic
## moves and every track drives a known channel, as one-shots that start and
## end at rest; every ability's move exists in its caster's library; a cast
## plays it in a match while the rig still never writes its entity;
## mid_body() anchors line effects on the body, not the feet; the timed moves
## (7.4): a leap's landing marker stretches to the airtime its SLAM_LEAP
## reports, a dash's run loops while the dash goes on, only FULL rigs listen;
## Gorrak's spin is never drawn edge on, River's twirl never shows its
## unwind, no key gap shorter than a frame can be sampled half-way, and Ground
## Slam and the head channel settle without a snap; a dash in flight faces its
## way (Echo Strike's return pass); Grount's anchors follow his stage.
## test_rig_pipeline covers the sampling and blending on the fixture.

const ROOT := "res://Assets/Characters"
const MOVES_DIR := "res://Assets/Characters/_moves"
const PLAN_FILES: Dictionary[RigProfile.BodyPlan, String] = {
	RigProfile.BodyPlan.HUMANOID: "humanoid_moves.tres",
	RigProfile.BodyPlan.QUADRUPED: "quadruped_moves.tres",
	RigProfile.BodyPlan.FLYER: "flyer_moves.tres",
}
const BODY_PLANS: Dictionary[String, RigProfile.BodyPlan] = {
	"irelia": RigProfile.BodyPlan.HUMANOID, "river": RigProfile.BodyPlan.HUMANOID,
	"ted": RigProfile.BodyPlan.HUMANOID, "vlad": RigProfile.BodyPlan.HUMANOID,
	"gorrak": RigProfile.BodyPlan.HUMANOID, "grount": RigProfile.BodyPlan.HUMANOID,
	"hog": RigProfile.BodyPlan.QUADRUPED, "pet": RigProfile.BodyPlan.QUADRUPED,
	"bat": RigProfile.BodyPlan.FLYER, "nyxa": RigProfile.BodyPlan.FLYER,
}
## Every library: the slot fallbacks, the flinch and the menus' cheer.
const BASE_MOVES: Array[StringName] = [&"attack", &"cast", &"ultimate", &"hurt", &"cheer"]
## The humanoid library's signature moves (the plan's list).
const HUMANOID_SIGNATURE: Array[StringName] = [&"spin", &"slam", &"leap", &"throw", &"shield_up", &"aim"]
## The longest move (Ground Slam: a 1.0 s leap and its landing).
const MAX_LENGTH := 1.5
const IRELIA := "res://Scenes/NPCs/Hero/Heros/Support/Irelia/Irelia.tscn"
const RIVER := "res://Scenes/NPCs/Hero/Heros/Healer/River/River.tscn"
const GORRAK := "res://Scenes/NPCs/Monster/Gorrak/Gorrak.tscn"
const NYXA := "res://Scenes/NPCs/Monster/Nyxa/Nyxa.tscn"
const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"
const BAT := "res://Scenes/NPCs/Mob/Mobs/Bat/Bat.tscn"
const GROUNT_SLAM := "res://Scenes/NPCs/Monster/Grount/abilities/grount_ground_slam.tres"
const GORRAK_STOMP := "res://Scenes/NPCs/Monster/Gorrak/abilities/gorrak_stomp.tres"
## The moves a leap or a dash plays, with the markers that time them.
const LEAPS: Dictionary[StringName, String] = {&"slam": GROUNT_SLAM, &"stomp": GORRAK_STOMP}
const DASH_RUNS: Dictionary[RigProfile.BodyPlan, StringName] = {
	RigProfile.BodyPlan.HUMANOID: &"charge",
	RigProfile.BodyPlan.FLYER: &"swoop",
}
## Narrowest a turning body may be drawn (|x scale|): Gorrak's spin used to
## pass through 0 and showed a 2-3 px sliver.
const MIN_TURN_SCALE := 0.4
## The shortest frame a device draws (s): two keys closer than this can hide a
## jump only as a step (transition 0), never as an interpolated sweep.
const FRAME := 1.0 / 60.0
const ROSTER := "res://Scenes/NPCs/roster.tres"


func after_each() -> void:
	CharacterRig.force_awake = false


func _profile(id: String) -> RigProfile:
	return load("%s/%s/%s_motion.tres" % [ROOT, id, id]) as RigProfile


func _body(id: String) -> RigBody:
	return (load("%s/%s/%s_body.tscn" % [ROOT, id, id]) as PackedScene).instantiate() as RigBody


func _library(plan: RigProfile.BodyPlan) -> AnimationLibrary:
	return load("%s/%s" % [MOVES_DIR, PLAN_FILES[plan]]) as AnimationLibrary


## The labels match the moves: each profile's body plan is its art's, and its
## library is that plan's.
func test_profiles_use_their_body_plan_library() -> void:
	for id in BODY_PLANS:
		var p := _profile(id)
		assert_eq(p.body_plan, BODY_PLANS[id], "%s body plan" % id)
		assert_true(p.moves != null, "%s has moves" % id)
		if p.moves:
			assert_eq(p.moves.resource_path, "%s/%s" % [MOVES_DIR, PLAN_FILES[p.body_plan]], "%s moves = its plan's library" % id)


## Every library has the generic moves; the humanoid one also the signature
## moves. Every move is an authored one-shot: value tracks on known channels
## of parts that some body of the plan has, linear keys from 0 to its length,
## ending at rest (zero angle and offset, unit scale) so the hand-back to the
## procedural pose is seamless.
func test_libraries_hold_authored_one_shots() -> void:
	var parts_by_plan: Dictionary = {}
	for id in BODY_PLANS:
		var body := _body(id)
		var parts: Array = parts_by_plan.get(BODY_PLANS[id], [])
		for n in body.part_order:
			if not parts.has(StringName(n)):
				parts.append(StringName(n))
		parts_by_plan[BODY_PLANS[id]] = parts
		body.free()
	for plan: RigProfile.BodyPlan in PLAN_FILES:
		var lib := _library(plan)
		var plan_name := String(RigProfile.BodyPlan.keys()[plan]).to_lower()
		for m in BASE_MOVES:
			assert_true(lib.has_animation(m), "%s has %s" % [plan_name, m])
		if plan == RigProfile.BodyPlan.HUMANOID:
			for m in HUMANOID_SIGNATURE:
				assert_true(lib.has_animation(m), "humanoid has %s" % m)
		var parts: Array = parts_by_plan[plan]
		for move in lib.get_animation_list():
			var anim := lib.get_animation(move)
			var tag := "%s/%s" % [plan_name, move]
			assert_eq(anim.loop_mode, Animation.LOOP_NONE, "%s is a one-shot" % tag)
			assert_true(anim.length > 0.2 and anim.length <= MAX_LENGTH, "%s length %.2f" % [tag, anim.length])
			var channels := CharacterRig.channels_of(anim)
			for i in anim.get_track_count():
				var ch := channels[i]
				assert_true(ch >= 0, "%s track %s drives a move channel" % [tag, anim.track_get_path(i)])
				if ch < 0:
					continue
				if ch < CharacterRig.CH_OFFSET:
					assert_true(parts.has(CharacterRig.LIMB_NAMES[ch]), "%s: some %s body has %s" % [tag, plan_name, CharacterRig.LIMB_NAMES[ch]])
				# Linear keys eased per segment: a pose never overshoots its
				# keys (cubic keys across uneven spacing bulged a held lean 3x).
				assert_eq(anim.track_get_interpolation_type(i), Animation.INTERPOLATION_LINEAR, "%s %s linear keys" % [tag, anim.track_get_path(i)])
				var n := anim.track_get_key_count(i)
				assert_near(anim.track_get_key_time(i, 0), 0.0, 0.0001, "%s %s starts at 0" % [tag, anim.track_get_path(i)])
				assert_near(anim.track_get_key_time(i, n - 1), anim.length, 0.0001, "%s %s ends at the length" % [tag, anim.track_get_path(i)])
				var rest: Variant = Vector2.ZERO
				if ch == CharacterRig.CH_SCALE:
					rest = Vector2.ONE
				elif ch < CharacterRig.CH_OFFSET or ch == CharacterRig.CH_TILT:
					rest = 0.0
				assert_eq(anim.track_get_key_value(i, n - 1), rest, "%s %s ends at rest" % [tag, anim.track_get_path(i)])


## The moves a cast can ask for (move_name, River's heal_move_name, the
## cleave's full_circle_move_name) exist in the caster's library, for every
## roster character's non-passive abilities, which all name one.
func test_every_ability_move_exists_in_its_library() -> void:
	var roster := load(ROSTER) as Roster
	var checked := 0
	for def in roster.all():
		var scene := (load(def.scene_path) as PackedScene).instantiate()
		var abilities: Array[AbilityBase] = []
		var system := scene.get_node_or_null(^"AbilitySystem") as AbilitySystem
		if system:
			abilities.assign([system.basic_attack, system.active_ability, system.ultimate_ability])
		else:
			for slot in ["ability_1", "ability_2", "ability_3"]:
				abilities.append(scene.get(slot) as AbilityBase)
		var lib := def.rig_profile.moves
		for a in abilities:
			assert_true(a != null, "%s: every cast slot is filled" % def.character_id())
			if a == null:
				continue
			assert_true(a.move_name != &"", "%s %s names its move" % [def.character_id(), a.ability_name])
			var names: Array[StringName] = [a.move_name]
			if a is RiverBasicAttack:
				names.append((a as RiverBasicAttack).heal_move_name)
			if a is BullFrontCleave and (a as BullFrontCleave).full_circle_move_name != &"":
				names.append((a as BullFrontCleave).full_circle_move_name)
			for m in names:
				assert_true(lib.has_animation(m), "%s %s: move %s in %s" % [def.character_id(), a.ability_name, m, lib.resource_path])
				checked += 1
		scene.free()
	assert_true(checked >= 21, "every cast ability checked (%d)" % checked)


## In a match a cast plays the ability's move on the caster's rig (by its
## weapon or Whirlwind where the ability says so), the body moves, facing
## left mirrors the move's offset, and the rig still writes nothing on its
## entity: position, scale, modulate and the facing carrier stay as gameplay
## left them.
func test_a_cast_plays_its_move_and_writes_no_entity_state() -> void:
	var irelia := await spawn_frozen(IRELIA, Vector2(300, 300)) as EntityBase
	var rig := irelia.get_node(^"Rig") as CharacterRig
	rig.set_on_screen(true)
	var system := irelia.get_node(^"AbilitySystem") as AbilitySystem
	var facing := irelia.get_node(^"Sprite2D") as Node2D
	facing.rotation = PI
	await wait_frames(2)
	var before := [irelia.global_position, irelia.scale, irelia.modulate, facing.rotation]
	var arm := rig.body.part(&"arm_f")
	var arm_rest := rig.body.rest_of(&"arm_f").get_origin()
	irelia.announce_cast(system.basic_attack, null)
	assert_eq(rig.current_move(), &"bash", "Shield Bash plays bash")
	await wait_seconds(0.14)
	assert_true(arm.position.x - arm_rest.x > 10.0, "the shield arm punches forward (%.1f sheet px)" % (arm.position.x - arm_rest.x))
	assert_true(rig.body.position.x < 0.0, "facing left, the lunge goes left (%.2f)" % rig.body.position.x)
	assert_eq([irelia.global_position, irelia.scale, irelia.modulate, facing.rotation], before, "no entity state written")
	irelia.announce_cast(system.ultimate_ability, null)
	assert_eq(rig.current_move(), &"war_cry", "a cast replaces the swing")
	await wait_seconds(1.0)
	assert_eq(rig.current_move(), &"", "over")
	assert_near(rig.body.rotation, 0.0, 0.0001, "upright again")
	assert_eq([irelia.global_position, irelia.scale, irelia.modulate, facing.rotation], before, "still no entity state written")
	irelia.queue_free()
	var river := await spawn_frozen(RIVER, Vector2(300, 300)) as EntityBase
	var river_rig := river.get_node(^"Rig") as CharacterRig
	river_rig.set_on_screen(true)
	var basic := (river.get_node(^"AbilitySystem") as AbilitySystem).basic_attack
	assert_eq(river_rig.move_for(basic, river), &"aim", "the rifle shot")
	(river.get_node(^"AbilitySystem") as AbilitySystem).active_ability.execute(river)
	assert_eq(river_rig.move_for(basic, river), &"point", "the heal staff")
	river.queue_free()
	var gorrak := await spawn_frozen(GORRAK, Vector2(300, 300)) as MonsterBase
	var gorrak_rig := gorrak.get_node(^"Rig") as CharacterRig
	var cleaver := gorrak.ability_1 as BullFrontCleave
	assert_eq(gorrak_rig.move_for(cleaver, gorrak), &"chop", "Cleaver Chop")
	cleaver.cone_angle = BullFrontCleave.FULL_CIRCLE
	assert_eq(gorrak_rig.move_for(cleaver, gorrak), &"spin", "Whirlwind spins")
	gorrak.queue_free()
	await wait_frames(1)


## Mid-body anchors: line effects start and end at the middle of the drawn
## body (about half the art's height above the feet, higher for a hovering
## flyer), at the entity's scale; a node without a rig keeps its position.
func test_mid_body_anchor() -> void:
	var irelia := await spawn_frozen(IRELIA, Vector2(300, 300)) as EntityBase
	var rig := irelia.get_node(^"Rig") as CharacterRig
	var mid := CharacterRig.mid_body_of(irelia)
	var half := rig.body.bounds.get_center().y * rig.profile.world_scale
	assert_near(mid.x, 300.0, 0.001, "straight above the feet")
	assert_near(mid.y - 300.0, half, absf(half) * 0.05, "half-way up the art (+-4 % size)")
	assert_true(mid.y < 300.0 - 15.0, "well above the feet (%.1f)" % mid.y)
	var nyxa := await spawn_frozen(NYXA, Vector2(600, 300)) as EntityBase
	var nyxa_mid := CharacterRig.mid_body_of(nyxa)
	var nyxa_rig := nyxa.get_node(^"Rig") as CharacterRig
	var walker_mid := nyxa_rig.body.bounds.get_center().y * nyxa_rig.profile.world_scale
	assert_true(nyxa_mid.y - 300.0 < walker_mid, "a flyer's anchor includes its hover")
	nyxa.scale = Vector2(1.5, 1.5)
	assert_near(CharacterRig.mid_body_of(nyxa).y - 300.0, (nyxa_mid.y - 300.0) * 1.5, 0.01, "grows with the entity")
	var plain := Node2D.new()
	plain.position = Vector2(40, 50)
	add_child(plain)
	assert_eq(CharacterRig.mid_body_of(plain), Vector2(40, 50), "no rig: the node's own position")
	plain.queue_free()
	irelia.queue_free()
	nyxa.queue_free()
	await wait_frames(1)


## A leap's move has its landing at a "contact" marker, at today's airtime
## (the ability's jump_duration); a dash's run loops seamlessly between its
## "loop_from" and "loop_to" markers (every channel the same at both).
func test_timed_moves_carry_their_markers() -> void:
	var humanoid := _library(RigProfile.BodyPlan.HUMANOID)
	for move: StringName in LEAPS:
		var anim := humanoid.get_animation(move)
		var contact := CharacterRig.marker_time(anim, &"contact")
		assert_near(contact, float((load(LEAPS[move]) as AbilityBase).get(&"jump_duration")), 0.0001, "%s lands at its airtime" % move)
	for plan: RigProfile.BodyPlan in DASH_RUNS:
		var anim := _library(plan).get_animation(DASH_RUNS[plan])
		var from := CharacterRig.marker_time(anim, &"loop_from")
		var to := CharacterRig.marker_time(anim, &"loop_to")
		assert_true(from > 0.0 and to > from + 0.05 and to < anim.length, "%s loops %.2f..%.2f" % [DASH_RUNS[plan], from, to])
		for i in anim.get_track_count():
			var a: Variant = anim.value_track_interpolate(i, from)
			var b: Variant = anim.value_track_interpolate(i, to)
			var same: bool = is_equal_approx(float(a), float(b)) if typeof(a) == TYPE_FLOAT else (a as Vector2).is_equal_approx(b as Vector2)
			assert_true(same, "%s %s: %s at loop_from, %s at loop_to" % [DASH_RUNS[plan], anim.track_get_path(i), a, b])


## Gorrak's spin (Whirlwind) turns through a mirrored body without ever being
## drawn edge on: its x scale flips within a tenth of a millisecond and stays
## at least MIN_TURN_SCALE wide on every frame.
func test_spin_never_turns_edge_on() -> void:
	var anim := _library(RigProfile.BodyPlan.HUMANOID).get_animation(&"spin")
	var track := anim.find_track(^"..:move_scale", Animation.TYPE_VALUE)
	assert_true(track >= 0, "the spin keys the body's scale")
	var narrowest := INF
	var mirrored := false
	# Every 1/240 s, and at a quarter, half and three quarters of every key
	# gap: the mirror flip sits in a 0.1 ms gap a 1/240 s step never samples.
	var times := PackedFloat32Array()
	var t := 0.0
	while t <= anim.length:
		times.append(t)
		t += 1.0 / 240.0
	for k in anim.track_get_key_count(track) - 1:
		var t0 := anim.track_get_key_time(track, k)
		var t1 := anim.track_get_key_time(track, k + 1)
		for share: float in [0.25, 0.5, 0.75]:
			times.append(lerpf(t0, t1, share))
	for at in times:
		var x: float = (anim.value_track_interpolate(track, at) as Vector2).x
		narrowest = minf(narrowest, absf(x))
		mirrored = mirrored or x < -0.9
	assert_true(narrowest >= MIN_TURN_SCALE, "never thinner than %.2f (%.2f)" % [MIN_TURN_SCALE, narrowest])
	assert_true(mirrored, "it turns all the way round")


## rig-6: two keys of a track closer than a frame hide a jump (the spin's
## mirror flip, the twirl's full-turn unwind). A frame landing between them
## drew the jump half done (Gorrak edge on, River's staff arm up to 180
## degrees off) unless the first key is a step (transition 0: Godot holds
## its value up to the next key).
func test_sub_frame_key_gaps_are_steps() -> void:
	for plan: RigProfile.BodyPlan in PLAN_FILES:
		var lib := _library(plan)
		for move in lib.get_animation_list():
			var anim := lib.get_animation(move)
			for tr_i in anim.get_track_count():
				for k in anim.track_get_key_count(tr_i) - 1:
					var gap := anim.track_get_key_time(tr_i, k + 1) - anim.track_get_key_time(tr_i, k)
					if gap < FRAME:
						assert_eq(anim.track_get_key_transition(tr_i, k), 0.0, "%s/%s track %d key %d: a %.4f s gap is a step" % [
								PLAN_FILES[plan], move, tr_i, k, gap])
	# River's twirl inside its 1 ms unwind: the staff arm at a whole turn.
	var twirl := _library(RigProfile.BodyPlan.HUMANOID).get_animation(&"twirl")
	var arm := twirl.find_track(^"%arm_f:rotation", Animation.TYPE_VALUE)
	for at: float in [0.3, 0.3002, 0.3005, 0.3008]:
		var r := float(twirl.value_track_interpolate(arm, at))
		var off := absf(angle_difference(r, 0.0))
		assert_true(off < 0.01, "twirl at %.4f s: the arm at a whole turn (%.3f rad off)" % [at, off])


## Ground Slam's move after its landing bounce (from 1.1 s) eases back to the
## procedural pose with no visible snap: frame to frame the body and every
## limb move only a little, and the hand-back at its end changes nothing.
func test_slam_returns_to_rest_without_a_snap() -> void:
	var grount := await spawn_frozen(GROUNT, Vector2(300, 300)) as MonsterBase
	var rig := grount.get_node(^"Rig") as CharacterRig
	rig.set_on_screen(true)
	grount.announce_cast(load(GROUNT_SLAM) as AbilityBase, null)
	assert_eq(rig.current_move(), &"slam", "the slam plays")
	rig.set_process(false)  # stepped by hand below
	var dt := 1.0 / 60.0
	var limbs: Array[Node2D] = []
	for part: StringName in [&"body", &"head", &"arm_f", &"arm_b", &"leg_f", &"leg_b"]:
		limbs.append(rig.body.part(part))
	var last_scale := Vector2.ZERO
	var last_pos := Vector2.ZERO
	var last_rot := PackedFloat32Array()
	var worst_scale := 0.0
	var worst_pos := 0.0
	var worst_rot := 0.0
	for frame in 110:
		rig._process(dt)
		var rot := PackedFloat32Array()
		for limb in limbs:
			rot.append(limb.rotation)
		if frame >= 66:  # 1.1 s and on, through the end of the move and past it
			worst_scale = maxf(worst_scale, absf(absf(rig.body.scale.y) - absf(last_scale.y)) / absf(last_scale.y))
			worst_pos = maxf(worst_pos, rig.body.position.distance_to(last_pos))
			for i in rot.size():
				worst_rot = maxf(worst_rot, absf(rot[i] - last_rot[i]))
		last_scale = rig.body.scale
		last_pos = rig.body.position
		last_rot = rot
	assert_eq(rig.current_move(), &"", "over")
	assert_true(worst_scale < 0.05, "the squash eases out (%.3f a frame)" % worst_scale)
	assert_true(worst_pos < 1.0, "the body settles (%.2f px a frame)" % worst_pos)
	assert_true(worst_rot < 0.08, "the limbs settle (%.3f rad a frame)" % worst_rot)
	grount.queue_free()
	await wait_frames(1)


## rig-3: a move's head channel blends over the head's rest angle and out
## to it: on every frame the head is lerp(rest, the move's angle, weight),
## and the frame that ends the move moves it by almost nothing. (The head was
## the one limb the procedural layer never set back to rest: it lerped from
## last frame's angle, froze in the blend-out and snapped at the hand-back,
## 0.078 rad on Irelia's war cry.)
func test_head_blends_out_to_rest() -> void:
	var irelia := await spawn_frozen(IRELIA, Vector2(300, 300)) as EntityBase
	var rig := irelia.get_node(^"Rig") as CharacterRig
	rig.set_on_screen(true)
	rig.play_move(&"war_cry")
	assert_eq(rig.current_move(), &"war_cry", "the war cry plays")
	rig.set_process(false)  # stepped by hand below
	var head := rig.body.part(&"head")
	var rest: float = rig._rest_rot[1]
	var worst := 0.0
	var last := head.rotation
	var last_step := 0.0
	for frame in 120:
		var playing := rig.current_move() != &""
		rig._process(1.0 / 60.0)
		if playing and rig.current_move() == &"":
			last_step = absf(head.rotation - last)
		elif rig.current_move() != &"" and not is_nan(rig._move_rot[1]):
			worst = maxf(worst, absf(head.rotation - lerpf(rest, rig._move_rot[1], rig._move_weight())))
		last = head.rotation
	assert_eq(rig.current_move(), &"", "over")
	assert_true(worst < 0.001, "the head is lerp(rest, move, weight) on every frame (%.4f rad off)" % worst)
	assert_true(last_step < 0.01, "the hand-back moves the head by almost nothing (%.4f rad)" % last_step)
	assert_near(head.rotation, rest, 0.0001, "at rest after it")
	irelia.queue_free()
	await wait_frames(1)


## rig-2: a dash in flight faces its way. With Echo Strike Nyxa's swoop flies
## back through its target; the rig took its side from the facing carrier
## alone, which the busy AI never turns during a dash, so she flew the whole
## way back tail-first. The rig only reads the dash: the carrier is unchanged.
func test_echo_strike_return_pass_faces_its_way() -> void:
	var n := (await spawn_frozen(NYXA, Vector2(300, 300))) as MonsterBase
	var v := await spawn_frozen(IRELIA, Vector2(480, 300))
	var rig := n.get_node(^"Rig") as CharacterRig
	rig.set_on_screen(true)
	var swoop := n.ability_2 as BullRamDash
	swoop.double_pass = true  # Echo Strike, on her own copy
	n.sprite.rotation = 0.0
	assert_true(n._cast("ability_2", swoop, v), "she swoops at Irelia on her right")
	var outbound := 0
	var back := 0
	var back_mirrored := 0
	var turned := false
	for f in 90:
		await wait_frames(1)
		if not swoop.is_dashing:
			if turned:
				break
			continue
		if swoop.dash_direction.x > 0.25:
			outbound += 1
			assert_eq(rig._flip, 1.0, "frame %d: out to the right, facing right" % f)
		elif swoop.dash_direction.x < -0.25:
			back += 1
			if turned:  # the turn frame itself may lag a frame
				back_mirrored += 1 if rig._flip == -1.0 else 0
			turned = true
	assert_true(outbound > 0 and back > 2, "an outbound and a return pass (%d / %d frames)" % [outbound, back])
	assert_eq(back_mirrored, back - 1, "the way back faces left")
	await wait_seconds(CharacterRig.FACE_HOLD)
	assert_false(swoop.is_dashing, "the dash ended")
	assert_eq(rig._flip, 1.0, "after the dash the carrier decides again (still right)")
	assert_near(n.sprite.rotation, 0.0, 0.0001, "the carrier is untouched by the rig")
	n.queue_free()
	v.queue_free()
	await wait_frames(1)


## rig-5: Grount's effect anchors follow his stage. The body box was the
## union of all three stages (Stage III's horns), so at Stage I the status
## marks floated 17 px above the calf and beams ended 9 px above his middle.
## drawn_bounds() is the box of the parts drawn at the stage (measured on the
## visible sprites), and head_top() / mid_body() are its top and middle.
func test_grount_anchors_follow_his_stage() -> void:
	var g := await spawn_frozen(GROUNT, Vector2(300, 300)) as MonsterBase
	var rig := g.get_node(^"Rig") as CharacterRig
	var k: float = rig.profile.world_scale * rig._size * g.scale.y
	var tops: Array[float] = []
	for stage in [1, 2, 3]:
		rig.set_stage(stage)
		rig.body.reset_pose()  # the parts at their generated pose
		var drawn := _drawn_box(rig.body)
		var box := rig.body.drawn_bounds()
		assert_near(box.position.y, drawn.position.y, 1.0, "stage %d: the box's top is the visible parts' (%.1f vs %.1f)" % [
				stage, box.position.y, drawn.position.y])
		assert_near(box.end.y, drawn.end.y, 1.0, "stage %d: and its bottom" % stage)
		var head_top := CharacterRig.head_top_of(g)
		var mid := CharacterRig.mid_body_of(g)
		assert_near(head_top.y - g.global_position.y, box.position.y * k, 0.01, "stage %d: head_top() is its top" % stage)
		assert_near(mid.y - g.global_position.y, box.get_center().y * k, 0.01, "stage %d: mid_body() its middle" % stage)
		tops.append(head_top.y)
	assert_true(tops[0] > tops[1] and tops[1] > tops[2], "the top rises with the horns (%s)" % str(tops))
	assert_true(tops[0] - tops[2] > 10.0, "the calf's top is well below the Alpha Bull's")
	g.queue_free()
	await wait_frames(1)


## The box of the visible parts of `body` in art units around its origin (each
## part's region at its transform under the body, in sheet px / sheet_scale).
func _drawn_box(body: RigBody) -> Rect2:
	var to_body := body.get_global_transform().affine_inverse()
	var box := Rect2()
	var first := true
	for n in body.part_order:
		var part := body.part(StringName(n)) as Sprite2D
		if part == null or not part.is_visible_in_tree():
			continue
		var r := part.get_rect()
		var xf := to_body * part.get_global_transform()
		for corner: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			var at: Vector2 = xf * corner / body.sheet_scale
			box = Rect2(at, Vector2.ZERO) if first else box.expand(at)
			first = false
	return box


## The airtime a leap reports (FxEvents.SLAM_LEAP, the frame before its cast)
## stretches its move so the landing pose comes with the hit; a landing that
## comes early jumps straight to it; a report from an earlier frame is stale.
func test_leap_lands_with_its_airtime() -> void:
	var grount := await spawn_frozen(GROUNT, Vector2(300, 300)) as MonsterBase
	var rig := grount.get_node(^"Rig") as CharacterRig
	rig.set_on_screen(true)
	var slam := grount.ability_3
	EventBus.notify_ability_event(grount, slam, FxEvents.SLAM_LEAP, grount.global_position, 2.0)
	grount.announce_cast(slam, null)
	assert_eq(rig.current_move(), &"slam", "the slam plays")
	assert_near(rig._move_rate, 0.5, 0.001, "stretched to a 2 s airtime")
	await wait_seconds(1.0)
	assert_near(rig._move_t, 0.5, 0.05, "half-way to the landing after 1 s")
	EventBus.notify_ability_event(grount, slam, FxEvents.SLAM_LANDED, grount.global_position, 120.0)
	assert_near(rig._move_t, 1.0, 0.001, "landed: the impact pose")
	assert_near(rig._move_rate, 1.0, 0.001, "and the recovery at its own pace")
	await wait_seconds(0.6)
	EventBus.notify_ability_event(grount, slam, FxEvents.SLAM_LEAP, grount.global_position, 2.0)
	await wait_frames(1)
	grount.announce_cast(slam, null)
	assert_near(rig._move_rate, 1.0, 0.001, "a leap reported a frame earlier is not this cast's")
	grount.queue_free()
	await wait_frames(1)


## A dash's run loops for as long as the dash goes on, and plays out once it
## ended (DASH_ENDED, or the dash simply no longer dashing).
func test_dash_run_loops_while_dashing() -> void:
	var grount := await spawn_frozen(GROUNT, Vector2(300, 300)) as MonsterBase
	var rig := grount.get_node(^"Rig") as CharacterRig
	rig.set_on_screen(true)
	var dash := grount.ability_2 as BullRamDash
	var anim := rig.profile.moves.get_animation(&"charge")
	dash.is_dashing = true  # the dash in flight (read only by the rig)
	EventBus.notify_ability_event(grount, dash, FxEvents.DASH_STARTED, grount.global_position + Vector2(300, 0), 40.0)
	grount.announce_cast(dash, null)
	assert_eq(rig.current_move(), &"charge", "the charge plays")
	await wait_seconds(anim.length + 0.6)
	assert_eq(rig.current_move(), &"charge", "still running past its length while dashing")
	assert_true(rig._move_t >= CharacterRig.marker_time(anim, &"loop_from") - 0.001 \
			and rig._move_t < CharacterRig.marker_time(anim, &"loop_to"), "inside its run loop (%.2f)" % rig._move_t)
	dash.is_dashing = false
	EventBus.notify_ability_event(grount, dash, FxEvents.DASH_ENDED, grount.global_position)
	await wait_seconds(anim.length - CharacterRig.marker_time(anim, &"loop_from") + 0.05)
	assert_eq(rig.current_move(), &"", "played out after the dash")
	dash.is_dashing = true
	EventBus.notify_ability_event(grount, dash, FxEvents.DASH_STARTED, grount.global_position + Vector2(300, 0), 40.0)
	grount.announce_cast(dash, null)
	dash.is_dashing = false  # stopped without an event (a wall, a stun)
	await wait_seconds(anim.length + 0.05)
	assert_eq(rig.current_move(), &"", "a dash that stopped stops the loop")
	grount.queue_free()
	await wait_frames(1)


## Only FULL rigs with an entity (heroes, monsters, the fox) listen for the
## timed moves; the mobs' rigs never connect.
func test_only_full_rigs_listen_for_timed_moves() -> void:
	var grount := await spawn_frozen(GROUNT, Vector2(300, 300)) as MonsterBase
	var bat := await spawn_frozen(BAT, Vector2(500, 300)) as MobBase
	var grount_rig := grount.get_node(^"Rig") as CharacterRig
	var bat_rig := bat.get_node(^"Rig") as CharacterRig
	assert_true(EventBus.ability_event.is_connected(grount_rig._on_ability_event), "the monster's rig listens")
	assert_false(EventBus.ability_event.is_connected(bat_rig._on_ability_event), "a mob's rig does not")
	grount.queue_free()
	bat.queue_free()
	await wait_frames(1)
