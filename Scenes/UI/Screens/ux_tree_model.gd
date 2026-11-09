class_name UxTreeModel
extends RefCounted

## One skill tree as the menus show it, and the only thing SkillTreeView and the
## character detail's bottom sheet read: columns (branches), rows (tiers) and
## their gates, nodes with ranks, prices, effects and prerequisites, the
## equipped capstone, plus each node's state and why it cannot be bought.
## Adapters fill it from the game's data; the view never talks to
## MetaSkillManager.
##
## A snapshot: rebuild it after MetaSkillManager.skills_changed or
## PersistedData.currency_changed (MenuRoot does, through CharacterDetail).
##
## from_ranked_manager() maps MetaSkillManager's ranked trees (named branches,
## ranks with their prices and values, prerequisites, gates, capstones; hidden
## nodes only as "coming soon" slots) and takes the gates, ranks and the
## equipped capstone from MetaSkillManager, so the screen and the shop never
## disagree.

enum NodeState { LOCKED, AVAILABLE, OWNED, MAXED }

## Stat icons (Assets/UI/Icons/Stats/<file>.svg) by the node's stat or ability
## property. A node shows its own icon first, then this, then the icon of the
## ability it upgrades, then stat_level.
const STAT_ICON_PATH := "res://Assets/UI/Icons/Stats/%s.svg"
const STAT_ICONS: Dictionary[String, String] = {
	"max_health": "stat_hp", "monster_health_mult": "stat_hp", "monster_titan_form": "stat_hp",
	"attack_damage": "stat_damage", "monster_damage_mult": "stat_damage", "damage": "stat_damage",
	"extra_targets": "stat_damage",
	"move_speed": "stat_speed", "monster_speed_mult": "stat_speed",
	"attack_speed": "stat_attack_speed",
	"attack_range": "stat_range", "ability_range": "stat_range", "monster_range_mult": "stat_range",
	"dash_distance": "stat_range",
	"cooldown": "stat_cooldown",
	"damage_taken_mult": "stat_armor",
	"heal_amount": "stat_heal",
	"area_of_effect": "stat_aoe", "slam_radius": "stat_aoe", "pull_radius": "stat_aoe",
	"duration": "stat_duration", "stun_duration": "stat_duration",
	"monster_evo_threshold": "stat_xp", "monster_xp_mult": "stat_xp",
	"monster_enrage": "stat_threat",
	"unlock_stage": "stat_level",
	# Skill trees v2 (several still hidden until their code lands).
	"cooldown_mult": "stat_cooldown", "monster_cooldown_mult": "stat_cooldown", "respawn_time": "stat_cooldown",
	"start_level": "stat_level", "pet_count": "stat_level",
	"monster_start_xp": "stat_xp",
	"monster_damage_taken_mult": "stat_armor", "cleanse_stuns": "stat_armor", "monster_cc_immune": "stat_armor",
	"monster_regen_mult": "stat_regen", "monster_rebirth": "stat_regen",
	"monster_s3_damage_mult": "stat_damage", "execute_threshold": "stat_damage", "crit_every": "stat_damage",
	"pet_damage_mult": "stat_damage", "cage_dps": "stat_damage",
	"last_stand": "stat_hp", "pet_health_mult": "stat_hp",
	"health_threshold": "stat_threat", "monster_rampage": "stat_threat", "recruit_radius": "stat_threat",
	"lifesteal_pct": "stat_lifesteal",
	"extra_heal_targets": "stat_heal",
	"boost_duration": "stat_duration", "permanent_from_stage": "stat_duration",
	"team_speed_aura": "stat_speed",
	"rally_radius": "stat_attack_speed", "aura_radius": "stat_attack_speed",
	"mine_count": "stat_aoe", "trample": "stat_aoe", "cone_angle": "stat_aoe", "full_circle_from_stage": "stat_aoe",
	"double_pass": "stat_range",
}
const FALLBACK_ICON := "stat_level"


