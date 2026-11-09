extends TestCase

## Ranked meta-skill nodes: price and effect per rank, the three tier gates,
## prerequisites, capstones (only the equipped one applies) and the card pill.
## A throwaway tree is registered for each test; the shipped trees are checked
## for the save-compatibility rule (rank 1 == the pre-rank node).

const TREE := &"test_ranked"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"


func before_each() -> void:
	if is_isolated():
		PersistedData.wipe_progress(false)
	var t := MetaSkillTree.new()
	t.id = TREE
	var hp := MetaSkillNode.make(&"hp", "Iron Skin", "+5% HP per rank", 1, 100, PersistedData.GOLD, "max_health", 1.05)
	hp.max_rank = 3
	hp.branch = 1
	var flat := MetaSkillNode.make(&"flat", "Flat", "+10 dmg per rank", 1, 50, PersistedData.GOLD, "attack_damage", 10.0, false)
	flat.max_rank = 2
	flat.rank_costs = [50, 120]
	flat.branch = 0
	var top := MetaSkillNode.make(&"top", "Top", "needs flat", 2, 10, PersistedData.GOLD, "move_speed", 1.1)
	top.requires = [&"flat"]
	top.branch = 0
	t.nodes = [hp, flat, top]
	MetaSkillManager.trees[TREE] = t


func after_each() -> void:
	MetaSkillManager.trees.erase(TREE)


func _tree() -> MetaSkillTree:
	return MetaSkillManager.get_tree_def(TREE)


## Adds three tier-4 capstones (branches 2, 0, 1 in tree order) to the test tree.
func _add_capstones() -> void:
	for spec: Array in [[&"cap_c", 2, "move_speed", 1.30], [&"cap_a", 0, "attack_damage", 1.50], [&"cap_b", 1, "max_health", 1.40]]:
		var cap := MetaSkillNode.make(spec[0], String(spec[0]), "", 4, 100, PersistedData.GOLD, spec[2], spec[3])
		cap.branch = spec[1]
		cap.capstone = true
		_tree().nodes.append(cap)


# ---------------------------------------------------------------- the node

func test_value_at_rank_is_linear_per_rank() -> void:
	var n := MetaSkillNode.make(&"x", "x", "", 1, 100, PersistedData.GOLD, "max_health", 1.05)
	n.max_rank = 3
	assert_near(n.value_at_rank(0), 1.0, 0.0001, "rank 0 is neutral")
	assert_near(n.value_at_rank(1), 1.05, 0.0001, "rank 1 == the pre-rank value")
	assert_near(n.value_at_rank(3), 1.15, 0.0001, "+5% per rank, not 1.05^3")
	assert_near(n.value_at_rank(9), 1.15, 0.0001, "clamped to max_rank")
	var a := MetaSkillNode.make(&"y", "y", "", 1, 100, PersistedData.GOLD, "stun_duration", 0.5, false)
	a.max_rank = 2
	assert_near(a.value_at_rank(0), 0.0, 0.0001, "additive rank 0 is 0")
	assert_near(a.value_at_rank(2), 1.0, 0.0001, "additive: 0.5 x 2")


func test_explicit_rank_values_win_over_the_linear_rule() -> void:
	var n := MetaSkillNode.make(&"x", "x", "", 1, 60, PersistedData.GOLD, "monster_damage_mult", 1.10)
	n.max_rank = 5
	n.rank_values = [1.10, 1.14, 1.17]
	assert_near(n.value_at_rank(1), 1.10)
	assert_near(n.value_at_rank(3), 1.17, 0.0001, "the cumulative table, not +10% per rank")
	assert_near(n.value_at_rank(4), 1.40, 0.0001, "past the table: the linear rule")
	assert_near(n.value_at_rank(0), 1.0)


