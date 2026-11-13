extends TestCase

## Opponent Threat and the side rule (README "Opponent Threat"): the played
## side (GameManager.chosen_side) applies the save's trees; the AI opponent
## applies the first 3T entries of its character tree's ai_build_order and the
## first 2T of its base tree's, T = min(4, floor(P / 6)), P = the played side's
## power ranks. The opponent no longer inherits the player's unlocks. Rewards
## carry x(1 + 0.1 T) (test_rewards).

const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const THROWAWAY := &"test_ai_order"
const HEROES := MatchRewards.Side.HEROES
const MONSTER := MatchRewards.Side.MONSTER


func before_each() -> void:
	if is_isolated():
		PersistedData.wipe_progress(false)


func after_each() -> void:
	MetaSkillManager.threat_override = -1
	if is_isolated():
		PersistedData.wipe_progress(false)


func _node(tree_id: StringName, node_id: StringName) -> MetaSkillNode:
	return MetaSkillManager.get_tree_def(tree_id).find_node(node_id)


func _value(tree_id: StringName, node_id: StringName, rank: int) -> float:
	return _node(tree_id, node_id).value_at_rank(rank)


## The product of a multiplicative stat over builds (tree id -> node id ->
## rank), as a spawn stacks it (1.0 when none of the nodes has it).
func _expected(builds: Dictionary, stat_name: String) -> float:
	var out := 1.0
	for tree_id: StringName in builds:
		var ranks: Dictionary = builds[tree_id]
		for node_id: StringName in ranks:
			var n := _node(tree_id, node_id)
			if n.stat_name == stat_name and n.stat_multiplicative and not n.is_ability_node():
				out *= n.value_at_rank(int(ranks[node_id]))
	return out


## Writes tree id -> (node id -> rank) into the save.
func _own_build(build: Dictionary) -> void:
	for tree_id: StringName in build:
		var ranks: Dictionary = build[tree_id]
		for node_id: StringName in ranks:
			PersistedData.set_skill_rank(tree_id, node_id, int(ranks[node_id]))


# ------------------------------------------------------------ threat maths

func test_threat_is_a_sixth_of_the_power_ranks_capped_at_4() -> void:
	var cases: Array[Vector2i] = [Vector2i(0, 0), Vector2i(5, 0), Vector2i(6, 1), Vector2i(11, 1),
		Vector2i(12, 2), Vector2i(18, 3), Vector2i(23, 3), Vector2i(24, 4), Vector2i(75, 4), Vector2i(-3, 0)]
	for c in cases:
		assert_eq(MetaSkillManager.threat_for_power(c.x), c.y, "P %d" % c.x)


func test_heroes_power_is_the_base_tree_plus_the_mean_hero_tree() -> void:
	if not require_isolated():
		return
	assert_eq(MetaSkillManager.power_ranks(HEROES, &"grount"), 0, "a fresh save")
	assert_eq(MetaSkillManager.threat_for(HEROES, &"grount"), 0)
	PersistedData.set_skill_rank(&"hero_base", &"t1_hp", 3)
	PersistedData.set_skill_rank(&"hero_river", &"r1_range", 5)
	PersistedData.set_skill_rank(&"hero_river", &"r1_hp", 2)
	PersistedData.set_skill_rank(&"hero_vlad", &"v1_dmg", 5)
	PersistedData.set_skill_rank(&"hero_vlad", &"v1_hp", 2)
	PersistedData.set_skill_rank(&"hero_ted", &"t1_hp", 5)
	PersistedData.set_skill_rank(&"hero_ted", &"t1_range", 1)
	PersistedData.set_skill_rank(&"hero_irelia", &"i1_hp", 5)
	# 7 + 7 + 6 + 5 = 25 hero ranks: the floor of the mean is 6.
	assert_eq(MetaSkillManager.power_ranks(HEROES, &"grount"), 3 + 6)
	assert_eq(MetaSkillManager.threat_for(HEROES, &"grount"), 1)
	# Cross-side and junk ranks never count: the monster trees, an id no tree
	# has, a rank above the node's max.
	PersistedData.set_skill_rank(&"monster_grount", &"g1_dmg", 5)
	PersistedData.set_skill_rank(&"monster_base", &"mt1_hp", 5)
	PersistedData.set_skill_rank(&"hero_base", &"retired_node", 9)
	PersistedData.set_skill_rank(&"hero_irelia", &"i1_hp", 50)
	assert_eq(MetaSkillManager.power_ranks(HEROES, &"grount"), 9)


