extends TestCase

## UxTreeModel, the one thing the skill-tree view and the detail sheet read:
## node states (LOCKED, AVAILABLE, OWNED, MAXED), the block reasons (closed
## tier, missing prerequisite, maxed), prices against the wallet, the rank
## totals, the suggested node and capstone equipping, on a hand-built ranked
## tree; and the live adapter from_ranked_manager over MetaSkillManager's
## ranked trees (branches, tiers and their gates, ranks with prices, values and
## effect texts, prerequisites, capstones and the equipped one, icons,
## currency; hidden nodes only as slots), which must agree with
## MetaSkillManager.node_state, card_progress and equipped_capstone on every
## node of every tree, on a fresh save and on a seeded one. Tests that write
## the save run only in the isolated test user dir.

func before_each() -> void:
	if is_isolated():
		PersistedData.wipe_progress(false)


func after_each() -> void:
	if is_isolated():
		PersistedData.wipe_progress(false)


func _node(id: StringName, tier: int, costs: Array[int], rank: int = 0, requires: Array[StringName] = []) -> UxTreeModel.TreeNodeData:
	var n := UxTreeModel.TreeNodeData.new()
	n.id = id
	n.name = String(id).capitalize()
	n.tier = tier
	n.rank = rank
	n.rank_costs = costs
	for i in costs.size():
		n.rank_texts.append("+%d%% %s" % [5 * (i + 1), n.name])
		n.rank_values.append(1.0 + 0.05 * (i + 1))
	n.requires = requires
	return n


## Three tiers (the third closed), two named branches, a wallet of 150:
##   maxed: tier 1, rank 3/3     owned: tier 1, rank 1/2 (next 200)
##   open: tier 1, 0/1 (100)     needs_open: tier 2, requires open
##   either: tier 2, requires owned or open     gated: tier 3
func _ranked() -> UxTreeModel:
	var m := UxTreeModel.new()
	m.tree_id = &"test_tree"
	m.branches = PackedStringArray(["Bulwark", "Vanguard"])
	m.tiers = 3
	m.tier_open.assign([true, true, false])
	m.gate_kind = MetaSkillTree.GateKind.LEVEL
	m.tier_gates.assign([1, 3, 5])
	m.tier_block_reason = PackedStringArray(["", "Needs Lv 3", "Needs Lv 5"])
	m.wallet = 150
	m.add_node(_node(&"maxed", 1, [100, 200, 300], 3))
	m.add_node(_node(&"owned", 1, [100, 200], 1))
	m.add_node(_node(&"open", 1, [100]))
	m.add_node(_node(&"needs_open", 2, [100], 0, [&"open"]))
	m.add_node(_node(&"either", 2, [100], 0, [&"owned", &"open"]))
	m.add_node(_node(&"gated", 3, [100]))
	return m


func test_states_follow_ranks_tiers_and_prerequisites() -> void:
	var m := _ranked()
	var expected: Dictionary[StringName, UxTreeModel.NodeState] = {
		&"maxed": UxTreeModel.NodeState.MAXED, &"owned": UxTreeModel.NodeState.OWNED, &"open": UxTreeModel.NodeState.AVAILABLE,
		&"needs_open": UxTreeModel.NodeState.LOCKED, &"either": UxTreeModel.NodeState.AVAILABLE, &"gated": UxTreeModel.NodeState.LOCKED,
	}
	for id: StringName in expected:
		assert_eq(m.state_of(m.find(id)), expected[id], String(id))
	m.find(&"open").rank = 1
	assert_eq(m.state_of(m.find(&"needs_open")), UxTreeModel.NodeState.AVAILABLE, "its prerequisite is owned now")
	assert_eq(m.state_of(m.find(&"open")), UxTreeModel.NodeState.MAXED, "one rank of one")
	assert_true(m.find(&"nope") == null, "unknown ids are null")
	assert_eq(m.columns(), 2)
	assert_true(m.tier_unlocked(2) and not m.tier_unlocked(3) and not m.tier_unlocked(0) and not m.tier_unlocked(4))


func test_block_reasons() -> void:
	var m := _ranked()
	var expected: Dictionary[StringName, String] = {
		&"maxed": "Maxed", &"owned": "", &"open": "", &"needs_open": "Needs Open",
		&"either": "", &"gated": "Needs Lv 5",
	}
	for id: StringName in expected:
		assert_eq(m.block_reason(m.find(id)), expected[id], String(id))
	var both := _node(&"both", 2, [100], 0, [&"maxed_twin", &"open_twin"])
	m.add_node(_node(&"maxed_twin", 1, [100]))
	m.add_node(_node(&"open_twin", 1, [100]))
	m.add_node(both)
	assert_eq(m.block_reason(both), "Needs Maxed Twin or Open Twin", "any one of them opens it")
	var before := TranslationServer.get_locale()
	TranslationServer.set_locale("de")
	assert_eq(m.block_reason(m.find(&"maxed")), "Maximal", "reasons are translated")
	assert_eq(m.block_reason(both), "Benötigt Maxed Twin oder Open Twin")
	TranslationServer.set_locale(before)