func test_cost_per_rank() -> void:
	var n := MetaSkillNode.make(&"x", "x", "", 1, 100, PersistedData.GOLD, "max_health", 1.05)
	n.max_rank = 3
	assert_eq(n.cost_of_rank(1), 100)
	assert_eq(n.cost_of_rank(2), 150, "cost x 1.5")
	assert_eq(n.cost_of_rank(3), 225, "rounded to 5")
	assert_eq(n.cost_of_rank(0), 0)
	assert_eq(n.cost_of_rank(4), 0, "beyond max")
	n.rank_costs = [40, 60, 100]
	assert_eq(n.cost_of_rank(1), 40, "the explicit row wins, rank 1 too")
	assert_eq(n.cost_of_rank(3), 100)


## Save compatibility: every shipped node's rank 1 is the node as it was before
## ranks (same price, same value), so an old save that owns it plays the same.
func test_rank_one_equals_the_pre_rank_node_on_every_shipped_tree() -> void:
	var checked := 0
	for tree_id: StringName in MetaSkillManager.trees:
		if tree_id == TREE:
			continue
		var t: MetaSkillTree = MetaSkillManager.get_tree_def(tree_id)
		for n in t.nodes:
			assert_near(n.value_at_rank(1), n.stat_value, 0.000001, "%s/%s value" % [tree_id, n.id])
			assert_eq(n.cost_of_rank(1), n.cost, "%s/%s price" % [tree_id, n.id])
			checked += 1
	assert_true(checked >= 71, "every shipped node checked (%d)" % checked)


## The same save, read through ranks, gives the monster exactly the modifiers
## the pre-rank rule (stat_value per owned node, stacked) gave.
func test_a_rank_one_save_applies_the_pre_rank_values() -> void:
	if not require_isolated():
		return
	var expected: Dictionary = {}
	for tree_id: StringName in [MetaSkillManager.TREE_MONSTER_BASE, MetaSkillManager.monster_tree_id(&"grount")]:
		var t: MetaSkillTree = MetaSkillManager.get_tree_def(tree_id)
		var ids: Array = []
		for n in t.nodes:
			ids.append(String(n.id))
			if n.stat_name.is_empty() or n.is_ability_node():
				continue
			if n.stat_multiplicative:
				expected[n.stat_name] = float(expected.get(n.stat_name, 1.0)) * n.stat_value
			else:
				expected[n.stat_name] = float(expected.get(n.stat_name, 0.0)) + n.stat_value
		PersistedData.set_unlocked_skills(tree_id, ids)
	var mods: Dictionary = MetaSkillManager.collect_monster_modifiers(&"grount")
	assert_eq(mods.size(), expected.size(), str(mods))
	for key: String in expected:
		assert_near(float(mods.get(key, -1.0)), float(expected[key]), 0.000001, key)


# ---------------------------------------------------------------- buying

func test_rank_up_spends_and_stops_at_max() -> void:
	if not require_isolated():
		return
	PersistedData.add_currency(PersistedData.GOLD, 1000)
	assert_eq(MetaSkillManager.next_rank_cost(TREE, &"hp"), 100)
	assert_true(MetaSkillManager.rank_up(TREE, &"hp"))
	assert_eq(MetaSkillManager.node_state(TREE, &"hp"), MetaSkillManager.NodeState.AVAILABLE, "owned below max: the next rank is for sale")
	assert_eq(MetaSkillManager.next_rank_cost(TREE, &"hp"), 150)
	assert_true(MetaSkillManager.rank_up(TREE, &"hp"))
	assert_true(MetaSkillManager.rank_up(TREE, &"hp"))
	assert_eq(MetaSkillManager.get_rank(TREE, &"hp"), 3)
	assert_true(MetaSkillManager.is_maxed(TREE, &"hp"))
	assert_eq(PersistedData.get_currency(PersistedData.GOLD), 1000 - 100 - 150 - 225)
	assert_eq(MetaSkillManager.next_rank_cost(TREE, &"hp"), 0, "nothing left to buy")
	assert_false(MetaSkillManager.rank_up(TREE, &"hp"), "maxed")
	assert_eq(MetaSkillManager.node_state(TREE, &"hp"), MetaSkillManager.NodeState.UNLOCKED)
	assert_false(MetaSkillManager.unlock(TREE, &"hp"), "unlock() is rank 1 only")
	assert_eq(MetaSkillManager.points_spent(TREE), 3)
	assert_eq(PersistedData.get_unlocked_skills(TREE), ["hp"], "the pre-rank view: owned ids")


