class_name UxTreeModel
extends RefCounted

## One skill tree as the menus show it, and the only thing SkillTreeView and the
## character detail's bottom sheet read: columns (branches), rows (tiers) and
## nodes with ranks, prices and prerequisites, plus each node's state and why
## it cannot be bought. Adapters fill it from the game's data; the view never
## talks to MetaSkillManager.
##
## A snapshot: rebuild it after MetaSkillManager.skills_changed or
## PersistedData.currency_changed (MenuRoot does, through CharacterDetail).
##
## from_meta_skills() maps today's trees (one rank per node, no named branches
## or prerequisites; a tier opens once a node of the tier below is owned) and
## takes the gates from MetaSkillManager.node_state, so the screen and the shop
## never disagree. The ranked trees add their own adapter that fills the same
## fields (branch names, several ranks, requires, capstones).

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
	## The tree's final reward: a square frame instead of the round ring.
	var capstone: bool = false
	## Ranks owned.
	var rank: int = 0
	## Price of each rank (rank 1 first): its size is the node's max rank.
	var rank_costs: Array[int] = []
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
## The currency every price is in, and the player's amount of it when built.
var currency: StringName = PersistedData.GOLD
var wallet: int = 0
## One entry per column; a name draws a branch plaque, "" draws none.
var branches: PackedStringArray = PackedStringArray()
## Rows, 1..tiers.
var tiers: int = 0
## Per tier (index tier - 1): open for buying, the gate chip's text and the
## reason a node of a closed tier cannot be bought.
var tier_open: Array[bool] = []
var tier_gate_text: PackedStringArray = PackedStringArray()
var tier_block_reason: PackedStringArray = PackedStringArray()
var nodes: Array[TreeNodeData] = []

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


func state_of(n: TreeNodeData) -> NodeState:
	if n.rank >= n.max_rank():
		return NodeState.MAXED
	if n.rank > 0:
		return NodeState.OWNED
	if not tier_unlocked(n.tier) or not _requirement_met(n):
		return NodeState.LOCKED
	return NodeState.AVAILABLE


## Why the next rank of `n` cannot be bought, ignoring the price; "" when only
## the price can stop it.
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


## Live adapter over today's MetaSkillManager trees: one rank per node, column
## = the node's index inside its tier (no named branches), a lone node in the
## top tier of a multi-tier tree is the capstone. Tier gates and ownership come
## from MetaSkillManager.node_state; prices from the nodes; the wallet from
## PersistedData. `ability_icons` (ability_name -> icon) is the fallback icon
## of ability nodes. Null when the tree does not exist.
static func from_meta_skills(p_tree_id: StringName, ability_icons: Dictionary = {}) -> UxTreeModel:
	var t: MetaSkillTree = MetaSkillManager.get_tree_def(p_tree_id)
	if t == null:
		return null
	var m := UxTreeModel.new()
	m.tree_id = p_tree_id
	m.title = t.display_name
	m.description = t.description
	m.tiers = t.max_tier()
	var cols := 1
	for tier in range(1, m.tiers + 1):
		var row := t.nodes_in_tier(tier)
		cols = maxi(cols, row.size())
		var open := false
		for raw in row:
			if MetaSkillManager.node_state(p_tree_id, raw.id) != MetaSkillManager.NodeState.TIER_GATED:
				open = true
		m.tier_open.append(open)
		m.tier_gate_text.append(TranslationServer.translate("Tier %d") % tier)
		m.tier_block_reason.append(TranslationServer.translate("Learn a Tier %d skill first") % (tier - 1))
	for i in cols:
		m.branches.append("")
	for raw in t.nodes:
		var row := t.nodes_in_tier(raw.tier)
		var n := TreeNodeData.new()
		n.id = raw.id
		n.name = raw.display_name
		n.tier = raw.tier
		n.branch = row.find(raw)
		n.capstone = m.tiers > 1 and raw.tier == m.tiers and row.size() == 1
		n.rank = 1 if MetaSkillManager.is_unlocked(p_tree_id, raw.id) else 0
		n.rank_costs.assign([raw.cost])
		n.rank_texts = PackedStringArray([raw.description])
		n.icon = raw.icon if raw.icon != null else icon_for(raw.stat_name, raw.ability_name, ability_icons)
		m.currency = raw.currency
		m.add_node(n)
	m.wallet = PersistedData.get_currency(m.currency)
	return m
