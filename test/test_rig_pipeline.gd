extends TestCase

## SVG character rigs (Scripts/Rig, tools/rig_builder.gd), tested on the
## fixture character test/fixtures/rig_fixture so the suite does not depend on
## the real art: the generated files are fresh, a body draws in its art's z
## order without z_index, and CharacterRig is pure presentation (no global RNG,
## no entity writes, asleep off screen, half rate over budget, inert without a
## body) whose procedural pose takes every part back after an authored move.

const FIXTURE := "rig_fixture"
const FIXTURE_SRC := "res://test/fixtures/rig_fixture/src/rig_src.json"
const FIXTURE_BODY := "res://test/fixtures/rig_fixture/rig_fixture_body.tscn"
const FIXTURE_MOTION := "res://test/fixtures/rig_fixture/rig_fixture_motion.tres"
const RIG_SCRIPT := "res://Scripts/Rig/character_rig.gd"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"
## Every character scene draws its rig now; the bare mob base scene (an
## EntityBase whose Rig has no body) stands in for one still on its sprite.
const UNMIGRATED := "res://Scenes/NPCs/Mob/mobs_base_class.tscn"
## Broken sources the builder must refuse (written under user://, isolated runs only).
const BROKEN_ROOT := "user://rig_builder_test"
const PART_SVG := '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="160" viewBox="0 0 128 160">%s</svg>'


func after_each() -> void:
	CharacterRig.force_awake = false


## Golden: rebuilding from src/ gives exactly the committed sheet and body, for
## every character (Assets/Characters) and the fixture.
func test_generated_rigs_are_fresh() -> void:
	var ids: PackedStringArray = []
	for root in RigBuilder.ROOTS:
		for id in RigBuilder.character_dirs(root):
			ids.append(id)
			var b := RigBuilder.new(id, root)
			assert_true(b.build(), "%s builds: %s" % [id, ", ".join(b.errors)])
			assert_eq(FileAccess.get_file_as_string(b.sheet_path()), b.sheet_svg, "%s sheet stale: run tools/build_rigs.sh" % id)
			assert_eq(FileAccess.get_file_as_string(b.body_path()), b.body_tscn, "%s body stale: run tools/build_rigs.sh" % id)
			var imp := FileAccess.get_file_as_string(b.sheet_path() + ".import")
			assert_true(imp.contains("mipmaps/generate=true") and imp.contains("svg/scale="), "%s sheet imports with mipmaps at its svg/scale" % id)
	assert_true(ids.has(FIXTURE), "the fixture character is found")
	assert_eq(RigBuilder.root_of(FIXTURE), RigBuilder.FIXTURE_ROOT)


## Draw order of the generated tree (show_behind_parent honoured), no z_index.
func _draw_sequence(n: Node, out: PackedStringArray) -> void:
	var kids := n.get_children()
	for c in kids:
		if c is CanvasItem and (c as CanvasItem).show_behind_parent:
			_draw_sequence(c, out)
	if n is Sprite2D:
		out.append(String(n.name))
	for c in kids:
		if not (c is CanvasItem and (c as CanvasItem).show_behind_parent):
			_draw_sequence(c, out)


func _z_indices(n: Node, out: Array[int]) -> void:
	if n is CanvasItem:
		out.append((n as CanvasItem).z_index)
	for c in n.get_children():
		_z_indices(c, out)


func test_body_draws_in_art_z_order() -> void:
	# The art's z order, straight from the source.
	var src: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_SRC))
	var parts: Array = src.parts
	parts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.z) < int(b.z))
	var art_order: PackedStringArray = []
	for p: Dictionary in parts:
		art_order.append(String(p.name))
	var body := (load(FIXTURE_BODY) as PackedScene).instantiate() as RigBody
	assert_eq(body.part_order, art_order, "part_order is the art's z order")
	var seq: PackedStringArray = []
	_draw_sequence(body, seq)
	assert_eq(seq, art_order, "the tree draws in the art's z order")
	var zs: Array[int] = []
	_z_indices(body, zs)
	assert_eq(zs.max(), 0, "no z_index (it is global: parts would cover other entities)")
	assert_eq(zs.min(), 0, "no negative z_index either")
	for p in body.part_order:
		assert_true(body.part(StringName(p)) != null, "%%%s is a scene-unique part" % p)
	# The cape and back arm hang from the body but draw behind the legs.
	assert_eq(String(body.part(&"cape").get_parent().name), "body__back", "back branch moved under the proxy")
	assert_eq(body.proxies, {"body__back": "body"})
	body.free()


