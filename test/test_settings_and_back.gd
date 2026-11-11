extends TestCase

## The SettingsScreen sheet (scene-side wiring, live volumes, the reset's
## second tap, back closing it), the match's PauseMenu (pause, resume, the
## settings over it, the quit's second tap), the Android back button as
## ui_cancel (BackButton; quit_on_go_back off; MenuRoot leaves only from the
## bare lobby; the result screen's back is LOBBY), the settings opening after
## the first-run tutorial, the lobby's lair on a tall phone, and the exit
## leaks (a pooled mob released while its manager leaves). Tests that write
## the save run only in the isolated test user dir.

const SETTINGS := preload("res://Scenes/UI/Settings/SettingsScreen.tscn")
const PAUSE_MENU := preload("res://Scenes/UI/Hud/PauseMenu.tscn")
const MENU_ROOT := preload("res://Scenes/UI/Screens/MenuRoot.tscn")
const LOBBY := preload("res://Scenes/UI/Screens/LobbyScreen.tscn")
const RESULT := preload("res://Scenes/UI/Screens/MatchResultScreen.tscn")
## The result's buttons have faded in and its TapGuard has let go (about 1.3 s).
const INTRO_SHOWN := 1.5

var _world_before: PackedScene = null
var _side_before: int = MatchRewards.Side.HEROES


func before_each() -> void:
	_world_before = GameManager.world_scene
	_side_before = GameManager.chosen_side
	if GameManager.world_scene == null:
		GameManager.world_scene = PackedScene.new()
	if is_isolated():
		PersistedData.wipe_progress(false)
		TutorialOverlay.mark_seen()


func after_each() -> void:
	GameManager.world_scene = _world_before
	GameManager.choose_side(_side_before, false)
	get_tree().paused = false


func _back(node: Node) -> bool:
	return BackButton.press(node.get_viewport())


func _overlays(root: Node, script_class: StringName) -> Array[Node]:
	var out: Array[Node] = []
	for child in root.get_children():
		var script := child.get_script() as Script
		if script != null and script.get_global_name() == script_class and not child.is_queued_for_deletion():
			out.append(child)
	return out


# ------------------------------------------------------------ settings ----

func test_settings_sheet_is_wired_in_its_scene() -> void:
	var state := SETTINGS.get_state()
	var bound: Array[StringName] = []
	for i in state.get_connection_count():
		if state.get_connection_method(i) == &"_on_volume_changed":
			var binds := state.get_connection_binds(i)
			bound.append(binds[0])
	for key in AudioSettings.VOLUME_KEYS:
		assert_true(bound.has(key), "a slider bound to %s" % key)
	assert_true(state.get_connection_count() >= 10, "every control wired scene-side")


func test_volumes_apply_live_and_close_saves() -> void:
	if not require_isolated():
		return
	var sheet := SETTINGS.instantiate() as SettingsScreen
	add_child(sheet)
	var music := sheet.slider(AudioSettings.KEY_MUSIC)
	assert_near(music.value, AudioSettings.get_volume(AudioSettings.KEY_MUSIC), 0.001, "shows the saved volume")
	music.value = 0.35
	assert_near(AudioSettings.get_volume(AudioSettings.KEY_MUSIC), 0.35, 0.001, "applies at once")
	assert_eq((sheet.get_node("%MusicValue") as Label).text, "35%")
	var closed := [false]
	sheet.closed.connect(func() -> void: closed[0] = true)
	assert_true(_back(sheet), "back closes the sheet")
	assert_true(closed[0])
	PersistedData.load_data()
	assert_near(AudioSettings.get_volume(AudioSettings.KEY_MUSIC), 0.35, 0.001, "saved on close")
	await wait_seconds(SettingsScreen.SLIDE_TIME + 0.1)
	assert_false(is_instance_valid(sheet), "and frees itself")
	AudioSettings.set_volume(AudioSettings.KEY_MUSIC, AudioSettings.DEFAULT_VOLUME)


