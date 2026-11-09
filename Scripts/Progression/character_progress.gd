class_name CharacterProgress
extends RefCounted

## Permanent progression of one roster character as the menus show it: the
## collection card's "Lv.N", its pill (XP toward the next level, or a red
## "up N" when skill ranks are ready to buy), the padlock. Static helpers over
## PersistedData and MetaSkillManager; no state of its own, nothing written.
##
## The level comes from the character's permanent XP on the one curve
## PersistedData.level_progress() defines (100, 200, 300, ... XP per level),
## the same numbers the match result shows. Levels are not bought: XP alone
## raises them.
##
## The helpers take the CharacterDef (the roster entry), so a card built from
## GameManager.ROSTER and a def made in a test or a preview read one path.


## Permanent XP of the character (hero or monster save section).
static func xp(def: CharacterDef) -> int:
	if def == null:
		return 0
	if def.is_monster():
		return PersistedData.get_monster_xp(def.character_id())
	return PersistedData.get_hero_xp(def.character_id())


## {level, into, needed}: the level reached, the XP earned inside it and the
## XP the next level costs (PersistedData.level_progress).
static func progress(def: CharacterDef) -> Dictionary:
	return PersistedData.level_progress(xp(def))


static func level(def: CharacterDef) -> int:
	var lv: int = progress(def)["level"]
	return lv


## XP earned toward the next level (the pill's left number).
static func xp_into(def: CharacterDef) -> int:
	var into: int = progress(def)["into"]
	return into


## XP the next level costs (the pill's right number).
static func xp_needed(def: CharacterDef) -> int:
	var needed: int = progress(def)["needed"]
	return needed


## Skill ranks of the character's own tree the player can buy right now: the
## nodes MetaSkillManager reports AVAILABLE (owned below max, tier open,
## affordable). The card pill turns red with this number when it is above 0.
static func upgrades_ready(def: CharacterDef) -> int:
	if def == null or not is_unlocked(def):
		return 0
	var tree := def.skill_tree_def()
	if tree == null:
		return 0
	var n := 0
	for node in tree.nodes:
		if MetaSkillManager.node_state(tree.id, node.id) == MetaSkillManager.NodeState.AVAILABLE:
			n += 1
	return n


## Whether the player owns the character. Today every shipped character is
## unlocked_by_default; the bought set of locked monsters (Nyxa, Gorrak) joins
## here with their unlock flow.
static func is_unlocked(def: CharacterDef) -> bool:
	return def != null and def.unlocked_by_default
