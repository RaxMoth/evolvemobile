extends TestCase

## The test runner's own rules (test/run_tests.gd, README "Headless Tools"),
## called on the runner's script: a name that selects no test file fails the
## run, a SCRIPT ERROR is placed from its backtrace (in the test, in code it
## called, or outside it) and an engine ERROR a test announced with
## expect_error does not fail it (review3 tools-3, tools-4).

const THIS_TEST := "test_a_script_error_is_placed_from_its_backtrace"


## The runner's script: the SceneTree the tests run in.
func _rules() -> Script:
	return get_tree().get_script() as Script


func test_a_name_that_matches_no_test_file_fails_the_run() -> void:
	var rules := _rules()
	assert_eq(String(rules.call("selection_problem", PackedStringArray(["zz_no_such_test"]), 0)),
			"no test file matches zz_no_such_test", "a typo selects nothing: the run fails")
	assert_eq(String(rules.call("selection_problem", PackedStringArray(), 0)),
			"no test file found under res://test")
	assert_eq(String(rules.call("selection_problem", PackedStringArray(["minimap"]), 1)), "", "a match runs")


## Origin: 0 in the test (it stopped there), 1 in code the test called, 2 not
## called by the test (a timer or coroutine an earlier test left running).
func test_a_script_error_is_placed_from_its_backtrace() -> void:
	var rules := _rules()
	var path: String = (get_script() as Script).resource_path
	var here := Engine.capture_script_backtraces()
	var below := _capture_one_call_down()
	assert_eq(int(rules.call("error_origin", here, path, THIS_TEST)), 0, "in the test itself")
	assert_eq(int(rules.call("error_origin", below, path, THIS_TEST)), 1, "in code the test called")
	assert_eq(int(rules.call("error_origin", here, path, "test_some_other_test")), 2, "not called by this test")
	var where := "res://test/test_x.gd:12 (_later)"
	var stopped := String(rules.call("script_error_message", 0, where))
	assert_true(stopped.contains(where) and stopped.contains("the test stopped there"), stopped)
	var called := String(rules.call("script_error_message", 1, where))
	assert_true(called.contains(where) and not called.contains("stopped there"), called)
	var outside := String(rules.call("script_error_message", 2, where))
	assert_true(outside.contains(where) and outside.contains("earlier test") and not outside.contains("stopped there"),
			outside)


func _capture_one_call_down() -> Array[ScriptBacktrace]:
	return Engine.capture_script_backtraces()


## An engine ERROR the test announced counts as expected (the run still prints
## it, marked on the test's ok line); without expect_error it fails the test.
func test_an_announced_engine_error_does_not_fail_the_test() -> void:
	expect_error("planted by test_runner_rules")
	push_error("an engine ERROR planted by test_runner_rules (expected)")