func test_reset_needs_a_second_tap() -> void:
	if not require_isolated():
		return
	PersistedData.add_currency(PersistedData.GOLD, 500)
	var sheet := SETTINGS.instantiate() as SettingsScreen
	add_child(sheet)
	var reset := sheet.get_node("%Reset") as Button
	reset.pressed.emit()
	assert_eq(PersistedData.get_currency(PersistedData.GOLD), 500, "the first tap only arms it")
	assert_eq(reset.text, "Tap again to confirm")
	await wait_seconds(ConfirmButton.MIN_GAP + 0.05)
	reset.pressed.emit()
	assert_eq(PersistedData.get_currency(PersistedData.GOLD), 0, "the second tap wipes the progress")
	assert_true(reset.disabled)
	sheet.queue_free()


func test_settings_use_theme_variations_only() -> void:
	var sheet := SETTINGS.instantiate()
	for node in sheet.find_children("*", "Control", true, true):
		var c := node as Control
		for prop in c.get_property_list():
			var prop_name: String = prop["name"]
			if prop_name.begins_with("theme_override_colors") or prop_name.begins_with("theme_override_fonts") \
					or prop_name.begins_with("theme_override_styles") or prop_name.begins_with("theme_override_font_sizes"):
				assert_true(c.get(prop_name) == null, "%s overrides %s" % [c.name, prop_name])
	sheet.free()


# ---------------------------------------------------------- pause menu ----

func test_pause_menu_pauses_resumes_and_quits_on_a_second_tap() -> void:
	if not require_isolated():
		return
	var menu := PAUSE_MENU.instantiate() as PauseMenu
	menu.changes_scene = false
	add_child(menu)
	assert_false(menu.is_open())
	assert_eq(menu.process_mode, Node.PROCESS_MODE_ALWAYS, "it works on the paused tree")
	menu.open()
	assert_true(menu.is_open())
	assert_true(get_tree().paused, "the match pauses")
	(menu.get_node("Center/Panel/VBox/Settings") as Button).pressed.emit()
	var sheet := menu.settings()
	assert_true(sheet != null, "SETTINGS opens the sheet over it")
	assert_true(_back(menu), "back")
	assert_true(sheet.is_closing(), "closes the sheet first")
	assert_true(menu.is_open(), "the menu stays")
	assert_true(_back(menu))
	assert_false(menu.is_open(), "then back resumes")
	assert_false(get_tree().paused)
	menu.open()
	var quits := [0]
	menu.quit_requested.connect(func() -> void: quits[0] += 1)
	var quit := menu.get_node("%Quit") as Button
	quit.pressed.emit()
	assert_eq(quits[0], 0, "the first tap only arms QUIT")
	assert_true((menu.get_node("%Hint") as Control).visible, "and says it pays nothing")
	await wait_seconds(ConfirmButton.MIN_GAP + 0.05)
	quit.pressed.emit()
	assert_eq(quits[0], 1, "the second tap leaves")
	menu.queue_free()
	get_tree().paused = false


func test_the_hud_owns_its_pause_menu() -> void:
	var hud := (load("res://Scenes/UI/Hud/MatchHud.tscn") as PackedScene).instantiate()
	var menu := hud.get_node("%PauseMenu") as PauseMenu
	assert_true(menu != null, "MatchHud.tscn holds the pause menu")
	for sig: StringName in [&"opened", &"resumed"]:
		assert_eq(menu.get_signal_connection_list(sig).size(), 1, "%s is wired in the scene" % sig)
	hud.free()


# --------------------------------------------------------- back button ----

func test_back_button_is_ui_cancel_and_quits_only_from_the_lobby() -> void:
	if not require_isolated():
		return
	assert_false(bool(ProjectSettings.get_setting("application/config/quit_on_go_back", true)), "the OS back press reaches the game")
	var root := MENU_ROOT.instantiate() as MenuRoot
	add_child(root)
	await wait_frames(1)
	assert_false(root.go_back(), "nothing to go back from on the bare lobby: MenuRoot quits")
	root.lobby.roster_requested.emit(MatchRewards.Side.HEROES)
	await wait_seconds(MenuRoot.SLIDE_TIME + 0.1)
	assert_true(root.go_back(), "a screen pops")
	assert_eq(root.top(), root.lobby)
	await wait_seconds(MenuRoot.SLIDE_TIME + 0.1)
	root._on_settings_requested()
	assert_true(root.go_back(), "an open overlay closes first")
	assert_eq(root.top(), root.lobby)
	await wait_seconds(SettingsScreen.SLIDE_TIME + 0.1)
	root.unlock_sheet.open_for(GameManager.ROSTER.find(&"nyxa"))
	assert_true(root.go_back(), "a bottom sheet closes")
	assert_false(root.unlock_sheet.is_open())
	root.queue_free()