func test_monster_power_is_the_base_tree_plus_the_played_monster() -> void:
	if not require_isolated():
		return
	PersistedData.set_skill_rank(&"monster_base", &"mt1_hp", 3)
	PersistedData.set_skill_rank(&"monster_base", &"mb_claws", 2)
	PersistedData.set_skill_rank(&"monster_nyxa", &"ny_hp", 5)
	PersistedData.set_skill_rank(&"monster_nyxa", &"ny_dmg", 2)
	PersistedData.set_skill_rank(&"monster_grount", &"g1_dmg", 5)
	PersistedData.set_skill_rank(&"hero_base", &"t1_hp", 3)
	assert_eq(MetaSkillManager.power_ranks(MONSTER, &"nyxa"), 5 + 7, "Nyxa's own tree, not Grount's or the heroes'")
	assert_eq(MetaSkillManager.threat_for(MONSTER, &"nyxa"), 2)
	assert_eq(MetaSkillManager.power_ranks(MONSTER, &"gorrak"), 5)
	assert_eq(MetaSkillManager.threat_for(MONSTER, &"gorrak"), 0)
	# A rank above the node's max counts as its max (mt1_hp has 3).
	PersistedData.set_skill_rank(&"monster_base", &"mt1_hp", 5)
	assert_eq(MetaSkillManager.power_ranks(MONSTER, &"gorrak"), 5)


func test_opponent_threat_reads_the_chosen_side_and_monster() -> void:
	if not require_isolated():
		return
	var monster_before := GameManager.selected_monster_id
	PersistedData.set_skill_rank(&"monster_base", &"mt1_hp", 3)
	PersistedData.set_skill_rank(&"monster_gorrak", &"gk_hp", 5)
	PersistedData.set_skill_rank(&"monster_gorrak", &"gk_dmg", 5)
	GameManager.select_monster(&"gorrak", false)
	play_side(MONSTER)
	assert_eq(MetaSkillManager.opponent_threat(), 2, "13 Gorrak ranks: the AI heroes face threat 2")
	play_side(HEROES)
	assert_eq(MetaSkillManager.opponent_threat(), 0, "the heroes own nothing: the AI Gorrak is unbuilt")
	GameManager.select_monster(monster_before, false)


# ------------------------------------------------------------ the AI build

func test_ai_build_takes_3t_character_and_2t_base_entries() -> void:
	var trees: Array[StringName] = [MetaSkillManager.TREE_HERO_BASE, MetaSkillManager.TREE_MONSTER_BASE]
	for def in GameManager.ROSTER.all():
		trees.append(def.skill_tree_id())
	for tree_id in trees:
		var per := 2 if MetaSkillManager.is_base_tree(tree_id) else 3
		for threat in range(0, 6):
			var size := MetaSkillManager.ai_build_size(tree_id, threat)
			assert_eq(size, mini(threat, 4) * per, "%s at threat %d" % [tree_id, threat])
		# An AI build never holds a capstone, not even at threat 4 (fix batch
		# G3: Brood Mother, Whirlwind and Titan Form won 83-92 % of the
		# threat-4 parity matches; the player's own capstone stays theirs).
		var capstones := 0
		var full := MetaSkillManager.ai_build_ranks(tree_id, MetaSkillManager.ai_build_entries(tree_id, 4))
		for id: StringName in full:
			if _node(tree_id, id).capstone:
				capstones += 1
		assert_eq(capstones, 0, "%s: capstones at threat 4" % tree_id)


func test_ai_build_ranks_are_the_order_prefix() -> void:
	# A throwaway tree: each entry is one more rank, capped at the node's max;
	# unknown and hidden ids are skipped.
	var t := MetaSkillTree.new()
	t.id = THROWAWAY
	for spec: Array in [[&"a", 2, false], [&"b", 3, false], [&"secret", 1, true]]:
		var n := MetaSkillNode.new()
		n.id = spec[0]
		n.max_rank = spec[1]
		n.hidden = spec[2]
		n.stat_name = "max_health"
		n.stat_value = 1.1
		t.nodes.append(n)
	t.ai_build_order.assign([&"a", &"b", &"a", &"a", &"gone", &"secret", &"b"])
	MetaSkillManager.register_tree(t)
	assert_eq(MetaSkillManager.ai_build_ranks(THROWAWAY, 0), {})
	assert_eq(MetaSkillManager.ai_build_ranks(THROWAWAY, 1), {&"a": 1})
	assert_eq(MetaSkillManager.ai_build_ranks(THROWAWAY, 3), {&"a": 2, &"b": 1})
	assert_eq(MetaSkillManager.ai_build_ranks(THROWAWAY, 4), {&"a": 2, &"b": 1}, "a third rank of a 2-rank node is capped")
	assert_eq(MetaSkillManager.ai_build_ranks(THROWAWAY, 99), {&"a": 2, &"b": 2}, "unknown and hidden ids are skipped")
	assert_eq(MetaSkillManager.ai_build_ranks(&"no_such_tree", 6), {})
	MetaSkillManager.trees.erase(THROWAWAY)
	var nyxa := MetaSkillManager.monster_tree_id(&"nyxa")
	assert_eq(MetaSkillManager.ai_build_entries(nyxa, 2), 6)
	assert_eq(MetaSkillManager.ai_build_entries(MetaSkillManager.TREE_HERO_BASE, 2), 4)
	assert_eq(MetaSkillManager.ai_build_entries(nyxa, 9), 12, "capped at threat 4")


