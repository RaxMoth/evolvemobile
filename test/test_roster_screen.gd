extends TestCase

## RosterScreen, a side's collection: the roster's characters as a 4-column
## grid of M cards plus the one rumour card, the role filters of each side, the
## owned / total count, the staggered card intro, the taps (an owned character
## asks for its detail, the rumour shakes), refresh() re-reading the save, and
## its own wiring in RosterScreen.tscn. Tests that write the save run only in
## the isolated test user dir.

const ROSTER_SCREEN := preload("res://Scenes/UI/Screens/RosterScreen.tscn")
const HEROES := CharacterDef.HEROES
const MONSTER := CharacterDef.MONSTER
const MONSTER_FILTERS: Array[StringName] = [&"all", &"brute", &"stalker", &"swarm"]


func before_each() -> void:
	if is_isolated():
		PersistedData.wipe_progress(false)


func after_each() -> void:
	if is_isolated():
		PersistedData.wipe_progress(false)


func _screen(side: int) -> RosterScreen:
	var screen := ROSTER_SCREEN.instantiate() as RosterScreen
	screen.side = side
	if side == MONSTER:
		screen.filters = MONSTER_FILTERS.duplicate()
	add_child(screen)
	return screen


func _filter_buttons(screen: RosterScreen) -> Array[Button]:
	var out: Array[Button] = []
	for c in screen.get_node("%Filters").get_children():
		out.append(c as Button)
	return out


func test_hero_grid_is_the_roster_and_a_rumour() -> void:
	var screen := _screen(HEROES)
	assert_true(screen.cards().is_empty(), "nothing is built before the first open")
	screen.open()
	var heroes := GameManager.ROSTER.heroes
	var cards := screen.cards()
	assert_eq(cards.size(), heroes.size(), "one card per roster hero")
	for i in mini(cards.size(), heroes.size()):
		assert_eq(cards[i].character, heroes[i], "roster order")
		assert_eq(cards[i].size_preset, CharacterCard.CardSize.M)
		assert_true(cards[i].animated, "live rigs")
	var grid := screen.get_node("%Grid") as GridContainer
	assert_eq(grid.columns, 4)
	var rumour := screen.rumour_card()
	assert_true(rumour != null and rumour.rumour and not rumour.monster_side, "the heroes' rumour card")
	assert_eq(grid.get_child(grid.get_child_count() - 1), rumour, "the rumour comes last")
	assert_eq(grid.get_child_count(), heroes.size() + 1, "nothing else in the grid")
	var top_bar := screen.get_node("%TopBar") as TopBar
	assert_eq(top_bar.title, "Heroes")
	assert_true(top_bar.chip(PersistedData.STEEL).visible and not top_bar.chip(PersistedData.LEAVES).visible,
			"Gold and Steel")
	assert_eq((screen.get_node("%NavBar") as NavBar).active_tab, &"heroes")
	assert_eq((screen.get_node("%Count") as Label).text, "%d/%d" % [heroes.size(), heroes.size()])
	var buttons := _filter_buttons(screen)
	assert_eq(buttons.size(), 5, "all, tank, melee, ranged, support")
	for b in buttons:
		assert_true(b.icon != null, "%s has its role icon" % b.name)
		assert_eq(b.theme_type_variation, &"FilterTab")
	assert_true(buttons[0].button_pressed, "all is on")
	screen.queue_free()


func test_monster_grid() -> void:
	var screen := _screen(MONSTER)
	screen.open()
	var monsters := GameManager.ROSTER.monsters
	assert_eq(screen.cards().size(), monsters.size())
	for i in mini(screen.cards().size(), monsters.size()):
		assert_eq(screen.cards()[i].character, monsters[i])
	assert_true(screen.rumour_card().monster_side, "the lair's rumour card")
	var top_bar := screen.get_node("%TopBar") as TopBar
	assert_eq(top_bar.title, "Monsters")
	assert_true(top_bar.chip(PersistedData.LEAVES).visible and not top_bar.chip(PersistedData.STEEL).visible,
			"Gold and Leaves")
	assert_eq((screen.get_node("%NavBar") as NavBar).active_tab, &"monsters")
	var keys: Array[StringName] = []
	for b in _filter_buttons(screen):
		keys.append(StringName(String(b.name).trim_prefix("Filter_")))
	assert_eq(str(keys), str(MONSTER_FILTERS))
	screen.queue_free()


