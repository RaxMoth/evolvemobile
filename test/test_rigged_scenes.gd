extends TestCase

## The character scenes migrated to their SVG rigs (the four heroes, Ted's
## pet, Grount, Nyxa and Gorrak, and the Bat and Hog mobs): each Rig carries the character's own
## generated body and motion profile, tier FULL for heroes, the pet and the
## monster, BUDGETED for mobs; no pixel AnimatedSprite2D is left (8.3 retired
## that path) while the hidden facing carrier stays; the HP bar sits just
## above the rig's art and clears its tallest pose (at every monster stage);
## the screen notifier covers the drawn body; every rig stands on an ink
## contact shadow; and in a match the rig walks (or flies), faces and flinches
## with its character, Grount's shows its stage's parts, mob rigs go half rate
## over the budget and a pooled mob's rig starts its next life clean.
## test_rig_pipeline covers the runtime itself on the fixture.

const ROOT := "res://Assets/Characters"
const HEROES: Dictionary[String, String] = {
	"irelia": "res://Scenes/NPCs/Hero/Heros/Support/Irelia/Irelia.tscn",
	"river": "res://Scenes/NPCs/Hero/Heros/Healer/River/River.tscn",
	"ted": "res://Scenes/NPCs/Hero/Heros/Support/Ted/Ted.tscn",
	"vlad": "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn",
}
const MONSTERS: Dictionary[String, String] = {
	"grount": "res://Scenes/NPCs/Monster/Grount/Grount.tscn",
	"nyxa": "res://Scenes/NPCs/Monster/Nyxa/Nyxa.tscn",
	"gorrak": "res://Scenes/NPCs/Monster/Gorrak/Gorrak.tscn",
}
const MOBS: Dictionary[String, String] = {
	"bat": "res://Scenes/NPCs/Mob/Mobs/Bat/Bat.tscn",
	"hog": "res://Scenes/NPCs/Mob/Mobs/Hog/Hog.tscn",
}
const PET := "res://Scenes/NPCs/Hero/Heros/Support/Ted/Abilities/Passive/TedsPet.tscn"
const PET_ID := "pet"
const FIXTURE_BODY := "res://test/fixtures/rig_fixture/rig_fixture_body.tscn"
const FIXTURE_MOTION := "res://test/fixtures/rig_fixture/rig_fixture_motion.tres"
## Grount Slam's hop scales visual_root() (the rig) up by this much mid-leap
## (grount_slam.gd), so Grount's notifier covers that too.
const SLAM_HOP := 1.2
## World px between the top of the art (RigBody.art_height() x world_scale,
## rounded) and the bottom edge of the HP bar.
const HP_BAR_GAP := 6.0
## CharacterRig's private per-instance size spread (+-4 %).
const MAX_SIZE := 1.04
const SHADOW_BLOB := "res://Assets/Characters/shadow_blob.svg"


func after_each() -> void:
	CharacterRig.force_awake = false


func _instance(path: String) -> Node2D:
	return (load(path) as PackedScene).instantiate() as Node2D


func _rig(inst: Node) -> CharacterRig:
	return inst.get_node(^"Rig") as CharacterRig


## Every migrated EntityBase scene by character id.
func _entities() -> Dictionary[String, String]:
	var all: Dictionary[String, String] = {}
	all.merge(HEROES)
	all.merge(MONSTERS)
	all.merge(MOBS)
	return all


## Height of the art above the feet that the HP bar clears, art units: the
## body's height for a walker; for a flyer (its art floats above its feet)
## the art's top at its highest hover.
func _head_height(body: RigBody, p: RigProfile) -> float:
	if p.body_plan == RigProfile.BodyPlan.FLYER:
		return -body.bounds.position.y + p.hover * 1.35
	return body.art_height()


## Highest point of the drawn art above the feet, world px: the art's top at
## the largest size, breathing in, at the top of a walk bounce (or hover).
func _max_top(body: RigBody, p: RigProfile) -> float:
	var lift := p.hover * 1.35 if p.body_plan == RigProfile.BodyPlan.FLYER else p.bounce
	return (-body.bounds.position.y * (1.0 + p.breathe_amount) + lift) * p.world_scale * MAX_SIZE


