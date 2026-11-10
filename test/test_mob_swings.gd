extends TestCase

## The swings that carry no ability (Phase 7, 7.4): a mob's basic swing
## (MobBase announces it with announce_cast(null)) and Ted's fox's bite play
## the rig's attack move and the rig's swing_fx (the generic bite or claw
## recipe) only while the rig plays moves: awake on screen and inside the rig
## budget. Over the budget a mob swings with the procedural swing and a hit
## only flashes it, with no effect; asleep (off screen) nothing plays at all.
## The hits' packets keep carrying no ability. The bite program keeps the
## toning-down rules, its pools never grow and it draws no global random
## number.

const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"
const BAT := "res://Scenes/NPCs/Mob/Mobs/Bat/Bat.tscn"
const HOG := "res://Scenes/NPCs/Mob/Mobs/Hog/Hog.tscn"
const PET := "res://Scenes/NPCs/Hero/Heros/Support/Ted/Abilities/Passive/TedsPet.tscn"
const BITE := "res://Assets/Vfx/recipes/fx_generic_bite.tres"
const CLAW := "res://Assets/Vfx/recipes/fx_generic_claw.tres"
const FIXTURE_BODY := "res://test/fixtures/rig_fixture/rig_fixture_body.tscn"
const FIXTURE_MOTION := "res://test/fixtures/rig_fixture/rig_fixture_motion.tres"


func after_each() -> void:
	CharacterRig.force_awake = false


## The two generic recipes name hit programs AbilityVfx plays; the Bat and
## the fox bite, the Hog claws; heroes and monsters strike with abilities and
## carry none.
func test_generic_recipes_and_who_swings_them() -> void:
	var bite := load(BITE) as AbilityFxRecipe
	var claw := load(CLAW) as AbilityFxRecipe
	assert_eq(bite.cue, &"bite", "the generic bite")
	assert_eq(claw.cue, &"claw", "the generic claw")
	for fx: AbilityFxRecipe in [bite, claw]:
		assert_true(fx.cue in AbilityVfx.HIT_CUES and fx.cue in AbilityVfx.CUES, "%s is a hit program" % fx.cue)
	var expected: Dictionary[String, String] = {BAT: BITE, HOG: CLAW, PET: BITE, VLAD: "", GROUNT: ""}
	for path: String in expected:
		var inst := (load(path) as PackedScene).instantiate()
		var rig := inst.get_node(^"Rig") as CharacterRig
		var got: String = rig.swing_fx.resource_path if rig.swing_fx != null else ""
		assert_eq(got, expected[path], "%s swings %s" % [path.get_file(), expected[path].get_file()])
		inst.free()


## FULL rigs are always inside the budget, BUDGETED ones up to BUDGET awake;
## the half-rate rule is the same line.
func test_the_budget_rule() -> void:
	var full := CharacterRig.Tier.FULL
	var mob := CharacterRig.Tier.BUDGETED
	assert_true(CharacterRig.within_budget(full, CharacterRig.BUDGET * 10), "FULL: always")
	assert_true(CharacterRig.within_budget(mob, CharacterRig.BUDGET), "a mob at the budget")
	assert_false(CharacterRig.within_budget(mob, CharacterRig.BUDGET + 1), "a mob over it")
	for frame in 2:
		assert_false(CharacterRig.skips_frame(mob, CharacterRig.BUDGET, frame, 0), "inside: every frame")


## On screen and inside the budget, a Bat's swing plays its attack move and
## two jaws snap shut over the target's body (gone within HEAD_COVER); the
## packet still carries no ability.
func test_mob_swing_bites_inside_the_budget() -> void:
	var vfx := _vfx()
	var vlad := await spawn_frozen(VLAD, Vector2(150, 120))
	var bat := await spawn_frozen(BAT, Vector2(120, 120)) as MobBase
	var rig := bat.get_node(^"Rig") as CharacterRig
	rig.set_on_screen(true)
	assert_true(CharacterRig.awake_count() <= CharacterRig.BUDGET and rig.plays_moves(), "awake inside the budget")
	var packets := _swing(bat, vlad)
	assert_eq(packets.size(), 1, "the swing landed")
	if packets.size() == 1:
		assert_true(packets[0].ability == null and packets[0].source == bat, "its packet carries no ability")
	assert_eq(rig.current_move(), &"attack", "the attack move")
	assert_eq(vfx.swings_played, 1, "one swing effect")
	var jaws := _sprites(vfx, FxTex.BITE)
	assert_eq(jaws.size(), 2, "two jaws")
	if jaws.size() == 2:
		for i in jaws:
			assert_true(vfx.over.life[i] <= AbilityVfx.HEAD_COVER, "a jaw over the body for %.2f s" % vfx.over.life[i])
		var gap := vfx.over.pos[jaws[0]].distance_to(vfx.over.pos[jaws[1]])
		assert_near(absf(angle_difference(vfx.over.rot[jaws[0]], vfx.over.rot[jaws[1]])), PI, 0.001, "the lower jaw turned over")
		await wait_frames(4)
		assert_true(vfx.over.pos[jaws[0]].distance_to(vfx.over.pos[jaws[1]]) < gap * 0.6, "the jaws snap together")
	bat.queue_free()
	vlad.queue_free()
	vfx.queue_free()
	await wait_frames(1)


