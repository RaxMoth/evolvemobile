extends TestCase

## Skill trees v2 (Data/SkillTrees/*.tres, generated once from
## Scripts/MetaSkills/skill_tree_data_v2.gd by tools/build_skill_trees.gd): the
## port of the design's validate_trees_v2. Save compatibility against a frozen
## copy of the v1 seeds (every v1 id kept, rank 1 = the v1 effect), the shape
## of all nine trees, every ability node against its character's kit, the AI
## build orders, hidden nodes, the "{v}" effect texts and the four v1 nodes the
## ability renames / retargets bring to life.

const TREE_DIR := "res://Data/SkillTrees"
const TREE_IDS: Array[StringName] = [&"hero_base", &"monster_base", &"hero_river", &"hero_vlad",
	&"hero_ted", &"hero_irelia", &"monster_grount", &"monster_nyxa", &"monster_gorrak"]
## Not in the roster until Phase 6: generated, not registered.
const UNLINKED: Array[StringName] = [&"monster_nyxa", &"monster_gorrak"]
## The throwaway tree of the hidden-node tests (_register_hidden_tree).
const HIDDEN_TREE := &"test_hidden_nodes"
const TED := "res://Scenes/NPCs/Hero/Heros/Support/Ted/Ted.tscn"
const IRELIA := "res://Scenes/NPCs/Hero/Heros/Support/Irelia/Irelia.tscn"

