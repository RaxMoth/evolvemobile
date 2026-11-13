extends TestCase

## Save-file versioning: older files are backed up, walked up the migration
## ladder and normalized. Only runs against the isolated test user:// dir.

const SAVE := "user://save.cfg"


func before_each() -> void:
	if is_isolated():
		for f in [SAVE, SAVE + ".tmp", SAVE + ".v0.bak", SAVE + ".v1.bak", SAVE + ".v2.bak", SAVE + ".corrupt.bak"]:
			if FileAccess.file_exists(f):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(f))


func _write_v1(values: Dictionary, with_version: bool = true) -> void:
	var cfg := ConfigFile.new()
	if with_version:
		cfg.set_value("meta", "save_version", 1)
	for section in values:
		for key in values[section]:
			cfg.set_value(section, key, values[section][key])
	cfg.save(SAVE)


func test_v1_save_is_backed_up_and_normalized() -> void:
	if not require_isolated():
		return
	_write_v1({
		"currency": {"steel": 12.6, "gold": -5, "leaves": "40"},
		"hero_xp": {"vlad": 250.0},
		"skills": {"hero_base": ["t1_hp", 7, "t1_hp", &"t2_dmg"]},
		"settings": {"music_volume": 1.7, "sfx_volume": "loud"},
		"meta": {"total_matches": 3, "last_saved_unix": 1700000000},
	})
	PersistedData.load_data()
	assert_eq(PersistedData.get_save_version(), PersistedData.CURRENT_SAVE_VERSION, "v1 walks the whole ladder")
	assert_eq(PersistedData.get_currency(PersistedData.STEEL), 13, "float rounded to int")
	assert_eq(PersistedData.get_currency(PersistedData.GOLD), 0, "negative clamped")
	assert_eq(PersistedData.get_currency(PersistedData.LEAVES), 40, "numeric string parsed")
	assert_eq(PersistedData.get_hero_xp(&"vlad"), 250)
	assert_eq(PersistedData.get_unlocked_skills(&"hero_base"), ["t1_hp", "t2_dmg"], "strings only, de-duplicated")
	assert_eq(PersistedData.get_skill_ranks(&"hero_base"), {"t1_hp": 1, "t2_dmg": 1}, "v1 -> v3: owned ids at rank 1")
	assert_near(float(PersistedData.get_setting(&"music_volume")), 1.0, 0.0001, "volume clamped")
	assert_near(float(PersistedData.get_setting(&"sfx_volume")), AudioSettings.DEFAULT_VOLUME, 0.0001, "garbage volume reset")
	assert_eq(PersistedData.get_total_matches(), 3)
	assert_eq(int(PersistedData.get_setting(&"__none", 0)), 0)
	assert_true(FileAccess.file_exists(SAVE + ".v1.bak"), "backup written before migrating")
	var bak := ConfigFile.new()
	bak.load(SAVE + ".v1.bak")
	assert_eq(int(bak.get_value("meta", "save_version", 0)), 1, "backup is the untouched v1 file")
	assert_eq(bak.get_value("currency", "gold", null), -5)
	var on_disk := ConfigFile.new()
	on_disk.load(SAVE)
	assert_eq(int(on_disk.get_value("meta", "save_version", 0)), PersistedData.CURRENT_SAVE_VERSION, "migrated file re-saved")
	assert_false(on_disk.has_section("skills"), "the v2 skill lists are gone")
	assert_true(int(on_disk.get_value("meta", "created_unix", 0)) == 1700000000, "created_unix seeded from last save")


func test_unversioned_save_counts_as_v1() -> void:
	if not require_isolated():
		return
	_write_v1({"currency": {"steel": 5}}, false)
	PersistedData.load_data()
	assert_eq(PersistedData.get_save_version(), PersistedData.CURRENT_SAVE_VERSION)
	assert_eq(PersistedData.get_currency(PersistedData.STEEL), 5)
	assert_true(FileAccess.file_exists(SAVE + ".v1.bak"))