## One node of the tree.
class TreeNodeData:
	extends RefCounted

	var id: StringName = &""
	var name: String = ""
	var icon: Texture2D = null
	## Column (branch index) and row (1-based tier).
	var branch: int = 0
	var tier: int = 1
	## A branch's tier-4 reward: the 92 px tile in the stone arch. Several can
	## be owned, one is equipped (UxTreeModel.equipped).
	var capstone: bool = false
	## Ranks owned.
	var rank: int = 0
	## Price of each rank (rank 1 first): its size is the node's max rank.
	var rank_costs: Array[int] = []
	## The node's value when owning each rank (MetaSkillNode.value_at_rank),
	## rank 1 first; rank_texts says the same in words.
	var rank_values: Array[float] = []
	## What the node gives at each rank ("+5% Max HP"), rank 1 first.
	var rank_texts: PackedStringArray = PackedStringArray()
	## Owning any one of these opens the node (empty: no prerequisite).
	var requires: Array[StringName] = []

	func max_rank() -> int:
		return rank_costs.size()

	## Price of the next rank (0 when maxed).
	func next_cost() -> int:
		return rank_costs[rank] if rank < rank_costs.size() else 0

	## Effect at rank `r` (1-based), "" outside the node's ranks.
	func effect_at(r: int) -> String:
		return rank_texts[r - 1] if r >= 1 and r <= rank_texts.size() else ""


var tree_id: StringName = &""
## The tree's name and blurb (the Growth header).
var title: String = ""
var description: String = ""
## A monster-side tree (monster_<id>, monster_base): the monsters' branch
## colours.
var monster: bool = false
## The currency every price is in, and the player's amount of it when built.
var currency: StringName = PersistedData.GOLD
var wallet: int = 0
## One entry per column; a name draws a branch plaque, "" draws none.
var branches: PackedStringArray = PackedStringArray()
## Rows, 1..tiers.
var tiers: int = 0
## How a tier opens (the tier gutter): MetaSkillTree.GateKind, and per tier
## (index tier - 1) the gate's number: the owner's level (LEVEL, "Lv 5"), the
## ranks owned in the tree (POINTS, "pts 10") or the tier itself (TIER_BELOW).
var gate_kind: MetaSkillTree.GateKind = MetaSkillTree.GateKind.TIER_BELOW
var tier_gates: Array[int] = []
## Per tier (index tier - 1): open for buying, and the reason a node of a
## closed tier cannot be bought.
var tier_open: Array[bool] = []
var tier_block_reason: PackedStringArray = PackedStringArray()
## The capstone that applies (&"" while the tree owns none).
var equipped: StringName = &""
var nodes: Array[TreeNodeData] = []
## Nodes the data has but the game does not yet (MetaSkillNode.hidden): only
## their place (id, branch, tier, capstone) for the view's "coming soon" slots.
var hidden_nodes: Array[TreeNodeData] = []

var _by_id: Dictionary[StringName, TreeNodeData] = {}


## Adds a node (adapters, tests).
func add_node(n: TreeNodeData) -> void:
	nodes.append(n)
	_by_id[n.id] = n


func find(id: StringName) -> TreeNodeData:
	return _by_id.get(id, null)


func columns() -> int:
	return branches.size()


func tier_unlocked(tier: int) -> bool:
	return tier >= 1 and tier <= tier_open.size() and tier_open[tier - 1]


## The tier gutter's caption over the gate numbers: "Lv", "pts" or "Tier".
func gate_caption() -> String:
	match gate_kind:
		MetaSkillTree.GateKind.LEVEL:
			return TranslationServer.translate("Lv")
		MetaSkillTree.GateKind.POINTS:
			return TranslationServer.translate("pts")
	return TranslationServer.translate("Tier")


## The gate number of `tier` (the gutter): tier_gates, else the tier itself.
func gate_value(tier: int) -> int:
	return tier_gates[tier - 1] if tier >= 1 and tier <= tier_gates.size() else tier


