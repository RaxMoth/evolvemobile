extends SceneTree

## Prints the roster's monster ids, in roster order, on one line:
##   MONSTER_IDS grount nyxa gorrak
## The sim tools' MONSTER=all loops them and MONSTER=<id> is checked against
## them (tools/monster_env.zsh). Run it like the other -s tools, on a temp copy
## with its own user:// (override.cfg): the autoloads start with it.
##
##   godot --headless --path <copy> -s res://tools/list_monsters.gd

## GameManager.ROSTER's file (a -s script must not name project classes, so
## the roster is loaded by path and called by name).
const ROSTER_PATH := "res://Scenes/NPCs/roster.tres"


func _initialize() -> void:
	var roster := load(ROSTER_PATH)
	var ids := PackedStringArray()
	if roster != null:
		for id: StringName in roster.call("monster_ids"):
			ids.append(String(id))
	print("MONSTER_IDS " + " ".join(ids))
	quit()
