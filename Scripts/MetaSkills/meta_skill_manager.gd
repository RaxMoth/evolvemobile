extends Node

## MetaSkillManager — autoload that owns all permanent upgrade trees and
## handles the unlock + apply lifecycle.
##
## The trees are resources (Data/SkillTrees/<tree_id>.tres, one MetaSkillTree
## each). _ready registers the two side-wide base trees (HERO_BASE_TREE,
## MONSTER_BASE_TREE) and the tree of every roster character
## (CharacterDef.skill_tree in GameManager.ROSTER): adding a character = its
## def + its tree. A tree whose character is not in the roster yet (Nyxa,
## Gorrak) is not registered, so nothing can buy or apply it.
##
## Flow:
##   • UI renders each node from `node_state(tree_id, node_id)` and calls
##     `rank_up(tree_id, node_id)` → buys the next rank of an AVAILABLE node:
##     spends currency via PersistedData, persists the rank.
##   • On entity spawn (HeroBase._ready), entity calls
##     `apply_unlocked_to_hero(self)` → iterates owned nodes in hero-relevant
##     trees and stacks each effect, at its rank, onto HeroStatsComponent.
##
## Ranks: a node has 1..max_rank ranks; owning rank r applies
## MetaSkillNode.value_at_rank(r) once. Gates (the tree's gate_kind, the node's
## `requires`) guard buying rank 1 only: owned nodes are never revoked, and an
## old save that owns a node above today's gate keeps it and it applies.
##
## Capstones: every branch of a character tree ends in one. All can be bought,
## but only the tree's equipped capstone applies (equipped_capstone). Buying the
## first one equips it; equip_capstone() swaps for free.
##
## Hidden nodes (MetaSkillNode.hidden, effects without code yet) are treated
## like ids the tree does not have: INVALID (UNLOCKED if a save owns one), never
## bought, never applied, left out of card_progress.

signal skill_unlocked(tree_id: StringName, node_id: StringName)
## Every purchase, rank 1 included (skill_unlocked still fires for rank 1).
signal skill_ranked(tree_id: StringName, node_id: StringName, rank: int)
signal skills_changed  ## Generic refresh signal for UI panels.

# --- Tree id constants (use these instead of stringly references) ---
const TREE_HERO_BASE: StringName = &"hero_base"
const TREE_MONSTER_BASE: StringName = &"monster_base"
## Per-character trees are "hero_<hero_id>" (Steel) and "monster_<monster_id>"
## (Leaves); the ids come from HeroStats.hero_id / MonsterStats.monster_id.
const TREE_HERO_PREFIX := "hero_"
const TREE_MONSTER_PREFIX := "monster_"

## A node as the skill screen shows it; only AVAILABLE can be bought (its next
## rank). INVALID = no such tree, or no such node in it. UNLOCKED = every rank
## owned (for a 1-rank node: owned, as before ranks existed). A node owned below
## max_rank reports its NEXT rank (AVAILABLE / UNAFFORDABLE): the gates only
## guard rank 1. TIER_GATED = the tier is closed (TIER_BELOW / POINTS gate),
## LEVEL_GATED = closed by the owner's level (LEVEL gate), REQUIRES_MISSING =
## none of `requires` is owned. New values are appended; the old ordinals stay.
enum NodeState { INVALID, UNLOCKED, TIER_GATED, AVAILABLE, UNAFFORDABLE, LEVEL_GATED, REQUIRES_MISSING }

## The side-wide trees, bought with Gold. Character trees come from the roster.
const HERO_BASE_TREE: MetaSkillTree = preload("res://Data/SkillTrees/hero_base.tres")
const MONSTER_BASE_TREE: MetaSkillTree = preload("res://Data/SkillTrees/monster_base.tres")

var trees: Dictionary = {}   ## id -> MetaSkillTree


func _ready() -> void:
	register_tree(HERO_BASE_TREE)
	register_tree(MONSTER_BASE_TREE)
	# GameManager is a later autoload: every autoload node exists before the
	# first _ready runs, and ROSTER is its preloaded constant.
	for def in GameManager.ROSTER.all():
		if def != null and def.skill_tree != null:
			register_tree(def.skill_tree)


## Makes `t` known under its id (replacing a tree with the same id). The tree
## is the shared resource: read it, never modify it at runtime.
func register_tree(t: MetaSkillTree) -> void:
	trees[t.id] = t


func hero_tree_id(hero_id: StringName) -> StringName:
	return StringName(TREE_HERO_PREFIX + String(hero_id))