## The drawn body's box in world px around the feet, either facing, at its
## widest (breathing out under a hurt squash) and tallest.
func _max_box(body: RigBody, p: RigProfile) -> Rect2:
	var b := body.bounds
	var half := maxf(-b.position.x, b.end.x) * (1.0 + p.breathe_amount + p.hurt_squash) * p.world_scale * MAX_SIZE
	var bottom := b.end.y * (1.0 + p.breathe_amount) * p.world_scale * MAX_SIZE
	var top := _max_top(body, p)
	return Rect2(-half, -top, 2.0 * half, top + bottom)


func _check_rig(inst: Node, id: String, rig_tier: CharacterRig.Tier = CharacterRig.Tier.FULL) -> void:
	var rig := _rig(inst)
	assert_true(rig.body != null, "%s: Rig.body is set in the scene" % id)
	if rig.body == null:
		return
	assert_eq(rig.body.get_parent(), rig, "%s: the body is the Rig's child" % id)
	assert_eq(String(rig.body.character_id), id, "%s: its own body" % id)
	assert_eq(rig.body.scene_file_path, "%s/%s/%s_body.tscn" % [ROOT, id, id], "%s: the generated body scene" % id)
	assert_eq(String(rig.body.name), id.capitalize() + "Body", "%s: <Id>Body" % id)
	assert_true(rig.profile != null and rig.profile.resource_path == "%s/%s/%s_motion.tres" % [ROOT, id, id], "%s: its motion profile" % id)
	assert_eq(rig.tier, rig_tier, "%s: tier %s" % [id, CharacterRig.Tier.keys()[rig_tier]])


## The pixel sprite is gone (8.3 retired the AnimatedSprite2D path); the hidden
## facing carrier stays.
func _check_sprite_retired(inst: Node, id: String) -> void:
	assert_true(_rig(inst).mover == null, "%s: an EntityBase drives its Rig as the parent" % id)
	assert_true(_animated_sprites(inst).is_empty(), "%s: no AnimatedSprite2D left" % id)
	var facing := inst.get_node_or_null(^"Sprite2D") as Sprite2D
	assert_true(facing != null and not facing.visible, "%s: the hidden facing carrier stays" % id)


## Every AnimatedSprite2D under `root` (none since 8.3).
func _animated_sprites(root: Node) -> Array[Node]:
	return root.find_children("*", "AnimatedSprite2D", true, false)


func test_heroes_carry_their_rig() -> void:
	for id in HEROES:
		var hero := _instance(HEROES[id])
		_check_rig(hero, id)
		_check_sprite_retired(hero, id)
		hero.free()


## The monster animates every frame (FULL); mobs are BUDGETED (half rate while
## more than CharacterRig.BUDGET rigs are awake).
func test_monster_and_mobs_carry_their_rig() -> void:
	for id in MONSTERS:
		var monster := _instance(MONSTERS[id])
		_check_rig(monster, id)
		_check_sprite_retired(monster, id)
		monster.free()
	for id in MOBS:
		var mob := _instance(MOBS[id])
		_check_rig(mob, id, CharacterRig.Tier.BUDGETED)
		_check_sprite_retired(mob, id)
		mob.free()


func test_pet_carries_its_rig() -> void:
	var pet := _instance(PET)
	_check_rig(pet, PET_ID)
	assert_eq(_rig(pet).mover, pet, "the pet (not an EntityBase) is the Rig's mover")
	var facing := pet.get_node_or_null(^"Sprite2D") as Sprite2D
	assert_true(facing != null and not facing.visible, "the hidden facing carrier is a plain Sprite2D")
	assert_true(_animated_sprites(pet).is_empty(), "no AnimatedSprite2D left")
	var notifier := pet.get_node_or_null(^"%ScreenNotifier") as VisibleOnScreenNotifier2D
	assert_true(notifier != null, "a unique ScreenNotifier for the rig's LOD")
	for sig in [&"ability_cast", &"damaged"]:
		assert_true(pet.has_signal(sig), "the pet announces %s like an EntityBase" % sig)
	pet.free()


