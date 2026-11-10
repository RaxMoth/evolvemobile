extends TestCase

## MatchConfig persistence + derived values; the PreRoundScreen (heroes side)
## shows the saved strategy, edits it through its dials and formation tiles,
## forecasts it in words, and persists and emits it on START HUNT.

const SCENE := preload("res://Scenes/UI/Screens/PreRoundScreen.tscn")


func before_each() -> void:
	if is_isolated():
		PersistedData.wipe_progress(false)


func test_derived_values_follow_the_sliders() -> void:
	var c := MatchConfig.new()
	c.aggression = 0.0
	assert_eq(c.auto_ult_min_enemies(), 4)
	assert_near(c.auto_ult_panic_hp_pct(), 0.15)
	c.aggression = 1.0
	assert_eq(c.auto_ult_min_enemies(), 1)
	assert_near(c.auto_ult_panic_hp_pct(), 0.4)
	c.farming = 1.0
	assert_near(c.priority_mob(), 120.0)
	c.exploration = 0.0
	assert_near(c.exploration_update_interval(), 5.0)
	assert_near(c.search_radius(), 300.0)
	c.formation = MatchConfig.Formation.LINE
	assert_near(c.formation_spread_px(), 160.0)


func test_roundtrip_through_settings() -> void:
	if not require_isolated():
		return
	var defaults := MatchConfig.from_settings()
	assert_near(defaults.aggression, 0.5)
	assert_eq(defaults.formation, MatchConfig.Formation.SPREAD)
	var c := MatchConfig.new()
	c.aggression = 0.9
	c.farming = 0.1
	c.exploration = 0.75
	c.formation = MatchConfig.Formation.TIGHT
	c.save_to_settings()
	var back := MatchConfig.from_settings()
	assert_near(back.aggression, 0.9)
	assert_near(back.farming, 0.1)
	assert_near(back.exploration, 0.75)
	assert_eq(back.formation, MatchConfig.Formation.TIGHT)


func _hero_screen() -> PreRoundScreen:
	var screen := SCENE.instantiate() as PreRoundScreen
	add_child(screen)
	screen.open(MatchRewards.Side.HEROES)
	return screen


func _row(screen: PreRoundScreen, row_name: String) -> StrategyRow:
	return screen.get_node("%" + row_name) as StrategyRow


func _tile(screen: PreRoundScreen, tile_name: String) -> ChoiceTile:
	return screen.get_node("%Formations/" + tile_name) as ChoiceTile


func test_screen_opens_on_the_saved_strategy() -> void:
	if not require_isolated():
		return
	var c := MatchConfig.new()
	c.aggression = 0.2
	c.farming = 0.65
	c.exploration = 1.0
	c.formation = MatchConfig.Formation.TIGHT
	c.save_to_settings()
	var screen := _hero_screen()
	assert_near(_row(screen, "Aggression").slider().value, 0.2)
	assert_eq(_row(screen, "Aggression").value_text(), "20%")
	assert_near(_row(screen, "Farming").value, 0.65)
	assert_near(_row(screen, "Exploration").value, 1.0)
	assert_true(_tile(screen, "Tight").button_pressed, "the saved formation is picked")
	assert_false(_tile(screen, "Spread").button_pressed, "and only it")
	assert_eq(_tile(screen, "Tight").get_node("%Frame").theme_type_variation, &"CharacterCardSelected")
	assert_eq(_tile(screen, "Line").get_node("%Frame").theme_type_variation, &"CharacterCard")
	assert_eq((_tile(screen, "Line").get_node("%Glyph") as FormationGlyph).formation, MatchConfig.Formation.LINE)
	# aggression 0.2: ult at round(lerp(4, 1, 0.2)) = 3 enemies, panic at 20%;
	# farming 0.65: mob camps 85; exploration 1.0: every 1.5 s, 600 px; tight: 60 px.
	assert_eq((screen.get_node("%ForecastUlt") as Label).text, "Ultimates fire at 3+ enemies, or when an ally drops below 20% HP.")
	assert_eq((screen.get_node("%ForecastFarm") as Label).text, "Mob camps weigh 85 against 100 for the monster.")
	assert_eq((screen.get_node("%ForecastScout") as Label).text, "New targets every 1.5 s, scanning 600 px ahead, 60 px apart.")
	screen.queue_free()


