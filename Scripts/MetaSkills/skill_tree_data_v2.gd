class_name SkillTreeDataV2
extends RefCounted

## Skill Trees v2 — the seed data tools/build_skill_trees.gd turned into the
## nine Data/SkillTrees/<tree_id>.tres (one MetaSkillTree each, its nodes as
## sub-resources). It was generated ONCE: the .tres files are the trees now.
## Edit them in the inspector (a later batch unhides a node there by clearing
## its `hidden`); this file stays as the record of the design's numbers, and the
## tool refuses to overwrite an existing tree without --force.
##
## Every tree has three BRANCHES (columns) and four TIERS (rows). Nodes have
## RANKS: `ranks` holds the CUMULATIVE effect value at rank 1..N (a
## multiplicative stat stores the full multiplier, an additive one the total
## delta) and becomes MetaSkillNode.rank_values; `cost` names a row of COSTS =
## the price of rank 1..N (rank_costs). Tier 4 of a character tree holds one
## CAPSTONE per branch; only the equipped one applies.
##
## Save compatibility: every node id of the v1 trees is kept, and its RANK 1
## has exactly the v1 effect (test_skill_trees_v2 checks it against a frozen
## copy of the v1 seeds), so an old save that owns an id simply owns rank 1.
## Four v1 nodes never did anything, because their ability name matched no
## ability of the hero: i2_rallycd ("Rally Cry", Ted's) and i3_dashcd ("Dash",
## none) are retargeted at Irelia's Divine Shield and Monster Taunt; t2_trapcd
## and t3_trapdur already named "Trap Cage", which ted_ultimate.tres called
## "TED ULt" until it was renamed.
##
## Node dictionary keys:
##   id, name, desc ("{v}" = this rank's value as the UI shows it), tier (1-4),
##   branch (0-2), ranks (Array[float], cumulative), cost (COSTS key),
##   kind: "stat" (character stat / monster key), "ability" (ability property),
##         "flag" (behaviour switch, additive 0 -> 1; a count export whose
##         default is 1, mine_count / pet_count, is multiplicative so the
##         value is the total: 1 x 3 = 3 mines),
##   stat (stat key or ability property), ability (AbilityBase.ability_name for
##   kind "ability"), mult (true = multiplier), requires (ANY of these ids at
##   rank >= 1; empty = only the tier gate), capstone (tier-4 exclusive),
##   new_code (what has to be written for it; "" = works with today's code),
##   hidden (= new_code is not empty: MetaSkillNode.hidden, the node is not
##   shown, bought or applied until the batch that writes its code unhides it).

const COSTS: Dictionary = {
	# Character trees (Steel for heroes, Leaves for monsters)
	"S5": [40, 60, 100, 150, 240],       # tier-1 stat, 5 ranks      = 590
	"T1x3": [50, 90, 150],               # tier-1 ability, 3 ranks   = 290
	"T1x1": [200],                       # tier-1 behaviour
	"T2x3": [120, 200, 330],             # tier-2, 3 ranks           = 650
	"T2x1": [450],                       # tier-2 behaviour
	"T3x3": [240, 400, 600],             # tier-3, 3 ranks           = 1240
	"T3x1": [750],                       # tier-3 behaviour
	"CAP": [1500],                       # tier-4 capstone
	# Shared base trees (Gold)
	"G1x3": [40, 70, 110],               # = 220
	"G2x3": [100, 160, 250],             # = 510
	"G3x2": [200, 320],                  # = 520
	"G4x1": [600],
	"G4x1b": [900],
}

## Character trees gate tiers on the character's PERMANENT level
## (PersistedData.level_from_xp of its hero/monster XP); base trees gate tiers
## on points (ranks) already spent in that tree.
const CHARACTER_TIER_LEVEL: Array[int] = [1, 3, 5, 8]
const BASE_TIER_POINTS: Array[int] = [0, 4, 10, 18]

const BRANCHES: Dictionary = {
	&"hero_base": ["Might", "Vitality", "Tactics"],
	&"monster_base": ["Ferocity", "Hide", "Instinct"],
	&"hero_river": ["Marksman", "Field Medic", "Scout"],
	&"hero_vlad": ["Butcher", "Blood", "Demolition"],
	&"hero_ted": ["Brawler", "Beastmaster", "Trapper"],
	&"hero_irelia": ["Bulwark", "Oathkeeper", "Vanguard"],
	&"monster_grount": ["Horns", "Hide", "Charge"],
	&"monster_nyxa": ["Hunger", "Shadow", "Brood"],
	&"monster_gorrak": ["Tusks", "Bristles", "Warband"],
}


## Name and blurb of each tree (MetaSkillTree.display_name / description); the
## seven v1 trees keep their v1 texts.
const TITLES: Dictionary = {
	&"hero_base": ["Hero Base Upgrades", "Bonuses applied to every hero on spawn. Bought with Gold."],
	&"monster_base": ["Monster Base Upgrades", "Bonuses applied to the monster on spawn. Bought with Gold."],
	&"hero_river": ["River — Scout's Edge", "River's personal upgrades. Bought with Steel."],
	&"hero_vlad": ["Vlad — Blood Rites", "Vlad's personal upgrades. Bought with Steel."],
	&"hero_ted": ["Ted — Beast Bond", "Ted's personal upgrades. Bought with Steel."],
	&"hero_irelia": ["Irelia — Shield Wall", "Irelia's personal upgrades. Bought with Steel."],
	&"monster_grount": ["Grount — Alpha Bull", "Grount's personal upgrades. Bought with Leaves."],
	&"monster_nyxa": ["Nyxa — Dusk Matriarch", "Nyxa's personal upgrades. Bought with Leaves."],
	&"monster_gorrak": ["Gorrak — Boar King", "Gorrak's personal upgrades. Bought with Leaves."],
}


