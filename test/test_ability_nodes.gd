extends TestCase

## Ability-modifying skill nodes apply to per-entity ability copies, never to
## the shared .tres, and survive monster stage re-application.

const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"


func _isolated() -> bool:
	return OS.get_user_data_dir().contains("evolvemobile_tests")


func before_each() -> void:
	if _isolated():
		PersistedData.wipe_progress(false)


func test_hero_ability_node_modifies_only_that_heros_copy() -> void:
	if not _isolated():
		skip("user:// is not the isolated test dir")
		return
	PersistedData.add_currency(PersistedData.STEEL, 1000)
	assert_true(MetaSkillManager.unlock(MetaSkillManager.hero_tree_id(&"vlad"), &"v1_dmg"))
	assert_true(MetaSkillManager.unlock(MetaSkillManager.hero_tree_id(&"vlad"), &"v2_bombaoe"))
	var vlad := await spawn_entity(VLAD, Vector2(0, 0))
	var abilities := vlad.get_node("AbilitySystem") as AbilitySystem
	var ult: AbilityBase = abilities.ultimate_ability
	assert_eq(ult.ability_name, "Blood Bomb")
	assert_true(ult.resource_path.is_empty(), "hero owns a copy of the ability")
	assert_near(ult.area_of_effect, 150.0 * 1.25, 0.01)
	var shared: AbilityBase = load("res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Abilities/ult/ult_bomb.tres") if ResourceLoader.exists("res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Abilities/ult/ult_bomb.tres") else null
	if shared:
		assert_near(shared.area_of_effect, 150.0, 0.01, "shared resource untouched")
	var other := await spawn_entity(VLAD, Vector2(3000, 0))
	# Both Vlads get it (same tree) but each on its own copy.
	assert_true((other.get_node("AbilitySystem") as AbilitySystem).ultimate_ability != ult)
	vlad.queue_free()
	other.queue_free()


func test_monster_ability_nodes_survive_evolution() -> void:
	if not _isolated():
		skip("user:// is not the isolated test dir")
		return
	PersistedData.add_currency(PersistedData.LEAVES, 2000)
	var tree := MetaSkillManager.monster_tree_id(&"grount")
	assert_true(MetaSkillManager.unlock(tree, &"g1_dmg"))
	assert_true(MetaSkillManager.unlock(tree, &"g2_cleavecd"))
	assert_true(MetaSkillManager.unlock(tree, &"g3_dash"))
	var grount := await spawn_entity(GROUNT, Vector2(3000, 0))
	var cleave: AbilityBase = grount.ability_1
	var dash: AbilityBase = grount.ability_2
	assert_eq(cleave.ability_name, "Front Cleave")
	assert_eq(dash.ability_name, "Ram Dash")
	assert_true(cleave.resource_path.is_empty(), "monster owns copies")
	var base_cd: float = cleave.get_cooldown_for_stage(1)
	assert_near(cleave.cooldown, base_cd * 0.85, 0.001)
	assert_near(float(dash.get("dash_distance")), 300.0 * 1.33, 0.01)
	grount.gain_xp(1000.0)  # -> stage 2 re-applies stage stats
	assert_eq(grount.current_stage, 2)
	assert_near(cleave.cooldown, cleave.get_cooldown_for_stage(2) * 0.85, 0.001, "multiplier re-applied after evolution")
	grount.queue_free()
