extends SceneTree

## Minimal headless test runner — no addon download required.
##   tools/run_tests.sh [name ...]   (copies the project, isolates user://, runs this)
## Discovers res://test/test_*.gd, each extending TestCase; runs every
## `test_*` method (async allowed), prints a summary and exits 1 on failure.
## Names (user args after "--") run only the files whose name contains one.
##
## A test passes when it ran to its end with no failed assert, no SCRIPT
## ERROR and no engine ERROR it did not announce. A script error aborts the
## function it happens in, so the test's later asserts may never run: a
## Logger counts errors as they happen and the test that was running fails,
## with where the first one came from (error_origin: in the test itself, in
## code it called, or outside it: game code on its own, or a timer, deferred
## call or coroutine an earlier test left running). An engine ERROR
## (push_error, an engine check, a freed object in a typed array) fails the
## test too unless the test expected it (TestCase.expect_error: a corrupt save
## on purpose), so a new one stands out. A skipped test (skip(), e.g.
## require_isolated()) counts as skipped, not as passed. A run outside the
## isolated user:// of tools/run_tests.sh skips the save tests: it says so
## and exits 1. A name that matches no test file fails the run (a typo must
## not pass as "0 failed"). A test still running after TEST_TIME_LIMIT_SEC (a
## loop that never ends, an await that never returns) is named and the run
## stops.

## Wall-clock wait before quitting for the audio mixer thread to drop the
## stopped playbacks (the run's frames are not real time).
const EXIT_AUDIO_WAIT_MSEC := 120
## Wall-clock limit of one test (the slowest takes a few seconds).
const TEST_TIME_LIMIT_SEC := 120
## How often the watchdog looks at the clock.
const WATCH_EVERY_MSEC := 250

## Where a SCRIPT ERROR came from, seen from the running test (error_origin).
enum Origin { IN_TEST, CALLED_BY_TEST, OUTSIDE_TEST }


## Counts the errors logged while the tests run (a Logger: any thread, so
## behind a lock). SCRIPT ERRORs (Logger.ERROR_TYPE_SCRIPT) and engine ERRORs
## (ERROR_TYPE_ERROR) are counted apart, with the place and the backtraces of
## the first of each; an engine ERROR whose text holds a fragment the running
## test passed to expect() is counted as expected. Warnings are left alone.
class ErrorCounter extends Logger:
	var _lock := Mutex.new()
	var _expected: PackedStringArray = []
	var _new_script: int = 0
	var _new_engine: int = 0
	var _new_expected: int = 0
	var _script_backtraces: Array[ScriptBacktrace] = []
	var _script_where: String = ""
	var _engine_text: String = ""

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_SCRIPT and error_type != Logger.ERROR_TYPE_ERROR:
			return
		_lock.lock()
		if error_type == Logger.ERROR_TYPE_SCRIPT:
			if _new_script == 0:
				_script_backtraces = script_backtraces
				_script_where = "%s:%d (%s)" % [file, line, function]
			_new_script += 1
		else:
			var text := rationale if not rationale.is_empty() else code
			var expected := false
			for fragment in _expected:
				expected = expected or text.contains(fragment)
			if expected:
				_new_expected += 1
			else:
				if _new_engine == 0:
					_engine_text = "%s, at %s" % [text, _script_top(script_backtraces, "%s:%d" % [file, line])]
				_new_engine += 1
		_lock.unlock()

	## A new test starts: no error expected yet.
	func start_test() -> void:
		_lock.lock()
		_expected = []
		_lock.unlock()

	func expect(fragment: String) -> void:
		_lock.lock()
		_expected.append(fragment)
		_lock.unlock()

	## The errors since the last take(): {script, engine, expected (counts),
	## backtraces and where (of the first SCRIPT ERROR), engine_text (of the
	## first unexpected engine ERROR)}.
	func take() -> Dictionary:
		_lock.lock()
		var out := {
			"script": _new_script, "engine": _new_engine, "expected": _new_expected,
			"backtraces": _script_backtraces, "where": _script_where, "engine_text": _engine_text,
		}
		_new_script = 0
		_new_engine = 0
		_new_expected = 0
		_script_backtraces = []
		_lock.unlock()
		return out

	## "file:line (function)" of the innermost GDScript frame, else `fallback`.
	static func _script_top(backtraces: Array[ScriptBacktrace], fallback: String) -> String:
		for bt in backtraces:
			if bt.get_frame_count() > 0:
				return "%s:%d (%s)" % [bt.get_frame_file(0), bt.get_frame_line(0), bt.get_frame_function(0)]
		return fallback


