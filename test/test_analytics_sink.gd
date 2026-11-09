extends TestCase

## AnalyticsSink: buffering, JSONL flush, opt-out, provider hook.

const LOG := "user://analytics.jsonl"


func before_each() -> void:
	if is_isolated():
		PersistedData.wipe_progress(false)
		AnalyticsSink.set_opt_out(false)
		AnalyticsSink.flush()
		if FileAccess.file_exists(LOG):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG))


func _lines() -> Array[String]:
	var out: Array[String] = []
	if not FileAccess.file_exists(LOG):
		return out
	var f := FileAccess.open(LOG, FileAccess.READ)
	while not f.eof_reached():
		var line := f.get_line()
		if not line.is_empty():
			out.append(line)
	return out


func test_events_are_buffered_then_written_as_json_lines() -> void:
	if not require_isolated():
		return
	AnalyticsSink.track(&"unit_a", {"x": 1})
	AnalyticsSink.track(&"unit_b", {"y": "two"})
	assert_eq(AnalyticsSink.pending_count(), 2)
	assert_eq(AnalyticsSink.flush(), 2)
	assert_eq(AnalyticsSink.pending_count(), 0)
	var lines := _lines()
	assert_eq(lines.size(), 2)
	var first: Dictionary = JSON.parse_string(lines[0])
	assert_eq(first.get("name"), "unit_a")
	assert_eq(int(first.get("x")), 1)
	assert_true(int(first.get("t", 0)) > 0, "unix timestamp present")
	assert_eq((JSON.parse_string(lines[1]) as Dictionary).get("y"), "two")
	AnalyticsSink.track(&"unit_c")
	AnalyticsSink.flush()
	assert_eq(_lines().size(), 3, "flush appends, never truncates")


func test_opt_out_drops_events_and_provider_receives_them_otherwise() -> void:
	if not require_isolated():
		return
	var seen: Array = []
	AnalyticsSink.set_provider(func(e: Dictionary) -> void: seen.append(e.get("name")))
	AnalyticsSink.track(&"with_provider")
	assert_eq(seen, ["with_provider"])
	AnalyticsSink.set_opt_out(true)
	assert_false(AnalyticsSink.is_enabled())
	AnalyticsSink.track(&"dropped")
	assert_eq(AnalyticsSink.pending_count(), 0)
	assert_eq(seen.size(), 1, "provider not called while opted out")
	AnalyticsSink.set_provider(Callable())
	AnalyticsSink.set_opt_out(false)


func test_skill_unlock_is_tracked_through_the_manager_signal() -> void:
	if not require_isolated():
		return
	PersistedData.add_currency(PersistedData.GOLD, 200)
	assert_true(MetaSkillManager.unlock(MetaSkillManager.TREE_HERO_BASE, &"t1_hp"))
	AnalyticsSink.flush()
	var names: Array = []
	for line in _lines():
		names.append((JSON.parse_string(line) as Dictionary).get("name"))
	assert_true(names.has("skill_unlocked"))


func test_match_ended_names_the_monster() -> void:
	if not require_isolated():
		return
	var before := GameManager.selected_monster_id
	GameManager.select_monster(GameManager.ROSTER.default_monster_id, false)
	GameManager.match_ended.emit("Heroes", 61.0)
	AnalyticsSink.flush()
	var ended: Dictionary = {}
	for line in _lines():
		var event: Dictionary = JSON.parse_string(line)
		if event.get("name") == "match_ended":
			ended = event
	assert_eq(ended.get("monster"), String(GameManager.ROSTER.default_monster_id), "match_ended carries the monster id")
	assert_eq(ended.get("side"), "heroes")
	GameManager.select_monster(before, false)
