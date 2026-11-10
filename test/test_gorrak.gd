extends TestCase

## Gorrak, the Boar King (README "Gorrak"): his scene wires the gamedesign v6
## kit on the shared monster framework (reach 85, keeps 50 px, leaves Fight
## past 110; Cleaver Chop, Tusk Axe, Warcry Stomp, the Bristled Hide passive),
## his per-stage numbers and armour, the Tusk Axe (a point stepped through
## tick_active: out up to its range, stopped by walls, back to his hand, each
## target hit once a leg, never thrown twice at once, ends with him, thrown
## from Approach at a hero 110 px or more away, never as an escape), the
## in-place Warcry Stomp that stuns, the F3 line (monster id, axe state), the
## VfxManager axe sprite that follows the axe, his CharacterDef (locked, 3,000
## Leaves, Lv.3 gate, met after 6 hunts) and the tree nodes that act on his own
## ability copies. Shared .tres are never touched: every check runs on his
## spawned copies.

const GORRAK := "res://Scenes/NPCs/Monster/Gorrak/Gorrak.tscn"
const GORRAK_AXE := "res://Scenes/NPCs/Monster/Gorrak/abilities/gorrak_axe.tres"
const GORRAK_STOMP := "res://Scenes/NPCs/Monster/Gorrak/abilities/gorrak_stomp.tres"
const GORRAK_MOTION := "res://Assets/Characters/gorrak/gorrak_motion.tres"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const TREE := &"monster_gorrak"
## One frame of the 60 Hz sim.
const STEP := 1.0 / 60.0

## The axe whose hits _on_damage counts (_track), and its hits per target.
var _tracked: AbilityBase = null
var _hits: Dictionary[Node, int] = {}


## His numbers are the stock ones: no purchase from an earlier file applies,
## and the tree ranks bought here never leak into later files.
func before_each() -> void:
	# Every tree these tests seed is a monster's: the played side applies it.
	play_side(MatchRewards.Side.MONSTER)
	if is_isolated():
		PersistedData.wipe_progress(false)


func after_each() -> void:
	if EventBus.damage_applied.is_connected(_on_damage):
		EventBus.damage_applied.disconnect(_on_damage)
	_tracked = null
	_hits.clear()
	if is_isolated():
		PersistedData.wipe_progress(false)


func _gorrak(pos: Vector2 = Vector2.ZERO) -> MonsterBase:
	return (await spawn_frozen(GORRAK, pos)) as MonsterBase


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


## Steps the axe frame by frame until it is back (at most `max_steps`);
## returns the steps taken.
func _fly(axe: ThrownAxe, caster: MonsterBase, max_steps: int = 300) -> int:
	var steps := 0
	while axe.is_flying() and steps < max_steps:
		axe.tick_active(caster, STEP)
		steps += 1
	return steps


## Counts `ability`'s hits on each of `targets` into _hits (after_each stops).
func _track(ability: AbilityBase, targets: Array) -> void:
	_tracked = ability
	_hits.clear()
	for t: Node in targets:
		_hits[t] = 0
	if not EventBus.damage_applied.is_connected(_on_damage):
		EventBus.damage_applied.connect(_on_damage)


func _on_damage(packet: DamagePacket) -> void:
	if packet.ability == _tracked and _hits.has(packet.target):
		_hits[packet.target] += 1


# ---------- the scene ----------

