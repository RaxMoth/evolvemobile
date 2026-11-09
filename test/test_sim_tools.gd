extends TestCase

## The sim tools' per-monster side (README "Headless Tools"): every roster
## monster has a determinism baseline in tools/baselines, recorded with
## tools/sim_trace.sh's default arguments, so
## `MONSTER=all BASELINE_DIR=tools/baselines tools/sim_trace.sh` checks them
## all; and tools/list_monsters.gd (MONSTER=all, the id check) reads
## GameManager's roster. Whether a baseline is still current only a trace run
## can tell: a commit that changes gameplay re-records them.

const BASELINE := "res://tools/baselines/trace_%s.txt"
const LIST_MONSTERS := "res://tools/list_monsters.gd"
## sim_trace.sh's defaults, in its output order (seed-major).
const SEEDS: Array[String] = ["1", "2", "3"]
const SIDES: Array[String] = ["heroes", "monster"]


func test_every_roster_monster_has_a_trace_baseline() -> void:
	var ids := GameManager.ROSTER.monster_ids()
	assert_false(ids.is_empty())
	for id: StringName in ids:
		assert_true(FileAccess.file_exists(BASELINE % id),
				"tools/baselines/trace_%s.txt exists (MONSTER=%s RECORD_DIR=tools/baselines tools/sim_trace.sh)" % [id, id])


func test_baselines_hold_the_default_runs() -> void:
	var expected_ends: Array[String] = []
	for s: String in SEEDS:
		for side: String in SIDES:
			expected_ends.append("%s %s" % [s, side])
	for id: StringName in GameManager.ROSTER.monster_ids():
		var path := BASELINE % id
		if not FileAccess.file_exists(path):
			continue
		var ends: Array[String] = []
		var bad := 0
		var first_bad := ""
		var lines := FileAccess.get_file_as_string(path).split("\n", false)
		for line: String in lines:
			var f := line.split(" ")
			var trace_line := f.size() == 5 and f[2] == "SIM_TRACE"
			var end_line := f.size() == 7 and f[2] == "SIM_TRACE_END"
			if f.size() < 3 or not SEEDS.has(f[0]) or not SIDES.has(f[1]) or not (trace_line or end_line):
				bad += 1
				if first_bad.is_empty():
					first_bad = line
			elif end_line:
				ends.append("%s %s" % [f[0], f[1]])
		assert_eq(bad, 0, "%s: every line is '<seed> <side> SIM_TRACE...' (first bad: '%s')" % [id, first_bad])
		assert_eq(ends, expected_ends, "%s: one finished match per default seed x side, in sim_trace order" % id)
		assert_true(lines.size() > expected_ends.size(), "%s: the baseline holds the per-second hashes" % id)


func test_list_monsters_reads_the_game_roster() -> void:
	var lister := load(LIST_MONSTERS) as GDScript
	assert_true(lister != null and lister.can_instantiate(), "list_monsters.gd compiles")
	if lister == null:
		return
	assert_eq(lister.get_instance_base_type(), &"SceneTree", "a -s script")
	assert_eq(lister.get_script_constant_map().get("ROSTER_PATH", ""), GameManager.ROSTER.resource_path,
			"it lists GameManager.ROSTER's file")
