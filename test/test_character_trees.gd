extends TestCase

## Per-hero (Steel) and per-monster (Leaves) skill trees.

const RIVER := "res://Scenes/NPCs/Hero/Heros/Healer/River/River.tscn"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"


func before_each() -> void:
	if is_isolated():
		PersistedData.wipe_progress(false)


func test_every_character_has_a_tree_with_the_right_currency() -> void:
	for hero_id in GameManager.KNOWN_HERO_IDS:
		var t: MetaSkillTree = MetaSkillManager.get_tree_def(MetaSkillManager.hero_tree_id(hero_id))
		assert_true(t != null, "tree for %s" % hero_id)
		if t == null:
			continue
		# Tier 4 holds the capstones, shown once their hero's code landed (5.4).
		assert_eq(t.max_tier(), 4 if not t.capstones().is_empty() else 3, "%s: tier 4 is the capstones' row" % hero_id)
		for n in t.nodes_in_tier(4):
			assert_true(n.capstone, "%s/%s: tier 4 holds only capstones" % [hero_id, n.id])
		assert_eq(t.owner_id, hero_id)
		assert_eq(t.gate_kind, MetaSkillTree.GateKind.LEVEL)
		for n in t.nodes:
			assert_eq(n.currency, PersistedData.STEEL, "%s/%s costs Steel" % [hero_id, n.id])
			assert_false(n.stat_name.begins_with("monster_"))
	# Every monster tree ends in a row of three capstones, one per branch, all
	# with their code since 6.6 (nothing hidden).
	for d in GameManager.ROSTER.monsters:
		var mt: MetaSkillTree = MetaSkillManager.get_tree_def(d.skill_tree_id())
		assert_true(mt != null, "tree for %s" % d.character_id())
		if mt == null:
			continue
		assert_eq(mt.max_tier(), 4, "%s: tier 4 is the capstones' row" % d.character_id())
		var branches: Array[int] = []
		for n in mt.nodes_in_tier(4):
			assert_true(n.capstone, "%s/%s: tier 4 holds only capstones" % [d.character_id(), n.id])
			branches.append(n.branch)
		assert_eq(branches, [0, 1, 2] as Array[int], "%s: one capstone per branch" % d.character_id())
		assert_eq(mt.shown_nodes().size(), mt.nodes.size(), "%s: no hidden node left" % d.character_id())
	var g: MetaSkillTree = MetaSkillManager.get_tree_def(MetaSkillManager.monster_tree_id(&"grount"))
	assert_true(g != null)
	if g != null:
		for n in g.nodes:
			assert_eq(n.currency, PersistedData.LEAVES)
			if n.is_ability_node():
				assert_false(n.ability_name.is_empty())
			else:
				assert_true(n.stat_name.begins_with("monster_"), "%s is a monster stat key" % n.id)


func test_hero_tree_applies_only_to_that_hero() -> void:
	if not require_isolated():
		return
	PersistedData.add_currency(PersistedData.STEEL, 1000)
	assert_true(MetaSkillManager.unlock(MetaSkillManager.hero_tree_id(&"river"), &"r1_range"))
	assert_eq(PersistedData.get_currency(PersistedData.STEEL), 960, "rank 1 costs 40")
	var river := await spawn_entity(RIVER, Vector2(0, 0))
	var vlad := await spawn_entity(VLAD, Vector2(3000, 0))
	assert_eq(MetaSkillManager.hero_id_of(river), &"river")
	assert_eq(MetaSkillManager.hero_id_of(vlad), &"vlad")
	var river_stats := river.get_node("HeroStats") as HeroStatsComponent
	var vlad_stats := vlad.get_node("HeroStats") as HeroStatsComponent
	assert_near(river_stats.get_attack_range(), river_stats.base_stats.base_attack_range * 1.08, 0.01, "River gets +8% range")
	assert_near(vlad_stats.get_attack_range(), vlad_stats.base_stats.base_attack_range, 0.01, "Vlad is untouched by River's tree")


func test_monster_tree_merges_with_base_tree() -> void:
	if not require_isolated():
		return
	PersistedData.add_currency(PersistedData.LEAVES, 500)
	PersistedData.add_currency(PersistedData.GOLD, 500)
	assert_true(MetaSkillManager.unlock(MetaSkillManager.monster_tree_id(&"grount"), &"g1_dmg"))
	assert_true(MetaSkillManager.unlock(MetaSkillManager.TREE_MONSTER_BASE, &"mt1_speed"))
	var base_only: Dictionary = MetaSkillManager.collect_monster_modifiers()
	assert_near(float(base_only.get("monster_speed_mult", 1.0)), 1.05)
	assert_false(base_only.has("monster_damage_mult"), "per-monster node needs the id")
	var merged: Dictionary = MetaSkillManager.collect_monster_modifiers(&"grount")
	assert_near(float(merged.get("monster_damage_mult", 1.0)), 1.10)
	assert_near(float(merged.get("monster_speed_mult", 1.0)), 1.05)
	assert_eq(PersistedData.get_currency(PersistedData.LEAVES), 460, "Heavy Horns rank 1: 40 Leaves")
	assert_eq(PersistedData.get_currency(PersistedData.GOLD), 460, "Faster Hunt rank 1: 40 Gold")
