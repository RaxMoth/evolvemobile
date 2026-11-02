extends TestCase

## Monster strategy layer (hide & farm → ambush → hunt, retreat) and combos.
## AIs are frozen with TickScheduler.unregister so each rule is driven by hand.

const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const BAT := "res://Scenes/NPCs/Mob/Mobs/Bat/Bat.tscn"
const AREA := "res://Scenes/World/MobSpawnArea/MobSpawnArea.tscn"


func _frozen(path: String, pos: Vector2) -> Node2D:
	var e := await spawn_entity(path, pos)
	TickScheduler.unregister(e)
	return e


func test_strategy_follows_stage() -> void:
	var g := await _frozen(GROUNT, Vector2(0, 0))
	g._update_strategy()
	assert_eq(g.strategy, MonsterBase.Strategy.FARM, "stage 1 hides and farms")
	g.gain_xp(1000.0)
	g._update_strategy()
	assert_eq(g.strategy, MonsterBase.Strategy.AMBUSH, "stage 2 ambushes")
	g.gain_xp(0.0)
	g._update_strategy()
	assert_eq(g.strategy, MonsterBase.Strategy.HUNT, "stage 3 hunts")
	g.queue_free()


func test_hurt_early_monster_retreats_but_stage_3_hunts() -> void:
	var g := await _frozen(GROUNT, Vector2(0, 0))
	var a := await _frozen(VLAD, Vector2(200, 0))
	var b := await _frozen(VLAD, Vector2(-200, 0))
	g.current_health = 0.2 * g.get_max_health()
	g._update_strategy()
	assert_eq(g.strategy, MonsterBase.Strategy.RETREAT)
	g.gain_xp(1000.0)
	g.gain_xp(0.0)
	g.current_health = 0.2 * g.get_max_health()
	g._update_strategy()
	assert_eq(g.strategy, MonsterBase.Strategy.HUNT, "retreat only up to retreat_max_stage")
	for n in [g, a, b]:
		n.queue_free()


func test_farming_monster_ignores_heroes_unless_cornered() -> void:
	var g := await _frozen(GROUNT, Vector2(0, 0))
	var v := await _frozen(VLAD, Vector2(150, 0))
	g._update_strategy()
	assert_true(g._score_target(v) < 0.0, "a hero 150 px away is not engaged at stage 1")
	v.global_position = Vector2(50, 0)
	assert_true(g._score_target(v) > 0.0, "cornered (≤ 70 px): fight back")
	g.queue_free()
	v.queue_free()


func test_ambush_only_engages_isolated_heroes() -> void:
	var g := await _frozen(GROUNT, Vector2(0, 0))
	g.gain_xp(1000.0)
	var lone := await _frozen(VLAD, Vector2(200, 0))
	g._update_strategy()
	assert_eq(g.strategy, MonsterBase.Strategy.AMBUSH)
	assert_true(g._may_engage_hero(lone), "isolated hero")
	var b := await _frozen(VLAD, Vector2(250, 50))
	var c := await _frozen(VLAD, Vector2(250, -50))
	assert_false(g._may_engage_hero(lone), "three heroes together are not ambushed")
	for n in [g, lone, b, c]:
		n.queue_free()


func test_the_monster_activates_camps_so_it_can_farm() -> void:
	var mgr := SpawnManager.new()
	mgr.auto_activate_on_ready = false
	add_child(mgr)
	var area := (load(AREA) as PackedScene).instantiate() as MobSpawnArea
	area.mob_scene = load(BAT)
	area.mob_count = 3
	area.auto_spawn_on_ready = false
	area.position = Vector2(5000, 5000)
	mgr.add_child(area)
	area.virtual_count = 3
	mgr.active_spawn_areas.append(area)
	var g := await _frozen(GROUNT, Vector2(5000, 5000))
	await wait_seconds(0.4)
	assert_true(area.is_active, "a camp next to the monster activates (no hero needed)")
	assert_eq(area.spawned_mobs.size(), 3)
	g.queue_free()
	mgr.queue_free()


