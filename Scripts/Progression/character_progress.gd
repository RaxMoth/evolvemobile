class_name CharacterProgress
extends RefCounted

## Permanent progression of one roster character as the menus show it: the
## collection card's "Lv.N", its pill (XP toward the next level, or a red
## "up N" when skill ranks are ready to buy), the padlock and the unlock rule
## of a locked monster. Static helpers over PersistedData and MetaSkillManager
## with no state of their own; only unlock() (a purchase) writes the save.
##
## The level comes from the character's permanent XP on the one curve
## PersistedData.level_progress() defines (100, 200, 300, ... XP per level),
## the same numbers the match result shows. Levels are not bought: XP alone
## raises them.
##
## The helpers take the CharacterDef (the roster entry), so a card built from
## GameManager.ROSTER and a def made in a test or a preview read one path.
##
## Unlocks (Monster side): a def with unlocked_by_default (Grount) is owned from
## the start; a locked monster (Nyxa, Gorrak) is bought for its unlock_cost in
## its currency() once ANY owned character of its side has reached
## unlock_requires_level, and then joins PersistedData's [monsters] owned.

## Where a character stands on the way to owning it (unlock_state()).
##   OWNED: owned (by default or bought).
##   NOT_FOR_SALE: locked with no price (or a hero: only monsters are sold).
##   GATED: no owned character of its side has reached unlock_requires_level.
##   SHORT: the gate is met but the wallet is short of unlock_cost.
##   READY: unlock() buys it now.
enum UnlockState { OWNED, NOT_FOR_SALE, GATED, SHORT, READY }


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


## Whether the player owns the character: unlocked_by_default, or a monster
## the player bought (PersistedData [monsters] owned).
static func is_unlocked(def: CharacterDef) -> bool:
	if def == null:
		return false
	if def.unlocked_by_default:
		return true
	return def.is_monster() and PersistedData.owns_monster(def.character_id())


## Highest permanent level among the owned roster characters of `side`
## (CharacterDef.HEROES / MONSTER); 0 when the side owns nobody.
static func best_owned_level(side: int) -> int:
	var best := 0
	for d in GameManager.ROSTER.all():
		if d != null and d.side == side and is_unlocked(d):
			best = maxi(best, level(d))
	return best


## The unlock gate: an owned character of the def's side at
## unlock_requires_level (always met without a level gate).
static func unlock_gate_met(def: CharacterDef) -> bool:
	return def != null and (def.unlock_requires_level <= 0 or best_owned_level(def.side) >= def.unlock_requires_level)


static func unlock_state(def: CharacterDef) -> UnlockState:
	if def == null:
		return UnlockState.NOT_FOR_SALE
	if is_unlocked(def):
		return UnlockState.OWNED
	if not def.is_monster() or def.unlock_cost <= 0:
		return UnlockState.NOT_FOR_SALE
	if not unlock_gate_met(def):
		return UnlockState.GATED
	if not PersistedData.can_afford(def.currency(), def.unlock_cost):
		return UnlockState.SHORT
	return UnlockState.READY


## unlock() would buy it now (the card's red dot, the nav bar's Monsters dot).
static func can_unlock(def: CharacterDef) -> bool:
	return unlock_state(def) == UnlockState.READY


## The unlock rule, short (card and lobby caption): "Needs a Lv 3 monster";
## "" without a level gate (and for heroes, which are not sold).
static func unlock_rule_short(def: CharacterDef) -> String:
	if def == null or not def.is_monster() or def.unlock_requires_level <= 0:
		return ""
	return TranslationServer.translate("Needs a Lv %d monster") % def.unlock_requires_level


## The unlock rule as the confirm sheet states it: what is still missing
## ("Reach Lv 3 with any monster you own (best: Lv 1).") or that it is met;
## "" without a level gate (and for heroes).
static func unlock_rule(def: CharacterDef) -> String:
	if def == null or not def.is_monster() or def.unlock_requires_level <= 0:
		return ""
	var need := def.unlock_requires_level
	if unlock_gate_met(def):
		return TranslationServer.translate("A monster of yours has reached Lv %d.") % need
	return TranslationServer.translate("Reach Lv %d with any monster you own (best: Lv %d).") % [need, best_owned_level(def.side)]


## Buys a locked monster: spends unlock_cost of its currency(), adds it to
## PersistedData's [monsters] owned (monster_owned fires) and saves. Only from
## READY; anything else changes nothing and returns false.
static func unlock(def: CharacterDef) -> bool:
	if unlock_state(def) != UnlockState.READY:
		return false
	if not PersistedData.spend_currency(def.currency(), def.unlock_cost):
		return false
	PersistedData.add_owned_monster(def.character_id())
	PersistedData.save_data()
	return true
