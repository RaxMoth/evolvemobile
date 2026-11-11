extends TestCase

## The CodexScreen (README "Codex"): the guide (the tutorial's chapters as
## cards, the replays), the monster pages in the order the quarries were met
## (PersistedData [codex] monsters) with their field notes, stages,
## counterplay and abilities, the unmet monsters as locked pages, the hero
## pages, the unseen-pages count behind the nav bar's Codex dot, and MenuRoot
## opening it from the nav bar and replaying the guide. Tests that write the
## save run only in the isolated test user dir.

const SCENE := preload("res://Scenes/UI/Screens/CodexScreen.tscn")
const MENU_ROOT := preload("res://Scenes/UI/Screens/MenuRoot.tscn")

var _world_before: PackedScene = null


func before_each() -> void:
	_world_before = GameManager.world_scene
	if GameManager.world_scene == null:
		GameManager.world_scene = PackedScene.new()
	if is_isolated():
		PersistedData.wipe_progress(false)
		TutorialOverlay.mark_seen()


func after_each() -> void:
	GameManager.world_scene = _world_before


func _codex() -> CodexScreen:
	var codex := SCENE.instantiate() as CodexScreen
	add_child(codex)
	codex.open()
	return codex


func _ids(entries: Array[CodexEntry]) -> Array[StringName]:
	var out: Array[StringName] = []
	for e in entries:
		out.append(e.character.character_id())
	return out


func test_monster_pages_follow_the_order_they_were_met() -> void:
	if not require_isolated():
		return
	PersistedData.add_codex_entry(PersistedData.CODEX_MONSTERS, &"gorrak")
	PersistedData.add_codex_entry(PersistedData.CODEX_MONSTERS, &"grount")
	var codex := _codex()
	var entries := codex.monster_entries()
	assert_eq(entries.size(), GameManager.ROSTER.monsters.size(), "a page per roster monster")
	var order: Array[StringName] = [&"gorrak", &"grount", &"nyxa"]
	assert_eq(_ids(entries), order, "met first, in the order met, then the rest")
	assert_true(entries[0].met and entries[1].met)
	assert_false(entries[2].met, "Nyxa has not been met")
	assert_eq((entries[2].get_node("%Name") as Label).text, "???")
	assert_eq(entries[2].theme_type_variation, &"CharacterCardLocked")
	assert_true((entries[2].get_node("%Tagline") as Label).text.begins_with("Not met yet"), "and says when it turns up")
	assert_false((entries[2].get_node("%AbilitiesBox") as Control).visible, "a locked page tells nothing else")
	var grount := entries[1]
	var def := GameManager.ROSTER.find(&"grount")
	assert_eq((grount.get_node("%Name") as Label).text, def.get_display_name())
	assert_eq((grount.get_node("%Notes") as Label).text, def.codex_notes, "field notes")
	assert_false(def.codex_notes.is_empty())
	assert_eq(grount.stage_texts(), PackedStringArray(["I · Bullcalf", "II · Rampager", "III · Alpha Bull"]), "the stage names")
	assert_eq((grount.get_node("%Counter") as Label).text, def.tip, "the counterplay")
	assert_true((grount.get_node("%CounterBox") as Control).visible)
	var names := PackedStringArray()
	for ability in def.abilities():
		names.append(ability.ability_name)
	assert_eq(grount.ability_names(), names, "every ability, in menu order")
	assert_eq((codex.get_node("%MetCount") as Label).text, "Beasts met 2 / %d" % GameManager.ROSTER.monsters.size())
	codex.queue_free()


