class_name MetaSkillTree
extends Resource

## MetaSkillTree — a named collection of MetaSkillNodes that belong
## together (e.g. all the "Hero Base" upgrades). The tree's id is also
## the key used in PersistedData (`get_skill_ranks(tree_id)`).
##
## Layout: nodes sit in tiers (rows, 1..4) and branches (columns, `branches`
## names them). When a tier opens is the tree's gate_kind; MetaSkillManager
## applies it to buying rank 1 only, so owned nodes are never revoked.

## How a tier opens (tier 1 is always open):
##   TIER_BELOW: one node of the tier below is owned (the pre-rank trees).
##   LEVEL:      the owner character's permanent level >= tier_gates[tier - 1]
##               (character trees: [1, 3, 5, 8]).
##   POINTS:     ranks owned in this tree >= tier_gates[tier - 1]
##               (side-wide base trees: [0, 4, 10, 18]).
enum GateKind { TIER_BELOW, LEVEL, POINTS }

@export var id: StringName = &""
@export var display_name: String = "Tree"
@export var description: String = ""
@export var nodes: Array[MetaSkillNode] = []

@export_group("Layout")
## Branch names by column (MetaSkillNode.branch): offense, defense, utility.
## Empty = unnamed columns.
@export var branches: PackedStringArray = PackedStringArray()

@export_group("Tier gates")
@export var gate_kind: GateKind = GateKind.TIER_BELOW
## Per tier (index tier - 1): the level (LEVEL) or the ranks owned in this tree
## (POINTS) that open it. A tier past the end uses the last entry; empty = every
## tier open. Unused by TIER_BELOW.
@export var tier_gates: Array[int] = []
## The roster character (hero_id / monster_id) whose permanent level the LEVEL
## gate reads; &"" for a side-wide base tree.
@export var owner_id: StringName = &""

@export_group("AI")
## The ranks an AI-controlled side buys, in order: each entry is one more rank
## of that node id, capstones last (the Opponent Threat build takes a prefix).
@export var ai_build_order: Array[StringName] = []


func find_node(node_id: StringName) -> MetaSkillNode:
	for n in nodes:
		if n.id == node_id:
			return n
	return null


func nodes_in_tier(tier: int) -> Array[MetaSkillNode]:
	var out: Array[MetaSkillNode] = []
	for n in nodes:
		if n.tier == tier:
			out.append(n)
	return out


func max_tier() -> int:
	var t: int = 0
	for n in nodes:
		if n.tier > t:
			t = n.tier
	return t


## The gate value of `tier` (LEVEL / POINTS); 0 = open.
func gate_for_tier(tier: int) -> int:
	if tier <= 1 or tier_gates.is_empty():
		return 0
	return tier_gates[mini(tier, tier_gates.size()) - 1]


## The capstone nodes in branch order (then tree order within a branch).
func capstones() -> Array[MetaSkillNode]:
	var out: Array[MetaSkillNode] = []
	for n in nodes:
		if n.capstone:
			out.append(n)
	out.sort_custom(func(a: MetaSkillNode, b: MetaSkillNode) -> bool:
		return a.branch < b.branch or (a.branch == b.branch and nodes.find(a) < nodes.find(b)))
	return out