## The v1 trees as MetaSkillManager seeded them in code before v2 (7a866a0):
## [tree, id, tier, stat or ability property, value, multiplicative, ability].
const V1: Array = [
	[&"hero_base", &"t1_hp", 1, "max_health", 1.05, true, ""],
	[&"hero_base", &"t1_speed", 1, "move_speed", 1.05, true, ""],
	[&"hero_base", &"t1_dmg", 1, "attack_damage", 1.05, true, ""],
	[&"hero_base", &"t2_dmg", 2, "attack_damage", 1.10, true, ""],
	[&"hero_base", &"t2_hp", 2, "max_health", 1.10, true, ""],
	[&"hero_base", &"t2_atkspd", 2, "attack_speed", 1.10, true, ""],
	[&"hero_base", &"t3_hp", 3, "max_health", 1.15, true, ""],
	[&"hero_base", &"t3_atkspd", 3, "attack_speed", 1.15, true, ""],
	[&"hero_base", &"t3_speed", 3, "move_speed", 1.15, true, ""],
	[&"hero_base", &"t4_dmg", 4, "attack_damage", 1.20, true, ""],
	[&"hero_base", &"t4_hp", 4, "max_health", 1.25, true, ""],
	[&"hero_base", &"t4_atkspd", 4, "attack_speed", 1.25, true, ""],
	[&"monster_base", &"mt1_hp", 1, "monster_health_mult", 1.10, true, ""],
	[&"monster_base", &"mt1_speed", 1, "monster_speed_mult", 1.05, true, ""],
	[&"monster_base", &"mt1_xp", 1, "monster_xp_mult", 1.10, true, ""],
	[&"monster_base", &"mt2_evo", 2, "monster_evo_threshold", 0.90, true, ""],
	[&"monster_base", &"mt2_dmg", 2, "monster_damage_mult", 1.15, true, ""],
	[&"monster_base", &"mt3_hp", 3, "monster_health_mult", 1.20, true, ""],
	[&"monster_base", &"mt3_range", 3, "monster_range_mult", 1.10, true, ""],
	[&"hero_river", &"r1_range", 1, "attack_range", 1.08, true, ""],
	[&"hero_river", &"r1_speed", 1, "move_speed", 1.05, true, ""],
	[&"hero_river", &"r1_hp", 1, "max_health", 1.05, true, ""],
	[&"hero_river", &"r2_dmg", 2, "attack_damage", 1.10, true, ""],
	[&"hero_river", &"r2_atkspd", 2, "attack_speed", 1.10, true, ""],
	[&"hero_river", &"r3_range", 3, "attack_range", 1.15, true, ""],
	[&"hero_river", &"r3_hp", 3, "max_health", 1.15, true, ""],
	[&"hero_river", &"r2_dropcd", 2, "cooldown", 0.80, true, "Emergency Supply Drop"],
	[&"hero_river", &"r3_dropheal", 3, "heal_amount", 1.50, true, "Emergency Supply Drop"],
	[&"hero_river", &"r2_triple", 2, "extra_targets", 2.0, false, "Adaptive Weapon"],
	[&"hero_vlad", &"v1_dmg", 1, "attack_damage", 1.05, true, ""],
	[&"hero_vlad", &"v1_atkspd", 1, "attack_speed", 1.05, true, ""],
	[&"hero_vlad", &"v1_hp", 1, "max_health", 1.05, true, ""],
	[&"hero_vlad", &"v2_dmg", 2, "attack_damage", 1.10, true, ""],
	[&"hero_vlad", &"v2_hp", 2, "max_health", 1.10, true, ""],
	[&"hero_vlad", &"v3_atkspd", 3, "attack_speed", 1.15, true, ""],
	[&"hero_vlad", &"v3_dmg", 3, "attack_damage", 1.20, true, ""],
	[&"hero_vlad", &"v2_bombaoe", 2, "area_of_effect", 1.25, true, "Blood Bomb"],
	[&"hero_vlad", &"v3_minecd", 3, "cooldown", 0.75, true, "Land Mine"],
	[&"hero_ted", &"t1_hp", 1, "max_health", 1.05, true, ""],
	[&"hero_ted", &"t1_speed", 1, "move_speed", 1.05, true, ""],
	[&"hero_ted", &"t1_range", 1, "attack_range", 1.05, true, ""],
	[&"hero_ted", &"t2_dmg", 2, "attack_damage", 1.10, true, ""],
	[&"hero_ted", &"t2_atkspd", 2, "attack_speed", 1.10, true, ""],
	[&"hero_ted", &"t3_hp", 3, "max_health", 1.15, true, ""],
	[&"hero_ted", &"t3_range", 3, "attack_range", 1.15, true, ""],
	[&"hero_ted", &"t2_trapcd", 2, "cooldown", 0.80, true, "Trap Cage"],
	[&"hero_ted", &"t3_trapdur", 3, "duration", 1.50, true, "Trap Cage"],
	[&"hero_irelia", &"i1_hp", 1, "max_health", 1.08, true, ""],
	[&"hero_irelia", &"i1_dmg", 1, "attack_damage", 1.05, true, ""],
	[&"hero_irelia", &"i1_speed", 1, "move_speed", 1.05, true, ""],
	[&"hero_irelia", &"i2_hp", 2, "max_health", 1.12, true, ""],
	[&"hero_irelia", &"i2_atkspd", 2, "attack_speed", 1.10, true, ""],
	[&"hero_irelia", &"i3_hp", 3, "max_health", 1.20, true, ""],
	[&"hero_irelia", &"i3_dmg", 3, "attack_damage", 1.10, true, ""],
	[&"hero_irelia", &"i2_rallycd", 2, "cooldown", 0.80, true, "Rally Cry"],
	[&"hero_irelia", &"i3_dashcd", 3, "cooldown", 0.70, true, "Dash"],
	[&"monster_grount", &"g1_dmg", 1, "monster_damage_mult", 1.10, true, ""],
	[&"monster_grount", &"g1_speed", 1, "monster_speed_mult", 1.05, true, ""],
	[&"monster_grount", &"g1_range", 1, "monster_range_mult", 1.10, true, ""],
	[&"monster_grount", &"g2_evo", 2, "monster_evo_threshold", 0.90, true, ""],
	[&"monster_grount", &"g2_hp", 2, "monster_health_mult", 1.15, true, ""],
	[&"monster_grount", &"g3_dmg", 3, "monster_damage_mult", 1.20, true, ""],
	[&"monster_grount", &"g3_speed", 3, "monster_speed_mult", 1.15, true, ""],
	[&"monster_grount", &"g2_cleavecd", 2, "cooldown", 0.85, true, "Front Cleave"],
	[&"monster_grount", &"g3_dash", 3, "dash_distance", 1.33, true, "Ram Dash"],
	[&"monster_grount", &"g3_slam", 3, "slam_radius", 1.20, true, "Ground Slam"],
	[&"monster_grount", &"g1_stun", 1, "stun_duration", 0.5, false, "Ram Dash"],
	[&"monster_grount", &"g2_earlyslam", 2, "unlock_stage", -1.0, false, "Ground Slam"],
	[&"monster_grount", &"g3_pull", 3, "pull_radius", 200.0, false, "Ground Slam"],
	[&"monster_grount", &"g3_enrage", 3, "monster_enrage", 1.0, false, ""],
	[&"monster_grount", &"g4_titan", 4, "monster_titan_form", 1.0, false, ""],
]
## v1 nodes that never applied (their ability name matched no ability of the
## hero) and the effect v2 gives them: id -> [ability, property].
const RETARGETED: Dictionary = {
	&"i2_rallycd": ["Divine Shield", "cooldown"],
	&"i3_dashcd": ["Monster Taunt", "cooldown"],
	&"t2_trapcd": ["Trap Cage", "cooldown"],
	&"t3_trapdur": ["Trap Cage", "duration"],
}


