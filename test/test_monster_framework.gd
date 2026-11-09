extends TestCase

## The shared monster framework (README "Shared monster framework"): the
## per-monster combat numbers on MonsterStats, the stage's damage-taken
## multiplier, heal_self and lifesteal through AbilityBase.deal, the per-frame
## tick_active hook, the cast centre of the slam-target count, the
## escape_with_ability_2 switch, tree-modifiable cone angles and the slam's
## stun. Every default is Grount's old behaviour, so the shipped match is
## unchanged (tools/sim_trace.sh stays byte-identical). Shared .tres are never
## touched: a test that needs other numbers works on a duplicate.

const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"
const GROUNT_STATS := "res://Scenes/NPCs/Monster/Grount/grount_stats.tres"
const GROUNT_CLEAVE := "res://Scenes/NPCs/Monster/Grount/abilities/grount_front_cleave.tres"
const GROUNT_EVOLUTION := "res://Scenes/NPCs/Monster/Grount/abilities/grount_evolution.tres"
const EVOLUTION_ICON := "res://Assets/UI/Icons/Abilities/grount_passive_evolution.svg"
const NYXA_TREE := "res://Data/SkillTrees/monster_nyxa.tres"
const GORRAK_TREE := "res://Data/SkillTrees/monster_gorrak.tres"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"


## Counts MonsterBase's per-frame tick_active calls (an aura or a thrown axe
## would act here).
class TickProbe extends AbilityBase:
	var ticks: int = 0
	var seconds: float = 0.0
	var last_caster: Node2D = null

	func tick_active(caster: Node2D, delta: float) -> void:
		ticks += 1
		seconds += delta
		last_caster = caster


func _grount(pos: Vector2 = Vector2.ZERO) -> MonsterBase:
	return (await spawn_frozen(GROUNT, pos)) as MonsterBase


func _hero(pos: Vector2) -> EntityBase:
	return (await spawn_frozen(VLAD, pos)) as EntityBase


func _free(nodes: Array) -> void:
	for n: Node in nodes:
		if is_instance_valid(n):
			n.queue_free()
	await wait_frames(1)


# ---------- MonsterStats ----------

## The combat exports default to the constants MonsterBase had (80 px reach,
## Fight left past 100 px, no armour), and Grount's stats keep them.
func test_stats_defaults_are_grounts_old_constants() -> void:
	var fresh := MonsterStats.new()
	var grount := load(GROUNT_STATS) as MonsterStats
	for s: MonsterStats in [fresh, grount]:
		assert_eq(s.base_attack_range, 80.0)
		assert_eq(s.fight_leave_distance, 100.0)
		assert_true(s.damage_taken_mult_per_stage.is_empty(), "no armour")
		for stage in [0, 1, 2, 3, 4]:
			assert_eq(s.get_damage_taken_mult(stage), 1.0, "stage %d takes full damage" % stage)
	var armoured := MonsterStats.new()
	armoured.damage_taken_mult_per_stage = [0.85, 0.9]
	assert_eq(armoured.get_damage_taken_mult(1), 0.85)
	assert_eq(armoured.get_damage_taken_mult(2), 0.9)
	assert_eq(armoured.get_damage_taken_mult(3), 1.0, "a short table ends in full damage")


## Reach and the Fight leave distance come from the monster's own stats.
func test_reach_and_fight_leave_distance_read_the_stats() -> void:
	var g := await _grount()
	assert_eq(g.attack_range, 80.0, "Grount's reach")
	assert_eq(g.max_distance, 100.0, "Grount leaves Fight past 100 px")
	var stats := g.monster_stats.duplicate() as MonsterStats
	stats.base_attack_range = 110.0
	stats.fight_leave_distance = 150.0
	g.monster_stats = stats
	g._enter_stage()
	assert_eq(g.attack_range, 110.0, "a longer-reach monster")
	assert_eq(g.max_distance, 150.0)
	assert_eq((load(GROUNT_STATS) as MonsterStats).base_attack_range, 80.0, "the shared .tres is untouched")
	await _free([g])


## damage_taken_mult_per_stage scales every hit after the tree's own
## damage-taken nodes; the listeners and deal_damage see the final amount.
func test_stage_damage_taken_multiplier() -> void:
	var g := await _grount()
	var stats := g.monster_stats.duplicate() as MonsterStats
	stats.damage_taken_mult_per_stage = [0.5, 0.75]
	g.monster_stats = stats
	var hp: float = g.get_health()
	assert_near(EventBus.deal_damage(null, g, 100.0), 50.0, 0.0001, "stage 1 takes half")
	assert_near(g.get_health(), hp - 50.0, 0.0001)
	g.gain_xp(1000.0)
	assert_eq(g.get_stage(), 2)
	hp = g.get_health()
	assert_near(EventBus.deal_damage(null, g, 100.0), 75.0, 0.0001, "stage 2 takes three quarters")
	assert_near(g.get_health(), hp - 75.0, 0.0001)
	g.gain_xp(0.0)
	assert_eq(g.get_stage(), 3)
	assert_near(EventBus.deal_damage(null, g, 100.0), 100.0, 0.0001, "past the table: full damage")
	await _free([g])