func test_stage_parts_follow_the_stage() -> void:
	var body := (load(FIXTURE_BODY) as PackedScene).instantiate() as RigBody
	add_child(body)
	assert_eq(body.stage_parts.keys(), ["crown"], "only the crown is stage-bound")
	assert_false(body.part(&"crown").visible, "freshly instanced = stage 1")
	var stages: Array[int] = [2, 3, 1, 2]
	for stage in stages:
		body.set_stage(stage)
		assert_eq(body.part(&"crown").visible, stage >= 2, "crown at stage %d" % stage)
		assert_true(body.part(&"head").visible, "stage-free parts always show (stage %d)" % stage)
	body.queue_free()
	await wait_frames(1)


func _write_broken(id: String, parts: Array, svgs: Dictionary) -> void:
	var dir := "%s/%s/src/parts" % [BROKEN_ROOT, id]
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open("%s/%s/src/rig_src.json" % [BROKEN_ROOT, id], FileAccess.WRITE)
	f.store_string(JSON.stringify({"canvas": [128, 160], "baseline": 150, "parts": parts}))
	f.close()
	for part_name: String in svgs:
		var s := FileAccess.open("%s/%s.svg" % [dir, part_name], FileAccess.WRITE)
		s.store_string(PART_SVG % String(svgs[part_name]))
		s.close()


## Art that no node tree can draw in z order, or whose parts share an SVG id,
## is reported and nothing is generated.
func test_builder_refuses_broken_art() -> void:
	if not require_isolated():
		return
	var rect := '<rect x="%d" y="40" width="20" height="60" fill="#c86a32"/>'
	# Y hangs from X, X from C; B (z2) would have to draw between X (z1) and Y (z3).
	_write_broken("order", [
		{"name": "a", "z": 0, "pivot": [20, 100], "parent": ""},
		{"name": "x", "z": 1, "pivot": [40, 100], "parent": "c"},
		{"name": "b", "z": 2, "pivot": [60, 100], "parent": ""},
		{"name": "y", "z": 3, "pivot": [80, 100], "parent": "x"},
		{"name": "c", "z": 4, "pivot": [100, 100], "parent": ""},
	], {"a": rect % 10, "x": rect % 30, "b": rect % 50, "y": rect % 70, "c": rect % 90})
	var b := RigBuilder.new("order", BROKEN_ROOT)
	assert_false(b.build(), "out-of-order art does not build")
	assert_true(", ".join(b.errors).contains("cannot follow z order"), "reported: %s" % ", ".join(b.errors))
	assert_eq(b.body_tscn, "", "nothing generated")
	var clip := '<clipPath id="c1"><rect x="%d" y="40" width="20" height="60"/></clipPath><rect x="%d" y="40" width="20" height="60" fill="#c86a32" clip-path="url(#c1)"/>'
	_write_broken("ids", [
		{"name": "a", "z": 0, "pivot": [20, 100], "parent": ""},
		{"name": "b", "z": 1, "pivot": [60, 100], "parent": ""},
	], {"a": clip % [10, 10], "b": clip % [50, 50]})
	b = RigBuilder.new("ids", BROKEN_ROOT)
	assert_false(b.build(), "parts sharing an SVG id do not build")
	assert_true(", ".join(b.errors).contains("SVG id c1"), "reported: %s" % ", ".join(b.errors))


## A puppet rig (menus, previews) animates without drawing from the global
## RNG, which drives gameplay.
func test_puppet_never_draws_the_global_rng() -> void:
	seed(4242)
	var expected := [randf(), randi()]
	seed(4242)
	var holder := Node2D.new()
	var rig := CharacterRig.new()
	rig.profile = load(FIXTURE_MOTION)
	rig.tier = CharacterRig.Tier.FULL
	rig.puppet_speed = 80.0
	var body := (load(FIXTURE_BODY) as PackedScene).instantiate() as RigBody
	rig.add_child(body)
	rig.body = body
	holder.add_child(rig)
	add_child(holder)
	await wait_frames(10)
	assert_true(rig.is_processing(), "a puppet is always awake")
	assert_true(absf(body.part(&"leg_f").rotation - body.rest_of(&"leg_f").get_rotation()) > 0.001, "walking in place moves the legs")
	rig.play_move(&"attack")
	rig.play_hurt()
	await wait_frames(4)
	assert_true(body.modulate.r > 1.0, "hurt flash")
	assert_eq([randf(), randi()], expected, "the rig consumed no global random number")
	holder.queue_free()
	await wait_frames(1)