func before_each() -> void:
	if is_isolated():
		PersistedData.wipe_progress(false)


func after_each() -> void:
	MetaSkillManager.trees.erase(HIDDEN_TREE)
	if is_isolated():
		PersistedData.wipe_progress(false)


func _load_tree(tree_id: StringName) -> MetaSkillTree:
	return load("%s/%s.tres" % [TREE_DIR, tree_id]) as MetaSkillTree


## A throwaway tree (after_each removes it), as the shipped trees change while
## batches unhide their nodes. Tier 1, no gates: Shown, Secret (hidden), Both
## (needs Secret or Shown) and Orphan (needs Secret).
func _register_hidden_tree() -> MetaSkillTree:
	var t := MetaSkillTree.new()
	t.id = HIDDEN_TREE
	var shown := MetaSkillNode.make(&"shown", "Shown", "+{v}% max HP", 1, 100, PersistedData.GOLD, "max_health", 1.05)
	var secret := MetaSkillNode.make(&"secret", "Secret", "-{v}% damage taken", 1, 100, PersistedData.GOLD, "damage_taken_mult", 0.9)
	secret.hidden = true
	var both := MetaSkillNode.make(&"both", "Both", "+{v}% damage", 1, 100, PersistedData.GOLD, "attack_damage", 1.1)
	both.requires = [&"secret", &"shown"]
	var orphan := MetaSkillNode.make(&"orphan", "Orphan", "+{v}% move speed", 1, 100, PersistedData.GOLD, "move_speed", 1.1)
	orphan.requires = [&"secret"]
	t.nodes = [shown, secret, both, orphan]
	MetaSkillManager.register_tree(t)
	return t


# ------------------------------------------------------- save compatibility