## Over the budget the same swing plays only the procedural swing, no move
## and no effect, and a hit only flashes the mob (no hurt move); back inside
## the budget the next swing bites again.
func test_mob_swing_over_the_budget_is_procedural_and_plain() -> void:
	var vfx := _vfx()
	var vlad := await spawn_frozen(VLAD, Vector2(150, 120))
	var hog := await spawn_frozen(HOG, Vector2(120, 120)) as MobBase
	var rig := hog.get_node(^"Rig") as CharacterRig
	rig.set_on_screen(true)
	var crowd := _puppets(maxi(0, CharacterRig.BUDGET + 1 - CharacterRig.awake_count()))
	await wait_frames(1)
	assert_true(CharacterRig.awake_count() > CharacterRig.BUDGET, "over the budget (%d awake)" % CharacterRig.awake_count())
	assert_false(rig.plays_moves(), "no moves over the budget")
	var packets := _swing(hog, vlad)
	assert_eq(packets.size(), 1, "the swing still lands (gameplay)")
	assert_eq(rig.current_move(), &"", "no authored move")
	assert_true(rig._act > 0.0, "the procedural swing")
	assert_eq(vfx.swings_played, 0, "no swing effect")
	assert_eq(_sprites(vfx, FxTex.CLAW).size(), 0, "no claw marks")
	hog.damaged.emit(DamagePacket.make(vlad, hog, 1.0, null, 0))
	await wait_frames(2)
	assert_eq(rig.current_move(), &"", "a hit plays no hurt move")
	assert_true(rig.body.modulate.r > 1.0, "but flashes")
	crowd.queue_free()
	await wait_frames(1)
	assert_true(rig.plays_moves(), "inside the budget again")
	_swing(hog, vlad)
	assert_eq(rig.current_move(), &"attack", "the attack move again")
	assert_eq(vfx.swings_played, 1, "and its claw")
	assert_eq(_sprites(vfx, FxTex.CLAW).size(), 1, "three raking marks")
	hog.queue_free()
	vlad.queue_free()
	vfx.queue_free()
	await wait_frames(1)


## Off screen (headless: the rig sleeps) a swing plays nothing at all.
func test_mob_swing_off_screen_shows_nothing() -> void:
	var vfx := _vfx()
	var vlad := await spawn_frozen(VLAD, Vector2(150, 120))
	var bat := await spawn_frozen(BAT, Vector2(120, 120)) as MobBase
	var rig := bat.get_node(^"Rig") as CharacterRig
	assert_false(rig.is_processing() or rig.plays_moves(), "asleep off screen")
	var packets := _swing(bat, vlad)
	assert_eq(packets.size(), 1, "the swing lands (gameplay)")
	assert_eq(rig.current_move(), &"", "no move")
	assert_eq(rig._act, 0.0, "not even the procedural swing")
	assert_eq([vfx.swings_played, vfx.over.live], [0, 0], "no effect")
	bat.queue_free()
	vlad.queue_free()
	vfx.queue_free()
	await wait_frames(1)


