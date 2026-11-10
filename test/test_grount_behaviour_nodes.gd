extends TestCase

## Grount's behaviour nodes (README "Grount Tree" T3/T4): Gravity Slam, Enrage,
## Second Wind and Titan Form, the Hide branch's capstone behind the Lv 8 gate.
## Every one of them is off on a fresh save. AIs are frozen
## (TickScheduler.unregister) and driven by hand.

const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const BAT := "res://Scenes/NPCs/Mob/Mobs/Bat/Bat.tscn"
const PET := "res://Scenes/NPCs/Hero/Heros/Support/Ted/Abilities/Passive/TedsPet.tscn"
const AREA := "res://Scenes/World/MobSpawnArea/MobSpawnArea.tscn"
const SCREEN := "res://Scenes/UI/Screens/CharacterDetail.tscn"

## Grount "Second Wind" (README "Stage 2 Evolution Heal +200 HP"): wired
## (MonsterBase._apply_evolution_bonus_heal) and tested here, but in no shipped
## tree: evolution refills HP (MonsterBase.heal_to_full_on_evolution), so +200
## capped at max would be a no-op purchase. Add it to monster_grount.tres once
## evolution heals by the README rule (new max HP - old max HP) for every
## monster: switching to that rule only while the node is owned would make the
## purchase a net loss (README heal + 200 never beats a refill), and switching
## it for everyone retunes the balance. test_grount_tree_lists_its_shipped_nodes
## pins the tree's contents until that is decided. The test that needs the node
## adds it to the tree and after_each removes it.
var _added_second_wind: MetaSkillNode = null


func before_each() -> void:
	# Every tree these tests seed is a monster's: the played side applies it.
	play_side(MatchRewards.Side.MONSTER)
	if is_isolated():
		PersistedData.wipe_progress(false)


## Unlocks must never leak into later files: they spawn Grount and assert the
## stock numbers (stage scale, ranges, damage).
func after_each() -> void:
	if _added_second_wind != null:
		MetaSkillManager.get_tree_def(_tree()).nodes.erase(_added_second_wind)
		_added_second_wind = null
	if is_isolated():
		PersistedData.wipe_progress(false)


func _tree() -> StringName:
	return MetaSkillManager.monster_tree_id(&"grount")


## Own these Grount nodes (skips the tier chain and the Leaves).
func _grant(ids: Array) -> void:
	PersistedData.set_unlocked_skills(_tree(), ids)


func _add_second_wind() -> void:
	var t: MetaSkillTree = MetaSkillManager.get_tree_def(_tree())
	if t.find_node(&"g3_evoheal") != null:
		return
	_added_second_wind = MetaSkillNode.make(&"g3_evoheal", "Second Wind", "Stage 2 evolution heals +200 HP",
		3, 750, PersistedData.LEAVES, "monster_stage_2_evo_heal", 200.0, false)
	t.nodes.append(_added_second_wind)


func _grount(pos: Vector2 = Vector2.ZERO) -> MonsterBase:
	return (await spawn_frozen(GROUNT, pos)) as MonsterBase


func _hero(pos: Vector2) -> EntityBase:
	return (await spawn_frozen(VLAD, pos)) as EntityBase


func _bat(pos: Vector2) -> MobBase:
	return (await spawn_frozen(BAT, pos)) as MobBase


## Ted's pet (a CharacterBody2D, not an EntityBase) owned by a far-away hero.
func _pet(pos: Vector2, owner_hero: Node2D) -> CharacterBody2D:
	var pet := (load(PET) as PackedScene).instantiate() as CharacterBody2D
	pet.global_position = pos
	pet.set("owner_entity", owner_hero)
	add_child(pet)
	await wait_physics_frames(4)
	return pet


func _evolve_to_3(g: MonsterBase) -> void:
	g.gain_xp(1000.0)
	g.gain_xp(0.0)
	await wait_seconds(0.7)  # stage scale tween


func _slam_of(g: MonsterBase, dmg: float) -> BullGroundSlam:
	var slam := g.ability_3 as BullGroundSlam
	slam._effective_damage = dmg
	return slam


# ---------- tree data ----------