## A one-move library: `tracks` = [[path, [[t, value], ...]], ...], cubic keys.
func _library(move: StringName, length: float, tracks: Array) -> AnimationLibrary:
	var anim := Animation.new()
	anim.length = length
	for track: Array in tracks:
		var i := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(i, NodePath(String(track[0])))
		for key: Array in track[1]:
			anim.track_insert_key(i, float(key[0]), key[1])
	var lib := AnimationLibrary.new()
	lib.add_animation(move, anim)
	return lib


## A FULL-tier puppet of the fixture whose profile (a copy: the shared .tres
## is never touched) carries `lib`.
func _puppet(lib: AnimationLibrary, speed: float = 0.0) -> CharacterRig:
	var holder := Node2D.new()
	var rig := CharacterRig.new()
	var profile := (load(FIXTURE_MOTION) as RigProfile).duplicate() as RigProfile
	profile.moves = lib
	rig.profile = profile
	rig.tier = CharacterRig.Tier.FULL
	rig.puppet_speed = speed
	var body := (load(FIXTURE_BODY) as PackedScene).instantiate() as RigBody
	rig.add_child(body)
	rig.body = body
	holder.add_child(rig)
	add_child(holder)
	return rig


## The procedural layer writes only the channels that changed. An authored
## move writes the parts directly, so when it ends the rig must take every part
## back, even one whose procedural value never changed (an idle leg).
func test_procedural_pose_takes_over_after_a_move() -> void:
	var rig := _puppet(_library(&"attack", 0.3, [["%leg_f:rotation", [[0.0, 1.0], [0.3, 1.0]]]]))
	var body := rig.body
	await wait_frames(3)
	var leg := body.part(&"leg_f")
	var rest := body.rest_of(&"leg_f").get_rotation()
	assert_near(leg.rotation, rest, 0.0001, "an idle puppet's leg rests")
	rig.play_move(&"attack")
	assert_eq(rig.current_move(), &"attack")
	await wait_seconds(0.12)
	assert_near(leg.rotation, 1.0, 0.0001, "the move drives the leg (fully blended in)")
	await wait_seconds(0.3)
	assert_eq(rig.current_move(), &"", "the move is over")
	assert_near(leg.rotation, rest, 0.0001, "the procedural layer takes the leg back")
	rig.get_parent().queue_free()
	await wait_frames(1)


## A move blends over the locomotion on the channels it keys only: an arm
## move leaves the legs walking; it eases in and hands back at its end.
func test_move_blends_over_locomotion() -> void:
	var rig := _puppet(_library(&"cast", 0.6, [["%arm_f:rotation", [[0.0, -1.5], [0.6, -1.5]]]]), 80.0)
	var body := rig.body
	await wait_frames(10)
	rig.play_move(&"cast")
	var arm := body.part(&"arm_f")
	assert_true(absf(arm.rotation + 1.5) > 0.3, "blending in, not snapped (%.3f)" % arm.rotation)
	await wait_seconds(0.2)
	assert_near(arm.rotation, -1.5, 0.0001, "the keyed arm follows the move")
	var leg := body.part(&"leg_f")
	var legs: Array[float] = []
	for i in 6:
		legs.append(leg.rotation)
		await wait_frames(1)
	assert_true(legs.max() - legs.min() > 0.05, "the unkeyed legs keep walking (%s)" % str(legs))
	await wait_seconds(0.5)
	assert_eq(rig.current_move(), &"")
	assert_true(absf(arm.rotation + 1.5) > 0.5, "the walk swing has the arm back (%.3f)" % arm.rotation)
	rig.get_parent().queue_free()
	await wait_frames(1)


