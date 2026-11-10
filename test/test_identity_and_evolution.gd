extends TestCase

## Character ids come from the stat resources; monster evolution is announced
## on the EventBus and the per-monster tree reaches the spawned monster.

const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"


func before_each() -> void:
	if is_isolated():
		PersistedData.wipe_progress(false)


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
	if not require_isolated():
		return
	play_side(MatchRewards.Side.MONSTER)  # the played side applies the save's trees
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


## Back-to-back evolutions: the second flash replaces the first and both end at
## WHITE. The old sprite flash restored the tint it captured, which was
## mid-flash here, and the Grount stayed tinted; the rig's flash (on screen)
## decays to WHITE and the hidden sprite is never tinted.
func test_evolution_flashes_end_white() -> void:
	var grount := (await spawn_frozen(GROUNT, Vector2(3000, 0))) as MonsterBase
	var rig := grount.get_node(^"Rig") as CharacterRig
	rig.set_on_screen(true)
	grount.gain_xp(1000.0)
	await wait_seconds(0.1)  # first flash on its way back
	assert_true(rig.body.modulate.r > 1.0, "the first flash is still running")
	grount.gain_xp(0.0)
	assert_eq(grount.current_stage, 3)
	await wait_seconds(0.7)
	assert_eq(rig.body.modulate, Color.WHITE, "no flash tint left on the rig")
	assert_eq(grount.animated_sprite.modulate, Color.WHITE, "the hidden sprite is never tinted")
	grount.queue_free()