func test_grount_tree_ends_in_the_titan_form_capstone() -> void:
	var t: MetaSkillTree = MetaSkillManager.get_tree_def(_tree())
	assert_eq(t.max_tier(), 4)
	assert_eq(t.gate_kind, MetaSkillTree.GateKind.LEVEL)
	assert_eq(t.tier_gates, [1, 3, 5, 8] as Array[int])
	assert_eq(t.owner_id, &"grount")
	var titan: MetaSkillNode = t.find_node(&"g4_titan")
	assert_true(titan != null, "Titan Form exists")
	if titan != null:
		assert_eq(titan.tier, 4)
		assert_eq(titan.cost, 1500)
		assert_true(titan.capstone, "the Hide branch's capstone")
		assert_eq(titan.branch, 1)
		assert_eq(titan.currency, PersistedData.LEAVES)
		assert_false(titan.is_ability_node())
		assert_eq(titan.stat_name, "monster_titan_form")
		assert_false(titan.stat_multiplicative, "behaviour flags are additive")
	var rampage: MetaSkillNode = t.find_node(&"g4_rampage")
	var trample: MetaSkillNode = t.find_node(&"g4_stampede")
	assert_eq(t.capstones(), [rampage, titan, trample] as Array[MetaSkillNode], "one capstone per branch, in branch order")
	if rampage != null and trample != null:
		assert_false(rampage.hidden or trample.hidden, "Rampage and Trample have their code (6.6)")
		assert_eq([rampage.branch, rampage.stat_name, rampage.is_ability_node()], [0, "monster_rampage", false])
		assert_eq([trample.branch, trample.ability_name, trample.stat_name], [2, "Ram Dash", "trample"])
		assert_false(rampage.stat_multiplicative or trample.stat_multiplicative, "flags are additive")
	var pull: MetaSkillNode = t.find_node(&"g3_pull")
	assert_true(pull != null, "Gravity Slam exists")
	if pull != null:
		assert_eq(pull.tier, 3)
		assert_eq(pull.cost, 750)
		assert_eq(pull.ability_name, "Ground Slam")
		assert_eq(pull.stat_name, "pull_radius")
		assert_near(pull.stat_value, 200.0)
		assert_false(pull.stat_multiplicative)
	var enrage: MetaSkillNode = t.find_node(&"g3_enrage")
	assert_true(enrage != null, "Enrage exists")
	if enrage != null:
		assert_eq(enrage.tier, 3)
		assert_eq(enrage.cost, 750)
		assert_false(enrage.is_ability_node())
		assert_eq(enrage.stat_name, "monster_enrage")
		assert_false(enrage.stat_multiplicative)
	var hp: MetaSkillNode = t.find_node(&"g2_hp")
	assert_true(hp != null and hp.stat_multiplicative and not hp.is_ability_node())


## What a player can buy, read from the shipped tree itself (no test inserts).
## Second Wind is deliberately absent until the evolution heal is decided (see
## _added_second_wind): flip this when it ships.
func test_grount_tree_lists_its_shipped_nodes() -> void:
	var t: MetaSkillTree = MetaSkillManager.get_tree_def(_tree())
	var expected: Dictionary = {
		1: ["g1_dmg", "g1_hide", "g1_range", "g1_speed", "g1_stun"],
		2: ["g2_cleavecd", "g2_earlyslam", "g2_evo", "g2_hp"],
		3: ["g3_dash", "g3_dmg", "g3_enrage", "g3_pull", "g3_slam", "g3_speed"],
		4: ["g4_rampage", "g4_stampede", "g4_titan"],
	}
	assert_eq(t.max_tier(), 4)
	for tier: int in expected:
		var ids: Array = []
		for n in t.nodes_in_tier(tier):
			ids.append(String(n.id))
		ids.sort()
		assert_eq(ids, expected[tier], "tier %d" % tier)
	for n in t.nodes:
		assert_false(n.hidden, "%s: every Grount node has its code (6.6)" % n.id)
	assert_true(t.find_node(&"g3_evoheal") == null, "Second Wind is not in the shipped tree yet")
	if is_isolated():
		PersistedData.add_currency(PersistedData.LEAVES, 5000)
		PersistedData.add_monster_xp(&"grount", 2800)
		_grant(["g1_dmg", "g2_hp", "g3_dmg"])
		assert_false(MetaSkillManager.unlock(_tree(), &"g3_evoheal"), "so it cannot be bought")
		assert_eq(MetaSkillManager.node_state(_tree(), &"g3_evoheal"), MetaSkillManager.NodeState.INVALID)
		assert_true(MetaSkillManager.unlock(_tree(), &"g4_rampage"), "Rampage is bought like any capstone at Lv 8")


## Character trees open tiers by the character's permanent level (1/3/5/8).
## Titan Form's Hide branch starts at Thick Hide, Scar Tissue's only parent.
func test_tier_4_opens_at_grount_level_8() -> void:
	if not require_isolated():
		return
	PersistedData.add_currency(PersistedData.LEAVES, 40 + 120 + 1500)
	assert_true(MetaSkillManager.unlock(_tree(), &"g1_hide"))
	assert_eq(MetaSkillManager.node_state(_tree(), &"g2_hp"), MetaSkillManager.NodeState.LEVEL_GATED, "Lv 1")
	PersistedData.add_monster_xp(&"grount", 1000)  # Lv 5: tiers 2 and 3
	assert_true(MetaSkillManager.unlock(_tree(), &"g2_hp"), "Thick Hide opens Scar Tissue")
	assert_eq(MetaSkillManager.node_state(_tree(), &"g4_titan"), MetaSkillManager.NodeState.LEVEL_GATED)
	assert_false(MetaSkillManager.unlock(_tree(), &"g4_titan"), "tier 4 needs Lv 8")
	PersistedData.add_monster_xp(&"grount", 1800)  # 2800 XP: Lv 8
	assert_true(MetaSkillManager.is_node_available(_tree(), &"g4_titan"), "Scar Tissue is one of its parents")
	assert_true(MetaSkillManager.unlock(_tree(), &"g4_titan"))
	assert_eq(PersistedData.get_currency(PersistedData.LEAVES), 0, "1500 Leaves for a capstone")
	assert_eq(MetaSkillManager.equipped_capstone(_tree()), &"g4_titan", "the first capstone bought is equipped")


