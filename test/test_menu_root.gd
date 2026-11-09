extends TestCase

## MenuRoot (the main scene) and its home screen, the LobbyScreen: every screen
## signal connected scene-side, push / pop with the slide and ui_cancel as
## back, the lobby's side choice (dim, frame, HUNT pop, cheer, nav glow) and
## its requests, the locked teasers in the lair, the chosen side persisted
## through GameManager, the first-run tutorial, the rosters, Growth and the
## character detail each request opens (nav tabs switch, cards push), the
## purchases MenuRoot makes for the detail screen and the refresh after them,
## and the old overlays that still stand in for the pre-round and settings
## screens. Tests that write the save run only in the isolated test user dir.

const MENU_ROOT_PATH := "res://Scenes/UI/Screens/MenuRoot.tscn"
const MENU_ROOT := preload("res://Scenes/UI/Screens/MenuRoot.tscn")
const LOBBY := preload("res://Scenes/UI/Screens/LobbyScreen.tscn")
const HEROES := MatchRewards.Side.HEROES
const MONSTER := MatchRewards.Side.MONSTER

var _side_before: int = HEROES
var _world_before: PackedScene = null


func before_each() -> void:
	_side_before = GameManager.chosen_side
	# A MenuRoot in the tree starts the background World load unless the
	# session already holds the scene: a stand-in keeps the suite from loading
	# the whole match.
	_world_before = GameManager.world_scene
	if GameManager.world_scene == null:
		GameManager.world_scene = PackedScene.new()
	if is_isolated():
		PersistedData.wipe_progress(false)
		TutorialOverlay.mark_seen()


func after_each() -> void:
	GameManager.world_scene = _world_before
	GameManager.choose_side(_side_before, false)


func _menu_root() -> MenuRoot:
	var root := MENU_ROOT.instantiate() as MenuRoot
	add_child(root)
	await wait_frames(1)
	return root


func _lobby() -> LobbyScreen:
	var lobby := LOBBY.instantiate() as LobbyScreen
	add_child(lobby)
	return lobby


func _press_back(root: Control) -> void:
	var back := InputEventAction.new()
	back.action = &"ui_cancel"
	back.pressed = true
	root.get_viewport().push_input(back)


func _overlays(root: Node, script_class: StringName) -> Array[Node]:
	var out: Array[Node] = []
	for child in root.get_children():
		var script := child.get_script() as Script
		if script != null and script.get_global_name() == script_class and not child.is_queued_for_deletion():
			out.append(child)
	return out


# ------------------------------------------------------------ wiring ----

func test_every_screen_signal_is_connected_scene_side() -> void:
	var state := MENU_ROOT.get_state()
	var root := MENU_ROOT.instantiate() as MenuRoot
	var screens := root.get_node("Screens")
	assert_true(screens.get_child_count() > 0, "MenuRoot instances its screens")
	assert_eq(root.lobby, screens.get_node("LobbyScreen"), "the lobby is the home screen")
	for screen in screens.get_children():
		var path := String(root.get_path_to(screen))
		var signals := (screen.get_script() as Script).get_script_signal_list()
		assert_true(signals.size() > 0, "%s declares its requests" % path)
		for sig: Dictionary in signals:
			var sig_name: StringName = sig["name"]
			var wired := 0
			for i in state.get_connection_count():
				if String(state.get_connection_source(i)) == path and state.get_connection_signal(i) == sig_name:
					wired += 1
					assert_eq(String(state.get_connection_target(i)), ".", "%s.%s goes to MenuRoot" % [path, sig_name])
					assert_true(root.has_method(state.get_connection_method(i)), "MenuRoot has %s" % state.get_connection_method(i))
			assert_eq(wired, 1, "%s.%s is connected once in MenuRoot.tscn" % [path, sig_name])
			for c: Dictionary in screen.get_signal_connection_list(sig_name):
				var flags: int = c["flags"]
				assert_true(flags & CONNECT_PERSIST != 0, "%s.%s has no code connection" % [path, sig_name])
	root.free()


