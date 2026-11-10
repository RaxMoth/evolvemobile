extends TestCase

## The authored rig moves (Assets/Characters/_moves, CharacterRig): one
## AnimationLibrary per body plan, picked by every motion profile's body plan
## (Grount and Gorrak stand upright: HUMANOID); every library has the generic
## moves and every track drives a known channel, as one-shots that start and
## end at rest; every ability's move exists in its caster's library; a cast
## plays it in a match while the rig still never writes its entity; and
## mid_body() anchors line effects on the body, not the feet.
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
