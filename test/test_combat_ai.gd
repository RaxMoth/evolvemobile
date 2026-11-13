extends TestCase

## Combat AI rules of fix batch G1: a pooled mob that comes back is nobody's
## old target, ultimates go off only with something in their own reach, the
## Supply Drop heals once it has landed, the monsters use ability 2 in a fight,
## Gorrak's warband is no prey, and heroes fight an evolved monster from the
## edge of his body, each on its own side.

const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const RIVER := "res://Scenes/NPCs/Hero/Heros/Healer/River/River.tscn"
const TED := "res://Scenes/NPCs/Hero/Heros/Support/Ted/Ted.tscn"
const IRELIA := "res://Scenes/NPCs/Hero/Heros/Support/Irelia/Irelia.tscn"
const HOG := "res://Scenes/NPCs/Mob/Mobs/Hog/Hog.tscn"
const BAT := "res://Scenes/NPCs/Mob/Mobs/Bat/Bat.tscn"
const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"
const NYXA := "res://Scenes/NPCs/Monster/Nyxa/Nyxa.tscn"
const GORRAK := "res://Scenes/NPCs/Monster/Gorrak/Gorrak.tscn"
const AREA := "res://Scenes/World/MobSpawnArea/MobSpawnArea.tscn"


func _free(nodes: Array) -> void:
	for n in nodes:
		if is_instance_valid(n):
			(n as Node).queue_free()
	await wait_frames(2)


## A frozen hero whose own auto-casts are off: the tests call the rules.
func _hero(path: String, pos: Vector2) -> HeroBase:
	var h := (await spawn_frozen(path, pos)) as HeroBase
	h.auto_use_ultimate = false
	h.auto_use_active = false
	h.auto_ult_min_enemies = 3
	h.auto_ult_panic_hp_pct = 0.25
	return h


func _hurt(hero: HeroBase, amount: float) -> void:
	hero.stats.take_damage(amount)


func _ult(hero: HeroBase) -> AbilityBase:
	return (hero.get_node("AbilitySystem") as AbilitySystem).ultimate_ability


## The node of `type_name` a cast added under the test since `before`, or null.
func _new_child(before: Array[Node], type_name: String) -> Node:
	for n in get_children():
		if not before.has(n) and n.get_script() != null and (n.get_script() as Script).get_global_name() == type_name:
			return n
	return null


# ---------------------------------------------------------------- stale targets

## heroes-1 / monsters-1: a killed mob is parked and the pool hands the same
## node to the next camp. The old target pair came back to life with it (Idle
## heroes fired ultimates at it across the map); the holder now records the
## target's life_id, and a fighting holder drops the dead target at once.
func test_a_reused_pooled_mob_is_nobodys_old_target() -> void:
	# One Bat camp beside Vlad (no respawn within the test), one far away that
	# activates once the Bat is parked: the pool hands it the same node.
	var mgr := make_spawn_manager(1, 100.0, Vector2(40, 0)) as SpawnManager
	var near_camp := mgr.get_child(0) as MobSpawnArea
	var far_camp := (load(AREA) as PackedScene).instantiate() as MobSpawnArea
	far_camp.mob_scene = near_camp.mob_scene
	far_camp.mob_count = 1
	far_camp.auto_spawn_on_ready = false
	far_camp.position = Vector2(2600, 0)
	mgr.add_child(far_camp)
	far_camp.virtual_count = 1
	var vlad := (await spawn_entity(VLAD, Vector2(0, 0))) as HeroBase
	vlad.auto_use_ultimate = false
	var watcher := await _hero(IRELIA, Vector2(-3000, 0))
	near_camp.activate()
	await wait_physics_frames(4)
	var bat := near_camp.spawned_mobs[0] as MobBase
	bat.global_position = Vector2(30, 0)
	watcher.set_target(bat)  # a frozen holder far away
	await wait_seconds(0.3)
	assert_true(vlad.target_entity == bat, "Vlad fights the Bat beside him")
	var life: int = bat.life_id
	EventBus.deal_damage(vlad, bat, 9999.0)
	await wait_frames(3)
	assert_true(bat.is_parked, "parked in the pool")
	assert_true(vlad.target_entity == null and vlad.target == null, "the fighter dropped its dead target")
	far_camp.activate()
	await wait_physics_frames(3)
	assert_true(far_camp.spawned_mobs.has(bat), "the far camp got the same node")
	assert_true(bat.is_inside_tree() and bat.is_alive() and not bat.is_parked, "alive again, 2600 px away")
	assert_true(bat.life_id > life, "a new life")
	assert_true(watcher.target_entity == bat, "the frozen holder still names the node ...")
	assert_false(watcher.is_target_valid(), "... but it is not its target any more")
	assert_false(vlad.target_entity == bat, "and Vlad does not take it up again")
	await _free([vlad, watcher, mgr])


