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
## Per-character trees are "hero_<hero_id>" (Steel) and "monster_<monster_id>"
## (Leaves); the ids come from HeroStats.hero_id / MonsterStats.monster_id.
const TREE_HERO_PREFIX := "hero_"
const TREE_MONSTER_PREFIX := "monster_"

var trees: Dictionary = {}   ## id -> MetaSkillTree


func _ready() -> void:
	_seed_hero_base_tree()
	_seed_monster_base_tree()
	_seed_hero_trees()
	_seed_monster_trees()


static func hero_tree_id(hero_id: StringName) -> StringName:
	return StringName(TREE_HERO_PREFIX + String(hero_id))


static func monster_tree_id(monster_id: StringName) -> StringName:
	return StringName(TREE_MONSTER_PREFIX + String(monster_id))


## The stable id of a spawned hero, read from its HeroStats resource.
static func hero_id_of(hero: Node) -> StringName:
	var stats := hero.get_node_or_null("HeroStats") as HeroStatsComponent
	if stats == null or stats.base_stats == null:
		return &""
	return stats.base_stats.hero_id


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
# Seeding — individual hero trees (Steel) / monster trees (Leaves)
# ============================================
# Stat-only slice of README §"Individual Hero Trees" / "Individual Monster
# Trees": every node is one stat effect the existing components already
# consume. Ability-changing unlocks (Triple Shot, Ram Dash stun, …) need
# per-ability hooks and are not represented yet.

const HERO_TIER_COSTS: Array[int] = [100, 300, 700]
const MONSTER_TIER_COSTS: Array[int] = [100, 500, 1000]


