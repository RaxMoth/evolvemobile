class_name MetaSkillNode
extends Resource

## MetaSkillNode — one unlock-able permanent upgrade.
##
## "Meta" distinguishes from the in-round SkillNode in /Scripts/Skilltree/
## (which uses per-match leveling). This one is persistent across all
## matches: bought with Steel / Leaves / Gold, applied to every hero or
## monster spawn from now on.
##
## v1: each node has a SINGLE stat effect. If we need multi-effect nodes
## later (e.g. "+5% HP AND +5% speed"), turn `effects` into an array of
## sub-resources. For now the per-tier nodes in the README spec all map
## cleanly to one-stat-each.

@export var id: StringName = &""
@export var display_name: String = "Unnamed"
@export var description: String = ""
@export var tier: int = 1               ## 1-4 per README. Higher tiers gate on previous tier having at least one unlock.
@export var cost: int = 100             ## Currency cost to unlock.
@export var currency: StringName = &"gold"  ## Matches PersistedData.STEEL / LEAVES / GOLD.
@export var icon: Texture2D = null

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
	## Convenience builder so we can define trees in code without hand-
	## constructing each resource. Used by MetaSkillManager._seed_*.
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
