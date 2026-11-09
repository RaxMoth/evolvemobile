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


## The procedural layer writes only the channels that changed. An authored
## move writes the parts directly, so when it ends the rig must take every part
## back, even one whose procedural value never changed (an idle leg).
func test_procedural_pose_takes_over_after_a_move() -> void:
	var holder := Node2D.new()
	var rig := CharacterRig.new()
	rig.profile = load(FIXTURE_MOTION)
	rig.tier = CharacterRig.Tier.FULL
	var body := (load(FIXTURE_BODY) as PackedScene).instantiate() as RigBody
	rig.add_child(body)
	rig.body = body
	var anim := Animation.new()
	anim.length = 0.1
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, "%leg_f:rotation")
	anim.track_insert_key(track, 0.0, 1.0)
	anim.track_insert_key(track, 0.1, 1.0)
	var lib := AnimationLibrary.new()
	lib.add_animation(&"attack", anim)
	var player := AnimationPlayer.new()
	player.add_animation_library(&"", lib)
	rig.add_child(player)
	player.root_node = NodePath("../" + String(body.name))
	rig.moves = player
	holder.add_child(rig)
	add_child(holder)
	await wait_frames(3)
	var leg := body.part(&"leg_f")
	var rest := body.rest_of(&"leg_f").get_rotation()
	assert_near(leg.rotation, rest, 0.0001, "an idle puppet's leg rests")
	rig.play_move(&"attack")
	await wait_frames(2)
	assert_near(leg.rotation, 1.0, 0.0001, "the move drives the leg")
	await wait_seconds(0.3)
	assert_false(player.is_playing(), "the move is over")
	assert_near(leg.rotation, rest, 0.0001, "the procedural layer takes the leg back")
	holder.queue_free()
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
