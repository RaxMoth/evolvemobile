extends TestCase

## MatchRewards.compute is pure; these pin the README "Earning Rates v2"
## formula. Currency: win 150 / loss 75, +15 per kill, +5 per minute, +20 per
## survivor (heroes) or +25 per stage (monster). Gold: win 100 / loss 50, +2
## per kill. Permanent XP is the pre-v2 formula, unchanged.

func test_hero_win_formula() -> void:
	# The README example: heroes win at 8:00 with 3 survivors and 40 kills.
	var r := MatchRewards.compute(MatchRewards.Side.HEROES, MatchRewards.Outcome.WIN, 480.0, 40, 3, 2)
	assert_eq(r.steel, 150 + 600 + 40 + 60, "steel = base + kills*15 + minutes*5 + survivors*20")
	assert_eq(r.leaves, 0)
	assert_eq(r.gold, 100 + 80, "gold = base + kills*2")
	assert_eq(r.xp, 25 + 80 + 24 + 15, "xp = base + kills*2 + minutes*3 + survivors*5")
	assert_true(r.has_rewards())


func test_hero_loss_formula() -> void:
	var r := MatchRewards.compute(MatchRewards.Side.HEROES, MatchRewards.Outcome.LOSS, 359.9, 12, 0, 3)
	assert_eq(r.steel, 75 + 180 + 25, "a loss halves the base; 5:59 counts 5 full minutes; no survivors")
	assert_eq(r.leaves, 0)
	assert_eq(r.gold, 50 + 24)
	assert_eq(r.xp, 10 + 24 + 15)


func test_monster_win_formula() -> void:
	var r := MatchRewards.compute(MatchRewards.Side.MONSTER, MatchRewards.Outcome.WIN, 660.0, 30, 4, 3)
	assert_eq(r.leaves, 150 + 450 + 55 + 75, "leaves = base + kills*15 + minutes*5 + stage*25")
	assert_eq(r.steel, 0, "heroes alive never pays the monster")
	assert_eq(r.gold, 100 + 60)
	assert_eq(r.xp, 25 + 60 + 33 + 30, "xp = base + kills*2 + minutes*3 + stage*10")


func test_monster_loss_formula() -> void:
	var r := MatchRewards.compute(MatchRewards.Side.MONSTER, MatchRewards.Outcome.LOSS, 125.0, 3, 0, 2)
	assert_eq(r.leaves, 75 + 45 + 10 + 50, "leaves = base + kills + minutes + stage")
	assert_eq(r.steel, 0)
	assert_eq(r.gold, 50 + 6)
	assert_eq(r.xp, 10 + 6 + 6 + 20, "xp is unchanged by v2")


func test_inputs_are_clamped() -> void:
	var r := MatchRewards.compute(MatchRewards.Side.MONSTER, MatchRewards.Outcome.TIMEOUT, -90.0, -5, -2, 7)
	assert_eq(r.mob_kills, 0)
	assert_eq(r.heroes_alive, 0)
	assert_eq(r.monster_stage, 3)
	assert_eq(r.leaves, 75 + 75, "timeout counts as a loss; stage clamped to 3; no negative minutes")
	assert_eq(r.gold, 50)
	assert_eq(r.xp, 10 + 30)


func test_v2_constants() -> void:
	# The rates the skill-tree prices were balanced against (about 800 Steel,
	# 1000 Leaves and 160 Gold per match): a change here re-prices every tree.
	assert_eq([MatchRewards.CURRENCY_WIN, MatchRewards.CURRENCY_LOSS], [150, 75])
	assert_eq([MatchRewards.CURRENCY_PER_KILL, MatchRewards.CURRENCY_PER_MINUTE], [15, 5])
	assert_eq([MatchRewards.CURRENCY_PER_SURVIVOR, MatchRewards.CURRENCY_PER_STAGE], [20, 25])
	assert_eq([MatchRewards.GOLD_WIN, MatchRewards.GOLD_LOSS, MatchRewards.GOLD_PER_KILL], [100, 50, 2])


func test_format_duration() -> void:
	assert_eq(MatchRewards.format_duration(125.0), "2:05")
	assert_eq(MatchRewards.format_duration(0.0), "0:00")
