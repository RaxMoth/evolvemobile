extends SceneTree

## Prints the GDScript warnings the project leaves at "warn" (level 1), by
## setting name, on one line:
##   WARNINGS unassigned_variable unused_variable shadowed_variable ...
## tools/lint.sh sets each of them to "error" (2) in its copy's override.cfg,
## so a warning fails the lint (Godot 4.7 has no single "treat warnings as
## errors" switch). Warnings the project ignores (0) stay ignored. Run it like
## the other -s tools, on a temp copy with its own user:// (override.cfg).
##
##   godot --headless --path <copy> -s res://tools/list_warnings.gd

const PREFIX := "debug/gdscript/warnings/"
## ProjectSettings' warning levels: GDScriptWarning.WarnLevel.
const LEVEL_WARN := 1


func _initialize() -> void:
	var names := PackedStringArray()
	for prop: Dictionary in ProjectSettings.get_property_list():
		var key: String = prop["name"]
		if not key.begins_with(PREFIX):
			continue
		var level: Variant = ProjectSettings.get_setting(key)
		if typeof(level) == TYPE_INT and int(level) == LEVEL_WARN:
			names.append(key.trim_prefix(PREFIX))
	print("WARNINGS " + " ".join(names))
	quit()