## Where an error with these backtraces came from, seen from the test `method`
## of the script at `path`: IN_TEST when the innermost frame is that test (it
## stopped there), CALLED_BY_TEST when the test is lower in the stack (a helper
## or game code it called returned a default value), OUTSIDE_TEST when the
## test is not in the stack at all.
static func error_origin(backtraces: Array[ScriptBacktrace], path: String, method: String) -> Origin:
	var origin := Origin.OUTSIDE_TEST
	for bt in backtraces:
		for i in bt.get_frame_count():
			if bt.get_frame_file(i) == path and bt.get_frame_function(i) == method:
				origin = Origin.IN_TEST if i == 0 else mini(origin, Origin.CALLED_BY_TEST) as Origin
	return origin


## The failure line of a test whose run logged a SCRIPT ERROR.
static func script_error_message(origin: Origin, where: String) -> String:
	match origin:
		Origin.IN_TEST:
			return "SCRIPT ERROR (above) at %s: the test stopped there, its later checks did not run" % where
		Origin.CALLED_BY_TEST:
			return "SCRIPT ERROR (above) at %s, in code the test called (it returned a default value)" % where
	return ("SCRIPT ERROR (above) at %s, not called by this test: game code running on its own (an AI tick, "
			+ "a signal), or a timer, deferred call or coroutine an earlier test left behind") % where


## Why a run selected no test file ("" when it found some).
static func selection_problem(names: PackedStringArray, found: int) -> String:
	if found > 0:
		return ""
	if names.is_empty():
		return "no test file found under res://test"
	return "no test file matches %s" % " ".join(names)


var _passed: int = 0
var _failed: int = 0
var _skipped: int = 0
var _current: String = ""
var _current_failed: bool = false
var _current_skipped: bool = false
var _failures: Array[String] = []
var _errors := ErrorCounter.new()
var _watchdog := Thread.new()
var _watch_lock := Mutex.new()
var _watch_label: String = ""
var _watch_deadline_msec: int = 0
var _watch_stop: bool = false


func _initialize() -> void:
	# SceneTree.initialize() calls _initialize BEFORE root._set_tree(), so nodes
	# added here would have no tree yet. Start on the first processed frame.
	process_frame.connect(_run_all, CONNECT_ONE_SHOT)


func record_failure(msg: String) -> void:
	_current_failed = true
	_failures.append(_current + ": " + msg)
	printerr("  FAIL ", _current, ": ", msg)


func record_skip(reason: String) -> void:
	_current_skipped = true
	print("  skip ", _current, ": ", reason)


## TestCase.expect_error: the running test provokes an engine ERROR holding
## `fragment` on purpose.
func expect_error(fragment: String) -> void:
	_errors.expect(fragment)


