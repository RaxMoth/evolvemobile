extends TestCase

## Regressions from the second adversarial review (production batch).

const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const RIVER := "res://Scenes/NPCs/Hero/Heros/Healer/River/River.tscn"
const PET := "res://Scenes/NPCs/Hero/Heros/Support/Ted/Abilities/Passive/TedsPet.tscn"


func before_each() -> void:
	if is_isolated():
		PersistedData.wipe_progress(false)


func test_pet_respawns_only_after_the_timer() -> void:
	var vlad := await spawn_entity(VLAD, Vector2(0, 0))
	var passive := TedPassivePet.new()
	passive.pet_scene = load(PET)
	passive.on_passive_update(vlad, 0.1)
	var first: Node = passive.pet_instance
	assert_true(is_instance_valid(first), "first spawn is immediate")
	await wait_physics_frames(2)
	EventBus.deal_damage(vlad, first, 9999.0)  # the pet dies and emits `died`
	await wait_frames(2)
	assert_false(is_instance_valid(first))
	passive.on_passive_update(vlad, 0.1)
	assert_true(passive.pet_instance == null, "no instant respawn after death")
	passive.on_passive_update(vlad, TedPassivePet.RESPAWN_TIME - 0.5)
	assert_true(passive.pet_instance == null, "still waiting")
	passive.on_passive_update(vlad, 1.0)
	assert_true(is_instance_valid(passive.pet_instance), "respawned after RESPAWN_TIME")
	passive.pet_instance.queue_free()
	vlad.queue_free()


func test_damage_and_attack_speed_nodes_reach_combat() -> void:
	if not require_isolated():
		return
	PersistedData.add_currency(PersistedData.STEEL, 1000)
	assert_true(MetaSkillManager.unlock(MetaSkillManager.hero_tree_id(&"vlad"), &"v1_dmg"))
	assert_true(MetaSkillManager.unlock(MetaSkillManager.hero_tree_id(&"vlad"), &"v1_atkspd"))
	var vlad := await spawn_entity(VLAD, Vector2(0, 0))
	var abilities := vlad.get_node("AbilitySystem") as AbilitySystem
	var passive_mult: float = abilities.passive_ability.get_damage_multiplier(vlad) if abilities.passive_ability else 1.0
	assert_near(abilities.get_damage_multiplier(), passive_mult * 1.05, 0.001, "+5% damage node multiplies ability damage")
	assert_near(abilities.get_attack_speed_multiplier(), (abilities.passive_ability.get_attack_speed_multiplier(vlad) if abilities.passive_ability else 1.0) * 1.05, 0.001)
	vlad.queue_free()


func test_hero_spawns_at_full_upgraded_health() -> void:
	if not require_isolated():
		return
	PersistedData.add_currency(PersistedData.GOLD, 1000)
	assert_true(MetaSkillManager.unlock(MetaSkillManager.TREE_HERO_BASE, &"t1_hp"))
	var vlad := await spawn_entity(VLAD, Vector2(0, 0))
	assert_true(vlad.get_max_health() > vlad.get_node("HeroStats").base_stats.base_max_health, "max HP upgraded")
	assert_near(vlad.get_health(), vlad.get_max_health(), 0.01, "current HP refilled to the upgraded max")
	vlad.queue_free()


func test_river_exposes_weapon_mode_and_scaled_range() -> void:
	var river := await spawn_entity(RIVER, Vector2(0, 0))
	assert_true(river.has_method("get_weapon_mode"), "RiverBasicAttack.execute needs it or River never attacks")
	assert_eq(river.get_weapon_mode(), 0)
	assert_near(river.attack_range, 300.0, 0.01)
	river.set_weapon_mode("heal_staff")
	assert_near(river.attack_range, river.heal_max_range, 0.01)
	river.queue_free()


func test_melee_reach_follows_the_caster_range() -> void:
	var vlad := await spawn_entity(VLAD, Vector2(0, 0))
	var basic: AbilityBase = (vlad.get_node("AbilitySystem") as AbilitySystem).basic_attack
	assert_near(basic.effective_range(vlad), maxf(basic.ability_range, vlad.attack_range), 0.01)
	vlad.queue_free()


func test_outcome_is_converted_to_the_played_side() -> void:
	assert_eq(MatchRewards.outcome_for_side(MatchRewards.Side.HEROES, MatchRewards.Outcome.WIN), MatchRewards.Outcome.WIN)
	assert_eq(MatchRewards.outcome_for_side(MatchRewards.Side.HEROES, MatchRewards.Outcome.TIMEOUT), MatchRewards.Outcome.TIMEOUT)
	assert_eq(MatchRewards.outcome_for_side(MatchRewards.Side.MONSTER, MatchRewards.Outcome.WIN), MatchRewards.Outcome.LOSS, "monster died")
	assert_eq(MatchRewards.outcome_for_side(MatchRewards.Side.MONSTER, MatchRewards.Outcome.LOSS), MatchRewards.Outcome.WIN, "heroes wiped")
	assert_eq(MatchRewards.outcome_for_side(MatchRewards.Side.MONSTER, MatchRewards.Outcome.TIMEOUT), MatchRewards.Outcome.WIN, "survived the clock")