func monster_tree_id(monster_id: StringName) -> StringName:
	return StringName(TREE_MONSTER_PREFIX + String(monster_id))


## The stable id of a spawned hero, read from its HeroStats resource.
func hero_id_of(hero: Node) -> StringName:
	var stats := hero.get_node_or_null("HeroStats") as HeroStatsComponent
	if stats == null or stats.base_stats == null:
		return &""
	return stats.base_stats.hero_id


# ============================================
# Public API
# ============================================

func get_tree_def(tree_id: StringName) -> MetaSkillTree:
	# Dictionary.get returns Variant; cast keeps the typed return clean.
	return trees.get(tree_id) as MetaSkillTree


## Ranks owned of a node (0 = not owned), straight from the save.
func get_rank(tree_id: StringName, node_id: StringName) -> int:
	return PersistedData.get_skill_rank(tree_id, node_id)


func is_unlocked(tree_id: StringName, node_id: StringName) -> bool:
	return get_rank(tree_id, node_id) >= 1


func is_maxed(tree_id: StringName, node_id: StringName) -> bool:
	var n := _node(tree_id, node_id)
	return n != null and get_rank(tree_id, node_id) >= n.max_rank


## Price of the node's next rank; 0 when maxed or unknown.
func next_rank_cost(tree_id: StringName, node_id: StringName) -> int:
	var n := _node(tree_id, node_id)
	return n.cost_of_rank(get_rank(tree_id, node_id) + 1) if n != null else 0


## The buying rules, in one place: owned ranks, then (rank 1 only) the tier
## gate and the prerequisites, then the price of the next rank. An id the save
## owns stays UNLOCKED even if its tree or node is gone (or hidden).
func node_state(tree_id: StringName, node_id: StringName) -> NodeState:
	var rank := get_rank(tree_id, node_id)
	var t: MetaSkillTree = get_tree_def(tree_id)
	var n := _node(tree_id, node_id)
	if n == null:
		return NodeState.UNLOCKED if rank >= 1 else NodeState.INVALID
	if rank >= n.max_rank:
		return NodeState.UNLOCKED
	if rank == 0:
		if not is_tier_open(tree_id, n.tier):
			return NodeState.LEVEL_GATED if t.gate_kind == MetaSkillTree.GateKind.LEVEL else NodeState.TIER_GATED
		if not _requires_met(tree_id, n):
			return NodeState.REQUIRES_MISSING
	if not PersistedData.can_afford(n.currency, n.cost_of_rank(rank + 1)):
		return NodeState.UNAFFORDABLE
	return NodeState.AVAILABLE


func is_node_available(tree_id: StringName, node_id: StringName) -> bool:
	return node_state(tree_id, node_id) == NodeState.AVAILABLE


## Buys the next rank: spends currency, persists, fires the signals. false
## unless node_state is AVAILABLE. Buying a capstone while the tree has none
## equipped equips it; otherwise the equipped one stays (and is written down,
## so a second capstone never takes over through the first-owned rule).
func rank_up(tree_id: StringName, node_id: StringName) -> bool:
	if node_state(tree_id, node_id) != NodeState.AVAILABLE:
		return false
	var n := _node(tree_id, node_id)
	var rank := get_rank(tree_id, node_id) + 1
	if not PersistedData.spend_currency(n.currency, n.cost_of_rank(rank)):
		return false
	if n.capstone:
		var equipped := equipped_capstone(tree_id)
		PersistedData.set_equipped_capstone(tree_id, equipped if equipped != &"" else node_id)
	PersistedData.set_skill_rank(tree_id, node_id, rank)
	PersistedData.save_data()
	if rank == 1:
		skill_unlocked.emit(tree_id, node_id)
	skill_ranked.emit(tree_id, node_id, rank)
	skills_changed.emit()
	return true


## Rank 1 only (the pre-rank API): false on a node already owned.
func unlock(tree_id: StringName, node_id: StringName) -> bool:
	if is_unlocked(tree_id, node_id):
		return false
	return rank_up(tree_id, node_id)


## Whether tier `tier` of a tree is open for buying (tier 1 always is):
##   TIER_BELOW: a node of the tier below is owned;
##   LEVEL:      the owner's permanent level reaches tier_gates;
##   POINTS:     the ranks owned in the tree reach tier_gates.
func is_tier_open(tree_id: StringName, tier: int) -> bool:
	var t: MetaSkillTree = get_tree_def(tree_id)
	if t == null or tier <= 1:
		return true
	match t.gate_kind:
		MetaSkillTree.GateKind.LEVEL:
			return t.owner_id == &"" or owner_level(t) >= t.gate_for_tier(tier)
		MetaSkillTree.GateKind.POINTS:
			return points_spent(tree_id) >= t.gate_for_tier(tier)
	for n in t.nodes_in_tier(tier - 1):
		if is_unlocked(tree_id, n.id):
			return true
	return false


