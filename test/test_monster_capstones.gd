extends TestCase

## The monster capstones and their behaviour switches (README "Monster
## capstones and behaviour nodes"). Each one is off on a fresh save, so a
## fresh-save match plays exactly as before; a seeded save turns it on for the
## spawned monster's own copies. AIs are frozen (spawn_frozen) and driven by
## hand.
##   Grount: Rampage (monster_rampage), Trample (Ram Dash trample).
##   Nyxa: Vampiric Rebirth (monster_rebirth, the chart's Scattered state),
##     Echo Strike (Shadow Swoop double_pass), Brood Mother (Night Swarm
##     permanent_from_stage).

const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"
const GROUNT_DASH := "res://Scenes/NPCs/Monster/Grount/abilities/grout_ram_dash.tres"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const BAT := "res://Scenes/NPCs/Mob/Mobs/Bat/Bat.tscn"
const GROUNT_TREE := &"monster_grount"
const NYXA := "res://Scenes/NPCs/Monster/Nyxa/Nyxa.tscn"
const NYXA_SWOOP := "res://Scenes/NPCs/Monster/Nyxa/abilities/nyxa_swoop.tres"
const NYXA_SWARM := "res://Scenes/NPCs/Monster/Nyxa/abilities/nyxa_night_swarm.tres"
const NYXA_TREE := &"monster_nyxa"


## Unlocks never leak into later files (they assert the stock numbers).
func before_each() -> void:
	if is_isolated():
		PersistedData.wipe_progress(false)


func after_each() -> void:
	if is_isolated():
		PersistedData.wipe_progress(false)


func _spawn(scene: String, pos: Vector2 = Vector2.ZERO) -> Node2D:
	return await spawn_frozen(scene, pos)


## Frees what is still there (a killed hero already freed itself).
func _free(nodes: Array) -> void:
	for n in nodes:
		if is_instance_valid(n):
			(n as Node).queue_free()
	await wait_frames(1)


## Own one node of a tree at rank 1 (skips gates and prices) and equip it
## when it is a capstone.
func _own(tree_id: StringName, node_id: StringName) -> void:
	PersistedData.set_skill_rank(tree_id, node_id, 1)
	if MetaSkillManager.get_tree_def(tree_id).find_node(node_id).capstone:
		PersistedData.set_equipped_capstone(tree_id, node_id)


func _set_cooldowns(m: MonsterBase, seconds: float) -> void:
	for key in m.ability_cooldowns.keys():
		m.ability_cooldowns[key] = seconds


## Every cooldown above `seconds` (they keep ticking down in _process).
func _cooldowns_above(m: MonsterBase, seconds: float) -> bool:
	for key in m.ability_cooldowns.keys():
		if float(m.ability_cooldowns[key]) <= seconds:
			return false
	return true


func _cooldowns_reset(m: MonsterBase) -> bool:
	for key in m.ability_cooldowns.keys():
		if float(m.ability_cooldowns[key]) > 0.0:
			return false
	return true


func _evolve(m: MonsterBase, stage: int) -> void:
	while m.get_stage() < stage:
		m.gain_xp(1000.0)


# ---------- Grount: Rampage ----------

## Fresh save: no EventBus listener, and a hero kill changes nothing.
func test_rampage_is_off_on_a_fresh_save() -> void:
	if not require_isolated():
		return
	var g := (await _spawn(GROUNT)) as MonsterBase
	var v := (await _spawn(VLAD, Vector2(60, 0))) as HeroBase
	assert_false(g._meta_rampage)
	assert_false(EventBus.entity_died.is_connected(g._on_entity_died_rampage), "no listener without the node")
	_set_cooldowns(g, 5.0)
	g.current_health = 0.5 * g.get_max_health()
	EventBus.deal_damage(g, v, 99999.0)
	await wait_frames(1)
	assert_false(is_instance_valid(v) and v.is_alive(), "the hero died")
	assert_true(_cooldowns_above(g, 4.0), "cooldowns untouched")
	assert_near(g.current_health, 0.5 * g.get_max_health(), 0.001, "no heal")
	assert_false(g.debug_meta_line().contains("rampage"), g.debug_meta_line())
	await _free([g, v])