static func _n(id: StringName, nm: String, desc: String, tier: int, branch: int, ranks: Array,
		cost: String, kind: String, stat: String, mult: bool = true, ability: String = "",
		requires: Array = [], capstone: bool = false, new_code: String = "") -> Dictionary:
	return {
		"id": id, "name": nm, "desc": desc, "tier": tier, "branch": branch, "ranks": ranks,
		"cost": cost, "kind": kind, "stat": stat, "mult": mult, "ability": ability,
		"requires": requires, "capstone": capstone, "new_code": new_code,
		"hidden": not new_code.is_empty(),
	}


static func trees() -> Dictionary:
	return {
		&"hero_base": hero_base(),
		&"monster_base": monster_base(),
		&"hero_river": river(),
		&"hero_vlad": vlad(),
		&"hero_ted": ted(),
		&"hero_irelia": irelia(),
		&"monster_grount": grount(),
		&"monster_nyxa": nyxa(),
		&"monster_gorrak": gorrak(),
	}


# ---------------------------------------------------------------- base trees

static func hero_base() -> Array:
	return [
		# Might
		_n(&"t1_dmg", "Sharp Edge", "+{v}% attack damage", 1, 0, [1.05, 1.08, 1.10], "G1x3", "stat", "attack_damage"),
		_n(&"t2_dmg", "Forged Steel", "+{v}% attack damage", 2, 0, [1.10, 1.13, 1.15], "G2x3", "stat", "attack_damage", true, "", [&"t1_dmg"]),
		_n(&"t3_atkspd", "Battle Rhythm", "+{v}% attack speed", 3, 0, [1.15, 1.20], "G3x2", "stat", "attack_speed", true, "", [&"t2_dmg"]),
		_n(&"t4_dmg", "Berserker", "+{v}% attack damage", 4, 0, [1.20], "G4x1", "stat", "attack_damage", true, "", [&"t3_atkspd"]),
		# Vitality
		_n(&"t1_hp", "Iron Skin", "+{v}% max HP", 1, 1, [1.05, 1.08, 1.10], "G1x3", "stat", "max_health"),
		_n(&"t2_hp", "Hardened", "+{v}% max HP", 2, 1, [1.10, 1.13, 1.15], "G2x3", "stat", "max_health", true, "", [&"t1_hp"]),
		_n(&"hb_armor", "Tempered Mail", "-{v}% damage taken", 2, 1, [0.96, 0.93, 0.90], "G2x3", "stat", "damage_taken_mult", true, "", [&"t1_hp"], false, "new hero stat key damage_taken_mult (HeroBase._receive_damage scales packet.amount)"),
		_n(&"t3_hp", "Veteran Plate", "+{v}% max HP", 3, 1, [1.15, 1.20], "G3x2", "stat", "max_health", true, "", [&"t2_hp", &"hb_armor"]),
		_n(&"t4_hp", "Titan", "+{v}% max HP", 4, 1, [1.25], "G4x1", "stat", "max_health", true, "", [&"t3_hp"]),
		# Tactics
		_n(&"t1_speed", "Light Step", "+{v}% move speed", 1, 2, [1.05, 1.07, 1.09], "G1x3", "stat", "move_speed"),
		_n(&"t2_atkspd", "Quick Strike", "+{v}% attack speed", 2, 2, [1.10, 1.13, 1.15], "G2x3", "stat", "attack_speed", true, "", [&"t1_speed"]),
		_n(&"t3_speed", "Swift Runner", "+{v}% move speed", 3, 2, [1.15, 1.18], "G3x2", "stat", "move_speed", true, "", [&"t2_atkspd"]),
		_n(&"hb_cdr", "Battle Drills", "-{v}% active & ultimate cooldowns", 3, 2, [0.92, 0.85], "G3x2", "stat", "cooldown_mult", true, "", [&"t2_atkspd"], false, "new hero stat key cooldown_mult (AbilitySystem scales active/ultimate cooldowns when it starts them)"),
		_n(&"t4_atkspd", "Storm Blades", "+{v}% attack speed", 4, 2, [1.25], "G4x1", "stat", "attack_speed", true, "", [&"t3_speed", &"hb_cdr"]),
		_n(&"hb_startlvl", "Veteran Squad", "Heroes start each match at level {v}", 4, 2, [2.0], "G4x1b", "stat", "start_level", false, "", [&"t3_speed", &"hb_cdr"], false, "new hero stat key start_level (HeroBase._ready levels the hero up after the tree is applied)"),
	]