# ---------- heal_self and lifesteal ----------

func test_heal_self_caps_at_max_and_never_revives() -> void:
	var g := await _grount()
	var max_hp: float = g.get_max_health()
	g.current_health = max_hp - 30.0
	g.heal_self(10.0)
	assert_near(g.get_health(), max_hp - 20.0, 0.0001)
	g.heal_self(500.0)
	assert_eq(g.get_health(), max_hp, "never above max HP")
	g.heal_self(-50.0)
	assert_eq(g.get_health(), max_hp, "a negative heal does nothing")
	g.current_health = 0.0
	g.heal_self(100.0)
	assert_eq(g.get_health(), 0.0, "a dead monster is not healed back")
	await _free([g])


## AbilityBase.deal on a monster's own ability copy: lifesteal_pct of the
## damage that landed comes back through MonsterBase.heal_self.
func test_monster_lifesteal_through_deal() -> void:
	var g := await _grount()
	var v := await _hero(Vector2(60, 0))
	var cleave := g.ability_1
	assert_eq(cleave.lifesteal_pct, 0.0, "Grount has no lifesteal")
	cleave.lifesteal_pct = 0.25
	g.current_health = g.get_max_health() - 100.0
	var hp: float = g.get_health()
	var landed: float = cleave.deal(g, v, 20.0)
	assert_true(landed > 0.0, "the hit landed")
	assert_near(g.get_health(), hp + landed * 0.25, 0.0001, "healed for a quarter of what landed")
	assert_eq((load(GROUNT_CLEAVE) as AbilityBase).lifesteal_pct, 0.0, "the shared .tres is untouched")
	await _free([g, v])


# ---------- tick_active ----------

## MonsterBase._process steps every ability's tick_active with its delta.
func test_process_ticks_all_three_abilities() -> void:
	var g := await _grount()
	var probes: Array[TickProbe] = [TickProbe.new(), TickProbe.new(), TickProbe.new()]
	g.ability_1 = probes[0]
	g.ability_2 = probes[1]
	g.ability_3 = probes[2]
	g._process(0.25)
	g._process(0.25)
	for p in probes:
		assert_eq(p.ticks, 2)
		assert_near(p.seconds, 0.5, 0.0001)
		assert_true(p.last_caster == g, "ticked with the monster as caster")
	g.ability_2 = null
	g._process(0.1)
	assert_eq(probes[0].ticks, 3, "an empty slot does not stop the others")
	await _free([g])


# ---------- cast centre and the slam-target count ----------

func test_cast_center_default_and_ground_slam_leap() -> void:
	var g := await _grount()
	var near := await _hero(Vector2(100, 0))
	var far := await _hero(Vector2(400, 0))
	assert_eq(AbilityBase.new().get_cast_center(g, near), near.global_position, "default: on the target")
	var slam := g.ability_3 as BullGroundSlam
	assert_eq(slam.leap_distance, 150.0)
	assert_eq(slam.get_cast_center(g, near), near.global_position, "the leap lands on a target in reach")
	assert_eq(slam.get_cast_center(g, far), Vector2(150, 0), "and stops leap_distance short of a far one")
	slam.leap_distance = 0.0
	assert_eq(slam.get_cast_center(g, near), g.global_position, "leap_distance 0 stomps in place")
	await _free([g, near, far])


## The combo's "slam only when it hits slam_min_targets" counts around the cast
## centre: the leap target for Grount's slam, the monster itself in place.
func test_slam_target_count_uses_the_cast_center() -> void:
	var g := await _grount()
	g.gain_xp(1000.0)
	assert_eq(g.get_stage(), 2)
	var h1 := await _hero(Vector2(100, 0))
	var h2 := await _hero(Vector2(210, 0))
	g.target = h1.get_node(^"Body")
	g.target_entity = h1
	var slam := g.ability_3 as BullGroundSlam
	assert_eq(slam.get_reach(), 120.0, "stage-2 slam radius")
	assert_eq(g._count_slam_targets(), 2, "around the leap target: both heroes")
	slam.leap_distance = 0.0
	assert_eq(g._count_slam_targets(), 1, "around the monster: only the near hero")
	await _free([g, h1, h2])


