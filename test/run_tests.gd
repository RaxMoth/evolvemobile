extends SceneTree

## Minimal headless test runner — no addon download required.
##   tools/run_tests.sh            (copies the project, isolates user://, runs this)
## Discovers res://test/test_*.gd, each extending TestCase; runs every
## `test_*` method (async allowed), prints a summary and exits 1 on failure.

var _passed: int = 0
var _failed: int = 0
var _skipped: int = 0
var _current: String = ""
var _current_failed: bool = false
var _failures: Array[String] = []


func _initialize() -> void:
	# SceneTree.initialize() calls _initialize BEFORE root._set_tree(), so nodes
	# added here would have no tree yet. Start on the first processed frame.
	process_frame.connect(_run_all, CONNECT_ONE_SHOT)


func record_failure(msg: String) -> void:
	_current_failed = true
	_failures.append(_current + ": " + msg)
	printerr("  FAIL ", _current, ": ", msg)


func record_skip(reason: String) -> void:
	_skipped += 1
	print("  skip ", _current, ": ", reason)


func _run_all() -> void:
	# Killing heroes / the monster must not end a match, pause the tree or
	# switch scenes while testing. (Looked up by path: a -s script is compiled
	# before autoload names exist as globals.)
	var gm := root.get_node_or_null("GameManager")
	if gm:
		gm.set("match_ended_flag", true)
	var paths := _find_tests("res://test")
	paths.sort()
	print("== Better Hunt tests: %d files ==" % paths.size())
	for path in paths:
		var script := load(path) as GDScript
		if script == null:
			_current = path
			record_failure("could not load")
			continue
		var case := script.new() as TestCase
		if case == null:
			_current = path
			record_failure("does not extend TestCase")
			continue
		case.runner = self
		root.add_child(case)
		for m in case.get_method_list():
			var method_name: String = m.name
			if not method_name.begins_with("test_"):
				continue
			_current = path.get_file() + "::" + method_name
			_current_failed = false
			# Hermetic: never depend on the host language (tr() in UI code).
			TranslationServer.set_locale("en")
			# TestCase.play_side changes the played side for one test only.
			var side_before: Variant = gm.get("chosen_side") if gm else null
			case.before_each()
			await case.call(method_name)
			case.after_each()
			if gm:
				gm.set("chosen_side", side_before)
			# Free whatever the test left behind so tests never see each other's entities.
			for leftover in case.get_children():
				case.remove_child(leftover)
				leftover.queue_free()
			await process_frame
			if _current_failed:
				_failed += 1
			else:
				_passed += 1
				print("  ok   ", _current)
		root.remove_child(case)
		case.queue_free()
		await process_frame
	# Let queued frees (parked mobs released by SpawnManager._exit_tree etc.)
	# flush before quitting, or Godot reports them as leaks at exit.
	await process_frame
	await process_frame
	print("== %d passed, %d failed, %d skipped ==" % [_passed, _failed, _skipped])
	for f in _failures:
		print("   ", f)
	quit(1 if _failed > 0 else 0)


func _find_tests(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if not d.current_is_dir() and f.begins_with("test_") and f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
		f = d.get_next()
	d.list_dir_end()
	return out