static func monster_base() -> Array:
	return [
		# Ferocity
		_n(&"mb_claws", "Sharpened Claws", "+{v}% damage", 1, 0, [1.03, 1.05, 1.07], "G1x3", "stat", "monster_damage_mult"),
		_n(&"mt2_dmg", "Brutal Strikes", "+{v}% damage", 2, 0, [1.15, 1.18, 1.20], "G2x3", "stat", "monster_damage_mult", true, "", [&"mb_claws"]),
		_n(&"mt3_range", "Long Reach", "+{v}% ability range", 3, 0, [1.10, 1.15], "G3x2", "stat", "monster_range_mult", true, "", [&"mt2_dmg"]),
		_n(&"mb_apex", "Apex Predator", "+{v}% damage at Stage 3", 4, 0, [1.15], "G4x1", "stat", "monster_s3_damage_mult", true, "", [&"mt3_range"], false, "new monster key monster_s3_damage_mult (MonsterBase.effective_ability_damage at stage 3)"),
		# Hide
		_n(&"mt1_hp", "Thicker Hide", "+{v}% max HP (all stages)", 1, 1, [1.10, 1.13, 1.15], "G1x3", "stat", "monster_health_mult"),
		_n(&"mb_bark", "Scarred Hide", "-{v}% damage taken", 2, 1, [0.96, 0.93, 0.90], "G2x3", "stat", "monster_damage_taken_mult", true, "", [&"mt1_hp"], false, "new monster key monster_damage_taken_mult (MonsterBase._receive_damage)"),
		_n(&"mt3_hp", "Apex Body", "+{v}% max HP", 3, 1, [1.20, 1.25], "G3x2", "stat", "monster_health_mult", true, "", [&"mb_bark"]),
		_n(&"mb_regen", "Primal Regeneration", "Resting regenerates {v}x as fast", 4, 1, [2.0], "G4x1", "stat", "monster_regen_mult", true, "", [&"mt3_hp"], false, "new monster key monster_regen_mult (MonsterBase._update_rest)"),
		# Instinct
		_n(&"mt1_speed", "Faster Hunt", "+{v}% move speed", 1, 2, [1.05, 1.07, 1.09], "G1x3", "stat", "monster_speed_mult"),
		_n(&"mt1_xp", "Bloodhound", "+{v}% XP from kills", 1, 2, [1.10, 1.15, 1.20], "G1x3", "stat", "monster_xp_mult"),
		_n(&"mt2_evo", "Quick Evolution", "-{v}% stage XP requirements", 2, 2, [0.90, 0.87, 0.85], "G2x3", "stat", "monster_evo_threshold", true, "", [&"mt1_speed", &"mt1_xp"]),
		_n(&"mb_cdr", "Primal Rhythm", "-{v}% ability cooldowns", 3, 2, [0.95, 0.90], "G3x2", "stat", "monster_cooldown_mult", true, "", [&"mt2_evo"], false, "new monster key monster_cooldown_mult (MonsterBase._cast)"),
		_n(&"mb_headstart", "Head Start", "Start each match with {v} XP", 4, 2, [60.0], "G4x1b", "stat", "monster_start_xp", false, "", [&"mb_cdr"], false, "new monster key monster_start_xp (MonsterBase._ready, unscaled by the XP node)"),
	]


# ---------------------------------------------------------------- heroes

static func river() -> Array:
	var aw := "Adaptive Weapon"
	var drop := "Emergency Supply Drop"
	return [
		# Marksman
		_n(&"r1_range", "Long Scope", "+{v}% attack range", 1, 0, [1.08, 1.11, 1.14, 1.17, 1.20], "S5", "stat", "attack_range"),
		_n(&"r2_dmg", "Hollow Points", "+{v}% attack damage", 2, 0, [1.10, 1.15, 1.20], "T2x3", "stat", "attack_damage", true, "", [&"r1_range"]),
		_n(&"r2_triple", "Triple Shot", "Sniper shots also hit {v} enemies near the target", 2, 0, [2.0], "T2x1", "flag", "extra_targets", false, aw, [&"r1_range"]),
		_n(&"r3_range", "Sniper's Nest", "+{v}% attack range", 3, 0, [1.15, 1.20, 1.25], "T3x3", "stat", "attack_range", true, "", [&"r2_dmg", &"r2_triple"]),
		_n(&"rv_deadeye", "Deadeye", "Every {v}th sniper shot deals 2.5x damage", 4, 0, [4.0], "CAP", "flag", "crit_every", false, aw, [&"r3_range"], true, "RiverBasicAttack: crit_every (int, 0 = off) + crit_mult 2.5 export, shot counter per instance"),
		# Field Medic
		_n(&"r1_hp", "Field Dressing", "+{v}% max HP", 1, 1, [1.05, 1.08, 1.11, 1.14, 1.17], "S5", "stat", "max_health"),
		_n(&"r2_dropcd", "Fast Resupply", "Supply Drop cooldown -{v}%", 2, 1, [0.80, 0.72, 0.65], "T2x3", "ability", "cooldown", true, drop, [&"r1_hp"]),
		_n(&"rv_heal", "Steady Hands", "+{v}% heal per staff shot", 2, 1, [1.15, 1.30, 1.45], "T2x3", "ability", "heal_amount", true, aw, [&"r1_hp"]),
		_n(&"r3_dropheal", "Field Hospital", "Supply Drop heals +{v}%", 3, 1, [1.50, 1.75, 2.00], "T3x3", "ability", "heal_amount", true, drop, [&"r2_dropcd"]),
		_n(&"r3_hp", "Veteran Scout", "+{v}% max HP", 3, 1, [1.15, 1.20, 1.25], "T3x3", "stat", "max_health", true, "", [&"rv_heal", &"r2_dropcd"]),
		_n(&"rv_chain", "Chain Heal", "Staff heals also heal the most hurt ally within 160 px of the target", 4, 1, [1.0], "CAP", "flag", "extra_heal_targets", false, aw, [&"r3_dropheal", &"r3_hp"], true, "RiverBasicAttack: extra_heal_targets (int) export, same search as Triple Shot over allies"),
		# Scout
		_n(&"r1_speed", "Light Boots", "+{v}% move speed", 1, 2, [1.05, 1.07, 1.09, 1.11, 1.13], "S5", "stat", "move_speed"),
		_n(&"r2_atkspd", "Quick Hands", "+{v}% attack speed", 2, 2, [1.10, 1.14, 1.18], "T2x3", "stat", "attack_speed", true, "", [&"r1_speed"]),
		_n(&"rv_adrenal", "Adrenaline", "Adaptive Movement boost lasts +{v}%", 3, 2, [1.5, 1.8, 2.1], "T3x3", "ability", "boost_duration", true, "Adaptive Movement", [&"r2_atkspd"]),
		_n(&"rv_pathfinder", "Pathfinder", "While River lives, every hero moves +12% faster", 4, 2, [1.12], "CAP", "flag", "team_speed_aura", true, "Adaptive Movement", [&"rv_adrenal"], true, "RiverPassiveAdaptive: team_speed_aura export written to TeamBlackboard each passive tick; HeroBase._get_move_speed reads it"),
	]