func test_hero_pages_and_the_guide() -> void:
	if not require_isolated():
		return
	var codex := _codex()
	assert_eq(codex.hero_entries().size(), GameManager.ROSTER.heroes.size(), "a page per hero")
	for entry in codex.hero_entries():
		assert_true(entry.met, "heroes are always open")
		assert_false((entry.get_node("%StagesBox") as Control).visible, "heroes do not evolve")
		assert_eq(entry.ability_names().size(), 4, "%s: four abilities" % entry.character.character_id())
		assert_false(entry.character.codex_notes.is_empty(), "%s has field notes" % entry.character.character_id())
	var camp := PackedStringArray()
	for step in TutorialOverlay.LOBBY_STEPS:
		camp.append(String(step.get("title")))
	assert_eq(codex.guide_titles(TutorialOverlay.CHAPTER_LOBBY), camp, "the camp tour as cards")
	assert_eq(codex.guide_titles(TutorialOverlay.CHAPTER_HUD).size(), TutorialOverlay.HUD_STEPS.size(), "the hunt tips too")
	var replay_hunt := codex.get_node("%ReplayHunt") as Button
	assert_true(replay_hunt.disabled, "the hunt tips are still to come")
	TutorialOverlay.mark_seen(TutorialOverlay.CHAPTER_HUD)
	codex.open()
	assert_false(replay_hunt.disabled, "seen: they can be switched on again")
	codex.show_page(CodexScreen.PAGE_GUIDE)
	var asked: Array[StringName] = []
	codex.guide_requested.connect(func(chapter: StringName) -> void: asked.append(chapter))
	(codex.get_node("Scroll/Margin/Pages/GuidePage/ReplayCamp") as Button).pressed.emit()
	(codex.get_node("Scroll/Margin/Pages/GuidePage/ReplayHunt") as Button).pressed.emit()
	var both: Array[StringName] = [TutorialOverlay.CHAPTER_LOBBY, TutorialOverlay.CHAPTER_HUD]
	assert_eq(asked, both)
	assert_true(replay_hunt.disabled, "pressed: on for the next hunt")
	(codex.get_node("%HeroesTab") as Button).pressed.emit()
	assert_eq(codex.page, CodexScreen.PAGE_HEROES)
	assert_true((codex.get_node("%HeroesPage") as Control).visible)
	assert_false((codex.get_node("%GuidePage") as Control).visible, "one page at a time")
	codex.queue_free()


func test_new_pages_light_the_dot_until_the_codex_opens() -> void:
	if not require_isolated():
		return
	assert_eq(CodexScreen.unseen_monsters(), 0)
	PersistedData.add_codex_entry(PersistedData.CODEX_MONSTERS, &"grount")
	assert_eq(CodexScreen.unseen_monsters(), 1, "a first sighting is news")
	var codex := _codex()
	assert_eq(codex.page, CodexScreen.PAGE_MONSTERS, "the Codex opens on the new page")
	assert_eq(CodexScreen.unseen_monsters(), 0, "and it is seen")
	codex.show_page(CodexScreen.PAGE_GUIDE)
	codex.open()
	assert_eq(codex.page, CodexScreen.PAGE_GUIDE, "nothing new: the page stays")
	codex.queue_free()


func test_menu_root_opens_the_codex_and_replays_the_guide() -> void:
	if not require_isolated():
		return
	PersistedData.add_codex_entry(PersistedData.CODEX_MONSTERS, &"grount")
	var root := MENU_ROOT.instantiate() as MenuRoot
	add_child(root)
	await wait_frames(1)
	var nav := root.lobby.get_node("%NavBar") as NavBar
	assert_true(nav.notify_tabs.has(&"codex"), "the Codex dot: a page not seen yet")
	nav.tab(&"codex").chosen.emit(&"codex")
	assert_eq(root.top(), root.codex, "the nav bar's Codex opens the Codex screen")
	assert_false(nav.notify_tabs.has(&"codex"), "opening it clears the dot")
	await wait_seconds(MenuRoot.SLIDE_TIME + 0.1)
	root.codex.guide_requested.emit(TutorialOverlay.CHAPTER_HUD)
	assert_false(TutorialOverlay.has_been_seen(TutorialOverlay.CHAPTER_HUD), "the hunt tips play again next match")
	assert_eq(root.top(), root.codex, "and the Codex stays")
	root.codex.guide_requested.emit(TutorialOverlay.CHAPTER_LOBBY)
	await wait_seconds(MenuRoot.SLIDE_TIME * 2 + 0.1)
	assert_eq(root.top(), root.lobby, "the camp tour plays at home")
	var tours := 0
	for child in root.get_children():
		if child is TutorialOverlay and not child.is_queued_for_deletion():
			tours += 1
	assert_eq(tours, 1, "over the lobby")
	root.queue_free()
