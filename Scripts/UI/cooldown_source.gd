class_name CooldownSource
extends RefCounted

## Read-only view of one entity's ability slots for the HUD: an AbilitySlot
## bound to a source (AbilitySlot.bind) polls it every frame. It never writes
## game state and keeps no timer of its own (the old per-cast HUD timers drifted
## from the real cooldown under attack-speed boosts and a paused tree): every
## number is read from the entity when asked.
##
## Slot order is the HUD's left-to-right order:
##   heroes   (Hero, an AbilitySystem):  basic attack, active, ultimate, passive
##   monsters (Monster, a MonsterBase):  ability_1, ability_2, ability_3, passive
## Previews and tests subclass the base with scripted numbers.

## Stage numerals for lock_hint(): Ground Slam before Stage II shows "II".
const STAGE_NUMERALS: Array[String] = ["", "I", "II", "III"]


func slot_count() -> int:
	return 0


## The ability in `slot`, or null for an empty slot (a monster without a
## passive).
func ability(_slot: int) -> AbilityBase:
	return null


## The slot's kind, which picks its frame (slot_basic / _active / _ult /
## _passive) and whether it glows while ready (ULTIMATE).
func slot_type(_slot: int) -> AbilityBase.AbilityType:
	return AbilityBase.AbilityType.ACTIVE


## The entity the abilities belong to (the caster for get_display_icon).
func caster() -> Node:
	return null


## The icon the slot shows: the ability's display icon for its caster, so
## River's basic-attack slot follows her weapon mode.
func icon(slot: int) -> Texture2D:
	var a := ability(slot)
	return a.get_display_icon(caster()) if a else null


## 0.0 right after a cast, 1.0 when ready (always 1.0 for passives).
func progress(_slot: int) -> float:
	return 1.0


## Seconds until the ability is ready again (0.0 when ready).
func remaining(_slot: int) -> float:
	return 0.0


## Not castable yet for a reason other than its cooldown (Ground Slam before
## Stage II). The slot shows a padlock and lock_hint() instead of a sweep.
func locked(_slot: int) -> bool:
	return false


## What a locked slot shows under its padlock (the unlock stage's numeral).
func lock_hint(_slot: int) -> String:
	return ""


## False once the entity is gone; a bound slot then stops polling.
func is_valid() -> bool:
	return false


## A hero's four abilities, read from its AbilitySystem.
class Hero extends CooldownSource:
	const ORDER: Array[AbilityBase.AbilityType] = [
		AbilityBase.AbilityType.BASIC_ATTACK, AbilityBase.AbilityType.ACTIVE,
		AbilityBase.AbilityType.ULTIMATE, AbilityBase.AbilityType.PASSIVE]

	var _system: AbilitySystem

	func _init(system: AbilitySystem) -> void:
		_system = system

	func is_valid() -> bool:
		return is_instance_valid(_system)

	func slot_count() -> int:
		return ORDER.size()

	func slot_type(slot: int) -> AbilityBase.AbilityType:
		return ORDER[slot]

	func caster() -> Node:
		return _system.owner_entity

	func ability(slot: int) -> AbilityBase:
		match ORDER[slot]:
			AbilityBase.AbilityType.BASIC_ATTACK:
				return _system.basic_attack
			AbilityBase.AbilityType.ACTIVE:
				return _system.active_ability
			AbilityBase.AbilityType.ULTIMATE:
				return _system.ultimate_ability
		return _system.passive_ability

	func progress(slot: int) -> float:
		return _system.get_cooldown_progress(ORDER[slot])

	func remaining(slot: int) -> float:
		return maxf(_system.cooldowns[ORDER[slot]], 0.0)


## A monster's three abilities and its passive, read from the MonsterBase
## (ability_cooldowns and get_cooldown_progress). Stage-gated abilities are
## locked until the monster reaches their unlock_stage.
class Monster extends CooldownSource:
	const KEYS: Array[String] = ["ability_1", "ability_2", "ability_3", ""]
	const TYPES: Array[AbilityBase.AbilityType] = [
		AbilityBase.AbilityType.BASIC_ATTACK, AbilityBase.AbilityType.ACTIVE,
		AbilityBase.AbilityType.ULTIMATE, AbilityBase.AbilityType.PASSIVE]

	var _monster: MonsterBase

	func _init(monster: MonsterBase) -> void:
		_monster = monster

	func is_valid() -> bool:
		return is_instance_valid(_monster)

	func slot_count() -> int:
		return KEYS.size()

	func slot_type(slot: int) -> AbilityBase.AbilityType:
		return TYPES[slot]

	func caster() -> Node:
		return _monster

	func ability(slot: int) -> AbilityBase:
		match slot:
			0:
				return _monster.ability_1
			1:
				return _monster.ability_2
			2:
				return _monster.ability_3
		return _monster.passive_ability

	func progress(slot: int) -> float:
		return 1.0 if KEYS[slot].is_empty() else _monster.get_cooldown_progress(KEYS[slot])

	func remaining(slot: int) -> float:
		return 0.0 if KEYS[slot].is_empty() else maxf(_monster.get_ability_cooldown(KEYS[slot]), 0.0)

	func locked(slot: int) -> bool:
		var a := ability(slot)
		return a != null and not a.is_unlocked_at(_monster.get_stage())

	func lock_hint(slot: int) -> String:
		var a := ability(slot)
		if a == null:
			return ""
		return STAGE_NUMERALS[clampi(a.unlock_stage, 0, STAGE_NUMERALS.size() - 1)]