func test_prices_against_the_wallet() -> void:
	var m := _ranked()
	assert_eq(m.find(&"maxed").next_cost(), 0, "nothing left to buy")
	assert_eq(m.find(&"owned").next_cost(), 200, "the next rank's price")
	assert_eq(m.find(&"open").next_cost(), 100)
	assert_false(m.affordable(m.find(&"owned")), "200 > 150")
	assert_true(m.can_buy(m.find(&"open")))
	assert_true(m.can_buy(m.find(&"either")))
	assert_false(m.can_buy(m.find(&"needs_open")), "locked, however cheap")
	assert_false(m.can_buy(m.find(&"maxed")))
	assert_eq(m.buyable_count(), 2)
	m.wallet = 99
	assert_eq(m.buyable_count(), 0)
	var owned := m.find(&"owned")
	assert_eq(owned.effect_at(1), "+5% Owned")
	assert_eq(owned.effect_at(2), "+10% Owned")
	assert_eq(owned.effect_at(3), "", "past the last rank")
	assert_eq(owned.max_rank(), 2)


func test_gutter_captions_and_rank_totals() -> void:
	var m := _ranked()
	assert_eq(m.gate_caption(), "Lv")
	assert_eq(str([m.gate_value(1), m.gate_value(2), m.gate_value(3)]), str([1, 3, 5]))
	m.gate_kind = MetaSkillTree.GateKind.POINTS
	assert_eq(m.gate_caption(), "pts")
	m.gate_kind = MetaSkillTree.GateKind.TIER_BELOW
	m.tier_gates.clear()
	assert_eq(m.gate_caption(), "Tier")
	assert_eq(m.gate_value(2), 2, "a tier without a gate number shows itself")
	# Owned 3 + 1; open: tiers 1-2 (3 + 2 + 1 + 1 + 1) and nothing owned in tier 3.
	assert_eq(m.ranks_owned(), 4)
	assert_eq(m.ranks_open(), 8)


func test_suggested_node_prefers_what_can_be_bought() -> void:
	var m := _ranked()
	assert_eq(m.suggested_node(), &"open", "the first node the wallet can buy (tier 1 before tier 2)")
	m.wallet = 0
	assert_eq(m.suggested_node(), &"owned", "nothing affordable: the first open node with a rank left")
	m.find(&"owned").rank = 2
	m.find(&"open").rank = 1
	assert_eq(m.suggested_node(), &"needs_open", "then tier 2")
	for n in m.nodes:
		n.rank = n.max_rank()
	assert_eq(m.suggested_node(), &"maxed", "everything maxed: the first node")
	assert_eq(UxTreeModel.new().suggested_node(), &"", "an empty tree selects nothing")


func test_capstone_equip() -> void:
	var m := _ranked()
	var cap_a := _node(&"cap_a", 3, [1500])
	cap_a.capstone = true
	var cap_b := _node(&"cap_b", 3, [1500])
	cap_b.capstone = true
	m.add_node(cap_a)
	m.add_node(cap_b)
	assert_false(m.can_equip(cap_a), "not owned yet")
	assert_false(m.is_equipped(cap_a))
	cap_a.rank = 1
	cap_b.rank = 1
	m.equipped = &"cap_a"
	assert_true(m.is_equipped(cap_a))
	assert_false(m.can_equip(cap_a), "already the active one")
	assert_true(m.can_equip(cap_b), "an owned capstone swaps in")
	assert_false(m.can_equip(m.find(&"maxed")), "only capstones equip")
	assert_false(m.is_equipped(m.find(&"maxed")))


