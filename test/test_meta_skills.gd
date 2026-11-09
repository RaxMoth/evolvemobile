extends TestCase

## Tier gating + spending. These WRITE the save file, so they only run when
## user:// is the isolated test directory that tools/run_tests.sh sets up.

const TREE := &"hero_base"


func before_each() -> void:
	if is_isolated():
		PersistedData.wipe_progress(false)


## A base tree opens tier 2 once 4 ranks are owned in it (POINTS gate 0/4/10/18).
func test_tier_two_opens_after_four_ranks_in_the_tree() -> void:
	if not require_isolated():
		return
	PersistedData.add_currency(PersistedData.GOLD, 1000)
	assert_eq(MetaSkillManager.node_state(TREE, &"t2_dmg"), MetaSkillManager.NodeState.TIER_GATED, "tier 2 locked before any rank")
	assert_false(MetaSkillManager.unlock(TREE, &"t2_dmg"))
	assert_true(MetaSkillManager.unlock(TREE, &"t1_hp"))
	assert_eq(PersistedData.get_currency(PersistedData.GOLD), 960, "Iron Skin rank 1 costs 40")
	assert_true(MetaSkillManager.rank_up(TREE, &"t1_hp"))
	assert_true(MetaSkillManager.rank_up(TREE, &"t1_hp"))
	assert_eq(PersistedData.get_currency(PersistedData.GOLD), 960 - 70 - 110, "ranks 2 and 3: 70 + 110")
	assert_false(MetaSkillManager.is_node_available(TREE, &"t2_hp"), "3 ranks: tier 2 still closed")
	assert_true(MetaSkillManager.unlock(TREE, &"t1_dmg"))
	assert_eq(MetaSkillManager.points_spent(TREE), 4)
	assert_true(MetaSkillManager.is_node_available(TREE, &"t2_dmg"), "4 ranks open tier 2; its parent Sharp Edge is owned")
	assert_eq(MetaSkillManager.node_state(TREE, &"t2_atkspd"), MetaSkillManager.NodeState.REQUIRES_MISSING, "Quick Strike needs Light Step")
	assert_true(MetaSkillManager.unlock(TREE, &"t2_dmg"))
	assert_eq(PersistedData.get_currency(PersistedData.GOLD), 740 - 100, "t2 rank 1 costs 100")
	assert_true(MetaSkillManager.is_unlocked(TREE, &"t2_dmg"))
	assert_false(MetaSkillManager.unlock(TREE, &"t2_dmg"), "unlock() is rank 1 only")
	assert_eq(PersistedData.get_currency(PersistedData.GOLD), 640, "no double charge")


func test_unlock_fails_when_unaffordable() -> void:
	if not require_isolated():
		return
	PersistedData.add_currency(PersistedData.GOLD, 30)
	assert_false(MetaSkillManager.unlock(TREE, &"t1_hp"), "rank 1 costs 40")
	assert_eq(PersistedData.get_currency(PersistedData.GOLD), 30)
	assert_false(MetaSkillManager.is_unlocked(TREE, &"t1_hp"))
