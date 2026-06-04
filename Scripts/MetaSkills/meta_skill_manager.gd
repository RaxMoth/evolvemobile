extends Node

## MetaSkillManager — autoload that owns all permanent upgrade trees and
## handles the unlock + apply lifecycle.
##
## Trees are seeded in code on _ready (no .tres files needed yet). To add
## a new tree, write a `_seed_xyz_tree()` method and call it from _ready.
## When the data set grows large enough to need a designer-friendly format,
## migrate the seeding to .tres resources — the API stays the same.
##
## Flow:
##   • UI calls `unlock(tree_id, node_id)` → checks tier gate + affordability,
##     spends currency via PersistedData, persists the unlock id.
##   • On entity spawn (HeroBase._ready), entity calls
##     `apply_unlocked_to_hero(self)` → iterates unlocked nodes in
##     hero-relevant trees and stacks each effect onto HeroStatsComponent.

signal skill_unlocked(tree_id: StringName, node_id: StringName)
signal skills_changed  ## Generic refresh signal for UI panels.

# --- Tree id constants (use these instead of stringly references) ---
const TREE_HERO_BASE: StringName = &"hero_base"
const TREE_MONSTER_BASE: StringName = &"monster_base"

var trees: Dictionary = {}   ## id -> MetaSkillTree


func _ready() -> void:
	_seed_hero_base_tree()
	_seed_monster_base_tree()


# ============================================
# Seeding (built-in trees) — README spec
# ============================================

func _seed_hero_base_tree() -> void:
	## Hero Base Tree — universal upgrades that apply to every hero.
	## Bought with Gold. Mirrors README §"Hero Base Tree (Costs Gold)".
	var t: MetaSkillTree = MetaSkillTree.new()
	t.id = TREE_HERO_BASE
	t.display_name = "Hero Base Upgrades"
	t.description = "Bonuses applied to every hero on spawn. Bought with Gold."

	# Stat keys must match HeroStatsComponent (max_health / move_speed / attack_damage).
	# Multiplicative: pass 1.0+pct (e.g. 1.05 = +5%). HeroStatsComponent does *=.

	# Tier 1 — 100 Gold each
	t.nodes.append(MetaSkillNode.make(&"t1_hp",     "Iron Skin",     "+5% Max HP",          1, 100, PersistedData.GOLD, "max_health",    1.05))
	t.nodes.append(MetaSkillNode.make(&"t1_speed",  "Light Step",    "+5% Move Speed",      1, 100, PersistedData.GOLD, "move_speed",    1.05))
	t.nodes.append(MetaSkillNode.make(&"t1_dmg",    "Sharp Edge",    "+5% Attack Damage",   1, 100, PersistedData.GOLD, "attack_damage", 1.05))

	# Tier 2 — 300 Gold each
	t.nodes.append(MetaSkillNode.make(&"t2_dmg",    "Forged Steel",  "+10% Attack Damage",  2, 300, PersistedData.GOLD, "attack_damage", 1.10))
	t.nodes.append(MetaSkillNode.make(&"t2_hp",     "Hardened",      "+10% Max HP",         2, 300, PersistedData.GOLD, "max_health",    1.10))
	t.nodes.append(MetaSkillNode.make(&"t2_atkspd", "Quick Strike",  "+10% Attack Speed",   2, 300, PersistedData.GOLD, "attack_speed",  1.10))

	# Tier 3 — 700 Gold each
	t.nodes.append(MetaSkillNode.make(&"t3_hp",     "Veteran Plate", "+15% Max HP",         3, 700, PersistedData.GOLD, "max_health",    1.15))
	t.nodes.append(MetaSkillNode.make(&"t3_atkspd", "Battle Rhythm", "+15% Attack Speed",   3, 700, PersistedData.GOLD, "attack_speed",  1.15))
	t.nodes.append(MetaSkillNode.make(&"t3_speed",  "Swift Runner",  "+15% Move Speed",     3, 700, PersistedData.GOLD, "move_speed",    1.15))

	# Tier 4 — 1500 Gold each
	t.nodes.append(MetaSkillNode.make(&"t4_dmg",    "Berserker",     "+20% Attack Damage",  4, 1500, PersistedData.GOLD, "attack_damage", 1.20))
	t.nodes.append(MetaSkillNode.make(&"t4_hp",     "Titan",         "+25% Max HP",         4, 1500, PersistedData.GOLD, "max_health",    1.25))
	t.nodes.append(MetaSkillNode.make(&"t4_atkspd", "Storm Blades",  "+25% Attack Speed",   4, 1500, PersistedData.GOLD, "attack_speed",  1.25))

	trees[t.id] = t