## Owned: a hero this monster killed zeroes every cooldown and heals 15% of
## max HP; a mob kill or someone else's kill does nothing.
func test_rampage_resets_cooldowns_and_heals_on_a_hero_kill() -> void:
	if not require_isolated():
		return
	_own(GROUNT_TREE, &"g4_rampage")
	var g := (await _spawn(GROUNT)) as MonsterBase
	var v := (await _spawn(VLAD, Vector2(60, 0))) as HeroBase
	var bat := (await _spawn(BAT, Vector2(-60, 0))) as MobBase
	assert_true(g._meta_rampage)
	assert_true(EventBus.entity_died.is_connected(g._on_entity_died_rampage))
	var max_hp: float = g.get_max_health()
	_set_cooldowns(g, 5.0)
	g.current_health = 0.5 * max_hp
	g._on_entity_died_rampage(bat, g)
	assert_true(_cooldowns_above(g, 4.0), "a mob kill is no Rampage")
	g._on_entity_died_rampage(v, bat)
	assert_true(_cooldowns_above(g, 4.0), "a hero someone else killed is no Rampage")
	assert_near(g.current_health, 0.5 * max_hp, 0.001)
	EventBus.deal_damage(g, v, 99999.0)
	await wait_frames(1)
	assert_false(is_instance_valid(v) and v.is_alive(), "the hero died to Grount")
	assert_true(_cooldowns_reset(g), "every cooldown reset: %s" % str(g.ability_cooldowns))
	assert_near(g.current_health, 0.65 * max_hp, 0.001, "+15% of max HP")
	assert_eq(g._rampage_kills, 1)
	assert_true(g.debug_meta_line().contains("rampage(1)"), g.debug_meta_line())
	g.current_health = max_hp - 10.0
	g._on_entity_died_rampage(await _spawn(VLAD, Vector2(0, 90)), g)
	assert_near(g.current_health, max_hp, 0.001, "never above max HP")
	var third := await _spawn(VLAD, Vector2(0, -90))
	g.current_health = 0.0
	_set_cooldowns(g, 5.0)
	g._on_entity_died_rampage(third, g)
	assert_true(_cooldowns_above(g, 4.0), "a dead monster does not rampage")
	await _free([g, bat])
	for h in get_children():
		if h is HeroBase:
			h.queue_free()
	await wait_frames(1)


# ---------- Grount: Trample ----------

func test_trample_is_off_on_a_fresh_save() -> void:
	if not require_isolated():
		return
	var g := (await _spawn(GROUNT)) as MonsterBase
	var dash := g.ability_2 as BullRamDash
	assert_false(dash.trample)
	assert_eq(dash.get_hit_radius(), 40.0, "the stock lane")
	_evolve(g, 3)
	assert_near(dash.cooldown, 5.0, 0.001, "the stock Stage 3 cooldown")
	assert_eq(dash.debug_tag(), "")
	await _free([g])


## Owned: a 70 px lane at every stage, half the cooldown from Stage 3.
func test_trample_widens_the_lane_and_halves_the_stage_3_cooldown() -> void:
	if not require_isolated():
		return
	_own(GROUNT_TREE, &"g4_stampede")
	var g := (await _spawn(GROUNT)) as MonsterBase
	var dash := g.ability_2 as BullRamDash
	assert_true(dash.trample, "the node sets the flag on Grount's copy")
	assert_eq(dash.get_hit_radius(), 70.0)
	assert_near(dash.cooldown, 12.0, 0.001, "Stage 1: the stock cooldown")
	_evolve(g, 2)
	assert_near(dash.cooldown, 8.0, 0.001, "Stage 2: the stock cooldown")
	_evolve(g, 3)
	assert_near(dash.cooldown, 2.5, 0.001, "Stage 3: twice as fast")
	g._evolve_to_stage(3)
	assert_near(dash.cooldown, 2.5, 0.001, "re-entering the stage never compounds")
	assert_true(g.debug_meta_line().contains("trample 70 px"), g.debug_meta_line())
	assert_false((load(GROUNT_DASH) as BullRamDash).trample, "the shared .tres is untouched")
	await _free([g])


