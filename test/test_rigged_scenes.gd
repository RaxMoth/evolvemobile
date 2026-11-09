extends TestCase

## The character scenes migrated to their SVG rigs (the four heroes and Ted's
## pet so far): each Rig carries the character's own generated body, motion
## profile and tier FULL; the pixel AnimatedSprite2D is hidden with its dead
## SpriteFrames gone while the facing carrier stays; the HP bar sits just above
## the rig's art and clears its tallest pose; the screen notifier covers the
## drawn body; and in a match the rig walks, faces and flinches with its
## character. test_rig_pipeline covers the runtime itself on the fixture.

const ROOT := "res://Assets/Characters"
const HEROES: Dictionary[String, String] = {
	"irelia": "res://Scenes/NPCs/Hero/Heros/Support/Irelia/Irelia.tscn",
	"river": "res://Scenes/NPCs/Hero/Heros/Healer/River/River.tscn",
	"ted": "res://Scenes/NPCs/Hero/Heros/Support/Ted/Ted.tscn",
	"vlad": "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn",
}
const PET := "res://Scenes/NPCs/Hero/Heros/Support/Ted/Abilities/Passive/TedsPet.tscn"
const PET_ID := "pet"
## World px between the top of the art (RigBody.art_height() x world_scale,
## rounded) and the bottom edge of the HP bar.
const HP_BAR_GAP := 6.0
## CharacterRig's private per-instance size spread (+-4 %).
const MAX_SIZE := 1.04


func after_each() -> void:
	CharacterRig.force_awake = false


func _instance(path: String) -> Node2D:
	return (load(path) as PackedScene).instantiate() as Node2D


func _rig(inst: Node) -> CharacterRig:
	return inst.get_node(^"Rig") as CharacterRig


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


func _check_rig(inst: Node, id: String) -> void:
	var rig := _rig(inst)
	assert_true(rig.body != null, "%s: Rig.body is set in the scene" % id)
	if rig.body == null:
		return
	assert_eq(rig.body.get_parent(), rig, "%s: the body is the Rig's child" % id)
	assert_eq(String(rig.body.character_id), id, "%s: its own body" % id)
	assert_eq(rig.body.scene_file_path, "%s/%s/%s_body.tscn" % [ROOT, id, id], "%s: the generated body scene" % id)
	assert_eq(String(rig.body.name), id.capitalize() + "Body", "%s: <Id>Body" % id)
	assert_true(rig.profile != null and rig.profile.resource_path == "%s/%s/%s_motion.tres" % [ROOT, id, id], "%s: its motion profile" % id)
	assert_eq(rig.tier, CharacterRig.Tier.FULL, "%s: tier FULL" % id)


func test_heroes_carry_their_rig() -> void:
	for id in HEROES:
		var hero := _instance(HEROES[id])
		_check_rig(hero, id)
		assert_true(_rig(hero).mover == null, "%s: an EntityBase drives its Rig as the parent" % id)
		var sprite := hero.get_node(^"AnimatedSprite2D") as AnimatedSprite2D
		assert_false(sprite.visible, "%s: the pixel sprite is hidden" % id)
		assert_true(sprite.sprite_frames == null, "%s: its dead SpriteFrames are gone" % id)
		var facing := hero.get_node_or_null(^"Sprite2D") as Sprite2D
		assert_true(facing != null and not facing.visible, "%s: the hidden facing carrier stays" % id)
		hero.free()


func test_pet_carries_its_rig() -> void:
	var pet := _instance(PET)
	_check_rig(pet, PET_ID)
	assert_eq(_rig(pet).mover, pet, "the pet (not an EntityBase) is the Rig's mover")
	var facing := pet.get_node(^"Sprite2D") as AnimatedSprite2D
	assert_false(facing.visible, "the pixel sprite is hidden")
	assert_true(facing.sprite_frames == null, "its dead SpriteFrames are gone")
	var notifier := pet.get_node_or_null(^"%ScreenNotifier") as VisibleOnScreenNotifier2D
	assert_true(notifier != null, "a unique ScreenNotifier for the rig's LOD")
	for sig in [&"ability_cast", &"damaged"]:
		assert_true(pet.has_signal(sig), "the pet announces %s like an EntityBase" % sig)
	pet.free()


## The HP bar's bottom edge sits HP_BAR_GAP above the art's height x
## world_scale and clears the tallest pose.
func test_hp_bar_sits_above_the_head() -> void:
	for id in HEROES:
		var hero := _instance(HEROES[id])
		var rig := _rig(hero)
		var hud := hero.get_node(^"%Hud") as Node2D
		var bar := hero.get_node(^"%HealthBar") as HpBar2D
		var bottom := hud.position.y + bar.position.y + bar.bar_size.y
		var expected := -(roundf(rig.body.art_height() * rig.profile.world_scale) + HP_BAR_GAP)
		assert_near(bottom, expected, 0.01, "%s: HP bar bottom" % id)
		assert_true(-bottom > _max_top(rig.body, rig.profile), "%s: the bar clears the head" % id)
		hero.free()
	var pet := _instance(PET)
	var pet_rig := _rig(pet)
	var pet_bar := pet.get_node(^"HealthBar") as ProgressBar
	var pet_expected := -(roundf(pet_rig.body.art_height() * pet_rig.profile.world_scale) + HP_BAR_GAP)
	assert_near(pet_bar.offset_bottom, pet_expected, 0.01, "pet: HP bar bottom")
	assert_true(-pet_bar.offset_bottom > _max_top(pet_rig.body, pet_rig.profile), "pet: the bar clears the head")
	pet.free()


## The rig sleeps while its notifier is off screen, so the notifier must cover
## everything the rig can draw.
func test_screen_notifier_covers_the_drawn_body() -> void:
	var paths: Dictionary[String, String] = {PET_ID: PET}
	paths.merge(HEROES)
	for id in paths:
		var inst := _instance(paths[id])
		var rig := _rig(inst)
		var notifier := inst.get_node(^"%ScreenNotifier") as VisibleOnScreenNotifier2D
		var box := _max_box(rig.body, rig.profile)
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
	await wait_frames(3)
	assert_true(absf(body.part(&"body").position.x - body.rest_of(&"body").origin.x) > 0.5, "a bite lunges the body")
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