func state_of(n: TreeNodeData) -> NodeState:
	if n.rank >= n.max_rank():
		return NodeState.MAXED
	if n.rank > 0:
		return NodeState.OWNED
	if not tier_unlocked(n.tier) or not _requirement_met(n):
		return NodeState.LOCKED
	return NodeState.AVAILABLE


## Why the next rank of `n` cannot be bought, ignoring the price; "" when only
## the price can stop it. The gates guard rank 1 only.
func block_reason(n: TreeNodeData) -> String:
	if n.rank >= n.max_rank():
		return TranslationServer.translate("Maxed")
	if n.rank > 0:
		return ""
	if not tier_unlocked(n.tier):
		return tier_block_reason[n.tier - 1] if n.tier >= 1 and n.tier <= tier_block_reason.size() else ""
	if not _requirement_met(n):
		var names := PackedStringArray()
		for r in n.requires:
			var p := find(r)
			if p != null:
				names.append(p.name)
		var joiner := " %s " % TranslationServer.translate("or")
		return TranslationServer.translate("Needs %s") % joiner.join(names)
	return ""


func affordable(n: TreeNodeData) -> bool:
	return n.rank < n.max_rank() and n.next_cost() <= wallet


## The next rank can be bought right now (open and affordable).
func can_buy(n: TreeNodeData) -> bool:
	return block_reason(n).is_empty() and affordable(n)


## Nodes whose next rank can be bought right now.
func buyable_count() -> int:
	var count := 0
	for n in nodes:
		if can_buy(n):
			count += 1
	return count


## The capstone that applies (the tree has one at a time).
func is_equipped(n: TreeNodeData) -> bool:
	return n.capstone and n.id == equipped


## An owned capstone that is not the equipped one: EQUIP swaps to it.
func can_equip(n: TreeNodeData) -> bool:
	return n.capstone and n.rank >= 1 and not is_equipped(n)


## Ranks owned in the tree (the header's left number).
func ranks_owned() -> int:
	var total := 0
	for n in nodes:
		total += n.rank
	return total


## Ranks the player can hold today: every rank of a node in an open tier, plus
## what is owned in a closed one (MetaSkillManager.card_progress's open_ranks).
func ranks_open() -> int:
	var total := 0
	for n in nodes:
		total += n.max_rank() if tier_unlocked(n.tier) else n.rank
	return total


## The nodes top to bottom, left to right: by tier, then branch, then the
## tree's order.
func display_order() -> Array[TreeNodeData]:
	var out: Array[TreeNodeData] = nodes.duplicate()
	out.sort_custom(func(a: TreeNodeData, b: TreeNodeData) -> bool:
		if a.tier != b.tier:
			return a.tier < b.tier
		if a.branch != b.branch:
			return a.branch < b.branch
		return nodes.find(a) < nodes.find(b))
	return out


## The node the sheet opens on: the first one that can be bought now, else
## the first open one with a rank left, else the first node; &"" for an empty
## tree.
func suggested_node() -> StringName:
	var order := display_order()
	for n in order:
		if can_buy(n):
			return n.id
	for n in order:
		var state := state_of(n)
		if state == NodeState.AVAILABLE or state == NodeState.OWNED:
			return n.id
	return order[0].id if not order.is_empty() else &""


func _requirement_met(n: TreeNodeData) -> bool:
	if n.requires.is_empty():
		return true
	for r in n.requires:
		var p := find(r)
		if p != null and p.rank > 0:
			return true
	return false


## Icon of a node that has none of its own: the stat icon of `stat_key`, else
## the icon of the ability it upgrades (`ability_icons`: ability_name -> icon),
## else stat_level.
static func icon_for(stat_key: String, ability_name: String, ability_icons: Dictionary) -> Texture2D:
	if STAT_ICONS.has(stat_key):
		return load(STAT_ICON_PATH % STAT_ICONS[stat_key]) as Texture2D
	var ability_icon := ability_icons.get(ability_name, null) as Texture2D
	if ability_icon != null:
		return ability_icon
	return load(STAT_ICON_PATH % FALLBACK_ICON) as Texture2D