## The root channels ("..:move_offset", "..:move_tilt", "..:move_scale",
## "..:arm_f_reach") move the body root and the arm, facing-relative, on top
## of the rig's own flip and squash, and come back to rest after the move.
## Tracks on parts or channels this body lacks are skipped silently.
func test_move_root_channels_and_missing_parts() -> void:
	var lib := _library(&"ultimate", 1.0, [
		["..:move_offset", [[0.0, Vector2(10, -5)], [1.0, Vector2(10, -5)]]],
		["..:move_tilt", [[0.0, 0.3], [1.0, 0.3]]],
		["..:move_scale", [[0.0, Vector2(1.2, 0.8)], [1.0, Vector2(1.2, 0.8)]]],
		["..:arm_f_reach", [[0.0, Vector2(0, -10)], [1.0, Vector2(0, -10)]]],
		["%wing_f:rotation", [[0.0, 1.0], [1.0, 1.0]]],
		["%no_such_part:rotation", [[0.0, 1.0], [1.0, 1.0]]],
		["%head:modulate", [[0.0, Color.RED], [1.0, Color.RED]]],
	])
	assert_eq(CharacterRig.channels_of(lib.get_animation(&"ultimate")),
		PackedInt32Array([CharacterRig.CH_OFFSET, CharacterRig.CH_TILT, CharacterRig.CH_SCALE, CharacterRig.CH_REACH_F, 6, -1, -1]),
		"track channels: root ones, a wing (absent here), unknown ones ignored")
	var rig := _puppet(lib)
	var body := rig.body
	await wait_frames(2)
	var rest_scale := body.scale
	var arm := body.part(&"arm_f")
	var arm_rest := body.rest_of(&"arm_f").get_origin()
	rig.play_move(&"ultimate", 0.5)
	var k := rig.profile.world_scale * rig._size
	assert_near(body.position.x, 10.0 * k, 0.001, "offset forward (puppets face right)")
	assert_true(body.position.y < -5.0 * k + 0.5, "offset up (plus its own lift)")
	assert_near(body.rotation, 0.3, 0.0001, "leans forward")
	assert_near(body.scale.x / rest_scale.x, 1.2, 0.05, "stretched x")
	assert_near(body.scale.y / rest_scale.y, 0.8, 0.05, "squashed y")
	assert_near(arm.position.y, arm_rest.y - 10.0 * body.sheet_scale, 0.001, "the front arm reaches up (art units x sheet scale)")
	assert_eq(body.part(&"head").modulate, Color.WHITE, "a non-move track writes nothing")
	await wait_seconds(0.6)
	assert_eq(rig.current_move(), &"")
	assert_near(body.position.x, 0.0, 0.0001, "offset back at rest")
	assert_near(body.rotation, 0.0, 0.0001, "upright again")
	assert_eq(arm.position, arm_rest, "the arm back at its rest position")
	assert_eq([rig.move_offset, rig.move_scale, rig.move_tilt, rig.arm_f_reach], [Vector2.ZERO, Vector2.ONE, 0.0, Vector2.ZERO],
		"root channels at rest")
	rig.get_parent().queue_free()
	await wait_frames(1)


## Which move a cast plays: the ability's get_move_name() when the library has
## it, else attack / cast / ultimate by slot; a mob's swing (null) attacks. A
## flinch never cuts a move short; a cast replaces whatever plays.
func test_move_for_and_priorities() -> void:
	var lib := _library(&"attack", 0.5, [["%arm_f:rotation", [[0.0, 0.5], [0.5, 0.5]]]])
	for extra: StringName in [&"cast", &"ultimate", &"hurt", &"bash"]:
		lib.add_animation(extra, lib.get_animation(&"attack").duplicate() as Animation)
	var rig := _puppet(lib)
	var named := AbilityBase.new()
	named.ability_type = AbilityBase.AbilityType.BASIC_ATTACK
	named.move_name = &"bash"
	assert_eq(rig.move_for(named), &"bash", "the ability's own move")
	named.move_name = &"no_such_move"
	assert_eq(rig.move_for(named), &"attack", "unknown name: the basic slot's attack")
	named.move_name = &""
	named.ability_type = AbilityBase.AbilityType.ULTIMATE
	assert_eq(rig.move_for(named), &"ultimate")
	named.ability_type = AbilityBase.AbilityType.ACTIVE
	assert_eq(rig.move_for(named), &"cast")
	assert_eq(rig.move_for(null), &"attack", "a mob's swing")
	rig.play_move(&"cast")
	rig.play_hurt()
	assert_eq(rig.current_move(), &"cast", "a flinch does not cut a cast short")
	await wait_frames(1)
	assert_true(rig.body.modulate.r > 1.0, "but it still flashes")
	rig.play_move(&"bash")
	assert_eq(rig.current_move(), &"bash", "a new move replaces the one playing")
	await wait_seconds(0.6)
	rig.play_hurt()
	assert_eq(rig.current_move(), &"hurt", "an idle rig flinches with the hurt move")
	await wait_seconds(0.6)
	assert_false(rig.has_move(&"no_such_move"))
	rig.play_move(&"no_such_move")
	assert_eq(rig.current_move(), &"", "no move plays for a name the library lacks")
	assert_true(rig._act > 0.0, "the procedural swing stands in")
	rig.get_parent().queue_free()
	await wait_frames(1)


