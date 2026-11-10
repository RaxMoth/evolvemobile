extends TestCase

## Nyxa, the Dusk Matriarch (README "Nyxa"): her scene wires the gamedesign
## v9 kit on the shared monster framework (reach 110, keeps 55 px, leaves Fight
## past 150; Sonic Screech, Shadow Swoop, Night Swarm, the Blood Drinker
## passive), her per-stage numbers, the Night Swarm aura (locked below Stage 2,
## bites on the cast and every tick_interval through tick_active, heals her,
## ends with her), the F3 line (monster id, swarm state), the VfxManager swarm
## ring that follows her, her CharacterDef (locked, 2,500 Leaves, Lv.3 gate,
## met after 3 hunts) and the tree nodes that act on her own ability copies.
## Shared .tres are never touched: every check runs on her spawned copies.

const NYXA := "res://Scenes/NPCs/Monster/Nyxa/Nyxa.tscn"
const NYXA_SWARM := "res://Scenes/NPCs/Monster/Nyxa/abilities/nyxa_night_swarm.tres"
const NYXA_MOTION := "res://Assets/Characters/nyxa/nyxa_motion.tres"
const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const TREE := &"monster_nyxa"
## Her capstones wait for their code (batch 6.6): data only until then.
const HIDDEN_NODES: Array[StringName] = [&"ny_rebirth", &"ny_echo", &"ny_brood"]


## Her numbers are the stock ones: no purchase from an earlier file applies,
## and the tree ranks bought here never leak into later files.
func before_each() -> void:
	if is_isolated():
		PersistedData.wipe_progress(false)


func after_each() -> void:
	if is_isolated():
		PersistedData.wipe_progress(false)


func _nyxa(pos: Vector2 = Vector2.ZERO) -> MonsterBase:
	return (await spawn_frozen(NYXA, pos)) as MonsterBase


func _hero(pos: Vector2) -> EntityBase:
	return (await spawn_frozen(VLAD, pos)) as EntityBase


func _free(nodes: Array) -> void:
	for n: Node in nodes:
		if is_instance_valid(n):
			n.queue_free()
	await wait_frames(1)


## Evolve to `stage` (gain_xp checks one threshold per call).
func _evolve(m: MonsterBase, stage: int) -> void:
	while m.get_stage() < stage:
		m.gain_xp(1000.0)


# ---------- the scene ----------

func test_scene_wires_her_kit() -> void:
	var n := await _nyxa()
	assert_eq(n.monster_stats.monster_id, &"nyxa")
	assert_eq(n.monster_stats.monster_type, "Dusk Matriarch")
	assert_eq(n.attack_range, 110.0, "reach 110")
	assert_eq(n.max_distance, 150.0, "leaves Fight past 150 px")
	assert_eq(n.preferred_distance, 55.0, "keeps 55 px (the scene root's spacing)")
	assert_eq(n.min_distance, 20.0)
	assert_eq(n.combat_role, Types.CombatRole.MELEE)
	var screech := n.ability_1 as BullFrontCleave
	var swoop := n.ability_2 as BullRamDash
	var swarm := n.ability_3 as NightSwarm
	assert_true(screech != null and screech.ability_name == "Sonic Screech", "ability 1: Sonic Screech")
	assert_true(swoop != null and swoop.ability_name == "Shadow Swoop", "ability 2: Shadow Swoop")
	assert_true(swarm != null and swarm.ability_name == "Night Swarm", "ability 3: Night Swarm")
	assert_true(n.passive_ability != null and n.passive_ability.ability_name == "Blood Drinker", "the passive slot")
	if screech == null or swoop == null or swarm == null or n.passive_ability == null:
		await _free([n])
		return
	assert_eq(n.passive_ability.ability_type, AbilityBase.AbilityType.PASSIVE)
	assert_eq(swarm.ability_type, AbilityBase.AbilityType.ULTIMATE)
	assert_true(swarm != load(NYXA_SWARM), "a per-entity copy")
	assert_eq([screech.lifesteal_pct, swoop.lifesteal_pct, swarm.lifesteal_pct], [0.2, 0.3, 0.25], "lifesteal 20/30/25%")
	assert_eq(swoop.dash_stop_short, -60.0, "she swoops 60 px through the target")
	assert_eq(swoop.get_reach(), 200.0, "260 px minus the overshoot")
	assert_eq(screech.cone_range, 110.0)
	var p := n.strategy_profile
	assert_eq([p.ambush_from_stage, p.hunt_from_stage, p.ambush_max_heroes], [2, 3, 1])
	assert_eq([p.hero_awareness_radius, p.isolation_radius, p.escape_dash_radius], [450.0, 280.0, 140.0])
	assert_eq(p.farm_max_mob_health, [60.0, 60.0, 1000.0] as Array[float], "Bats only until Stage 3")
	assert_true(p.escape_with_ability_2, "Shadow Swoop is her escape")
	await _free([n])