func test_next_rank_unaffordable() -> void:
	if not require_isolated():
		return
	PersistedData.add_currency(PersistedData.GOLD, 150)
	assert_true(MetaSkillManager.rank_up(TREE, &"flat"))
	assert_eq(MetaSkillManager.node_state(TREE, &"flat"), MetaSkillManager.NodeState.UNAFFORDABLE, "rank 2 costs 120, 100 left")
	assert_false(MetaSkillManager.rank_up(TREE, &"flat"))
	assert_eq(PersistedData.get_currency(PersistedData.GOLD), 100, "no charge")
	assert_eq(MetaSkillManager.get_rank(TREE, &"flat"), 1)


func test_signals_fire_per_rank() -> void:
	if not require_isolated():
		return
	PersistedData.add_currency(PersistedData.GOLD, 1000)
	var seen: Array = []
	var on_rank := func(_t: StringName, id: StringName, r: int) -> void: seen.append("%s:%d" % [id, r])
	var unlocked: Array = [0]
	var on_unlock := func(_t: StringName, _id: StringName) -> void: unlocked[0] += 1
	var events: Array = []
	var provider := func(e: Dictionary) -> void: events.append([e.get("name"), e.get("rank", 0)])
	MetaSkillManager.skill_ranked.connect(on_rank)
	MetaSkillManager.skill_unlocked.connect(on_unlock)
	AnalyticsSink.set_provider(provider)
	MetaSkillManager.rank_up(TREE, &"flat")
	MetaSkillManager.rank_up(TREE, &"flat")
	AnalyticsSink.set_provider(Callable())
	MetaSkillManager.skill_ranked.disconnect(on_rank)
	MetaSkillManager.skill_unlocked.disconnect(on_unlock)
	assert_eq(seen, ["flat:1", "flat:2"])
	assert_eq(unlocked[0], 1, "skill_unlocked only for rank 1 (analytics keep their meaning)")
	assert_eq(events, [["skill_unlocked", 0], ["skill_ranked", 2]], "analytics: unlocked, then the rank-up")


## Ranks reach the entity through the same single apply call per node.
func test_ranked_stat_node_applies_to_a_spawned_hero() -> void:
	if not require_isolated():
		return
	var n: MetaSkillNode = MetaSkillManager.get_tree_def(MetaSkillManager.TREE_HERO_BASE).find_node(&"t1_hp")
	var old_max := n.max_rank
	n.max_rank = 3
	PersistedData.set_skill_rank(MetaSkillManager.TREE_HERO_BASE, &"t1_hp", 3)
	var vlad := await spawn_entity(VLAD, Vector2(0, 0))
	var stats := vlad.get_node("HeroStats") as HeroStatsComponent
	assert_near(stats.get_max_health(), stats.base_stats.base_max_health * 1.15, 0.01, "3 ranks of +5% = +15%")
	n.max_rank = old_max
	vlad.queue_free()


# ---------------------------------------------------------------- gates

func test_tier_below_gate_and_requires() -> void:
	if not require_isolated():
		return
	PersistedData.add_currency(PersistedData.GOLD, 1000)
	assert_false(MetaSkillManager.is_tier_open(TREE, 2))
	assert_eq(MetaSkillManager.node_state(TREE, &"top"), MetaSkillManager.NodeState.TIER_GATED)
	assert_true(MetaSkillManager.rank_up(TREE, &"hp"))
	assert_true(MetaSkillManager.is_tier_open(TREE, 2), "a tier-1 node owned")
	assert_eq(MetaSkillManager.node_state(TREE, &"top"), MetaSkillManager.NodeState.REQUIRES_MISSING, "tier open, prerequisite missing")
	assert_false(MetaSkillManager.rank_up(TREE, &"top"))
	assert_true(MetaSkillManager.rank_up(TREE, &"flat"))
	assert_true(MetaSkillManager.is_node_available(TREE, &"top"))