func test_scene_wires_his_kit() -> void:
	var g := await _gorrak()
	assert_eq(g.monster_stats.monster_id, &"gorrak")
	assert_eq(g.monster_stats.monster_type, "Boar King")
	assert_eq(g.attack_range, 85.0, "reach 85")
	assert_eq(g.max_distance, 110.0, "leaves Fight past 110 px")
	assert_eq(g.preferred_distance, 50.0, "keeps 50 px (the scene root's spacing)")
	assert_eq(g.min_distance, 20.0)
	assert_eq(g.combat_role, Types.CombatRole.MELEE)
	var chop := g.ability_1 as BullFrontCleave
	var axe := g.ability_2 as ThrownAxe
	var stomp := g.ability_3 as BullGroundSlam
	assert_true(chop != null and chop.ability_name == "Cleaver Chop", "ability 1: Cleaver Chop")
	assert_true(axe != null and axe.ability_name == "Tusk Axe", "ability 2: Tusk Axe")
	assert_true(stomp != null and stomp.ability_name == "Warcry Stomp", "ability 3: Warcry Stomp")
	assert_true(g.passive_ability != null and g.passive_ability.ability_name == "Bristled Hide", "the passive slot")
	if chop == null or axe == null or stomp == null or g.passive_ability == null:
		await _free([g])
		return
	assert_eq(g.passive_ability.ability_type, AbilityBase.AbilityType.PASSIVE)
	assert_eq(axe.ability_type, AbilityBase.AbilityType.ACTIVE)
	assert_eq(stomp.ability_type, AbilityBase.AbilityType.ULTIMATE)
	assert_true(axe != load(GORRAK_AXE), "a per-entity copy")
	assert_eq([axe.axe_speed, axe.hit_radius, axe.returns, axe.stun_duration], [520.0, 28.0, true, 0.0])
	assert_eq(axe.get_reach(), 260.0, "the axe flies 260 px")
	assert_eq([stomp.leap_distance, stomp.stun_duration, stomp.jump_duration], [0.0, 0.6, 0.6], "stomps in place, stuns 0.6 s")
	assert_true(stomp.is_unlocked_at(1), "the stomp is his from Stage 1")
	assert_eq(chop.cone_range, 85.0)
	assert_eq([chop.lifesteal_pct, axe.lifesteal_pct, stomp.lifesteal_pct], [0.0, 0.0, 0.0], "no lifesteal")
	var p := g.strategy_profile
	assert_eq([p.hero_awareness_radius, p.cornered_radius], [350.0, 90.0])
	assert_eq([p.retreat_hp_pct, p.retreat_min_heroes], [0.25, 3])
	assert_eq([p.rest_hp_pct, p.resume_hp_pct, p.rest_regen_pct_per_sec], [0.4, 0.75, 0.008])
	assert_eq(p.farm_max_mob_health, [60.0, 150.0, 1000.0] as Array[float])
	assert_eq([p.dash_min_range, p.dash_cleave_window, p.slam_min_targets], [110.0, 99.0, 2])
	assert_false(p.escape_with_ability_2, "the axe is no escape")
	await _free([g])


## The motion profile's full speed (the walk cycle's no-slide speed) is his
## Stage 1 move speed.
func test_motion_full_speed_is_his_stage_1_speed() -> void:
	var g := await _gorrak()
	var motion := load(GORRAK_MOTION) as RigProfile
	assert_eq(motion.full_speed, g.monster_stats.stage_1_speed)
	assert_eq(motion.body_plan, RigProfile.BodyPlan.HUMANOID, "an upright boar king: the humanoid moves")
	await _free([g])


# ---------- stages ----------

## HP 1100/1450/1500 at 150 and 500 XP (Stage 3: the design's 1600 retuned to
## 1500 for 6.5's balance), speed 56/64/74; Cleaver Chop 14/18/18
## in a 70/80/90 degree cone, Tusk Axe 10/14/18 every 7/6/5 s, Warcry Stomp
## 12/18/22 within 100/130/160 px every 18/15/12 s.
func test_stage_numbers() -> void:
	var g := await _gorrak()
	var chop := g.ability_1 as BullFrontCleave
	var axe := g.ability_2 as ThrownAxe
	var stomp := g.ability_3 as BullGroundSlam
	var rows: Array[Array] = [
		[1, 1100.0, 56.0, 14.0, 70.0, 10.0, 7.0, 12.0, 100.0, 18.0, 150],
		[2, 1450.0, 64.0, 18.0, 80.0, 14.0, 6.0, 18.0, 130.0, 15.0, 500],
		[3, 1500.0, 74.0, 18.0, 90.0, 18.0, 5.0, 22.0, 160.0, 12.0, 999999],
	]
	for row: Array in rows:
		_evolve(g, int(row[0]))
		var tag := "stage %d" % row[0]
		assert_eq(g.get_max_health(), row[1], tag + " HP")
		assert_eq(g.get_health(), row[1], tag + ": evolving heals to full")
		assert_eq(g._get_move_speed(), row[2], tag + " speed")
		assert_eq(g.effective_ability_damage(chop), row[3], tag + " chop (the per-stage table, no stage multiplier)")
		assert_eq(chop.cone_angle, row[4], tag + " cone")
		assert_eq([g.effective_ability_damage(axe), axe.cooldown], [row[5], row[6]], tag + " axe")
		assert_eq([g.effective_ability_damage(stomp), stomp.slam_radius, stomp.cooldown], [row[7], row[8], row[9]], tag + " stomp")
		assert_eq(g.get_evolution_threshold(), row[10], tag + " next evolution")
	await _free([g])


