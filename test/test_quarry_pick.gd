extends TestCase

## Opponent choice and monster unlocks (Phase 6.7):
##   - Heroes side: the quarry pool (matches played >= the def's
##     opponent_after_matches: Grount 0, Nyxa 3, Gorrak 6, whatever the Monster
##     side owns), the random pick (never the last quarry twice in a row while
##     the pool has two or more), drawn with GameManager's PRIVATE
##     RandomNumberGenerator so the global RNG (gameplay) is untouched, kept
##     until a hunt starts; the Change picker's lock; begin_hunt() recording the
##     last quarry and the first sighting's Codex entry (the NEW QUARRY flag);
##     the PreRoundScreen's quarry card (NEW QUARRY banner, the AI build's
##     card), its Change sheet (pool cards, "Appears after N hunts"
##     silhouettes, the lock, Random) and the quarry it hands on.
##   - Monster side: the owned set ([monsters] owned, Grount by default), the
##     Lv 3 gate on ANY owned monster, the Leaves prices, the purchase, and the
##     player's own monster for the Monster-side hunt.
## Tests that write the save run only in the isolated test user dir.

const PRE_ROUND := preload("res://Scenes/UI/Screens/PreRoundScreen.tscn")

var _side_before: int = MatchRewards.Side.HEROES
var _monster_before: StringName = &""


func before_each() -> void:
	_side_before = GameManager.chosen_side
	_monster_before = GameManager.selected_monster_id
	if is_isolated():
		PersistedData.wipe_progress(false)


func after_each() -> void:
	GameManager.choose_side(_side_before, false)
	GameManager.select_monster(_monster_before, false)
	if is_isolated():
		PersistedData.wipe_progress(false)


func _def(id: StringName) -> CharacterDef:
	return GameManager.ROSTER.find(id)


func _play_matches(n: int) -> void:
	for i in n:
		PersistedData.record_match_played()


func _ids(list: Array[StringName]) -> String:
	return ", ".join(list)


## A value as the save FILE has it (what the next launch reads).
func _saved(section: String, key: String) -> Variant:
	var file := ConfigFile.new()
	if file.load(PersistedData.SAVE_PATH) != OK:
		return null
	return file.get_value(section, key, null)


# ------------------------------------------------------------ the pool ----

func test_defs_carry_the_rules() -> void:
	assert_eq(_def(&"grount").opponent_after_matches, 0, "Grount from the first hunt")
	assert_eq(_def(&"nyxa").opponent_after_matches, 3)
	assert_eq(_def(&"gorrak").opponent_after_matches, 6)
	assert_true(_def(&"grount").unlocked_by_default, "Grount is owned by default")
	for id: StringName in [&"nyxa", &"gorrak"]:
		assert_false(_def(id).unlocked_by_default, "%s is bought" % id)
		assert_eq(_def(id).unlock_requires_level, 3, "%s: any owned monster at Lv 3" % id)
		assert_eq(_def(id).currency(), PersistedData.LEAVES)
	assert_eq(_def(&"nyxa").unlock_cost, 2500)
	assert_eq(_def(&"gorrak").unlock_cost, 3000)


func test_pool_grows_with_matches_played() -> void:
	if not require_isolated():
		return
	assert_eq(_ids(GameManager.quarry_pool()), "grount", "a fresh save meets Grount only")
	assert_eq(GameManager.hunts_until_quarry(_def(&"nyxa")), 3)
	_play_matches(2)
	assert_eq(_ids(GameManager.quarry_pool()), "grount")
	_play_matches(1)
	assert_eq(_ids(GameManager.quarry_pool()), "grount, nyxa", "Nyxa after 3 matches, not owned")
	assert_eq(GameManager.hunts_until_quarry(_def(&"nyxa")), 0)
	assert_eq(GameManager.hunts_until_quarry(_def(&"gorrak")), 3, "Gorrak's silhouette: 3 more hunts")
	_play_matches(3)
	assert_eq(_ids(GameManager.quarry_pool()), "grount, nyxa, gorrak")
	assert_eq(GameManager.hunts_until_quarry(_def(&"gorrak")), 0)
	assert_eq(GameManager.hunts_until_quarry(null), 0)


# ------------------------------------------------------------ the pick ----

