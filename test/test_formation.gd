extends TestCase

## Exploration formation: the tank leads and paces the group, melee flank,
## the healer trails, and slots turn with the direction of travel.

const CTRL := "res://Scenes/NPCs/Hero/HeroExplorationController.tscn"
const IRELIA := "res://Scenes/NPCs/Hero/Heros/Support/Irelia/Irelia.tscn"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const TED := "res://Scenes/NPCs/Hero/Heros/Support/Ted/Ted.tscn"
const RIVER := "res://Scenes/NPCs/Hero/Heros/Healer/River/River.tscn"


func _frozen(path: String, pos: Vector2) -> Node2D:
	var e := await spawn_entity(path, pos)
	TickScheduler.unregister(e)
	return e


func test_tank_leads_healer_trails_and_followers_pace_on_the_leader() -> void:
	# Roster order puts the fast melee first: the old index-based slots made
	# Ted the "leader" and he reached every camp alone.
	var ted := await _frozen(TED, Vector2(0, 0))
	var vlad := await _frozen(VLAD, Vector2(40, 0))
	var river := await _frozen(RIVER, Vector2(80, 0))
	var irelia := await _frozen(IRELIA, Vector2(120, 0))
	var ctrl := (load(CTRL) as PackedScene).instantiate() as HeroExplorationController
	add_child(ctrl)
	await wait_frames(2)
	assert_eq(ctrl.get_formation_leader(), irelia, "formation_rank 0 leads")
	assert_false(ctrl._formation_slots.has(null))
	for hero in ctrl._formation_slots:
		assert_true(hero is HeroBase, "pets get no slot")

	ctrl.current_group_target = irelia.global_position + Vector2(0, 1000)  # travel south
	ctrl._update_formation_offsets()
	var spread: float = ctrl.formation_spread
	var rear: Vector2 = ctrl.hero_formation_offset[river]
	assert_true(rear.distance_to(Vector2(0, -1.4 * spread)) < 0.5, "healer trails behind the leader")
	var flank: Vector2 = ctrl.hero_formation_offset[ted]
	assert_near(absf(flank.x), spread, 0.5, "melee on a flank")
	assert_true(flank.y < 0.0, "flanks sit slightly behind the leader")

	ctrl._recalculate_boids()
	ctrl._apply_cached_boids(vlad)
	ctrl._apply_cached_boids(irelia)
	var slot: Vector2 = irelia.global_position + ctrl.hero_formation_offset[vlad]
	assert_true((vlad as HeroBase).exploration_target.distance_to(slot) < 150.0,
		"a follower heads for its slot next to the leader, not the far group target")
	assert_true((irelia as HeroBase).exploration_target.distance_to(ctrl.current_group_target) < 150.0,
		"the leader heads for the group target")

	# The leader really walks there: Irelia's own idle used to wander around
	# her allies and ignore the exploration target, stalling the whole group.
	irelia._idle_timer = 0.0
	irelia._on_idle_state_processing(0.016)
	assert_true(irelia._idle_goal.distance_to((irelia as HeroBase).exploration_target) < 1.0,
		"the leader's idle goal is the exploration target")

	irelia.queue_free()
	await wait_frames(2)
	ctrl._cleanup_freed_heroes()
	ctrl._recalculate_boids()
	assert_true(ctrl.get_formation_leader() == vlad or ctrl.get_formation_leader() == ted,
		"a flank takes over when the leader dies")
	for n in [ted, vlad, river, ctrl]:
		n.queue_free()