func test_live_grount_tree() -> void:
	if not require_isolated():
		return
	var tree_id := MetaSkillManager.monster_tree_id(&"grount")
	var t: MetaSkillTree = MetaSkillManager.get_tree_def(tree_id)
	var m := UxTreeModel.from_ranked_manager(tree_id)
	assert_true(m != null)
	if m == null:
		return
	assert_eq(m.tree_id, tree_id)
	assert_eq(m.title, t.display_name)
	assert_true(m.monster, "the monsters' branch colours")
	assert_eq(m.nodes.size(), t.shown_nodes().size(), "every shown node")
	var hidden: Array[StringName] = []
	for n in m.hidden_nodes:
		hidden.append(n.id)
		assert_true(n.capstone and n.tier == 4, "%s: a tier-4 capstone slot" % n.id)
	for n in t.nodes:
		if n.hidden:
			assert_true(m.find(n.id) == null, "hidden %s is left out" % n.id)
			assert_true(hidden.has(n.id), "hidden %s keeps a slot" % n.id)
	assert_eq(hidden.size(), t.nodes.size() - t.shown_nodes().size())
	assert_eq(m.tiers, 4)
	assert_eq(m.columns(), 3)
	assert_eq(m.branches, PackedStringArray(["Horns", "Hide", "Charge"]), "the tree's branches")
	assert_eq(m.currency, PersistedData.LEAVES)
	assert_eq(m.wallet, 0)
	assert_eq(str(m.tier_open), str([true, false, false, false]), "a fresh save opens tier 1 only")
	assert_eq(m.gate_kind, MetaSkillTree.GateKind.LEVEL)
	assert_eq(m.gate_caption(), "Lv")
	assert_eq(str(m.tier_gates), str([1, 3, 5, 8]), "Grount's level gates")
	assert_eq(m.equipped, &"", "no capstone owned")
	var capstones: Array[StringName] = []
	for n in m.nodes:
		var raw := t.find_node(n.id)
		assert_eq(n.max_rank(), raw.max_rank, "%s: its ranks" % n.id)
		for r in range(1, raw.max_rank + 1):
			assert_eq(n.rank_costs[r - 1], raw.cost_of_rank(r), "%s: the shop's price of rank %d" % [n.id, r])
			assert_eq(n.rank_values[r - 1], raw.value_at_rank(r), "%s: the value of rank %d" % [n.id, r])
			assert_eq(n.effect_at(r), raw.effect_text(r))
		assert_false(n.effect_at(1).contains("{v}"), "%s: the value is filled in" % n.id)
		assert_true(n.icon != null, "%s has an icon" % n.id)
		assert_eq(n.branch, raw.branch, "%s: column = its branch" % n.id)
		assert_eq(n.capstone, raw.capstone)
		if n.capstone:
			capstones.append(n.id)
		if n.tier == 1:
			assert_eq(m.state_of(n), UxTreeModel.NodeState.AVAILABLE, "%s is open" % n.id)
			assert_eq(m.block_reason(n), "", "only the price stops it")
			assert_false(m.can_buy(n), "no Leaves yet")
		else:
			assert_eq(m.state_of(n), UxTreeModel.NodeState.LOCKED, "%s is gated" % n.id)
			assert_eq(m.block_reason(n), "Needs Lv %d" % t.gate_for_tier(n.tier))
	assert_eq(str(capstones), str([&"g4_rampage", &"g4_titan", &"g4_stampede"]), "one capstone per branch, all shown since 6.6")
	assert_eq(m.find(&"g2_hp").requires, [&"g1_hide"] as Array[StringName], "Thick Hide opens Scar Tissue")
	assert_eq(m.find(&"g4_titan").requires, [&"g3_slam", &"g3_pull", &"g2_hp"] as Array[StringName])
	assert_eq(m.find(&"g1_dmg").effect_at(2), "+14% damage")
	assert_eq(m.find(&"g1_dmg").icon.resource_path, "res://Assets/UI/Icons/Stats/stat_damage.svg")
	assert_eq(m.find(&"g2_cleavecd").icon.resource_path, "res://Assets/UI/Icons/Stats/stat_cooldown.svg",
			"an ability node shows what it changes")
	assert_true(UxTreeModel.from_ranked_manager(&"no_such_tree") == null)