func test_current_save_is_not_backed_up_or_rewritten() -> void:
	if not require_isolated():
		return
	# A hand-written current-version file with a sentinel timestamp.
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "save_version", PersistedData.CURRENT_SAVE_VERSION)
	cfg.set_value("meta", "last_saved_unix", 1)
	cfg.set_value("currency", "gold", 77)
	cfg.save(SAVE)
	PersistedData.add_currency(PersistedData.GOLD, 5)  # dirty memory so a no-op load would show
	var saves := [0]
	var cb := func() -> void: saves[0] += 1
	PersistedData.data_saved.connect(cb)
	PersistedData.load_data()
	PersistedData.data_saved.disconnect(cb)
	assert_eq(PersistedData.get_currency(PersistedData.GOLD), 77, "memory replaced from disk")
	assert_eq(saves[0], 0, "a current save is not re-saved on load")
	var on_disk := ConfigFile.new()
	on_disk.load(SAVE)
	assert_eq(int(on_disk.get_value("meta", "last_saved_unix", 0)), 1, "file untouched")
	for f in DirAccess.get_files_at("user://"):
		assert_false(f.begins_with("save.cfg.") and f.ends_with(".bak"), "no backup of any version: " + f)


func test_reset_progress_keeps_preferences() -> void:
	if not require_isolated():
		return
	PersistedData.wipe_progress(false)
	PersistedData.add_currency(PersistedData.GOLD, 300)
	PersistedData.set_setting(&"analytics_opt_out", true)
	PersistedData.set_setting(&"locale", "de")
	PersistedData.set_setting(&"music_volume", 0.3)
	PersistedData.wipe_progress()  # the in-game Reset Progress
	PersistedData.load_data()
	assert_eq(PersistedData.get_currency(PersistedData.GOLD), 0, "progress gone")
	assert_true(bool(PersistedData.get_setting(&"analytics_opt_out", false)), "opt-out kept")
	assert_eq(String(PersistedData.get_setting(&"locale", "")), "de", "language kept")
	assert_near(float(PersistedData.get_setting(&"music_volume", 1.0)), 0.3, 0.0001, "volume kept")
	TranslationServer.set_locale("en")


func test_corrupt_save_is_kept_aside_and_defaults_seeded() -> void:
	if not require_isolated():
		return
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string("this is = not [ a config\n[[[")
	f.close()
	expect_error("ConfigFile parse error")
	PersistedData.load_data()
	assert_eq(PersistedData.get_save_version(), PersistedData.CURRENT_SAVE_VERSION)
	assert_eq(PersistedData.get_currency(PersistedData.STEEL), 0)
	assert_true(FileAccess.file_exists(SAVE + ".corrupt.bak"), "unreadable file preserved")


func test_save_replaces_the_file_atomically() -> void:
	if not require_isolated():
		return
	PersistedData.wipe_progress(false)
	PersistedData.add_currency(PersistedData.GOLD, 42)
	PersistedData.add_hero_xp(&"vlad", 120)
	PersistedData.set_setting(&"music_volume", 0.4)
	var saves := [0]
	var cb := func() -> void: saves[0] += 1
	PersistedData.data_saved.connect(cb)
	PersistedData.save_data()
	PersistedData.data_saved.disconnect(cb)
	assert_eq(saves[0], 1, "data_saved once per save")
	assert_false(FileAccess.file_exists(SAVE + ".tmp"), "tmp file renamed over the save")
	PersistedData.load_data()
	assert_eq(PersistedData.get_currency(PersistedData.GOLD), 42)
	assert_eq(PersistedData.get_hero_xp(&"vlad"), 120)
	assert_near(float(PersistedData.get_setting(&"music_volume", 1.0)), 0.4, 0.0001)


func test_unreadable_save_recovers_the_tmp_file() -> void:
	if not require_isolated():
		return
	# A finished tmp write whose rename never happened, next to an unreadable save.
	var tmp := ConfigFile.new()
	tmp.set_value("meta", "save_version", PersistedData.CURRENT_SAVE_VERSION)
	tmp.set_value("currency", "gold", 55)
	tmp.set_value("hero_xp", "vlad", 300)
	tmp.save(SAVE + ".tmp")
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string("this is = not [ a config\n[[[")
	f.close()
	expect_error("ConfigFile parse error")
	PersistedData.load_data()
	assert_eq(PersistedData.get_currency(PersistedData.GOLD), 55, "tmp data recovered")
	assert_eq(PersistedData.get_hero_xp(&"vlad"), 300)
	assert_false(FileAccess.file_exists(SAVE + ".tmp"), "tmp moved into place")
	assert_true(FileAccess.file_exists(SAVE + ".corrupt.bak"), "unreadable file preserved")
	var on_disk := ConfigFile.new()
	assert_eq(on_disk.load(SAVE), OK)
	assert_eq(int(on_disk.get_value("currency", "gold", 0)), 55)


