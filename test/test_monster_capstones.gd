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
##   Gorrak: Whirlwind (Cleaver Chop full_circle_from_stage), Unstoppable
##     (monster_cc_immune: Monster Taunt and Trap Cage skip him), Call of the
##     Herd (Warcry Stomp recruit_radius, MobBase.ally_monster and its timer,
##     GameUtils.can_entity_target).

const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"
const GROUNT_DASH := "res://Scenes/NPCs/Monster/Grount/abilities/grout_ram_dash.tres"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const BAT := "res://Scenes/NPCs/Mob/Mobs/Bat/Bat.tscn"
const GROUNT_TREE := &"monster_grount"
const NYXA := "res://Scenes/NPCs/Monster/Nyxa/Nyxa.tscn"
const NYXA_SWOOP := "res://Scenes/NPCs/Monster/Nyxa/abilities/nyxa_swoop.tres"
const NYXA_SWARM := "res://Scenes/NPCs/Monster/Nyxa/abilities/nyxa_night_swarm.tres"
const NYXA_TREE := &"monster_nyxa"
const GORRAK := "res://Scenes/NPCs/Monster/Gorrak/Gorrak.tscn"
const GORRAK_CLEAVER := "res://Scenes/NPCs/Monster/Gorrak/abilities/gorrak_cleaver.tres"
const GORRAK_STOMP := "res://Scenes/NPCs/Monster/Gorrak/abilities/gorrak_stomp.tres"
const GORRAK_TREE := &"monster_gorrak"
const IRELIA := "res://Scenes/NPCs/Hero/Heros/Support/Irelia/Irelia.tscn"
const TED := "res://Scenes/NPCs/Hero/Heros/Support/Ted/Ted.tscn"
const HOG := "res://Scenes/NPCs/Mob/Mobs/Hog/Hog.tscn"


## Unlocks never leak into later files (they assert the stock numbers).
func before_each() -> void:
	# Every tree these tests seed is a monster's: the played side applies it.
	play_side(MatchRewards.Side.MONSTER)
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
	evolve_to(g, 3)
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
	evolve_to(g, 2)
	assert_near(dash.cooldown, 8.0, 0.001, "Stage 2: the stock cooldown")
	evolve_to(g, 3)
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


## monsters-9: the lethal hit lands mid-swoop. The scattered bats (0 HP, the
## chart in Scattered) stop the swoop where they are: one DASH_ENDED, no more
## steps and no hit on the hero in the swoop's path, 200 px on. (The swoop
## flew on and hit him for 12 while she was scattered.)
func test_a_swoop_ends_when_the_bats_scatter() -> void:
	if not require_isolated():
		return
	_own(NYXA_TREE, &"ny_rebirth")
	var n := (await _spawn(NYXA)) as MonsterBase
	var v := (await _spawn(VLAD, Vector2(200, 0))) as HeroBase
	var swoop := n.ability_2 as BullRamDash
	var ended: Array[int] = [0]
	var on_event := func(_source: Node, ability: AbilityBase, event: StringName, _pos: Vector2, _value: float) -> void:
		if ability == swoop and event == FxEvents.DASH_ENDED:
			ended[0] += 1
	EventBus.ability_event.connect(on_event)
	var hp: float = v.get_health()
	assert_true(n._cast("ability_2", swoop, v), "she swoops at the hero")
	await wait_frames(2)
	assert_true(swoop.is_dashing, "in flight")
	var x_at_hit: float = n.global_position.x
	assert_true(x_at_hit < 150.0, "short of the hero (x %.0f)" % x_at_hit)
	EventBus.deal_damage(null, n, 99999.0)
	assert_eq(active_state_of(n), "Scattered", "the lethal hit scatters her")
	await wait_seconds(1.0)
	EventBus.ability_event.disconnect(on_event)
	assert_false(swoop.is_dashing, "the swoop ended")
	assert_eq(ended[0], 1, "once")
	assert_eq(v.get_health(), hp, "the hero in its path is not hit")
	assert_near(n.global_position.x, x_at_hit, 30.0, "she stopped where the bats burst (x %.0f)" % n.global_position.x)
	await _free([n, v])