## The HP bar's bottom edge sits HP_BAR_GAP above the art's height x
## world_scale (a flyer: its top at the highest hover) and clears the tallest
## pose.
func test_hp_bar_sits_above_the_head() -> void:
	var all := _entities()
	for id in all:
		var inst := _instance(all[id])
		var rig := _rig(inst)
		var hud := inst.get_node(^"%Hud") as Node2D
		var bar := inst.get_node(^"%HealthBar") as HpBar2D
		var bottom := hud.position.y + bar.position.y + bar.bar_size.y
		var expected := -(roundf(_head_height(rig.body, rig.profile) * rig.profile.world_scale) + HP_BAR_GAP)
		assert_near(bottom, expected, 0.01, "%s: HP bar bottom" % id)
		assert_true(-bottom > _max_top(rig.body, rig.profile), "%s: the bar clears the head" % id)
		inst.free()
	var pet := _instance(PET)
	var pet_rig := _rig(pet)
	var pet_bar := pet.get_node(^"HealthBar") as HpBar2D
	var pet_bottom := pet_bar.position.y + pet_bar.bar_size.y
	var pet_expected := -(roundf(pet_rig.body.art_height() * pet_rig.profile.world_scale) + HP_BAR_GAP)
	assert_near(pet_bottom, pet_expected, 0.01, "pet: HP bar bottom")
	assert_true(-pet_bottom > _max_top(pet_rig.body, pet_rig.profile), "pet: the bar clears the head")
	pet.free()


## A growing monster: the Hud is a child of the root, so its position grows
## with the stage scale (and Titan Form) while the bar keeps its pixel size
## (counter-scaled): the bar clears the grown head at every stage.
func test_monster_hp_bar_clears_the_head_at_every_stage() -> void:
	for id in MONSTERS:
		var monster := _instance(MONSTERS[id]) as MonsterBase
		var rig := _rig(monster)
		var hud := monster.get_node(^"%Hud") as Node2D
		var bar := monster.get_node(^"%HealthBar") as HpBar2D
		var stats := monster.monster_stats
		var titan := stats.get_scale_for_stage(monster.titan_stage).y * monster.titan_scale_mult
		for s: float in [stats.get_scale_for_stage(1).y, stats.get_scale_for_stage(2).y, stats.get_scale_for_stage(3).y, titan]:
			var bottom := s * hud.position.y + bar.position.y + bar.bar_size.y
			assert_true(-bottom > s * _max_top(rig.body, rig.profile), "%s at scale %.2f: bar %.1f clears the head" % [id, s, bottom])
		monster.free()


## The shadow radius each character had as a hand-set scene number before it
## was derived from the body (CharacterRig.shadow_radius_for): the profiles'
## shadow_per_width keep them within half a pixel.
const SHADOW_RADII: Dictionary[String, float] = {
	"irelia": 14.0, "river": 14.0, "ted": 14.0, "vlad": 14.0,
	"grount": 24.0, "bat": 9.0, "hog": 14.0, PET_ID: 10.0,
	# Nyxa and Gorrak were built on their rigs: the derived 132 x 0.6 x 0.21
	# and 109 x 0.6 x 0.36.
	"nyxa": 16.6, "gorrak": 23.5,
}
## River's body is the narrowest hero's: 13.4 px.
const SHADOW_TOLERANCE := 0.7


