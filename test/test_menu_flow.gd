extends TestCase

## The menu flow fixes of the final review (fix batch F5):
##   - TapGuard: what has just appeared takes no tap (MenuRoot's push and pop,
##     the unlock, settings and quarry sheets, the match result's intro), with
##     real mouse presses through the viewport, as a finger's would go;
##   - ConfirmButton: arm, the minimum gap before the confirming tap, the
##     window that starts again with every arming (Reset Progress, QUIT);
##   - START HUNT / UNLEASH act once per visit;
##   - the lobby: the first tap on the stage that is not chosen only chooses
##     the side; the cave above the lair for tall screens;
##   - the Codex: the player's own monsters have open pages, and Reset Progress
##     clears the seen count;
##   - Growth's HEROES / MONSTER tabs and the arch starting the hunt of the
##     screen's side;
##   - the AI quarry card's labels, the sheets reaching the bottom edge, the
##     settings' privacy line, the tour's skill tree step.
## (test_roster_screen has the filters and the grid, test_match_config the
## strategy that survives back.) Tests that write the save run only in the
## isolated test user dir.

const MENU_ROOT := preload("res://Scenes/UI/Screens/MenuRoot.tscn")
const LOBBY := preload("res://Scenes/UI/Screens/LobbyScreen.tscn")
const SETTINGS := preload("res://Scenes/UI/Settings/SettingsScreen.tscn")
const PAUSE_MENU := preload("res://Scenes/UI/Hud/PauseMenu.tscn")
const RESULT := preload("res://Scenes/UI/Screens/MatchResultScreen.tscn")
const CONFIRM_BUTTON := preload("res://Scenes/UI/Components/ConfirmButton.tscn")
const PRE_ROUND := preload("res://Scenes/UI/Screens/PreRoundScreen.tscn")
const CODEX := preload("res://Scenes/UI/Screens/CodexScreen.tscn")
const UNLOCK_SHEET := preload("res://Scenes/UI/Components/UnlockSheet.tscn")
const HEROES := MatchRewards.Side.HEROES
const MONSTER := MatchRewards.Side.MONSTER
## The gaps between the two taps of a double tap the walkthrough tried.
const DOUBLE_TAP_GAPS: Array[float] = [0.08, 0.15, 0.25]
## A slide and the guard's grace have passed.
const SETTLED := MenuRoot.SLIDE_TIME + TapGuard.GRACE + 0.1

var _side_before: int = HEROES
var _world_before: PackedScene = null


func before_each() -> void:
	_side_before = GameManager.chosen_side
	# A MenuRoot in the tree starts the background World load unless the
	# session already holds the scene (see test_menu_root).
	_world_before = GameManager.world_scene
	if GameManager.world_scene == null:
		GameManager.world_scene = PackedScene.new()
	if is_isolated():
		PersistedData.wipe_progress(false)
		TutorialOverlay.mark_seen()


func after_each() -> void:
	GameManager.world_scene = _world_before
	GameManager.choose_side(_side_before, false)
	get_tree().paused = false
	if is_isolated():
		PersistedData.wipe_progress(false)


func _menu_root() -> MenuRoot:
	var root := MENU_ROOT.instantiate() as MenuRoot
	add_child(root)
	await wait_frames(2)
	return root


## One tap (the left mouse button down and up) at `at`, in viewport pixels,
## through the viewport's input pipeline.
func _tap(at: Vector2) -> void:
	for down: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		click.position = at
		click.global_position = at
		get_viewport().push_input(click, true)