# ------------------------------------------------------------ the side rule

func test_the_ai_monster_never_inherits_the_players_unlocks() -> void:
	if not require_isolated():
		return
	play_side(HEROES)
	PersistedData.set_skill_rank(&"monster_grount", &"g1_dmg", 5)
	PersistedData.set_skill_rank(&"monster_grount", &"g4_titan", 1)
	PersistedData.set_skill_rank(&"monster_base", &"mt1_hp", 3)
	var mods: Dictionary = MetaSkillManager.collect_monster_modifiers(&"grount")
	assert_true(mods.is_empty(), "threat 0: the AI Grount has no build, whatever the save owns: %s" % str(mods))
	var g := (await spawn_frozen(GROUNT, Vector2(3000, 0))) as MonsterBase
	assert_near(g._meta_damage_mult, 1.0, 0.0001)
	assert_false(g.is_titan() or g._meta_titan, "Titan Form is the player's, not the AI's")
	assert_true(g.debug_meta_line().contains(" AI T0 0+0 nodes: "), g.debug_meta_line())
	g.queue_free()
	await wait_frames(1)


func test_the_ai_monster_gets_its_build_from_the_heroes_power() -> void:
	if not require_isolated():
		return
	play_side(HEROES)
	# hero_base 6 ranks = P 6 = threat 1: the first 3 entries of Grount's
	# order and the first 2 of monster_base's.
	PersistedData.set_skill_rank(&"hero_base", &"t1_hp", 3)
	PersistedData.set_skill_rank(&"hero_base", &"t1_dmg", 3)
	var grount := MetaSkillManager.monster_tree_id(&"grount")
	var base := MetaSkillManager.TREE_MONSTER_BASE
	var builds := {grount: MetaSkillManager.ai_build_ranks(grount, 3), base: MetaSkillManager.ai_build_ranks(base, 2)}
	var g := (await spawn_frozen(GROUNT, Vector2(3000, 0))) as MonsterBase
	assert_near(g._meta_damage_mult, _expected(builds, "monster_damage_mult"), 0.0001)
	assert_near(g._meta_damage_taken_mult, _expected(builds, "monster_damage_taken_mult"), 0.0001)
	assert_near(g._meta_speed_mult, _expected(builds, "monster_speed_mult"), 0.0001)
	assert_near(g._meta_health_mult, _expected(builds, "monster_health_mult"), 0.0001)
	assert_true(_expected(builds, "monster_health_mult") * _expected(builds, "monster_damage_mult") > 1.0,
			"threat 1 buys Grount something")
	assert_true(g.debug_meta_line().contains(" AI T1 3+2 nodes: "), g.debug_meta_line())
	g.queue_free()
	await wait_frames(1)


