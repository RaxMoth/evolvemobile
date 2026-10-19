extends SceneTree

## Headless compile check: loads every script / scene / resource under res://
## so parse + compile errors surface on stderr. Run through tools/lint.sh (which
## works on a temp COPY of the project — never run a newer editor binary
## against the real project directory).
func _initialize() -> void:
	# Autoload names only exist as globals after Main::start, hence not _init().
	var files: Array[String] = []
	_walk("res://", files)
	var n_scripts := 0
	var n_res := 0
	for p in files:
		if p.ends_with(".gd"):
			n_scripts += 1
			var s := load(p) as GDScript
			if s == null:
				push_error("LINT: failed to load script " + p)
			elif not s.can_instantiate():
				push_error("LINT: script not instantiable (compile error?) " + p)
		elif p.ends_with(".tscn") or p.ends_with(".tres"):
			n_res += 1
			if load(p) == null:
				push_error("LINT: failed to load resource " + p)
	print("LINT DONE scripts=%d resources=%d" % [n_scripts, n_res])
	quit()


func _walk(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if not f.begins_with("."):
			var full := dir_path.path_join(f)
			if d.current_is_dir():
				if f != "addons":
					_walk(full, out)
			elif f != "lint_all.gd":
				out.append(full)
		f = d.get_next()
	d.list_dir_end()