func test_all_71_v1_nodes_are_kept_with_their_rank_1_effect() -> void:
	var errors: Array[String] = []
	var kept := 0
	for row: Array in V1:
		var tree_id: StringName = row[0]
		var id: StringName = row[1]
		var t: MetaSkillTree = MetaSkillManager.get_tree_def(tree_id)
		var n: MetaSkillNode = t.find_node(id) if t != null else null
		if n == null:
			errors.append("%s/%s missing" % [tree_id, id])
			continue
		kept += 1
		if n.hidden:
			errors.append("%s/%s hidden: an old purchase would vanish from the screen" % [tree_id, id])
		if n.tier != int(row[2]):
			errors.append("%s/%s tier %d -> %d" % [tree_id, id, row[2], n.tier])
		if n.stat_multiplicative != bool(row[5]):
			errors.append("%s/%s multiplicative flag changed" % [tree_id, id])
		if not is_equal_approx(n.value_at_rank(1), float(row[4])):
			errors.append("%s/%s rank 1 = %s, v1 %s" % [tree_id, id, n.value_at_rank(1), row[4]])
		if not is_equal_approx(n.stat_value, float(row[4])):
			errors.append("%s/%s stat_value %s, v1 %s" % [tree_id, id, n.stat_value, row[4]])
		var target: Array = RETARGETED.get(id, [row[6], row[3]])
		if n.ability_name != String(target[0]) or n.stat_name != String(target[1]):
			errors.append("%s/%s effect %s.%s, expected %s.%s" % [tree_id, id, n.ability_name, n.stat_name, target[0], target[1]])
	assert_eq(errors, [] as Array[String], "v1 nodes kept: %d, errors=%d" % [kept, errors.size()])
	assert_eq(kept, 71, "v1 nodes kept")


## An old save owns rank 1 of its nodes: the same effects as before v2, except
## the four retargeted nodes, which now reach their ability.
func test_a_v1_save_applies_the_v1_values() -> void:
	if not require_isolated():
		return
	# Every v1 node of Hero Base and Vlad's tree, as a v2 -> v3 migration owns them.
	var expected: Dictionary[String, float] = {"max_health": 1.0, "attack_damage": 1.0}
	var owned: Dictionary[StringName, Array] = {&"hero_base": [], &"hero_vlad": []}
	for row: Array in V1:
		if not owned.has(row[0]):
			continue
		owned[row[0]].append(String(row[1]))
		if expected.has(row[3]) and String(row[6]).is_empty():
			expected[row[3]] *= float(row[4])
	for tree_id: StringName in owned:
		PersistedData.set_unlocked_skills(tree_id, owned[tree_id])
	var vlad := await spawn_frozen("res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn", Vector2.ZERO)
	var stats := vlad.get_node("HeroStats") as HeroStatsComponent
	assert_near(stats.get_max_health(), stats.base_stats.base_max_health * expected["max_health"], 0.01, "max HP")
	assert_near(stats.get_attack_damage(), stats.base_stats.base_attack_damage * expected["attack_damage"], 0.01, "damage")
	var abilities := vlad.get_node("AbilitySystem") as AbilitySystem
	assert_near(abilities.ultimate_ability.area_of_effect, 150.0 * 1.25, 0.01, "Bigger Bomb rank 1")
	vlad.queue_free()


# ------------------------------------------------------------ tree shapes