static func vlad() -> Array:
	return [
		# Butcher
		_n(&"v1_dmg", "Keen Blade", "+{v}% attack damage", 1, 0, [1.05, 1.08, 1.11, 1.14, 1.17], "S5", "stat", "attack_damage"),
		_n(&"v1_atkspd", "Eager Swings", "+{v}% attack speed", 1, 0, [1.05, 1.08, 1.11], "T1x3", "stat", "attack_speed"),
		_n(&"v2_dmg", "Bloodthirst", "+{v}% attack damage", 2, 0, [1.10, 1.14, 1.18], "T2x3", "stat", "attack_damage", true, "", [&"v1_dmg", &"v1_atkspd"]),
		_n(&"v3_dmg", "Executioner", "+{v}% attack damage", 3, 0, [1.20, 1.25, 1.30], "T3x3", "stat", "attack_damage", true, "", [&"v2_dmg"]),
		_n(&"vl_execute", "Executioner's Mark", "Blood Strike deals 2x damage to targets below 25% HP", 4, 0, [0.25], "CAP", "flag", "execute_threshold", false, "Blood Strike", [&"v3_dmg"], true, "BasicStrike (shared with Ted's Claw Swipe; only Vlad's .tres sets it): execute_threshold (0 = off) + execute_mult 2.0 exports, read the target's health ratio before dealing"),
		# Blood
		_n(&"v1_hp", "Thick Blood", "+{v}% max HP", 1, 1, [1.05, 1.08, 1.11, 1.14, 1.17], "S5", "stat", "max_health"),
		_n(&"v2_hp", "Iron Heart", "+{v}% max HP", 2, 1, [1.10, 1.14, 1.18], "T2x3", "stat", "max_health", true, "", [&"v1_hp"]),
		_n(&"vl_lust", "Deeper Thirst", "Bloodlust kicks in {v}% HP sooner (base: below 30%)", 2, 1, [0.05, 0.10, 0.15], "T2x3", "ability", "health_threshold", false, "Bloodlust", [&"v1_hp"]),
		_n(&"v3_atkspd", "Frenzy", "+{v}% attack speed", 3, 1, [1.15, 1.20, 1.25], "T3x3", "stat", "attack_speed", true, "", [&"v2_hp", &"vl_lust"]),
		_n(&"vl_leech", "Sanguine Feast", "Blood Strike heals Vlad for {v}% of its damage", 4, 1, [0.20], "CAP", "flag", "lifesteal_pct", false, "Blood Strike", [&"v3_atkspd"], true, "AbilityBase.lifesteal_pct + deal() (shared with the monster kits, prototype done); BasicStrike.execute calls deal() instead of EventBus.deal_damage and HeroBase gets heal_self()"),
		# Demolition
		_n(&"vl_minedmg", "Black Powder", "Land Mine damage +{v}%", 1, 2, [1.20, 1.40, 1.60], "T1x3", "ability", "damage", true, "Land Mine"),
		_n(&"v2_bombaoe", "Bigger Bomb", "Blood Bomb radius +{v}%", 2, 2, [1.25, 1.35, 1.45], "T2x3", "ability", "area_of_effect", true, "Blood Bomb", [&"vl_minedmg"]),
		_n(&"v3_minecd", "Quick Mines", "Land Mine cooldown -{v}%", 3, 2, [0.75, 0.65, 0.55], "T3x3", "ability", "cooldown", true, "Land Mine", [&"v2_bombaoe"]),
		_n(&"vl_cluster", "Cluster Mines", "Land Mine places {v} mines in a triangle", 4, 2, [3.0], "CAP", "flag", "mine_count", true, "Land Mine", [&"v3_minecd"], true, "VladActiveMine: mine_count export (1), mines 40 px apart"),
	]