func test_result_screen_back_is_lobby() -> void:
	var screen := RESULT.instantiate() as MatchResultScreen
	screen.changes_scene = false
	add_child(screen)
	var r := MatchRewards.compute(MatchRewards.Side.HEROES, MatchRewards.Outcome.WIN, 300.0, 5, 4, 1, 0)
	screen.populate(r)
	var asked := [0]
	screen.lobby_requested.connect(func() -> void: asked[0] += 1)
	assert_true(_back(screen), "back during the intro is taken")
	assert_eq(asked[0], 0, "and dropped: the result is still appearing")
	await wait_seconds(INTRO_SHOWN)
	assert_true(_back(screen))
	assert_eq(asked[0], 1, "back is LOBBY")
	screen.queue_free()


func test_settings_open_after_the_first_run_tutorial() -> void:
	if not require_isolated():
		return
	PersistedData.wipe_progress(false)
	var root := MENU_ROOT.instantiate() as MenuRoot
	add_child(root)
	await wait_seconds(MenuRoot.TUTORIAL_DELAY + 0.2)
	var tours := _overlays(root, &"TutorialOverlay")
	assert_eq(tours.size(), 1, "the first run opens the tour")
	(tours[0].get_node("%SkipButton") as Button).pressed.emit()
	(root.lobby.get_node("%TopBar") as TopBar).left_pressed.emit()
	assert_eq(_overlays(root, &"SettingsScreen").size(), 1, "the gear opens the settings right after the tour")
	root.queue_free()


# ---------------------------------------------------------- tall phone ----

## 19.5:9: the lair keeps its design size at the bottom of its stage (the
## backdrop no longer scales up around monsters that keep theirs).
func test_the_lair_keeps_its_size_on_a_tall_phone() -> void:
	var holder := Control.new()
	holder.size = Vector2(720, 1560)
	add_child(holder)
	var lobby := LOBBY.instantiate() as LobbyScreen
	holder.add_child(lobby)
	lobby.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await wait_frames(1)
	var stage := lobby.get_node("%MonsterStage") as Control
	var backdrop := stage.get_node("Backdrop") as Control
	assert_true(stage.size.y > 700.0, "the stage grows with the screen")
	assert_near(backdrop.size.y, 540.0, 0.5, "the backdrop does not")
	assert_near(backdrop.position.y + backdrop.size.y, stage.size.y, 0.5, "it sits at the bottom")
	var grount := stage.get_node("Grount") as Control
	assert_near(stage.size.y - (grount.position.y + grount.size.y), 54.0, 0.5, "Grount stands where he stood")
	holder.queue_free()


# --------------------------------------------------------------- leaks ----

## A mob that dies as the match ends: its deferred release lands on a manager
## that already left the tree. It is freed, not parked out of reach.
func test_a_late_release_frees_the_mob() -> void:
	var mgr := make_spawn_manager(1, 60.0, Vector2(3000, 3000)) as SpawnManager
	var mob := (load("res://Scenes/NPCs/Mob/Mobs/Bat/Bat.tscn") as PackedScene).instantiate() as MobBase
	mob.pool_key = "res://Scenes/NPCs/Mob/Mobs/Bat/Bat.tscn"
	mob.spawn_manager = mgr
	remove_child(mgr)
	mgr.release_mob(mob)
	assert_eq(mgr.get_pooled_count(), 0, "not parked in a manager on its way out")
	assert_true(mob.is_queued_for_deletion(), "freed instead")
	mgr.queue_free()
	await wait_frames(1)
	assert_false(is_instance_valid(mob))