func test_roll_never_repeats_the_last_quarry() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var pool: Array[StringName] = [&"grount", &"nyxa", &"gorrak"]
	var last: StringName = &"grount"
	var seen := {}
	for i in 300:
		var pick := GameManager.roll_quarry(pool, last, rng)
		assert_true(pool.has(pick), "%s is in the pool" % pick)
		assert_true(pick != last, "draw %d repeats %s" % [i, last])
		seen[pick] = true
		last = pick
	assert_eq(seen.size(), 3, "every pool monster comes up")
	var two: Array[StringName] = [&"grount", &"nyxa"]
	for i in 20:
		assert_eq(GameManager.roll_quarry(two, &"nyxa", rng), &"grount", "two in the pool: the other one")
	var one: Array[StringName] = [&"grount"]
	assert_eq(GameManager.roll_quarry(one, &"grount", rng), &"grount", "one in the pool: it, again")
	var none: Array[StringName] = []
	assert_eq(GameManager.roll_quarry(none, &"", rng), GameManager.ROSTER.default_monster_id, "empty: the default")
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 99
	b.seed = 99
	for i in 10:
		assert_eq(GameManager.roll_quarry(pool, &"", a), GameManager.roll_quarry(pool, &"", b), "the rng alone decides")


## The menus pick with GameManager's own generator: the global RNG, which
## drives gameplay and the determinism trace, reads the same afterwards.
func test_picking_leaves_the_global_rng_alone() -> void:
	if not require_isolated():
		return
	_play_matches(6)
	GameManager.choose_side(MatchRewards.Side.HEROES, false)
	seed(4242)
	var expected := [randi(), randf()]
	seed(4242)
	for i in 25:
		GameManager.next_quarry()
		GameManager.begin_hunt()
		GameManager.roll_quarry(GameManager.quarry_pool(), PersistedData.get_last_quarry(), RandomNumberGenerator.new())
	assert_eq([randi(), randf()], expected, "25 picks and hunts drew nothing from the global RNG")


## The pick stays put until a hunt starts; the hunt records it (last quarry,
## Codex entry: the NEW flag goes) and the next pick is another monster.
func test_hunts_never_meet_the_same_quarry_twice_in_a_row() -> void:
	if not require_isolated():
		return
	_play_matches(6)
	GameManager.choose_side(MatchRewards.Side.HEROES, false)
	var first := GameManager.next_quarry()
	assert_true(GameManager.quarry_pool().has(first))
	for i in 5:
		assert_eq(GameManager.next_quarry(), first, "kept while the pre-round reopens")
	assert_true(GameManager.is_new_quarry(first), "never met: NEW QUARRY")
	GameManager.begin_hunt()
	assert_eq(GameManager.selected_monster_id, first, "the hunt spawns the pick")
	assert_eq(PersistedData.get_last_quarry(), first)
	assert_false(GameManager.is_new_quarry(first), "met once: no flag")
	assert_true(PersistedData.has_codex_entry(PersistedData.CODEX_MONSTERS, first), "and a Codex entry")
	var last := first
	var met := {first: true}
	for i in 40:
		var next := GameManager.next_quarry()
		assert_true(next != last, "hunt %d: %s twice in a row" % [i, next])
		GameManager.begin_hunt()
		assert_eq(GameManager.selected_monster_id, next)
		met[next] = true
		last = next
	assert_eq(met.size(), 3, "Grount, Nyxa and Gorrak all hunted")
	assert_eq(PersistedData.get_codex_entries(PersistedData.CODEX_MONSTERS).size(), 3, "one Codex entry each")
	assert_eq(_saved(PersistedData.SECTION_MONSTERS, "last_quarry"), String(last), "saved")


## Only Grount in the pool: he is hunted every time (no repeat rule with one).
func test_a_fresh_save_hunts_grount() -> void:
	if not require_isolated():
		return
	GameManager.choose_side(MatchRewards.Side.HEROES, false)
	for i in 3:
		assert_eq(GameManager.next_quarry(), &"grount")
		GameManager.begin_hunt()
		assert_eq(GameManager.selected_monster_id, &"grount")