# ---------- escape_with_ability_2 ----------

## A retreating monster escape-casts ability 2 away from a close hero, unless
## its strategy says ability 2 is no movement skill (Gorrak's thrown axe).
func test_escape_dash_obeys_escape_with_ability_2() -> void:
	var region := await bake_nav_rect(Rect2(-2000, -2000, 4000, 4000))
	var g := await _grount()
	var a := await _hero(Vector2(90, 0))
	var b := await _hero(Vector2(0, 200))
	assert_true(g.strategy_profile.escape_with_ability_2, "Grount's Ram Dash is an escape")
	var profile := g.strategy_profile.duplicate() as MonsterStrategy
	profile.escape_with_ability_2 = false
	g.strategy_profile = profile
	g.current_health = 0.2 * g.get_max_health()
	g._update_strategy()
	assert_eq(g.strategy, MonsterBase.Strategy.RETREAT)
	assert_true(g.is_ability_ready("ability_2"), "no escape cast with the switch off")
	profile.escape_with_ability_2 = true
	g._update_strategy()
	assert_false(g.is_ability_ready("ability_2"), "escape cast with the switch on")
	await _free([g, a, b, region])
	await wait_physics_frames(6)


# ---------- tree-modifiable cone angle ----------

## A cone_angle node (Nyxa "Wide Shriek", Gorrak "Wide Arc") survives every
## stage's own angle, on the entity's copy only.
func test_cone_angle_modifier_survives_stage_stats() -> void:
	var cleave := (load(GROUNT_CLEAVE) as BullFrontCleave).duplicate() as BullFrontCleave
	cleave.apply_meta_modifier("cone_angle", 8.0, false)
	for stage in [1, 2, 3]:
		cleave.apply_stage_stats(stage)
		assert_near(cleave.cone_angle, cleave.cone_angle_per_stage[stage - 1] + 8.0, 0.0001, "stage %d angle + 8" % stage)
	var plain := (load(GROUNT_CLEAVE) as BullFrontCleave).duplicate() as BullFrontCleave
	plain.apply_stage_stats(2)
	assert_eq(plain.cone_angle, plain.cone_angle_per_stage[1], "no node: the stage's angle exactly")
	assert_eq((load(GROUNT_CLEAVE) as BullFrontCleave).cone_angle, 50.0, "the shared .tres is untouched")


## The cone nodes are part of the game now that their code exists.
func test_cone_nodes_are_shown() -> void:
	for pair: Array in [[NYXA_TREE, &"ny_cone"], [GORRAK_TREE, &"gk_arc"]]:
		var n := (load(pair[0]) as MetaSkillTree).find_node(pair[1])
		assert_true(n != null, "%s exists" % pair[1])
		if n == null:
			continue
		assert_false(n.hidden, "%s is shown" % pair[1])
		assert_eq(n.stat_name, "cone_angle")
		assert_true(n.stat_name in BullFrontCleave.new(), "a BullFrontCleave property")


# ---------- slam stun ----------

## stun_duration (Gorrak's Warcry Stomp): every target the slam hits is
## stunned; Grount's slam stuns nobody.
func test_slam_stun_duration() -> void:
	var g := await _grount()
	var v := await _hero(Vector2(60, 0))
	var slam := g.ability_3 as BullGroundSlam
	slam.slam_radius = 120.0
	slam._effective_damage = 1.0
	assert_eq(slam.stun_duration, 0.0, "Grount's slam has no stun")
	slam._perform_slam(g)
	assert_true(v.get_health() < v.get_max_health(), "the slam hit")
	assert_false(v.is_stunned(), "and stunned nobody")
	slam.stun_duration = 0.6
	slam._perform_slam(g)
	assert_true(v.is_stunned(), "stunned with stun_duration")
	await _free([g, v])


# ---------- the passive slot ----------

## Every monster fills the HUD's passive slot: Grount's Evolution, with its
## kit icon, on his own copy.
func test_grount_has_the_evolution_passive() -> void:
	var evolution := load(GROUNT_EVOLUTION) as AbilityBase
	assert_eq(evolution.ability_name, "Evolution")
	assert_eq(evolution.ability_type, AbilityBase.AbilityType.PASSIVE)
	assert_true(evolution.icon != null and evolution.icon.resource_path == EVOLUTION_ICON, "the kit's evolution icon")
	assert_false(evolution.description.is_empty())
	var g := await _grount()
	assert_true(g.passive_ability != null and g.passive_ability.ability_name == "Evolution", "Grount.tscn wires it")
	assert_true(g.passive_ability != evolution, "a per-entity copy")
	await _free([g])
