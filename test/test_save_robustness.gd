extends TestCase

## A damaged, hand-edited or newer save.cfg never crashes the game or locks the
## player out (README "Save robustness"). Each case writes a save.cfg variant,
## loads it through PersistedData.load_data as a launch does, reads it the way
## the menus and the match do, opens the lobby and starts a match on it:
##   - missing sections and keys read as their defaults;
##   - a value of the wrong type reads as its default (repaired, not a crash);
##   - unknown character, tree or node ids are ignored and kept;
##   - ranks above a node's maximum count as the maximum;
##   - a save from a newer build is backed up (save.cfg.v<N>.bak) and played
##     on what this build knows;
##   - a truncated file that no longer parses is kept aside
##     (save.cfg.corrupt.bak) and a fresh save starts;
##   - an empty file is a fresh save.
## Writes the save: runs only in the isolated test user dir.

const SAVE := "user://save.cfg"
const MENU_ROOT := preload("res://Scenes/UI/Screens/MenuRoot.tscn")
const WORLD := "res://Scenes/World/World.tscn"
const BACKUPS: Array[String] = [".tmp", ".v0.bak", ".v1.bak", ".v2.bak", ".v99.bak", ".corrupt.bak"]

var _world_before: PackedScene = null
var _side_before: int = MatchRewards.Side.HEROES


func before_each() -> void:
	_side_before = GameManager.chosen_side
	_world_before = GameManager.world_scene
	_remove_files()


func after_each() -> void:
	GameManager.world_scene = _world_before
	_remove_files()
	if is_isolated():
		PersistedData.wipe_progress(false)
	GameManager.load_saved_choices()
	GameManager.choose_side(_side_before, false)
	GameManager.match_ended_flag = true
	TranslationServer.set_locale("en")


func _remove_files() -> void:
	if not is_isolated():
		return
	for f in [SAVE] + BACKUPS.map(func(b: String) -> String: return SAVE + b):
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))


func _write_text(text: String) -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(text)
	f.close()


## A launch on whatever save.cfg holds now: PersistedData's load and the
## saved choices GameManager reads at boot.
func _launch() -> void:
	PersistedData.load_data()
	GameManager.load_saved_choices()


## Everything the menus and the match read from the save, as they read it.
func _read_everything() -> void:
	for c in PersistedData.ALL_CURRENCIES:
		assert_true(PersistedData.get_currency(c) >= 0, "%s reads as a count" % c)
	assert_true(PersistedData.get_total_matches() >= 0, "the match count reads")
	for def in GameManager.ROSTER.heroes:
		assert_true(PersistedData.get_hero_xp(def.character_id()) >= 0)
	for def in GameManager.ROSTER.monsters:
		assert_true(PersistedData.get_monster_xp(def.character_id()) >= 0)
		CharacterProgress.is_unlocked(def)
	for tree_id: StringName in MetaSkillManager.trees:
		var t: MetaSkillTree = MetaSkillManager.get_tree_def(tree_id)
		var progress: Dictionary = MetaSkillManager.card_progress(tree_id)
		assert_true(int(progress["owned_ranks"]) >= 0, String(tree_id))
		for n in t.shown_nodes():
			MetaSkillManager.node_state(tree_id, n.id)
			assert_true(MetaSkillManager.get_rank(tree_id, n.id) >= 0)
		MetaSkillManager.equipped_capstone(tree_id)
		MetaSkillManager.points_spent(tree_id)
	for side in [MatchRewards.Side.HEROES, MatchRewards.Side.MONSTER]:
		var threat := MetaSkillManager.threat_for(side, GameManager.played_monster_id())
		assert_true(threat >= 0 and threat <= MetaSkillManager.MAX_THREAT, "the threat is in range")
	assert_true(GameManager.ROSTER.find(GameManager.played_monster_id()) != null, "the own monster is a roster monster")
	assert_true(GameManager.ROSTER.find(GameManager.next_quarry()) != null, "tonight's quarry is a roster monster")
	for id in CodexScreen.met_monsters():
		assert_true(GameManager.ROSTER.find(id) != null, "a Codex page is a roster monster: %s" % id)
	CodexScreen.unseen_monsters()
	MatchConfig.from_settings()
	for key in AudioSettings.VOLUME_KEYS:
		var v := AudioSettings.get_volume(key)
		assert_true(v >= 0.0 and v <= 1.0, "%s in 0..1" % key)
	assert_true(LocaleSettings.CHOICES.has(LocaleSettings.get_choice()), "the language choice is one of the list")
	TutorialOverlay.has_been_seen()
	TutorialOverlay.has_been_seen(TutorialOverlay.CHAPTER_HUD)
	AnalyticsSink.is_enabled()
	GameCamera.shake_setting_on()


