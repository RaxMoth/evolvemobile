extends TestCase

## MatchRewards.compute is pure; these pin the README formula.

func test_hero_win_formula() -> void:
	var r := MatchRewards.compute(MatchRewards.Side.HEROES, MatchRewards.Outcome.WIN, 480.0, 40, 3, 2)
	assert_eq(r.steel, 100 + 400 + 40 + 45, "steel = base + kills + minutes + survivors")
	assert_eq(r.leaves, 0)
	assert_eq(r.gold, 50)
	assert_eq(r.xp, 25 + 80 + 24 + 15, "xp = base + kills*2 + minutes*3 + survivors*5")
	assert_true(r.has_rewards())


func test_monster_loss_formula() -> void:
	var r := MatchRewards.compute(MatchRewards.Side.MONSTER, MatchRewards.Outcome.LOSS, 125.0, 3, 0, 2)
	assert_eq(r.leaves, 50 + 30 + 10 + 50, "leaves = base + kills + minutes + stage")
	assert_eq(r.steel, 0)
	assert_eq(r.gold, 25)
	assert_eq(r.xp, 10 + 6 + 6 + 20)


func test_inputs_are_clamped() -> void:
	var r := MatchRewards.compute(MatchRewards.Side.MONSTER, MatchRewards.Outcome.TIMEOUT, -10.0, -5, -2, 7)
	assert_eq(r.mob_kills, 0)
	assert_eq(r.heroes_alive, 0)
	assert_eq(r.monster_stage, 3)
	assert_eq(r.leaves, 50 + 75, "timeout counts as a loss; stage clamped to 3")


func test_format_duration() -> void:
	assert_eq(MatchRewards.format_duration(125.0), "2:05")
	assert_eq(MatchRewards.format_duration(0.0), "0:00")
