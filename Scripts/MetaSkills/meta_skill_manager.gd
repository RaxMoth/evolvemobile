extends Node

## MetaSkillManager — autoload that owns all permanent upgrade trees and
## handles the unlock + apply lifecycle.
##
## The trees are resources (Data/SkillTrees/<tree_id>.tres, one MetaSkillTree
## each). _ready registers the two side-wide base trees (HERO_BASE_TREE,
## MONSTER_BASE_TREE) and the tree of every roster character
## (CharacterDef.skill_tree in GameManager.ROSTER): adding a character = its
## def + its tree (all three monsters, Grount, Nyxa and Gorrak, are in it). A
## tree whose character is not in the roster is not registered, so nothing can
## buy or apply it.
##
## Flow:
##   • UI renders each node from `node_state(tree_id, node_id)` and calls
##     `rank_up(tree_id, node_id)` → buys the next rank of an AVAILABLE node:
##     spends currency via PersistedData, persists the rank.
##   • On entity spawn (HeroBase._ready), entity calls
##     `apply_unlocked_to_hero(self)` → iterates owned nodes in hero-relevant
##     trees and stacks each effect, at its rank, onto HeroStatsComponent.
##
## Side rule (README "Opponent Threat"): only the PLAYED side
## (GameManager.chosen_side) applies the save's trees. The AI opponent applies
## a fixed AI build instead: at threat T = min(4, floor(P / 6)), P = the played
## side's power ranks, the first 3T entries of its character tree's
## ai_build_order and the first 2T of its base tree's. No RNG. The opponent
## never gets the player's unlocks (it used to: both sides read the save).
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

# --- Opponent Threat (README "Opponent Threat") ---
## The highest threat level.
const MAX_THREAT := 4
## Power ranks per threat level: T = min(MAX_THREAT, floor(P / RANKS_PER_THREAT)).
const RANKS_PER_THREAT := 6
## ai_build_order entries the AI build takes per threat level: of the
## opponent's character tree, and of its side's base tree.
const AI_CHARACTER_ENTRIES_PER_THREAT := 3
const AI_BASE_ENTRIES_PER_THREAT := 2

var trees: Dictionary = {}   ## id -> MetaSkillTree
## Sims only (tools/sim_match.gd "threat=N", the parity check): when >= 0,
## opponent_threat() returns it instead of the rule's threat. -1 = the rule.
var threat_override: int = -1


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
# Opponent Threat: the side rule and the AI build
# ============================================

## Whether `side` (MatchRewards.Side) is the AI opponent this match: the side
## GameManager.chosen_side does not play. Its spawns apply the AI build.
func is_ai_side(side: int) -> bool:
	return side != GameManager.chosen_side


## Whether a tree is one of the two side-wide base trees.
func is_base_tree(tree_id: StringName) -> bool:
	return tree_id == TREE_HERO_BASE or tree_id == TREE_MONSTER_BASE


## Ranks owned in a tree's shown nodes, each capped at its max rank (the card
## pill's owned_ranks): retired and hidden ids do not count.
func owned_ranks(tree_id: StringName) -> int:
	var t: MetaSkillTree = get_tree_def(tree_id)
	if t == null:
		return 0
	var ranks := PersistedData.get_skill_ranks(tree_id)
	var total := 0
	for n in t.shown_nodes():
		total += mini(int(ranks.get(String(n.id), 0)), n.max_rank)
	return total


## The power ranks P of the played `side`: ranks owned in its base tree plus
## in the played character's tree (`monster_id` on the Monster side); for the
## heroes the floor of the mean over the roster's hero trees.
func power_ranks(side: int, monster_id: StringName) -> int:
	if side == MatchRewards.Side.MONSTER:
		return owned_ranks(TREE_MONSTER_BASE) + owned_ranks(monster_tree_id(monster_id))
	var hero_ids := GameManager.ROSTER.hero_ids()
	var total := 0
	for id in hero_ids:
		total += owned_ranks(hero_tree_id(id))
	@warning_ignore("integer_division")
	var mean: int = total / hero_ids.size() if not hero_ids.is_empty() else 0
	return owned_ranks(TREE_HERO_BASE) + mean


## T = min(MAX_THREAT, floor(P / RANKS_PER_THREAT)).
func threat_for_power(power: int) -> int:
	@warning_ignore("integer_division")
	return clampi(power / RANKS_PER_THREAT, 0, MAX_THREAT)


## The threat the AI opponent has when the player plays `side` (with
## `monster_id`, the played monster, on the Monster side).
func threat_for(side: int, monster_id: StringName) -> int:
	return threat_for_power(power_ranks(side, monster_id))


## This match's threat: GameManager's chosen side and selected monster (the
## match's monster once begin_hunt or a sim picked it); threat_override when a
## sim set one.
func opponent_threat() -> int:
	if threat_override >= 0:
		return mini(threat_override, MAX_THREAT)
	return threat_for(GameManager.chosen_side, GameManager.selected_monster_id)