## Live adapter over MetaSkillManager's ranked trees. Columns are the tree's
## branches (a node without one takes its index inside its tier); every shown
## node with its owned rank, the price, value and effect text of each rank
## (cost_of_rank, value_at_rank, effect_text), its capstone flag and its
## prerequisites (hidden parents dropped: MetaSkillManager ignores them too).
## Hidden nodes go to hidden_nodes. The gates: gate_kind and tier_gates from
## the tree, which tiers are open from MetaSkillManager.is_tier_open, and the
## block reason of a closed tier by gate kind ("Needs Lv 5", "Spend 3 more
## points", "Learn a Tier 1 skill first"). The equipped capstone from
## MetaSkillManager.equipped_capstone, the wallet from PersistedData.
## `ability_icons` (ability_name -> icon) is the fallback icon of ability
## nodes. Null when the tree does not exist.
static func from_ranked_manager(p_tree_id: StringName, ability_icons: Dictionary = {}) -> UxTreeModel:
	var t: MetaSkillTree = MetaSkillManager.get_tree_def(p_tree_id)
	if t == null:
		return null
	var m := UxTreeModel.new()
	m.tree_id = p_tree_id
	m.title = t.display_name
	m.description = t.description
	m.monster = String(p_tree_id).begins_with(MetaSkillManager.TREE_MONSTER_PREFIX)
	m.tiers = t.max_tier()
	m.gate_kind = t.gate_kind
	m.equipped = MetaSkillManager.equipped_capstone(p_tree_id)
	var spent := MetaSkillManager.points_spent(p_tree_id)
	for tier in range(1, m.tiers + 1):
		# gate_for_tier says 0 (open) for tier 1; the gutter shows the data's value.
		var gate := t.gate_for_tier(tier) if tier > 1 or t.tier_gates.is_empty() else t.tier_gates[0]
		m.tier_open.append(MetaSkillManager.is_tier_open(p_tree_id, tier))
		match t.gate_kind:
			MetaSkillTree.GateKind.LEVEL:
				m.tier_gates.append(gate)
				m.tier_block_reason.append(TranslationServer.translate("Needs Lv %d") % gate)
			MetaSkillTree.GateKind.POINTS:
				m.tier_gates.append(gate)
				m.tier_block_reason.append(_points_reason(gate - spent))
			_:
				m.tier_gates.append(tier)
				m.tier_block_reason.append(TranslationServer.translate("Learn a Tier %d skill first") % (tier - 1))
	var cols := t.branches.size()
	for raw in t.nodes:
		var n := TreeNodeData.new()
		n.id = raw.id
		n.tier = raw.tier
		n.branch = raw.branch if raw.branch >= 0 else t.nodes_in_tier(raw.tier).find(raw)
		n.capstone = raw.capstone
		if raw.hidden:
			n.branch = maxi(raw.branch, 0)
			m.hidden_nodes.append(n)
			continue
		cols = maxi(cols, n.branch + 1)
		n.name = raw.display_name
		n.rank = mini(MetaSkillManager.get_rank(p_tree_id, raw.id), raw.max_rank)
		for r in range(1, raw.max_rank + 1):
			n.rank_costs.append(raw.cost_of_rank(r))
			n.rank_values.append(raw.value_at_rank(r))
			n.rank_texts.append(raw.effect_text(r))
		for req in raw.requires:
			var parent := t.find_node(req)
			if parent != null and not parent.hidden:
				n.requires.append(req)
		n.icon = raw.icon if raw.icon != null else icon_for(raw.stat_name, raw.ability_name, ability_icons)
		m.currency = raw.currency
		m.add_node(n)
	m.branches = t.branches.duplicate()
	while m.branches.size() < cols:
		m.branches.append("")
	m.wallet = PersistedData.get_currency(m.currency)
	return m


## A closed POINTS tier: "Spend 3 more points" (the ranks still to buy).
static func _points_reason(missing: int) -> String:
	if missing == 1:
		return TranslationServer.translate("Spend 1 more point")
	return TranslationServer.translate("Spend %d more points") % maxi(missing, 0)
