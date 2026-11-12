extends TestCase

## The roster (GameManager.ROSTER): every entry is consistent with its scene,
## its rig and its art, ids are unique, every character has a skill tree, the
## menus read abilities from the scene's own .tres, and World's MonsterSlot
## spawns the selected monster during the scene's enter pass, at Grount's old
## child index (unknown ids fall back to the default).

const WORLD := "res://Scenes/World/World.tscn"
const HEAD_PART := "res://Assets/Characters/%s/src/parts/head.svg"
## Share of the head part's drawn box that head_region must cover.
const MIN_HEAD_COVERAGE := 0.6


func _roster() -> Roster:
	return GameManager.ROSTER


func test_entries_match_their_scenes_and_rigs() -> void:
	var roster := _roster()
	assert_eq(roster.heroes.size(), 4)
	assert_false(roster.monsters.is_empty())
	var seen: Array[StringName] = []
	for d in roster.all():
		var id := d.character_id()
		assert_false(id == &"", "every entry has an id")
		assert_false(seen.has(id), "ids are unique: %s" % id)
		seen.append(id)
		assert_eq(d.side, CharacterDef.MONSTER if roster.monsters.has(d) else CharacterDef.HEROES, "%s sits in its side's list" % id)
		var scene := d.scene()
		assert_true(scene != null, "%s has a scene" % id)
		assert_true(scene == load(d.scene_path), "%s: scene() is scene_path" % id)
		if scene == null:
			continue
		if d.is_monster():
			assert_true(CharacterDef.scene_property(scene, ".", &"monster_stats") == d.stats, "%s: def.stats IS the scene's MonsterStats" % id)
		else:
			assert_true(CharacterDef.scene_property(scene, "./HeroStats", &"base_stats") == d.stats, "%s: def.stats IS the scene's HeroStats" % id)
		assert_true(d.rig_body != null and d.rig_profile != null, "%s has a rig" % id)
		if d.rig_body != null:
			var body := d.rig_body.instantiate() as RigBody
			assert_eq(body.character_id, id, "%s: the rig body is its own" % id)
			body.free()
		assert_true(d.portrait is DPITexture, "%s portrait is an SVG DPITexture" % id)
		assert_true(d.skill_tree_def() != null, "%s has a skill tree" % id)
		assert_false(d.get_display_name().is_empty(), "%s has a name" % id)
		assert_false(d.role_text.is_empty(), "%s has a role line" % id)
		assert_true(d.role_icon() != null, "%s: role '%s' has a filter icon" % [id, d.role_filter])
		assert_true(UiPalette.get_default().tokens().has(d.accent_token), "%s: accent '%s' is a palette token" % [id, d.accent_token])
		assert_false(d.tagline.is_empty(), "%s has a tagline" % id)


func test_hero_entries_are_the_known_heroes() -> void:
	var ids := _roster().hero_ids()
	ids.sort()
	var known := GameManager.KNOWN_HERO_IDS.duplicate()
	known.sort()
	assert_eq(ids, known, "the roster's heroes are the ones the census knows")


func test_names_fall_back_to_the_stats() -> void:
	var irelia := _roster().find(&"irelia")
	assert_eq(irelia.get_display_name(), (irelia.stats as HeroStats).hero_name)
	var grount := _roster().find(&"grount")
	assert_eq(grount.get_display_name(), (grount.stats as MonsterStats).monster_name)
	assert_true(_roster().find(&"no_such_character") == null)


func test_abilities_are_the_scenes_own_resources() -> void:
	for d in _roster().all():
		var id := d.character_id()
		var abilities := d.abilities()
		assert_eq(abilities.size(), 4, "%s: every ability slot of the scene (a monster's passive too)" % id)
		for a in abilities:
			assert_false(a.ability_name.is_empty(), "%s: ability named" % id)
			assert_true(a.icon != null, "%s: %s has its icon" % [id, a.ability_name])
			assert_false(a.resource_path.is_empty(), "%s: %s is a .tres, not a copy" % [id, a.ability_name])
			assert_true(load(a.resource_path) == a, "%s: %s is the shared resource" % [id, a.ability_name])
	var hero_types: Array[int] = []
	for a in _roster().find(&"irelia").abilities():
		hero_types.append(a.ability_type)
	var menu_order: Array[int] = [AbilityBase.AbilityType.PASSIVE, AbilityBase.AbilityType.BASIC_ATTACK,
		AbilityBase.AbilityType.ACTIVE, AbilityBase.AbilityType.ULTIMATE]
	assert_eq(hero_types, menu_order, "menu order: passive, basic, active, ultimate")
	var monster_types: Array[int] = []
	for a in _roster().find(&"grount").abilities():
		monster_types.append(a.ability_type)
	assert_eq(monster_types[0], AbilityBase.AbilityType.PASSIVE, "a monster's passive comes first (Evolution)")


func test_monster_fields() -> void:
	var grount := _roster().resolve_monster(_roster().default_monster_id)
	assert_eq(grount.character_id(), &"grount")
	assert_eq(grount.stage_names.size(), 3, "one name per evolution stage")
	assert_eq(grount.stage_name(3), grount.stage_names[2])
	assert_eq(grount.stage_name(4), "", "no fourth stage")
	assert_false(grount.tip.is_empty(), "the heroes get a counterplay tip")
	assert_eq(grount.opponent_after_matches, 0, "the default monster is met from the first match")
	assert_true(grount.unlocked_by_default)
	assert_eq(grount.currency(), PersistedData.LEAVES)
	for d in _roster().heroes:
		assert_true(d.stage_names.is_empty(), "%s does not evolve" % d.character_id())
		assert_eq(d.currency(), PersistedData.STEEL)