## Bristled Hide: hits land x0.85 at Stage 1, x0.90 at Stage 2, in full at
## Stage 3 (MonsterStats.damage_taken_mult_per_stage).
func test_armour_cracks_at_stage_3() -> void:
	var g := await _gorrak()
	var v := await _hero(Vector2(3000, 0))
	for row: Array in [[1, 85.0], [2, 90.0], [3, 100.0]]:
		_evolve(g, int(row[0]))
		var hp: float = g.get_health()
		EventBus.deal_damage(v, g, 100.0)
		assert_near(hp - g.get_health(), row[1], 0.0001, "stage %d takes %d of 100" % row)
	await _free([g, v])


# ---------- Tusk Axe ----------

## Thrown at a hero 150 px away: it hits on the way out and again on the way
## back (10 a hit at Stage 1), flies its full 260 px, returns to his hand and
## starts its 7 s cooldown; the shared .tres never flies.
func test_axe_flies_out_and_back_hitting_twice() -> void:
	var g := await _gorrak()
	var v := await _hero(Vector2(150, 0))
	var axe := g.ability_2 as ThrownAxe
	_track(axe, [v])
	var hp: float = v.get_health()
	assert_true(g._cast("ability_2", axe, v), "thrown")
	assert_true(axe.is_flying())
	assert_eq(axe.axe_position, g.global_position, "from his hand")
	assert_eq(axe.direction(), Vector2.RIGHT, "at the hero")
	assert_eq(g.get_ability_cooldown("ability_2"), 7.0)
	var out_steps := 0
	var farthest := 0.0
	while not axe.is_returning() and axe.is_flying() and out_steps < 120:
		axe.tick_active(g, STEP)
		farthest = maxf(farthest, axe.axe_position.x)
		out_steps += 1
	assert_eq(_hits[v], 1, "one hit on the way out")
	assert_near(farthest, 260.0, 0.01, "out to its full range")
	var back_steps := _fly(axe, g)
	assert_false(axe.is_flying(), "back in his hand")
	assert_eq(axe.axe_position, g.global_position)
	assert_eq(_hits[v], 2, "and one on the way back")
	assert_near(hp - v.get_health(), 20.0, 0.0001, "10 a hit")
	assert_near((out_steps + back_steps) * STEP, 1.0, 2.0 * STEP, "520 px at 520 px/s: about 1 s in the air")
	assert_false((load(GORRAK_AXE) as ThrownAxe).is_flying(), "the shared .tres never flies")
	await _free([g, v])


## A hero beyond 260 px is never hit; one off the line is not hit either.
func test_axe_misses_what_it_does_not_reach() -> void:
	var g := await _gorrak()
	var target := await _hero(Vector2(400, 0))
	var aside := await _hero(Vector2(150, 120))
	var axe := g.ability_2 as ThrownAxe
	_track(axe, [target, aside])
	axe.execute(g, target, 10.0)
	_fly(axe, g)
	assert_eq(_hits[target], 0, "400 px is out of reach")
	assert_eq(_hits[aside], 0, "120 px off the line")
	await _free([g, target, aside])