func test_missing_save_recovers_the_tmp_file() -> void:
	if not require_isolated():
		return
	var tmp := ConfigFile.new()
	tmp.set_value("meta", "save_version", PersistedData.CURRENT_SAVE_VERSION)
	tmp.set_value("currency", "steel", 9)
	tmp.save(SAVE + ".tmp")
	PersistedData.load_data()
	assert_eq(PersistedData.get_currency(PersistedData.STEEL), 9)
	assert_true(FileAccess.file_exists(SAVE))
	assert_false(FileAccess.file_exists(SAVE + ".tmp"))


func test_pause_saves_only_unsaved_changes() -> void:
	if not require_isolated():
		return
	PersistedData.wipe_progress(false)
	var saves := [0]
	var cb := func() -> void: saves[0] += 1
	PersistedData.data_saved.connect(cb)
	PersistedData.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(saves[0], 0, "nothing unsaved, no write")
	PersistedData.set_setting(&"sfx_volume", 0.25)  # what the volume sliders do
	PersistedData.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(saves[0], 1, "backgrounding flushes the change")
	PersistedData.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(saves[0], 1, "flushed once")
	PersistedData.data_saved.disconnect(cb)
	var on_disk := ConfigFile.new()
	on_disk.load(SAVE)
	assert_near(float(on_disk.get_value("settings", "sfx_volume", 1.0)), 0.25, 0.0001)


func test_reset_progress_signals_xp_back_to_zero() -> void:
	if not require_isolated():
		return
	PersistedData.wipe_progress(false)
	PersistedData.add_hero_xp(&"vlad", 500)
	PersistedData.add_monster_xp(&"grount", 300)
	var heroes: Array = []
	var monsters: Array = []
	var on_hero := func(id: StringName, xp: int) -> void: heroes.append([id, xp])
	var on_monster := func(id: StringName, xp: int) -> void: monsters.append([id, xp])
	PersistedData.hero_xp_changed.connect(on_hero)
	PersistedData.monster_xp_changed.connect(on_monster)
	PersistedData.wipe_progress()
	PersistedData.hero_xp_changed.disconnect(on_hero)
	PersistedData.monster_xp_changed.disconnect(on_monster)
	assert_eq(heroes, [[&"vlad", 0]], "menu level row refreshed")
	assert_eq(monsters, [[&"grount", 0]], "monster bar refreshed")


func _write_v2(skills: Dictionary, extra: Dictionary = {}) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "save_version", 2)
	cfg.set_value("currency", "gold", 40)
	cfg.set_value("currency", "leaves", 7)
	for tree_id: String in skills:
		cfg.set_value("skills", tree_id, skills[tree_id])
	for section: String in extra:
		for key: String in extra[section]:
			cfg.set_value(section, key, extra[section][key])
	cfg.save(SAVE)