func test_additive_keys_sum_from_zero_and_multiplicative_keys_are_unchanged() -> void:
	if not require_isolated():
		return
	assert_true(MetaSkillManager.collect_monster_modifiers(&"grount").is_empty(), "fresh save: no modifiers")
	_grant(["g2_hp", "g3_enrage", "g4_titan", "g3_pull"])
	PersistedData.set_unlocked_skills(MetaSkillManager.TREE_MONSTER_BASE, ["mt1_hp", "mt3_hp"])
	var mods: Dictionary = MetaSkillManager.collect_monster_modifiers(&"grount")
	assert_near(float(mods.get("monster_health_mult", 0.0)), 1.10 * 1.20 * 1.15, 0.0001, "% nodes still stack from 1.0")
	assert_near(float(mods.get("monster_enrage", 0.0)), 1.0, 0.0001, "flag summed from 0.0")
	assert_near(float(mods.get("monster_titan_form", 0.0)), 1.0, 0.0001)
	assert_false(mods.has("pull_radius"), "ability nodes go to the ability copies")


# ---------- fresh save ----------

func test_behaviour_nodes_are_off_on_a_fresh_save() -> void:
	if not require_isolated():
		return
	assert_true(MetaSkillManager.collect_monster_modifiers(&"grount").is_empty(), "no unlock leaked in from an earlier test")
	var g := await _grount()
	var stats: MonsterStats = g.monster_stats
	var slam := _slam_of(g, 5.0)
	assert_eq(slam.pull_radius, 0.0)
	assert_eq(slam.get_reach(), slam.slam_radius)
	var max_hp: float = g.get_max_health()
	assert_eq(max_hp, stats.stage_1_health)
	var cleave: float = g.effective_ability_damage(g.ability_1)
	g.current_health = 0.1 * max_hp
	assert_false(g.is_enraged())
	assert_eq(g.move_speed, stats.stage_1_speed)
	assert_eq(g.effective_ability_damage(g.ability_1), cleave)
	# The slam on the fresh-save path (no pull) still hits and moves nobody.
	var v := await _hero(Vector2(130, 0))
	slam._perform_slam(g)
	await wait_frames(1)
	assert_eq(v.global_position, Vector2(130, 0), "no pull without the node")
	assert_true(v.get_health() < v.get_max_health(), "the slam itself still damages")
	assert_eq(slam.last_pull_count, 0)
	g.current_health = 100.0
	g._apply_evolution_bonus_heal(2)
	assert_eq(g.current_health, 100.0, "no Second Wind")
	g.current_health = max_hp
	await _evolve_to_3(g)
	assert_eq(g.current_stage, 3)
	assert_true(g.scale.is_equal_approx(stats.stage_3_scale), "stock stage-3 scale %s" % str(g.scale))
	assert_eq(g.get_max_health(), stats.stage_3_health)
	assert_eq(g.attack_range, 80.0)
	assert_eq(g.max_distance, 100.0)
	assert_eq(g.get_range_bonus(), 0.0)
	assert_false(g.is_titan())
	var det := g.get_node("DetectionArea/CollisionShape2D") as CollisionShape2D
	assert_near((det.shape as CircleShape2D).radius, g.detection_radius, 0.001, "stock aggro shape")
	assert_true(g.debug_meta_line().ends_with("nodes: -"), g.debug_meta_line())


func test_range_nodes_alone_keep_the_stock_fight_leave_distance() -> void:
	if not require_isolated():
		return
	_grant(["g1_range"])
	PersistedData.set_unlocked_skills(MetaSkillManager.TREE_MONSTER_BASE, ["mt3_range"])
	var g := await _grount()
	await _evolve_to_3(g)
	assert_near(g.attack_range, 80.0 * 1.1 * 1.1, 0.001)
	assert_eq(g.max_distance, 100.0, "no Titan: Fight still leaves at 100 px")


# ---------- Enrage ----------

func test_enrage_below_20_percent_without_compounding() -> void:
	if not require_isolated():
		return
	_grant(["g1_dmg", "g3_enrage"])
	var g := await _grount()
	var max_hp: float = g.get_max_health()
	assert_false(g.is_enraged(), "full HP")
	var speed: float = g.move_speed
	var cleave: float = g.effective_ability_damage(g.ability_1)
	var dash: float = g.effective_ability_damage(g.ability_2)
	var slam: float = g.effective_ability_damage(g.ability_3)
	assert_near(cleave, g.ability_1.damage * 1.10, 0.0001, "Heavy Horns still applies")
	var stored_mult: float = g.damage_multiplier
	var stored_meta: float = g._meta_damage_mult
	g.current_health = 0.19 * max_hp
	assert_true(g.is_enraged(), "below 20%")
	assert_near(g.move_speed, speed * 1.3, 0.0001)
	assert_near(g.effective_ability_damage(g.ability_1), cleave * 1.5, 0.0001, "Front Cleave")
	assert_near(g.effective_ability_damage(g.ability_2), dash * 1.5, 0.0001, "Ram Dash")
	assert_near(g.effective_ability_damage(g.ability_3), slam * 1.5, 0.0001, "Ground Slam")
	g.current_health = 0.2 * max_hp
	assert_false(g.is_enraged(), "ends at exactly 20%")
	assert_eq(g.move_speed, speed)
	assert_eq(g.effective_ability_damage(g.ability_1), cleave)
	for i in range(3):
		g.current_health = 0.1 * max_hp
		assert_near(g.move_speed, speed * 1.3, 0.0001, "no compounding (%d)" % i)
		assert_near(g.effective_ability_damage(g.ability_1), cleave * 1.5, 0.0001, "no compounding (%d)" % i)
		g.current_health = 0.5 * max_hp
		assert_eq(g.move_speed, speed)
		assert_eq(g.effective_ability_damage(g.ability_1), cleave)
	assert_eq(g.damage_multiplier, stored_mult, "the stored multipliers are never touched")
	assert_eq(g._meta_damage_mult, stored_meta)
	g.current_health = 0.0
	assert_false(g.is_enraged(), "a dead monster is not enraged")