## How many ai_build_order entries of `tree_id` the AI build takes at
## `threat`: 3T of a character tree, 2T of a base tree.
func ai_build_entries(tree_id: StringName, threat: int) -> int:
	var per: int = AI_BASE_ENTRIES_PER_THREAT if is_base_tree(tree_id) else AI_CHARACTER_ENTRIES_PER_THREAT
	return clampi(threat, 0, MAX_THREAT) * per


## node id -> rank of the first `entries` entries of the tree's ai_build_order:
## each entry is one more rank of that node, capped at its max rank. Ids the
## game does not know (unknown, hidden) are skipped. Every capstone in the
## prefix applies: an order ends in its one capstone.
func ai_build_ranks(tree_id: StringName, entries: int) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	var t: MetaSkillTree = get_tree_def(tree_id)
	if t == null:
		return out
	for i in mini(maxi(entries, 0), t.ai_build_order.size()):
		var id: StringName = t.ai_build_order[i]
		var n := _node(tree_id, id)
		if n != null:
			out[id] = mini(int(out.get(id, 0)) + 1, n.max_rank)
	return out


## The ranks a spawn of `side` applies from `tree_id`, node id -> rank: the
## save's (applied_ranks) for the played side, the AI build at this match's
## threat for the opponent.
func spawn_ranks(tree_id: StringName, side: int) -> Dictionary[StringName, int]:
	if not is_ai_side(side):
		return applied_ranks(tree_id)
	return ai_build_ranks(tree_id, ai_build_entries(tree_id, opponent_threat()))


## Ranks the AI build at `threat` holds in `tree_id` (F3).
func ai_build_size(tree_id: StringName, threat: int) -> int:
	var total := 0
	for r: int in ai_build_ranks(tree_id, ai_build_entries(tree_id, threat)).values():
		total += r
	return total


## The AI build of a whole side at `threat`, tree id -> (node id -> rank): its
## base tree (2T entries) and each of its character trees (3T): every roster
## hero's, or `monster_id`'s on the Monster side. What the AI opponent spawns
## with, and what tools/sim.sh THREAT=N gives the played side too, so both
## sides hold their threat-N build (the parity check).
func side_ai_build(side: int, monster_id: StringName, threat: int) -> Dictionary[StringName, Dictionary]:
	var tree_ids: Array[StringName] = []
	if side == MatchRewards.Side.MONSTER:
		tree_ids = [TREE_MONSTER_BASE, monster_tree_id(monster_id)]
	else:
		tree_ids = [TREE_HERO_BASE]
		for id in GameManager.ROSTER.hero_ids():
			tree_ids.append(hero_tree_id(id))
	var out: Dictionary[StringName, Dictionary] = {}
	for tree_id in tree_ids:
		out[tree_id] = ai_build_ranks(tree_id, ai_build_entries(tree_id, threat))
	return out


# ============================================
# Apply unlocked effects to a freshly spawned entity
# ============================================

## Called by HeroBase._ready. Stacks every node the heroes' build holds from
## the Hero Base tree AND this hero's own tree (hero_<id>) onto its
## HeroStatsComponent, each at its rank (one apply call per node): the save's
## owned nodes (applied_ranks) when the player plays the heroes, else the AI
## build (spawn_ranks). The generic keys (damage_taken_mult, cooldown_mult,
## start_level) stack there like the stats; their apply sites read them back
## (README "Generic stat keys").
func apply_unlocked_to_hero(hero: Node) -> void:
	var stats := hero.get_node_or_null("HeroStats") as HeroStatsComponent
	if stats == null:
		return
	_apply_tree_to_stats(TREE_HERO_BASE, stats, spawn_ranks(TREE_HERO_BASE, MatchRewards.Side.HEROES))
	var hero_id := hero_id_of(hero)
	if hero_id != &"":
		var tree_id := hero_tree_id(hero_id)
		var ranks := spawn_ranks(tree_id, MatchRewards.Side.HEROES)
		_apply_tree_to_stats(tree_id, stats, ranks)
		var abilities := hero.get_node_or_null("AbilitySystem") as AbilitySystem
		if abilities:
			abilities.make_abilities_unique()
			_apply_ability_nodes(tree_id, abilities.all_abilities(), ranks)
	# HeroStats initialised current_health before the +max HP nodes existed.
	stats.refill_health()


## Called by MonsterBase._load_meta_modifiers with its own ability copies:
## the ability nodes of the monster's build (spawn_ranks).
func apply_ability_nodes_to_monster(monster_id: StringName, abilities: Array[AbilityBase]) -> void:
	if monster_id == &"":
		return
	var tree_id := monster_tree_id(monster_id)
	_apply_ability_nodes(tree_id, abilities, spawn_ranks(tree_id, MatchRewards.Side.MONSTER))


## The nodes of a tree that take effect on a spawn of the played side, node
## id -> rank: every owned node of the tree at its owned rank, except the
## capstones that are not the equipped one. Unknown ids (no such node) and
## hidden nodes are left out.
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