func test_screen_emits_and_persists_the_choice() -> void:
	if not require_isolated():
		return
	var screen := _hero_screen()
	var got: Array[MatchConfig] = []
	screen.start_requested.connect(func(cfg: MatchConfig) -> void: got.append(cfg))
	_row(screen, "Aggression").slider().value = 0.8
	_row(screen, "Farming").slider().value = 0.2
	_tile(screen, "Line").button_pressed = true
	assert_eq(_row(screen, "Aggression").value_text(), "80%", "the value follows the slider")
	assert_false(_tile(screen, "Spread").button_pressed, "one formation at a time")
	assert_eq((screen.get_node("%ForecastUlt") as Label).text, "Ultimates fire at 2+ enemies, or when an ally drops below 35% HP.",
			"the forecast follows the dials")
	assert_true((screen.get_node("%ForecastScout") as Label).text.ends_with("160 px apart."), "and the formation")
	assert_near(MatchConfig.from_settings().aggression, 0.5, 0.001, "nothing is saved before START")
	(screen.get_node("%HeroStart") as BaseButton).pressed.emit()
	assert_eq(got.size(), 1)
	assert_near(got[0].aggression, 0.8)
	assert_near(got[0].farming, 0.2)
	assert_eq(got[0].formation, MatchConfig.Formation.LINE)
	assert_eq(got[0].quarry_id, GameManager.next_quarry(), "the config names tonight's quarry")
	assert_near(MatchConfig.from_settings().aggression, 0.8, 0.001, "persisted for next time")
	assert_eq(MatchConfig.from_settings().formation, MatchConfig.Formation.LINE)
	await wait_frames(2)
	assert_true(is_instance_valid(screen), "a MenuRoot screen: it stays for the next hunt")
	screen.queue_free()


func test_back_cancels_without_saving() -> void:
	if not require_isolated():
		return
	var screen := _hero_screen()
	var cancels: Array[int] = [0]
	screen.cancelled.connect(func() -> void: cancels[0] += 1)
	_row(screen, "Aggression").slider().value = 1.0
	(screen.get_node("%TopBar") as TopBar).left_pressed.emit()
	assert_eq(cancels[0], 1)
	assert_near(MatchConfig.from_settings().aggression, 0.5, 0.001, "back keeps the saved strategy")
	screen.open(MatchRewards.Side.HEROES)
	assert_near(_row(screen, "Aggression").value, 0.5, 0.001, "and the next visit shows it")
	screen.queue_free()


func test_spawned_hero_uses_the_chosen_strategy() -> void:
	if not require_isolated():
		return
	var c := MatchConfig.new()
	c.aggression = 1.0
	c.farming = 1.0
	c.save_to_settings()
	var side_before: int = GameManager.chosen_side
	GameManager.chosen_side = MatchRewards.Side.HEROES
	var vlad := await spawn_entity("res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn", Vector2(0, 0))
	assert_eq(vlad.auto_ult_min_enemies, 1, "aggressive: ult on a single enemy")
	assert_near(vlad.auto_ult_panic_hp_pct, 0.4)
	assert_eq(vlad.priority_mob, 120, "farming: mobs outrank the default")
	GameManager.chosen_side = MatchRewards.Side.MONSTER
	var ai_vlad := await spawn_entity("res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn", Vector2(3000, 0))
	assert_eq(ai_vlad.auto_ult_min_enemies, 3, "AI-controlled heroes ignore the player's sliders (neutral 0.5 → 3)")
	GameManager.chosen_side = side_before
	vlad.queue_free()
	ai_vlad.queue_free()