func test_every_tree_file_has_the_v2_shape() -> void:
	for tree_id in TREE_IDS:
		var t := _load_tree(tree_id)
		assert_true(t != null, "%s.tres loads" % tree_id)
		if t == null:
			continue
		var errors: Array[String] = []
		var side_wide := String(tree_id).ends_with("_base")
		var currency := PersistedData.GOLD if side_wide else (PersistedData.STEEL if String(tree_id).begins_with("hero_") else PersistedData.LEAVES)
		if t.id != tree_id:
			errors.append("id %s" % t.id)
		if t.branches.size() != 3:
			errors.append("%d branches" % t.branches.size())
		if side_wide:
			if t.gate_kind != MetaSkillTree.GateKind.POINTS or t.tier_gates != ([0, 4, 10, 18] as Array[int]) or t.owner_id != &"":
				errors.append("base trees gate on points 0/4/10/18")
		elif t.gate_kind != MetaSkillTree.GateKind.LEVEL or t.tier_gates != ([1, 3, 5, 8] as Array[int]) or String(t.owner_id) != String(tree_id).get_slice("_", 1):
			errors.append("character trees gate on the owner's level 1/3/5/8")
		var ids: Dictionary[StringName, MetaSkillNode] = {}
		for n in t.nodes:
			if ids.has(n.id):
				errors.append("duplicate %s" % n.id)
			ids[n.id] = n
		var caps_per_branch: Dictionary[int, int] = {}
		for n in t.nodes:
			if n.currency != currency:
				errors.append("%s costs %s" % [n.id, n.currency])
			if n.tier < 1 or n.tier > 4 or n.branch < 0 or n.branch > 2:
				errors.append("%s tier %d branch %d" % [n.id, n.tier, n.branch])
			if n.tier >= 2 and n.requires.is_empty():
				errors.append("%s: tier %d without a parent" % [n.id, n.tier])
			for r in n.requires:
				if not ids.has(r):
					errors.append("%s requires unknown %s" % [n.id, r])
				elif ids[r].tier > n.tier:
					errors.append("%s requires the higher-tier %s" % [n.id, r])
			if n.capstone:
				if n.tier != 4:
					errors.append("%s: a capstone below tier 4" % n.id)
				caps_per_branch[n.branch] = int(caps_per_branch.get(n.branch, 0)) + 1
			if n.max_rank > 1 and (n.rank_costs.size() != n.max_rank or n.rank_values.size() != n.max_rank):
				errors.append("%s: %d ranks, %d costs, %d values" % [n.id, n.max_rank, n.rank_costs.size(), n.rank_values.size()])
			if n.cost_of_rank(1) != n.cost or n.cost <= 0:
				errors.append("%s: rank 1 costs %d, cost %d" % [n.id, n.cost_of_rank(1), n.cost])
			if not is_equal_approx(n.value_at_rank(1), n.stat_value):
				errors.append("%s: rank 1 %s != stat_value %s" % [n.id, n.value_at_rank(1), n.stat_value])
			for r in range(2, n.max_rank + 1):
				if is_equal_approx(n.value_at_rank(r), n.value_at_rank(r - 1)):
					errors.append("%s: rank %d does not change the value" % [n.id, r])
				if n.cost_of_rank(r) <= n.cost_of_rank(r - 1):
					errors.append("%s: rank %d is not dearer" % [n.id, r])
		if side_wide:
			if not caps_per_branch.is_empty():
				errors.append("a base tree has capstones")
		elif caps_per_branch != ({0: 1, 1: 1, 2: 1} as Dictionary[int, int]):
			errors.append("one capstone per branch, got %s" % str(caps_per_branch))
		assert_eq(errors, [] as Array[String], String(tree_id))


func test_the_roster_links_its_trees_and_the_manager_registers_them() -> void:
	for d in GameManager.ROSTER.all():
		assert_true(d.skill_tree != null, "%s links its tree" % d.character_id())
		if d.skill_tree == null:
			continue
		assert_eq(d.skill_tree.id, d.skill_tree_id(), "%s: the tree id is the save key" % d.character_id())
		assert_eq(d.skill_tree.resource_path, "%s/%s.tres" % [TREE_DIR, d.skill_tree_id()])
		assert_true(MetaSkillManager.get_tree_def(d.skill_tree_id()) == d.skill_tree, "registered as the shared resource")
	for id: StringName in [MetaSkillManager.TREE_HERO_BASE, MetaSkillManager.TREE_MONSTER_BASE]:
		assert_eq(MetaSkillManager.get_tree_def(id).resource_path, "%s/%s.tres" % [TREE_DIR, id])
	for id in TREE_IDS:
		var registered := MetaSkillManager.get_tree_def(id) != null
		assert_eq(registered, not UNLINKED.has(id), "%s registered: only the roster's trees and the base trees" % id)
		assert_true(_load_tree(id) != null, "%s is generated" % id)


# ------------------------------------------------------------- kits and AI