func test_enrage_ends_on_rest_regen_and_on_evolution() -> void:
	if not require_isolated():
		return
	_grant(["g3_enrage"])
	var g := await _grount()
	var max_hp: float = g.get_max_health()
	g.current_health = 0.15 * max_hp
	g._update_strategy()
	g._pre_tick(0.1)
	assert_true(g.is_resting(), "below rest_hp_pct")
	assert_true(g.is_enraged())
	g._since_damage = 99.0
	var guard: int = 0
	while g.current_health < 0.2 * max_hp and guard < 100:
		g._pre_tick(5.0)
		guard += 1
	assert_true(g.current_health >= 0.2 * max_hp, "rest regeneration got past 20%")
	assert_false(g.is_enraged(), "and that ended Enrage")
	assert_near(g.move_speed, g.monster_stats.stage_1_speed, 0.0001)
	g.current_health = 0.1 * max_hp
	assert_true(g.is_enraged())
	g.gain_xp(1000.0)
	assert_eq(g.current_stage, 2)
	assert_near(g.current_health, g.get_max_health(), 0.001, "evolution heal")
	assert_false(g.is_enraged(), "the evolution heal ended it")
	assert_near(g.move_speed, g.monster_stats.stage_2_speed, 0.0001)


func test_enrage_threshold_counts_the_titan_bonus() -> void:
	if not require_isolated():
		return
	_grant(["g3_enrage", "g4_titan"])
	var g := await _grount()
	await _evolve_to_3(g)
	var titan_max: float = g.monster_stats.stage_3_health + 500.0
	assert_near(g.get_max_health(), titan_max, 0.001)
	# 21% of the plain stage-3 max is still under 20% of the Titan max.
	g.current_health = 0.21 * g.monster_stats.stage_3_health
	assert_true(g.is_enraged(), "%.0f HP < 20%% of %.0f" % [g.current_health, titan_max])
	g.current_health = 0.2 * titan_max
	assert_false(g.is_enraged())


func test_enrage_and_titan_show_in_the_f3_overlay() -> void:
	if not require_isolated():
		return
	_grant(["g3_enrage", "g4_titan", "g3_pull"])
	var g := await _grount()
	var overlay := DebugOverlay.new()
	add_child(overlay)
	await wait_frames(1)
	g.current_health = 0.1 * g.get_max_health()
	overlay._collect_snapshots()
	assert_true(_state_str(overlay, g).contains("ENRAGED"), _state_str(overlay, g))
	assert_false(_state_str(overlay, g).contains("TITAN"), "Titan Form waits for stage 3")
	var line: String = g.debug_meta_line()
	assert_true(line.contains("pull(last 0)"), line)
	assert_true(line.contains("enrage!"), line)
	assert_true(line.contains("titan") and not line.contains("titan!"), line)
	assert_true(overlay._hud_label.text.contains(line), "the HUD lists the monster's nodes")
	await _evolve_to_3(g)
	overlay._collect_snapshots()
	var s: String = _state_str(overlay, g)
	assert_true(s.contains("TITAN"), s)
	assert_false(s.contains("ENRAGED"), "the evolution heal ended Enrage")
	assert_true(g.debug_meta_line().contains("titan!"))
	overlay.queue_free()


func _state_str(overlay: DebugOverlay, entity: Node) -> String:
	for snap in overlay._snapshots:
		if snap.entity.get_ref() == entity:
			return snap.state_str
	return ""


func test_f3_line_copes_with_a_monster_without_ground_slam() -> void:
	var g := await _grount()
	g.ability_3 = BullFrontCleave.new()
	assert_false(g.debug_meta_line().contains("pull("), "not a Ground Slam: no pull tag")
	g.ability_3 = null
	assert_true(g.debug_meta_line().contains(" S1 "), g.debug_meta_line())


# ---------- Second Wind ----------

func test_second_wind_heals_200_on_stage_2_capped_at_max() -> void:
	if not require_isolated():
		return
	_add_second_wind()
	_grant(["g3_evoheal"])
	var mods: Dictionary = MetaSkillManager.collect_monster_modifiers(&"grount")
	assert_near(float(mods.get("monster_stage_2_evo_heal", 0.0)), 200.0, 0.0001, "additive key summed from 0")
	var g := await _grount()
	var stats: MonsterStats = g.monster_stats
	assert_near(g._meta_stage_2_evo_heal, 200.0, 0.0001)
	assert_true(g.debug_meta_line().contains("evoheal +200"), g.debug_meta_line())
	g.current_health = 100.0
	g._apply_evolution_bonus_heal(2)
	assert_near(g.current_health, 300.0, 0.001, "+200")
	g.current_health = g.get_max_health() - 50.0
	g._apply_evolution_bonus_heal(2)
	assert_near(g.current_health, g.get_max_health(), 0.001, "never above max")
	g.current_health = 100.0
	g._apply_evolution_bonus_heal(3)
	assert_near(g.current_health, 100.0, 0.001, "Stage 2 only")
	# Wired into the evolution: on the README heal (new max - old max) the
	# +200 lands on top of it. Fails if _evolve_to_stage stops calling it.
	g.heal_to_full_on_evolution = false
	g.current_health = 100.0
	g.gain_xp(1000.0)
	assert_eq(g.current_stage, 2)
	assert_near(g.current_health, 100.0 + (stats.stage_2_health - stats.stage_1_health) + 200.0, 0.001,
		"README evolution heal + Second Wind")
	# The tuned build refills HP on evolution, so Second Wind has nothing to add.
	var h := await _grount(Vector2(600, 0))
	h.current_health = 100.0
	h.gain_xp(1000.0)
	assert_near(h.current_health, h.get_max_health(), 0.001, "full heal, never above max")