## monsters-8: the bats never re-form in a sealed pocket of the navigation
## mesh. A mesh like the baked world's: the main part ends at x 380 and a
## sealed 40 px pocket lies 15 px past it, right where the flee fan's first
## point falls (400 px from her, straight away from the hero). A path from her
## stops at the main part's edge 20 px short of it (nav_path_reaches' default
## 32 px tolerance would let it through), so she re-forms on the first fan
## point her path reaches instead. (She was teleported into the pocket and
## could not leave it for the rest of the match.)
func test_rebirth_never_lands_in_a_sealed_pocket() -> void:
	if not require_isolated():
		return
	_own(NYXA_TREE, &"ny_rebirth")
	var region := NavigationRegion2D.new()
	var poly := NavigationPolygon.new()
	poly.agent_radius = 0.0
	var src := NavigationMeshSourceGeometryData2D.new()
	src.add_traversable_outline(PackedVector2Array([Vector2(-600, -400), Vector2(380, -400), Vector2(380, 400), Vector2(-600, 400)]))
	src.add_traversable_outline(PackedVector2Array([Vector2(395, -20), Vector2(435, -20), Vector2(435, 20), Vector2(395, 20)]))
	NavigationServer2D.bake_from_source_geometry_data(poly, src)
	region.navigation_polygon = poly
	add_child(region)
	await wait_physics_frames(6)  # polygons land one map sync after the region
	var n := (await _spawn(NYXA)) as MonsterBase
	var v := (await _spawn(VLAD, Vector2(-100, 0))) as HeroBase
	var w := n.get_world_2d()
	var pocket := Vector2(400, 0)
	assert_true(n._is_on_nav_mesh(pocket), "the pocket is mesh")
	assert_false(GameUtils.nav_path_reaches(w, n.global_position, pocket, 4.0), "but sealed from her")
	var p: Vector2 = n._scatter_point()
	assert_true(p.x < 380.5, "not in the pocket (%s)" % str(p))
	assert_true(GameUtils.nav_path_reaches(w, n.global_position, p, 4.0), "a point her path reaches (%s)" % str(p))
	assert_true(p.distance_to(v.global_position) >= n.rebirth_return_distance, "400 px from the hero")
	# Through the chart: the lethal hit, 3 s of bats, the re-form.
	var from: Vector2 = n.global_position
	EventBus.deal_damage(v, n, 99999.0)
	assert_eq(active_state_of(n), "Scattered")
	await wait_seconds(3.1)
	assert_eq(active_state_of(n), "Idle", "re-formed")
	assert_true(n.global_position.x < 380.5, "on the main part (%s)" % str(n.global_position))
	assert_true(GameUtils.nav_path_reaches(w, from, n.global_position, 4.0), "where a path leads (%s)" % str(n.global_position))
	await _free([n, v, region])
	await wait_physics_frames(6)


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
		evolve_to(n, 2)
		assert_false(swarm.is_permanent(), "Stage 2: a normal swarm")
		swarm.execute(n, null, 1.0)
		swarm.tick_active(n, swarm.duration + 0.1)
		assert_false(swarm.is_active(), "it runs out at Stage 2")
		evolve_to(n, 3)
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