func test_head_region_frames_the_head() -> void:
	for d in _roster().all():
		var id := d.character_id()
		var region := d.head_region
		assert_true(Rect2(Vector2.ZERO, CharacterDef.PORTRAIT_CANVAS).encloses(region), "%s: head inside the portrait" % id)
		assert_true(region.size.x > 0.0 and absf(region.size.x / region.size.y - 1.0) < 0.15, "%s: a square-ish head crop" % id)
		var img := Image.new()
		assert_eq(img.load_svg_from_string(FileAccess.get_file_as_string(HEAD_PART % id), 1.0), OK, "%s head part" % id)
		var head := Rect2(img.get_used_rect())
		var covered := head.intersection(region).get_area() / maxf(1.0, head.get_area())
		assert_true(covered >= MIN_HEAD_COVERAGE, "%s: the crop covers %d%% of the head" % [id, roundi(covered * 100.0)])
		var tex := d.head_texture()
		assert_true(tex.atlas == d.portrait, "%s: cropped from the portrait" % id)
		assert_true(Rect2(Vector2.ZERO, d.portrait.get_size()).encloses(tex.region), "%s: head region inside the texture" % id)


## A later stage's portrait (Grount's) has its own crop: square-ish, inside
## the canvas, framing the head and that stage's horns, which grow past the
## Stage I crop.
func test_stage_head_regions_frame_the_grown_head() -> void:
	for d in _roster().all():
		var id := d.character_id()
		assert_eq(d.stage_head_regions.size(), d.stage_portraits.size(), "%s: a crop per stage portrait" % id)
		for i in d.stage_portraits.size():
			var stage := i + 2
			var region := d.stage_head_regions[i]
			assert_true(d.stage_portraits[i] is DPITexture, "%s Stage %d portrait" % [id, stage])
			assert_true(Rect2(Vector2.ZERO, CharacterDef.PORTRAIT_CANVAS).encloses(region), "%s Stage %d: inside the portrait" % [id, stage])
			assert_true(absf(region.size.x / region.size.y - 1.0) < 0.15, "%s Stage %d: square-ish" % [id, stage])
			for part: String in ["head", "horns_s%d" % stage]:
				var path := "res://Assets/Characters/%s/src/parts/%s.svg" % [id, part]
				if not FileAccess.file_exists(path):
					continue
				var img := Image.new()
				assert_eq(img.load_svg_from_string(FileAccess.get_file_as_string(path), 1.0), OK, path)
				var box := Rect2(img.get_used_rect())
				var covered := box.intersection(region).get_area() / maxf(1.0, box.get_area())
				assert_true(covered >= 0.85, "%s Stage %d: the crop covers %d%% of the %s" % [id, stage, roundi(covered * 100.0), part])
			var tex := d.head_texture(stage)
			assert_true(tex.atlas == d.stage_portraits[i], "%s Stage %d: cropped from its portrait" % [id, stage])
		assert_true(d.head_texture(1).atlas == d.portrait, "%s Stage I: the portrait" % id)


func test_unknown_monster_falls_back_to_default() -> void:
	var roster := _roster()
	assert_eq(roster.resolve_monster(&"no_such_monster").character_id(), roster.default_monster_id)
	var before := GameManager.selected_monster_id
	GameManager.select_monster(&"no_such_monster", false)
	assert_eq(GameManager.selected_monster_id, roster.default_monster_id)
	assert_true(GameManager.selected_monster_def() == roster.resolve_monster(roster.default_monster_id))
	GameManager.select_monster(before, false)


func test_selection_persists_as_a_setting() -> void:
	if not require_isolated():
		return
	var before := GameManager.selected_monster_id
	GameManager.select_monster(&"no_such_monster")
	assert_eq(PersistedData.get_setting(GameManager.SETTING_SELECTED_MONSTER), String(_roster().default_monster_id),
		"an unknown id persists as the id actually picked")
	GameManager.select_monster(before)


func test_world_keeps_the_monster_at_grounts_old_index() -> void:
	# Determinism: the monster must enter the tree right after the heroes and
	# before Spawns._ready shuffles the camps, as the hard-wired Grount did.
	var state := (load(WORLD) as PackedScene).get_state()
	var top: Array[String] = []
	for n in state.get_node_count():
		var path := String(state.get_node_path(n))
		if path.count("/") == 1:
			top.append(path)
		assert_false(path.ends_with("/Grount"), "no hard-wired Grount left")
	assert_eq(top.back(), "./MonsterSlot", "the slot is World's last child")
	assert_eq(top[top.size() - 2], "./Heros", "right after the heroes")
	assert_true(top.find("./Spawns") < top.find("./MonsterSlot"))


func test_slot_spawns_the_selected_monster_during_the_enter_pass() -> void:
	var slot := MonsterSlot.new()
	slot.roster = _roster()
	slot.spawn_position = Vector2(5000, 0)
	var seen := {}
	slot.tree_entered.connect(func() -> void:
		seen["inside"] = slot.monster != null and slot.monster.is_inside_tree()
		seen["ready"] = slot.monster != null and slot.monster.is_node_ready()
		seen["registered"] = slot.monster != null and EntityRegistry.monsters.has(slot.monster))
	add_child(slot)
	assert_eq(seen.get("inside"), true, "the monster entered with the slot")
	assert_eq(seen.get("ready"), false, "before any _ready ran")
	assert_eq(seen.get("registered"), true, "registered during the enter pass")
	assert_true(slot.monster != null and slot.monster.get_parent() == slot)
	if slot.monster != null:
		assert_eq(slot.monster.monster_stats.monster_id, GameManager.selected_monster_id)
		assert_near(slot.monster.global_position.x, 5000.0)
	await wait_physics_frames(3)
	slot.queue_free()
	await wait_frames(1)