func test_filters_show_one_role() -> void:
	var screen := _screen(HEROES)
	screen.open()
	screen.set_filter(&"tank")
	for card in screen.cards():
		assert_eq(card.visible, card.character.role_filter == &"tank", "%s under tank" % card.character.get_display_name())
	assert_false(screen.rumour_card().visible, "the rumour only shows under all")
	assert_false((screen.get_node("%Empty") as CanvasItem).visible)
	(screen.get_node("%Filters/Filter_all") as BaseButton).pressed.emit()
	assert_eq(screen.active_filter, RosterScreen.ALL, "a filter button applies its role")
	for card in screen.cards():
		assert_true(card.visible)
	assert_true(screen.rumour_card().visible)
	screen.set_filter(&"wizard")
	assert_eq(screen.active_filter, RosterScreen.ALL, "an unknown role falls back to all")
	screen.queue_free()
	var lair := _screen(MONSTER)
	lair.open()
	lair.set_filter(&"stalker")
	assert_true((lair.get_node("%Empty") as CanvasItem).visible, "nobody in this role yet")
	assert_true((lair.get_node("%Filters/Filter_stalker") as BaseButton).button_pressed)
	lair.queue_free()


func test_cards_drop_in_one_after_another() -> void:
	var screen := _screen(HEROES)
	screen.open()
	await wait_frames(2)
	var grid := screen.get_node("%Grid")
	var first := grid.get_child(0) as Control
	var last := grid.get_child(grid.get_child_count() - 1) as Control
	assert_true(first.modulate.a > last.modulate.a, "the first card leads (%.2f > %.2f)" % [first.modulate.a, last.modulate.a])
	assert_true((last.get_node("%Frame") as Control).scale.x < 1.0, "the last one still grows")
	await wait_seconds(RosterScreen.CARD_STAGGER * grid.get_child_count() + CharacterCard.INTRO_TIME + 0.1)
	for c: Control in grid.get_children():
		assert_near(c.modulate.a, 1.0, 0.001, "%s has landed" % c.name)
		assert_near((c.get_node("%Frame") as Control).scale.x, 1.0, 0.001)
	screen.queue_free()


func test_taps() -> void:
	var screen := _screen(HEROES)
	screen.open()
	await wait_frames(1)  # the grid has placed its cards
	var events: Array[String] = []
	screen.character_requested.connect(func(def: CharacterDef) -> void: events.append("detail %s" % def.character_id()))
	screen.back_requested.connect(func() -> void: events.append("back"))
	screen.tab_selected.connect(func(tab_id: StringName) -> void: events.append("tab %s" % tab_id))
	var card := screen.cards()[0]
	card.pressed.emit()
	var rumour := screen.rumour_card()
	var x := rumour.position.x
	rumour.pressed.emit()
	await wait_frames(3)
	assert_true(absf(rumour.position.x - x) > 0.5, "the rumour shakes")
	await wait_seconds(RosterScreen.SHAKE_STEP * 6.0)
	assert_near(rumour.position.x, x, 0.01, "and settles back")
	(screen.get_node("%TopBar") as TopBar).left_pressed.emit()
	var nav := screen.get_node("%NavBar") as NavBar
	nav.tab(&"codex").chosen.emit(&"codex")
	assert_eq(nav.active_tab, &"heroes", "the roster keeps its own tab lit")
	assert_eq(", ".join(events), "detail %s, back, tab codex" % card.character.character_id())
	screen.queue_free()


func test_refresh_reads_the_save() -> void:
	if not require_isolated():
		return
	var screen := _screen(HEROES)
	screen.open()
	var card := screen.cards()[0]
	var def := card.character
	assert_eq(card.level, 1)
	PersistedData.add_hero_xp(def.character_id(), 250)
	PersistedData.add_currency(PersistedData.STEEL, 1000)
	screen.refresh()
	assert_eq(card.level, CharacterProgress.level(def), "the level from the new XP")
	assert_true(card.level > 1)
	assert_eq(card.xp_into, CharacterProgress.xp_into(def))
	assert_eq(card.upgrades, CharacterProgress.upgrades_ready(def), "the up-arrow count")
	assert_true(card.upgrades > 0, "Steel opens tier-1 nodes")
	screen.queue_free()


func test_wiring_lives_in_the_scene() -> void:
	var screen := ROSTER_SCREEN.instantiate() as RosterScreen
	for path: String in ["%TopBar", "%NavBar"]:
		var source := screen.get_node(path)
		var sig: StringName = &"left_pressed" if path == "%TopBar" else &"tab_selected"
		var links := source.get_signal_connection_list(sig)
		assert_eq(links.size(), 1, "%s.%s is wired" % [path, sig])
		for c: Dictionary in links:
			var flags: int = c["flags"]
			assert_true(flags & CONNECT_PERSIST != 0, "in RosterScreen.tscn")
	screen.free()