## The motion profile's full speed (the walk cycle's no-slide speed) is her
## Stage 1 move speed.
func test_motion_full_speed_is_her_stage_1_speed() -> void:
	var n := await _nyxa()
	var motion := load(NYXA_MOTION) as RigProfile
	assert_eq(motion.full_speed, n.monster_stats.stage_1_speed)
	assert_eq(motion.body_plan, RigProfile.BodyPlan.FLYER)
	await _free([n])


# ---------- stages ----------

## HP 600/950/1250 at 150 and 400 XP, speed 85/105/125; Screech 8/10/8 in a
## 50/60/70 degree cone, Swoop 12/16/22; Night Swarm locked at Stage 1, then
## 4 a bite in 110 px every 18 s, then 5 in 140 px every 14 s.
func test_stage_numbers() -> void:
	var n := await _nyxa()
	var screech := n.ability_1 as BullFrontCleave
	var swarm := n.ability_3 as NightSwarm
	var rows: Array[Array] = [
		[1, 600.0, 85.0, 8.0, 50.0, 12.0],
		[2, 950.0, 105.0, 10.0, 60.0, 16.0],
		[3, 1250.0, 125.0, 8.0, 70.0, 22.0],
	]
	assert_eq(n.get_evolution_threshold(), 150)
	for row: Array in rows:
		_evolve(n, int(row[0]))
		var tag := "stage %d" % row[0]
		assert_eq(n.get_max_health(), row[1], tag + " HP")
		assert_eq(n.get_health(), row[1], tag + ": evolving heals to full")
		assert_eq(n._get_move_speed(), row[2], tag + " speed")
		assert_eq(n.effective_ability_damage(screech), row[3], tag + " screech (the per-stage table, no stage multiplier)")
		assert_eq(screech.cone_angle, row[4], tag + " cone")
		assert_eq(n.effective_ability_damage(n.ability_2), row[5], tag + " swoop")
		if row[0] == 1:
			assert_eq(n.get_evolution_threshold(), 150)
			assert_false(swarm.is_unlocked_at(1), "no swarm at Stage 1")
			assert_eq(swarm.cooldown, AbilityBase.LOCKED_COOLDOWN)
		elif row[0] == 2:
			assert_eq(n.get_evolution_threshold(), 400)
			assert_eq([swarm.damage, swarm.area_of_effect, swarm.cooldown], [4.0, 110.0, 18.0])
		else:
			assert_eq([swarm.damage, swarm.area_of_effect, swarm.cooldown], [5.0, 140.0, 14.0])
	await _free([n])


func test_swarm_cannot_be_cast_before_stage_2() -> void:
	var n := await _nyxa()
	var v := await _hero(Vector2(60, 0))
	assert_false(n._cast("ability_3", n.ability_3, v), "locked at Stage 1")
	assert_false((n.ability_3 as NightSwarm).is_active())
	_evolve(n, 2)
	assert_true(n._cast("ability_3", n.ability_3, v), "open at Stage 2")
	assert_true((n.ability_3 as NightSwarm).is_active())
	assert_eq(n.get_ability_cooldown("ability_3"), 18.0)
	await _free([n, v])


# ---------- Night Swarm ----------

## Cast at Stage 2 (4 a bite, 110 px, 3.5 s): the first bite lands on the
## first step, then one every 0.5 s through the end (8 bites); a hero out of
## reach is never bitten; each bite heals her for 25% of what landed; the
## shared .tres never runs.
func test_swarm_bites_every_tick_and_heals_her() -> void:
	var n := await _nyxa()
	var near := await _hero(Vector2(60, 0))
	var far := await _hero(Vector2(300, 0))
	_evolve(n, 2)
	var swarm := n.ability_3 as NightSwarm
	var bites: Dictionary[Node, int] = {near: 0, far: 0}
	var landed: Array[float] = [0.0]
	var on_hit := func(packet: DamagePacket) -> void:
		if packet.ability == swarm and bites.has(packet.target):
			bites[packet.target] += 1
			landed[0] += packet.amount
	EventBus.damage_applied.connect(on_hit)
	n.current_health = n.get_max_health() - 300.0
	var hp: float = n.get_health()
	assert_true(n._cast("ability_3", swarm, near))
	assert_near(swarm.time_left(), 3.5, 0.0001)
	var steps := 0
	while swarm.is_active() and steps < 40:
		swarm.tick_active(n, 0.25)
		steps += 1
	EventBus.damage_applied.disconnect(on_hit)
	assert_eq(steps, 14, "3.5 s in 0.25 s steps")
	assert_eq(bites[near], 8, "a bite on the cast, then every 0.5 s")
	assert_eq(bites[far], 0, "300 px is out of the swarm")
	assert_near(landed[0], 8.0 * 4.0, 0.0001, "4 a bite")
	assert_near(n.get_health(), hp + landed[0] * 0.25, 0.0001, "healed for a quarter")
	swarm.tick_active(n, 1.0)
	assert_eq(bites[near], 8, "over: no more bites")
	assert_false((load(NYXA_SWARM) as NightSwarm).is_active(), "the shared .tres never runs")
	await _free([n, near, far])