func _seed_monster_base_tree() -> void:
	## Monster Base Tree — applies to whichever monster spawns. Bought with Gold.
	## Stub for now — same shape as hero tree but routed to monster spawn hook
	## (Phase 2.2 will add per-monster trees with Leaves). Kept here so the
	## monster-side player has somewhere to spend currency too.
	var t: MetaSkillTree = MetaSkillTree.new()
	t.id = TREE_MONSTER_BASE
	t.display_name = "Monster Base Upgrades"
	t.description = "Bonuses applied to the monster on spawn. Bought with Gold."

	# Monster stats live in MonsterStats resource per stage — Phase 2.1
	# nodes are stat-flag placeholders read by MonsterBase. For now they
	# unlock and persist correctly even though MonsterBase doesn't consume
	# them yet (wires up in Phase 2.2).
	t.nodes.append(MetaSkillNode.make(&"mt1_hp",     "Thicker Hide",   "+10% Max HP all stages",        1, 100, PersistedData.GOLD, "monster_health_mult",  1.10))
	t.nodes.append(MetaSkillNode.make(&"mt1_speed",  "Faster Hunt",    "+5% Move Speed",                1, 100, PersistedData.GOLD, "monster_speed_mult",   1.05))
	t.nodes.append(MetaSkillNode.make(&"mt1_xp",     "Bloodhound",     "+10% XP from kills",            1, 100, PersistedData.GOLD, "monster_xp_mult",      1.10))

	t.nodes.append(MetaSkillNode.make(&"mt2_evo",    "Quick Evolution","-10% Stage XP requirements",    2, 500, PersistedData.GOLD, "monster_evo_threshold",0.90))
	t.nodes.append(MetaSkillNode.make(&"mt2_dmg",    "Brutal Strikes", "+15% Damage",                   2, 500, PersistedData.GOLD, "monster_damage_mult",  1.15))

	t.nodes.append(MetaSkillNode.make(&"mt3_hp",     "Apex Body",      "+20% Max HP",                   3, 1000, PersistedData.GOLD, "monster_health_mult",  1.20))
	t.nodes.append(MetaSkillNode.make(&"mt3_range",  "Long Reach",     "+10% Ability Range",            3, 1000, PersistedData.GOLD, "monster_range_mult",   1.10))

	trees[t.id] = t


# ============================================
# Public API
# ============================================

func get_tree_def(tree_id: StringName) -> MetaSkillTree:
	# Dictionary.get returns Variant; cast keeps the typed return clean.
	return trees.get(tree_id) as MetaSkillTree


func is_unlocked(tree_id: StringName, node_id: StringName) -> bool:
	var unlocked: Array = PersistedData.get_unlocked_skills(tree_id)
	return unlocked.has(String(node_id))


func is_node_available(tree_id: StringName, node_id: StringName) -> bool:
	## A node is "available" if not yet unlocked, the tier gate is satisfied,
	## and the player can afford its cost. UI uses this to color the button.
	if is_unlocked(tree_id, node_id):
		return false
	var t: MetaSkillTree = get_tree_def(tree_id)
	if t == null:
		return false
	var n: MetaSkillNode = t.find_node(node_id)
	if n == null:
		return false
	if not _tier_gate_satisfied(t, n.tier):
		return false
	return PersistedData.can_afford(n.currency, n.cost)


func unlock(tree_id: StringName, node_id: StringName) -> bool:
	## Attempt to unlock a node. Returns true on success, false if blocked
	## (already unlocked / tier-locked / unaffordable). On success: spends
	## currency, persists, fires signal.
	var t: MetaSkillTree = get_tree_def(tree_id)
	if t == null:
		return false
	var n: MetaSkillNode = t.find_node(node_id)
	if n == null:
		return false
	if is_unlocked(tree_id, node_id):
		return false
	if not _tier_gate_satisfied(t, n.tier):
		return false
	if not PersistedData.spend_currency(n.currency, n.cost):
		return false

	var unlocked: Array = PersistedData.get_unlocked_skills(tree_id)
	unlocked.append(String(node_id))
	PersistedData.set_unlocked_skills(tree_id, unlocked)
	PersistedData.save_data()

	skill_unlocked.emit(tree_id, node_id)
	skills_changed.emit()
	return true


func _tier_gate_satisfied(t: MetaSkillTree, tier: int) -> bool:
	## A tier is reachable if at least one node in tier-1 is unlocked.
	## Tier 1 is always reachable.
	if tier <= 1:
		return true
	for n in t.nodes_in_tier(tier - 1):
		if is_unlocked(t.id, n.id):
			return true
	return false


# ============================================
# Apply unlocked effects to a freshly spawned entity
# ============================================

## Called by HeroBase._ready. Stacks every unlocked hero-base node's stat
## modifier onto the hero's HeroStatsComponent.
func apply_unlocked_to_hero(hero: Node) -> void:
	var stats := hero.get_node_or_null("HeroStats") as HeroStatsComponent
	if stats == null:
		return
	var t: MetaSkillTree = get_tree_def(TREE_HERO_BASE)
	if t == null:
		return
	var unlocked: Array = PersistedData.get_unlocked_skills(TREE_HERO_BASE)
	for n in t.nodes:
		if not unlocked.has(String(n.id)):
			continue
		if n.stat_name.is_empty():
			continue
		# HeroStatsComponent only knows about hero stats — skip monster keys.
		if n.stat_name.begins_with("monster_"):
			continue
		stats.add_stat_modifier(n.stat_name, n.stat_value, n.stat_multiplicative)


## Called by MonsterBase._ready when its time comes (Phase 2.2 hookup).
## For now, returns the dict of multipliers so MonsterStats reading can
## apply them at stage-config time.
func collect_monster_modifiers() -> Dictionary:
	var out: Dictionary = {}
	var t: MetaSkillTree = get_tree_def(TREE_MONSTER_BASE)
	if t == null:
		return out
	var unlocked: Array = PersistedData.get_unlocked_skills(TREE_MONSTER_BASE)
	for n in t.nodes:
		if not unlocked.has(String(n.id)) or n.stat_name.is_empty():
			continue
		# Stack multiplicatively if same key appears multiple times.
		out[n.stat_name] = float(out.get(n.stat_name, 1.0)) * n.stat_value
	return out