# ---------------------------------------------------------------- ultimates in reach

## heroes-3: Blood Bomb goes off around Vlad, so three enemies around a target
## 400 px away are not "in reach"; beside them it fires. The panic rule (an
## ally below the panic HP) needs one enemy in reach too.
func test_blood_bomb_waits_until_the_enemies_are_around_vlad() -> void:
	var vlad := await _hero(VLAD, Vector2(0, 0))
	var river := await _hero(RIVER, Vector2(0, 600))
	var hogs: Array[Node2D] = []
	for pos: Vector2 in [Vector2(400, 0), Vector2(450, 60), Vector2(450, -60)]:
		hogs.append(await spawn_frozen(HOG, pos))
	vlad.set_target(hogs[0])
	assert_eq(_ult(vlad).count_reached(vlad, hogs[0], 3), 0)
	assert_false(vlad._should_auto_use_ultimate(), "three Hogs 400 px away: nothing in the bomb's 150 px")
	vlad.global_position = Vector2(380, 0)
	assert_true(vlad._should_auto_use_ultimate(), "beside them: fire")
	vlad.global_position = Vector2(0, 0)
	_hurt(river, river.get_max_health() * 0.9)
	assert_false(vlad._should_auto_use_ultimate(), "an ally in trouble, but nothing in reach")
	vlad.global_position = Vector2(300, 0)
	assert_eq(_ult(vlad).count_reached(vlad, hogs[0], 3), 1)
	assert_true(vlad._should_auto_use_ultimate(), "panic: one enemy in reach is enough")
	var nodes: Array = [vlad, river]
	nodes.append_array(hogs)
	await _free(nodes)


## Monster Taunt goes off around Irelia: the monster must stand within its
## 200 px, whatever the panic.
func test_monster_taunt_needs_the_monster_in_irelias_range() -> void:
	var irelia := await _hero(IRELIA, Vector2(0, 0))
	var vlad := await _hero(VLAD, Vector2(0, -150))
	var g := await spawn_frozen(GROUNT, Vector2(350, 0))
	_hurt(vlad, vlad.get_max_health() * 0.9)
	irelia.set_target(g)
	assert_false(irelia._should_auto_use_ultimate(), "350 px: out of the taunt's 200")
	g.global_position = Vector2(150, 0)
	assert_eq(_ult(irelia).count_reached(irelia, g, 3), 1, "the monster, not the mobs")
	assert_true(irelia._should_auto_use_ultimate(), "in range, with an ally in trouble")
	await _free([irelia, vlad, g])


## Trap Cage is thrown at most its ability_range (200 px): a target further out
## is no throw for the AI, and a cast lands at most that far from Ted.
func test_trap_cage_is_thrown_at_most_its_range() -> void:
	var ted := await _hero(TED, Vector2(0, 0))
	var ult := _ult(ted) as TedUltimateTrapCage
	assert_near(ult.ability_range, 200.0, 0.001, "the throw range in the data")
	var hogs: Array[Node2D] = []
	for pos: Vector2 in [Vector2(500, 0), Vector2(520, 40), Vector2(520, -40)]:
		hogs.append(await spawn_frozen(HOG, pos))
	ted.set_target(hogs[0])
	assert_false(ted._should_auto_use_ultimate(), "500 px: beyond the throw")
	var before: Array[Node] = get_children()
	ult.execute(ted, hogs[0])
	var cage := _new_child(before, "TrapCage") as Node2D
	assert_true(cage != null, "a cast still drops a cage")
	if cage != null:
		assert_near(cage.global_position.distance_to(ted.global_position), 200.0, 0.01, "200 px out, toward the target")
		cage.queue_free()
	ted.global_position = Vector2(350, 0)
	assert_true(ted._should_auto_use_ultimate(), "150 px: thrown onto the three")
	var nodes: Array = [ted]
	nodes.append_array(hogs)
	await _free(nodes)