## While the axe flies it cannot be thrown again, even off cooldown.
func test_axe_cannot_be_thrown_while_flying() -> void:
	var g := await _gorrak()
	var v := await _hero(Vector2(200, 0))
	var axe := g.ability_2 as ThrownAxe
	assert_true(g._cast("ability_2", axe, v))
	g.ability_cooldowns["ability_2"] = 0.0
	assert_false(axe.can_use(g))
	assert_false(g._cast("ability_2", axe, v), "no second throw mid-air")
	_fly(axe, g)
	assert_true(g._cast("ability_2", axe, v), "back in hand: throwable again")
	await _free([g, v])


## A wall (the edge of the navigation mesh) stops the outbound flight; the
## axe turns back from there.
func test_walls_stop_the_axe() -> void:
	var region := await bake_nav_rect(Rect2(-400, -400, 500, 800))
	var g := await _gorrak()
	var axe := g.ability_2 as ThrownAxe
	g.sprite.rotation = 0.0
	axe.execute(g, null, 10.0)
	var farthest := 0.0
	var steps := 0
	while axe.is_flying() and not axe.is_returning() and steps < 120:
		axe.tick_active(g, STEP)
		farthest = maxf(farthest, axe.axe_position.x)
		steps += 1
	assert_true(axe.is_returning(), "turned back")
	assert_true(farthest < 103.0 and farthest > 80.0, "stopped at the mesh edge (x 100): %.1f" % farthest)
	_fly(axe, g)
	assert_false(axe.is_flying())
	await _free([g, region])
	await wait_physics_frames(6)


func test_axe_ends_when_he_dies() -> void:
	var g := await _gorrak()
	var axe := g.ability_2 as ThrownAxe
	axe.execute(g, null, 10.0)
	axe.tick_active(g, STEP)
	assert_true(axe.is_flying())
	g.current_health = 0.0
	axe.tick_active(g, STEP)
	assert_false(axe.is_flying(), "no axe without him")
	await _free([g])


## Approach throws the axe at a hero 110 to 260 px away (dash_min_range 110,
## the axe's reach), aimed at it; closer, he walks in and chops instead.
func test_approach_throws_the_axe_from_range() -> void:
	var g := await _gorrak()
	var v := await _hero(Vector2(90, 0))
	var axe := g.ability_2 as ThrownAxe
	g.strategy = MonsterBase.Strategy.HUNT
	g.set_target(v)
	assert_false(g._try_gap_close(), "90 px is too close to throw")
	assert_false(axe.is_flying())
	v.global_position = Vector2(0, 200)
	assert_true(g._try_gap_close(), "200 px: thrown")
	assert_true(axe.is_flying())
	assert_near(g.sprite.rotation, PI / 2.0, 0.0001, "aimed at the hero")
	assert_eq(axe.direction(), Vector2.DOWN)
	await _free([g, v])


## Retreating, he never throws the axe away from a close hero as an escape.
func test_the_axe_is_no_escape() -> void:
	var region := await bake_nav_rect(Rect2(-2000, -2000, 4000, 4000))
	var g := await _gorrak()
	var heroes: Array[EntityBase] = []
	for pos: Vector2 in [Vector2(90, 0), Vector2(0, 150), Vector2(-150, 0)]:
		heroes.append(await _hero(pos))
	g.current_health = 0.2 * g.get_max_health()
	g._update_strategy()
	assert_eq(g.strategy, MonsterBase.Strategy.RETREAT)
	assert_true(g.is_ability_ready("ability_2"), "no escape throw")
	assert_false((g.ability_2 as ThrownAxe).is_flying())
	var nodes: Array = [g, region]
	nodes.append_array(heroes)
	await _free(nodes)
	await wait_physics_frames(6)


# ---------- Warcry Stomp ----------