## The aura follows her: it bites around where she is now.
func test_swarm_follows_her() -> void:
	var n := await _nyxa()
	var v := await _hero(Vector2(400, 0))
	_evolve(n, 2)
	var swarm := n.ability_3 as NightSwarm
	var hp: float = v.get_health()
	swarm.execute(n, null, 4.0)
	swarm.tick_active(n, 0.25)
	assert_eq(v.get_health(), hp, "out of reach where she cast it")
	n.global_position = Vector2(340, 0)
	swarm.tick_active(n, 0.25)
	assert_true(v.get_health() < hp, "bitten once she flew to it")
	await _free([n, v])


func test_swarm_ends_when_she_dies() -> void:
	var n := await _nyxa()
	_evolve(n, 2)
	var swarm := n.ability_3 as NightSwarm
	swarm.execute(n, null, 4.0)
	assert_true(swarm.is_active())
	n.current_health = 0.0
	swarm.tick_active(n, 0.1)
	assert_false(swarm.is_active(), "no swarm without her")
	assert_eq(swarm.time_left(), 0.0)
	await _free([n])


## Its cast centre is Nyxa, so the combo's slam_min_targets (1) counts the
## heroes around HER, not around her target.
func test_swarm_counts_the_heroes_around_her() -> void:
	var n := await _nyxa()
	var near := await _hero(Vector2(80, 0))
	var target := await _hero(Vector2(0, 300))
	_evolve(n, 2)
	n.target = target.get_node(^"Body")
	n.target_entity = target
	assert_eq(n.ability_3.get_cast_center(n, target), n.global_position)
	assert_eq(n._count_slam_targets(), 1, "only the hero inside 110 px of her")
	await _free([n, near, target])


# ---------- F3 ----------

func test_f3_line_shows_the_monster_id_and_the_swarm() -> void:
	var n := await _nyxa()
	var line := n.debug_meta_line()
	assert_true(line.contains("[nyxa] S1 "), line)
	assert_true(line.ends_with(" | swarm off"), line)
	_evolve(n, 2)
	var swarm := n.ability_3 as NightSwarm
	swarm.execute(n, null, 4.0)
	swarm.tick_active(n, 0.5)
	line = n.debug_meta_line()
	assert_true(line.contains("[nyxa] S2 "), line)
	assert_true(line.ends_with(" | swarm! 3.0 s left"), line)
	var g := (await spawn_frozen(GROUNT, Vector2(3000, 0))) as MonsterBase
	assert_true(g.debug_meta_line().contains("[grount] S1 "), g.debug_meta_line())
	assert_false(g.debug_meta_line().contains(" | "), "Grount's abilities report no live state")
	await _free([n, g])


# ---------- VFX ----------