func test_the_played_monster_applies_the_save_and_the_ai_heroes_their_build() -> void:
	if not require_isolated():
		return
	play_side(MONSTER)
	var monster_before := GameManager.selected_monster_id
	GameManager.select_monster(&"grount", false)
	# The save's hero ranks are the player's other side: never the AI heroes'.
	PersistedData.set_skill_rank(&"hero_base", &"t1_hp", 3)
	PersistedData.set_skill_rank(&"hero_vlad", &"v1_hp", 5)
	var vlad := (await spawn_frozen(VLAD, Vector2(0, 600))) as HeroBase
	var stats := vlad.get_node("HeroStats") as HeroStatsComponent
	assert_near(stats.get_modifier("max_health", true), 1.0, 0.0001, "threat 0: no hero ranks")
	vlad.queue_free()
	# 12 monster ranks = threat 2: the first 4 entries of hero_base's order and
	# the first 6 of Vlad's.
	PersistedData.set_skill_rank(&"monster_base", &"mt1_hp", 3)
	PersistedData.set_skill_rank(&"monster_grount", &"g1_dmg", 5)
	PersistedData.set_skill_rank(&"monster_grount", &"g1_hide", 4)
	assert_eq(MetaSkillManager.opponent_threat(), 2)
	vlad = (await spawn_frozen(VLAD, Vector2(0, 600))) as HeroBase
	stats = vlad.get_node("HeroStats") as HeroStatsComponent
	var base := MetaSkillManager.TREE_HERO_BASE
	var own := MetaSkillManager.hero_tree_id(&"vlad")
	var builds := {base: MetaSkillManager.ai_build_ranks(base, 4), own: MetaSkillManager.ai_build_ranks(own, 6)}
	for stat: String in ["max_health", "attack_damage", "attack_speed", "move_speed"]:
		assert_near(stats.get_modifier(stat, true), _expected(builds, stat), 0.0001, stat)
	assert_true(_expected(builds, "max_health") > 1.0, "threat 2 buys Vlad health")
	# The played Grount applies the save (g1_dmg 5, mt1_hp 3), not an AI build.
	var g := (await spawn_frozen(GROUNT, Vector2(3000, 0))) as MonsterBase
	assert_near(g._meta_damage_mult, _value(MetaSkillManager.monster_tree_id(&"grount"), &"g1_dmg", 5), 0.0001)
	assert_near(g._meta_health_mult, _value(MetaSkillManager.TREE_MONSTER_BASE, &"mt1_hp", 3), 0.0001)
	assert_true(g.debug_meta_line().contains(" save nodes: "), g.debug_meta_line())
	vlad.queue_free()
	g.queue_free()
	await wait_frames(1)
	GameManager.select_monster(monster_before, false)


# ------------------------------------------------------------ a side's AI build

func test_a_sides_ai_build_holds_3t_per_character_and_2t_base() -> void:
	for threat in range(0, 5):
		var heroes := MetaSkillManager.side_ai_build(HEROES, &"", threat)
		var hero_trees: Array = [MetaSkillManager.TREE_HERO_BASE]
		for id in GameManager.ROSTER.hero_ids():
			hero_trees.append(MetaSkillManager.hero_tree_id(id))
		assert_eq(heroes.keys(), hero_trees)
		for tree_id: StringName in heroes:
			assert_eq(heroes[tree_id], MetaSkillManager.ai_build_ranks(tree_id, MetaSkillManager.ai_build_entries(tree_id, threat)))
		for monster_id in GameManager.ROSTER.monster_ids():
			var build := MetaSkillManager.side_ai_build(MONSTER, monster_id, threat)
			assert_eq(build.keys(), [MetaSkillManager.TREE_MONSTER_BASE, MetaSkillManager.monster_tree_id(monster_id)])


## tools/sim.sh THREAT=N: the played side owns its own AI build (5N power
## ranks) and threat_override puts the opponent at N.
func test_the_parity_check_gives_both_sides_their_threat_build() -> void:
	if not require_isolated():
		return
	for threat in range(0, 5):
		PersistedData.wipe_progress(false)
		var build := MetaSkillManager.side_ai_build(HEROES, &"", threat)
		_own_build(build)
		assert_eq(MetaSkillManager.power_ranks(HEROES, &""), 5 * threat, "heroes at threat %d" % threat)
		for monster_id in GameManager.ROSTER.monster_ids():
			PersistedData.wipe_progress(false)
			_own_build(MetaSkillManager.side_ai_build(MONSTER, monster_id, threat))
			assert_eq(MetaSkillManager.power_ranks(MONSTER, monster_id), 5 * threat, "%s at threat %d" % [monster_id, threat])
	play_side(HEROES)
	assert_eq(MetaSkillManager.opponent_threat(), 0, "the save holds a monster build only: the heroes' P is 0")
	MetaSkillManager.threat_override = 3
	assert_eq(MetaSkillManager.opponent_threat(), 3, "the override wins")
	MetaSkillManager.threat_override = 9
	assert_eq(MetaSkillManager.opponent_threat(), 4, "capped at 4")
	MetaSkillManager.threat_override = -1


# ------------------------------------------------------------ F3

func test_the_f3_threat_line_names_the_ai_build() -> void:
	var monster_before := GameManager.selected_monster_id
	var threat_before := GameManager.match_threat
	GameManager.select_monster(&"nyxa", false)
	GameManager.match_threat = 2
	play_side(HEROES)
	var line := GameManager.debug_threat_line()
	assert_true(line.begins_with("Threat 2  played heroes P "), line)
	assert_true(line.ends_with("AI monster: 6 nyxa + 4 base ranks"), line)
	play_side(MONSTER)
	line = GameManager.debug_threat_line()
	assert_true(line.begins_with("Threat 2  played monster P "), line)
	assert_true(line.ends_with("AI heroes: 6/6/6/6 + 4 base ranks"), line)
	GameManager.match_threat = threat_before
	GameManager.select_monster(monster_before, false)