## The lobby on this save: MenuRoot settles and its screens read the save.
func _open_lobby() -> void:
	# A stand-in: the match is loaded by _start_match, not in the background.
	if GameManager.world_scene == null:
		GameManager.world_scene = PackedScene.new()
	var root := MENU_ROOT.instantiate() as MenuRoot
	add_child(root)
	await wait_frames(5)
	assert_true(root.top() == root.lobby, "the lobby is up")
	root.queue_free()
	await wait_frames(2)


## A match on this save: the chosen side's hunt, World, the census and the
## monster's placement.
func _start_match() -> void:
	GameManager.begin_hunt()
	var world := (load(WORLD) as PackedScene).instantiate()
	add_child(world)
	for i in 120:
		if world.get("_monster_placed") and GameManager.heroes_alive > 0:
			break
		await wait_physics_frames(1)
	assert_true(GameManager.is_match_active(), "the match runs")
	assert_eq(GameManager.heroes_alive, 4, "four heroes in the census")
	assert_true(GameManager.monster_alive, "and the monster")
	assert_true(bool(world.get("_monster_placed")), "the monster was placed")
	GameManager.match_ended_flag = true
	world.queue_free()
	await wait_frames(3)
	AudioManager.stop_music()


func _play_on_it() -> void:
	_read_everything()
	await _open_lobby()
	await _start_match()


func test_missing_sections_read_as_defaults() -> void:
	if not require_isolated():
		return
	_write_text("[meta]\nsave_version=%d\n" % PersistedData.CURRENT_SAVE_VERSION)
	_launch()
	assert_eq(PersistedData.get_currency(PersistedData.GOLD), 0)
	assert_eq(PersistedData.get_total_matches(), 0)
	assert_eq(GameManager.chosen_side, MatchRewards.Side.HEROES)
	assert_eq(GameManager.played_monster_id(), GameManager.ROSTER.default_monster_id)
	assert_false(FileAccess.file_exists(SAVE + ".corrupt.bak"), "nothing to keep aside")
	await _play_on_it()


func test_wrong_value_types_read_as_defaults() -> void:
	if not require_isolated():
		return
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "save_version", PersistedData.CURRENT_SAVE_VERSION)
	cfg.set_value("meta", "total_matches", "many")
	cfg.set_value("currency", "steel", "lots")
	cfg.set_value("currency", "gold", [1, 2])
	cfg.set_value("currency", "leaves", -40)
	cfg.set_value("hero_xp", "vlad", {"a": 1})
	cfg.set_value("hero_xp", "ted", "250")
	cfg.set_value("monster_xp", "grount", Vector2(1, 2))
	cfg.set_value("skill_ranks", "hero_base", "t1_hp")
	cfg.set_value("skill_ranks", "hero_vlad", {"no": "x", "also": [1], 3: 2, "kept": 2.0})
	cfg.set_value("capstones", "monster_base", 5)
	cfg.set_value("monsters", "owned", "nyxa")
	cfg.set_value("monsters", "last_quarry", 7)
	cfg.set_value("monsters", "locked_quarry", ["nyxa"])
	cfg.set_value("codex", "monsters", 3)
	cfg.set_value("codex", "monsters_seen", "x")
	cfg.set_value("settings", "chosen_side", "monster")
	cfg.set_value("settings", "match_fast", "yes")
	cfg.set_value("settings", "selected_monster", 42)
	cfg.set_value("settings", "music_volume", "loud")
	cfg.set_value("settings", "sfx_volume", [0.5])
	cfg.set_value("settings", "locale", 5)
	cfg.set_value("settings", "tutorial_seen", "x")
	cfg.set_value("settings", "tutorial_hud_seen", [true])
	cfg.set_value("settings", "analytics_opt_out", "no")
	cfg.set_value("settings", "screen_shake", {"on": false})
	cfg.set_value("settings", "match_aggression", "high")
	cfg.set_value("settings", "match_formation", "spread")
	cfg.save(SAVE)
	_launch()
	assert_eq(PersistedData.get_total_matches(), 0, "a word for the match count reads as 0")
	assert_eq(PersistedData.get_currency(PersistedData.STEEL), 0, "a word for Steel reads as 0")
	assert_eq(PersistedData.get_currency(PersistedData.GOLD), 0, "a list for Gold reads as 0")
	assert_eq(PersistedData.get_currency(PersistedData.LEAVES), 0, "a negative count reads as 0")
	assert_eq(PersistedData.get_hero_xp(&"vlad"), 0)
	assert_eq(PersistedData.get_hero_xp(&"ted"), 250, "a number written as text still counts")
	assert_eq(PersistedData.get_monster_xp(&"grount"), 0)
	assert_eq(PersistedData.get_skill_ranks(&"hero_base"), {}, "a tree that is no table owns nothing")
	assert_eq(PersistedData.get_skill_ranks(&"hero_vlad"), {"kept": 2}, "only text ids with a number for a rank count")
	assert_eq(PersistedData.get_equipped_capstone(&"monster_base"), &"")
	assert_eq(PersistedData.get_owned_monsters(), [] as Array[StringName])
	assert_eq(PersistedData.get_last_quarry(), &"")
	assert_eq(PersistedData.get_locked_quarry(), &"")
	assert_eq(PersistedData.get_codex_entries(PersistedData.CODEX_MONSTERS), [] as Array[StringName])
	assert_eq(PersistedData.get_codex_seen(PersistedData.CODEX_MONSTERS), 0)
	assert_eq(GameManager.chosen_side, MatchRewards.Side.HEROES, "a word for the side reads as the Heroes")
	assert_false(GameManager.match_fast, "a word for the speed reads as normal")
	assert_eq(GameManager.played_monster_id(), GameManager.ROSTER.default_monster_id)
	assert_near(AudioSettings.get_volume(AudioSettings.KEY_MUSIC), AudioSettings.DEFAULT_VOLUME, 0.0001, "a word for a volume reads as the default")
	assert_near(AudioSettings.get_volume(AudioSettings.KEY_SFX), AudioSettings.DEFAULT_VOLUME, 0.0001)
	assert_eq(LocaleSettings.get_choice(), "", "a number for the language reads as System")
	assert_false(TutorialOverlay.has_been_seen(), "the tour plays again")
	assert_true(AnalyticsSink.is_enabled(), "a word for the opt-out reads as the default")
	assert_true(GameCamera.shake_setting_on(), "a table for the shake reads as the default")
	var config := MatchConfig.from_settings()
	assert_near(config.aggression, 0.5, 0.0001, "a word for a slider reads as its default")
	assert_eq(int(config.formation), int(MatchConfig.Formation.SPREAD))
	await _play_on_it()