## Every rig stands on one contact shadow: the scene's "Shadow" Sprite2D
## (wired to `shadow`) is the Rig's first child, so it draws under the body,
## and holds the white blob, mipmapped and linear like the rig art. In the
## tree it shows in the palette's ink at shadow_alpha, SHADOW_SPREAD x 2 x
## shadow_radius wide, at the feet, where shadow_radius is the body's width x
## world_scale x the profile's shadow_per_width (no number per scene). Grount's
## is the biggest, the bat's and the fox's the smallest.
func test_rigs_stand_on_an_ink_contact_shadow() -> void:
	var ink := UiPalette.get_default().ink
	var paths: Dictionary[String, String] = {PET_ID: PET}
	paths.merge(_entities())
	var widths: Dictionary[String, float] = {}
	for id in paths:
		var inst := _instance(paths[id])
		var rig := _rig(inst)
		var shadow := rig.shadow
		assert_true(shadow != null and shadow.get_parent() == rig, "%s: Rig.shadow is the Rig's own Shadow" % id)
		if shadow == null:
			inst.free()
			continue
		assert_eq(String(shadow.name), "Shadow", "%s: the scene's Shadow node" % id)
		assert_eq(shadow.get_index(), 0, "%s: drawn first, under the body" % id)
		assert_true(shadow.texture != null and shadow.texture.resource_path == SHADOW_BLOB, "%s: the shadow blob" % id)
		assert_eq(shadow.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "%s: mipmapped like the rig art" % id)
		assert_eq(shadow.position, Vector2.ZERO, "%s: at the feet" % id)
		# The rig alone in the tree (puppet mode): its _ready sets the shadow up
		# from the scene's exports without the entity's AI.
		rig.owner = null
		inst.remove_child(rig)
		rig.mover = null
		add_child(rig)
		assert_true(shadow.visible, "%s: shown once the rig is live" % id)
		assert_eq(shadow.modulate, Color(ink, rig.shadow_alpha), "%s: the palette's ink at shadow_alpha" % id)
		var derived := rig.body.bounds.size.x * rig.profile.world_scale * rig.profile.shadow_per_width
		assert_near(rig.shadow_radius, derived, 0.0001, "%s: from the body's width" % id)
		assert_near(rig.shadow_radius, CharacterRig.shadow_radius_for(rig.body, rig.profile), 0.0001)
		assert_near(rig.shadow_radius, SHADOW_RADII.get(id, -1.0), SHADOW_TOLERANCE, "%s: the size it had" % id)
		var width := shadow.texture.get_width() * shadow.scale.x
		assert_near(width, 2.0 * rig.shadow_radius * CharacterRig.SHADOW_SPREAD, 0.01, "%s: sized to shadow_radius" % id)
		assert_eq(shadow.scale.x, shadow.scale.y, "%s: the blob keeps its ground ellipse" % id)
		widths[id] = width
		rig.free()
		inst.free()
	assert_eq(widths.size(), paths.size(), "every rig has its shadow")
	if widths.size() != paths.size():
		return
	assert_true(widths["grount"] > widths["vlad"] and widths["vlad"] > widths["bat"] and widths["vlad"] > widths[PET_ID],
			"Grount's shadow is the biggest, the bat's and the fox's the smallest: %s" % widths)


## The rig sleeps while its notifier is off screen, so the notifier must cover
## everything the rig can draw (it scales with the entity, like the rig).
func test_screen_notifier_covers_the_drawn_body() -> void:
	var paths: Dictionary[String, String] = {PET_ID: PET}
	paths.merge(_entities())
	for id in paths:
		var inst := _instance(paths[id])
		var rig := _rig(inst)
		var notifier := inst.get_node(^"%ScreenNotifier") as VisibleOnScreenNotifier2D
		var box := _max_box(rig.body, rig.profile)
		if MONSTERS.has(id):
			box = Rect2(box.position * SLAM_HOP, box.size * SLAM_HOP)
		assert_true(notifier.rect.encloses(box), "%s: notifier %s encloses the drawn body %s" % [id, notifier.rect, box])
		inst.free()


## A real hero in a match: the rig walks when the hero moves, mirrors the
## facing carrier, flashes when hurt, and is what visual effects target.
func test_hero_rigs_walk_face_and_flinch() -> void:
	for id in HEROES:
		var hero := await spawn_frozen(HEROES[id], Vector2(300, 300)) as EntityBase
		var rig := _rig(hero)
		var body := rig.body
		assert_eq(hero.visual_root(), rig, "%s: effects target the rig" % id)
		rig.set_on_screen(true)
		var facing := hero.get_node(^"Sprite2D") as Node2D
		facing.rotation = 0.0
		var swing := 0.0
		for i in 16:
			hero.global_position += Vector2(3, 0)
			await wait_frames(1)
			swing = maxf(swing, absf(body.part(&"leg_f").rotation - body.rest_of(&"leg_f").get_rotation()))
		assert_true(swing > 0.1, "%s walks (leg swing %.3f)" % [id, swing])
		assert_true(body.scale.x > 0.0, "%s faces right" % id)
		facing.rotation = PI
		await wait_frames(2)
		assert_true(body.scale.x < 0.0, "%s faces left with the carrier" % id)
		hero.damaged.emit(DamagePacket.make(null, hero, 1.0, null, 0))
		await wait_frames(1)
		assert_true(body.modulate.r > 1.0, "%s flinches (hurt flash)" % id)
		hero.queue_free()
		await wait_frames(1)


