extends TestCase

## Ability-modifying skill nodes apply to per-entity ability copies, never to
## the shared .tres, and survive monster stage re-application.

const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"
const RIVER := "res://Scenes/NPCs/Hero/Heros/Healer/River/River.tscn"
const BAT := "res://Scenes/NPCs/Mob/Mobs/Bat/Bat.tscn"


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


func _frozen(path: String, pos: Vector2) -> Node2D:
	var e := await spawn_entity(path, pos)
	TickScheduler.unregister(e)
	return e


func test_stacked_modifiers_apply_to_the_unmodified_base() -> void:
	var dash := BullRamDash.new()
	dash.apply_meta_modifier("stun_duration", 0.5, false)
	dash.apply_meta_modifier("stun_duration", 0.5, false)
	assert_near(dash.stun_duration, 1.0, 0.0001, "0 + 0.5 + 0.5, not compounded")
	dash.apply_meta_modifier("dash_distance", 1.1, true)
	dash.apply_meta_modifier("dash_distance", 1.1, true)
	assert_near(dash.dash_distance, 300.0 * 1.21, 0.01)
	var shot := RiverBasicAttack.new()
	shot.apply_meta_modifier("extra_targets", 2.0, false)
	assert_eq(typeof(shot.extra_targets), TYPE_INT, "int exports stay int")
	assert_eq(shot.extra_targets, 2)
	var plain := AbilityBase.new()
	plain.ability_range = 100.0
	plain.apply_meta_modifier("ability_range", 1.2, true)
	plain.apply_stage_stats(1)
	plain.apply_stage_stats(2)
	assert_near(plain.ability_range, 120.0, 0.001, "no compounding through stage re-application")


func test_early_slam_unlocks_ground_slam_at_stage_1() -> void:
	if not _isolated():
		skip("user:// is not the isolated test dir")
		return
	var locked := await _frozen(GROUNT, Vector2(3000, 0))
	assert_false(locked.ability_3.is_unlocked_at(1), "Ground Slam is a stage-2 unlock by default")
	assert_true(locked.ability_3.cooldown >= AbilityBase.LOCKED_COOLDOWN)
	assert_false(locked._slam_ready())
	assert_false(locked._cast("ability_3", locked.ability_3, null), "a locked ability never casts")
	locked.queue_free()
	PersistedData.add_currency(PersistedData.LEAVES, 2000)
	var tree := MetaSkillManager.monster_tree_id(&"grount")
	assert_true(MetaSkillManager.unlock(tree, &"g1_stun"))
	assert_true(MetaSkillManager.unlock(tree, &"g2_earlyslam"))
	var g := await _frozen(GROUNT, Vector2(3000, 0))
	var slam: AbilityBase = g.ability_3
	assert_eq(g.current_stage, 1)
	assert_true(slam.is_unlocked_at(1))
	assert_near(slam.cooldown, 15.0, 0.001, "the first stage with data (stage 2) supplies the numbers")
	assert_near(float(slam.get("slam_radius")), 120.0, 0.5)
	assert_true(g._slam_ready())
	g.queue_free()


func test_stunning_charge_stuns_what_the_dash_hits() -> void:
	if not _isolated():
		skip("user:// is not the isolated test dir")
		return
	PersistedData.add_currency(PersistedData.LEAVES, 1000)
	assert_true(MetaSkillManager.unlock(MetaSkillManager.monster_tree_id(&"grount"), &"g1_stun"))
	var g := await _frozen(GROUNT, Vector2(0, 0))
	var v := await _frozen(VLAD, Vector2(220, 0))
	assert_near(float(g.ability_2.get("stun_duration")), 0.5, 0.001)
	g.target = v.get_node("Body")
	g.target_entity = v
	assert_true(g._cast("ability_2", g.ability_2, v))
	await wait_seconds(0.8)
	assert_true(v.is_stunned(), "the dash target is stunned")
	v._tick(0.3)
	assert_true(v.is_stunned(), "still stunned after 0.3 s")
	v._tick(0.3)
	assert_false(v.is_stunned(), "recovers after 0.5 s")
	g.queue_free()
	v.queue_free()


func test_triple_shot_hits_two_more_enemies_near_the_target() -> void:
	if not _isolated():
		skip("user:// is not the isolated test dir")
		return
	PersistedData.add_currency(PersistedData.STEEL, 1000)
	var tree := MetaSkillManager.hero_tree_id(&"river")
	assert_true(MetaSkillManager.unlock(tree, &"r1_range"))
	assert_true(MetaSkillManager.unlock(tree, &"r2_triple"))
	var river := await _frozen(RIVER, Vector2(0, 0))
	var main := await _frozen(BAT, Vector2(200, 0))
	var near_a := await _frozen(BAT, Vector2(260, 0))
	var near_b := await _frozen(BAT, Vector2(200, 80))
	var near_c := await _frozen(BAT, Vector2(200, -120))
	var far := await _frozen(BAT, Vector2(200, 600))
	var shot: AbilityBase = (river.get_node("AbilitySystem") as AbilitySystem).basic_attack
	assert_eq(int(shot.get("extra_targets")), 2)
	var bats: Array[Node2D] = [main, near_a, near_b, near_c, far]
	shot.execute(river, main)
	await wait_frames(2)
	var hit := 0
	for b in bats:
		if (b as EntityBase).get_health() < (b as EntityBase).get_max_health():
			hit += 1
	assert_eq(hit, 3, "main target + the 2 nearest within the radius")
	assert_true((near_a as EntityBase).get_health() < (near_a as EntityBase).get_max_health(), "nearest extra hit")
	assert_eq((near_c as EntityBase).get_health(), (near_c as EntityBase).get_max_health(), "third-nearest left alone")
	assert_eq((far as EntityBase).get_health(), (far as EntityBase).get_max_health(), "out of the radius")
	for n in [river, main, near_a, near_b, near_c, far]:
		n.queue_free()