## v2 -> v3 (ranked nodes): every owned id is rank 1, ids no tree defines are
## kept, nothing is charged or refunded, the v2 file is backed up and the old
## [skills] section is gone from the file.
func test_v2_skill_lists_become_rank_one() -> void:
	if not require_isolated():
		return
	_write_v2({"hero_base": ["t1_hp", "t2_dmg"], "monster_grount": ["g1_dmg", "g9_retired_node"],
		"hero_vlad": ["v1_dmg", "v2_bombaoe"]})
	PersistedData.load_data()
	assert_eq(PersistedData.get_save_version(), 3)
	assert_eq(PersistedData.get_skill_ranks(&"hero_base"), {"t1_hp": 1, "t2_dmg": 1})
	assert_eq(PersistedData.get_skill_ranks(&"hero_vlad"), {"v1_dmg": 1, "v2_bombaoe": 1})
	assert_eq(PersistedData.get_skill_rank(&"monster_grount", &"g9_retired_node"), 1, "unknown ids are kept, not dropped")
	assert_true(MetaSkillManager.is_unlocked(&"hero_base", &"t2_dmg"), "old unlocks stay valid")
	assert_eq(MetaSkillManager.get_rank(&"hero_base", &"t1_hp"), 1)
	assert_eq(MetaSkillManager.node_state(&"hero_base", &"t1_hp"), MetaSkillManager.NodeState.UNAFFORDABLE,
		"owned at rank 1 of 3: rank 2 is for sale (70 Gold, 40 owned)")
	assert_eq(MetaSkillManager.node_state(&"monster_grount", &"g9_retired_node"), MetaSkillManager.NodeState.UNLOCKED,
		"an owned id the tree does not have stays owned")
	assert_eq(PersistedData.get_unlocked_skills(&"monster_grount"), ["g1_dmg", "g9_retired_node"], "the old list, as a view")
	assert_eq(PersistedData.get_currency(PersistedData.GOLD), 40, "no refund, no charge")
	assert_eq(PersistedData.get_currency(PersistedData.LEAVES), 7)
	assert_true(FileAccess.file_exists(SAVE + ".v2.bak"), "v2 file backed up")
	var bak := ConfigFile.new()
	bak.load(SAVE + ".v2.bak")
	assert_eq(bak.get_value("skills", "hero_base", []), ["t1_hp", "t2_dmg"], "the backup is the untouched v2 file")
	var on_disk := ConfigFile.new()
	on_disk.load(SAVE)
	assert_eq(int(on_disk.get_value("meta", "save_version", 0)), 3, "migrated file re-saved")
	assert_false(on_disk.has_section("skills"), "old layout removed")
	assert_eq(on_disk.get_value("skill_ranks", "hero_base", {}), {"t1_hp": 1, "t2_dmg": 1})


## The migration may run twice (a v2 stamp over ranks that are already there):
## it changes nothing, and a rank already owned is never reset to 1.
func test_double_migration_is_a_no_op() -> void:
	if not require_isolated():
		return
	_write_v2({"hero_base": ["t1_hp", "t2_dmg"]})
	PersistedData.load_data()
	var first := PersistedData.get_skill_ranks(&"hero_base")
	PersistedData.load_data()
	assert_eq(PersistedData.get_skill_ranks(&"hero_base"), first, "loading the migrated file again changes nothing")
	# Same ids again under an old stamp, next to ranks bought since (t1_hp at 3).
	var on_disk := ConfigFile.new()
	on_disk.load(SAVE)
	on_disk.set_value("meta", "save_version", 2)
	on_disk.set_value("skills", "hero_base", ["t1_hp", "t2_dmg", "t3_hp"])
	on_disk.set_value("skill_ranks", "hero_base", {"t1_hp": 3, "t2_dmg": 1})
	on_disk.save(SAVE)
	PersistedData.load_data()
	assert_eq(PersistedData.get_save_version(), 3)
	assert_eq(PersistedData.get_skill_ranks(&"hero_base"), {"t1_hp": 3, "t2_dmg": 1, "t3_hp": 1},
		"existing ranks win, only the missing id is added at rank 1")


## A v2 save can own one capstone, Titan Form. With no choice saved it is the
## equipped capstone after the migration and keeps applying.
func test_v2_titan_form_owner_keeps_it_equipped() -> void:
	if not require_isolated():
		return
	play_side(MatchRewards.Side.MONSTER)  # the played side applies the save's trees
	_write_v2({"monster_grount": ["g1_dmg", "g2_hp", "g3_enrage", "g4_titan"]}, {"monster_xp": {"grount": 900}})
	PersistedData.load_data()
	var tree := MetaSkillManager.monster_tree_id(&"grount")
	assert_eq(PersistedData.get_equipped_capstone(tree), &"", "no choice saved")
	assert_eq(MetaSkillManager.equipped_capstone(tree), &"g4_titan", "the first owned capstone is equipped")
	var mods: Dictionary = MetaSkillManager.collect_monster_modifiers(&"grount")
	assert_near(float(mods.get("monster_titan_form", 0.0)), 1.0, 0.0001, "Titan Form still applies")
	assert_near(float(mods.get("monster_damage_mult", 0.0)), 1.10, 0.0001, "rank 1 of Heavy Horns is the old +10%")
	assert_eq(PersistedData.get_monster_xp(&"grount"), 900, "XP untouched")