static func ted() -> Array:
	var cage := "Trap Cage"
	var pet := "Loyal Companion"
	return [
		# Brawler
		_n(&"t1_hp", "Trail Rations", "+{v}% max HP", 1, 0, [1.05, 1.08, 1.11, 1.14, 1.17], "S5", "stat", "max_health"),
		_n(&"t2_dmg", "Sharpened Snares", "+{v}% attack damage", 2, 0, [1.10, 1.14, 1.18], "T2x3", "stat", "attack_damage", true, "", [&"t1_hp"]),
		_n(&"t2_atkspd", "Rapid Traps", "+{v}% attack speed", 2, 0, [1.10, 1.14, 1.18], "T2x3", "stat", "attack_speed", true, "", [&"t1_hp"]),
		_n(&"t3_hp", "Pack Leader", "+{v}% max HP", 3, 0, [1.15, 1.20, 1.25], "T3x3", "stat", "max_health", true, "", [&"t2_dmg", &"t2_atkspd"]),
		_n(&"td_warcry", "War Cry", "Rally Cry also hastes every hero within 300 px", 4, 0, [300.0], "CAP", "flag", "aura_radius", false, "Rally Cry", [&"t3_hp"], true, "TedActiveRally: aura_radius export (0 = Ted only)"),
		# Beastmaster
		_n(&"td_petvit", "Loyal Bond", "Pet max HP +{v}%", 1, 1, [1.20, 1.40, 1.60], "T1x3", "ability", "pet_health_mult", true, pet, [], false, "TedPassivePet: pet_health_mult export applied to the spawned pet"),
		_n(&"td_petdmg", "Sharp Fangs", "Pet damage +{v}%", 2, 1, [1.20, 1.40, 1.60], "T2x3", "ability", "pet_damage_mult", true, pet, [&"td_petvit"], false, "TedPassivePet: pet_damage_mult export applied to the spawned pet"),
		_n(&"td_respawn", "Never Alone", "Pet respawns {v}% faster", 3, 1, [0.70, 0.50, 0.35], "T3x3", "ability", "respawn_time", true, pet, [&"td_petdmg"], false, "TedPassivePet: RESPAWN_TIME const -> respawn_time export"),
		_n(&"td_twin", "Pack of Two", "Ted keeps {v} pets", 4, 1, [2.0], "CAP", "flag", "pet_count", false, pet, [&"td_respawn"], true, "TedPassivePet: pet_count export, pets in an array (one respawn timer each)"),
		# Trapper
		_n(&"t1_range", "Long Leash", "+{v}% attack range", 1, 2, [1.05, 1.08, 1.11, 1.14, 1.17], "S5", "stat", "attack_range"),
		_n(&"t1_speed", "Tracker's Pace", "+{v}% move speed", 1, 2, [1.05, 1.07, 1.09], "T1x3", "stat", "move_speed"),
		_n(&"t2_trapcd", "Fast Traps", "Trap Cage cooldown -{v}%", 2, 2, [0.80, 0.72, 0.65], "T2x3", "ability", "cooldown", true, cage, [&"t1_range", &"t1_speed"]),
		_n(&"t3_trapdur", "Sturdy Cage", "Trap Cage lasts +{v}%", 3, 2, [1.50, 1.75, 2.00], "T3x3", "ability", "duration", true, cage, [&"t2_trapcd"]),
		_n(&"t3_range", "Far Whistle", "+{v}% attack range", 3, 2, [1.15, 1.20, 1.25], "T3x3", "stat", "attack_range", true, "", [&"t2_trapcd"]),
		_n(&"td_spikes", "Spiked Cage", "Enemies inside the cage take {v} damage per second", 4, 2, [6.0], "CAP", "flag", "cage_dps", false, cage, [&"t3_trapdur", &"t3_range"], true, "TedUltimateTrapCage: cage_dps export passed to TrapCage, 1 Hz overlap tick"),
	]


static func irelia() -> Array:
	return [
		# Bulwark
		_n(&"i1_hp", "Reinforced Plate", "+{v}% max HP", 1, 0, [1.08, 1.11, 1.14, 1.17, 1.20], "S5", "stat", "max_health"),
		_n(&"i2_hp", "Unbreakable", "+{v}% max HP", 2, 0, [1.12, 1.16, 1.20], "T2x3", "stat", "max_health", true, "", [&"i1_hp"]),
		_n(&"ir_armor", "Plated", "-{v}% damage taken", 2, 0, [0.95, 0.91, 0.88], "T2x3", "stat", "damage_taken_mult", true, "", [&"i1_hp"], false, "hero stat key damage_taken_mult (shared with hb_armor)"),
		_n(&"i3_hp", "Bulwark", "+{v}% max HP", 3, 0, [1.20, 1.25, 1.30], "T3x3", "stat", "max_health", true, "", [&"i2_hp", &"ir_armor"]),
		_n(&"ir_laststand", "Last Stand", "Once per match a lethal hit leaves Irelia at 1 HP, invulnerable for 2 s", 4, 0, [1.0], "CAP", "flag", "last_stand", false, "Regeneration", [&"i3_hp"], true, "IreliaPassiveRegeneration: last_stand flag; HeroBase._receive_damage asks the passive before dying"),
		# Oathkeeper
		_n(&"ir_regen", "Second Breath", "Regeneration heals {v}x as much", 1, 1, [1.5, 2.0, 2.5], "T1x3", "ability", "heal_amount", true, "Regeneration"),
		_n(&"i2_rallycd", "Shield Cadence", "Divine Shield cooldown -{v}%", 2, 1, [0.80, 0.72, 0.65], "T2x3", "ability", "cooldown", true, "Divine Shield", [&"ir_regen"]),
		_n(&"ir_aegis", "Aegis", "Divine Shield absorbs +{v}%", 3, 1, [1.30, 1.60, 1.90], "T3x3", "ability", "heal_amount", true, "Divine Shield", [&"i2_rallycd"]),
		_n(&"ir_guardian", "Guardian Angel", "Divine Shield also breaks every stun on the shielded heroes", 4, 1, [1.0], "CAP", "flag", "cleanse_stuns", false, "Divine Shield", [&"ir_aegis"], true, "IreliaActiveShield: cleanse_stuns flag -> EntityBase.clear_stun() on each shielded hero"),
		# Vanguard
		_n(&"i1_dmg", "Shield Bash", "+{v}% attack damage", 1, 2, [1.05, 1.08, 1.11, 1.14, 1.17], "S5", "stat", "attack_damage"),
		_n(&"i1_speed", "Marching Order", "+{v}% move speed", 1, 2, [1.05, 1.07, 1.09], "T1x3", "stat", "move_speed"),
		_n(&"i2_atkspd", "Riposte", "+{v}% attack speed", 2, 2, [1.10, 1.14, 1.18], "T2x3", "stat", "attack_speed", true, "", [&"i1_dmg", &"i1_speed"]),
		_n(&"i3_dmg", "Vanguard", "+{v}% attack damage", 3, 2, [1.10, 1.15, 1.20], "T3x3", "stat", "attack_damage", true, "", [&"i2_atkspd"]),
		_n(&"i3_dashcd", "Relentless", "Monster Taunt cooldown -{v}%", 3, 2, [0.70, 0.62, 0.55], "T3x3", "ability", "cooldown", true, "Monster Taunt", [&"i2_atkspd"]),
		_n(&"ir_banner", "Rallying Taunt", "Monster Taunt gives heroes within 250 px +25% attack speed while it lasts", 4, 2, [250.0], "CAP", "flag", "rally_radius", false, "Monster Taunt", [&"i3_dmg", &"i3_dashcd"], true, "IreliaUltimateTaunt: rally_radius export, reuses Rally Cry's attack-speed buff"),
	]