func _run_all() -> void:
	OS.add_logger(_errors)
	_arm("the start of the run")
	_watchdog.start(_watch)
	# Killing heroes / the monster must not end a match, pause the tree or
	# switch scenes while testing. (Looked up by path: a -s script is compiled
	# before autoload names exist as globals.)
	var gm := root.get_node_or_null("GameManager")
	if gm:
		gm.set("match_ended_flag", true)
	var names := OS.get_cmdline_user_args()
	var paths := _find_tests("res://test", names)
	paths.sort()
	print("== Better Hunt tests: %d files ==" % paths.size())
	var nothing := selection_problem(names, paths.size())
	if not nothing.is_empty():
		_fail_outside_a_test("the test selection", nothing)
	for path in paths:
		var file := path.get_file()
		_arm(file + " (set-up)")
		var script := load(path) as GDScript
		if script == null:
			_fail_outside_a_test(file, "could not load")
			continue
		var case := script.new() as TestCase
		if case == null:
			_fail_outside_a_test(file, "does not extend TestCase")
			continue
		case.runner = self
		root.add_child(case)
		_charge_errors(file + " (set-up)")
		for m in case.get_method_list():
			var method_name: String = m.name
			if not method_name.begins_with("test_"):
				continue
			_current = file + "::" + method_name
			_current_failed = false
			_current_skipped = false
			_arm(_current)
			_errors.start_test()
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
			var errors := _errors.take()
			if int(errors["script"]) > 0:
				var backtraces: Array[ScriptBacktrace] = errors["backtraces"]
				var origin := error_origin(backtraces, path, method_name)
				record_failure(script_error_message(origin, String(errors["where"])))
			if int(errors["engine"]) > 0:
				record_failure("engine ERROR (above) the test did not expect (TestCase.expect_error): %s"
						% String(errors["engine_text"]))
			if _current_failed:
				_failed += 1
			elif _current_skipped:
				_skipped += 1
			else:
				_passed += 1
				print("  ok   ", _current, " (the ERROR above was expected)" if int(errors["expected"]) > 0 else "")
		_arm(file + " (teardown)")
		root.remove_child(case)
		case.queue_free()
		await process_frame
		_charge_errors(file + " (teardown)")
	# Let queued frees (parked mobs released by SpawnManager._exit_tree etc.)
	# flush before quitting, and let the audio mixer drop the playbacks of the
	# sounds still playing, or Godot reports them as leaks at exit.
	_arm("the end of the run")
	var audio := root.get_node_or_null("AudioManager")
	if audio:
		audio.call("stop_all")
	await process_frame
	OS.delay_msec(EXIT_AUDIO_WAIT_MSEC)
	await process_frame
	await process_frame
	_charge_errors("the end of the run")
	_stop_watchdog()
	OS.remove_logger(_errors)
	var isolated := OS.get_user_data_dir().contains("evolvemobile_tests")
	print("== %d passed, %d failed, %d skipped ==" % [_passed, _failed, _skipped])
	for f in _failures:
		print("   ", f)
	if not isolated:
		printerr("NOT ISOLATED: user:// is %s, so the tests that write the save were skipped; run tools/run_tests.sh"
				% OS.get_user_data_dir())
	quit(1 if _failed > 0 or not isolated else 0)


## A failure that belongs to no test: a file that does not load, a script
## error while a file's case is added or freed.
func _fail_outside_a_test(label: String, msg: String) -> void:
	_current = label
	record_failure(msg)
	_failed += 1


func _charge_errors(label: String) -> void:
	var errors := _errors.take()
	if int(errors["script"]) > 0:
		_fail_outside_a_test(label, "SCRIPT ERROR (above) at %s" % String(errors["where"]))
	elif int(errors["engine"]) > 0:
		_fail_outside_a_test(label, "engine ERROR (above): %s" % String(errors["engine_text"]))


## The watchdog: when the armed step outlives TEST_TIME_LIMIT_SEC it names it
## and kills the run. A GDScript loop that never ends holds the main thread,
## so nothing on that thread could end it.
func _watch() -> void:
	while true:
		OS.delay_msec(WATCH_EVERY_MSEC)
		_watch_lock.lock()
		var stop := _watch_stop
		var late := Time.get_ticks_msec() > _watch_deadline_msec
		var label := _watch_label
		_watch_lock.unlock()
		if stop:
			return
		if late:
			printerr("  TIMEOUT %s: still running after %d s (a loop or an await that never ends?); the run stops here"
					% [label, TEST_TIME_LIMIT_SEC])
			OS.kill(OS.get_process_id())
			return


func _arm(label: String) -> void:
	_watch_lock.lock()
	_watch_label = label
	_watch_deadline_msec = Time.get_ticks_msec() + TEST_TIME_LIMIT_SEC * 1000
	_watch_lock.unlock()


func _stop_watchdog() -> void:
	_watch_lock.lock()
	_watch_stop = true
	_watch_lock.unlock()
	_watchdog.wait_to_finish()


## The test files under dir_path; with names, only those whose file name
## contains one of them.
func _find_tests(dir_path: String, names: PackedStringArray) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if not d.current_is_dir() and f.begins_with("test_") and f.ends_with(".gd") and _wanted(f, names):
			out.append(dir_path.path_join(f))
		f = d.get_next()
	d.list_dir_end()
	return out


func _wanted(file: String, names: PackedStringArray) -> bool:
	if names.is_empty():
		return true
	for n in names:
		if file.contains(n):
			return true
	return false
