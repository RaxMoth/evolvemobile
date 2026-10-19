extends TestCase

## Character ids come from the stat resources; monster evolution is announced
## on the EventBus and the per-monster tree reaches the spawned monster.

const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"


func _isolated() -> bool:
	return OS.get_user_data_dir().contains("evolvemobile_tests")


func before_each() -> void:
	if _isolated():
		PersistedData.wipe_progress()


func test_hero_and_monster_ids_come_from_resources() -> void:
	var vlad := await spawn_entity(VLAD, Vector2(0, 0))
	vlad.name = "SomethingElse"  # the old name-substring convention must not be needed
	assert_eq(GameManager._hero_id_from(vlad), &"vlad")
	var grount := await spawn_entity(GROUNT, Vector2(3000, 0))
	assert_eq(grount.monster_stats.monster_id, &"grount")
	var stats := vlad.get_node("HeroStats") as HeroStatsComponent
	assert_near(stats.base_stats.vision_radius, 250.0)
	vlad.queue_free()
	grount.queue_free()


func test_per_monster_tree_reaches_the_spawned_monster() -> void:
	if not _isolated():
		skip("user:// is not the isolated test dir")
		return
	PersistedData.add_currency(PersistedData.LEAVES, 500)
	assert_true(MetaSkillManager.unlock(MetaSkillManager.monster_tree_id(&"grount"), &"g1_dmg"))
	var grount := await spawn_entity(GROUNT, Vector2(3000, 0))
	assert_near(grount._meta_damage_mult, 1.10, 0.0001, "monster_grount node applied via monster_stats.monster_id")
	grount.queue_free()


func test_evolution_is_announced_on_the_event_bus() -> void:
	var grount := await spawn_entity(GROUNT, Vector2(3000, 0))
	var seen := []
	var cb := func(monster: Node, stage: int) -> void: seen.append([monster, stage])
	EventBus.monster_evolved.connect(cb)
	grount.gain_xp(1000.0)
	EventBus.monster_evolved.disconnect(cb)
	assert_eq(grount.current_stage, 2)
	assert_eq(seen.size(), 1)
	assert_true(seen[0][0] == grount and seen[0][1] == 2)
	grount.queue_free()