func test_the_change_picker_locks_a_quarry() -> void:
	if not require_isolated():
		return
	_play_matches(3)
	GameManager.choose_side(MatchRewards.Side.HEROES, false)
	GameManager.lock_quarry(&"gorrak")
	assert_eq(GameManager.locked_quarry(), &"", "Gorrak is not in the pool yet: no lock")
	GameManager.lock_quarry(&"nyxa")
	assert_eq(GameManager.locked_quarry(), &"nyxa")
	for i in 3:
		assert_eq(GameManager.next_quarry(), &"nyxa", "locked: every hunt, repeats allowed")
		GameManager.begin_hunt()
		assert_eq(GameManager.selected_monster_id, &"nyxa")
	assert_eq(_saved(PersistedData.SECTION_MONSTERS, "locked_quarry"), "nyxa", "the lock is saved")
	GameManager.lock_quarry(&"")
	assert_eq(GameManager.locked_quarry(), &"", "Random again")
	assert_eq(GameManager.next_quarry(), &"grount", "two in the pool, Nyxa was last")
	GameManager.begin_hunt(&"nyxa")
	assert_eq(GameManager.selected_monster_id, &"nyxa", "an explicit quarry from the pool")
	GameManager.begin_hunt(&"gorrak")
	assert_eq(GameManager.selected_monster_id, &"grount", "one outside the pool falls back to the pick")
	PersistedData.wipe_progress(false)
	assert_eq(GameManager.locked_quarry(), &"", "Reset Progress clears the lock")
	assert_eq(PersistedData.get_last_quarry(), &"")
	assert_eq(PersistedData.get_codex_entries(PersistedData.CODEX_MONSTERS).size(), 0)


func _pre_round() -> PreRoundScreen:
	var screen := PRE_ROUND.instantiate() as PreRoundScreen
	add_child(screen)
	screen.open(MatchRewards.Side.HEROES)
	return screen


## The pre-round shows tonight's quarry (NEW on a first sighting) as the AI
## opponent it will be, and hands it on in the MatchConfig.
func test_pre_round_shows_the_quarry() -> void:
	if not require_isolated():
		return
	_play_matches(3)
	GameManager.lock_quarry(&"nyxa")
	var screen := _pre_round()
	assert_eq(screen.quarry, _def(&"nyxa"))
	assert_eq((screen.get_node("%QuarryName") as Label).text, "Nyxa")
	assert_eq((screen.get_node("%QuarryTagline") as Label).text, _def(&"nyxa").tagline)
	assert_true((screen.get_node("%NewBanner") as Control).visible, "NEW QUARRY on a first sighting")
	var card := screen.get_node("%QuarryCard") as CharacterCard
	assert_eq(card.character, _def(&"nyxa"))
	assert_true(card.unlocked, "shown although the Monster side does not own her")
	assert_eq(card.level, 1, "threat 0: Lv.1")
	assert_eq(card.xp_into, 0, "no AI ranks at threat 0")
	assert_eq(card.xp_needed, MetaSkillManager.ai_build_size(&"monster_nyxa", MetaSkillManager.MAX_THREAT),
			"out of the threat-4 build")
	var moves := 0
	for frame: Control in screen.get_node("%QuarryMoves").get_children():
		if frame.visible:
			moves += 1
	assert_eq(moves, 3, "her three moves")
	assert_eq(screen.collect_config().quarry_id, &"nyxa", "the config carries it")
	GameManager.choose_side(MatchRewards.Side.HEROES, false)
	GameManager.begin_hunt()
	screen.open(MatchRewards.Side.HEROES)
	assert_false((screen.get_node("%NewBanner") as Control).visible, "met: no banner")
	screen.queue_free()
	assert_eq(MatchConfig.new().quarry_id, &"", "a new config leaves the pick to GameManager")