## A cast swarm takes a VfxManager slot: two pooled ground rings (made once,
## under the manager's "Swarms" layer) at the swarm's radius that follow Nyxa
## and hide, kept, when it ends. Read-only: the swarm runs the same with or
## without the manager.
func test_vfx_swarm_ring_follows_her_and_ends() -> void:
	var vfx := VfxManager.new()
	add_child(vfx)
	var n := await _nyxa(Vector2(100, 100))
	_evolve(n, 3)
	var layer := vfx.get_node(^"Swarms")
	var rings: Array[RingPulse] = []
	for c in layer.get_children():
		rings.append(c as RingPulse)
	assert_eq(rings.size(), 2 * VfxManager.SWARM_CAP, "an outline and a bite ring per slot, made once")
	var swarm := n.ability_3 as NightSwarm
	assert_true(n._cast("ability_3", swarm, null), "cast (no hero needed)")
	assert_eq(vfx.swarms_live(), 1)
	var outline := rings[0]
	assert_true(outline.visible, "shown on the cast")
	assert_eq(outline.position, n.global_position)
	assert_near(outline.scale.x, swarm.area_of_effect, 0.001, "at the swarm's radius (Stage 3: 140)")
	assert_near(outline.width * outline.scale.x, vfx.swarm_width, 0.001, "the line keeps its width")
	assert_eq([outline.z_as_relative, outline.z_index], [false, 0], "on the ground, under the characters")
	assert_true(vfx.debug_line().contains("swarms 1/%d" % VfxManager.SWARM_CAP), vfx.debug_line())
	n.global_position = Vector2(180, 60)
	await wait_frames(1)
	assert_eq(outline.position, n.global_position, "follows her")
	swarm.tick_active(n, 10.0)
	await wait_frames(1)
	assert_eq(vfx.swarms_live(), 0, "ended")
	for ring in rings:
		assert_false(ring.visible, "hidden")
		assert_true(is_instance_valid(ring), "kept for the next swarm")
	vfx.queue_free()
	await _free([n])


# ---------- def and tree ----------

func test_her_def_is_a_locked_roster_monster() -> void:
	var def := GameManager.ROSTER.find(&"nyxa")
	assert_true(def != null and def.is_monster(), "in the roster's monsters")
	if def == null:
		return
	assert_true(GameManager.ROSTER.monsters.has(def))
	assert_eq(def.scene_path, NYXA)
	assert_eq(def.get_display_name(), "Nyxa")
	assert_eq(def.accent_token, &"monster2", "her palette token")
	assert_eq(def.role_filter, &"stalker")
	assert_eq(def.stage_names, PackedStringArray(["Duskling", "Night Hunter", "Dusk Matriarch"]))
	assert_false(def.unlocked_by_default, "bought with Leaves")
	assert_eq(def.unlock_cost, 2500)
	assert_eq(def.currency(), PersistedData.LEAVES)
	assert_eq(def.unlock_requires_level, 3)
	assert_eq(def.opponent_after_matches, 3, "the heroes meet her after 3 hunts")
	assert_false(def.tip.is_empty())
	assert_eq(def.skill_tree_id(), TREE)
	assert_true(MetaSkillManager.get_tree_def(TREE) == def.skill_tree, "her tree is registered")
	assert_eq(GameManager.ROSTER.default_monster_id, &"grount", "Grount stays the default quarry")
	var names: Array[String] = []
	for a in def.abilities():
		names.append(a.ability_name)
	assert_eq(names, ["Blood Drinker", "Sonic Screech", "Shadow Swoop", "Night Swarm"] as Array[String])


## Every node whose effect has code is shown; the capstones wait for 6.6.
func test_her_tree_shows_the_nodes_with_code() -> void:
	var tree := MetaSkillManager.get_tree_def(TREE)
	assert_true(tree != null)
	if tree == null:
		return
	for node in tree.nodes:
		assert_eq(node.hidden, HIDDEN_NODES.has(node.id), "%s hidden only while its code is missing" % node.id)


## Her tree's ability nodes act on her own copies and survive every stage's
## numbers: Thicker Swarm (radius x1.15), Endless Night (duration x1.3),
## Wide Shriek (+8 degrees), Thirst (+10% screech lifesteal).
func test_tree_nodes_act_on_her_copies() -> void:
	if not require_isolated():
		return
	for id: StringName in [&"ny_swarm", &"ny_swarmdur", &"ny_cone", &"ny_leech"]:
		PersistedData.set_skill_rank(TREE, id, 1)
	var n := await _nyxa()
	_evolve(n, 2)
	var swarm := n.ability_3 as NightSwarm
	var screech := n.ability_1 as BullFrontCleave
	assert_near(swarm.area_of_effect, 110.0 * 1.15, 0.001, "Thicker Swarm at Stage 2")
	assert_near(swarm.duration, 3.5 * 1.3, 0.001, "Endless Night")
	assert_near(screech.cone_angle, 60.0 + 8.0, 0.001, "Wide Shriek at Stage 2")
	assert_near(screech.lifesteal_pct, 0.3, 0.001, "Thirst")
	_evolve(n, 3)
	assert_near(swarm.area_of_effect, 140.0 * 1.15, 0.001, "and at Stage 3")
	var shared := load(NYXA_SWARM) as NightSwarm
	assert_eq([shared.area_of_effect, shared.duration], [110.0, 3.5], "the shared .tres is untouched")
	await _free([n])