# ---------------------------------------------------------------- monsters

static func grount() -> Array:
	return [
		# Horns
		_n(&"g1_dmg", "Heavy Horns", "+{v}% damage", 1, 0, [1.10, 1.14, 1.17, 1.20, 1.22], "S5", "stat", "monster_damage_mult"),
		_n(&"g1_range", "Wide Sweep", "+{v}% ability range", 1, 0, [1.10, 1.14, 1.18], "T1x3", "stat", "monster_range_mult"),
		_n(&"g2_cleavecd", "Quick Cleave", "Front Cleave cooldown -{v}%", 2, 0, [0.85, 0.80, 0.75], "T2x3", "ability", "cooldown", true, "Front Cleave", [&"g1_dmg", &"g1_range"]),
		_n(&"g3_dmg", "Titan's Wrath", "+{v}% damage", 3, 0, [1.20, 1.25, 1.30], "T3x3", "stat", "monster_damage_mult", true, "", [&"g2_cleavecd"]),
		_n(&"g3_enrage", "Enrage", "Below 20% HP: +30% speed, +50% damage", 3, 0, [1.0], "T3x1", "flag", "monster_enrage", false, "", [&"g2_cleavecd"]),
		_n(&"g4_rampage", "Rampage", "Killing a hero resets every cooldown and heals 15% max HP", 4, 0, [1.0], "CAP", "flag", "monster_rampage", false, "", [&"g3_dmg", &"g3_enrage"], true, "MonsterBase: monster_rampage key; EventBus.entity_died with killer == self and a HeroBase victim -> zero ability_cooldowns, heal_self(15%)"),
		# Hide
		_n(&"g1_hide", "Thick Hide", "-{v}% damage taken", 1, 1, [0.97, 0.95, 0.93, 0.91, 0.90], "S5", "stat", "monster_damage_taken_mult", true, "", [], false, "monster key monster_damage_taken_mult (shared with mb_bark)"),
		_n(&"g2_hp", "Scar Tissue", "+{v}% max HP all stages", 2, 1, [1.15, 1.20, 1.25], "T2x3", "stat", "monster_health_mult", true, "", [&"g1_hide"]),
		_n(&"g2_earlyslam", "Early Slam", "Ground Slam unlocks at Stage 1", 2, 1, [-1.0], "T2x1", "flag", "unlock_stage", false, "Ground Slam", [&"g1_hide"]),
		_n(&"g3_slam", "Wider Slam", "Ground Slam radius +{v}%", 3, 1, [1.20, 1.30, 1.40], "T3x3", "ability", "slam_radius", true, "Ground Slam", [&"g2_hp", &"g2_earlyslam"]),
		_n(&"g3_pull", "Gravity Slam", "Ground Slam pulls enemies within {v} px to the impact", 3, 1, [200.0], "T3x1", "flag", "pull_radius", false, "Ground Slam", [&"g2_earlyslam"]),
		_n(&"g4_titan", "Titan Form", "Stage 3: +50% size, +500 HP, +20 range", 4, 1, [1.0], "CAP", "flag", "monster_titan_form", false, "", [&"g3_slam", &"g3_pull", &"g2_hp"], true),
		# Charge
		_n(&"g1_speed", "Stampede", "+{v}% move speed", 1, 2, [1.05, 1.07, 1.09, 1.11, 1.13], "S5", "stat", "monster_speed_mult"),
		_n(&"g1_stun", "Stunning Charge", "Ram Dash stuns for {v} s", 1, 2, [0.5], "T1x1", "flag", "stun_duration", false, "Ram Dash"),
		_n(&"g2_evo", "Ravenous", "-{v}% stage XP requirements", 2, 2, [0.90, 0.87, 0.85], "T2x3", "stat", "monster_evo_threshold", true, "", [&"g1_speed"]),
		_n(&"g3_dash", "Long Charge", "Ram Dash distance +{v}%", 3, 2, [1.33, 1.45, 1.55], "T3x3", "ability", "dash_distance", true, "Ram Dash", [&"g1_stun", &"g2_evo"]),
		_n(&"g3_speed", "Apex Charge", "+{v}% move speed", 3, 2, [1.15, 1.18, 1.21], "T3x3", "stat", "monster_speed_mult", true, "", [&"g2_evo"]),
		_n(&"g4_stampede", "Trample", "Ram Dash hits a 70 px wide lane and recharges twice as fast at Stage 3", 4, 2, [1.0], "CAP", "flag", "trample", false, "Ram Dash", [&"g3_dash", &"g3_speed"], true, "BullRamDash: trample flag -> hit radius 70 (DASH_HIT_RADIUS const -> export) and cooldown x0.5 at stage 3"),
	]