## CHANGE: the pool's monsters to pick (the lock), the rest as silhouettes with
## the hunts still to play, and Random.
func test_pre_round_change_sheet() -> void:
	if not require_isolated():
		return
	_play_matches(3)
	var screen := _pre_round()
	(screen.get_node("%Change") as BaseButton).pressed.emit()
	assert_true(screen.is_sheet_open())
	var cards := screen.sheet_cards()
	assert_eq(cards.size(), GameManager.ROSTER.monsters.size(), "every roster monster")
	var by_id: Dictionary[StringName, CharacterCard] = {}
	for c in cards:
		by_id[c.character.character_id()] = c
	assert_true(by_id[&"grount"].unlocked and by_id[&"nyxa"].unlocked, "the pool's monsters")
	var gorrak := by_id[&"gorrak"]
	assert_false(gorrak.unlocked, "Gorrak is not in the pool after 3 hunts")
	assert_eq(gorrak.locked_note, "Appears after 3 hunts")
	assert_true((gorrak.get_node("%Rule") as Label).visible)
	assert_eq((gorrak.get_node("%Rule") as Label).text, "Appears after 3 hunts", "instead of the unlock rule")
	assert_false((gorrak.get_node("%Price") as Control).visible, "and no price")
	assert_true(by_id[screen.quarry.character_id()].selected, "tonight's quarry is marked")
	assert_true((screen.get_node("%Random") as BaseButton).disabled, "already random")
	gorrak.pressed.emit()
	assert_true(screen.is_sheet_open(), "a silhouette picks nothing")
	assert_eq(GameManager.locked_quarry(), &"")
	var other: StringName = &"grount" if screen.quarry.character_id() == &"nyxa" else &"nyxa"
	by_id[other].pressed.emit()
	assert_eq(GameManager.locked_quarry(), other, "a pick locks it")
	assert_eq(screen.quarry.character_id(), other, "and shows it")
	assert_eq(screen.collect_config().quarry_id, other)
	assert_false(screen.is_sheet_open(), "the sheet closes")
	screen.open_sheet()
	assert_false((screen.get_node("%Random") as BaseButton).disabled)
	assert_eq((screen.get_node("%LockState") as Label).text, "%s every hunt, until you pick Random." % _def(other).get_display_name())
	(screen.get_node("%Random") as BaseButton).pressed.emit()
	assert_eq(GameManager.locked_quarry(), &"", "Random unlocks")
	assert_eq(screen.quarry.character_id(), GameManager.next_quarry(), "back to the random pick")
	screen.open_sheet()
	var back := InputEventAction.new()
	back.action = &"ui_cancel"
	back.pressed = true
	get_viewport().push_input(back)
	assert_false(screen.is_sheet_open(), "ui_cancel closes the sheet first")
	screen.queue_free()


# --------------------------------------------------------- the unlocks ----

func test_unlock_needs_the_level_then_the_leaves() -> void:
	if not require_isolated():
		return
	var nyxa := _def(&"nyxa")
	var owned_events: Array[StringName] = []
	var on_owned := func(id: StringName) -> void: owned_events.append(id)
	PersistedData.monster_owned.connect(on_owned)
	assert_eq(CharacterProgress.unlock_state(nyxa), CharacterProgress.UnlockState.GATED)
	assert_eq(CharacterProgress.unlock_rule(nyxa), "Reach Lv 3 with any monster you own (best: Lv 1).")
	assert_eq(CharacterProgress.unlock_rule_short(nyxa), "Needs a Lv 3 monster")
	PersistedData.add_currency(PersistedData.LEAVES, 2500)
	assert_eq(CharacterProgress.unlock_state(nyxa), CharacterProgress.UnlockState.GATED, "the rule comes before the price")
	assert_false(CharacterProgress.unlock(nyxa))
	assert_eq(PersistedData.get_currency(PersistedData.LEAVES), 2500, "nothing spent")
	PersistedData.add_monster_xp(&"grount", 299)
	assert_eq(CharacterProgress.best_owned_level(CharacterDef.MONSTER), 2)
	assert_eq(CharacterProgress.unlock_state(nyxa), CharacterProgress.UnlockState.GATED, "Lv 2 is not enough")
	PersistedData.add_monster_xp(&"grount", 1)
	assert_eq(CharacterProgress.unlock_state(nyxa), CharacterProgress.UnlockState.READY, "Grount Lv 3 opens it")
	assert_eq(CharacterProgress.unlock_rule(nyxa), "A monster of yours has reached Lv 3.")
	assert_true(PersistedData.spend_currency(PersistedData.LEAVES, 1))
	assert_eq(CharacterProgress.unlock_state(nyxa), CharacterProgress.UnlockState.SHORT, "2,499 Leaves")
	assert_false(CharacterProgress.can_unlock(nyxa))
	assert_false(CharacterProgress.unlock(nyxa))
	PersistedData.add_currency(PersistedData.LEAVES, 1)
	assert_true(CharacterProgress.can_unlock(nyxa))
	assert_true(CharacterProgress.unlock(nyxa), "bought")
	assert_eq(PersistedData.get_currency(PersistedData.LEAVES), 0, "for exactly 2,500 Leaves")
	assert_true(CharacterProgress.is_unlocked(nyxa))
	assert_eq(CharacterProgress.unlock_state(nyxa), CharacterProgress.UnlockState.OWNED)
	assert_false(CharacterProgress.unlock(nyxa), "never twice")
	assert_eq(_ids(owned_events), "nyxa", "monster_owned fired once")
	PersistedData.monster_owned.disconnect(on_owned)
	assert_eq(str(_saved(PersistedData.SECTION_MONSTERS, "owned")), str(["nyxa"]), "the purchase is saved")
	assert_eq(_ids(PersistedData.get_owned_monsters()), "nyxa", "[monsters] owned lists the bought one only")