func _seed_hero_trees() -> void:
	_seed_character_tree(hero_tree_id(&"river"), "River — Scout's Edge",
		"River's personal upgrades. Bought with Steel.", PersistedData.STEEL, HERO_TIER_COSTS, [
		[&"r1_range", "Long Scope", "+8% Attack Range", 1, "attack_range", 1.08],
		[&"r1_speed", "Light Boots", "+5% Move Speed", 1, "move_speed", 1.05],
		[&"r1_hp", "Field Dressing", "+5% Max HP", 1, "max_health", 1.05],
		[&"r2_dmg", "Hollow Points", "+10% Attack Damage", 2, "attack_damage", 1.10],
		[&"r2_atkspd", "Quick Hands", "+10% Attack Speed", 2, "attack_speed", 1.10],
		[&"r3_range", "Sniper's Nest", "+15% Attack Range", 3, "attack_range", 1.15],
		[&"r3_hp", "Veteran Scout", "+15% Max HP", 3, "max_health", 1.15],
		[&"r2_dropcd", "Fast Resupply", "Supply Drop cooldown -20%", 2, "cooldown", 0.80, "Emergency Supply Drop"],
		[&"r3_dropheal", "Field Hospital", "Supply Drop heals +50%", 3, "heal_amount", 1.50, "Emergency Supply Drop"],
	])
	_seed_character_tree(hero_tree_id(&"vlad"), "Vlad — Blood Rites",
		"Vlad's personal upgrades. Bought with Steel.", PersistedData.STEEL, HERO_TIER_COSTS, [
		[&"v1_dmg", "Keen Blade", "+5% Attack Damage", 1, "attack_damage", 1.05],
		[&"v1_atkspd", "Eager Swings", "+5% Attack Speed", 1, "attack_speed", 1.05],
		[&"v1_hp", "Thick Blood", "+5% Max HP", 1, "max_health", 1.05],
		[&"v2_dmg", "Bloodthirst", "+10% Attack Damage", 2, "attack_damage", 1.10],
		[&"v2_hp", "Iron Heart", "+10% Max HP", 2, "max_health", 1.10],
		[&"v3_atkspd", "Frenzy", "+15% Attack Speed", 3, "attack_speed", 1.15],
		[&"v3_dmg", "Executioner", "+20% Attack Damage", 3, "attack_damage", 1.20],
		[&"v2_bombaoe", "Bigger Bomb", "Blood Bomb radius +25%", 2, "area_of_effect", 1.25, "Blood Bomb"],
		[&"v3_minecd", "Quick Mines", "Land Mine cooldown -25%", 3, "cooldown", 0.75, "Land Mine"],
	])
	_seed_character_tree(hero_tree_id(&"ted"), "Ted — Beast Bond",
		"Ted's personal upgrades. Bought with Steel.", PersistedData.STEEL, HERO_TIER_COSTS, [
		[&"t1_hp", "Trail Rations", "+5% Max HP", 1, "max_health", 1.05],
		[&"t1_speed", "Tracker's Pace", "+5% Move Speed", 1, "move_speed", 1.05],
		[&"t1_range", "Long Leash", "+5% Attack Range", 1, "attack_range", 1.05],
		[&"t2_dmg", "Sharpened Snares", "+10% Attack Damage", 2, "attack_damage", 1.10],
		[&"t2_atkspd", "Rapid Traps", "+10% Attack Speed", 2, "attack_speed", 1.10],
		[&"t3_hp", "Pack Leader", "+15% Max HP", 3, "max_health", 1.15],
		[&"t3_range", "Far Whistle", "+15% Attack Range", 3, "attack_range", 1.15],
		[&"t2_trapcd", "Fast Traps", "Trap Cage cooldown -20%", 2, "cooldown", 0.80, "Trap Cage"],
		[&"t3_trapdur", "Sturdy Cage", "Trap Cage lasts +50%", 3, "duration", 1.50, "Trap Cage"],
	])
	_seed_character_tree(hero_tree_id(&"irelia"), "Irelia — Shield Wall",
		"Irelia's personal upgrades. Bought with Steel.", PersistedData.STEEL, HERO_TIER_COSTS, [
		[&"i1_hp", "Reinforced Plate", "+8% Max HP", 1, "max_health", 1.08],
		[&"i1_dmg", "Shield Bash", "+5% Attack Damage", 1, "attack_damage", 1.05],
		[&"i1_speed", "Marching Order", "+5% Move Speed", 1, "move_speed", 1.05],
		[&"i2_hp", "Unbreakable", "+12% Max HP", 2, "max_health", 1.12],
		[&"i2_atkspd", "Riposte", "+10% Attack Speed", 2, "attack_speed", 1.10],
		[&"i3_hp", "Bulwark", "+20% Max HP", 3, "max_health", 1.20],
		[&"i3_dmg", "Vanguard", "+10% Attack Damage", 3, "attack_damage", 1.10],
		[&"i2_rallycd", "Rally Faster", "Rally Cry cooldown -20%", 2, "cooldown", 0.80, "Rally Cry"],
		[&"i3_dashcd", "Relentless", "Dash cooldown -30%", 3, "cooldown", 0.70, "Dash"],
	])


func _seed_monster_trees() -> void:
	# Keys mirror collect_monster_modifiers / MonsterBase._load_meta_modifiers.
	_seed_character_tree(monster_tree_id(&"grount"), "Grount — Alpha Bull",
		"Grount's personal upgrades. Bought with Leaves.", PersistedData.LEAVES, MONSTER_TIER_COSTS, [
		[&"g1_dmg", "Heavy Horns", "+10% Damage", 1, "monster_damage_mult", 1.10],
		[&"g1_speed", "Stampede", "+5% Move Speed", 1, "monster_speed_mult", 1.05],
		[&"g1_range", "Wide Sweep", "+10% Ability Range", 1, "monster_range_mult", 1.10],
		[&"g2_evo", "Ravenous", "-10% Stage XP requirements", 2, "monster_evo_threshold", 0.90],
		[&"g2_hp", "Scar Tissue", "+15% Max HP all stages", 2, "monster_health_mult", 1.15],
		[&"g3_dmg", "Titan's Wrath", "+20% Damage", 3, "monster_damage_mult", 1.20],
		[&"g3_speed", "Apex Charge", "+15% Move Speed", 3, "monster_speed_mult", 1.15],
		[&"g2_cleavecd", "Quick Cleave", "Front Cleave cooldown -15%", 2, "cooldown", 0.85, "Front Cleave"],
		[&"g3_dash", "Long Charge", "Ram Dash distance +33%", 3, "dash_distance", 1.33, "Ram Dash"],
		[&"g3_slam", "Wider Slam", "Ground Slam radius +20%", 3, "slam_radius", 1.20, "Ground Slam"],
	])