func test_requires_any_by_default_or_all() -> void:
	if not require_isolated():
		return
	var top: MetaSkillNode = _tree().find_node(&"top")
	top.requires = [&"flat", &"hp"]
	PersistedData.add_currency(PersistedData.GOLD, 1000)
	assert_true(MetaSkillManager.rank_up(TREE, &"hp"))
	assert_true(MetaSkillManager.is_node_available(TREE, &"top"), "any one of the two is enough")
	top.requires_all = true
	assert_eq(MetaSkillManager.node_state(TREE, &"top"), MetaSkillManager.NodeState.REQUIRES_MISSING, "requires_all: both")
	assert_true(MetaSkillManager.rank_up(TREE, &"flat"))
	assert_true(MetaSkillManager.is_node_available(TREE, &"top"))


## Base trees: a tier opens once that many ranks are owned in the tree.
func test_points_gate() -> void:
	if not require_isolated():
		return
	_tree().gate_kind = MetaSkillTree.GateKind.POINTS
	_tree().tier_gates = [0, 3]
	PersistedData.add_currency(PersistedData.GOLD, 5000)
	assert_true(MetaSkillManager.rank_up(TREE, &"flat"))
	assert_true(MetaSkillManager.rank_up(TREE, &"flat"))
	assert_eq(MetaSkillManager.points_spent(TREE), 2)
	assert_eq(MetaSkillManager.node_state(TREE, &"top"), MetaSkillManager.NodeState.TIER_GATED, "2 of 3 ranks")
	assert_true(MetaSkillManager.rank_up(TREE, &"hp"))
	assert_true(MetaSkillManager.is_tier_open(TREE, 2), "3 ranks owned")
	assert_true(MetaSkillManager.is_node_available(TREE, &"top"))
	assert_true(MetaSkillManager.is_tier_open(TREE, 4), "a tier past the table uses its last entry")


## Character trees: a tier opens at the owner's permanent level (from its XP).
func test_level_gate_reads_the_owners_permanent_level() -> void:
	if not require_isolated():
		return
	_tree().gate_kind = MetaSkillTree.GateKind.LEVEL
	_tree().tier_gates = [1, 3]
	_tree().owner_id = &"vlad"
	PersistedData.add_currency(PersistedData.GOLD, 5000)
	assert_true(MetaSkillManager.rank_up(TREE, &"flat"), "tier 1 is always open")
	assert_eq(MetaSkillManager.owner_level(_tree()), 1)
	assert_eq(MetaSkillManager.node_state(TREE, &"top"), MetaSkillManager.NodeState.LEVEL_GATED, "Vlad is Lv.1")
	PersistedData.add_hero_xp(&"vlad", 100)
	assert_eq(MetaSkillManager.node_state(TREE, &"top"), MetaSkillManager.NodeState.LEVEL_GATED, "Lv.2 is not enough")
	PersistedData.add_monster_xp(&"vlad", 5000)
	assert_eq(MetaSkillManager.node_state(TREE, &"top"), MetaSkillManager.NodeState.LEVEL_GATED, "a hero tree reads hero XP")
	PersistedData.add_hero_xp(&"vlad", 200)
	assert_eq(MetaSkillManager.owner_level(_tree()), 3)
	assert_true(MetaSkillManager.is_node_available(TREE, &"top"), "Lv.3 opens tier 2")


## Gates guard buying rank 1 only: a save that owns a node above today's gate
## keeps it, it applies, and its next rank can be bought.
func test_gates_never_revoke_an_owned_node() -> void:
	if not require_isolated():
		return
	_tree().gate_kind = MetaSkillTree.GateKind.LEVEL
	_tree().tier_gates = [1, 8]
	_tree().owner_id = &"vlad"
	var top: MetaSkillNode = _tree().find_node(&"top")
	top.max_rank = 2
	PersistedData.set_skill_rank(TREE, &"top", 1)
	assert_false(MetaSkillManager.is_tier_open(TREE, 2))
	assert_true(MetaSkillManager.is_unlocked(TREE, &"top"))
	var applied := MetaSkillManager.applied_ranks(TREE)
	assert_true(applied.size() == 1 and applied.get(&"top", 0) == 1, "it still applies: %s" % applied)
	assert_eq(MetaSkillManager.node_state(TREE, &"top"), MetaSkillManager.NodeState.UNAFFORDABLE, "rank 2 is only a price away")
	PersistedData.add_currency(PersistedData.GOLD, 100)
	assert_true(MetaSkillManager.rank_up(TREE, &"top"))
	assert_eq(MetaSkillManager.node_state(TREE, &"top"), MetaSkillManager.NodeState.UNLOCKED)