static func nyxa() -> Array:
	return [
		# Hunger
		_n(&"ny_hp", "Dusk Hide", "+{v}% max HP all stages", 1, 0, [1.05, 1.08, 1.11, 1.14, 1.17], "S5", "stat", "monster_health_mult"),
		_n(&"ny_leech", "Thirst", "Sonic Screech lifesteal +{v}%", 2, 0, [0.10, 0.15, 0.20], "T2x3", "ability", "lifesteal_pct", false, "Sonic Screech", [&"ny_hp"]),
		_n(&"ny_regen", "Night Recovery", "Resting regenerates {v}x as fast", 3, 0, [1.5, 2.0, 2.5], "T3x3", "stat", "monster_regen_mult", true, "", [&"ny_leech"], false, "monster key monster_regen_mult (shared with mb_regen)"),
		_n(&"ny_rebirth", "Vampiric Rebirth", "Once per match: at 0 HP she scatters into bats for 3 s and returns with 30% HP", 4, 0, [1.0], "CAP", "flag", "monster_rebirth", false, "", [&"ny_regen"], true, "MonsterBase: monster_rebirth key; _receive_damage intercepts the lethal hit, untargetable 3 s (Body layer off, idle flee), then 30% HP 400 px from the heroes"),
		# Shadow
		_n(&"ny_speed", "Silent Wings", "+{v}% move speed", 1, 1, [1.04, 1.07, 1.10, 1.12, 1.14], "S5", "stat", "monster_speed_mult"),
		_n(&"ny_swoopcd", "Swift Hunter", "Shadow Swoop cooldown -{v}%", 2, 1, [0.85, 0.77, 0.70], "T2x3", "ability", "cooldown", true, "Shadow Swoop", [&"ny_speed"]),
		_n(&"ny_swoopstun", "Disorienting Dive", "Shadow Swoop stuns for {v} s", 2, 1, [0.4], "T2x1", "flag", "stun_duration", false, "Shadow Swoop", [&"ny_speed"]),
		_n(&"ny_evo", "Fast Maturity", "-{v}% stage XP requirements", 3, 1, [0.92, 0.88, 0.85], "T3x3", "stat", "monster_evo_threshold", true, "", [&"ny_swoopcd", &"ny_swoopstun"]),
		_n(&"ny_echo", "Echo Strike", "Shadow Swoop turns and passes through its target a second time", 4, 1, [1.0], "CAP", "flag", "double_pass", false, "Shadow Swoop", [&"ny_evo"], true, "BullRamDash: double_pass flag -> on arrival a second dash back along the lane (hit list cleared)"),
		# Brood
		_n(&"ny_dmg", "Piercing Shriek", "+{v}% damage", 1, 2, [1.04, 1.07, 1.10, 1.13, 1.15], "S5", "stat", "monster_damage_mult"),
		_n(&"ny_cone", "Wide Shriek", "Sonic Screech cone +{v} degrees", 2, 2, [8.0, 14.0, 20.0], "T2x3", "ability", "cone_angle", false, "Sonic Screech", [&"ny_dmg"], false, "BullFrontCleave.apply_stage_stats keeps cone_angle modifiers (_modified) — prototype done"),
		_n(&"ny_swarm", "Thicker Swarm", "Night Swarm radius +{v}%", 3, 2, [1.15, 1.25, 1.35], "T3x3", "ability", "area_of_effect", true, "Night Swarm", [&"ny_cone"]),
		_n(&"ny_swarmdur", "Endless Night", "Night Swarm lasts +{v}%", 3, 2, [1.3, 1.5, 1.7], "T3x3", "ability", "duration", true, "Night Swarm", [&"ny_cone"]),
		_n(&"ny_brood", "Brood Mother", "At Stage 3 the Night Swarm never ends", 4, 2, [3.0], "CAP", "flag", "permanent_from_stage", false, "Night Swarm", [&"ny_swarm", &"ny_swarmdur"], true, "NightSwarm: permanent_from_stage export (0 = off); tick_active keeps biting while the caster's stage >= it"),
	]