func test_ram_dash_stops_in_cleave_range_instead_of_overshooting() -> void:
	var g := await _frozen(GROUNT, Vector2(0, 0))
	var v := await _frozen(VLAD, Vector2(220, 0))
	g.target = v.get_node("Body")
	g.target_entity = v
	assert_true(g._cast("ability_2", g.ability_2, v))
	assert_true(g._is_busy(), "dashing")
	await wait_seconds(0.8)
	var d: float = g.global_position.distance_to(v.global_position)
	assert_true(d <= g.attack_range, "landed in cleave range (%.0f px)" % d)
	assert_true(g.global_position.x < v.global_position.x, "did not run past the target")
	g.queue_free()
	v.queue_free()


func test_ground_slam_keeps_the_evolved_scale_and_stage_radius() -> void:
	var g := await _frozen(GROUNT, Vector2(0, 0))
	g.gain_xp(1000.0)
	g.gain_xp(0.0)
	assert_eq(g.current_stage, 3)
	await wait_seconds(0.7)  # stage scale tween
	var slam: AbilityBase = g.ability_3
	assert_near(float(slam.get("slam_radius")), 180.0, 0.5, "stage-3 radius from aoe_per_stage")
	slam.execute(g, null, 0.0)
	assert_true(slam.is_channeling())
	await wait_seconds(1.3)
	assert_false(slam.is_channeling())
	assert_true(g.scale.is_equal_approx(g.monster_stats.stage_3_scale), "scale %s after the slam" % str(g.scale))
	g.queue_free()


func test_cast_lock_allows_one_ability_per_lock_window() -> void:
	var g := await _frozen(GROUNT, Vector2(0, 0))
	g.gain_xp(1000.0)
	g.gain_xp(0.0)
	var v := await _frozen(VLAD, Vector2(40, 0))
	var w := await _frozen(VLAD, Vector2(40, 30))
	g.target = v.get_node("Body")
	g.target_entity = v
	await wait_seconds(0.7)
	for i in 3:
		g._choose_and_use_ability_combo()
	var used := 0
	for key in ["ability_1", "ability_2", "ability_3"]:
		if not g.is_ability_ready(key):
			used += 1
	assert_eq(used, 1, "exactly one ability fired")
	for n in [g, v, w]:
		n.queue_free()


func test_taunt_overrides_strategy() -> void:
	var g := await _frozen(GROUNT, Vector2(0, 0))
	var v := await _frozen(VLAD, Vector2(300, 0))
	var fx := Node.new()
	fx.name = "TauntEffect"
	fx.set_meta("taunter", v)
	g.add_child(fx)
	g._update_strategy()
	assert_eq(g.strategy, MonsterBase.Strategy.FARM)
	assert_true(g._score_target(v) >= 10000.0, "taunted: the taunter is the only target")
	g.queue_free()
	v.queue_free()


func test_low_hp_monster_rests_ignores_mobs_and_regenerates() -> void:
	var g := await _frozen(GROUNT, Vector2(0, 0))
	var bat := await _frozen(BAT, Vector2(100, 0))
	g._update_strategy()
	assert_true(g._score_target(bat) > 0.0, "a healthy farming monster takes mob fights")
	var max_hp: float = g.get_max_health()
	g.current_health = 0.3 * max_hp
	g._pre_tick(0.1)
	assert_true(g.is_resting(), "below rest_hp_pct")
	assert_true(g._score_target(bat) < 0.0, "resting: no new mob fights")
	g._since_damage = 0.0
	var hp: float = g.current_health
	g._pre_tick(1.0)
	assert_eq(g.current_health, hp, "no regeneration within regen_delay of a hit")
	g._pre_tick(5.0)
	assert_true(g.current_health > hp, "regenerates once out of combat")
	g.current_health = 0.85 * max_hp
	g._pre_tick(0.1)
	assert_false(g.is_resting(), "back to farming at resume_hp_pct")
	g.queue_free()
	bat.queue_free()