func test_lobby_wiring_lives_in_its_scene() -> void:
	var lobby := LOBBY.instantiate() as LobbyScreen
	var cast := 0
	for stage: Control in [lobby.get_node("%HeroStage"), lobby.get_node("%MonsterStage")]:
		for character in lobby.stage_characters(stage):
			cast += 1
			var links := character.character_pressed.get_connections()
			assert_eq(links.size(), 1, "%s reports its taps" % character.name)
			for c: Dictionary in links:
				var flags: int = c["flags"]
				assert_true(flags & CONNECT_PERSIST != 0, "%s is wired in LobbyScreen.tscn" % character.name)
	assert_eq(cast, GameManager.ROSTER.heroes.size() + 3, "four heroes, Grount and two teasers")
	for button: String in ["%HeroStage", "%MonsterStage", "%HeroHunt", "%MonsterHunt", "HeroRow/HeroRoster", "MonsterRow/MonsterRoster"]:
		assert_eq((lobby.get_node(button) as BaseButton).pressed.get_connections().size(), 1, "%s is wired" % button)
	lobby.free()


func test_main_scene_is_the_menu_root() -> void:
	var main := String(ProjectSettings.get_setting("application/run/main_scene", ""))
	if main.begins_with("uid://"):
		main = ResourceUID.get_id_path(ResourceUID.text_to_id(main))
	assert_eq(main, MENU_ROOT_PATH)
	assert_true(ResourceLoader.exists("res://Scenes/UI/MainMenu/MainMenu.tscn"), "the old menu stays until Phase 8")


# -------------------------------------------------------- navigation ----

func test_push_slides_in_and_back_pops() -> void:
	var root := await _menu_root()
	var lobby := root.lobby
	assert_eq(root.top(), lobby)
	assert_true(lobby.visible)
	var screen := Control.new()
	screen.name = "Probe"
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.visible = false
	root.get_node("%Screens").add_child(screen)
	root.push(screen)
	assert_eq(root.top(), screen)
	assert_true(screen.visible)
	assert_near(screen.position.x, root.size.x, 0.5, "slides in from the right edge")
	await wait_frames(3)
	assert_true(lobby.visible, "the screen below stays drawn during the slide")
	assert_true(lobby.modulate.r < 1.0, "and darkens")
	assert_true(screen.position.x < root.size.x)
	await wait_seconds(MenuRoot.SLIDE_TIME + 0.1)
	assert_near(screen.position.x, 0.0, 0.01, "settled in place")
	assert_false(lobby.visible, "a covered screen hides once the slide settles")
	_press_back(root)
	assert_eq(root.top(), lobby, "ui_cancel pops")
	assert_true(lobby.visible, "the screen below shows again at once")
	await wait_seconds(MenuRoot.SLIDE_TIME + 0.1)
	assert_false(screen.visible, "the popped screen hides")
	assert_near(screen.position.x, 0.0, 0.01, "and rests in place for its next push")
	assert_eq(lobby.modulate, Color.WHITE)
	_press_back(root)
	assert_eq(root.top(), lobby, "the home screen never pops")
	assert_true(lobby.visible)
	root.push(screen)
	root.pop()
	assert_eq(root.top(), lobby, "a pop during the slide lands it first")
	root.queue_free()


func test_every_button_clicks() -> void:
	var root := await _menu_root()
	var buttons := 0
	for node in root.find_children("*", "BaseButton", true, false):
		buttons += 1
		assert_true((node as BaseButton).pressed.is_connected(AudioManager.play_ui_click), "%s clicks" % node.name)
	assert_true(buttons >= 18, "stages, characters, plaques, HUNT, gear and nav tabs")
	var later := Button.new()
	root.lobby.add_child(later)
	assert_true(later.pressed.is_connected(AudioManager.play_ui_click), "a button added later clicks too")
	root.queue_free()


# -------------------------------------------------------------- lobby ----

