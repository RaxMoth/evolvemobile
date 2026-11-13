extends TestCase

## tools/pace_stats.gd, the quiet-stretch math of the sims' pace metric
## (README "Headless Tools": "pace").

const PACE := "res://tools/pace_stats.gd"


func test_a_long_gap_and_the_opening_are_quiet_a_short_one_is_not() -> void:
	var stats := load(PACE) as GDScript
	# 0 -> 15 opening (quiet at 12), 15 -> 24 (9 s: not quiet), 24 -> 54
	# (30 s: quiet), 54 -> 60 closing (6 s: not quiet).
	var hits: Array[float] = [15.0, 24.0, 54.0]
	assert_eq(str(stats.call("gaps", hits, 60.0)), "[15.0, 9.0, 30.0, 6.0]")
	var base: Dictionary = stats.call("quiet", hits, 60.0, 12.0, 1.2)
	assert_eq(int(base["n"]), 2, "the opening and the 30 s gap, not the 9 s one")
	assert_near(float(base["share"]), 45.0 / 60.0, 0.001)
	assert_near(float(base["longest_real"]), 25.0, 0.001, "30 game s at x1.2")
	var fast: Dictionary = stats.call("quiet", hits, 60.0, 24.0, 2.4)
	assert_eq(int(fast["n"]), 1, "on fast only the 30 s gap")
	assert_near(float(fast["share"]), 0.5, 0.001)


func test_no_hit_at_all_is_one_quiet_match() -> void:
	var stats := load(PACE) as GDScript
	var none: Array[float] = []
	var q: Dictionary = stats.call("quiet", none, 100.0, 12.0, 1.2)
	assert_eq(int(q["n"]), 1)
	assert_near(float(q["share"]), 1.0, 0.001)
	assert_near(float(stats.call("longest_real", none, 120.0, 1.2)), 100.0, 0.001)
