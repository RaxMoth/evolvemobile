extends TestCase

## RosterScreen, a side's collection: the roster's characters as a centred
## grid of M cards (4 columns on a phone, more on a wider screen) plus the one
## rumour card, the role filters of each side (only roles that have a member),
## the
## owned / total count, the staggered card intro, the taps (an owned character
## asks for its detail, so does a locked monster with a price, for the unlock
## sheet; the rumour shakes), refresh() re-reading the save (a purchase too),
## and its own wiring in RosterScreen.tscn. Tests that write the save run only in
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
	assert_eq(RosterScreen.grid_columns(720.0, 32.0, 16.0), 4, "four columns on a phone")
	assert_eq(RosterScreen.grid_columns(600.0, 32.0, 16.0), 4, "never fewer")
	assert_eq(RosterScreen.grid_columns(960.0, 32.0, 16.0), 5, "a 3:4 tablet fits a fifth")
	assert_eq(grid.columns, RosterScreen.grid_columns(screen.size.x, 32.0, 16.0), "the grid fits the screen's width")
	assert_eq(grid.size_flags_horizontal, Control.SIZE_SHRINK_CENTER, "and sits in the middle")
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
	assert_eq(str(screen.shown_filters()), str([&"all", &"tank", &"melee", &"ranged"]),
			"no hero is filed under support: that filter gets no button")
	assert_eq(buttons.size(), screen.shown_filters().size())
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
	assert_eq(str(keys), str([&"all", &"brute", &"stalker"]), "no swarm monster yet: no swarm filter")
	for key in keys:
		if key != RosterScreen.ALL:
			screen.set_filter(key)
			assert_false((screen.get_node("%Empty") as CanvasItem).visible, "%s has a member" % key)
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
	assert_false((lair.get_node("%Empty") as CanvasItem).visible, "Nyxa stalks")
	for card in lair.cards():
		assert_eq(card.visible, card.character.character_id() == &"nyxa", "%s under stalker" % card.character.get_display_name())
	lair.set_filter(&"swarm")
	assert_eq(lair.active_filter, RosterScreen.ALL, "a role without a member is no filter")
	assert_false((lair.get_node("%Empty") as CanvasItem).visible)
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


## The lair's locked monsters are asked for like owned ones (MenuRoot opens
## the unlock sheet); a bought one counts as owned after a refresh.
func test_locked_monsters_ask_and_a_purchase_counts() -> void:
	if not require_isolated():
		return
	var screen := _screen(MONSTER)
	screen.open()
	await wait_frames(1)
	var count := screen.get_node("%Count") as Label
	assert_eq(count.text, "1/3", "Grount of three")
	var asked: Array[StringName] = []
	screen.character_requested.connect(func(def: CharacterDef) -> void: asked.append(def.character_id()))
	for card in screen.cards():
		assert_eq(card.unlocked, card.character.unlocked_by_default, "%s" % card.character.character_id())
		var x := card.position.x
		card.pressed.emit()
		await wait_frames(2)
		assert_near(card.position.x, x, 0.01, "%s does not shake" % card.character.character_id())
	assert_eq(str(asked), str(GameManager.ROSTER.monster_ids()), "every monster is asked for (Grount, Nyxa, Gorrak)")
	PersistedData.add_monster_xp(&"grount", 300)
	PersistedData.add_currency(PersistedData.LEAVES, 2500)
	assert_true(CharacterProgress.unlock(GameManager.ROSTER.find(&"nyxa")))
	screen.refresh()
	assert_eq(count.text, "2/3", "Nyxa is owned")
	assert_true(screen.cards()[1].unlocked and screen.cards()[1].character.character_id() == &"nyxa")
	assert_false(screen.cards()[2].unlocked, "Gorrak still locked")
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