func test_choosing_a_side_dims_the_other_and_cheers() -> void:
	var lobby := _lobby()
	var hero_stage := lobby.get_node("%HeroStage") as Control
	var monster_stage := lobby.get_node("%MonsterStage") as Control
	var nav := lobby.get_node("%NavBar") as NavBar
	lobby.show_side(HEROES)
	assert_true(lobby.get_node("%HeroFrame").visible)
	assert_false(lobby.get_node("%MonsterFrame").visible)
	assert_true(lobby.get_node("%HeroHunt").visible)
	assert_false(lobby.get_node("%MonsterHunt").visible)
	assert_eq(hero_stage.modulate, Color.WHITE)
	assert_eq(monster_stage.modulate, UiPalette.UNCHOSEN_SIDE_MODULATE)
	assert_false(nav.monster_side)
	var reported: Array[int] = []
	lobby.side_chosen.connect(func(side: int) -> void: reported.append(side))
	lobby.choose(HEROES)
	assert_eq(reported.size(), 0, "the chosen side changes nothing")
	lobby.choose(MONSTER)
	assert_eq(str(reported), str([MONSTER]))
	assert_eq(lobby.chosen_side, MONSTER)
	assert_false(lobby.get_node("%HeroFrame").visible)
	assert_true(lobby.get_node("%MonsterFrame").visible, "FrameMonster appears")
	assert_false(lobby.get_node("%HeroHunt").visible)
	var cta := lobby.get_node("%MonsterHunt") as Control
	assert_true(cta.visible)
	assert_near(cta.scale.x, LobbyScreen.CTA_POP_FROM.x, 0.01, "the HUNT button pops from small")
	assert_true(nav.monster_side, "the arch glows crimson")
	var cast := lobby.stage_characters(monster_stage)
	await wait_frames(2)
	assert_true((cast[0].get_node("%Hop") as Control).position.y < -1.0, "the first monster hops at once")
	assert_near((cast[2].get_node("%Hop") as Control).position.y, 0.0, 0.01, "the third waits for its stagger")
	await wait_seconds(LobbyScreen.CTA_POP_TIME + 0.1)
	assert_eq(monster_stage.modulate, Color.WHITE)
	assert_eq(hero_stage.modulate, UiPalette.UNCHOSEN_SIDE_MODULATE)
	assert_near(cta.scale.x, 1.0, 0.001)
	lobby.show_side(7)
	assert_eq(lobby.chosen_side, HEROES, "an unknown side reads as the heroes")
	lobby.queue_free()


func test_side_tap_chooses_or_opens_the_roster() -> void:
	var lobby := _lobby()
	lobby.show_side(HEROES)
	var rosters: Array[int] = []
	var sides: Array[int] = []
	lobby.roster_requested.connect(func(side: int) -> void: rosters.append(side))
	lobby.side_chosen.connect(func(side: int) -> void: sides.append(side))
	(lobby.get_node("%MonsterStage") as BaseButton).pressed.emit()
	assert_eq(str(sides), str([MONSTER]), "a stage tap chooses its side")
	assert_eq(rosters.size(), 0, "and stays in the lobby")
	lobby.side_tap_opens_roster = true
	(lobby.get_node("%HeroStage") as BaseButton).pressed.emit()
	assert_eq(str(sides), str([MONSTER, HEROES]))
	assert_eq(str(rosters), str([HEROES]), "side_tap_opens_roster opens that side's roster")
	lobby.queue_free()


func test_lobby_requests() -> void:
	var lobby := _lobby()
	lobby.show_side(HEROES)
	var events: Array[String] = []
	lobby.hunt_requested.connect(func(side: int) -> void: events.append("hunt %d" % side))
	lobby.roster_requested.connect(func(side: int) -> void: events.append("roster %d" % side))
	lobby.settings_requested.connect(func() -> void: events.append("settings"))
	lobby.tab_selected.connect(func(tab_id: StringName) -> void: events.append("tab %s" % tab_id))
	lobby.character_requested.connect(func(def: CharacterDef) -> void: events.append("character %s" % def.get_display_name()))
	(lobby.get_node("%HeroHunt") as BaseButton).pressed.emit()
	(lobby.get_node("HeroRow/HeroRoster") as BaseButton).pressed.emit()
	(lobby.get_node("MonsterRow/MonsterRoster") as BaseButton).pressed.emit()
	(lobby.get_node("%TopBar") as TopBar).left_pressed.emit()
	var nav := lobby.get_node("%NavBar") as NavBar
	nav.tab(&"codex").chosen.emit(&"codex")
	assert_eq(nav.active_tab, LobbyScreen.HOME_TAB, "the lobby's bar keeps HUNT lit")
	assert_true(nav.tab(LobbyScreen.HOME_TAB).button_pressed)
	(lobby.get_node("MonsterStage/Grount") as BaseButton).pressed.emit()
	assert_eq(lobby.chosen_side, MONSTER, "tapping a character chooses its side")
	(lobby.get_node("%MonsterHunt") as BaseButton).pressed.emit()
	assert_eq(", ".join(events), "hunt 0, roster 0, roster 1, settings, tab codex, character Grount, hunt 1")
	lobby.queue_free()


