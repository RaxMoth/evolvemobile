extends SceneTree

## Rebuilds the character rigs (see tools/rig_builder.gd): every character with
## a src/rig_src.json under res://Assets/Characters and res://test/fixtures, or
## only the ids given:
##   godot --headless --path <copy> -s res://tools/build_rigs.gd [-- <id> ...]
## Use tools/build_rigs.sh: it runs this on a temp copy, imports the new sheets
## there and copies the generated files back. Prints one "RIG <id> ..." line per
## character, "RIG_OUT <res path>" per written file and "RIG built <n>/<m>".
## Exit 1 when any character's source is broken (nothing is written for it).


func _initialize() -> void:
	var ids := Array(OS.get_cmdline_user_args())
	if ids.is_empty():
		for dir_root in RigBuilder.ROOTS:
			ids.append_array(Array(RigBuilder.character_dirs(dir_root)))
	var built := 0
	for id: String in ids:
		var dir_root := RigBuilder.root_of(id)
		if dir_root.is_empty():
			push_error("RIG: %s has no src/rig_src.json under %s" % [id, ", ".join(PackedStringArray(RigBuilder.ROOTS))])
			continue
		var b := RigBuilder.new(id, dir_root)
		if not b.build():
			for e in b.errors:
				push_error("RIG: " + e)
			continue
		var err := b.write()
		print("RIG %s -> %s (%s)" % [id, b.body_path(), error_string(err)])
		if err != OK:
			continue
		built += 1
		for p in b.output_paths():
			print("RIG_OUT " + p)
	print("RIG built %d/%d" % [built, ids.size()])
	quit(0 if built == ids.size() else 1)