## The monster and the mobs in a match: walkers swing their legs, the bat
## beats its wings; each mirrors its facing carrier, flashes when hurt, and is
## what visual effects target.
func test_monster_and_mob_rigs_move_face_and_flinch() -> void:
	var paths: Dictionary[String, String] = {}
	paths.merge(MONSTERS)
	paths.merge(MOBS)
	for id in paths:
		var e := await spawn_frozen(paths[id], Vector2(300, 300)) as EntityBase
		var rig := _rig(e)
		var body := rig.body
		assert_eq(e.visual_root(), rig, "%s: effects target the rig" % id)
		rig.set_on_screen(true)
		var facing := e.get_node(^"Sprite2D") as Node2D
		facing.rotation = 0.0
		var limb := &"wing_f" if rig.profile.body_plan == RigProfile.BodyPlan.FLYER else &"leg_f"
		var swing := 0.0
		for i in 16:
			e.global_position += Vector2(3, 0)
			await wait_frames(1)
			swing = maxf(swing, absf(body.part(limb).rotation - body.rest_of(limb).get_rotation()))
		assert_true(swing > 0.1, "%s: %s swings (%.3f)" % [id, limb, swing])
		if rig.profile.body_plan == RigProfile.BodyPlan.FLYER:
			assert_true(body.position.y < 0.0, "%s hovers (%.1f)" % [id, body.position.y])
		assert_true(rig.shadow.visible and rig.shadow.global_position.is_equal_approx(e.global_position),
				"%s: its shadow stays on the ground at its feet" % id)
		assert_true(body.scale.x > 0.0, "%s faces right" % id)
		facing.rotation = PI
		await wait_frames(2)
		assert_true(body.scale.x < 0.0, "%s faces left with the carrier" % id)
		e.damaged.emit(DamagePacket.make(null, e, 1.0, null, 0))
		await wait_frames(1)
		assert_true(body.modulate.r > 1.0, "%s flinches (hurt flash)" % id)
		e.queue_free()
		await wait_frames(1)


## Grount evolving 1 -> 2 -> 3: the scene-wired evolved signal shows each
## stage's horns, eyes, spikes, cracks and chain and flashes the body on
## screen; the root still grows by the stage scale (gameplay size, which the
## rig inherits) and the legacy sprite path stays out of it.
func test_grount_rig_follows_its_stages() -> void:
	var grount := await spawn_frozen(MONSTERS["grount"], Vector2(3000, 0)) as MonsterBase
	var rig := _rig(grount)
	var body := rig.body
	var shown: Dictionary[int, Array] = {
		1: [&"horns_s1", &"eyes_s1"],
		2: [&"horns_s2", &"eyes_s2", &"spikes_s2"],
		3: [&"horns_s3", &"eyes_s3", &"spikes_s3", &"cracks_s3", &"chain_s3"],
	}
	rig.set_on_screen(true)
	for stage in [1, 2, 3]:
		if stage > 1:
			grount.gain_xp(1000.0 if stage == 2 else 0.0)
			assert_eq(grount.current_stage, stage)
			await wait_frames(1)
			assert_true(body.modulate.r > 1.0, "stage %d: evolution flash on screen" % stage)
		for other in shown:
			for part: StringName in shown[other]:
				assert_eq(body.part(part).visible, other == stage, "stage %d: %s" % [stage, part])
		assert_true(body.part(&"head").visible and body.part(&"body").visible, "stage %d: stage-free parts show" % stage)
	await wait_seconds(0.7)
	assert_eq(body.modulate, Color.WHITE, "the flash ends white")
	assert_near(grount.scale.x, grount._scale_for_stage(3).x, 0.001, "the root grew to the stage-3 size")
	assert_true(_animated_sprites(grount).is_empty(), "no stage SpriteFrames to swap in")
	assert_eq(grount.sprite.modulate, Color.WHITE, "no stage tint on the facing carrier")
	grount.queue_free()
	await wait_frames(1)