## River drops the kit only when it heals someone: a hero within its pickup
## radius of her who misses at least its heal. The panic rule (anyone below
## the panic HP anywhere) no longer fires it.
func test_supply_drop_waits_for_a_hurt_hero_in_its_reach() -> void:
	var river := await _hero(RIVER, Vector2(0, 0))
	var vlad := await _hero(VLAD, Vector2(0, 40))
	assert_false(river._should_auto_use_ultimate(), "everyone at full HP")
	_hurt(vlad, vlad.get_max_health() * 0.9)
	vlad.global_position = Vector2(300, 0)
	assert_false(river._should_auto_use_ultimate(), "hurt, but out of the kit's reach")
	vlad.global_position = Vector2(0, 40)
	assert_true(river._should_auto_use_ultimate(), "hurt and beside her")
	vlad.heal(vlad.get_max_health())
	_hurt(vlad, 20.0)
	assert_false(river._should_auto_use_ultimate(), "missing less than the kit's 30")
	_hurt(river, 40.0)
	assert_true(river._should_auto_use_ultimate(), "she counts herself")
	assert_true(river.use_ultimate(), "and drops it with no target")
	await wait_seconds(1.5)
	await _free([river, vlad])


# ---------------------------------------------------------------- Supply Drop

## heroes-4: the kit lands before it heals. It used to be added to the tree
## before its radius was set (50 px trigger, 60 px ring), its pickup area slid
## down the 100 px fall path, and River's own pickup mid-air made it fade
## before it landed.
func test_the_supply_drop_heals_once_it_has_landed() -> void:
	var river := await _hero(RIVER, Vector2(0, 0))
	var north := await _hero(VLAD, Vector2(0, -110))
	var south := await _hero(TED, Vector2(0, 110))
	for h: HeroBase in [river, north, south]:
		_hurt(h, 40.0)
	var hp_river: float = river.get_health()
	var hp_north: float = north.get_health()
	var hp_south: float = south.get_health()
	var before: Array[Node] = get_children()
	_ult(river).execute(river)
	var kit := _new_child(before, "MediKit") as MediKit
	assert_true(kit != null, "a kit")
	if kit == null:
		await _free([river, north, south])
		return
	var shape := (kit.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	assert_near(shape.radius, 60.0, 0.001, "the trigger is the drawn 60 px ring")
	assert_eq(kit.global_position, river.global_position, "it lands at her feet")
	await wait_seconds(0.3)
	assert_false(kit.landed)
	assert_near(river.get_health(), hp_river, 0.001, "nothing heals during the fall")
	await wait_seconds(0.35)
	assert_true(is_instance_valid(kit) and kit.landed, "landed after 0.5 s")
	assert_near(river.get_health(), hp_river + 30.0, 0.001, "River, on the spot, is healed once")
	assert_near(north.get_health(), hp_north, 0.001, "110 px north: outside (the fall path healed it)")
	assert_near(south.get_health(), hp_south, 0.001, "110 px south: outside")
	await wait_seconds(0.8)
	assert_false(is_instance_valid(kit), "nobody else hurt in its radius: gone")
	await _free([river, north, south])


## A hero at full HP does not use the kit up: River drops it unhurt and a hurt
## Vlad who walks onto it later is healed.
func test_a_hero_at_full_hp_leaves_the_kit_for_the_hurt() -> void:
	var river := await _hero(RIVER, Vector2(0, 0))
	var vlad := await _hero(VLAD, Vector2(400, 0))
	_hurt(vlad, 40.0)
	var hp: float = vlad.get_health()
	var before: Array[Node] = get_children()
	_ult(river).execute(river)
	var kit := _new_child(before, "MediKit") as MediKit
	await wait_seconds(1.0)
	assert_true(is_instance_valid(kit) and kit.landed, "River at full HP left it lying")
	vlad.global_position = Vector2(20, 0)
	await wait_physics_frames(3)
	assert_near(vlad.get_health(), hp + 30.0, 0.001, "Vlad walks over it and is healed")
	await wait_seconds(0.8)
	assert_false(is_instance_valid(kit), "then it is gone")
	await _free([river, vlad])


# ---------------------------------------------------------------- monster ability 2

## Grount at Stage III fights a hero 60 px away with Ram Dash and Front Cleave
## ready: the dash goes first (it used to wait for an Approach gap close).
func test_ram_dash_is_used_in_a_fight() -> void:
	var g := (await spawn_frozen(GROUNT, Vector2(0, 0))) as MonsterBase
	evolve_to(g, 3)
	g._update_strategy()
	assert_eq(g.strategy, MonsterBase.Strategy.HUNT)
	var v := await _hero(VLAD, Vector2(60, 0))
	g.set_target(v)
	assert_true(g._ability_2_fight_ready(), "ready, a hero, in reach")
	g._choose_and_use_ability_combo()
	assert_true(g.get_ability_cooldown("ability_2") > 0.0, "Ram Dash cast in the fight")
	assert_near(g._ability_2_rest, g.strategy_profile.fight_ability_2_interval, 0.001, "then a 15 s rest")
	await wait_seconds(0.6)
	assert_true(g.is_ability_ready("ability_1"), "the cleave waits for the next step")
	g.ability_cooldowns["ability_1"] = 2.0
	g.ability_cooldowns["ability_3"] = 10.0
	g.ability_cooldowns["ability_2"] = 0.0
	assert_false(g._ability_2_fight_ready(), "ready again after its 5 s cooldown, but resting")
	assert_false(g._is_attack_ready(), "dash resting, cleave spent: nothing to swing")
	g._ability_2_rest = 0.0
	assert_true(g._is_attack_ready(), "the dash alone is a reason to act")
	await _free([g, v])


## Farming, a cornered Grount keeps the dash for his escape; Gorrak's Tusk Axe
## is no escape, so he throws it in that fight too. A strategy's
## fight_ability_2_interval of 0 turns the rule off.
func test_ability_2_in_a_fight_follows_the_strategy() -> void:
	var g := (await spawn_frozen(GROUNT, Vector2(0, 0))) as MonsterBase
	var k := (await spawn_frozen(GORRAK, Vector2(3000, 0))) as MonsterBase
	var n := (await spawn_frozen(NYXA, Vector2(-3000, 0))) as MonsterBase
	var heroes: Array[Node2D] = []
	for m: MonsterBase in [g, k, n]:
		m.strategy = MonsterBase.Strategy.FARM
		var v := await _hero(VLAD, m.global_position + Vector2(60, 0))
		heroes.append(v)
		m.set_target(v)
	assert_false(g._ability_2_fight_ready(), "Grount farming: the dash is his escape")
	assert_false(n._ability_2_fight_ready(), "Nyxa farming: the swoop is her escape")
	assert_true(k._ability_2_fight_ready(), "Gorrak farming: the axe is thrown")
	g.strategy = MonsterBase.Strategy.AMBUSH
	n.strategy = MonsterBase.Strategy.HUNT
	assert_true(g._ability_2_fight_ready())
	assert_true(n._ability_2_fight_ready())
	var off := g.strategy_profile.duplicate() as MonsterStrategy
	off.fight_ability_2_interval = 0.0
	g.strategy_profile = off
	assert_false(g._ability_2_fight_ready(), "fight_ability_2_interval 0: off")
	var nodes: Array = [g, k, n]
	nodes.append_array(heroes)
	await _free(nodes)


# ---------------------------------------------------------------- warband

## monsters-5: Gorrak's own warband (Call of the Herd) is spared by his
## abilities, so the stomp's target count and the camp choice skip it.
func test_gorraks_warband_is_no_prey() -> void:
	var g := (await spawn_frozen(GORRAK, Vector2(0, 0))) as MonsterBase
	var v := await _hero(VLAD, Vector2(0, 60))
	var hog_a := (await spawn_frozen(HOG, Vector2(60, 0))) as MobBase
	var hog_b := (await spawn_frozen(HOG, Vector2(-60, 0))) as MobBase
	g.strategy = MonsterBase.Strategy.AMBUSH
	g.set_target(v)
	assert_eq(g._count_slam_targets(), 3, "the hero and two Hogs")
	hog_a.join_warband(g, 20.0)
	hog_b.join_warband(g, 20.0)
	assert_eq(g._count_slam_targets(), 1, "his warband does not count: one real target")
	await _free([g, v, hog_a, hog_b])


func test_gorrak_does_not_walk_to_a_camp_of_his_own_warband() -> void:
	var g := (await spawn_frozen(GORRAK, Vector2(0, 0))) as MonsterBase
	evolve_to(g, 2)
	var mgr := SpawnManager.new()
	mgr.auto_activate_on_ready = false
	mgr.add_to_group(&"SpawnManager")
	add_child(mgr)
	var hogs_camp := _camp(mgr, HOG, Vector2(300, 0))
	hogs_camp.virtual_count = 0
	var hogs: Array[MobBase] = []
	for i in 3:
		var h := (await spawn_frozen(HOG, Vector2(300 + 30 * i, 0))) as MobBase
		hogs_camp.spawned_mobs.append(h)
		hogs.append(h)
	var bats := _camp(mgr, BAT, Vector2(1500, 0))
	assert_eq(g._pick_camp(), hogs_camp, "three Hogs close by: his camp at Stage 2")
	for h in hogs:
		h.join_warband(g, 20.0)
	assert_eq(g._pick_camp(), bats, "his own warband is no prey: the Bat camp")
	var nodes: Array = [g, mgr]
	nodes.append_array(hogs)
	await _free(nodes)


func _camp(mgr: SpawnManager, mob_path: String, pos: Vector2) -> MobSpawnArea:
	var area := (load(AREA) as PackedScene).instantiate() as MobSpawnArea
	area.mob_scene = load(mob_path)
	area.mob_count = 3
	area.auto_spawn_on_ready = false
	area.position = pos
	mgr.add_child(area)
	area.virtual_count = 3
	mgr.active_spawn_areas.append(area)
	return area


# ---------------------------------------------------------------- stand-off

## Ranges to an evolved monster are measured from the edge of his grown body:
## Grount at Stage III (x1.5) reaches half a standard body further out, and
## Vlad's 50 px Blood Strike lands from 60 px of his centre.
func test_an_evolved_monster_is_hit_from_the_edge_of_his_body() -> void:
	var g := (await spawn_frozen(GROUNT, Vector2(0, 0))) as MonsterBase
	assert_near(g.reach_bonus(), 0.0, 0.001, "Stage I: a standard body")
	evolve_to(g, 3)
	await wait_seconds(0.7)  # the stage scale tween
	assert_near(g.scale.x, 1.5, 0.001)
	var body := ((g.get_node("Body/CollisionShape2D") as CollisionShape2D).shape as CircleShape2D).radius
	assert_near(g.reach_bonus(), body * 0.5, 0.01, "Stage III: half a body more")
	var v := await _hero(VLAD, Vector2(60, 0))
	v.set_target(g)
	assert_near(v.distance_to_target(), 60.0 - g.reach_bonus(), 0.01, "measured from his edge")
	var hp: float = g.get_health()
	(v.get_node("AbilitySystem") as AbilitySystem).basic_attack.execute(v, g)
	assert_true(g.get_health() < hp, "Blood Strike lands from 60 px (50 + his growth)")
	await _free([g, v])


## monsters-6: a monster is MELEE. In a fight, between casts (every ability
## on cooldown) and with its target inside its reach and beyond min_distance,
## it holds the spot it reached: no strafing and no preferred distance. (The
## per-stage strafe numbers and the scenes' preferred_distance were never read
## and are gone.)
func test_a_monster_holds_its_spot_in_a_fight_between_casts() -> void:
	var region := await bake_nav_rect(Rect2(-600, -600, 1200, 1200))
	for path: String in [GROUNT, NYXA, GORRAK]:
		var m := (await spawn_entity(path, Vector2.ZERO)) as MonsterBase
		evolve_to(m, 3)  # HUNT: it fights the hero
		_set_all_cooldowns(m, 100.0)
		var reach: float = m.attack_range
		var v := await _hero(VLAD, Vector2(reach * 0.6, 0))
		for i in 120:
			if active_state_of(m) == "Fight":
				break
			_set_all_cooldowns(m, 100.0)
			await wait_physics_frames(1)
		assert_eq(active_state_of(m), "Fight", "%s fights the hero" % m.name)
		var d: float = m.distance_to_target()
		assert_true(d >= m.min_distance and d <= reach, "%s: the hero inside its band (%.0f px)" % [m.name, d])
		var walked := 0.0
		var last: Vector2 = m.global_position
		for i in 60:
			_set_all_cooldowns(m, 100.0)
			await wait_physics_frames(1)
			walked += m.global_position.distance_to(last)
			last = m.global_position
		assert_eq(active_state_of(m), "Fight", "%s still fights" % m.name)
		assert_true(walked < 1.0, "%s holds its spot between casts (walked %.1f px)" % [m.name, walked])
		await _free([m, v])
	await _free([region])
	await wait_physics_frames(6)


func _set_all_cooldowns(m: MonsterBase, seconds: float) -> void:
	for key in m.ability_cooldowns.keys():
		m.ability_cooldowns[key] = seconds


## Vlad and Ted come at a Stage III Grount from behind (north of his feet,
## where y-sort hides them behind his body). They stop at the edge of his body
## and walk round to their own sides (Vlad 20 degrees, Ted 160: beside him,
## slightly in front), so they neither stack nor stand behind him, and they hit.
func test_melee_heroes_take_their_own_sides_of_a_big_monster() -> void:
	var region := await bake_nav_rect(Rect2(-600, -600, 1200, 1200))
	var g := (await spawn_frozen(GROUNT, Vector2(0, 0))) as MonsterBase
	evolve_to(g, 3)
	await wait_seconds(0.7)
	var body: float = ((g.get_node("Body/CollisionShape2D") as CollisionShape2D).shape as CircleShape2D).radius * g.scale.x
	var vlad := (await spawn_entity(VLAD, Vector2(-10, -150))) as HeroBase
	var ted := (await spawn_entity(TED, Vector2(10, -150))) as HeroBase
	for h: HeroBase in [vlad, ted]:
		h.auto_use_ultimate = false
		h.auto_use_active = false
	await wait_seconds(5.0)
	for h: HeroBase in [vlad, ted]:
		var off: Vector2 = h.global_position - g.global_position
		assert_true(off.length() >= body, "%s stands outside his body (%.0f px, body %.0f)" % [h.name, off.length(), body])
		assert_true(off.y > 0.0, "%s is in front of or beside him, not behind (%s)" % [h.name, str(off)])
	assert_true(vlad.global_position.x > g.global_position.x and ted.global_position.x < g.global_position.x,
			"Vlad on his right, Ted on his left")
	assert_true(vlad.global_position.distance_to(ted.global_position) > 80.0, "not stacked")
	assert_true(g.get_health() < g.get_max_health(), "and they hit him")
	await _free([g, vlad, ted, region])
	await wait_physics_frames(6)


## The four heroes start apart (they used to start 38 px apart, two pairs on
## top of each other), each on the world's baked navigation mesh.
func test_the_heroes_spawn_apart_on_walkable_ground() -> void:
	var world := (load("res://Scenes/World/World.tscn") as PackedScene).instantiate()
	var spawns: Array[Vector2] = []
	for hero in world.get_node("Heros").get_children():
		spawns.append((hero as Node2D).position)
	assert_eq(spawns.size(), 4)
	for i in spawns.size():
		for j in range(i + 1, spawns.size()):
			assert_true(spawns[i].distance_to(spawns[j]) >= 80.0, "%s and %s are 80 px apart or more" % [spawns[i], spawns[j]])
	var navpoly := (world.get_node("Navigation") as NavigationRegion2D).navigation_polygon
	var map := NavigationServer2D.map_create()
	NavigationServer2D.map_set_active(map, true)
	var rid := NavigationServer2D.region_create()
	NavigationServer2D.region_set_map(rid, map)
	NavigationServer2D.region_set_navigation_polygon(rid, navpoly)
	assert_true(await wait_for_nav_map(map, navpoly.vertices[0]), "the map synchronized")
	for p in spawns:
		assert_true(NavigationServer2D.map_get_closest_point(map, p).distance_to(p) < 1.5, "%s is walkable" % p)
	NavigationServer2D.free_rid(rid)
	NavigationServer2D.free_rid(map)
	world.free()