func test_unknown_ids_are_ignored() -> void:
	if not require_isolated():
		return
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "save_version", PersistedData.CURRENT_SAVE_VERSION)
	cfg.set_value("meta", "total_matches", 7)
	cfg.set_value("hero_xp", "ghost", 900)
	cfg.set_value("monster_xp", "dragon", 900)
	cfg.set_value("skill_ranks", "hero_ghost", {"t1_hp": 2})
	cfg.set_value("skill_ranks", "hero_base", {"no_such_node": 2})
	cfg.set_value("capstones", "monster_base", "no_such_capstone")
	cfg.set_value("monsters", "owned", ["dragon"])
	cfg.set_value("monsters", "last_quarry", "dragon")
	cfg.set_value("monsters", "locked_quarry", "dragon")
	cfg.set_value("codex", "monsters", ["dragon", "grount"])
	cfg.set_value("settings", "chosen_side", 1)
	cfg.set_value("settings", "selected_monster", "dragon")
	cfg.set_value("settings", "locale", "xx")
	cfg.save(SAVE)
	_launch()
	assert_eq(GameManager.chosen_side, MatchRewards.Side.MONSTER, "the Monster side, as saved")
	assert_eq(GameManager.played_monster_id(), GameManager.ROSTER.default_monster_id, "an unknown own monster plays the default")
	assert_eq(MetaSkillManager.owned_ranks(&"hero_base"), 0, "an unknown node owns nothing in the tree")
	assert_eq(MetaSkillManager.equipped_capstone(&"monster_base"), &"")
	assert_eq(GameManager.locked_quarry(), &"", "an unknown locked quarry is random")
	assert_eq(CodexScreen.met_monsters(), [&"grount"] as Array[StringName], "only roster monsters get a page")
	assert_eq(LocaleSettings.get_choice(), "")
	assert_eq(PersistedData.get_skill_rank(&"hero_base", &"no_such_node"), 2, "the unknown purchase is kept, not wiped")
	await _play_on_it()


func test_ranks_above_the_maximum_count_as_the_maximum() -> void:
	if not require_isolated():
		return
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "save_version", PersistedData.CURRENT_SAVE_VERSION)
	var max_total: Dictionary = {}
	for tree_id: StringName in MetaSkillManager.trees:
		var t: MetaSkillTree = MetaSkillManager.get_tree_def(tree_id)
		var ranks: Dictionary = {}
		var total := 0
		for n in t.nodes:
			ranks[String(n.id)] = 99
			if not n.hidden:
				total += n.max_rank
		cfg.set_value("skill_ranks", String(tree_id), ranks)
		max_total[tree_id] = total
	cfg.set_value("settings", "chosen_side", 1)
	cfg.save(SAVE)
	_launch()
	for tree_id: StringName in MetaSkillManager.trees:
		var t: MetaSkillTree = MetaSkillManager.get_tree_def(tree_id)
		assert_eq(MetaSkillManager.owned_ranks(tree_id), int(max_total[tree_id]), "%s: every node at its maximum" % tree_id)
		var spent := 0
		for n in t.nodes:
			spent += n.max_rank
		assert_eq(MetaSkillManager.points_spent(tree_id), spent, "%s: 99 ranks spend only the maximum" % tree_id)
		for n in t.shown_nodes():
			assert_true(MetaSkillManager.applied_ranks(tree_id).get(n.id, n.max_rank) <= n.max_rank,
					"%s %s applies at most its maximum" % [tree_id, n.id])
	assert_eq(MetaSkillManager.threat_for(MatchRewards.Side.MONSTER, GameManager.played_monster_id()), MetaSkillManager.MAX_THREAT)
	await _play_on_it()