static func gorrak() -> Array:
	var chop := "Cleaver Chop"
	var axe := "Tusk Axe"
	var stomp := "Warcry Stomp"
	return [
		# Tusks (offense)
		_n(&"gk_dmg", "Heavy Cleaver", "+{v}% damage", 1, 0, [1.05, 1.08, 1.11, 1.14, 1.17], "S5", "stat", "monster_damage_mult"),
		_n(&"gk_arc", "Wide Arc", "Cleaver Chop cone +{v} degrees", 2, 0, [10.0, 18.0, 25.0], "T2x3", "ability", "cone_angle", false, chop, [&"gk_dmg"]),
		_n(&"gk_axedmg", "Honed Tusks", "Tusk Axe damage +{v}%", 3, 0, [1.20, 1.35, 1.50], "T3x3", "ability", "damage", true, axe, [&"gk_arc"]),
		_n(&"gk_axestun", "Concussive Axe", "Tusk Axe stuns for {v} s", 3, 0, [0.5], "T3x1", "flag", "stun_duration", false, axe, [&"gk_arc"]),
		_n(&"gk_whirl", "Whirlwind", "From Stage 3 Cleaver Chop hits all around him", 4, 0, [3.0], "CAP", "flag", "full_circle_from_stage", false, chop, [&"gk_axedmg", &"gk_axestun"], true, "BullFrontCleave: full_circle_from_stage export (0 = off) skips the cone test"),
		# Bristles (defense)
		_n(&"gk_hp", "Thick Bristles", "+{v}% max HP all stages", 1, 1, [1.05, 1.08, 1.11, 1.14, 1.17], "S5", "stat", "monster_health_mult"),
		_n(&"gk_bark", "Mud Armour", "-{v}% damage taken", 2, 1, [0.95, 0.92, 0.89], "T2x3", "stat", "monster_damage_taken_mult", true, "", [&"gk_hp"], false, "monster key monster_damage_taken_mult (shared with mb_bark)"),
		_n(&"gk_regen", "Mud Bath", "Resting regenerates {v}x as fast", 3, 1, [1.5, 2.0, 2.5], "T3x3", "stat", "monster_regen_mult", true, "", [&"gk_bark"], false, "monster key monster_regen_mult (shared with mb_regen)"),
		_n(&"gk_unstoppable", "Unstoppable", "Immune to Irelia's taunt and Ted's Trap Cage", 4, 1, [1.0], "CAP", "flag", "monster_cc_immune", false, "", [&"gk_regen"], true, "MonsterBase.is_cc_immune(); IreliaUltimateTaunt and TrapCage skip such a target"),
		# Warband (utility)
		_n(&"gk_speed", "Long March", "+{v}% move speed", 1, 2, [1.04, 1.07, 1.10, 1.12, 1.14], "S5", "stat", "monster_speed_mult"),
		_n(&"gk_stomp", "Earthshaker", "Warcry Stomp radius +{v}%", 2, 2, [1.15, 1.25, 1.35], "T2x3", "ability", "slam_radius", true, stomp, [&"gk_speed"]),
		_n(&"gk_stompstun", "Ringing Ears", "Warcry Stomp stuns +{v} s longer", 2, 2, [0.25, 0.5, 0.75], "T2x3", "ability", "stun_duration", false, stomp, [&"gk_speed"]),
		_n(&"gk_evo", "King's Hunger", "-{v}% stage XP requirements", 3, 2, [0.92, 0.88, 0.85], "T3x3", "stat", "monster_evo_threshold", true, "", [&"gk_stomp", &"gk_stompstun"]),
		_n(&"gk_warband", "Call of the Herd", "Warcry Stomp turns the Hogs within 250 px into his warband for 20 s", 4, 2, [250.0], "CAP", "flag", "recruit_radius", false, stomp, [&"gk_evo"], true, "MobBase.ally_monster (faction override for 20 s): skips the monster as a target, targets heroes, GameUtils.can_entity_target honours it; BullGroundSlam: recruit_radius export"),
	]


## Which ranks an AI-controlled side buys, in order, at each Threat level
## (README "Opponent Threat"): threat N gives the first N*per_level entries.
## An entry is a node id (one more rank of it). Capstones come last.
const AI_BUILD_PER_THREAT: int = 3
const AI_BUILD_BASE_PER_THREAT: int = 2

static func ai_build_order() -> Dictionary:
	return {
		&"hero_base": [&"t1_hp", &"t1_dmg", &"t1_speed", &"t1_hp", &"t1_dmg", &"t2_hp", &"t2_dmg", &"hb_armor", &"t2_atkspd", &"t2_hp", &"t2_dmg", &"t3_hp", &"t3_atkspd", &"t3_speed", &"hb_cdr", &"t4_hp", &"t4_dmg", &"t4_atkspd"],
		&"monster_base": [&"mt1_hp", &"mb_claws", &"mt1_xp", &"mt1_hp", &"mb_claws", &"mt2_dmg", &"mb_bark", &"mt2_evo", &"mt2_dmg", &"mt3_hp", &"mt3_range", &"mb_cdr", &"mb_regen", &"mb_apex"],
		&"hero_river": [&"r1_range", &"r1_hp", &"r1_range", &"r2_dmg", &"rv_heal", &"r2_triple", &"r1_hp", &"r2_dropcd", &"r3_range", &"r3_dropheal", &"r3_hp", &"rv_deadeye"],
		&"hero_vlad": [&"v1_dmg", &"v1_hp", &"v1_dmg", &"v2_dmg", &"v2_hp", &"vl_lust", &"v1_hp", &"v3_dmg", &"v3_atkspd", &"vl_minedmg", &"v2_bombaoe", &"vl_leech"],
		&"hero_ted": [&"t1_hp", &"td_petvit", &"t1_hp", &"t2_dmg", &"td_petdmg", &"t2_atkspd", &"t1_range", &"t2_trapcd", &"t3_hp", &"td_respawn", &"t3_trapdur", &"td_twin"],
		&"hero_irelia": [&"i1_hp", &"ir_regen", &"i1_hp", &"i2_hp", &"ir_armor", &"i2_rallycd", &"i1_dmg", &"i3_hp", &"ir_aegis", &"i2_atkspd", &"i3_dashcd", &"ir_guardian"],
		&"monster_grount": [&"g1_dmg", &"g1_hide", &"g1_speed", &"g1_dmg", &"g2_hp", &"g2_evo", &"g1_stun", &"g2_cleavecd", &"g3_dmg", &"g3_slam", &"g3_dash", &"g4_titan"],
		&"monster_nyxa": [&"ny_hp", &"ny_dmg", &"ny_speed", &"ny_hp", &"ny_leech", &"ny_swoopcd", &"ny_cone", &"ny_evo", &"ny_swarm", &"ny_regen", &"ny_swarmdur", &"ny_brood"],
		&"monster_gorrak": [&"gk_hp", &"gk_dmg", &"gk_hp", &"gk_bark", &"gk_arc", &"gk_stompstun", &"gk_speed", &"gk_regen", &"gk_axedmg", &"gk_stomp", &"gk_evo", &"gk_unstoppable"],
	}