## Ted's fox bites with the generic bite: its attack move and the jaws, while
## its packet keeps carrying no ability (Loyal Companion and the damage
## pipeline see the same hit as before).
func test_pet_bite_plays_the_generic_bite() -> void:
	var vfx := _vfx()
	var ted := Node2D.new()
	ted.position = Vector2(150, 150)
	add_child(ted)
	var hog := await spawn_frozen(HOG, Vector2(185, 150)) as MobBase
	var pet := (load(PET) as PackedScene).instantiate() as CharacterBody2D
	pet.position = Vector2(150, 150)
	pet.set("owner_entity", ted)
	add_child(pet)
	pet.set_physics_process(false)  # the test drives its bite
	await wait_physics_frames(4)
	var rig := pet.get_node(^"Rig") as CharacterRig
	rig.set_on_screen(true)
	pet.set("current_target", hog)
	var packets: Array[DamagePacket] = []
	var cb := func(p: DamagePacket) -> void: packets.append(p)
	EventBus.damage_applied.connect(cb)
	pet.call("_perform_attack")
	EventBus.damage_applied.disconnect(cb)
	assert_eq(packets.size(), 1, "the bite landed")
	if packets.size() == 1:
		assert_true(packets[0].ability == null and packets[0].source == pet, "its packet carries no ability")
	assert_eq(rig.current_move(), &"attack", "the quadruped attack move")
	assert_eq(vfx.swings_played, 1, "one swing effect")
	assert_eq(_sprites(vfx, FxTex.BITE).size(), 2, "two jaws")
	pet.queue_free()
	hog.queue_free()
	ted.queue_free()
	vfx.queue_free()
	await wait_frames(1)


## The bite alone: two jaw sprites and nothing else (no rings, puffs or
## primitives); many bites and claws keep the pools at their caps and draw
## no global random number.
func test_bite_keeps_the_rules_and_the_pools() -> void:
	var vfx := _vfx()
	var a := Node2D.new()
	a.position = Vector2(60, 60)
	add_child(a)
	var b := Node2D.new()
	b.position = Vector2(100, 90)
	add_child(b)
	var bite := load(BITE) as AbilityFxRecipe
	var claw := load(CLAW) as AbilityFxRecipe
	vfx._play_hit(a, b, bite)
	assert_eq([vfx.over.live, vfx.under.live, vfx.marks.live], [2, 0, 0], "two jaws only")
	assert_eq(vfx.widest_ring(), 0.0, "no ring")
	for i in vfx.over.capacity:
		if vfx.over.tex[i] != null:
			assert_true(vfx.over.tex[i] == FxTex.BITE and vfx.over.life[i] <= AbilityVfx.HEAD_COVER, "a jaw, briefly")
	seed(4243)
	var expected: Array[int] = []
	for _i in 8:
		expected.append(randi())
	seed(4243)
	for _round in 120:
		vfx._play_hit(a, b, bite)
		vfx._play_hit(b, a, claw)
	assert_true(vfx.over.live <= AbilityVfx.OVER_CAP, "capped (%d)" % vfx.over.live)
	assert_eq([vfx.over.capacity, vfx.over.pos.size()], [AbilityVfx.OVER_CAP, AbilityVfx.OVER_CAP], "never grew")
	var after: Array[int] = []
	for _i in 8:
		after.append(randi())
	assert_eq(after, expected, "the vfx drew no global random number")
	a.queue_free()
	b.queue_free()
	vfx.queue_free()
	await wait_frames(1)


# ---------- helpers ----------

## A fresh AbilityVfx. The test viewport shows the world from 0,0 down and
## right (grown by CULL_MARGIN), where the tests place their characters.
func _vfx() -> AbilityVfx:
	var vfx := AbilityVfx.new()
	add_child(vfx)
	return vfx


## `mob` swings at `target` as its AI does (MobBase._perform_basic_attack);
## returns the packets that landed.
func _swing(mob: MobBase, target: Node2D) -> Array[DamagePacket]:
	var packets: Array[DamagePacket] = []
	var cb := func(p: DamagePacket) -> void: packets.append(p)
	EventBus.damage_applied.connect(cb)
	mob.set_target(target)
	mob._perform_basic_attack()
	EventBus.damage_applied.disconnect(cb)
	return packets


## The live overlay sprites drawing `tex`.
func _sprites(vfx: AbilityVfx, tex: Texture2D) -> Array[int]:
	var out: Array[int] = []
	for i in vfx.over.capacity:
		if vfx.over.tex[i] == tex:
			out.append(i)
	return out


## `n` awake fixture puppets (they count against the rig budget).
func _puppets(n: int) -> Node2D:
	var holder := Node2D.new()
	for i in n:
		var rig := CharacterRig.new()
		rig.profile = load(FIXTURE_MOTION)
		var body := (load(FIXTURE_BODY) as PackedScene).instantiate() as RigBody
		rig.add_child(body)
		rig.body = body
		holder.add_child(rig)
	add_child(holder)
	return holder
