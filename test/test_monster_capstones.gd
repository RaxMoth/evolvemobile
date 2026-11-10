extends TestCase

## The monster capstones and their behaviour switches (README "Monster
## capstones and behaviour nodes"). Each one is off on a fresh save, so a
## fresh-save match plays exactly as before; a seeded save turns it on for the
## spawned monster's own copies. AIs are frozen (spawn_frozen) and driven by
## hand.
##   Grount: Rampage (monster_rampage), Trample (Ram Dash trample).

const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"
const GROUNT_DASH := "res://Scenes/NPCs/Monster/Grount/abilities/grout_ram_dash.tres"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const BAT := "res://Scenes/NPCs/Mob/Mobs/Bat/Bat.tscn"
const GROUNT_TREE := &"monster_grount"


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
