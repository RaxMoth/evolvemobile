class_name MetaSkillNode
extends Resource

## MetaSkillNode — one permanent upgrade with one or more ranks.
##
## "Meta" distinguishes from the in-round SkillNode in /Scripts/Skilltree/
## (which uses per-match leveling). This one is persistent across all
## matches: bought with Steel / Leaves / Gold, applied to every hero or
## monster spawn from now on.
##
## Each node has a SINGLE effect (a character stat, one ability property or a
## behaviour key). Ranks deepen that one effect: owning rank r applies
## value_at_rank(r) once, so every consumer makes one apply call per node.
## max_rank 1 is the classic one-time unlock; an old save that owned a node
## owns its rank 1, whose value is exactly stat_value.

@export var id: StringName = &""
@export var display_name: String = "Unnamed"
## What the node gives; "{v}" stands for the value of the rank shown
## (effect_text): "+{v}% max HP" reads "+8% max HP" at rank 1.
@export var description: String = ""
@export var tier: int = 1               ## 1-4 per README. The tree's gate_kind decides when a tier opens.
@export var cost: int = 100             ## Currency cost of rank 1.
@export var currency: StringName = &"gold"  ## Matches PersistedData.STEEL / LEAVES / GOLD.
@export var icon: Texture2D = null

@export_group("Ranks")
## 1 = the classic one-time unlock. Above 1 the node can be bought again, up to
## this many times; owning rank r applies value_at_rank(r).
@export_range(1, 10) var max_rank: int = 1
## Explicit price per rank (index 0 = rank 1). Empty = cost x cost_growth^(r-1),
## rounded to 5 (cost_of_rank).
@export var rank_costs: Array[int] = []
@export var cost_growth: float = 1.5
## Explicit CUMULATIVE effect when owning rank r (index 0 = rank 1), in
## stat_value's form: the full multiplier for a multiplicative node (1.14 =
## +14 %, 0.8 = -20 %), the total delta for an additive one. Wins over the
## linear rule of value_at_rank, so a design can give diminishing ranks
## ([1.05, 1.08, 1.11, ...]). rank_values[0] must equal stat_value.
@export var rank_values: Array[float] = []
## Tier-4 reward of a branch (character trees only): several can be owned, but
## only the tree's equipped capstone applies (MetaSkillManager.equipped_capstone).
@export var capstone: bool = false

@export_group("Layout")
## Ids of nodes in the same tree that open this one (rank >= 1 owned). Empty =
## only the tier gate applies. The tree view draws them as edges.
@export var requires: Array[StringName] = []
## false: owning any one of `requires` is enough (the design rule); true: all.
@export var requires_all: bool = false
## Branch (column group) in the tree view: 0 = offense, 1 = defense, 2 = utility
## (MetaSkillTree.branches names them); -1 = none.
@export var branch: int = -1
## Column inside the tree view (0-based); -1 = auto (order within the tier).
@export var column: int = -1
## Not part of the game yet: its effect has no code. A hidden node is not shown,
## cannot be bought and never applies (MetaSkillManager treats it like an id
## the tree does not have); the batch that writes its code clears the flag.
@export var hidden: bool = false

@export_group("Ability Effect")
## When set, this node modifies ONE ability (matched by AbilityBase.ability_name)
## instead of a character stat: `stat_name` is then the ability property
## (cooldown, damage, ability_range, area_of_effect, duration, heal_amount or a
## subclass export such as dash_distance) and stat_value / stat_multiplicative
## apply to it. Applied on spawn to the entity's own ability copies.
@export var ability_name: String = ""

@export_group("Stat Effect")
## Stat name as understood by HeroStatsComponent (e.g. "max_health",
## "move_speed", "attack_damage"). Empty string = no stat effect (the node
## is a placeholder / unlock-flag-only node — handled by special logic).
@export var stat_name: String = ""
## For multiplicative: pass the full multiplier (1.05 = +5%). For additive:
## pass the absolute delta (10 = +10).
@export var stat_value: float = 1.0
@export var stat_multiplicative: bool = true


static func make(
	p_id: StringName,
	p_name: String,
	p_desc: String,
	p_tier: int,
	p_cost: int,
	p_currency: StringName,
	p_stat: String,
	p_value: float,
	p_mult: bool = true
) -> MetaSkillNode:
	## Convenience builder for a node defined in code (tests). The shipped
	## trees are resources: Data/SkillTrees/<tree_id>.tres.
	var n: MetaSkillNode = MetaSkillNode.new()
	n.id = p_id
	n.display_name = p_name
	n.description = p_desc
	n.tier = p_tier
	n.cost = p_cost
	n.currency = p_currency
	n.stat_name = p_stat
	n.stat_value = p_value
	n.stat_multiplicative = p_mult
	return n


func is_ability_node() -> bool:
	return not ability_name.is_empty()


## Currency price of buying rank `rank` (1-based); 0 outside 1..max_rank.
func cost_of_rank(rank: int) -> int:
	if rank < 1 or rank > max_rank:
		return 0
	if rank_costs.size() >= rank:
		return rank_costs[rank - 1]
	if rank == 1:
		return cost
	return int(roundf(cost * pow(cost_growth, rank - 1) / 5.0)) * 5


## The effect of owning `rank` ranks, in the form stat_value has for one rank,
## so every consumer stays a single apply call per node. An explicit
## rank_values entry wins; otherwise ranks are linear:
##   multiplicative: 1 + (stat_value - 1) x rank (1.05 -> 1.10 -> 1.15);
##   additive:       stat_value x rank.
## Rank 1 is exactly stat_value either way. Rank 0 is the neutral value (1.0
## or 0.0); ranks above max_rank count as max_rank. Different nodes on the
## same key still multiply / add with each other.
func value_at_rank(rank: int) -> float:
	var r := clampi(rank, 0, max_rank)
	if r == 0:
		return 1.0 if stat_multiplicative else 0.0
	if rank_values.size() >= r:
		return rank_values[r - 1]
	if stat_multiplicative:
		return 1.0 + (stat_value - 1.0) * r
	return stat_value * r


## The description at `rank` (1-based; clamped to 1..max_rank) with "{v}"
## filled in as the screens show it. Next to "%" the value is a percentage: a
## multiplier shows its distance from 1 (1.08 -> "8", 0.8 -> "20"), an additive
## value is a fraction (0.2 -> "20"). Anywhere else it is the plain number
## ("{v}x" 1.5 -> "1.5x", "{v} s" 0.5 -> "0.5 s", "{v} px" 200 -> "200 px").
func effect_text(rank: int) -> String:
	if not description.contains("{v}"):
		return description
	var v := value_at_rank(clampi(rank, 1, max_rank))
	var shown := v
	if description.contains("{v}%"):
		shown = absf(v - 1.0) * 100.0 if stat_multiplicative else absf(v) * 100.0
	# String.num keeps one zero after the point ("10.0"): whole numbers drop it.
	return description.replace("{v}", String.num(shown, 2).trim_suffix(".0"))