## monsters-4: Brood Mother owned. A swarm cast at Stage 2 through _cast (as
## the AI casts it) is still running when a kill evolves her to Stage 3: it
## turns permanent and bites from then on for the Stage 3 number (5, x Apex
## Predator when owned), not the Stage 2 one (4) it was cast with.
func test_brood_mother_bites_for_stage_3_with_a_swarm_cast_at_stage_2() -> void:
	if not require_isolated():
		return
	_own(NYXA_TREE, &"ny_brood")
	var n := (await _spawn(NYXA)) as MonsterBase
	var v := (await _spawn(VLAD, Vector2(60, 0))) as HeroBase
	var swarm := n.ability_3 as NightSwarm
	evolve_to(n, 2)
	var stage_2_bite: float = n.effective_ability_damage(swarm)
	var bites: Array[float] = []
	var on_hit := func(packet: DamagePacket) -> void:
		if packet.ability == swarm and packet.target == v:
			bites.append(packet.amount)
	EventBus.damage_applied.connect(on_hit)
	assert_true(n._cast("ability_3", swarm, v), "cast at Stage 2")
	await wait_frames(3)
	assert_true(bites.size() >= 1 and is_equal_approx(bites[0], stage_2_bite), "a Stage 2 bite: %s" % str(bites))
	assert_false(swarm.is_permanent(), "a normal swarm at Stage 2")
	n.gain_xp(1000.0)  # the kill that evolves her
	assert_eq(n.get_stage(), 3)
	assert_true(swarm.is_active() and swarm.is_permanent(), "the running swarm never ends now")
	var stage_3_bite: float = n.effective_ability_damage(swarm)
	assert_true(stage_3_bite > stage_2_bite, "Stage 3 bites harder (%.2f > %.2f)" % [stage_3_bite, stage_2_bite])
	bites.clear()
	await wait_seconds(1.2)
	EventBus.damage_applied.disconnect(on_hit)
	assert_true(bites.size() >= 2, "it keeps biting: %s" % str(bites))
	for bite in bites:
		assert_near(bite, stage_3_bite, 0.001, "each bite at the Stage 3 number")
	assert_false(swarm.can_use(n), "and it is not cast again while it runs")
	await _free([n, v])


# ---------- Gorrak: Whirlwind ----------

## A hero 60 px BEHIND Gorrak (he faces +x): the stock chop misses it at
## every stage; with Whirlwind the Stage 3 chop hits all around.
func test_whirlwind_hits_all_around_from_stage_3() -> void:
	if not require_isolated():
		return
	for owned: bool in [false, true]:
		PersistedData.wipe_progress(false)
		if owned:
			_own(GORRAK_TREE, &"gk_whirl")
		var g := (await _spawn(GORRAK)) as MonsterBase
		var v := (await _spawn(VLAD, Vector2(-60, 0))) as HeroBase
		var chop := g.ability_1 as BullFrontCleave
		assert_eq(chop.full_circle_from_stage, 3 if owned else 0)
		g.sprite.rotation = 0.0
		chop.execute(g, null, 10.0)
		assert_eq(v.get_health(), v.get_max_health(), "Stage 1: a frontal arc, owned or not")
		assert_near(chop.cone_angle, 70.0, 0.001)
		evolve_to(g, 3)
		assert_near(chop.cone_angle, 360.0 if owned else 90.0, 0.001, "the Stage 3 arc")
		g.sprite.rotation = 0.0
		chop.execute(g, null, 10.0)
		assert_eq(v.get_health() < v.get_max_health(), owned, "Stage 3: the hero behind him is hit only with Whirlwind")
		assert_eq(chop.debug_tag(), "whirlwind!" if owned else "")
		await _free([g, v])
	assert_eq((load(GORRAK_CLEAVER) as BullFrontCleave).full_circle_from_stage, 0, "the shared .tres is untouched")


# ---------- Gorrak: Unstoppable ----------

func _taunted(e: Node) -> bool:
	return e.get_node_or_null(^"TauntEffect") != null


## The TrapCage Ted's Trap Cage dropped on `target` (a child of the test).
func _drop_cage(ted: Node2D, target: Node2D) -> TrapCage:
	var before: Array[Node] = get_children()
	var ult: AbilityBase = (ted.get_node(^"AbilitySystem") as AbilitySystem).ultimate_ability
	ult.ability_range = 5000.0  # Ted's own copy: a throw across the test bed (200 px in the data)
	ult.execute(ted, target)
	for n in get_children():
		if n is TrapCage and not before.has(n):
			return n as TrapCage
	return null