func test_lair_teasers_are_locked_and_the_cast_is_the_roster() -> void:
	var lobby := _lobby()
	var heroes: Array[CharacterDef] = []
	for character in lobby.stage_characters(lobby.get_node("%HeroStage") as Control):
		heroes.append(character.character)
		assert_false((character.get_node("%Rig") as RigView).silhouette, "%s stands in colour" % character.name)
	for def in GameManager.ROSTER.heroes:
		assert_eq(heroes.count(def), 1, "%s stands at the campfire once" % def.get_display_name())
	var grount := lobby.get_node("MonsterStage/Grount") as StageCharacter
	assert_eq(grount.character, GameManager.ROSTER.find(&"grount"), "Grount is the roster's def")
	assert_false((grount.get_node("%Lock") as CanvasItem).visible)
	for teaser: String in ["Nyxa", "Gorrak"]:
		var character := lobby.get_node("MonsterStage/" + teaser) as StageCharacter
		assert_eq(character.character.get_display_name(), teaser)
		assert_eq(character.character.side, CharacterDef.MONSTER)
		assert_false(GameManager.ROSTER.monsters.has(character.character), "%s is not playable yet" % teaser)
		assert_false(CharacterProgress.is_unlocked(character.character))
		assert_true((character.get_node("%Rig") as RigView).silhouette, "%s is a silhouette" % teaser)
		assert_true((character.get_node("%Lock") as CanvasItem).visible, "%s wears the padlock" % teaser)
		assert_true((character.get_node("%Rig") as RigView).rig != null, "over its built rig")
	lobby.queue_free()


# ------------------------------------------------------- menu root ----

func test_chosen_side_is_persisted_and_restored() -> void:
	if not require_isolated():
		return
	GameManager.choose_side(HEROES)
	var root := await _menu_root()
	assert_eq(root.lobby.chosen_side, HEROES)
	root.lobby.choose(MONSTER)
	assert_eq(GameManager.chosen_side, MONSTER, "MenuRoot hands the choice to GameManager")
	PersistedData.load_data()  # re-read from disk: choose_side must have saved
	assert_eq(int(PersistedData.get_setting(GameManager.SETTING_CHOSEN_SIDE, -1)), MONSTER, "saved")
	root.queue_free()
	await wait_frames(1)
	var again := await _menu_root()
	assert_eq(again.lobby.chosen_side, MONSTER, "the next visit opens on the saved side")
	assert_true(again.lobby.get_node("%MonsterFrame").visible)
	assert_eq((again.lobby.get_node("%HeroStage") as Control).modulate, UiPalette.UNCHOSEN_SIDE_MODULATE, "without the animation")
	again.queue_free()
	GameManager.choose_side(5, false)
	assert_eq(GameManager.chosen_side, HEROES, "a corrupt side reads as the heroes")


func test_first_run_opens_the_tutorial() -> void:
	if not require_isolated():
		return
	PersistedData.wipe_progress(false)
	var root := await _menu_root()
	assert_eq(_overlays(root, &"TutorialOverlay").size(), 0, "not before the intro has settled")
	await wait_seconds(MenuRoot.TUTORIAL_DELAY + 0.1)
	assert_eq(_overlays(root, &"TutorialOverlay").size(), 1, "the first run walks the player through")
	root.queue_free()
	await wait_frames(1)
	TutorialOverlay.mark_seen()
	var again := await _menu_root()
	await wait_seconds(MenuRoot.TUTORIAL_DELAY + 0.1)
	assert_eq(_overlays(again, &"TutorialOverlay").size(), 0, "never again once seen")
	again.queue_free()


func _settle() -> void:
	await wait_seconds(MenuRoot.SLIDE_TIME + 0.1)


