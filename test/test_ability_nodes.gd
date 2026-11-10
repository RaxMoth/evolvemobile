extends TestCase

## Ability-modifying skill nodes apply to per-entity ability copies, never to
## the shared .tres, and survive monster stage re-application.

const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"
const RIVER := "res://Scenes/NPCs/Hero/Heros/Healer/River/River.tscn"
const BAT := "res://Scenes/NPCs/Mob/Mobs/Bat/Bat.tscn"


func before_each() -> void:
	if is_isolated():
		PersistedData.wipe_progress(false)


func after_each() -> void:
	get_tree().paused = false


func test_hero_ability_node_modifies_only_that_heros_copy() -> void:
	if not require_isolated():
		return
	# Owned outright (buying through the gates is test_skill_trees_v2's job).
	PersistedData.set_unlocked_skills(MetaSkillManager.hero_tree_id(&"vlad"), ["v1_dmg", "v2_bombaoe"])
	var vlad := await spawn_entity(VLAD, Vector2(0, 0))
	var abilities := vlad.get_node("AbilitySystem") as AbilitySystem
	var ult: AbilityBase = abilities.ultimate_ability
	assert_eq(ult.ability_name, "Blood Bomb")
	assert_true(ult.resource_path.is_empty(), "hero owns a copy of the ability")
	assert_near(ult.area_of_effect, 150.0 * 1.25, 0.01)
	var shared := load("res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Abilities/ult/ult.tres") as AbilityBase
	assert_true(shared != null, "shared Blood Bomb resource")
	assert_near(shared.area_of_effect, 150.0, 0.01, "shared resource untouched")
	var other := await spawn_entity(VLAD, Vector2(3000, 0))
	# Both Vlads get it (same tree) but each on its own copy.
	assert_true((other.get_node("AbilitySystem") as AbilitySystem).ultimate_ability != ult)
	vlad.queue_free()
	other.queue_free()


func test_monster_ability_nodes_survive_evolution() -> void:
	if not require_isolated():
		return
	play_side(MatchRewards.Side.MONSTER)  # the played side applies the save's trees
	var tree := MetaSkillManager.monster_tree_id(&"grount")
	PersistedData.set_unlocked_skills(tree, ["g1_dmg", "g2_cleavecd", "g3_dash"])
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
	if not require_isolated():
		return
	play_side(MatchRewards.Side.MONSTER)  # the played side applies the save's trees
	var locked := await spawn_frozen(GROUNT, Vector2(3000, 0))
	assert_false(locked.ability_3.is_unlocked_at(1), "Ground Slam is a stage-2 unlock by default")
	assert_true(locked.ability_3.cooldown >= AbilityBase.LOCKED_COOLDOWN)
	assert_false(locked._slam_ready())
	assert_false(locked._cast("ability_3", locked.ability_3, null), "a locked ability never casts")
	locked.queue_free()
	var tree := MetaSkillManager.monster_tree_id(&"grount")
	PersistedData.set_unlocked_skills(tree, ["g1_stun", "g2_earlyslam"])
	var g := await spawn_frozen(GROUNT, Vector2(3000, 0))
	var slam: AbilityBase = g.ability_3
	assert_eq(g.current_stage, 1)
	assert_true(slam.is_unlocked_at(1))
	assert_near(slam.cooldown, 15.0, 0.001, "the first stage with data (stage 2) supplies the numbers")
	assert_near(float(slam.get("slam_radius")), 120.0, 0.5)
	assert_true(g._slam_ready())
	g.queue_free()


func test_stunning_charge_stuns_what_the_dash_hits() -> void:
	if not require_isolated():
		return
	play_side(MatchRewards.Side.MONSTER)  # the played side applies the save's trees
	PersistedData.add_currency(PersistedData.LEAVES, 1000)
	assert_true(MetaSkillManager.unlock(MetaSkillManager.monster_tree_id(&"grount"), &"g1_stun"))
	var g := await spawn_frozen(GROUNT, Vector2(0, 0))
	var v := await spawn_frozen(VLAD, Vector2(220, 0))
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
	if not require_isolated():
		return
	PersistedData.add_currency(PersistedData.STEEL, 1000)
	PersistedData.add_hero_xp(&"river", 300)  # Lv 3 opens tier 2
	var tree := MetaSkillManager.hero_tree_id(&"river")
	assert_true(MetaSkillManager.unlock(tree, &"r1_range"))
	assert_true(MetaSkillManager.unlock(tree, &"r2_triple"), "tier 2, after its parent Long Scope")
	var river := await spawn_frozen(RIVER, Vector2(0, 0))
	var main := await spawn_frozen(BAT, Vector2(200, 0))
	var near_a := await spawn_frozen(BAT, Vector2(260, 0))
	var near_b := await spawn_frozen(BAT, Vector2(200, 80))
	var near_c := await spawn_frozen(BAT, Vector2(200, -120))
	var far := await spawn_frozen(BAT, Vector2(200, 600))
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


func test_a_pooled_mob_does_not_keep_its_stun() -> void:
	var bat := await spawn_frozen(BAT, Vector2(0, 0))
	(bat as EntityBase).apply_stun(0.5)
	assert_true((bat as EntityBase).is_stunned())
	(bat as MobBase).prepare_for_pool()
	assert_false((bat as EntityBase).is_stunned(), "the next life starts unstunned")
	bat.queue_free()


## The match-result screen pauses the tree: a dash in progress stops where it
## is instead of sliding on underneath, and finishes once unpaused.
func test_ram_dash_holds_still_while_paused() -> void:
	var g := await spawn_frozen(GROUNT, Vector2(0, 0))
	var v := await spawn_frozen(VLAD, Vector2(220, 0))
	var dash := g.ability_2 as BullRamDash
	dash.execute(g, v, 1.0)
	await wait_frames(3)
	assert_true(dash.is_channeling(), "dashing")
	var held: Vector2 = g.global_position
	assert_true(held.x > 0.0, "the dash has started moving")
	get_tree().paused = true
	await wait_seconds(0.3)
	assert_eq(g.global_position, held, "no movement while paused")
	assert_true(dash.is_channeling(), "the dash waits for the unpause")
	get_tree().paused = false
	await wait_seconds(0.6)
	assert_false(dash.is_channeling(), "the dash finished after the unpause")
	assert_true(g.global_position.x > held.x, "and moved on")
	g.queue_free()
	v.queue_free()


## Same for Ground Slam: a leap in the air when the tree pauses lands (and
## deals its damage) only after the unpause.
func test_ground_slam_lands_only_after_unpause() -> void:
	var g := await spawn_frozen(GROUNT, Vector2(0, 0))
	var v := await spawn_frozen(VLAD, Vector2(100, 0))
	var slam := g.ability_3 as BullGroundSlam
	slam.execute(g, v, 10.0)
	await wait_seconds(0.2)
	get_tree().paused = true
	var held: Vector2 = g.global_position
	await wait_seconds(slam.jump_duration + 0.2)
	assert_eq(v.get_health(), v.get_max_health(), "no slam damage while paused")
	assert_true(slam.is_channeling(), "still airborne")
	assert_eq(g.global_position, held, "the leap holds still while paused")
	get_tree().paused = false
	await wait_seconds(slam.jump_duration)
	assert_false(slam.is_channeling(), "landed after the unpause")
	assert_true(v.get_health() < v.get_max_health(), "and slammed")
	g.queue_free()
	v.queue_free()