func test_unstoppable_is_off_on_a_fresh_save() -> void:
	if not require_isolated():
		return
	var g := (await _spawn(GORRAK)) as MonsterBase
	var irelia := (await _spawn(IRELIA, Vector2(100, 0))) as HeroBase
	var ted := (await _spawn(TED, Vector2(0, 600))) as HeroBase
	assert_false(g.is_cc_immune())
	(irelia.get_node(^"AbilitySystem") as AbilitySystem).ultimate_ability.execute(irelia)
	assert_true(_taunted(g), "Monster Taunt takes him")
	var cage := _drop_cage(ted, g)
	assert_true(cage != null and cage.trapped_enemies.has(g), "Trap Cage takes him")
	assert_false(g.debug_meta_line().contains("unstoppable"))
	await _free([g, irelia, ted, cage])


## Owned: Monster Taunt passes him by (the Hog next to him is taunted
## instead) and Trap Cage never holds him (it still holds the Hog).
func test_unstoppable_skips_the_taunt_and_the_cage() -> void:
	if not require_isolated():
		return
	_own(GORRAK_TREE, &"gk_unstoppable")
	var g := (await _spawn(GORRAK)) as MonsterBase
	var hog := (await _spawn(HOG, Vector2(0, 80))) as MobBase
	var irelia := (await _spawn(IRELIA, Vector2(100, 0))) as HeroBase
	var ted := (await _spawn(TED, Vector2(0, 600))) as HeroBase
	assert_true(g.is_cc_immune())
	assert_true(g.debug_meta_line().contains("unstoppable"), g.debug_meta_line())
	(irelia.get_node(^"AbilitySystem") as AbilitySystem).ultimate_ability.execute(irelia)
	assert_false(_taunted(g), "Monster Taunt skips him")
	assert_true(_taunted(hog), "and falls back on the mob next to him")
	var cage := _drop_cage(ted, g)
	assert_true(cage != null, "the cage still lands on him")
	if cage != null:
		assert_false(cage.trapped_enemies.has(g), "but never holds him")
		assert_true(cage.trapped_enemies.has(hog), "the Hog is held")
		g.global_position = cage.global_position + Vector2(300, 0)
		await wait_frames(2)
		assert_true(g.global_position.distance_to(cage.global_position) > cage.cage_radius, "he walks out")
	await _free([g, hog, irelia, ted, cage])


## Nyxa's scattered bats are cc-immune too: a cage that held her lets the
## bats fly out, and lets her go for good. monsters-3: she re-forms (the
## chart's delayed ToIdle, 3 s into the 6 s cage) where the bats flew, and
## the still-closed cage neither holds her again nor pulls her back in (it
## did: re-formed and no longer immune, she was moved to its edge in the same
## frame and held among the heroes until it opened).
func test_a_cage_lets_the_scattered_bats_out() -> void:
	if not require_isolated():
		return
	_own(NYXA_TREE, &"ny_rebirth")
	var n := (await _spawn(NYXA)) as MonsterBase
	var ted := (await _spawn(TED, Vector2(0, 600))) as HeroBase
	var cage := _drop_cage(ted, n)
	assert_true(cage != null and cage.trapped_enemies.has(n), "held while alive")
	if cage == null:
		await _free([n, ted])
		return
	assert_false(n.is_cc_immune())
	EventBus.deal_damage(ted, n, 99999.0)
	assert_eq(active_state_of(n), "Scattered")
	assert_true(n.is_scattered() and n.is_cc_immune(), "the scattered bats are immune")
	n.global_position = cage.global_position + Vector2(300, 0)
	await wait_frames(2)
	assert_true(n.global_position.distance_to(cage.global_position) > cage.cage_radius, "the bats fly out")
	assert_false(cage.trapped_enemies.has(n), "the cage let her go")
	await wait_seconds(3.1)
	assert_eq(active_state_of(n), "Idle", "the bats re-formed")
	assert_false(n.is_cc_immune(), "no longer immune")
	assert_true(cage.cage_active, "the 6 s cage is still closed")
	for i in 5:
		await wait_physics_frames(1)
		assert_true(n.global_position.distance_to(cage.global_position) > cage.cage_radius,
				"frame %d: not pulled back in (%.0f px from the cage)" % [i, n.global_position.distance_to(cage.global_position)])
	assert_false(cage.trapped_enemies.has(n), "nor held again")
	var vis := n.visual_root()
	assert_true(vis == null or (vis.modulate.r == 1.0 and vis.modulate.g == 1.0), "and not tinted")
	await _free([n, ted, cage])