## A hero 90 px beside the dash line: outside the stock 40 px lane (its body
## is a 31 px circle), inside Trample's 70 px one.
func test_trample_hits_beside_the_dash_line() -> void:
	if not require_isolated():
		return
	for owned: bool in [false, true]:
		PersistedData.wipe_progress(false)
		if owned:
			_own(GROUNT_TREE, &"g4_stampede")
		var g := (await _spawn(GROUNT)) as MonsterBase
		var v := (await _spawn(VLAD, Vector2(150, 90))) as HeroBase
		g.sprite.rotation = 0.0
		assert_true(g._cast("ability_2", g.ability_2, null), "an escape dash along +x")
		await wait_seconds(0.9)
		assert_false((g.ability_2 as BullRamDash).is_dashing, "the dash ended")
		assert_true(g.global_position.x > 200.0, "it ran past the hero (x %.0f)" % g.global_position.x)
		assert_eq(v.get_health() < v.get_max_health(), owned, "hit 90 px beside the line: %s" % str(owned))
		await _free([g, v])


# ---------- Nyxa: Vampiric Rebirth ----------

func test_rebirth_is_off_on_a_fresh_save() -> void:
	if not require_isolated():
		return
	var n := (await _spawn(NYXA)) as MonsterBase
	assert_false(n._meta_rebirth)
	assert_eq(active_state_of(n), "Idle")
	assert_false(n.debug_meta_line().contains("rebirth"), n.debug_meta_line())
	EventBus.deal_damage(null, n, 99999.0)
	assert_eq(active_state_of(n), "Dead", "the lethal hit kills")
	assert_false(n.is_scattered())
	await _free([n])


## Owned: the first lethal hit takes the chart into Scattered (untargetable:
## 0 HP, hits canceled, Body layer off, no target, no stun, no death
## reported); its delayed ToIdle transition re-forms her after 3 s with 30%
## of max HP, 400 px from the hero; the next lethal hit kills.
func test_rebirth_scatters_once_and_returns_with_30_percent() -> void:
	if not require_isolated():
		return
	_own(NYXA_TREE, &"ny_rebirth")
	var n := (await _spawn(NYXA)) as MonsterBase
	var v := (await _spawn(VLAD, Vector2(120, 0))) as HeroBase
	var died: Array[Node] = []
	var on_died := func(e: Node, _killer: Node) -> void: died.append(e)
	EventBus.entity_died.connect(on_died)
	var body := n.get_node(^"Body") as Area2D
	assert_true(n._meta_rebirth)
	assert_eq(body.collision_layer, GameUtils.LAYER_BODY_MONSTER)
	assert_true(n.debug_meta_line().contains("rebirth"), n.debug_meta_line())
	n.set_target(v)
	n.apply_stun(2.0)
	EventBus.deal_damage(v, n, 99999.0)
	assert_eq(active_state_of(n), "Scattered", "the lethal hit is taken by the chart's Scattered state")
	assert_true(n.is_scattered())
	assert_false(n.is_alive(), "0 HP while scattered: no one keeps her as a target")
	assert_eq(n.get_health(), 0.0)
	assert_eq(body.collision_layer, 0, "Body layer off")
	assert_false(n.is_target_valid(), "she dropped her target")
	assert_false(n.is_stunned(), "and her stun")
	assert_eq(EventBus.deal_damage(v, n, 50.0), 0.0, "hits on the bats are canceled")
	assert_true(died.is_empty(), "no death reported")
	await wait_frames(2)
	assert_true(n.debug_meta_line().contains("rebirth! "), n.debug_meta_line())
	await wait_seconds(3.1)
	assert_eq(active_state_of(n), "Idle", "the delayed ToIdle transition ends it")
	assert_false(n.is_scattered())
	assert_near(n.get_health(), 0.3 * n.get_max_health(), 0.01, "30% of max HP")
	assert_eq(body.collision_layer, GameUtils.LAYER_BODY_MONSTER, "targetable again")
	assert_true(n.global_position.distance_to(v.global_position) >= 399.5,
			"re-formed 400 px from the hero (%.0f)" % n.global_position.distance_to(v.global_position))
	assert_true(n.debug_meta_line().contains("rebirth spent"), n.debug_meta_line())
	EventBus.deal_damage(v, n, 99999.0)
	assert_eq(active_state_of(n), "Dead", "once per match: the next lethal hit kills")
	assert_eq(died, [n] as Array[Node], "one death, reported once")
	EventBus.entity_died.disconnect(on_died)
	await _free([n, v])