## An entity scene with the fixture body under its Rig in place of the
## scene's own (a migrated hero brings its real one), AI frozen (as
## TestCase.spawn_frozen, but the body is added before the scene enters the
## tree, as a migrated character scene has it).
func _spawn_rigged(scene_path: String, pos: Vector2, rig_tier: CharacterRig.Tier) -> Node2D:
	var inst := (load(scene_path) as PackedScene).instantiate() as Node2D
	var rig := inst.get_node(^"Rig") as CharacterRig
	for own in rig.get_children():
		if own is RigBody:
			rig.remove_child(own)
			own.free()
	var body := (load(FIXTURE_BODY) as PackedScene).instantiate() as RigBody
	rig.add_child(body)
	rig.body = body
	rig.profile = load(FIXTURE_MOTION)
	rig.tier = rig_tier
	inst.position = pos
	add_child(inst)
	await wait_physics_frames(4)
	await wait_frames(1)
	get_tree().root.get_node(^"TickScheduler").unregister(inst)
	return inst


## In a match the rig only reads its entity; off screen it does not process.
func test_entity_rig_reads_but_never_writes() -> void:
	var awake_before := CharacterRig.awake_count()
	var vlad := await _spawn_rigged(VLAD, Vector2(300, 300), CharacterRig.Tier.FULL) as EntityBase
	var rig := vlad.get_node(^"Rig") as CharacterRig
	var facing := vlad.get_node(^"Sprite2D") as Node2D
	assert_eq(vlad.visual_root(), rig, "visual effects target the rig once it has a body")
	assert_false(rig.is_processing(), "headless = off screen = asleep")
	assert_eq(CharacterRig.awake_count(), awake_before, "an off-screen rig is not counted")
	rig.set_on_screen(true)
	assert_eq(CharacterRig.awake_count(), awake_before + 1)
	var facing_rot := facing.rotation
	var entity_scale := vlad.scale
	var entity_modulate := vlad.modulate
	for i in 20:
		vlad.global_position += Vector2(4, 0)
		await wait_frames(1)
	assert_near(vlad.global_position.x, 380.0, 0.001, "entity position untouched by the rig")
	assert_eq(facing.rotation, facing_rot, "facing carrier untouched by the rig")
	assert_eq(vlad.scale, entity_scale, "entity scale untouched")
	assert_eq(vlad.modulate, entity_modulate, "entity modulate untouched")
	assert_true(absf(rig.body.part(&"leg_f").rotation - rig.body.rest_of(&"leg_f").get_rotation()) > 0.01, "a moving entity walks")
	# The rig mirrors the facing it reads (cosine of the carrier's rotation).
	facing.rotation = PI
	await wait_frames(2)
	assert_true(rig.body.scale.x < 0.0, "faces left with the carrier")
	facing.rotation = 0.0
	await wait_frames(2)
	assert_true(rig.body.scale.x > 0.0, "faces right again")
	vlad.damaged.emit(DamagePacket.make(null, vlad, 1.0, null, 0))
	await wait_frames(1)
	assert_true(rig.body.modulate.r > 1.0, "hurt flash from the scene-wired damaged signal")
	rig.set_on_screen(false)
	assert_false(rig.is_processing(), "asleep again off screen")
	assert_eq(CharacterRig.awake_count(), awake_before)
	vlad.queue_free()
	await wait_frames(1)


## The step phase follows the distance in units of the drawn legs: a monster
## grown to 1.5x (or the rig's own +-4 % size) takes proportionally longer
## steps, so its feet stay planted instead of pedalling.
func test_stride_follows_the_entity_scale() -> void:
	var grount := await _spawn_rigged(GROUNT, Vector2(500, 300), CharacterRig.Tier.FULL) as MonsterBase
	var rig := grount.get_node(^"Rig") as CharacterRig
	grount._stage_tween.kill()
	rig.set_on_screen(true)
	for s: float in [1.0, 1.5]:
		grount.scale = Vector2(s, s)
		var stride := rig.profile.stride * rig._size * s
		assert_near(rig.walk_stride(), stride, 0.0001, "stride at scale %.2f" % s)
		rig._last_pos = grount.global_position
		var phase := rig._walk_phase
		for i in 10:
			grount.global_position += Vector2(3, 0)
			rig._process(1.0 / 60.0)
		assert_near(rig._walk_phase - phase, 30.0 / stride * PI, 0.0001, "30 px at scale %.2f" % s)
	assert_true(rig.walk_stride() > rig.profile.stride * 1.4, "the evolved monster's step is longer")
	rig.set_on_screen(false)
	grount.queue_free()
	await wait_frames(1)