## The stomp lands where he stands (cast centre = Gorrak, leap 0), so the
## combo counts the heroes around HIM; it stuns every target it hits.
func test_stomp_lands_in_place_and_stuns() -> void:
	var g := await _gorrak(Vector2(500, 500))
	var near := await _hero(Vector2(560, 500))
	var target := await _hero(Vector2(500, 700))
	g.set_target(target)
	var stomp := g.ability_3 as BullGroundSlam
	assert_eq(stomp.get_cast_center(g, target), g.global_position)
	assert_eq(g._count_slam_targets(), 1, "only the hero inside 100 px of him")
	assert_true(g._cast("ability_3", stomp, target), "open at Stage 1")
	await wait_seconds(stomp.jump_duration + 0.15)
	assert_eq(g.global_position, Vector2(500, 500), "he stays where he stomped")
	assert_true(near.is_stunned(), "the hero beside him is stunned")
	assert_true(near.get_health() < near.get_max_health(), "and hit")
	assert_false(target.is_stunned(), "200 px away: untouched")
	assert_eq((load(GORRAK_STOMP) as BullGroundSlam).stun_duration, 0.6, "the shared .tres is untouched")
	await _free([g, near, target])


# ---------- F3 ----------

func test_f3_line_shows_the_monster_id_and_the_axe() -> void:
	var g := await _gorrak()
	var line := g.debug_meta_line()
	assert_true(line.contains("[gorrak] S1 "), line)
	assert_true(line.ends_with(" | axe in hand"), line)
	var axe := g.ability_2 as ThrownAxe
	axe.execute(g, null, 10.0)
	axe.tick_active(g, STEP)
	assert_true(g.debug_meta_line().ends_with(" | axe! flying out"), g.debug_meta_line())
	while axe.is_flying() and not axe.is_returning():
		axe.tick_active(g, STEP)
	assert_true(g.debug_meta_line().ends_with(" | axe! flying back"), g.debug_meta_line())
	_fly(axe, g)
	assert_true(g.debug_meta_line().ends_with(" | axe in hand"), g.debug_meta_line())
	await _free([g])


# ---------- VFX ----------

## A thrown axe takes a VfxManager slot: the sprite is drawn at the axe's
## position, spins while it flies (clockwise thrown to the right) and frees
## its slot once the axe is back. Read-only: the axe flies the same with or
## without the manager.
func test_vfx_axe_spins_along_and_ends() -> void:
	var vfx := VfxManager.new()
	add_child(vfx)
	var g := await _gorrak(Vector2(100, 100))
	var v := await _hero(Vector2(300, 100))
	var axe := g.ability_2 as ThrownAxe
	assert_true(g._cast("ability_2", axe, v))
	assert_eq(vfx.axes_live(), 1, "a slot on the throw")
	assert_true(vfx.debug_line().contains("axes 1/%d" % VfxManager.AXE_CAP), vfx.debug_line())
	var a0: float = vfx.axe_angle(axe)
	assert_false(is_nan(a0), "drawn for this axe")
	await wait_frames(3)
	assert_true(axe.is_flying(), "his frames step it")
	var a1: float = vfx.axe_angle(axe)
	assert_true(wrapf(a1 - a0, -PI, PI) > 0.0, "spins clockwise thrown right (%.2f -> %.2f)" % [a0, a1])
	_fly(axe, g)
	await wait_frames(1)
	assert_eq(vfx.axes_live(), 0, "freed once back")
	assert_true(is_nan(vfx.axe_angle(axe)))
	vfx.queue_free()
	await _free([g, v])


# ---------- def and tree ----------

func test_his_def_is_a_locked_roster_monster() -> void:
	var def := GameManager.ROSTER.find(&"gorrak")
	assert_true(def != null and def.is_monster(), "in the roster's monsters")
	if def == null:
		return
	assert_true(GameManager.ROSTER.monsters.has(def))
	assert_eq(GameManager.ROSTER.monster_ids(), [&"grount", &"nyxa", &"gorrak"] as Array[StringName], "the third monster")
	assert_eq(def.scene_path, GORRAK)
	assert_eq(def.get_display_name(), "Gorrak")
	assert_eq(def.accent_token, &"monster3", "his palette token")
	assert_eq(def.role_filter, &"brute")
	assert_eq(def.stage_names, PackedStringArray(["Tusker", "Warlord", "Boar King"]))
	assert_false(def.unlocked_by_default, "bought with Leaves")
	assert_eq(def.unlock_cost, 3000)
	assert_eq(def.currency(), PersistedData.LEAVES)
	assert_eq(def.unlock_requires_level, 3)
	assert_eq(def.opponent_after_matches, 6, "the heroes meet him after 6 hunts")
	assert_false(def.tip.is_empty())
	assert_eq(def.skill_tree_id(), TREE)
	assert_true(MetaSkillManager.get_tree_def(TREE) == def.skill_tree, "his tree is registered")
	assert_eq(GameManager.ROSTER.default_monster_id, &"grount", "Grount stays the default quarry")
	var names: Array[String] = []
	for a in def.abilities():
		names.append(a.ability_name)
	assert_eq(names, ["Bristled Hide", "Cleaver Chop", "Tusk Axe", "Warcry Stomp"] as Array[String])