## Any owned monster opens the gate, a level on one the player does not own
## does not; heroes are never sold.
func test_any_owned_monster_opens_the_gate() -> void:
	if not require_isolated():
		return
	var gorrak := _def(&"gorrak")
	PersistedData.add_monster_xp(&"nyxa", 300)
	PersistedData.add_currency(PersistedData.LEAVES, 3000)
	assert_eq(CharacterProgress.unlock_state(gorrak), CharacterProgress.UnlockState.GATED, "Nyxa's Lv 3 does not count while she is locked")
	PersistedData.add_owned_monster(&"nyxa")
	assert_eq(CharacterProgress.best_owned_level(CharacterDef.MONSTER), 3)
	assert_eq(CharacterProgress.unlock_state(gorrak), CharacterProgress.UnlockState.READY, "an owned Lv 3 Nyxa opens Gorrak")
	assert_true(CharacterProgress.unlock(gorrak))
	assert_eq(PersistedData.get_currency(PersistedData.LEAVES), 0, "for 3,000 Leaves")
	assert_eq(_ids(PersistedData.get_owned_monsters()), "nyxa, gorrak")
	var irelia := _def(&"irelia")
	assert_eq(CharacterProgress.unlock_state(irelia), CharacterProgress.UnlockState.OWNED)
	PersistedData.add_hero_xp(&"irelia", 10000)
	assert_eq(CharacterProgress.best_owned_level(CharacterDef.MONSTER), 3, "hero levels never open a monster")


## The Monster side plays the player's own monster: Grount until another
## owned one is chosen; a Monster-side hunt adds no Codex entry.
func test_monster_side_plays_the_own_monster() -> void:
	if not require_isolated():
		return
	GameManager.choose_side(MatchRewards.Side.MONSTER, false)
	GameManager.begin_hunt()
	assert_eq(GameManager.selected_monster_id, &"grount")
	assert_false(GameManager.choose_monster(&"nyxa"), "not owned")
	assert_eq(GameManager.played_monster_id(), &"grount")
	PersistedData.set_setting(GameManager.SETTING_SELECTED_MONSTER, "gorrak")
	assert_eq(GameManager.played_monster_id(), &"grount", "a saved monster the player does not own falls back")
	PersistedData.add_owned_monster(&"nyxa")
	assert_true(GameManager.choose_monster(&"nyxa"))
	assert_eq(GameManager.played_monster_id(), &"nyxa")
	assert_false(GameManager.choose_monster(&"irelia"), "a hero is no monster")
	GameManager.begin_hunt()
	assert_eq(GameManager.selected_monster_id, &"nyxa", "the Monster-side hunt plays her")
	assert_eq(PersistedData.get_codex_entries(PersistedData.CODEX_MONSTERS).size(), 0, "playing her is no sighting")
	assert_eq(PersistedData.get_last_quarry(), &"", "nor a quarry")


func test_saved_lists_skip_junk() -> void:
	if not require_isolated():
		return
	PersistedData._config.set_value(PersistedData.SECTION_MONSTERS, "owned", ["nyxa", 7, "", "nyxa", &"gorrak"])
	assert_eq(_ids(PersistedData.get_owned_monsters()), "nyxa, gorrak", "strings only, once each")
	PersistedData._config.set_value(PersistedData.SECTION_CODEX, "monsters", "grount")
	assert_eq(PersistedData.get_codex_entries(PersistedData.CODEX_MONSTERS).size(), 0, "not a list: empty")
	assert_true(PersistedData.add_codex_entry(PersistedData.CODEX_MONSTERS, &"grount"))
	assert_false(PersistedData.add_codex_entry(PersistedData.CODEX_MONSTERS, &"grount"), "once")
	assert_false(PersistedData.add_codex_entry(PersistedData.CODEX_MONSTERS, &""))