## Every entity carries a Rig; until its scene adds a body it stays inert:
## never awake, nothing drawn (not even its ground shadow), events ignored,
## VFX keep the AnimatedSprite2D.
func test_rig_without_body_stays_inert() -> void:
	var awake_before := CharacterRig.awake_count()
	var mob := await spawn_frozen(UNMIGRATED, Vector2(200, 200)) as EntityBase
	var rig := mob.get_node(^"Rig") as CharacterRig
	assert_true(rig.body == null, "no body under the Rig")
	assert_true(rig.shadow != null and not rig.shadow.visible, "its ground shadow stays hidden")
	assert_eq(mob.visual_root(), mob.get_node(^"AnimatedSprite2D"), "VFX fall back to the sprite")
	rig.set_on_screen(true)
	CharacterRig.force_awake = true
	rig._on_screen_entered()
	assert_false(rig.is_processing(), "an inert rig never wakes")
	assert_eq(CharacterRig.awake_count(), awake_before)
	mob.announce_cast(null, null)
	mob.damaged.emit(DamagePacket.make(null, mob, 1.0, null, 0))
	rig.set_stage(2)
	rig.play_move(&"attack")
	await wait_frames(1)
	assert_false(rig.is_processing(), "events do not wake it")
	mob.queue_free()
	await wait_frames(1)


## Monster evolution reaches the rig through the scene-wired `evolved` signal.
func test_monster_stage_reaches_the_rig() -> void:
	var grount := await _spawn_rigged(GROUNT, Vector2(500, 300), CharacterRig.Tier.FULL)
	var body := (grount.get_node(^"Rig") as CharacterRig).body
	assert_false(body.part(&"crown").visible, "stage 1")
	(grount as MonsterBase).evolved.emit(2)
	assert_true(body.part(&"crown").visible, "evolved(2) -> Rig.set_stage(2)")
	grount.queue_free()
	await wait_frames(1)


## The tools' switch (sim_trace RIGS_AWAKE=1, bench rigs_awake=1): set through
## the script by path, it wakes every rig with a body whatever the notifier says.
func test_force_awake_switch() -> void:
	load(RIG_SCRIPT).set("force_awake", true)
	assert_true(CharacterRig.force_awake, "the -s tools reach the static switch by path")
	var awake_before := CharacterRig.awake_count()
	var vlad := await _spawn_rigged(VLAD, Vector2(300, 300), CharacterRig.Tier.FULL)
	var rig := vlad.get_node(^"Rig") as CharacterRig
	assert_true(rig.is_processing(), "awake off screen")
	assert_eq(int(load(RIG_SCRIPT).call("awake_count")), awake_before + 1, "awake_count by path (bench rigs_awake_mean)")
	rig._on_screen_exited()
	assert_true(rig.is_processing(), "the notifier cannot put it to sleep")
	vlad.queue_free()
	await wait_frames(1)
	assert_eq(CharacterRig.awake_count(), awake_before, "freed rigs leave the count")


## Over BUDGET awake rigs, mobs (BUDGETED) animate every other frame,
## staggered; heroes and the monster (FULL) every frame.
func test_budget_halves_mob_rigs() -> void:
	var over := CharacterRig.BUDGET + 1
	for frame in 4:
		for stagger in 2:
			assert_false(CharacterRig.skips_frame(CharacterRig.Tier.FULL, over, frame, stagger), "FULL never skips")
			assert_false(CharacterRig.skips_frame(CharacterRig.Tier.BUDGETED, CharacterRig.BUDGET, frame, stagger), "within budget never skips")
	for stagger in 2:
		var skipped := 0
		for frame in 2:
			if CharacterRig.skips_frame(CharacterRig.Tier.BUDGETED, over, frame, stagger):
				skipped += 1
		assert_eq(skipped, 1, "half rate over budget (stagger %d)" % stagger)
	assert_true(CharacterRig.skips_frame(CharacterRig.Tier.BUDGETED, over, 1, 0) != CharacterRig.skips_frame(CharacterRig.Tier.BUDGETED, over, 1, 1), "staggered: the two halves alternate")