## Each node that upgrades an ability names one of its character's abilities,
## and a shown one a property that ability has (a hidden one waits for code).
func test_every_ability_node_targets_its_characters_kit() -> void:
	for d in GameManager.ROSTER.all():
		var kit: Dictionary[String, AbilityBase] = {}
		for a in d.abilities():
			kit[a.ability_name] = a
		var t := d.skill_tree
		for n in t.nodes:
			if not n.is_ability_node():
				continue
			assert_true(kit.has(n.ability_name), "%s/%s targets '%s'; the kit has %s" % [t.id, n.id, n.ability_name, kit.keys()])
			if kit.has(n.ability_name) and not n.hidden:
				assert_true(n.stat_name in kit[n.ability_name], "%s/%s: %s has a property %s" % [t.id, n.id, n.ability_name, n.stat_name])
	for id in UNLINKED:
		# Their kits (Sonic Screech, Cleaver Chop, ...) arrive with Phase 6.
		for n in _load_tree(id).nodes:
			assert_true(n.is_ability_node() or n.stat_name.begins_with("monster_"), "%s/%s" % [id, n.id])


func test_ai_build_orders_are_valid() -> void:
	for tree_id in TREE_IDS:
		var t := _load_tree(tree_id)
		var order := t.ai_build_order
		var side_wide := String(tree_id).ends_with("_base")
		# Threat 4 buys 3 x 4 character ranks and 2 x 4 base ranks.
		assert_true(order.size() >= (8 if side_wide else 12), "%s: %d entries" % [tree_id, order.size()])
		var bought: Dictionary[StringName, int] = {}
		var capstone_seen := false
		for id in order:
			var n := t.find_node(id)
			assert_true(n != null, "%s: unknown %s" % [tree_id, id])
			if n == null:
				continue
			bought[id] = int(bought.get(id, 0)) + 1
			assert_true(bought[id] <= n.max_rank, "%s: %s bought past its max rank" % [tree_id, id])
			assert_false(capstone_seen and not n.capstone, "%s: the capstone comes last" % tree_id)
			capstone_seen = capstone_seen or n.capstone


# ------------------------------------------------------------ hidden nodes

func test_hidden_nodes_are_not_shown_bought_or_applied() -> void:
	if not require_isolated():
		return
	var t := _register_hidden_tree()
	var tree := HIDDEN_TREE
	PersistedData.add_currency(PersistedData.GOLD, 5000)
	assert_eq(MetaSkillManager.node_state(tree, &"secret"), MetaSkillManager.NodeState.INVALID, "not part of the game yet")
	assert_false(MetaSkillManager.rank_up(tree, &"secret"))
	assert_eq(MetaSkillManager.next_rank_cost(tree, &"secret"), 0)
	var model := UxTreeModel.from_meta_skills(tree)
	assert_true(model.find(&"secret") == null, "not on the screen")
	assert_eq(model.find(&"both").requires, [&"shown"] as Array[StringName], "its hidden parent is dropped")
	assert_eq(model.nodes.size(), t.shown_nodes().size())
	assert_eq(model.nodes.size(), 3)
	_buy(tree, [&"shown"])
	var open_before: int = MetaSkillManager.card_progress(tree)["open_ranks"]
	# A save that owns one anyway (written by hand) keeps it, but it applies nothing.
	PersistedData.set_skill_rank(tree, &"secret", 1)
	assert_eq(MetaSkillManager.node_state(tree, &"secret"), MetaSkillManager.NodeState.UNLOCKED)
	assert_false(MetaSkillManager.applied_ranks(tree).has(&"secret"))
	assert_eq(MetaSkillManager.card_progress(tree)["open_ranks"], open_before, "left out of the card pill")
	assert_eq(MetaSkillManager.card_progress(tree)["owned_ranks"], 1)


## A node whose parents are all hidden needs only its tier; a hidden parent
## next to a shown one does not open it.
func test_a_hidden_parent_neither_opens_nor_blocks() -> void:
	if not require_isolated():
		return
	_register_hidden_tree()
	var tree := HIDDEN_TREE
	PersistedData.add_currency(PersistedData.GOLD, 5000)
	assert_eq(MetaSkillManager.node_state(tree, &"orphan"), MetaSkillManager.NodeState.AVAILABLE, "its only parent is hidden")
	PersistedData.set_skill_rank(tree, &"secret", 1)
	assert_eq(MetaSkillManager.node_state(tree, &"both"), MetaSkillManager.NodeState.REQUIRES_MISSING,
		"an owned hidden parent opens nothing")
	_buy(tree, [&"shown"])
	assert_eq(MetaSkillManager.node_state(tree, &"both"), MetaSkillManager.NodeState.AVAILABLE)