func test_requests_open_their_screens() -> void:
	if not require_isolated():
		return
	GameManager.choose_side(HEROES, false)
	var root := await _menu_root()
	var lobby := root.lobby
	(lobby.get_node("%HeroHunt") as BaseButton).pressed.emit()
	assert_eq(_overlays(root, &"PreRoundSetup").size(), 1, "HUNT (heroes) opens the strategy screen")
	lobby.hunt_requested.emit(HEROES)
	assert_eq(_overlays(root, &"PreRoundSetup").size(), 1, "once")
	_overlays(root, &"PreRoundSetup")[0].queue_free()
	await wait_frames(1)
	(lobby.get_node("HeroRow/HeroRoster") as BaseButton).pressed.emit()
	assert_eq(root.top(), root.hero_roster, "the HEROES plaque opens the hero roster")
	assert_eq(root.hero_roster.cards().size(), GameManager.ROSTER.heroes.size(), "built when it opens")
	await _settle()
	root.hero_roster.tab_selected.emit(&"monsters")
	assert_eq(root.top(), root.monster_roster, "a nav tab switches to its screen")
	assert_eq(root._stack.size(), 2, "right above home: nav tabs do not stack up")
	await _settle()
	assert_false(root.hero_roster.visible, "the screen it replaced hides")
	root.monster_roster.tab_selected.emit(&"growth")
	assert_eq(root.top(), root.growth)
	assert_eq(root.growth.tree_id, MetaSkillManager.TREE_HERO_BASE, "Growth is the chosen side's account tree")
	assert_eq(root.growth.mode, CharacterDetail.Mode.TREE)
	await _settle()
	_press_back(root)
	assert_eq(root.top(), lobby, "back from a tab screen returns home")
	await _settle()
	lobby.choose(MONSTER)
	lobby.tab_selected.emit(&"growth")
	assert_eq(root.growth.tree_id, MetaSkillManager.TREE_MONSTER_BASE, "Growth follows the side")
	await _settle()
	root.growth.tab_selected.emit(&"codex")
	assert_eq(_overlays(root, &"TutorialOverlay").size(), 1, "Codex opens the guide")
	assert_eq(root.top(), root.growth, "over the shown screen")
	root.queue_free()


func test_the_detail_opens_buys_and_goes_back() -> void:
	if not require_isolated():
		return
	GameManager.choose_side(HEROES, false)
	var root := await _menu_root()
	var tree_id := MetaSkillManager.monster_tree_id(&"grount")
	root.lobby.roster_requested.emit(MONSTER)
	await _settle()
	var card := root.monster_roster.cards()[0]
	card.pressed.emit()
	assert_eq(root.top(), root.detail, "a card opens its character")
	assert_eq(root.detail.character, card.character)
	assert_eq(root._stack.size(), 3, "over the roster")
	await _settle()
	PersistedData.add_currency(PersistedData.LEAVES, 40)  # Heavy Horns, rank 1
	await wait_frames(1)
	assert_true(card.upgrades > 0, "the roster under the detail refreshed on the currency change")
	root.detail.set_mode(CharacterDetail.Mode.TREE)
	root.detail.tree_view().select(&"g1_dmg")
	(root.detail.get_node("%Upgrade") as BaseButton).pressed.emit()
	assert_true(MetaSkillManager.is_unlocked(tree_id, &"g1_dmg"), "MenuRoot buys the node")
	assert_eq(PersistedData.get_currency(PersistedData.LEAVES), 0)
	await wait_frames(1)
	assert_eq(root.detail.tree_view().button(&"g1_dmg").state, UxTreeModel.NodeState.OWNED, "the detail refreshed (rank 1 of 5)")
	assert_eq(card.upgrades, 0, "and the card")
	root.detail.back_requested.emit()
	assert_eq(root.top(), root.monster_roster, "back to the roster")
	await _settle()
	card.pressed.emit()
	await _settle()
	root.detail.tab_selected.emit(&"monsters")
	assert_eq(root.top(), root.monster_roster, "the detail's own tab returns to the roster below it")
	assert_eq(root._stack.size(), 2)
	await _settle()
	root.monster_roster.back_requested.emit()
	await _settle()
	(root.lobby.get_node("HeroStage/Irelia") as BaseButton).pressed.emit()
	assert_eq(root.top(), root.detail, "tapping a character in the lobby opens it")
	assert_eq(root.detail.character, GameManager.ROSTER.find(&"irelia"))
	assert_eq(root.detail.mode, CharacterDetail.Mode.OVERVIEW)
	assert_eq(root._stack.size(), 2, "right over the lobby")
	await _settle()
	root.detail.back_requested.emit()
	await _settle()
	(root.lobby.get_node("MonsterStage/Nyxa") as BaseButton).pressed.emit()
	assert_eq(root.top(), root.lobby, "a locked teaser has no detail yet")
	root.queue_free()
