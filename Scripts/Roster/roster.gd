class_name Roster
extends Resource

## Every playable character, in menu order. The one instance is
## res://Scenes/NPCs/roster.tres, preloaded by GameManager (ROSTER): World's
## MonsterSlot spawns from it, the menus show it and the sim tools pick a
## monster by id.
## Adding a monster = its scene (inherits monster_base_class.tscn) + its
## Assets/Characters/<id> rig + a CharacterDef here + its skill tree.

@export var heroes: Array[CharacterDef] = []
@export var monsters: Array[CharacterDef] = []
## Used when nothing (or an unknown / removed id) is selected.
@export var default_monster_id: StringName = &"grount"


func all() -> Array[CharacterDef]:
	var out: Array[CharacterDef] = []
	out.append_array(heroes)
	out.append_array(monsters)
	return out


func find(character_id: StringName) -> CharacterDef:
	for d in all():
		if d != null and d.character_id() == character_id:
			return d
	return null


func hero_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for d in heroes:
		if d != null:
			out.append(d.character_id())
	return out


func monster_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for d in monsters:
		if d != null:
			out.append(d.character_id())
	return out


## `monster_id` when the roster has it, else the default, else the first
## monster: a save or a sim argument naming a monster this build does not ship
## never breaks the match.
func resolve_monster(monster_id: StringName) -> CharacterDef:
	for id: StringName in [monster_id, default_monster_id]:
		for d in monsters:
			if d != null and d.character_id() == id:
				return d
	return monsters[0] if not monsters.is_empty() else null