## Off screen the rig still follows the stage but does not keep a pending flash
## for when it wakes.
func test_grount_evolving_off_screen_does_not_flash_later() -> void:
	var grount := await spawn_frozen(MONSTERS["grount"], Vector2(3000, 0)) as MonsterBase
	var rig := _rig(grount)
	assert_false(rig.is_processing(), "headless = off screen = asleep")
	grount.gain_xp(1000.0)
	assert_true(rig.body.part(&"horns_s2").visible, "the stage's parts show while asleep")
	rig.set_on_screen(true)
	await wait_frames(1)
	assert_eq(rig.body.modulate, Color.WHITE, "no late flash on waking")
	grount.queue_free()
	await wait_frames(1)


## Puppet rigs (always awake) to fill the budget.
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


## A mob rig animates on every frame within the budget and on every other
## frame while more than CharacterRig.BUDGET rigs are awake.
func test_mob_rigs_go_half_rate_over_the_budget() -> void:
	var bat := await spawn_frozen(MOBS["bat"], Vector2(600, 600)) as EntityBase
	var rig := _rig(bat)
	var wing := rig.body.part(&"wing_f")
	rig.set_on_screen(true)
	var updates := 0
	var last := wing.rotation
	for i in 8:
		await wait_frames(1)
		if wing.rotation != last:
			updates += 1
		last = wing.rotation
	assert_true(CharacterRig.awake_count() <= CharacterRig.BUDGET, "within the budget")
	assert_eq(updates, 8, "within the budget: every frame")
	var crowd := _puppets(maxi(0, CharacterRig.BUDGET + 1 - CharacterRig.awake_count()))
	await wait_frames(1)
	assert_true(CharacterRig.awake_count() > CharacterRig.BUDGET, "over the budget (%d awake)" % CharacterRig.awake_count())
	updates = 0
	last = wing.rotation
	for i in 8:
		await wait_frames(1)
		if wing.rotation != last:
			updates += 1
		last = wing.rotation
	assert_eq(updates, 4, "over the budget: every other frame")
	crowd.queue_free()
	bat.queue_free()
	await wait_frames(1)


## Pooled mobs leave the tree and come back without a new _ready: the parked
## rig sleeps and drops its flash, and under the tools' force_awake switch the
## reused mob's rig wakes again.
func test_pooled_mob_rig_starts_clean() -> void:
	var awake_before := CharacterRig.awake_count()
	var mgr := make_spawn_manager(1, 0.2) as SpawnManager
	var area := mgr.get_child(0) as MobSpawnArea
	var vlad := await spawn_entity(HEROES["vlad"], Vector2(4000, 4000))
	area.activate()
	await wait_physics_frames(4)
	var bat := area.spawned_mobs[0] as MobBase
	var rig := _rig(bat)
	rig.set_on_screen(true)
	await wait_frames(1)  # resumed from a physics frame: let this frame's process run
	bat.damaged.emit(DamagePacket.make(null, bat, 1.0, null, 0))
	await wait_frames(1)
	assert_true(rig.body.modulate.r > 1.0, "flashing when it dies")
	EventBus.deal_damage(vlad, bat, 9999.0)
	await wait_frames(2)  # deferred release_mob
	assert_true(bat.is_parked and not bat.is_inside_tree(), "parked in the pool")
	assert_false(rig.is_processing(), "a parked rig sleeps")
	assert_eq(CharacterRig.awake_count(), awake_before, "and leaves the awake count")
	assert_eq(rig.body.modulate, Color.WHITE, "its flash is dropped")
	CharacterRig.force_awake = true
	await wait_seconds(0.5)
	assert_true(bat.is_inside_tree() and not bat.is_parked, "reused from the pool")
	assert_true(rig.is_processing(), "force_awake wakes the reused mob's rig")
	CharacterRig.force_awake = false
	vlad.queue_free()
	mgr.queue_free()
	await wait_frames(1)
	assert_eq(CharacterRig.awake_count(), awake_before, "freed rigs leave the count")


