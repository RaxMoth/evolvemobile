extends TestCase

## README "Hero Leveling (In-Round)": shared mob XP within 800 px (100% → 50% by
## distance), ~80 XP per level, level growth reaches ability damage; the
## monster's kill XP (xp_value) never goes to heroes.

const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const BAT := "res://Scenes/NPCs/Mob/Mobs/Bat/Bat.tscn"
const HOG := "res://Scenes/NPCs/Mob/Mobs/Hog/Hog.tscn"


func test_mob_kill_xp_is_shared_by_distance_and_levels_heroes() -> void:
	var near := await spawn_entity(VLAD, Vector2(0, 0))
	var mid := await spawn_entity(VLAD, Vector2(400, 0))
	var far := await spawn_entity(VLAD, Vector2(5000, 0))
	var hog := await spawn_entity(HOG, Vector2(0, 0))
	EventBus.deal_damage(near, hog, 9999.0)
	await wait_frames(2)
	var s_near := near.get_node("HeroStats") as HeroStatsComponent
	var s_mid := mid.get_node("HeroStats") as HeroStatsComponent
	var s_far := far.get_node("HeroStats") as HeroStatsComponent
	assert_near(s_near.current_xp, 15.0, 0.01, "full Hog hero XP at the kill")
	assert_near(s_mid.current_xp, 15.0 * 0.75, 0.01, "400 px of 800 → 75%")
	assert_eq(s_far.current_xp, 0.0, "outside the 800 px radius")
	for n in [near, mid, far]:
		n.queue_free()


func test_level_up_raises_hp_and_ability_damage() -> void:
	var vlad := await spawn_entity(VLAD, Vector2(0, 0))
	var stats := vlad.get_node("HeroStats") as HeroStatsComponent
	var abilities := vlad.get_node("AbilitySystem") as AbilitySystem
	var hp1: float = stats.get_max_health()
	var dmg1: float = abilities.get_damage_multiplier()
	var levels := [0]
	stats.leveled_up.connect(func(_l: int) -> void: levels[0] += 1)
	vlad.gain_xp(170.0)  # 2 levels (80 each) + 10 left over
	assert_eq(stats.level, 3)
	assert_eq(levels[0], 2)
	assert_near(stats.current_xp, 10.0, 0.01)
	assert_true(stats.get_max_health() > hp1, "health_per_level applied")
	assert_true(abilities.get_damage_multiplier() > dmg1, "damage_per_level reaches abilities")
	assert_near(stats.get_current_health(), stats.get_max_health(), 0.01, "gained max HP is healed")
	assert_eq(vlad.lv_label.text, "3", "level label follows")
	vlad.queue_free()


func test_monster_kill_xp_never_goes_to_heroes() -> void:
	var vlad := await spawn_entity(VLAD, Vector2(0, 0))
	var bat := await spawn_entity(BAT, Vector2(30, 0))
	EventBus.deal_damage(vlad, bat, 9999.0)
	await wait_frames(2)
	var stats := vlad.get_node("HeroStats") as HeroStatsComponent
	# 30 px away → ~98% of the Bat's 6 hero XP; never the monster's xp_value (8).
	assert_true(stats.current_xp > 5.5 and stats.current_xp <= 6.0, "got %.3f" % stats.current_xp)
	vlad.queue_free()


func test_heroes_call_teammates_into_a_fight() -> void:
	var a := await spawn_entity(VLAD, Vector2(0, 0))
	var b := await spawn_entity(VLAD, Vector2(300, 0))
	var c := await spawn_entity(VLAD, Vector2(2000, 0))
	var hog := await spawn_entity(HOG, Vector2(4000, 4000))
	a._broadcast_aggro(hog)
	assert_true(b.target_entity == hog, "teammate within 500 px joins")
	assert_eq(active_state_of(b), "Approach")
	assert_true(c.target_entity == null, "teammate 2000 px away is not pulled")
	for n in [a, b, c, hog]:
		n.queue_free()


func test_summoned_teammate_keeps_the_target_until_it_arrives() -> void:
	# Regression: re-evaluation dropped any target outside the hero's own 172 px
	# detection circle, so the call-for-help was undone 0.5 s later.
	var a := await spawn_entity(VLAD, Vector2(0, 0))
	var b := await spawn_entity(VLAD, Vector2(380, 0))
	var hog := await spawn_entity(HOG, Vector2(-60, 0))
	a._broadcast_aggro(hog)
	assert_true(b.target_entity == hog)
	var start: float = b.global_position.distance_to(hog.global_position)
	await wait_seconds(1.5)
	assert_true(b.target_entity == hog, "still pursuing after several re-evaluations")
	# (No navigation mesh in the test world, so movement is not asserted here;
	# tools/sim.sh measures the effect in the real map.)
	assert_true(start > 172.0, "the teammate started outside its own detection circle")
	for n in [a, b, hog]:
		if is_instance_valid(n):
			n.queue_free()