## Away from every hero already: she re-forms where the flight left her.
func test_rebirth_far_from_the_heroes_stays_put() -> void:
	if not require_isolated():
		return
	_own(NYXA_TREE, &"ny_rebirth")
	var n := (await _spawn(NYXA)) as MonsterBase
	var v := (await _spawn(VLAD, Vector2(900, 0))) as HeroBase
	EventBus.deal_damage(v, n, 99999.0)
	assert_true(n.is_scattered())
	n.teleport_to(Vector2(-50, 30))
	await wait_seconds(3.1)
	assert_false(n.is_scattered())
	assert_eq(n.global_position, Vector2(-50, 30), "no hero within 400 px: no jump")
	await _free([n, v])


# ---------- Nyxa: Echo Strike ----------

## A swoop at a hero 150 px away: one hit stock, two with Echo Strike, which
## ends back where it started (the stock one 60 px past the hero).
func test_echo_strike_passes_the_target_twice() -> void:
	if not require_isolated():
		return
	var losses: Array[float] = []
	for owned: bool in [false, true]:
		PersistedData.wipe_progress(false)
		if owned:
			_own(NYXA_TREE, &"ny_echo")
		var n := (await _spawn(NYXA)) as MonsterBase
		var v := (await _spawn(VLAD, Vector2(150, 0))) as HeroBase
		var swoop := n.ability_2 as BullRamDash
		assert_eq(swoop.double_pass, owned)
		assert_eq(swoop.debug_tag(), "echo" if owned else "")
		var hp: float = v.get_health()
		assert_true(n._cast("ability_2", swoop, v))
		await wait_seconds(1.0)
		assert_false(swoop.is_dashing, "the swoop ended")
		losses.append(hp - v.get_health())
		if owned:
			assert_true(n.global_position.length() < 2.0, "back where she started (%s)" % str(n.global_position))
		else:
			assert_near(n.global_position.x, 210.0, 1.0, "60 px past the hero")
		await _free([n, v])
	assert_true(losses[0] > 0.0, "the stock swoop hits")
	assert_near(losses[1], 2.0 * losses[0], 0.01, "two passes, two hits")
	assert_false((load(NYXA_SWOOP) as BullRamDash).double_pass, "the shared .tres is untouched")


## An escape swoop (no target) never turns back toward the heroes.
func test_echo_strike_never_turns_an_escape() -> void:
	if not require_isolated():
		return
	_own(NYXA_TREE, &"ny_echo")
	var n := (await _spawn(NYXA)) as MonsterBase
	n.sprite.rotation = 0.0
	assert_true(n._cast("ability_2", n.ability_2, null))
	await wait_seconds(1.0)
	assert_near(n.global_position.x, (n.ability_2 as BullRamDash).dash_distance, 1.0, "the full distance, one way")
	await _free([n])


# ---------- Nyxa: Brood Mother ----------

func test_brood_mother_keeps_the_stage_3_swarm_running() -> void:
	if not require_isolated():
		return
	for owned: bool in [false, true]:
		PersistedData.wipe_progress(false)
		if owned:
			_own(NYXA_TREE, &"ny_brood")
		var n := (await _spawn(NYXA)) as MonsterBase
		var swarm := n.ability_3 as NightSwarm
		assert_eq(swarm.permanent_from_stage, 3 if owned else 0)
		_evolve(n, 2)
		assert_false(swarm.is_permanent(), "Stage 2: a normal swarm")
		swarm.execute(n, null, 1.0)
		swarm.tick_active(n, swarm.duration + 0.1)
		assert_false(swarm.is_active(), "it runs out at Stage 2")
		_evolve(n, 3)
		assert_eq(swarm.is_permanent(), owned)
		swarm.execute(n, null, 1.0)
		swarm.tick_active(n, 60.0)
		assert_eq(swarm.is_active(), owned, "Stage 3: it never ends with Brood Mother")
		assert_eq(swarm.can_use(n), not owned, "and is not cast again while it runs")
		if owned:
			assert_true(n.debug_meta_line().contains("swarm! forever"), n.debug_meta_line())
			n.current_health = 0.0
			swarm.tick_active(n, 0.1)
			assert_false(swarm.is_active(), "it stops with her")
			assert_true(swarm.can_use(n))
		await _free([n])
	assert_eq((load(NYXA_SWARM) as NightSwarm).permanent_from_stage, 0, "the shared .tres is untouched")