# ---------- Gorrak: Call of the Herd ----------

func test_call_of_the_herd_is_off_on_a_fresh_save() -> void:
	if not require_isolated():
		return
	var g := (await _spawn(GORRAK)) as MonsterBase
	var hog := (await _spawn(HOG, Vector2(80, 0))) as MobBase
	var v := (await _spawn(VLAD, Vector2(0, 90))) as HeroBase
	var stomp := g.ability_3 as BullGroundSlam
	assert_eq(stomp.recruit_radius, 0.0)
	await _stomp_at(g, v)
	assert_false(hog.is_in_warband())
	assert_true(hog.ally_monster == null)
	assert_true(hog.get_health() < hog.get_max_health(), "the stomp hits the Hog")
	assert_true(GameUtils.can_entity_target(hog, g) and GameUtils.can_entity_target(g, hog))
	assert_eq(stomp.debug_tag(), "")
	await _free([g, hog, v])


## Gorrak's Warcry Stomp cast at `target` (it lands where he stands after its
## 0.6 s hop).
func _stomp_at(g: MonsterBase, target: Node2D) -> void:
	var stomp := g.ability_3 as BullGroundSlam
	stomp.execute(g, target, 10.0)
	await wait_seconds(stomp.jump_duration + 0.2)


## Owned: a stomp cast at a hero turns the Hogs within 250 px into Gorrak's
## warband for 20 s (one cast at a mob, farming, recruits nobody): spared by
## the stomp (one stands inside its 100 px), they and he never target each
## other, they go for the
## hero; a Bat (not a Hog) and a Hog 400 px away are not recruited. When the
## timer runs out they are mobs again.
func test_call_of_the_herd_recruits_the_hogs_for_20_s() -> void:
	if not require_isolated():
		return
	_own(GORRAK_TREE, &"gk_warband")
	var g := (await _spawn(GORRAK)) as MonsterBase
	var hog_a := (await _spawn(HOG, Vector2(80, 0))) as MobBase
	var hog_b := (await _spawn(HOG, Vector2(-120, 140))) as MobBase
	var far_hog := (await _spawn(HOG, Vector2(400, 0))) as MobBase
	var bat := (await _spawn(BAT, Vector2(0, -90))) as MobBase
	var v := (await _spawn(VLAD, Vector2(0, 260))) as HeroBase
	var stomp := g.ability_3 as BullGroundSlam
	assert_near(stomp.recruit_radius, 250.0, 0.001)
	assert_true(hog_a.can_join_warband and not bat.can_join_warband, "the Hog scene is recruitable, the Bat is not")
	await _stomp_at(g, bat)
	assert_eq(stomp.last_recruit_count, 0, "a stomp at a mob (farming) calls no one")
	assert_false(hog_a.is_in_warband())
	assert_true(hog_a.get_health() < hog_a.get_max_health(), "and hits the Hog as usual")
	hog_a.current_health = hog_a.max_health
	bat.current_health = bat.max_health
	await _stomp_at(g, v)
	assert_eq(stomp.last_recruit_count, 2, "a stomp at a hero calls the herd")
	assert_eq(stomp.debug_tag(), "warband(last 2)")
	for hog: MobBase in [hog_a, hog_b]:
		assert_true(hog.is_in_warband() and hog.ally_monster == g, "%s joined" % hog.name)
		assert_near(hog.warband_timer.time_left, 20.0, 0.5, "a 20 s warband")
		assert_eq(hog.get_health(), hog.get_max_health(), "the stomp spares its warband")
		assert_false(GameUtils.can_entity_target(hog, g), "it never targets Gorrak")
		assert_false(GameUtils.can_entity_target(g, hog), "and Gorrak never hits it")
		assert_true(GameUtils.can_entity_target(hog, v), "heroes stay its targets")
		assert_true(hog.target_entity == v, "it goes for the hero")
		assert_true(hog.modulate != Color.WHITE, "tinted while in the warband")
	assert_false(far_hog.is_in_warband(), "400 px away: not recruited")
	assert_false(bat.is_in_warband(), "a Bat is not recruited")
	assert_true(bat.get_health() < bat.get_max_health(), "and the stomp hits it")
	hog_a.warband_timer.start(0.05)
	await wait_seconds(0.2)
	assert_false(hog_a.is_in_warband(), "the timer ran out")
	assert_true(hog_a.ally_monster == null)
	assert_eq(hog_a.modulate, Color.WHITE)
	assert_true(GameUtils.can_entity_target(hog_a, g) and GameUtils.can_entity_target(g, hog_a), "enemies again")
	hog_b.prepare_for_pool()
	assert_false(hog_b.is_in_warband(), "parking a mob ends its warband")
	assert_true(hog_b.warband_timer.is_stopped())
	assert_eq((load(GORRAK_STOMP) as BullGroundSlam).recruit_radius, 0.0, "the shared .tres is untouched")
	await _free([g, hog_a, hog_b, far_hog, bat, v])