func _centre(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


func _press_back() -> void:
	var back := InputEventAction.new()
	back.action = &"ui_cancel"
	back.pressed = true
	get_viewport().push_input(back)


func _settings_sheets(root: Node) -> int:
	var n := 0
	for child in root.get_children():
		if child is SettingsScreen and not child.is_queued_for_deletion():
			n += 1
	return n


# ------------------------------------------------------------ tap guard ----

func test_tap_guard_swallows_new_presses_until_it_lets_go() -> void:
	var guard := TapGuard.new()
	add_child(guard)
	var button := Button.new()
	button.size = Vector2(200, 80)
	add_child(button)
	await wait_frames(1)
	var presses := [0]
	button.pressed.connect(func() -> void: presses[0] += 1)
	var at := _centre(button)
	_tap(at)
	assert_eq(presses[0], 1, "an idle guard lets every tap through")
	guard.hold(0.2)
	assert_true(guard.is_holding())
	_tap(at)
	await wait_seconds(0.2)
	_tap(at)
	assert_eq(presses[0], 1, "held: no tap while it appears, none in the grace time after")
	await wait_seconds(TapGuard.GRACE + 0.05)
	assert_false(guard.is_holding(), "appear time + GRACE, in game time")
	_tap(at)
	assert_eq(presses[0], 2, "then taps count again")
	guard.hold(5.0)
	guard.hold(0.1)
	await wait_seconds(0.1 + TapGuard.GRACE + 0.05)
	assert_true(guard.is_holding(), "a shorter hold never cuts a longer one")
	guard.release()
	_tap(at)
	assert_eq(presses[0], 3, "release() ends it")
	guard.queue_free()
	button.queue_free()


## walk_menus problem 5 / review menus-1, the Monster side: the second tap of
## a double tap on HUNT landed on the pre-round's first picker card and made
## Grount the player's monster. (On a phone the card slides in under the HUNT
## button; the test's viewport is wider, so the second tap goes where the
## card comes to rest.)
func test_double_tap_on_hunt_keeps_the_players_monster() -> void:
	if not require_isolated():
		return
	PersistedData.add_owned_monster(&"nyxa")
	assert_true(GameManager.choose_monster(&"nyxa"))
	GameManager.choose_side(MONSTER, false)
	var root := await _menu_root()
	var hunt := _centre(root.lobby.get_node("%MonsterHunt") as Control)
	root.lobby.hunt_requested.emit(MONSTER)
	await wait_seconds(SETTLED)
	var grount_card := root.pre_round.picker_cards()[0]
	assert_eq(grount_card.character.character_id(), &"grount")
	var card := _centre(grount_card)
	root.pop()
	await wait_seconds(SETTLED)
	for gap in DOUBLE_TAP_GAPS:
		_tap(hunt)
		assert_eq(root.top(), root.pre_round, "the first tap opens the pre-round")
		await wait_seconds(gap)
		_tap(card)
		await wait_seconds(SETTLED)
		assert_eq(root.top(), root.pre_round)
		assert_eq(GameManager.played_monster_id(), &"nyxa", "second tap %.2f s later: still Nyxa" % gap)
		assert_eq(root.pre_round.monster.character_id(), &"nyxa")
		root.pop()
		await wait_seconds(SETTLED)
	# The same second tap without the guard is the bug: once the slide has
	# landed (0.25 s) it picks Grount's card.
	_tap(hunt)
	(root.get_node("%TapGuard") as TapGuard).release()
	await wait_seconds(0.25)
	_tap(card)
	assert_eq(GameManager.played_monster_id(), &"grount", "unguarded, the tap picks the card under it")
	root.queue_free()


## The Heroes side: the second tap landed on CHANGE and opened the quarry sheet.
func test_double_tap_on_hunt_does_not_open_the_quarry_sheet() -> void:
	if not require_isolated():
		return
	GameManager.choose_side(HEROES, false)
	var root := await _menu_root()
	var hunt := _centre(root.lobby.get_node("%HeroHunt") as Control)
	root.lobby.hunt_requested.emit(HEROES)
	await wait_seconds(SETTLED)
	var change := _centre(root.pre_round.get_node("Scroll/Body/Column/Quarry/QuarryInfo/Change") as Control)
	root.pop()
	await wait_seconds(SETTLED)
	for gap in DOUBLE_TAP_GAPS:
		_tap(hunt)
		assert_eq(root.top(), root.pre_round)
		await wait_seconds(gap)
		_tap(change)
		await wait_seconds(SETTLED)
		assert_false(root.pre_round.is_sheet_open(), "second tap %.2f s later: no quarry sheet" % gap)
		root.pop()
		await wait_seconds(SETTLED)
	_tap(hunt)
	(root.get_node("%TapGuard") as TapGuard).release()
	await wait_seconds(0.25)
	_tap(change)
	assert_true(root.pre_round.is_sheet_open(), "unguarded, the tap presses CHANGE")
	root.queue_free()


## A double tap on a back arrow popped to the lobby and opened the settings
## (the gear is under the arrow).
func test_double_tap_on_back_does_not_open_the_settings() -> void:
	if not require_isolated():
		return
	var root := await _menu_root()
	for gap in DOUBLE_TAP_GAPS:
		root.lobby.roster_requested.emit(HEROES)
		await wait_seconds(SETTLED)
		var at := _centre(root.hero_roster.get_node("%TopBar").get_node("%Left") as Control)
		_tap(at)
		assert_eq(root.top(), root.lobby, "the first tap goes back")
		await wait_seconds(gap)
		_tap(at)
		await wait_seconds(SETTLED)
		assert_eq(_settings_sheets(root), 0, "second tap %.2f s later: the gear is not pressed" % gap)
	_tap(_centre(root.lobby.get_node("%TopBar").get_node("%Left") as Control))
	assert_eq(_settings_sheets(root), 1, "a tap on the settled lobby's gear opens the settings")
	root.queue_free()


## The opening tap's twin hit the scrim and closed the sheet again.
func test_sheets_take_no_tap_while_they_slide_up() -> void:
	if not require_isolated():
		return
	GameManager.choose_side(HEROES, false)
	var root := await _menu_root()
	var scrim_spot := Vector2(root.size.x * 0.5, 40.0)
	# The unlock sheet.
	root.unlock_sheet.open_for(GameManager.ROSTER.find(&"nyxa"))
	await wait_seconds(0.12)
	_tap(scrim_spot)
	assert_true(root.unlock_sheet.is_open(), "a tap while the unlock sheet slides up does not close it")
	await wait_seconds(SETTLED)
	_tap(scrim_spot)
	assert_false(root.unlock_sheet.is_open(), "once it has settled, a tap on the scrim closes it")
	await wait_seconds(SETTLED)
	# The settings sheet.
	root._on_settings_requested()
	var settings: SettingsScreen = null
	for child in root.get_children():
		if child is SettingsScreen:
			settings = child as SettingsScreen
	assert_true(settings != null)
	await wait_seconds(0.12)
	_tap(scrim_spot)
	assert_false(settings.is_closing(), "nor the settings sheet")
	await wait_seconds(SETTLED)
	_tap(scrim_spot)
	assert_true(settings.is_closing(), "settled: the scrim closes it")
	await wait_seconds(SETTLED)
	# The pre-round's quarry sheet.
	root.lobby.hunt_requested.emit(HEROES)
	await wait_seconds(SETTLED)
	var change := _centre(root.pre_round.get_node("Scroll/Body/Column/Quarry/QuarryInfo/Change") as Control)
	_tap(change)
	assert_true(root.pre_round.is_sheet_open(), "CHANGE opens the quarry sheet")
	await wait_seconds(0.12)
	_tap(scrim_spot)
	assert_true(root.pre_round.is_sheet_open(), "nor the quarry sheet")
	await wait_seconds(SETTLED)
	_tap(scrim_spot)
	assert_false(root.pre_round.is_sheet_open(), "settled: the scrim closes it")
	root.queue_free()


## review menus-2: LOBBY and PLAY AGAIN were live while still invisible, where
## the HUD's hero cards are.
func test_match_result_takes_no_tap_before_its_buttons_show() -> void:
	var screen := RESULT.instantiate() as MatchResultScreen
	screen.changes_scene = false
	add_child(screen)
	screen.populate(MatchRewards.compute(HEROES, MatchRewards.Outcome.WIN, 300.0, 5, 4, 1, 0))
	var asked := [0]
	screen.lobby_requested.connect(func() -> void: asked[0] += 1)
	screen.play_again_requested.connect(func() -> void: asked[0] += 1)
	await wait_seconds(0.25)
	var buttons := screen.get_node("%Buttons") as CanvasItem
	assert_true(buttons.modulate.a < 0.05, "0.25 s in, the buttons are not shown yet")
	_tap(_centre(screen.get_node("Root/Margin/Column/Buttons/Lobby") as Control))
	_tap(_centre(screen.get_node("%PlayAgain") as Control))
	_press_back()
	assert_eq(asked[0], 0, "so no tap and no back press counts")
	await wait_seconds(1.25)
	assert_near(buttons.modulate.a, 1.0, 0.001, "1.5 s in they are")
	_tap(_centre(screen.get_node("%PlayAgain") as Control))
	assert_eq(asked[0], 1, "and they press")
	screen.queue_free()


# ------------------------------------------------------- confirm button ----

func test_confirm_button_needs_a_gap_and_a_fresh_window() -> void:
	var button := CONFIRM_BUTTON.instantiate() as ConfirmButton
	add_child(button)
	var events: Array[String] = []
	button.armed_changed.connect(func(armed: bool) -> void: events.append("armed" if armed else "disarmed"))
	button.confirmed.connect(func() -> void: events.append("confirmed"))
	button.pressed.emit()
	button.pressed.emit()
	assert_eq(", ".join(events), "armed", "the two taps of one double tap only arm it")
	await wait_seconds(0.08)
	button.pressed.emit()
	assert_true(button.is_armed(), "0.08 s later is still the same double tap")
	await wait_seconds(ConfirmButton.MIN_GAP)
	button.pressed.emit()
	assert_eq(", ".join(events), "armed, disarmed, confirmed", "a deliberate second tap confirms")
	assert_false(button.is_armed())
	events.clear()
	# An armed button that is left alone disarms itself.
	button.pressed.emit()
	await wait_seconds(button.arm_time + 0.1)
	assert_eq(", ".join(events), "armed, disarmed")
	# review menus-10: arming again starts a fresh window; nothing of the
	# first arming is left to cut it short.
	events.clear()
	button.pressed.emit()
	await wait_seconds(2.0)
	button.disarm()
	button.pressed.emit()
	await wait_seconds(1.2)
	assert_true(button.is_armed(), "armed 1.2 s ago, the window is 3 s")
	button.pressed.emit()
	assert_eq(", ".join(events), "armed, disarmed, armed, disarmed, confirmed")
	button.queue_free()


## review menus-5: both taps of one double tap on RESET PROGRESS wiped the save.
func test_reset_progress_ignores_a_double_tap() -> void:
	if not require_isolated():
		return
	PersistedData.add_currency(PersistedData.GOLD, 5000)
	PersistedData.add_hero_xp(&"irelia", 3000)
	var sheet := SETTINGS.instantiate() as SettingsScreen
	add_child(sheet)
	await wait_seconds(SETTLED)
	var at := _centre(sheet.get_node("%Reset") as Control)
	_tap(at)
	await wait_seconds(0.08)
	_tap(at)
	assert_eq(PersistedData.get_currency(PersistedData.GOLD), 5000, "a double tap wipes nothing")
	assert_eq(PersistedData.get_hero_xp(&"irelia"), 3000)
	assert_eq((sheet.get_node("%Reset") as Button).text, "Tap again to confirm", "it is armed and says so")
	await wait_seconds(ConfirmButton.MIN_GAP)
	_tap(at)
	assert_eq(PersistedData.get_currency(PersistedData.GOLD), 0, "the deliberate second tap does")
	sheet.queue_free()


## review menus-10 on the pause menu itself: QUIT armed, resumed after 2 s,
## paused and armed again; the first arming's timer disarmed it 1 s later.
func test_pause_quit_window_starts_again() -> void:
	var menu := PAUSE_MENU.instantiate() as PauseMenu
	menu.changes_scene = false
	add_child(menu)
	menu.open()
	var quit := menu.get_node("%Quit") as ConfirmButton
	var quits := [0]
	menu.quit_requested.connect(func() -> void: quits[0] += 1)
	quit.pressed.emit()
	assert_eq(quit.text, "Tap again to leave")
	await wait_seconds(2.0)
	menu.resume()
	menu.open()
	assert_false(quit.is_armed(), "opening the menu disarms QUIT")
	assert_eq(quit.text, "Quit to lobby")
	assert_false((menu.get_node("%Hint") as CanvasItem).visible)
	quit.pressed.emit()
	await wait_seconds(1.2)
	assert_true(quit.is_armed(), "armed 1.2 s ago: still inside its 3 s")
	quit.pressed.emit()
	assert_eq(quits[0], 1, "so the second tap leaves")
	menu.queue_free()
	get_tree().paused = false


## review menus-12: a double press on START HUNT saved and tracked twice.
func test_start_hunt_and_unleash_act_once_per_visit() -> void:
	if not require_isolated():
		return
	var screen := PRE_ROUND.instantiate() as PreRoundScreen
	add_child(screen)
	var starts := [0]
	screen.start_requested.connect(func(_cfg: MatchConfig) -> void: starts[0] += 1)
	screen.monster_start_requested.connect(func(_id: StringName, _instinct: StringName) -> void: starts[0] += 1)
	screen.open(HEROES)
	var start := screen.get_node("%HeroStart") as BaseButton
	start.pressed.emit()
	start.pressed.emit()
	assert_eq(starts[0], 1, "START HUNT asks once")
	screen.open(HEROES)
	start.pressed.emit()
	assert_eq(starts[0], 2, "the next visit starts again")
	screen.open(MONSTER)
	var unleash := screen.get_node("%MonsterStart") as BaseButton
	unleash.pressed.emit()
	unleash.pressed.emit()
	assert_eq(starts[0], 3, "UNLEASH asks once")
	screen.queue_free()


# ---------------------------------------------------------------- lobby ----

## walk_menus problem 8: "Tap the lair to play the Monster" opened Grount's
## detail (or an unlock sheet) instead of only choosing the side.
func test_first_tap_on_the_other_stage_only_chooses_the_side() -> void:
	if not require_isolated():
		return
	GameManager.choose_side(HEROES, false)
	var root := await _menu_root()
	var lobby := root.lobby
	_tap(_centre(lobby.get_node("MonsterStage/Grount") as Control))
	assert_eq(lobby.chosen_side, MONSTER, "a tap on Grount in the unchosen lair chooses the Monster side")
	assert_eq(GameManager.chosen_side, MONSTER)
	assert_eq(root.top(), lobby, "and stays in the lobby")
	await wait_seconds(LobbyScreen.CTA_POP_TIME + 0.1)
	_tap(_centre(lobby.get_node("MonsterStage/Grount") as Control))
	assert_eq(root.top(), root.detail, "a tap on him on the chosen side opens his detail")
	assert_eq(root.detail.character.character_id(), &"grount")
	await wait_seconds(SETTLED)
	root.pop()
	await wait_seconds(SETTLED)
	_tap(_centre(lobby.get_node("HeroStage/Irelia") as Control))
	assert_eq(lobby.chosen_side, HEROES, "the campfire works the same way")
	assert_eq(root.top(), lobby)
	await wait_seconds(LobbyScreen.CTA_POP_TIME + 0.1)
	_tap(_centre(lobby.get_node("MonsterStage/Nyxa") as Control))
	assert_false(root.unlock_sheet.is_open(), "a locked monster in the unchosen lair: the side first")
	assert_eq(lobby.chosen_side, MONSTER)
	await wait_seconds(LobbyScreen.CTA_POP_TIME + 0.1)
	_tap(_centre(lobby.get_node("MonsterStage/Nyxa") as Control))
	assert_true(root.unlock_sheet.is_open(), "then its unlock sheet")
	root.queue_free()


## walk_menus problem 7: on a 19.5:9 phone the lair had a band of plain
## background above it. The cave runs on upward now.
func test_the_cave_runs_on_above_the_lair() -> void:
	var lobby := LOBBY.instantiate() as LobbyScreen
	var stage := lobby.get_node("%MonsterStage") as Control
	var top := stage.get_node("BackdropTop") as TextureRect
	var backdrop := stage.get_node("Backdrop") as TextureRect
	assert_true(top.get_index() < backdrop.get_index(), "behind the lair and its monsters")
	assert_eq(top.offset_bottom, backdrop.offset_top, "it sits on the lair art's top edge")
	assert_eq(top.anchor_top, 1.0, "anchored to the bottom like the lair, so the seam never moves")
	assert_true(stage.clip_contents, "a 16:9 screen clips it away")
	assert_eq(Vector2(top.texture.get_size()), Vector2(720, 420))
	assert_near(top.offset_bottom - top.offset_top, 420.0, 0.01, "at the design scale")
	lobby.free()
	# Review menus-3: measured, not assumed. Laid out on a 19.5:9 and a 21:9
	# phone (720 x 1560, 720 x 1680), the cave's top edge is at or above the
	# lair stage's, so no plain band shows above it.
	for height: float in [1560.0, 1680.0]:
		var holder := Control.new()
		holder.size = Vector2(720, height)
		add_child(holder)
		var tall := LOBBY.instantiate() as LobbyScreen
		holder.add_child(tall)
		tall.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await wait_frames(1)
		var tall_stage := tall.get_node("%MonsterStage") as Control
		var cave := tall_stage.get_node("BackdropTop") as Control
		var stage_top := tall_stage.get_global_rect().position.y
		assert_true(cave.get_global_rect().position.y <= stage_top + 0.5,
				"720 x %d: the cave starts at %.0f, the stage at %.0f" % [height, cave.get_global_rect().position.y, stage_top])
		holder.queue_free()
		await wait_frames(1)


# ---------------------------------------------------------------- codex ----

## walk_menus problem 10: the Codex said "Not met yet" for the player's own
## monsters.
func test_codex_opens_the_pages_of_owned_monsters() -> void:
	if not require_isolated():
		return
	var codex := CODEX.instantiate() as CodexScreen
	add_child(codex)
	codex.open()
	var entries := codex.monster_entries()
	assert_eq(entries[0].character.character_id(), &"grount", "the starting monster comes first")
	assert_true(entries[0].met, "and its page is open on a fresh save")
	assert_eq((entries[0].get_node("%Name") as Label).text, "Grount")
	assert_false(entries[1].met or entries[2].met, "the others are still locked pages")
	assert_eq((codex.get_node("%MetCount") as Label).text, "Beasts met 1 / 3")
	PersistedData.add_owned_monster(&"nyxa")
	assert_eq(CodexScreen.unseen_monsters(), 1, "a bought monster is a new page")
	codex.open()
	entries = codex.monster_entries()
	assert_eq(str(CodexScreen.met_monsters()), str([&"grount", &"nyxa"]))
	assert_true(entries[1].met and entries[1].character.character_id() == &"nyxa", "Nyxa's page opens with the purchase")
	assert_false((entries[1].get_node("%Tagline") as Label).text.begins_with("Not met yet"))
	assert_eq((codex.get_node("%MetCount") as Label).text, "Beasts met 2 / 3")
	# A quarry the heroes met keeps its place before the owned ones.
	PersistedData.add_codex_entry(PersistedData.CODEX_MONSTERS, &"gorrak")
	assert_eq(str(CodexScreen.met_monsters()), str([&"gorrak", &"grount", &"nyxa"]))
	assert_true(GameManager.is_new_quarry(&"nyxa"), "owning a monster is not hunting it: NEW QUARRY stays")
	codex.queue_free()


## walk_menus problem 17 / review menus-6 and meta-3: Reset Progress kept the
## Codex's seen count, so new pages no longer lit the dot.
func test_reset_progress_clears_the_codex_seen_count() -> void:
	if not require_isolated():
		return
	for id: StringName in [&"grount", &"nyxa", &"gorrak"]:
		PersistedData.add_codex_entry(PersistedData.CODEX_MONSTERS, id)
	var codex := CODEX.instantiate() as CodexScreen
	add_child(codex)
	codex.open()
	assert_eq(PersistedData.get_codex_seen(PersistedData.CODEX_MONSTERS), 3)
	assert_eq(CodexScreen.unseen_monsters(), 0)
	PersistedData.set_setting(&"music_volume", 0.4)
	PersistedData.wipe_progress()  # Reset Progress: the settings stay
	assert_near(float(PersistedData.get_setting(&"music_volume", 0.0)), 0.4, 0.001, "a device setting survives")
	assert_eq(PersistedData.get_codex_seen(PersistedData.CODEX_MONSTERS), 0, "the seen count goes with the Codex")
	PersistedData.load_data()
	assert_eq(PersistedData.get_codex_seen(PersistedData.CODEX_MONSTERS), 0, "in the file too")
	PersistedData.add_codex_entry(PersistedData.CODEX_MONSTERS, &"nyxa")
	assert_eq(CodexScreen.unseen_monsters(), 2, "after a reset new pages light the dot again (Grount's own and Nyxa)")
	codex.queue_free()


# --------------------------------------------------------------- growth ----

## walk_menus problem 11: Growth showed only the lobby's side, and the arch
## started that side's hunt wherever it was pressed.
func test_growth_switches_sides_and_the_arch_follows_the_screen() -> void:
	if not require_isolated():
		return
	GameManager.choose_side(HEROES, false)
	var root := await _menu_root()
	var growth := root.growth
	root.lobby.tab_selected.emit(&"growth")
	assert_eq(growth.tree_id, MetaSkillManager.TREE_HERO_BASE, "Growth opens on the chosen side's tree")
	assert_true((growth.get_node("%SideTabs") as CanvasItem).visible, "with the HEROES / MONSTER tabs")
	assert_false((growth.get_node("%Tabs") as CanvasItem).visible)
	assert_true((growth.get_node("%HeroesSide") as BaseButton).button_pressed)
	await wait_seconds(SETTLED)
	_tap(_centre(growth.get_node("%MonsterSide") as Control))
	assert_eq(growth.tree_id, MetaSkillManager.TREE_MONSTER_BASE, "MONSTER shows the monsters' tree")
	assert_eq(growth.shown_side(), MONSTER)
	assert_true((growth.get_node("%MonsterSide") as BaseButton).button_pressed)
	assert_false((growth.get_node("%HeroesSide") as BaseButton).button_pressed)
	assert_eq(GameManager.chosen_side, HEROES, "looking at a tree chooses no side")
	assert_true((growth.get_node("%NavBar") as NavBar).monster_side, "the arch glows in the shown side's colour")
	growth.tab_selected.emit(&"growth")
	assert_eq(growth.tree_id, MetaSkillManager.TREE_MONSTER_BASE, "the Growth tab on Growth keeps the side")
	# A dot per side: 40 Gold buys a tier 1 rank in either tree.
	var heroes_dot := growth.get_node("%HeroesSideDot") as CanvasItem
	var monster_dot := growth.get_node("%MonsterSideDot") as CanvasItem
	assert_false(heroes_dot.visible or monster_dot.visible, "no Gold: no dot")
	PersistedData.add_currency(PersistedData.GOLD, 40)
	await wait_frames(2)
	assert_true(heroes_dot.visible and monster_dot.visible, "a dot on each side that has a rank to buy")
	# Only the monsters' tree has something to buy: max the heroes' tier 1.
	for n in MetaSkillManager.get_tree_def(MetaSkillManager.TREE_HERO_BASE).shown_nodes():
		if n.tier == 1:
			PersistedData.set_skill_rank(MetaSkillManager.TREE_HERO_BASE, n.id, n.max_rank)
	MetaSkillManager.skills_changed.emit()
	await wait_frames(2)
	if not CharacterDetail.base_tree_ready(HEROES):
		assert_false(heroes_dot.visible, "nothing to buy for the heroes")
		assert_true(monster_dot.visible)
		assert_true((root.lobby.get_node("%NavBar") as NavBar).notify_tabs.has(&"growth"),
				"the nav bars' Growth dot counts either side, not only the chosen one")
	# The arch: the hunt of the side the screen stands for.
	growth.tab_selected.emit(&"hunt")
	assert_eq(root.top(), root.pre_round)
	assert_eq(root.pre_round.side, MONSTER, "HUNT on the monsters' tree opens the Monster pre-round")
	assert_eq(GameManager.chosen_side, MONSTER, "which makes it the chosen side")
	assert_eq(root.lobby.chosen_side, MONSTER, "on the lobby too")
	await wait_seconds(SETTLED)
	root.pop_to(root.lobby)
	await wait_seconds(SETTLED)
	root.lobby.roster_requested.emit(HEROES)
	assert_false((root.hero_roster.get_node("%NavBar") as NavBar).monster_side, "the Heroes roster's arch is amber")
	await wait_seconds(SETTLED)
	root.hero_roster.tab_selected.emit(&"hunt")
	assert_eq(root.pre_round.side, HEROES, "HUNT on the Heroes roster hunts with the heroes")
	assert_eq(root.lobby.chosen_side, HEROES)
	await wait_seconds(SETTLED)
	root.pop()
	await wait_seconds(SETTLED)
	root.hero_roster.tab_selected.emit(&"monsters")
	await wait_seconds(SETTLED)
	root.monster_roster.cards()[0].pressed.emit()
	assert_eq(root.top(), root.detail)
	assert_true((root.detail.get_node("%NavBar") as NavBar).monster_side, "a monster's detail: crimson")
	await wait_seconds(SETTLED)
	root.detail.tab_selected.emit(&"hunt")
	assert_eq(root.pre_round.side, MONSTER, "and its arch starts the monster's hunt")
	root.queue_free()


# -------------------------------------------------------- small fixes ----

## walk_menus problem 14: the AI quarry card read "Lv.2" and "3/12" like one
## of the player's own cards.
func test_the_quarry_card_is_labelled_as_the_ai_opponent() -> void:
	if not require_isolated():
		return
	PersistedData.add_monster_xp(&"grount", 3000)  # the player's own Grount is far above level 2
	var screen := PRE_ROUND.instantiate() as PreRoundScreen
	add_child(screen)
	screen.open(HEROES)
	var card := screen.get_node("%QuarryCard") as CharacterCard
	var threat := (screen.get_node("%QuarryThreat") as ThreatBox).threat
	assert_eq(card.ai_threat, threat)
	assert_eq((card.get_node("%Level") as Label).text, "Threat %d" % threat, "the threat, not a level")
	var tree_id := MetaSkillManager.monster_tree_id(screen.quarry.character_id())
	assert_eq((card.get_node("%PillLabel") as Label).text, "AI build %d/%d" % [
		MetaSkillManager.ai_build_size(tree_id, threat), MetaSkillManager.ai_build_size(tree_id, MetaSkillManager.MAX_THREAT)])
	screen.open_sheet()
	for sheet_card in screen.sheet_cards():
		if sheet_card.unlocked:
			assert_true((sheet_card.get_node("%Level") as Label).text.begins_with("Threat "), "the Change sheet's cards too")
			assert_true((sheet_card.get_node("%PillLabel") as Label).text.begins_with("AI build "))
	# The longest labels (German, threat 4) stay inside an S card.
	var before := TranslationServer.get_locale()
	TranslationServer.set_locale("de")
	var small := screen.sheet_cards()[0]
	small.apply_ai_build(MetaSkillManager.MAX_THREAT, 12, 12)
	assert_eq((small.get_node("%Level") as Label).text, "Bedrohung 4")
	assert_eq((small.get_node("%PillLabel") as Label).text, "KI-Ausbau 12/12")
	assert_true(small.get_combined_minimum_size().x <= CharacterCard.SIZES[CharacterCard.CardSize.S].x,
			"the S card keeps its width (%.0f px needed)" % small.get_combined_minimum_size().x)
	TranslationServer.set_locale(before)
	# A card of the player's own still shows level and XP, at the level's size.
	var ai_font := (card.get_node("%Level") as Label).get_theme_font_size(&"font_size")
	card.character = GameManager.ROSTER.find(&"grount")
	assert_eq(card.ai_threat, -1)
	assert_true((card.get_node("%Level") as Label).text.begins_with("Lv."))
	assert_true((card.get_node("%Level") as Label).get_theme_font_size(&"font_size") > ai_font, "Threat N is set smaller than Lv.N")
	screen.queue_free()


## walk_menus problem 13: the nav tabs peeked out under the unlock sheet.
func test_sheets_reach_the_bottom_edge() -> void:
	var sheet := UNLOCK_SHEET.instantiate() as UnlockSheet
	var panel := sheet.get_node("Slide/Sheet") as Control
	assert_eq(panel.anchor_bottom, 1.0)
	assert_eq(panel.offset_bottom, 0.0, "the unlock sheet's panel ends on the screen's bottom edge")
	sheet.free()
	var pre_round := PRE_ROUND.instantiate() as PreRoundScreen
	assert_eq((pre_round.get_node("QuarrySheet/Slide/Sheet") as Control).offset_bottom, 0.0, "the quarry sheet's too")
	pre_round.free()


## walk_menus problem 16: the privacy line showed "user://analytics.jsonl".
func test_settings_show_no_developer_path() -> void:
	var sheet := SETTINGS.instantiate() as SettingsScreen
	var hint := sheet.get_node("Slide/Sheet/VBox/PrivacyPanel/Rows/Hint") as Label
	var before := TranslationServer.get_locale()
	for locale: String in ["en", "de"]:
		TranslationServer.set_locale(locale)
		var shown := TranslationServer.translate(hint.text)
		assert_false(String(shown).contains("user://") or String(shown).contains(".jsonl"), "%s: %s" % [locale, shown])
	TranslationServer.set_locale("de")
	assert_true(String(TranslationServer.translate(hint.text)) != hint.text, "the line has its German")
	TranslationServer.set_locale(before)
	sheet.free()


## walk_menus problem 20: the tour never pointed at the skill trees.
func test_the_tour_points_at_the_skill_tree_tabs() -> void:
	var steps := TutorialOverlay.LOBBY_STEPS
	var grow: Dictionary = {}
	for step in steps:
		if String(step.get("title")) == "Grow between matches":
			grow = step
	assert_eq(grow.get("anchor"), TutorialOverlay.TARGET_TREES, "the step frames the tabs that lead to the trees")
	assert_true(String(grow.get("body")).contains("SKILL TREE"), "and names the tab the tree sits behind")
	assert_eq(steps[-1].get("anchor"), TutorialOverlay.TARGET_CODEX, "the Codex keeps a step of its own")
	var before := TranslationServer.get_locale()
	TranslationServer.set_locale("de")
	for step: Dictionary in [grow, steps[-1]]:
		for key: String in ["title", "body"]:
			assert_true(String(TranslationServer.translate(String(step.get(key)))) != String(step.get(key)),
					"German for: %s" % step.get(key))
	TranslationServer.set_locale(before)
	var lobby := LOBBY.instantiate() as LobbyScreen
	add_child(lobby)
	var overlay := (load("res://Scenes/UI/Tutorial/TutorialOverlay.tscn") as PackedScene).instantiate() as TutorialOverlay
	add_child(overlay)
	await wait_frames(2)
	var nav := lobby.get_node("%NavBar") as NavBar
	var frame := overlay.target_rect(TutorialOverlay.TARGET_TREES)
	for tab: StringName in [&"heroes", &"growth", &"monsters"]:
		assert_true(nav.tab(tab).is_in_group(TutorialOverlay.TARGET_TREES), "%s is a tree tab" % tab)
		assert_true(frame.grow(1.0).encloses(nav.tab(tab).get_global_rect()), "the frame holds %s" % tab)
	overlay.queue_free()
	lobby.queue_free()
