extends SceneTree

## Headless compile check: loads every script / scene / resource under res://
## so parse + compile errors surface on stderr, checks every scene's wiring
## (see _check_scene_wiring) and that the UI has no colour literals (see
## _check_no_color_literals). Run through tools/lint.sh (which works on a temp
## COPY of the project — never run a newer editor binary against the real
## project directory), which also turns every GDScript warning into an error
## on that copy (see _count_warnings_as_errors).

## The no-colour-literal rule covers every script, scene and resource here.
const COLOR_RULE_ROOT := "res://Scenes/UI/"
## The colour sources themselves: the palette (its Color.MAGENTA defaults and
## the derived modulate constants), its values and the generated theme.
const COLOR_RULE_EXEMPT: Array[String] = [
	"res://Scenes/UI/Theme/ui_palette.gd",
	"res://Scenes/UI/Theme/palette.tres",
	"res://Scenes/UI/Theme/ui_theme.tres",
]
const WARNINGS_PREFIX := "debug/gdscript/warnings/"
## ProjectSettings' warning levels (GDScriptWarning.WarnLevel).
const LEVEL_WARN := 1
const LEVEL_ERROR := 2


func _initialize() -> void:
	# Autoload names only exist as globals after Main::start, hence not _init().
	var n_warnings := _count_warnings_as_errors()
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
			var res := load(p)
			if res == null:
				push_error("LINT: failed to load resource " + p)
			elif res is PackedScene:
				_check_scene_wiring(res as PackedScene, p)
	var n_color_checked := _check_no_color_literals(files)
	print("LINT DONE scripts=%d resources=%d ui_color_checked=%d warnings_as_errors=%d" % [n_scripts, n_res,
			n_color_checked, n_warnings])
	quit()


## tools/lint.sh sets every GDScript warning the project leaves at "warn" to
## "error" in its copy's override.cfg (tools/list_warnings.gd), so a script
## with a warning fails to compile here. A warning still at "warn" means that
## did not happen (lint_all.gd run by hand, or the list came back short): it
## would pass unseen, so it is an error. Returns how many warnings are errors.
func _count_warnings_as_errors() -> int:
	var as_errors := 0
	for prop: Dictionary in ProjectSettings.get_property_list():
		var key: String = prop["name"]
		if not key.begins_with(WARNINGS_PREFIX):
			continue
		var level: Variant = ProjectSettings.get_setting(key)
		if typeof(level) != TYPE_INT:
			continue
		if int(level) == LEVEL_ERROR:
			as_errors += 1
		elif int(level) == LEVEL_WARN:
			push_error("LINT: GDScript warning %s is only a warning (run the lint through tools/lint.sh)" % key)
	return as_errors


## load() never connects a signal or resolves a NodePath, so broken scene
## wiring passes it: a [connection] to a missing method connects silently and
## only errors when the signal fires, and a state-chart Transition whose `to`
## misses its state only errors when the transition is taken. So instantiate
## the scene (outside the tree: no _enter_tree / _ready runs) and check
##  - every [connection]: the source has the signal, the target has the method
##  - every Transition: `to`, resolved relative to the TRANSITION node itself
##    (the godot_state_charts rule), reaches a state node.
## A scene's SceneState lists only the connections and nodes its own file
## declares, so inherited wiring is checked once, through its base scene file.
func _check_scene_wiring(scene: PackedScene, p: String) -> void:
	var inst := scene.instantiate()
	if inst == null:
		push_error("LINT: failed to instantiate scene " + p)
		return
	var state := scene.get_state()
	for i in state.get_connection_count():
		var signal_name := state.get_connection_signal(i)
		var method := state.get_connection_method(i)
		var from_path := state.get_connection_source(i)
		var to_path := state.get_connection_target(i)
		var wire := "%s: %s:%s -> %s:%s()" % [p, from_path, signal_name, to_path, method]
		var source := inst.get_node_or_null(from_path)
		var target := inst.get_node_or_null(to_path)
		if source == null or target == null:
			push_error("LINT: connection endpoint not found " + wire)
		elif not source.has_signal(signal_name):
			push_error("LINT: connection from a nonexistent signal " + wire)
		elif not target.has_method(method):
			push_error("LINT: connection to a missing method " + wire)
	for i in state.get_node_count():
		var node := inst.get_node_or_null(state.get_node_path(i))
		if node == null or not _script_classes(node).has("Transition"):
			continue
		var state_path: NodePath = node.get("to")
		var to_state := node.get_node_or_null(state_path)
		if to_state == null or not _is_state(to_state):
			push_error("LINT: transition target is not a state %s: %s to = %s" % [p, state.get_node_path(i), state_path])
	inst.free()


## The palette (UiPalette, palette.tres) is the only colour source of the UI:
## no colour literal in Scenes/UI/** (art spec "no Color( literal in
## Scenes/UI"). In a script a literal is a Color( whose first argument is a
## number or a string, Color8(...) or Color.html / hex / from_*(...); a palette
## token with an alpha, Color(palette.bg_void, 0.72), is fine, and so are the
## named identity constants (Color.WHITE as "no tint"). In a scene or resource
## every Color( is a literal (the file format writes the numbers): use a theme
## type variation, or set the token from the script. Comments do not count.
## Returns how many files it checked.
func _check_no_color_literals(files: Array[String]) -> int:
	var in_script := RegEx.create_from_string("\\bColor\\(\\s*[-+.0-9\"')]|\\bColor8\\(|\\bColor\\.(html|hex|hex64|from_\\w+)\\(")
	var in_data := RegEx.create_from_string("\\bColor\\(")
	var checked := 0
	for p in files:
		if not p.begins_with(COLOR_RULE_ROOT) or COLOR_RULE_EXEMPT.has(p):
			continue
		var is_script := p.ends_with(".gd")
		if not (is_script or p.ends_with(".tscn") or p.ends_with(".tres")):
			continue
		checked += 1
		var lines := FileAccess.get_file_as_string(p).split("\n")
		for i in lines.size():
			var line: String = lines[i]
			if is_script:
				line = line.get_slice("#", 0)
			if (in_script if is_script else in_data).search(line) != null:
				push_error("LINT: colour literal in the UI (use a UiPalette token or a theme variation) %s:%d: %s" % [p, i + 1, lines[i].strip_edges()])
	return checked


## Global class names of the node's script and its base scripts. Compared by
## name: this script must not use the addon's class_names as types.
func _script_classes(node: Node) -> PackedStringArray:
	var names: PackedStringArray = []
	var s := node.get_script() as Script
	while s != null:
		names.append(String(s.get_global_name()))
		s = s.get_base_script()
	return names


## AtomicState, CompoundState, ParallelState, HistoryState, ... (all extend
## StateChartState).
func _is_state(node: Node) -> bool:
	for cls_name in _script_classes(node):
		if cls_name.ends_with("State"):
			return true
	return false


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