## The base trees open tiers by ranks owned: the closed tier says how many
## more to buy, and opens once they are bought.
func test_points_gates_on_the_hero_base_tree() -> void:
	if not require_isolated():
		return
	var tree_id := MetaSkillManager.TREE_HERO_BASE
	var m := UxTreeModel.from_ranked_manager(tree_id)
	assert_false(m.monster)
	assert_eq(m.gate_kind, MetaSkillTree.GateKind.POINTS)
	assert_eq(m.gate_caption(), "pts")
	assert_eq(str(m.tier_gates), str([0, 4, 10, 18]))
	assert_eq(m.currency, PersistedData.GOLD)
	assert_eq(m.block_reason(m.find(&"t2_dmg")), "Spend 4 more points", "a fresh save owns no rank")
	PersistedData.set_skill_rank(tree_id, &"t1_dmg", 3)
	m = UxTreeModel.from_ranked_manager(tree_id)
	assert_eq(m.block_reason(m.find(&"t2_dmg")), "Spend 1 more point")
	assert_eq(m.block_reason(m.find(&"t3_atkspd")), "Spend 7 more points")
	PersistedData.set_skill_rank(tree_id, &"t1_hp", 1)
	m = UxTreeModel.from_ranked_manager(tree_id)
	assert_true(m.tier_unlocked(2), "4 ranks open tier 2")
	assert_eq(m.block_reason(m.find(&"t2_dmg")), "", "its parent is owned")
	assert_eq(m.block_reason(m.find(&"t2_atkspd")), "Needs Light Step", "Quick Strike needs Light Step")
	var before := TranslationServer.get_locale()
	TranslationServer.set_locale("de")
	m = UxTreeModel.from_ranked_manager(tree_id)
	assert_eq(m.block_reason(m.find(&"t3_atkspd")), "Noch 6 Punkte ausgeben", "translated")
	assert_eq(m.gate_caption(), "Pkt.")
	TranslationServer.set_locale(before)


## Irelia's three capstones: buying the first equips it, the screen follows
## MetaSkillManager's choice, and a swap shows on the next model.
func test_live_capstones_follow_the_equipped_one() -> void:
	if not require_isolated():
		return
	var tree_id := MetaSkillManager.hero_tree_id(&"irelia")
	PersistedData.add_hero_xp(&"irelia", 4000)
	PersistedData.set_skill_rank(tree_id, &"i1_hp", 1)
	PersistedData.set_skill_rank(tree_id, &"i2_hp", 1)
	PersistedData.set_skill_rank(tree_id, &"i3_hp", 1)
	PersistedData.set_skill_rank(tree_id, &"ir_regen", 1)
	PersistedData.set_skill_rank(tree_id, &"i2_rallycd", 1)
	PersistedData.set_skill_rank(tree_id, &"ir_aegis", 1)
	PersistedData.add_currency(PersistedData.STEEL, 3000)
	var m := UxTreeModel.from_ranked_manager(tree_id)
	var capstones: Array[StringName] = []
	for n in m.nodes:
		if n.capstone:
			capstones.append(n.id)
	assert_eq(capstones.size(), 3, "one per branch")
	assert_true(m.can_buy(m.find(&"ir_laststand")) and m.can_buy(m.find(&"ir_guardian")), "Lv 8 with their parents owned")
	assert_true(MetaSkillManager.rank_up(tree_id, &"ir_guardian"))
	assert_true(MetaSkillManager.rank_up(tree_id, &"ir_laststand"))
	m = UxTreeModel.from_ranked_manager(tree_id)
	assert_eq(m.equipped, &"ir_guardian", "the first one bought is equipped")
	assert_true(m.is_equipped(m.find(&"ir_guardian")))
	assert_true(m.can_equip(m.find(&"ir_laststand")))
	assert_false(m.can_equip(m.find(&"ir_banner")), "not owned")
	assert_eq(m.state_of(m.find(&"ir_laststand")), UxTreeModel.NodeState.MAXED)
	assert_eq(m.block_reason(m.find(&"ir_laststand")), "Maxed")
	assert_true(MetaSkillManager.equip_capstone(tree_id, &"ir_laststand"))
	m = UxTreeModel.from_ranked_manager(tree_id)
	assert_eq(m.equipped, &"ir_laststand", "a swap shows")
	assert_true(m.can_equip(m.find(&"ir_guardian")))


func test_icon_fallbacks() -> void:
	var tex := PlaceholderTexture2D.new()
	assert_eq(UxTreeModel.icon_for("max_health", "Ram Dash", {"Ram Dash": tex}).resource_path,
			"res://Assets/UI/Icons/Stats/stat_hp.svg", "a known stat wins")
	assert_eq(UxTreeModel.icon_for("whirl", "Ram Dash", {"Ram Dash": tex}), tex, "then the ability's icon")
	assert_eq(UxTreeModel.icon_for("whirl", "", {}).resource_path, "res://Assets/UI/Icons/Stats/stat_level.svg")
	for key: String in UxTreeModel.STAT_ICONS:
		assert_true(ResourceLoader.exists(UxTreeModel.STAT_ICON_PATH % UxTreeModel.STAT_ICONS[key]), key)
	# Every node of the nine trees, hidden ones included.
	for file in DirAccess.get_files_at("res://Data/SkillTrees"):
		var t := load("res://Data/SkillTrees/" + file.trim_suffix(".remap")) as MetaSkillTree
		for n in t.nodes:
			assert_true(UxTreeModel.STAT_ICONS.has(n.stat_name), "%s/%s (%s) has a stat icon" % [t.id, n.id, n.stat_name])