func test_a_save_from_a_newer_build_is_backed_up_and_played() -> void:
	if not require_isolated():
		return
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "save_version", 99)
	cfg.set_value("meta", "total_matches", 12)
	cfg.set_value("currency", "gold", 50)
	cfg.set_value("future", "pets", ["owl"])
	cfg.save(SAVE)
	_launch()
	assert_eq(PersistedData.get_currency(PersistedData.GOLD), 50, "what this build knows is played")
	assert_eq(PersistedData.get_total_matches(), 12)
	assert_true(FileAccess.file_exists(SAVE + ".v99.bak"), "the newer file is kept as it was")
	var bak := ConfigFile.new()
	assert_eq(bak.load(SAVE + ".v99.bak"), OK)
	assert_eq(int(bak.get_value("meta", "save_version", 0)), 99)
	PersistedData.add_currency(PersistedData.GOLD, 5)
	PersistedData.save_data()
	var on_disk := ConfigFile.new()
	on_disk.load(SAVE)
	assert_eq(on_disk.get_value("future", "pets", []), ["owl"], "a section this build does not know stays in the save")
	await _play_on_it()


## F5's leftover: the Codex's seen count moved from [settings]
## codex_seen_monsters to [codex] monsters_seen. A save that still has the old
## key drops it on load and is saved without it; the count is not carried
## over (one that outlived a Reset Progress would hide new pages).
func test_a_retired_key_is_dropped_on_load() -> void:
	if not require_isolated():
		return
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "save_version", PersistedData.CURRENT_SAVE_VERSION)
	cfg.set_value("currency", "gold", 70)
	cfg.set_value("settings", "codex_seen_monsters", 3)
	cfg.set_value("settings", "music_volume", 0.4)
	cfg.save(SAVE)
	_launch()
	assert_eq(PersistedData.get_currency(PersistedData.GOLD), 70, "the rest is read as it was")
	assert_eq(PersistedData.get_codex_seen(PersistedData.CODEX_MONSTERS), 0, "the old count is not read")
	var on_disk := ConfigFile.new()
	assert_eq(on_disk.load(SAVE), OK)
	assert_false(on_disk.has_section_key("settings", "codex_seen_monsters"), "the file no longer has the old key")
	assert_near(float(on_disk.get_value("settings", "music_volume", 0.0)), 0.4, 0.0001, "the other settings stay")
	assert_false(FileAccess.file_exists(SAVE + ".v%d.bak" % PersistedData.CURRENT_SAVE_VERSION), "no migration backup for it")


func test_a_truncated_save_is_kept_aside_and_a_fresh_one_starts() -> void:
	if not require_isolated():
		return
	PersistedData.wipe_progress(false)
	PersistedData.add_currency(PersistedData.GOLD, 300)
	PersistedData.set_skill_rank(&"hero_base", &"t1_hp", 1)
	PersistedData.save_data()
	var text := FileAccess.get_file_as_string(SAVE)
	var cut := text.find("{")
	assert_true(cut > 0, "the save has a table to cut through")
	_write_text(text.substr(0, cut + 3))
	_launch()
	assert_true(FileAccess.file_exists(SAVE + ".corrupt.bak"), "the damaged file is kept aside")
	assert_eq(FileAccess.get_file_as_string(SAVE + ".corrupt.bak"), text.substr(0, cut + 3), "as it was")
	assert_eq(PersistedData.get_currency(PersistedData.GOLD), 0, "a fresh save")
	assert_eq(PersistedData.get_save_version(), PersistedData.CURRENT_SAVE_VERSION)
	await _play_on_it()


func test_an_empty_save_is_a_fresh_save() -> void:
	if not require_isolated():
		return
	_write_text("")
	_launch()
	assert_eq(PersistedData.get_save_version(), PersistedData.CURRENT_SAVE_VERSION)
	assert_eq(PersistedData.get_currency(PersistedData.STEEL), 0)
	assert_eq(PersistedData.get_total_matches(), 0)
	var on_disk := ConfigFile.new()
	assert_eq(on_disk.load(SAVE), OK, "a readable save is written back")
	await _play_on_it()