## Permanent level of the tree's owner (PersistedData.level_from_xp of its hero
## or, for a monster_<id> tree, monster XP); 1 for a tree without an owner.
func owner_level(t: MetaSkillTree) -> int:
	if t.owner_id == &"":
		return 1
	var monster := String(t.id).begins_with(TREE_MONSTER_PREFIX)
	var xp := PersistedData.get_monster_xp(t.owner_id) if monster else PersistedData.get_hero_xp(t.owner_id)
	return PersistedData.level_from_xp(xp)


## Ranks owned in a tree (the POINTS gate's currency), unknown ids included:
## a node retired from the data was still bought.
func points_spent(tree_id: StringName) -> int:
	var total := 0
	for r: Variant in PersistedData.get_skill_ranks(tree_id).values():
		total += int(r)
	return total


## The tree's active capstone: the saved choice while it names an owned
## capstone of the tree; otherwise (the capstone migration: no choice saved, as
## in every v2 save that owns Titan Form) the first owned capstone in branch
## order; &"" when the tree owns none.
func equipped_capstone(tree_id: StringName) -> StringName:
	var t: MetaSkillTree = get_tree_def(tree_id)
	if t == null:
		return &""
	var saved := PersistedData.get_equipped_capstone(tree_id)
	var first_owned: StringName = &""
	for n in t.capstones():
		if not is_unlocked(tree_id, n.id):
			continue
		if n.id == saved:
			return saved
		if first_owned == &"":
			first_owned = n.id
	return first_owned


## Makes an owned capstone the tree's active one (free, any number of times;
## the next spawn applies it). false when `node_id` is not an owned capstone of
## the tree.
func equip_capstone(tree_id: StringName, node_id: StringName) -> bool:
	var n := _node(tree_id, node_id)
	if n == null or not n.capstone or not is_unlocked(tree_id, node_id):
		return false
	if PersistedData.get_equipped_capstone(tree_id) == node_id:
		return true
	PersistedData.set_equipped_capstone(tree_id, node_id)
	PersistedData.save_data()
	skills_changed.emit()
	return true


## The card's rank pill for a tree:
##   owned_ranks:   ranks owned in the tree's nodes;
##   open_ranks:    ranks the player can hold today: every rank of a node in an
##                  open tier, plus what is owned in a closed one;
##   upgrade_ready: a next rank can be bought right now (AVAILABLE).
## All zero / false for an unknown tree.
func card_progress(tree_id: StringName) -> Dictionary:
	var owned := 0
	var open := 0
	var buyable := false
	var t: MetaSkillTree = get_tree_def(tree_id)
	if t != null:
		var ranks := PersistedData.get_skill_ranks(tree_id)
		for n in t.shown_nodes():
			var rank: int = mini(int(ranks.get(String(n.id), 0)), n.max_rank)
			owned += rank
			open += n.max_rank if is_tier_open(tree_id, n.tier) else rank
			if not buyable and node_state(tree_id, n.id) == NodeState.AVAILABLE:
				buyable = true
	return {"owned_ranks": owned, "open_ranks": open, "upgrade_ready": buyable}


## The node the game knows: null for an unknown tree or id, and for a hidden
## node.
func _node(tree_id: StringName, node_id: StringName) -> MetaSkillNode:
	var t: MetaSkillTree = get_tree_def(tree_id)
	var n: MetaSkillNode = t.find_node(node_id) if t != null else null
	return n if n != null and not n.hidden else null


## `requires` is met when any (requires_all: every) listed node is owned. Only
## nodes the game knows count: a hidden or unknown id neither opens nor blocks,
## so a list of only such ids (or an empty one) leaves just the tier gate.
func _requires_met(tree_id: StringName, n: MetaSkillNode) -> bool:
	var listed := false
	for req in n.requires:
		if _node(tree_id, req) == null:
			continue
		listed = true
		var owned := is_unlocked(tree_id, req)
		if owned and not n.requires_all:
			return true
		if not owned and n.requires_all:
			return false
	return n.requires_all or not listed


# ============================================
# Apply unlocked effects to a freshly spawned entity
# ============================================

