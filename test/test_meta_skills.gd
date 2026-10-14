extends TestCase

## Tier gating + spending. These WRITE the save file, so they only run when
## user:// is the isolated test directory that tools/run_tests.sh sets up.

const TREE := &"hero_base"


func _isolated() -> bool:
	return OS.get_user_data_dir().contains("evolvemobile_tests")


func before_each() -> void:
	if _isolated():
		PersistedData.wipe_progress()


func test_tier_two_is_gated_until_tier_one_unlocked() -> void:
	if not _isolated():
		skip("user:// is not the isolated test dir")
		return
	PersistedData.add_currency(PersistedData.GOLD, 1000)
	assert_false(MetaSkillManager.is_node_available(TREE, &"t2_dmg"), "tier 2 locked before any tier 1 node")
	assert_false(MetaSkillManager.unlock(TREE, &"t2_dmg"))
	assert_true(MetaSkillManager.unlock(TREE, &"t1_hp"))
	assert_eq(PersistedData.get_currency(PersistedData.GOLD), 900, "t1 costs 100")
	assert_true(MetaSkillManager.is_node_available(TREE, &"t2_dmg"))
	assert_true(MetaSkillManager.unlock(TREE, &"t2_dmg"))
	assert_eq(PersistedData.get_currency(PersistedData.GOLD), 600, "t2 costs 300")
	assert_true(MetaSkillManager.is_unlocked(TREE, &"t2_dmg"))
	assert_false(MetaSkillManager.unlock(TREE, &"t2_dmg"), "cannot unlock twice")
	assert_eq(PersistedData.get_currency(PersistedData.GOLD), 600, "no double charge")


func test_unlock_fails_when_unaffordable() -> void:
	if not _isolated():
		skip("user:// is not the isolated test dir")
		return
	PersistedData.add_currency(PersistedData.GOLD, 50)
	assert_false(MetaSkillManager.unlock(TREE, &"t1_hp"))
	assert_eq(PersistedData.get_currency(PersistedData.GOLD), 50)
	assert_false(MetaSkillManager.is_unlocked(TREE, &"t1_hp"))
