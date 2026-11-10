extends TestCase

## Regressions found by the adversarial review of the performance pass.

const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"
const PET := "res://Scenes/NPCs/Hero/Heros/Support/Ted/Abilities/Passive/TedsPet.tscn"

var mgr: SpawnManager
var area: MobSpawnArea


func before_each() -> void:
	mgr = make_spawn_manager(2, 60.0, Vector2(2000, 2000)) as SpawnManager
	area = mgr.get_child(0) as MobSpawnArea


func after_each() -> void:
	mgr.queue_free()


func test_pet_drops_a_target_that_dies_and_gets_parked() -> void:
	var vlad := await spawn_entity(VLAD, Vector2(2000, 1700))
	area.activate()
	await wait_physics_frames(4)
	var anchor: MobBase = area.spawned_mobs[0]
	var pet := (load(PET) as PackedScene).instantiate() as CharacterBody2D
	pet.global_position = anchor.global_position + Vector2(20, 0)
	pet.set("owner_entity", vlad)
	add_child(pet)
	await wait_physics_frames(6)
	await wait_seconds(0.3)
	var victim := pet.get("current_target") as MobBase
	assert_true(victim != null, "pet picked a mob target")
	if victim == null:
		pet.queue_free()
		vlad.queue_free()
		return
	EventBus.deal_damage(vlad, victim, 9999.0)
	await wait_frames(3)
	assert_true(victim.is_parked, "victim is parked, not freed")
	await wait_seconds(0.35)
	var t: Node = pet.get("current_target")
	assert_true(t != victim, "pet let go of the parked mob")
	assert_true(t == null or (is_instance_valid(t) and t.is_inside_tree()), "any new target is live")
	pet.queue_free()
	vlad.queue_free()


func test_parked_mob_is_forgotten_in_every_threat_table() -> void:
	var vlad := await spawn_entity(VLAD, Vector2(2000, 1700))
	area.activate()
	await wait_physics_frames(4)
	var mob: MobBase = area.spawned_mobs[0]
	var heroes_team: TeamBlackboard = TeamRegistry.get_team(TeamRegistry.HEROES)
	heroes_team.bump_threat(vlad, mob, 25.0)
	assert_true(heroes_team.get_threat_on(vlad).has(mob))
	EventBus.deal_damage(vlad, mob, 9999.0)
	await wait_frames(3)
	assert_true(mob.is_parked)
	assert_false(heroes_team.get_threat_on(vlad).has(mob), "parked attacker scrubbed from the heroes' rows")
	assert_false(mob.is_alive(), "parked mobs are never alive")
	vlad.queue_free()


func test_corpse_is_not_healed_by_the_leash() -> void:
	var vlad := await spawn_entity(VLAD, Vector2(2000, 1700))
	area.activate()
	await wait_physics_frames(4)
	var mob: MobBase = area.spawned_mobs[0]
	EventBus.deal_damage(vlad, mob, 9999.0)
	mob.global_position = area.global_position + Vector2(900, 0)  # far outside the leash
	mob._pre_tick(0.1)
	mob._reset_to_spawn()
	assert_eq(mob.get_health(), 0.0, "neither the leash check nor the reset revive a corpse")
	vlad.queue_free()


func test_singleton_cache_survives_a_freed_node() -> void:
	var a := Node.new()
	a.add_to_group(&"TestSingleton")
	add_child(a)
	assert_true(EntityRegistry.singleton(&"TestSingleton") == a)
	a.queue_free()
	await wait_frames(2)
	assert_true(EntityRegistry.singleton(&"TestSingleton") == null, "freed node is dropped, no error")
	var b := Node.new()
	b.add_to_group(&"TestSingleton")
	add_child(b)
	assert_true(EntityRegistry.singleton(&"TestSingleton") == b, "cache refreshed")


func test_hud_group_is_counter_scaled_as_one() -> void:
	var grount := await spawn_entity(GROUNT, Vector2(4000, 4000))
	var hud: Node2D = grount.get_node("%Hud")
	var badge := grount.get_node(^"%LevelBadge") as Control
	assert_true(hud != null and grount.health_bar.get_parent() == hud and badge.get_parent() == hud)
	assert_eq(grount.lv_label.get_parent(), badge, "the level number sits in its themed badge")
	grount.scale = Vector2(1.5, 1.5)
	grount._apply_ui_counter_scale()
	assert_near(hud.scale.x, 1.0 / 1.5)
	assert_eq(grount.health_bar.scale, Vector2.ONE, "children are not scaled separately")
	assert_eq(badge.scale, Vector2.ONE)
	grount.queue_free()


## The Hud used to be re-pinned only after the 0.5 s stage scale tween, so the
## HP bar and level label swelled with the body (and its overshoot) and then
## snapped back. Mid-tween they now keep their pixel size.
func test_hud_keeps_its_size_during_the_evolution_tween() -> void:
	var grount := await spawn_entity(GROUNT, Vector2(4000, 4000))
	var hud: Node2D = grount.get_node("%Hud")
	var start_scale: Vector2 = grount.scale
	grount.gain_xp(1000.0)
	assert_eq(grount.current_stage, 2)
	await wait_seconds(0.25)
	assert_false(grount.scale.is_equal_approx(start_scale), "mid-tween the body has grown (%s)" % str(grount.scale))
	assert_true(hud.global_scale.is_equal_approx(Vector2.ONE), "Hud at its pixel size, got %s" % str(hud.global_scale))
	await wait_seconds(0.4)
	assert_true(grount.scale.is_equal_approx(grount.monster_stats.stage_2_scale), "settled at %s" % str(grount.scale))
	assert_true(hud.global_scale.is_equal_approx(Vector2.ONE), "and the Hud with it, got %s" % str(hud.global_scale))
	grount.queue_free()


func test_monster_slam_can_hit_the_pet() -> void:
	var vlad := await spawn_entity(VLAD, Vector2(6000, 6000))
	var grount := await spawn_entity(GROUNT, Vector2(0, 0))
	var pet := (load(PET) as PackedScene).instantiate() as CharacterBody2D
	pet.global_position = Vector2(40, 0)
	pet.set("owner_entity", vlad)
	add_child(pet)
	await wait_physics_frames(4)
	var hp_before: float = pet.get("current_health")
	var slam := BullGroundSlam.new()
	slam._effective_damage = 5.0
	slam._perform_slam(grount)
	await wait_frames(1)
	assert_true(float(pet.get("current_health")) < hp_before, "pet (CharacterBody2D on the hero body layer) takes AoE damage")
	pet.queue_free()
	grount.queue_free()
	vlad.queue_free()