## monsters-7: a recruit that sees no hero still fights. A ticking camp Hog
## (its leash, chase_distance, 100 px: shorter than its sight) 300 px from
## the hero joins the warband: it goes for the nearest hero within
## warband_seek_radius (350), keeps after him out of sight past its first
## re-evaluation and reaches him. When the warband ends (its timer, or the
## pool) it drops nothing it does not see again: its pursue radius is back to
## the scene's 0. (It found no hero within 100 px, or dropped him 0.5 s later,
## and stood idle in its camp for the whole 20 s.)
func test_a_recruit_goes_for_a_hero_it_cannot_see() -> void:
	if not require_isolated():
		return
	var region := await bake_nav_rect(Rect2(-1200, -600, 2400, 1200))
	var g := (await _spawn(GORRAK, Vector2(-900, 0))) as MonsterBase
	var v := (await _spawn(VLAD, Vector2(300, 0))) as HeroBase
	var hog := (await spawn_entity(HOG, Vector2.ZERO)) as MobBase
	hog.chase_distance = 100.0  # a World camp's leash (MobSpawnArea.reset_for_spawn)
	assert_eq(hog.pursue_out_of_sight_radius, 0.0, "a mob drops what it does not see")
	assert_false(hog.is_target_valid(), "the hero is out of its sight")
	hog.join_warband(g, 20.0)
	assert_true(hog.target_entity == v, "it goes for the hero it cannot see")
	assert_eq(hog.pursue_out_of_sight_radius, hog.warband_seek_radius)
	await wait_seconds(1.0)
	assert_true(hog.is_target_valid() and hog.target_entity == v, "and keeps after him past its re-evaluation")
	for i in 60:
		if active_state_of(hog) == "Fight":
			break
		await wait_seconds(0.1)
	assert_eq(active_state_of(hog), "Fight", "it reaches him (%.0f px)" % hog.global_position.distance_to(v.global_position))
	hog.warband_timer.start(0.05)
	await wait_seconds(0.2)
	assert_false(hog.is_in_warband())
	assert_eq(hog.pursue_out_of_sight_radius, 0.0, "the timer ends the pursuit radius")
	hog.join_warband(g, 20.0)
	hog.prepare_for_pool()
	assert_eq(hog.pursue_out_of_sight_radius, 0.0, "and so does the pool")
	await _free([g, v, hog, region])
	await wait_physics_frames(6)
