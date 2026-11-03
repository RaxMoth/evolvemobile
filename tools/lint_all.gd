extends SceneTree

## Headless compile check: loads every script / scene / resource under res://
## so parse + compile errors surface on stderr, and checks every scene's wiring
## (see _check_scene_wiring). Run through tools/lint.sh (which works on a temp
## COPY of the project — never run a newer editor binary against the real
## project directory).
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
			var res := load(p)
			if res == null:
				push_error("LINT: failed to load resource " + p)
			elif res is PackedScene:
				_check_scene_wiring(res as PackedScene, p)
	print("LINT DONE scripts=%d resources=%d" % [n_scripts, n_res])
	quit()


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