# ============================================
# The owned build outside a match (the menus' character overview)
# ============================================
# The side rule does not apply here: these always read the save, so a screen
# shows the player's own character whatever side is chosen. Each one stacks
# the nodes with the helper a spawn uses (_apply_tree_to_stats,
# _merge_monster_tree, _apply_ability_nodes), so the menus and the match agree.

## A hero with `base` stats as the player fields it: a HeroStatsComponent that
## never enters the tree, carrying the save's nodes (applied_ranks) of Hero
## Base and the hero's own tree, then levelled to the start level, as
## HeroBase._ready does on a spawn. The caller reads it and frees it.
func owned_hero_stats(base: HeroStats) -> HeroStatsComponent:
	var stats := HeroStatsComponent.new()
	stats.base_stats = base
	stats.initialize()
	_apply_tree_to_stats(TREE_HERO_BASE, stats, applied_ranks(TREE_HERO_BASE))
	if base.hero_id != &"":
		var tree_id := hero_tree_id(base.hero_id)
		_apply_tree_to_stats(tree_id, stats, applied_ranks(tree_id))
	stats.apply_start_level()
	return stats


## key -> value of the monster build the player owns: the save's nodes
## (applied_ranks) of Monster Base and monster_<id>, merged like
## collect_monster_modifiers. What `monster_id` spawns with when the player
## plays it (MonsterBase.build_* turn it into stage numbers).
func owned_monster_modifiers(monster_id: StringName) -> Dictionary:
	var out: Dictionary = {}
	_merge_monster_tree(TREE_MONSTER_BASE, out, applied_ranks(TREE_MONSTER_BASE))
	if monster_id != &"":
		var tree_id := monster_tree_id(monster_id)
		_merge_monster_tree(tree_id, out, applied_ranks(tree_id))
	return out


## A copy of the shared ability resource `ability` carrying the ability nodes
## the player owns in `tree_id`, as a spawn's own copy does; null for null.
func owned_ability(tree_id: StringName, ability: AbilityBase) -> AbilityBase:
	if ability == null:
		return null
	var copy := ability.duplicate() as AbilityBase
	_apply_ability_nodes(tree_id, [copy], applied_ranks(tree_id))
	return copy


func _apply_ability_nodes(tree_id: StringName, abilities: Array[AbilityBase], ranks: Dictionary[StringName, int]) -> void:
	var t: MetaSkillTree = get_tree_def(tree_id)
	if t == null:
		return
	for n in t.nodes:
		if not n.is_ability_node() or not ranks.has(n.id):
			continue
		var value := n.value_at_rank(ranks[n.id])
		for a in abilities:
			if a.ability_name == n.ability_name:
				a.apply_meta_modifier(n.stat_name, value, n.stat_multiplicative)


func _apply_tree_to_stats(tree_id: StringName, stats: HeroStatsComponent, ranks: Dictionary[StringName, int]) -> void:
	var t: MetaSkillTree = get_tree_def(tree_id)
	if t == null:
		return
	for n in t.nodes:
		if not ranks.has(n.id) or n.stat_name.is_empty() or n.is_ability_node():
			continue
		# HeroStatsComponent only knows about hero stats — skip monster keys.
		if n.stat_name.begins_with("monster_"):
			continue
		stats.add_stat_modifier(n.stat_name, n.value_at_rank(ranks[n.id]), n.stat_multiplicative)


## Called by MonsterBase._load_meta_modifiers. Returns key -> value for the
## monster's build (spawn_ranks: the save when the player plays the monster,
## else the AI build) of the Monster Base tree merged with the monster's own
## tree (monster_<id>) when an id is given. A key is either always
## multiplicative (stacked from 1.0; a missing key means 1.0) or always
## additive (behaviour keys such as monster_enrage and amounts such as
## monster_start_xp, summed from 0.0; a missing key means 0.0 = off).
func collect_monster_modifiers(monster_id: StringName = &"") -> Dictionary:
	var out: Dictionary = {}
	_merge_monster_tree(TREE_MONSTER_BASE, out, spawn_ranks(TREE_MONSTER_BASE, MatchRewards.Side.MONSTER))
	if monster_id != &"":
		var tree_id := monster_tree_id(monster_id)
		_merge_monster_tree(tree_id, out, spawn_ranks(tree_id, MatchRewards.Side.MONSTER))
	return out


func _merge_monster_tree(tree_id: StringName, out: Dictionary, ranks: Dictionary[StringName, int]) -> void:
	var t: MetaSkillTree = get_tree_def(tree_id)
	if t == null:
		return
	for n in t.nodes:
		if not ranks.has(n.id) or n.stat_name.is_empty() or n.is_ability_node():
			continue
		var value := n.value_at_rank(ranks[n.id])
		if n.stat_multiplicative:
			# Stack multiplicatively if the same key appears multiple times.
			out[n.stat_name] = float(out.get(n.stat_name, 1.0)) * value
		else:
			out[n.stat_name] = float(out.get(n.stat_name, 0.0)) + value
