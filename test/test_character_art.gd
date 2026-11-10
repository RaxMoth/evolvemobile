extends TestCase

## The game's character art in Assets/Characters (test_rig_pipeline covers the
## builder and runtime on a fixture): the ten characters are built from their
## src/ (kept out of the import by a .gdignore), each sheet imports at its VRAM
## scale with mipmaps, every composite portrait imports as a DPITexture, and the
## motion profiles fit the art: flyers have wings, sizes are graded, and the
## walk stride matches the legs so the feet do not slide.

const ROOT := "res://Assets/Characters"
const HEROES: Array[String] = ["irelia", "river", "ted", "vlad"]
const MONSTERS: Array[String] = ["gorrak", "grount", "nyxa"]
## Ted's pet and the jungle mobs.
const SMALL: Array[String] = ["bat", "hog", "pet"]
## Sheet pixels per art unit: 2 for the small ones (VRAM), 3 for the rest.
const SMALL_SHEET_SCALE := 2.0
const SHEET_SCALE := 3.0
const BODY_PLANS: Dictionary[String, RigProfile.BodyPlan] = {
	"irelia": RigProfile.BodyPlan.HUMANOID, "river": RigProfile.BodyPlan.HUMANOID,
	"ted": RigProfile.BodyPlan.HUMANOID, "vlad": RigProfile.BodyPlan.HUMANOID,
	"gorrak": RigProfile.BodyPlan.HUMANOID, "grount": RigProfile.BodyPlan.HUMANOID,
	"hog": RigProfile.BodyPlan.QUADRUPED, "pet": RigProfile.BodyPlan.QUADRUPED,
	"bat": RigProfile.BodyPlan.FLYER, "nyxa": RigProfile.BodyPlan.FLYER,
}
const HERO_WORLD_SCALE := 0.4
const MONSTER_WORLD_SCALE := 0.6
## Grount's evolution stages have their own portraits.
const STAGE_PORTRAITS: Array[String] = ["grount_s2", "grount_s3"]


func _all() -> Array[String]:
	var ids: Array[String] = []
	ids.append_array(HEROES)
	ids.append_array(MONSTERS)
	ids.append_array(SMALL)
	ids.sort()
	return ids


func _body(id: String) -> RigBody:
	return (load("%s/%s/%s_body.tscn" % [ROOT, id, id]) as PackedScene).instantiate() as RigBody


func _profile(id: String) -> RigProfile:
	return load("%s/%s/%s_motion.tres" % [ROOT, id, id]) as RigProfile


func test_every_character_is_built_from_its_source() -> void:
	assert_eq(RigBuilder.character_dirs(ROOT), PackedStringArray(_all()), "the ten characters have a src/")
	for id in _all():
		var dir := "%s/%s" % [ROOT, id]
		assert_true(FileAccess.file_exists(dir + "/src/.gdignore"), "%s/src is never imported" % id)
		var body := _body(id)
		assert_eq(String(body.character_id), id, "%s body" % id)
		assert_true(body.part(&"body") != null, "%s has a root part named body" % id)
		body.free()


func test_sheets_import_at_their_vram_scale() -> void:
	for id in _all():
		var want := SMALL_SHEET_SCALE if SMALL.has(id) else SHEET_SCALE
		var sheet := "%s/%s/%s_sheet.svg" % [ROOT, id, id]
		var imp := FileAccess.get_file_as_string(sheet + ".import")
		assert_true(imp.contains("svg/scale=%.1f\n" % want), "%s sheet svg/scale %s" % [id, want])
		assert_true(imp.contains("mipmaps/generate=true"), "%s sheet has mipmaps" % id)
		var tex := load(sheet) as Texture2D
		assert_eq(tex.get_width(), roundi(RigBuilder.SHEET_WIDTH * want), "%s sheet rasterised at x%s" % [id, want])
		var body := _body(id)
		assert_eq(body.sheet_scale, want, "%s body regions are in sheet pixels at x%s" % [id, want])
		body.free()


func test_portraits_import_as_dpitextures() -> void:
	var names: Array[String] = _all()
	names.append_array(STAGE_PORTRAITS)
	for portrait_name in names:
		var id := portrait_name.get_slice("_", 0)
		var path := "%s/%s/%s.svg" % [ROOT, id, portrait_name]
		var tex := load(path) as Texture2D
		assert_true(tex is DPITexture, "%s imports as a DPITexture (got %s)" % [path, tex.get_class() if tex else "null"])
		if tex != null:
			assert_eq(tex.get_size(), Vector2(128, 160), "%s is on the 128x160 rig canvas" % portrait_name)


func test_motion_profiles_fit_the_art() -> void:
	for id in _all():
		var profile := _profile(id)
		assert_true(profile != null, "%s has a motion profile" % id)
		if profile == null:
			continue
		assert_eq(profile.body_plan, BODY_PLANS[id], "%s body plan" % id)
		var body := _body(id)
		assert_eq(profile.body_plan == RigProfile.BodyPlan.FLYER, body.part(&"wing_f") != null,
			"%s: flyers and only flyers have wings" % id)
		body.free()
		if HEROES.has(id):
			assert_eq(profile.world_scale, HERO_WORLD_SCALE, "%s hero world scale" % id)
		elif MONSTERS.has(id):
			assert_eq(profile.world_scale, MONSTER_WORLD_SCALE, "%s monster world scale" % id)
		else:
			assert_true(profile.world_scale < HERO_WORLD_SCALE, "%s is smaller than a hero" % id)


## A planted foot travels back 2 x leg x sin(leg_swing) during the half cycle
## in which the body moves stride / 2, so stride = 4 x leg x sin(leg_swing) x
## world_scale keeps the feet from sliding (leg = hip pivot to sole, from the
## generated sprite region; at full_speed, where the swing is full).
func test_stride_matches_the_legs() -> void:
	var walkers := 0
	for id in _all():
		var body := _body(id)
		var leg := body.part(&"leg_f") as Sprite2D
		if leg != null:
			walkers += 1
			var profile := _profile(id)
			var sole := (leg.offset.y + leg.region_rect.size.y) / body.sheet_scale - RigBuilder.PAD
			var want := 4.0 * sole * sin(profile.leg_swing) * profile.world_scale
			assert_near(profile.stride, want, want * 0.05, "%s stride for a %.0f-unit leg" % [id, sole])
			assert_true(profile.full_speed > 0.0, "%s full_speed" % id)
		body.free()
	assert_eq(walkers, 8, "every character but the two flyers walks on legs")