func test_unknown_trees_and_nodes() -> void:
	assert_eq(MetaSkillManager.node_state(&"no_tree", &"x"), MetaSkillManager.NodeState.INVALID)
	assert_eq(MetaSkillManager.node_state(TREE, &"no_node"), MetaSkillManager.NodeState.INVALID)
	assert_eq(MetaSkillManager.next_rank_cost(TREE, &"no_node"), 0)
	assert_false(MetaSkillManager.is_maxed(TREE, &"no_node"))
	assert_true(MetaSkillManager.is_tier_open(&"no_tree", 3))
	assert_eq(MetaSkillManager.equipped_capstone(&"no_tree"), &"")
	assert_eq(MetaSkillManager.card_progress(&"no_tree"), {"owned_ranks": 0, "open_ranks": 0, "upgrade_ready": false})
	if not require_isolated():
		return
	PersistedData.set_skill_rank(TREE, &"retired", 2)
	assert_eq(MetaSkillManager.node_state(TREE, &"retired"), MetaSkillManager.NodeState.UNLOCKED, "an owned id outlives its node")
	assert_eq(MetaSkillManager.points_spent(TREE), 2, "and still counts as bought ranks")
	assert_true(MetaSkillManager.applied_ranks(TREE).is_empty(), "but applies nothing")


# ---------------------------------------------------------------- capstones

func test_capstones_sort_by_branch() -> void:
	_add_capstones()
	var ids: Array[StringName] = []
	for n in _tree().capstones():
		ids.append(n.id)
	assert_eq(ids, [&"cap_a", &"cap_b", &"cap_c"] as Array[StringName])


## All three can be owned; exactly one applies. Buying the first equips it, a
## later purchase does not take over, equip_capstone swaps for free.
func test_capstone_exclusivity() -> void:
	if not require_isolated():
		return
	_add_capstones()
	PersistedData.add_currency(PersistedData.GOLD, 1000)
	PersistedData.set_unlocked_skills(TREE, ["hp", "top"])  # opens tier 4 (TIER_BELOW chain)
	PersistedData.set_skill_rank(TREE, &"flat", 1)
	_tree().find_node(&"top").tier = 3
	assert_eq(MetaSkillManager.equipped_capstone(TREE), &"", "none owned")
	assert_true(MetaSkillManager.rank_up(TREE, &"cap_c"))
	assert_eq(MetaSkillManager.equipped_capstone(TREE), &"cap_c", "the first purchase equips it")
	assert_true(MetaSkillManager.rank_up(TREE, &"cap_a"))
	assert_eq(MetaSkillManager.equipped_capstone(TREE), &"cap_c", "buying a second one does not swap")
	var gold_before := PersistedData.get_currency(PersistedData.GOLD)
	var changed: Array = [0]
	var on_changed := func() -> void: changed[0] += 1
	MetaSkillManager.skills_changed.connect(on_changed)
	assert_true(MetaSkillManager.equip_capstone(TREE, &"cap_a"))
	assert_true(MetaSkillManager.equip_capstone(TREE, &"cap_a"), "equipping the equipped one is fine")
	MetaSkillManager.skills_changed.disconnect(on_changed)
	assert_eq(changed[0], 1, "one refresh for one swap")
	assert_eq(MetaSkillManager.equipped_capstone(TREE), &"cap_a")
	assert_eq(PersistedData.get_currency(PersistedData.GOLD), gold_before, "swapping is free")
	assert_false(MetaSkillManager.equip_capstone(TREE, &"cap_b"), "not owned")
	assert_false(MetaSkillManager.equip_capstone(TREE, &"hp"), "not a capstone")
	var applied := MetaSkillManager.applied_ranks(TREE)
	assert_true(applied.has(&"cap_a"), "the equipped capstone applies")
	assert_false(applied.has(&"cap_c"), "the other owned one does not")
	assert_true(applied.has(&"hp") and applied.has(&"top"), "ordinary nodes are unaffected")
	PersistedData.load_data()
	assert_eq(MetaSkillManager.equipped_capstone(TREE), &"cap_a", "the choice is saved")