## The model and the shop read one rule set: the live states must match
## node_state for every node of every tree, fresh and with progress.
func test_live_states_agree_with_the_shop() -> void:
	if not require_isolated():
		return
	_assert_agree("fresh save")
	PersistedData.set_unlocked_skills(MetaSkillManager.monster_tree_id(&"grount"), ["g1_dmg", "g1_speed", "g2_hp", "g3_enrage"])
	PersistedData.set_unlocked_skills(MetaSkillManager.hero_tree_id(&"irelia"), ["i1_hp"])
	PersistedData.set_unlocked_skills(MetaSkillManager.TREE_HERO_BASE, ["t1_hp", "t2_dmg"])
	PersistedData.set_skill_rank(MetaSkillManager.TREE_HERO_BASE, &"t1_dmg", 3)
	PersistedData.set_skill_rank(MetaSkillManager.TREE_HERO_BASE, &"t1_speed", 3)
	PersistedData.add_hero_xp(&"irelia", 300)
	PersistedData.add_monster_xp(&"grount", 1000)
	PersistedData.add_currency(PersistedData.LEAVES, 1000)
	PersistedData.add_currency(PersistedData.STEEL, 300)
	PersistedData.add_currency(PersistedData.GOLD, 100)
	_assert_agree("seeded save")
	# A bought monster's card counts its buyable ranks like any owned one;
	# Gorrak, still locked, keeps 0.
	PersistedData.add_owned_monster(&"nyxa")
	assert_true(CharacterProgress.is_unlocked(GameManager.ROSTER.find(&"nyxa")), "Nyxa is bought")
	assert_true(CharacterProgress.upgrades_ready(GameManager.ROSTER.find(&"nyxa")) > 0, "1,000 Leaves buy her tier-1 ranks")
	assert_eq(CharacterProgress.upgrades_ready(GameManager.ROSTER.find(&"gorrak")), 0, "Gorrak is still locked")
	_assert_agree("bought Nyxa")


func _assert_agree(label: String) -> void:
	for tree_id: StringName in MetaSkillManager.trees:
		var m := UxTreeModel.from_ranked_manager(tree_id)
		var progress := MetaSkillManager.card_progress(tree_id)
		assert_eq(m.ranks_owned(), progress["owned_ranks"], "%s %s: ranks owned = the card's" % [label, tree_id])
		assert_eq(m.ranks_open(), progress["open_ranks"], "%s %s: ranks open = the card's" % [label, tree_id])
		assert_eq(m.equipped, MetaSkillManager.equipped_capstone(tree_id), "%s %s: equipped capstone" % [label, tree_id])
		var available := 0
		for n in m.nodes:
			var expected: int = MetaSkillManager.node_state(tree_id, n.id)
			var state := m.state_of(n)
			var tag := "%s %s/%s" % [label, tree_id, n.id]
			assert_eq(n.rank, MetaSkillManager.get_rank(tree_id, n.id), tag)
			# An owned node below its max sells its next rank: OWNED on the screen.
			var open_state := UxTreeModel.NodeState.OWNED if n.rank > 0 else UxTreeModel.NodeState.AVAILABLE
			if expected == MetaSkillManager.NodeState.UNLOCKED:
				assert_eq(state, UxTreeModel.NodeState.MAXED, tag)
			elif expected in [MetaSkillManager.NodeState.TIER_GATED, MetaSkillManager.NodeState.LEVEL_GATED,
					MetaSkillManager.NodeState.REQUIRES_MISSING]:
				assert_eq(state, UxTreeModel.NodeState.LOCKED, tag)
				assert_false(m.block_reason(n).is_empty(), tag)
			elif expected == MetaSkillManager.NodeState.AVAILABLE:
				assert_eq(state, open_state, tag)
				assert_true(m.can_buy(n), tag)
				available += 1
			else:
				assert_eq(expected, MetaSkillManager.NodeState.UNAFFORDABLE, tag)
				assert_eq(state, open_state, tag)
				assert_false(m.can_buy(n), tag)
		assert_eq(m.buyable_count(), available, "%s %s: buyable count" % [label, tree_id])
	# A locked character (Nyxa or Gorrak until bought) shows no up-arrows: its
	# detail does not open.
	for def in GameManager.ROSTER.all():
		var m := UxTreeModel.from_ranked_manager(def.skill_tree_id())
		var expected: int = m.buyable_count() if CharacterProgress.is_unlocked(def) else 0
		assert_eq(CharacterProgress.upgrades_ready(def), expected, "%s %s: the card's up-arrow count" % [label, def.character_id()])