## Every hidden node of a registered tree: data only, never bought or applied.
func test_shipped_hidden_nodes_stay_out_of_the_game() -> void:
	if not require_isolated():
		return
	for tree_id: StringName in TREE_IDS:
		var t := MetaSkillManager.get_tree_def(tree_id)
		if t == null:
			continue
		for n in t.nodes:
			if not n.hidden:
				continue
			assert_eq(MetaSkillManager.node_state(tree_id, n.id), MetaSkillManager.NodeState.INVALID, "%s/%s" % [tree_id, n.id])
			PersistedData.set_skill_rank(tree_id, n.id, 1)
			assert_false(MetaSkillManager.applied_ranks(tree_id).has(n.id), "%s/%s applies nothing" % [tree_id, n.id])


# ------------------------------------------------------------ gates

func test_character_tiers_open_by_permanent_level() -> void:
	if not require_isolated():
		return
	var tree := MetaSkillManager.hero_tree_id(&"irelia")
	for step: Array in [[0, 1], [300, 3], [700, 5], [1800, 8]]:
		PersistedData.add_hero_xp(&"irelia", int(step[0]))
		var level: int = step[1]
		assert_eq(MetaSkillManager.owner_level(MetaSkillManager.get_tree_def(tree)), level)
		assert_eq(MetaSkillManager.is_tier_open(tree, 2), level >= 3, "tier 2 at Lv %d" % level)
		assert_eq(MetaSkillManager.is_tier_open(tree, 3), level >= 5, "tier 3 at Lv %d" % level)
		assert_eq(MetaSkillManager.is_tier_open(tree, 4), level >= 8, "tier 4 at Lv %d" % level)
	assert_true(MetaSkillManager.is_tier_open(MetaSkillManager.hero_tree_id(&"vlad"), 1), "tier 1 is always open")
	assert_false(MetaSkillManager.is_tier_open(MetaSkillManager.hero_tree_id(&"vlad"), 2), "another hero's level")


# ------------------------------------------------------------ effect texts

func test_effect_texts_fill_in_the_rank_value() -> void:
	var cases: Array = [
		[&"hero_base", &"t1_hp", 1, "+5% max HP"],
		[&"hero_base", &"t1_hp", 3, "+10% max HP"],
		[&"hero_base", &"t1_hp", 0, "+5% max HP"],
		[&"hero_base", &"t1_hp", 9, "+10% max HP"],
		[&"hero_irelia", &"i2_rallycd", 1, "Divine Shield cooldown -20%"],
		[&"hero_irelia", &"i2_rallycd", 3, "Divine Shield cooldown -35%"],
		[&"hero_irelia", &"ir_regen", 1, "Regeneration heals 1.5x as much"],
		[&"hero_irelia", &"ir_regen", 2, "Regeneration heals 2x as much"],
		[&"hero_vlad", &"vl_lust", 2, "Bloodlust kicks in 10% HP sooner (base: below 30%)"],
		[&"hero_river", &"r2_triple", 1, "Sniper shots also hit 2 enemies near the target"],
		[&"monster_grount", &"g1_stun", 1, "Ram Dash stuns for 0.5 s"],
		[&"monster_grount", &"g3_pull", 1, "Ground Slam pulls enemies within 200 px to the impact"],
		[&"monster_grount", &"g4_titan", 1, "Stage 3: +50% size, +500 HP, +20 range"],
		[&"monster_base", &"mt2_evo", 3, "-15% stage XP requirements"],
	]
	for c: Array in cases:
		var n := MetaSkillManager.get_tree_def(c[0]).find_node(c[1])
		assert_eq(n.effect_text(int(c[2])), String(c[3]), "%s rank %d" % [c[1], c[2]])