## Every node has its code and is shown, the three capstones since 6.6
## (test_monster_capstones).
func test_his_tree_shows_every_node() -> void:
	var tree := MetaSkillManager.get_tree_def(TREE)
	assert_true(tree != null)
	if tree == null:
		return
	for node in tree.nodes:
		assert_false(node.hidden, "%s is shown" % node.id)
	var ids: Array[StringName] = []
	for n in tree.capstones():
		ids.append(n.id)
	assert_eq(ids, [&"gk_whirl", &"gk_unstoppable", &"gk_warband"] as Array[StringName], "one capstone per branch")
	assert_eq(tree.max_tier(), 4)


## His tree's nodes act on his own copies and survive every stage's numbers:
## Wide Arc (+10 degrees), Honed Tusks (axe damage x1.2), Concussive Axe
## (0.5 s stun), Earthshaker (stomp radius x1.15), Ringing Ears (+0.25 s),
## Mud Armour (damage taken x0.95 on top of the armour).
func test_tree_nodes_act_on_his_copies() -> void:
	if not require_isolated():
		return
	for id: StringName in [&"gk_arc", &"gk_axedmg", &"gk_axestun", &"gk_stomp", &"gk_stompstun", &"gk_bark"]:
		PersistedData.set_skill_rank(TREE, id, 1)
	var g := await _gorrak()
	var v := await _hero(Vector2(150, 0))
	var chop := g.ability_1 as BullFrontCleave
	var axe := g.ability_2 as ThrownAxe
	var stomp := g.ability_3 as BullGroundSlam
	assert_near(chop.cone_angle, 70.0 + 10.0, 0.001, "Wide Arc at Stage 1")
	assert_near(axe.damage, 10.0 * 1.2, 0.001, "Honed Tusks")
	assert_near(axe.stun_duration, 0.5, 0.001, "Concussive Axe")
	assert_near(stomp.slam_radius, 100.0 * 1.15, 0.001, "Earthshaker")
	assert_near(stomp.stun_duration, 0.6 + 0.25, 0.001, "Ringing Ears")
	axe.execute(g, v, g.effective_ability_damage(axe))
	_fly(axe, g)
	assert_true(v.is_stunned(), "the axe stuns with Concussive Axe")
	var hp: float = g.get_health()
	EventBus.deal_damage(v, g, 100.0)
	assert_near(hp - g.get_health(), 100.0 * 0.95 * 0.85, 0.001, "Mud Armour on top of the Stage 1 armour")
	_evolve(g, 3)
	assert_near(chop.cone_angle, 90.0 + 10.0, 0.001, "Wide Arc at Stage 3")
	assert_near(axe.damage, 18.0 * 1.2, 0.001, "Honed Tusks at Stage 3")
	assert_near(stomp.slam_radius, 160.0 * 1.15, 0.001, "Earthshaker at Stage 3")
	var shared_axe := load(GORRAK_AXE) as ThrownAxe
	var shared_stomp := load(GORRAK_STOMP) as BullGroundSlam
	assert_eq([shared_axe.damage, shared_axe.stun_duration], [10.0, 0.0], "the shared axe .tres is untouched")
	assert_eq([shared_stomp.slam_radius, shared_stomp.stun_duration], [100.0, 0.6], "the shared stomp .tres is untouched")
	await _free([g, v])
