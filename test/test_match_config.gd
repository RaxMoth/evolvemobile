extends TestCase

## MatchConfig persistence + derived values; PreRoundSetup screen collects and emits.

const SCENE := "res://Scenes/UI/PreRoundSetup/PreRoundSetup.tscn"


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


func test_setup_screen_emits_and_persists_the_choice() -> void:
	if not require_isolated():
		return
	var screen := (load(SCENE) as PackedScene).instantiate() as PreRoundSetup
	add_child(screen)
	var got := [null]
	screen.start_requested.connect(func(cfg: MatchConfig) -> void: got[0] = cfg)
	screen.aggression_slider.value = 0.8
	screen.farming_slider.value = 0.2
	screen.formation_picker.select(int(MatchConfig.Formation.LINE))
	assert_eq(screen.aggression_value.text, "80%", "value label follows the slider")
	screen.get_node("%StartButton").pressed.emit()
	assert_true(got[0] != null)
	assert_near(got[0].aggression, 0.8)
	assert_near(got[0].farming, 0.2)
	assert_eq(got[0].formation, MatchConfig.Formation.LINE)
	assert_near(MatchConfig.from_settings().aggression, 0.8, 0.001, "persisted for next time")
	await wait_frames(2)
	assert_false(is_instance_valid(screen), "screen frees itself after Start")


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