## Called by HeroBase._ready. Stacks every owned node of the Hero Base tree AND
## of this hero's own tree (hero_<id>) onto its HeroStatsComponent, each at its
## rank (one apply call per node; see applied_ranks). The generic keys
## (damage_taken_mult, cooldown_mult, start_level) stack there like the stats;
## their apply sites read them back (README "Generic stat keys").
func apply_unlocked_to_hero(hero: Node) -> void:
	var stats := hero.get_node_or_null("HeroStats") as HeroStatsComponent
	if stats == null:
		return
	_apply_tree_to_stats(TREE_HERO_BASE, stats)
	var hero_id := hero_id_of(hero)
	if hero_id != &"":
		_apply_tree_to_stats(hero_tree_id(hero_id), stats)
		var abilities := hero.get_node_or_null("AbilitySystem") as AbilitySystem
		if abilities:
			abilities.make_abilities_unique()
			_apply_ability_nodes(hero_tree_id(hero_id), abilities.all_abilities())
	# HeroStats initialised current_health before the +max HP nodes existed.
	stats.refill_health()


## Called by MonsterBase._load_meta_modifiers with its own ability copies.
func apply_ability_nodes_to_monster(monster_id: StringName, abilities: Array[AbilityBase]) -> void:
	if monster_id == &"":
		return
	_apply_ability_nodes(monster_tree_id(monster_id), abilities)


## The nodes of a tree that take effect on a spawn, node id -> rank: every
## owned node of the tree at its owned rank, except the capstones that are not
## the equipped one. Unknown ids (no such node) and hidden nodes are left out.
func applied_ranks(tree_id: StringName) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	var t: MetaSkillTree = get_tree_def(tree_id)
	if t == null:
		return out
	var ranks := PersistedData.get_skill_ranks(tree_id)
	var equipped := equipped_capstone(tree_id)
	for n in t.shown_nodes():
		var rank: int = int(ranks.get(String(n.id), 0))
		if rank >= 1 and (not n.capstone or n.id == equipped):
			out[n.id] = rank
	return out


func _apply_ability_nodes(tree_id: StringName, abilities: Array[AbilityBase]) -> void:
	var t: MetaSkillTree = get_tree_def(tree_id)
	if t == null:
		return
	var ranks := applied_ranks(tree_id)
	for n in t.nodes:
		if not n.is_ability_node() or not ranks.has(n.id):
			continue
		var value := n.value_at_rank(ranks[n.id])
		for a in abilities:
			if a.ability_name == n.ability_name:
				a.apply_meta_modifier(n.stat_name, value, n.stat_multiplicative)


func _apply_tree_to_stats(tree_id: StringName, stats: HeroStatsComponent) -> void:
	var t: MetaSkillTree = get_tree_def(tree_id)
	if t == null:
		return
	var ranks := applied_ranks(tree_id)
	for n in t.nodes:
		if not ranks.has(n.id) or n.stat_name.is_empty() or n.is_ability_node():
			continue
		# HeroStatsComponent only knows about hero stats — skip monster keys.
		if n.stat_name.begins_with("monster_"):
			continue
		stats.add_stat_modifier(n.stat_name, n.value_at_rank(ranks[n.id]), n.stat_multiplicative)


## Called by MonsterBase._load_meta_modifiers. Returns key -> value for the
## Monster Base tree merged with the monster's own tree (monster_<id>) when an
## id is given. A key is either always multiplicative (stacked from 1.0; a
## missing key means 1.0) or always additive (behaviour keys such as
## monster_enrage and amounts such as monster_start_xp, summed from 0.0; a
## missing key means 0.0 = off).
func collect_monster_modifiers(monster_id: StringName = &"") -> Dictionary:
	var out: Dictionary = {}
	_merge_monster_tree(TREE_MONSTER_BASE, out)
	if monster_id != &"":
		_merge_monster_tree(monster_tree_id(monster_id), out)
	return out


func _merge_monster_tree(tree_id: StringName, out: Dictionary) -> void:
	var t: MetaSkillTree = get_tree_def(tree_id)
	if t == null:
		return
	var ranks := applied_ranks(tree_id)
	for n in t.nodes:
		if not ranks.has(n.id) or n.stat_name.is_empty() or n.is_ability_node():
			continue
		var value := n.value_at_rank(ranks[n.id])
		if n.stat_multiplicative:
			# Stack multiplicatively if the same key appears multiple times.
			out[n.stat_name] = float(out.get(n.stat_name, 1.0)) * value
		else:
			out[n.stat_name] = float(out.get(n.stat_name, 0.0)) + value