## specs: [id, name, description, tier, stat_name, multiplier] for a stat node,
## or [id, name, description, tier, property, multiplier, ability_name] for an
## ability node. The tier index picks the cost from `tier_costs`.
func _seed_character_tree(tree_id: StringName, display_name: String, description: String,
		currency: StringName, tier_costs: Array[int], specs: Array) -> void:
	var t: MetaSkillTree = MetaSkillTree.new()
	t.id = tree_id
	t.display_name = display_name
	t.description = description
	for spec in specs:
		var tier: int = int(spec[3])
		var cost: int = tier_costs[clampi(tier - 1, 0, tier_costs.size() - 1)]
		if spec.size() >= 7:
			t.nodes.append(MetaSkillNode.make_ability(StringName(spec[0]), String(spec[1]), String(spec[2]),
				tier, cost, currency, String(spec[6]), String(spec[4]), float(spec[5])))
		else:
			t.nodes.append(MetaSkillNode.make(StringName(spec[0]), String(spec[1]), String(spec[2]),
				tier, cost, currency, String(spec[4]), float(spec[5])))
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

## Called by HeroBase._ready. Stacks every unlocked node of the Hero Base
## tree AND of this hero's own tree (hero_<id>) onto its HeroStatsComponent.
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


## Called by MonsterBase._load_meta_modifiers with its own ability copies.
func apply_ability_nodes_to_monster(monster_id: StringName, abilities: Array[AbilityBase]) -> void:
	if monster_id == &"":
		return
	_apply_ability_nodes(monster_tree_id(monster_id), abilities)


func _apply_ability_nodes(tree_id: StringName, abilities: Array[AbilityBase]) -> void:
	var t: MetaSkillTree = get_tree_def(tree_id)
	if t == null:
		return
	var unlocked: Array = PersistedData.get_unlocked_skills(tree_id)
	for n in t.nodes:
		if not n.is_ability_node() or not unlocked.has(String(n.id)):
			continue
		for a in abilities:
			if a.ability_name == n.ability_name:
				a.apply_meta_modifier(n.stat_name, n.stat_value, n.stat_multiplicative)


func _apply_tree_to_stats(tree_id: StringName, stats: HeroStatsComponent) -> void:
	var t: MetaSkillTree = get_tree_def(tree_id)
	if t == null:
		return
	var unlocked: Array = PersistedData.get_unlocked_skills(tree_id)
	for n in t.nodes:
		if not unlocked.has(String(n.id)) or n.stat_name.is_empty() or n.is_ability_node():
			continue
		# HeroStatsComponent only knows about hero stats — skip monster keys.
		if n.stat_name.begins_with("monster_"):
			continue
		stats.add_stat_modifier(n.stat_name, n.stat_value, n.stat_multiplicative)


## Called by MonsterBase._load_meta_modifiers. Returns key -> multiplier for
## the Monster Base tree merged with the monster's own tree (monster_<id>)
## when an id is given. Missing keys mean 1.0.
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
	var unlocked: Array = PersistedData.get_unlocked_skills(tree_id)
	for n in t.nodes:
		if not unlocked.has(String(n.id)) or n.stat_name.is_empty() or n.is_ability_node():
			continue
		# Stack multiplicatively if the same key appears multiple times.
		out[n.stat_name] = float(out.get(n.stat_name, 1.0)) * n.stat_value