## A save with capstones but no choice saved (v2 saves: Titan Form) equips the
## first owned capstone in branch order, and that one keeps applying when a
## second one is bought.
func test_no_saved_choice_equips_the_first_owned_capstone() -> void:
	if not require_isolated():
		return
	_add_capstones()
	PersistedData.set_unlocked_skills(TREE, ["hp", "top", "cap_c", "cap_b"])
	_tree().find_node(&"top").tier = 3
	assert_eq(PersistedData.get_equipped_capstone(TREE), &"", "nothing saved")
	assert_eq(MetaSkillManager.equipped_capstone(TREE), &"cap_b", "branch 1 before branch 2")
	PersistedData.add_currency(PersistedData.GOLD, 100)
	assert_true(MetaSkillManager.rank_up(TREE, &"cap_a"))
	assert_eq(MetaSkillManager.equipped_capstone(TREE), &"cap_b", "the branch-0 purchase does not take over")
	assert_eq(PersistedData.get_equipped_capstone(TREE), &"cap_b", "the choice is written down")
	PersistedData.set_skill_rank(TREE, &"cap_b", 0)
	assert_eq(MetaSkillManager.equipped_capstone(TREE), &"cap_a", "a saved choice that is not owned falls back")


## Titan Form, the one capstone a v2 save can own, keeps applying.
func test_titan_form_owners_keep_it_equipped() -> void:
	if not require_isolated():
		return
	var tree := MetaSkillManager.monster_tree_id(&"grount")
	assert_true(MetaSkillManager.get_tree_def(tree).find_node(&"g4_titan").capstone)
	PersistedData.set_unlocked_skills(tree, ["g3_enrage", "g4_titan"])
	assert_eq(MetaSkillManager.equipped_capstone(tree), &"g4_titan")
	var mods: Dictionary = MetaSkillManager.collect_monster_modifiers(&"grount")
	assert_near(float(mods.get("monster_titan_form", 0.0)), 1.0, 0.0001, "Titan Form applies")
	var g := (await spawn_frozen(GROUNT, Vector2.ZERO)) as MonsterBase
	assert_true(g.debug_meta_line().contains("titan"), "the spawned Grount has it: " + g.debug_meta_line())
	g.queue_free()


# ---------------------------------------------------------------- the card pill

func test_card_progress() -> void:
	if not require_isolated():
		return
	assert_eq(MetaSkillManager.card_progress(TREE), {"owned_ranks": 0, "open_ranks": 5, "upgrade_ready": false},
		"tier 1 open (3 + 2 ranks), no Gold")
	PersistedData.add_currency(PersistedData.GOLD, 100)
	assert_true(bool(MetaSkillManager.card_progress(TREE)["upgrade_ready"]), "a rank can be bought")
	assert_true(MetaSkillManager.rank_up(TREE, &"flat"))
	assert_eq(MetaSkillManager.card_progress(TREE), {"owned_ranks": 1, "open_ranks": 6, "upgrade_ready": true},
		"tier 2 opened (+1 rank); the 50 Gold left buys Top")
	PersistedData.spend_currency(PersistedData.GOLD, 50)
	assert_false(bool(MetaSkillManager.card_progress(TREE)["upgrade_ready"]), "nothing affordable")
	_tree().gate_kind = MetaSkillTree.GateKind.LEVEL
	_tree().tier_gates = [1, 5]
	_tree().owner_id = &"vlad"
	PersistedData.set_skill_rank(TREE, &"top", 1)
	assert_eq(MetaSkillManager.card_progress(TREE)["open_ranks"], 6, "a closed tier counts what is owned in it")