# ------------------------------------------------- renames and retargets

func test_every_roster_ability_has_a_real_name_description_and_translation() -> void:
	var de := load("res://Assets/Locale/strings.de.translation") as Translation
	assert_true(de != null, "the German translation is imported")
	for d in GameManager.ROSTER.all():
		for a in d.abilities():
			assert_false(a.ability_name in ["", "Unnamed Ability", "TED ULt"], "%s: '%s'" % [d.character_id(), a.ability_name])
			assert_true(a.description.length() > 10, "%s/%s has a description" % [d.character_id(), a.ability_name])
			if de != null:
				assert_false(String(de.get_message(a.ability_name)).is_empty(), "%s has a German name" % a.ability_name)
	var ted_ult := (GameManager.ROSTER.find(&"ted").ability_slots()[3])
	assert_eq(ted_ult.ability_name, "Trap Cage")
	var irelia_basic := (GameManager.ROSTER.find(&"irelia").ability_slots()[1])
	assert_eq(irelia_basic.ability_name, "Shield Bash")


## The four v1 nodes that never applied reach their ability now: on each hero's
## own copies, shown in the F3 overlay's ability lines.
func test_retargeted_nodes_change_the_cooldowns() -> void:
	if not require_isolated():
		return
	PersistedData.set_unlocked_skills(MetaSkillManager.hero_tree_id(&"ted"), ["t2_trapcd", "t3_trapdur"])
	PersistedData.set_unlocked_skills(MetaSkillManager.hero_tree_id(&"irelia"), ["i2_rallycd", "i3_dashcd"])
	var ted := await spawn_frozen(TED, Vector2.ZERO)
	var irelia := await spawn_frozen(IRELIA, Vector2(3000, 0))
	var cage: AbilityBase = (ted.get_node("AbilitySystem") as AbilitySystem).ultimate_ability
	var shared_cage := load("res://Scenes/NPCs/Hero/Heros/Support/Ted/Abilities/Ult/ted_ultimate.tres") as AbilityBase
	assert_near(cage.cooldown, shared_cage.cooldown * 0.80, 0.0001, "Fast Traps: Trap Cage cooldown -20%")
	assert_near(cage.duration, shared_cage.duration * 1.50, 0.0001, "Sturdy Cage: +50% on the ability")
	assert_near(shared_cage.cooldown, 5.0, 0.0001, "the shared resource is untouched")
	var irelia_abilities := irelia.get_node("AbilitySystem") as AbilitySystem
	var shield: AbilityBase = irelia_abilities.active_ability
	var taunt: AbilityBase = irelia_abilities.ultimate_ability
	assert_eq(shield.ability_name, "Divine Shield")
	assert_near(shield.cooldown, 13.0 * 0.80, 0.0001, "Shield Cadence: Divine Shield cooldown -20%")
	assert_eq(taunt.ability_name, "Monster Taunt")
	assert_near(taunt.cooldown, 15.0 * 0.70, 0.0001, "Relentless: Monster Taunt cooldown -30%")
	# The F3 overlay lists the followed hero's ability copies with their modifiers.
	var overlay := DebugOverlay.new()
	add_child(overlay)
	await wait_frames(1)
	overlay._update_hud_label(ted, null, null)
	var text: String = overlay._hud_label.text
	assert_true(text.contains("Trap Cage  cd 4.00 s  tree cooldown x0.80, duration x1.50"), text)
	overlay._update_hud_label(irelia, null, null)
	text = overlay._hud_label.text
	assert_true(text.contains("Divine Shield  cd 10.40 s  tree cooldown x0.80"), text)
	assert_true(text.contains("Monster Taunt  cd 10.50 s  tree cooldown x0.70"), text)
	overlay.queue_free()
	ted.queue_free()
	irelia.queue_free()


func _buy(tree: StringName, ids: Array[StringName]) -> void:
	for id in ids:
		assert_true(MetaSkillManager.rank_up(tree, id), "buy %s/%s" % [tree, id])