# ---------- Titan Form ----------

func test_titan_form_on_stage_3() -> void:
	if not require_isolated():
		return
	_grant(["g1_range", "g4_titan"])
	var g := await _grount()
	var stats: MonsterStats = g.monster_stats
	var shape := (g.get_node("DetectionArea/CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	assert_false(g.is_titan())
	assert_eq(g.get_max_health(), stats.stage_1_health)
	assert_near(g.attack_range, 88.0, 0.001)
	assert_eq(g.max_distance, 100.0)
	g.gain_xp(1000.0)
	assert_false(g.is_titan(), "stage 2: no Titan yet")
	assert_eq(g.get_max_health(), stats.stage_2_health)
	g.gain_xp(0.0)
	assert_eq(g.current_stage, 3)
	assert_true(g.is_titan())
	await wait_seconds(0.7)
	var titan_scale: Vector2 = stats.stage_3_scale * 1.5
	assert_true(g.scale.is_equal_approx(titan_scale), "scale %s" % str(g.scale))
	assert_true(g.hud.scale.is_equal_approx(Vector2.ONE / titan_scale), "HP bar keeps its pixel size")
	assert_near(g.get_max_health(), stats.stage_3_health + 500.0, 0.001, "+500 max HP")
	assert_near(g.current_health, g.get_max_health(), 0.001, "and the +500 is healed")
	assert_near(g.health_bar.ratio(), 1.0, 0.001)
	assert_near(g.attack_range, 80.0 * 1.1 + 20.0, 0.001, "+20 flat on top of the % node")
	assert_near(g.max_distance, 120.0, 0.001, "the Fight leave distance moves with it")
	assert_near(shape.radius * g.scale.x, g.detection_radius * stats.stage_3_scale.x, 0.01, "aggro stays at the stage-3 value")
	# Idempotent: re-applying stage 3 or more XP never stacks it.
	g._enter_stage()
	await wait_seconds(0.7)
	assert_true(g.scale.is_equal_approx(titan_scale), "still %s, got %s" % [str(titan_scale), str(g.scale)])
	assert_near(g.get_max_health(), stats.stage_3_health + 500.0, 0.001)
	assert_near(g.attack_range, 108.0, 0.001)
	assert_near(g.max_distance, 120.0, 0.001)
	g.gain_xp(1000.0)
	assert_eq(g.current_stage, 3)
	assert_near(g.get_max_health(), stats.stage_3_health + 500.0, 0.001)


## The Titan-sized aggro radius used to be written at once while the body was
## still at its stage-2 size: the circle shrank to ~143 px for a few frames and
## Grount dropped the hero it was chasing just as it evolved.
func test_titan_evolution_never_shrinks_the_aggro_circle() -> void:
	if not require_isolated():
		return
	_grant(["g4_titan"])
	var g := await _grount()
	var stats: MonsterStats = g.monster_stats
	var shape := (g.get_node("DetectionArea/CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	g.gain_xp(1000.0)
	assert_eq(g.current_stage, 2)
	await wait_seconds(0.7)  # stage-2 scale tween
	var stage_2_aggro: float = shape.radius * g.scale.x
	assert_near(stage_2_aggro, g.detection_radius * stats.stage_2_scale.x, 0.01)
	# Chased from 200 px: inside the stage-2 circle (215 px + its Body), outside
	# the one the early write gave (172 / 1.5 x 1.25 = 143 px + its Body).
	var v := await _hero(Vector2(200, 0))
	await wait_physics_frames(3)
	var body := v.get_node("Body") as Area2D
	assert_true(g.detection_area.overlaps_area(body), "setup: the hero is inside the stage-2 circle")
	g.target = body
	g.target_entity = v
	g.gain_xp(0.0)
	assert_eq(g.current_stage, 3)
	assert_true(g.is_titan())
	var smallest: float = shape.radius * g.scale.x
	var largest: float = smallest
	var kept: bool = true
	for _i in range(45):  # the 0.5 s scale tween, frame by frame
		await wait_physics_frames(1)
		var world_r: float = shape.radius * g.scale.x
		smallest = minf(smallest, world_r)
		largest = maxf(largest, world_r)
		kept = kept and g.target_entity == v and g.detection_area.overlaps_area(body)
	await wait_seconds(0.3)
	assert_true(smallest >= stage_2_aggro - 0.01, "never below the stage-2 circle (%.1f < %.1f px)" % [smallest, stage_2_aggro])
	assert_true(largest <= g.detection_radius * stats.stage_3_scale.x + 0.01, "nor wider than the stage-3 one (%.1f px)" % largest)
	assert_true(kept, "the chase target was never dropped")
	assert_true(g.scale.is_equal_approx(stats.stage_3_scale * 1.5), "grown to %s" % str(g.scale))
	assert_near(shape.radius * g.scale.x, g.detection_radius * stats.stage_3_scale.x, 0.01, "settles at the stage-3 value")


func test_titan_fight_holds_and_the_cleave_reaches_its_range() -> void:
	if not require_isolated():
		return
	_grant(["g1_range", "g4_titan"])
	PersistedData.set_unlocked_skills(MetaSkillManager.TREE_MONSTER_BASE, ["mt3_range"])
	var g := await _grount()
	await _evolve_to_3(g)
	var reach: float = g.attack_range
	assert_near(reach, 80.0 * 1.1 * 1.1 + 20.0, 0.001)
	assert_true(reach > g.monster_stats.fight_leave_distance, "the case that bounced between Approach and Fight")
	var v := await _hero(Vector2(reach - 1.0, 0))
	g._update_strategy()  # picks the hero up from its own detection area
	assert_true(g.target_entity == v, "acquired the hero")
	for i in range(6):
		g._tick(0.1)
		await wait_frames(1)
	assert_eq(active_state_of(g), "Fight", "no Approach/Fight ping-pong at the Titan's range")
	assert_false(g.is_ability_ready("ability_1"), "Front Cleave was cast")
	assert_true(v.get_health() < v.get_max_health(), "and connected at attack_range - 1")


func test_titan_cleave_reaches_teds_pet_at_100_px() -> void:
	if not require_isolated():
		return
	_grant(["g4_titan"])
	var g := await _grount()
	await _evolve_to_3(g)
	assert_near(g.attack_range, 100.0, 0.001)
	var ted := await _hero(Vector2(6000, 6000))
	var pet := await _pet(Vector2(99, 0), ted)
	var hp_before: float = float(pet.get("current_health"))
	g.sprite.rotation = 0.0  # face the pet
	g.ability_1.execute(g, pet, 5.0)
	await wait_frames(1)
	assert_true(float(pet.get("current_health")) < hp_before, "pet Body r16 at 99 px is inside the 100 px cleave")


# ---------- Gravity Slam ----------

func test_gravity_slam_pulls_then_damages() -> void:
	if not require_isolated():
		return
	_grant(["g3_pull"])
	var g := await _grount()
	var slam := _slam_of(g, 5.0)
	assert_near(slam.pull_radius, 200.0, 0.001)
	assert_near(slam.get_reach(), 200.0, 0.001, "pullable enemies count as slam targets")
	var a := await _hero(Vector2(190, 0))
	var bat := await _bat(Vector2(0, 150))
	var b := await _hero(Vector2(260, 0))
	var ted := await _hero(Vector2(6000, 6000))
	var pet := await _pet(Vector2(-150, 0), ted)
	var pet_hp: float = float(pet.get("current_health"))
	var a_goal: Vector2 = a._idle_goal
	slam._perform_slam(g)
	var stop: float = slam.pull_stop_distance
	assert_near(a.global_position.distance_to(g.global_position), stop, 0.5, "hero pulled in")
	assert_near(bat.global_position.distance_to(g.global_position), stop, 0.5, "mob pulled in")
	assert_near(pet.global_position.distance_to(g.global_position), stop, 0.5, "Ted's pet pulled in")
	assert_eq(slam.last_pull_count, 3)
	assert_eq(a._idle_goal, a_goal, "keeps its AI goal (not a teleport)")
	assert_eq(a._last_nav_target_pos, Vector2(INF, INF), "re-paths from the new spot")
	await wait_frames(1)
	assert_true(a.get_health() < a.get_max_health(), "pulled from outside the slam radius, then hit")
	assert_true(bat.get_health() < bat.get_max_health())
	assert_true(float(pet.get("current_health")) < pet_hp)
	assert_eq(b.global_position, Vector2(260, 0), "outside the 200 px pull")
	assert_eq(b.get_health(), b.get_max_health())
	assert_true(g.debug_meta_line().contains("pull(last 3)"), g.debug_meta_line())


## A pull that ends short (a wall, here a longer stop distance) hits by the
## same rule as standing on that spot: the Body circle overlaps the slam
## circle. The query used to see the pre-pull spot, and the fallback for pulled
## targets compared centres only, so a target pulled to slam_radius + 15 px got
## away while one standing there was hit.
func test_a_pull_cut_short_hits_like_standing_there() -> void:
	if not require_isolated():
		return
	_grant(["g3_pull"])
	var g := await _grount()
	var slam := _slam_of(g, 5.0)
	slam.slam_radius = 120.0  # the stage-2 radius
	var a := await _hero(Vector2(190, 0))
	var body_shape := (a.get_node("Body/CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	var body_r: float = body_shape.radius * a.global_scale.x
	# Centre outside the slam radius, Body circle inside it.
	var inside: float = slam.slam_radius + body_r * 0.5
	var stander := await _hero(Vector2(0, inside))  # already that close: not pulled
	slam.pull_stop_distance = inside
	slam._perform_slam(g)
	assert_eq(slam.last_pull_count, 1)
	assert_near(a.global_position.distance_to(g.global_position), inside, 0.5)
	await wait_frames(1)
	assert_true(stander.get_health() < stander.get_max_health(), "standing there: hit")
	assert_true(a.get_health() < a.get_max_health(), "pulled there: hit as well")
	# Just past the reach both miss.
	var outside: float = slam.slam_radius + body_r + 8.0
	var c := await _hero(Vector2(-190, 0))
	var far_stander := await _hero(Vector2(0, -outside))
	slam.pull_stop_distance = outside
	slam._perform_slam(g)
	assert_near(c.global_position.distance_to(g.global_position), outside, 0.5)
	await wait_frames(1)
	assert_eq(far_stander.get_health(), far_stander.get_max_health(), "standing there: missed")
	assert_eq(c.get_health(), c.get_max_health(), "pulled there: missed as well")


func test_gravity_slam_skips_the_dead_and_keeps_stuns() -> void:
	if not require_isolated():
		return
	_grant(["g3_pull"])
	var g := await _grount()
	var v := await _hero(Vector2(150, 0))
	var bat := await _bat(Vector2(0, 150))
	EventBus.deal_damage(v, bat, 9999.0)
	assert_false(bat.is_alive())
	v.apply_stun(1.0)
	var slam := _slam_of(g, 5.0)
	slam._perform_slam(g)
	assert_eq(bat.global_position, Vector2(0, 150), "corpses stay where they fell")
	assert_near(v.global_position.distance_to(g.global_position), slam.pull_stop_distance, 0.5)
	assert_true(v.is_stunned(), "a pulled target stays stunned")
	assert_eq(slam.last_pull_count, 1)


func test_a_pulled_hero_does_not_corner_a_farming_monster() -> void:
	if not require_isolated():
		return
	_grant(["g3_pull"])
	var g := await _grount()
	var v := await _hero(Vector2(180, 0))
	g._update_strategy()
	assert_eq(g.strategy, MonsterBase.Strategy.FARM)
	var slam := _slam_of(g, 1.0)
	assert_true(slam.pull_stop_distance > g.strategy_profile.cornered_radius, "the pull stops outside the Desperation radius")
	slam._perform_slam(g)
	assert_near(v.global_position.distance_to(g.global_position), slam.pull_stop_distance, 0.5)
	assert_false(g._may_engage_hero(v), "the pull did not force a fight")
	assert_true(g._score_target(v) < 0.0)


func test_an_idle_camp_mob_is_held_at_its_camp_edge() -> void:
	if not require_isolated():
		return
	_grant(["g3_pull"])
	var g := await _grount()
	var area := (load(AREA) as PackedScene).instantiate() as MobSpawnArea
	area.auto_spawn_on_ready = false
	area.position = Vector2(0, 200)
	add_child(area)
	await wait_frames(1)
	var bat := await _bat(Vector2(0, 180))
	bat.spawn_area = area
	bat.spawn_position = area.area_center
	assert_true(area.area_radius < 120.0, "geometry: the pull lands outside the camp")
	var slam := _slam_of(g, 1.0)
	slam._perform_slam(g)
	assert_near(bat.global_position.distance_to(g.global_position), slam.pull_stop_distance, 0.5)
	bat._pre_tick(0.1)  # idle mob: its leash puts it back on the camp's edge
	assert_near(bat.global_position.distance_to(area.area_center), area.area_radius, 0.5, "held at the edge")
	assert_true(bat.global_position.distance_to(g.global_position) < 179.0, "still closer to the slam than before")


func test_gravity_slam_never_pulls_through_a_wall() -> void:
	if not require_isolated():
		return
	_grant(["g3_pull"])
	# An L: the hero stands in the vertical arm, the monster in the horizontal
	# one; the straight line between them crosses the notch (off the mesh).
	var region := await bake_nav_outline(PackedVector2Array([Vector2(0, 0), Vector2(400, 0), Vector2(400, 100),
		Vector2(100, 100), Vector2(100, 400), Vector2(0, 400)]))
	var g := await _grount(Vector2(200, 50))
	var v := await _hero(Vector2(50, 180))
	var before: float = v.global_position.distance_to(g.global_position)
	assert_true(before < 200.0, "inside the pull radius")
	_slam_of(g, 1.0)._perform_slam(g)
	var p: Vector2 = v.global_position
	assert_true(p.distance_to(g.global_position) < before - 1.0, "pulled along the mesh")
	var nav_map: RID = GameUtils.usable_nav_map(region.get_world_2d())
	assert_true(nav_map.is_valid(), "test map synced")
	if nav_map.is_valid():
		assert_true(NavigationServer2D.map_get_closest_point(nav_map, p).distance_to(p) <= 2.0, "still on the mesh at %s" % str(p))
	assert_true(p.x <= 101.0, "stopped at the corner instead of crossing the notch (%s)" % str(p))
	for n in [g, v, region]:
		n.queue_free()
	await wait_physics_frames(6)  # map back to empty for the other tests


# ---------- shared overlap query ----------

## GameUtils.entities_in_circle (Front Cleave, Ram Dash, Ground Slam): every
## overlapping entity once, in the order a direct intersect_shape returns
## them, never the excluded caster. The shared query and shape take each
## call's own centre, radius and mask.
func test_entities_in_circle_matches_a_direct_overlap_query() -> void:
	var g := await _grount()
	var v := await _hero(Vector2(60, 0))
	var bat := await _bat(Vector2(0, 60))
	var world: World2D = g.get_world_2d()
	# The monster layer too, so the query reaches the caster's own Body.
	var all_bodies: int = GameUtils.LAYER_BODY_HERO | GameUtils.LAYER_BODY_MOB | GameUtils.LAYER_BODY_MONSTER
	var shape := CircleShape2D.new()
	shape.radius = 80.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, g.global_position)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = all_bodies
	var direct: Array[Node2D] = []
	var reached_caster := false
	for hit: Dictionary in world.direct_space_state.intersect_shape(query, 32):
		var e: Node2D = Globals.get_entity_from_collider(hit["collider"] as Node)
		if e == g:
			reached_caster = true
		elif not direct.has(e):
			direct.append(e)
	assert_true(reached_caster, "the direct query reaches the caster")
	var found: Array[Node2D] = GameUtils.entities_in_circle(world, g.global_position, 80.0, all_bodies, true, g)
	assert_eq(found, direct, "physics result order")
	assert_eq(found.size(), 2)
	assert_eq(found.count(v), 1, "the hero once")
	assert_eq(found.count(bat), 1, "the bat once")
	assert_false(found.has(g), "never the excluded caster")
	assert_true(GameUtils.entities_in_circle(world, g.global_position, 80.0, all_bodies, true).has(g),
		"no exclude: the caster counts too")
	var only_bat: Array[Node2D] = [bat]
	assert_eq(GameUtils.entities_in_circle(world, g.global_position, 80.0, GameUtils.LAYER_BODY_MOB, true, g),
		only_bat, "this call's mask")
	assert_true(GameUtils.entities_in_circle(world, Vector2(5000, -5000), 80.0, all_bodies, true, g).is_empty(),
		"this call's centre")
	assert_true(GameUtils.entities_in_circle(world, g.global_position, 1.0, all_bodies, true, g).is_empty(),
		"this call's radius")


# ---------- skill-tree screen ----------

## The character detail's SKILL TREE lists every shipped Grount node, keeps
## the 2000-Leaf Titan Form gated behind tier 3, fits the portrait screen and
## lets it be bought (through upgrade_requested, as MenuRoot does) once a
## tier-3 node is owned.
func test_skill_screen_renders_and_gates_tier_4() -> void:
	if not require_isolated():
		return
	# The headless root viewport is not portrait: lay the screen out at 720 px.
	var portrait := SubViewport.new()
	portrait.size = Vector2i(720, 1280)
	add_child(portrait)
	var screen := (load(SCREEN) as PackedScene).instantiate() as CharacterDetail
	portrait.add_child(screen)
	await wait_frames(2)
	screen.show_character(GameManager.ROSTER.find(&"grount"), CharacterDetail.Mode.TREE)
	await wait_frames(2)
	var t: MetaSkillTree = MetaSkillManager.get_tree_def(_tree())
	var view := screen.tree_view()
	assert_eq(screen.tree_id, _tree())
	var shown := t.shown_nodes()
	assert_eq(view.buttons().size(), shown.size(), "every shown node is on the screen")
	assert_true(view.button(&"g4_rampage") != null and view.button(&"g4_stampede") != null, "the 6.6 capstones too")
	assert_true(view.slots().is_empty(), "no \"???\" slot left in Grount's tree")
	var rows: Dictionary[int, Array] = {}
	for n in shown:
		var b := view.button(n.id)
		assert_true(b != null, "%s is shown" % n.id)
		if b == null:
			continue
		if not rows.has(n.tier):
			rows[n.tier] = []
		rows[n.tier].append(b)
		assert_true(b.get_global_rect().position.x >= 0.0 and b.get_global_rect().end.x <= 720.5,
				"%s inside the 720 px screen (%s)" % [n.id, str(b.get_global_rect())])
	assert_eq(rows.size(), 4, "rows T1..T4")
	if rows.size() != 4:
		portrait.queue_free()
		return
	var t3: Array = rows[3]
	assert_true(t3.size() >= 6, "Grount T3 carries the new nodes")
	for b: SkillNodeButton in t3:
		assert_near(b.position.y, (t3[0] as SkillNodeButton).position.y, 0.5, "all of tier 3 on one row")
	assert_true((rows[4][0] as SkillNodeButton).position.y > (t3[0] as SkillNodeButton).position.y, "tier 4 below tier 3")
	var titan := view.button(&"g4_titan")
	assert_eq(titan.state, UxTreeModel.NodeState.LOCKED, "level-gated")
	assert_true(screen.model.find(&"g4_titan").capstone, "the capstone frame")
	view.select(&"g4_titan")
	var upgrade := screen.get_node("%Upgrade") as Button
	assert_true(upgrade.disabled)
	assert_true(upgrade.text.contains("Needs Lv 8"), upgrade.text)
	_grant(["g1_dmg", "g2_hp", "g3_dmg"])
	PersistedData.add_monster_xp(&"grount", 2800)
	PersistedData.add_currency(PersistedData.LEAVES, 1500)
	screen.refresh()
	titan = view.button(&"g4_titan")
	assert_eq(titan.state, UxTreeModel.NodeState.AVAILABLE, "open at Lv 8 with a parent owned")
	assert_true(titan.buyable)
	assert_false(upgrade.disabled, "buyable")
	screen.upgrade_requested.connect(MetaSkillManager.unlock)
	upgrade.pressed.emit()
	assert_true(MetaSkillManager.is_unlocked(_tree(), &"g4_titan"), "bought through upgrade_requested")
	assert_eq(PersistedData.get_currency(PersistedData.LEAVES), 0, "1500 Leaves for a capstone")
	screen.refresh()
	assert_eq(view.button(&"g4_titan").state, UxTreeModel.NodeState.MAXED)
	portrait.queue_free()
	await wait_frames(1)
