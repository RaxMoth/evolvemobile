extends TestCase

## P0a regression: lethal damage must reach Dead from ANY state, not only
## from Fight (heroes / the monster used to be immortal in Idle / Approach).

const BAT := "res://Scenes/NPCs/Mob/Mobs/Bat/Bat.tscn"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"


func test_mob_dies_from_idle_and_is_freed_without_a_pool() -> void:
	var vlad := await spawn_entity(VLAD, Vector2(0, 0))
	var bat := await spawn_entity(BAT, Vector2(2000, 2000))
	assert_eq(active_state_of(bat), "Idle")
	var died_count := [0]
	bat.died.connect(func() -> void: died_count[0] += 1)
	EventBus.deal_damage(vlad, bat, 9999.0)
	assert_false(bat.is_alive())
	assert_eq(active_state_of(bat), "Dead")
	assert_eq(died_count[0], 1)
	await wait_frames(2)
	assert_false(is_instance_valid(bat), "no SpawnManager -> _release_or_free falls back to queue_free")
	vlad.queue_free()
	await wait_frames(1)


func test_monster_dies_while_approaching() -> void:
	var vlad := await spawn_entity(VLAD, Vector2(0, 0))
	var grount := await spawn_entity(GROUNT, Vector2(3000, 0))
	# Force Approach the way detection does: target the hero's Body area.
	grount.target = vlad.get_node("Body")
	grount.target_entity = vlad
	grount.state_chart.send_event(CombatEvents.ENEMY_ENTERED)
	assert_eq(active_state_of(grount), "Approach")
	var died := [false]
	grount.died.connect(func() -> void: died[0] = true)
	EventBus.deal_damage(vlad, grount, 999999.0)
	assert_false(grount.is_alive())
	assert_eq(active_state_of(grount), "Dead", "ToDead lives on the CompoundState, so Approach can die")
	assert_true(died[0])
	await wait_frames(2)
	assert_false(is_instance_valid(grount))
	vlad.queue_free()
	await wait_frames(1)


func test_hero_dies_from_idle() -> void:
	var bat := await spawn_entity(BAT, Vector2(0, 0))
	var vlad := await spawn_entity(VLAD, Vector2(3000, 0))
	assert_eq(active_state_of(vlad), "Idle")
	EventBus.deal_damage(bat, vlad, 999999.0)
	assert_false(vlad.is_alive())
	assert_eq(active_state_of(vlad), "Dead")
	await wait_frames(2)
	assert_false(is_instance_valid(vlad))
	bat.queue_free()
	await wait_frames(1)


func test_targeted_damage_hook_flinches_only_the_target() -> void:
	var vlad := await spawn_entity(VLAD, Vector2(0, 0))
	var bat_a := await spawn_entity(BAT, Vector2(2000, 0))
	var bat_b := await spawn_entity(BAT, Vector2(2000, 300))
	EventBus.deal_damage(vlad, bat_a, 1.0)
	assert_true(bat_a._flinch_timer > 0.0, "hit mob flinches")
	assert_eq(bat_b._flinch_timer, 0.0, "other mob does not")
	assert_near(bat_a.get_health(), bat_a.get_max_health() - 1.0)
	for n in [vlad, bat_a, bat_b]:
		n.queue_free()
	await wait_frames(1)