## The F3 overlay lists the rigs awake now and their mean since F3 was pressed.
func test_f3_overlay_reports_rigs_awake() -> void:
	var overlay := DebugOverlay.new()
	add_child(overlay)
	await wait_frames(1)
	overlay.set_active(true)
	var crowd := _puppets(3)
	var awake := CharacterRig.awake_count()
	await wait_frames(4)
	assert_near(overlay.rigs_awake_mean(), float(awake), 0.001, "mean over the frames since F3")
	overlay._collect_snapshots()
	assert_true(overlay._hud_label.text.contains("Rigs awake %d  mean %.1f  budget %d" % [awake, float(awake), CharacterRig.BUDGET]), overlay._hud_label.text)
	crowd.queue_free()
	overlay.queue_free()
	await wait_frames(1)


## Ted's pet is a CharacterBody2D: its Rig follows it through `mover`, reads
## its facing carrier, sleeps off screen and reacts to the pet's own scene-
## wired signals, without writing any of it.
func test_pet_rig_follows_the_pet() -> void:
	var awake_before := CharacterRig.awake_count()
	var ted := Node2D.new()
	ted.position = Vector2(600, 300)
	add_child(ted)
	var pet := _instance(PET) as CharacterBody2D
	pet.position = Vector2(600, 300)
	pet.set("owner_entity", ted)
	add_child(pet)
	await wait_physics_frames(4)
	var rig := _rig(pet)
	var body := rig.body
	var facing := pet.get_node(^"Sprite2D") as Node2D
	assert_false(rig.is_processing(), "headless = off screen = asleep")
	rig.set_on_screen(true)
	assert_eq(CharacterRig.awake_count(), awake_before + 1, "awake on screen")
	facing.rotation = 0.0
	var swing := 0.0
	for i in 16:
		pet.position += Vector2(3, 0)
		ted.position = pet.position
		await wait_frames(1)
		swing = maxf(swing, absf(body.part(&"leg_f").rotation - body.rest_of(&"leg_f").get_rotation()))
	assert_true(swing > 0.1, "the pet walks (leg swing %.3f)" % swing)
	assert_eq(facing.rotation, 0.0, "facing carrier untouched by the rig")
	assert_true(body.scale.x > 0.0, "faces right")
	facing.rotation = PI
	await wait_frames(2)
	assert_true(body.scale.x < 0.0, "faces left with the carrier")
	var hp: float = pet.get("current_health")
	pet.emit_signal(&"damaged", DamagePacket.make(null, pet, 1.0, null, 0))
	await wait_frames(1)
	assert_true(body.modulate.r > 1.0, "the scene-wired damaged signal flashes it")
	assert_eq(float(pet.get("current_health")), hp, "the signal is presentation only")
	pet.emit_signal(&"ability_cast", null, null)
	assert_eq(rig.current_move(), &"attack", "a bite plays the quadruped attack move")
	await wait_frames(6)
	assert_true(absf(body.position.x) > 0.5, "a bite moves the body (%.2f)" % body.position.x)
	rig.set_on_screen(false)
	assert_false(rig.is_processing(), "asleep again off screen")
	pet.queue_free()
	ted.queue_free()
	await wait_frames(1)
	assert_eq(CharacterRig.awake_count(), awake_before, "a freed pet leaves the count")


## Ted's real passive spawns the rigged pet beside him.
func test_teds_passive_spawns_the_rigged_pet() -> void:
	var ted := await spawn_frozen(HEROES["ted"], Vector2(0, 0))
	await wait_frames(3)
	var pet: Node2D = null
	for e in EntityRegistry.hero_side:
		if is_instance_valid(e) and not (e is HeroBase) and e.get("owner_entity") == ted:
			pet = e
	assert_true(pet != null, "Ted's passive spawned the pet")
	if pet:
		var rig := _rig(pet)
		assert_true(rig.body != null and String(rig.body.character_id) == PET_ID, "with its fox rig")
		CharacterRig.force_awake = true
		rig._on_screen_entered()
		assert_true(rig.is_processing(), "the rig wakes for its pet")
		pet.queue_free()
	ted.queue_free()
	await wait_frames(1)
