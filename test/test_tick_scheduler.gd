extends TestCase

## TickScheduler contract (Scripts/tick_scheduler.gd), pinned before the
## scheduler refactors: each LOD bucket hands out the time since the entity's
## last tick, a long stall is clamped to MAX_TICK_DELTA, an entity unregistered
## during the tick loop is tombstoned, and the bucket rules.
## The live autoload already processes every frame, so each test drives a
## PRIVATE scheduler (never in the tree) by calling its _process by hand. Its
## entities are spies that only record the delta they are handed and stay out
## of the live registries and the live scheduler.

const SchedulerScript := preload("res://Scripts/tick_scheduler.gd")
const NPC := "res://Scenes/NPCs/NPCBaseClass.tscn"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const DT := 1.0 / 60.0
const EPS := 1e-9


## Records every _tick and runs none of the AI. Built on NPCBaseClass.tscn so
## EntityBase's @onready nodes resolve: the scheduler only ticks entities that
## are inside the tree.
class Spy extends EntityBase:
	var tick_count: int = 0
	var tick_sum: float = 0.0
	var last_delta: float = 0.0
	var on_tick: Callable = Callable()

	func _enter_tree() -> void:
		pass  # no TeamRegistry / EntityRegistry / live TickScheduler registration

	func _exit_tree() -> void:
		pass

	func _ready() -> void:
		pass

	func _tick(delta: float) -> void:
		tick_count += 1
		tick_sum += delta
		last_delta = delta
		if on_tick.is_valid():
			on_tick.call()

	func _on_screen_entered() -> void:
		pass  # visual LOD is not under test (and the spy has no animation)

	func _on_screen_exited() -> void:
		pass


func test_each_lod_hands_out_the_time_since_its_last_tick() -> void:
	await _anchor()
	var ts := SchedulerScript.new()
	var full := _spy(Vector2(300, 0))
	var near := _spy(Vector2(300, 0))  # inside near_radius (450) of the anchor
	var mid := _spy(Vector2(800, 0))   # inside mid_radius (1200)
	var far := _spy(Vector2(2000, 0))
	_register(ts, full, true)
	_register(ts, near)
	_register(ts, mid)
	_register(ts, far)
	for _frame in 60:
		ts._process(DT)
	assert_eq(_entry(ts, full).lod, SchedulerScript.Lod.FULL)
	assert_eq(_entry(ts, near).lod, SchedulerScript.Lod.NEAR)
	assert_eq(_entry(ts, mid).lod, SchedulerScript.Lod.MID)
	assert_eq(_entry(ts, far).lod, SchedulerScript.Lod.FAR)
	# One second at a steady 60 fps. MID ticks every 7th frame, not every 6th:
	# six 1/60 s steps add up to just under its 0.1 s interval.
	assert_eq(full.tick_count, 60, "FULL: every frame")
	assert_eq(near.tick_count, 20, "NEAR: every 3rd frame")
	assert_eq(mid.tick_count, 8, "MID: every 7th frame")
	assert_eq(far.tick_count, 3, "FAR: every 20th frame")
	assert_near(full.tick_sum, 1.0, EPS)
	assert_near(near.tick_sum, 1.0, EPS)
	assert_near(mid.tick_sum, 56.0 / 60.0, EPS)
	assert_near(far.tick_sum, 1.0, EPS)
	assert_near(near.last_delta, 3.0 / 60.0, EPS, "a NEAR tick carries the 3 frames since the last one")
	assert_near(mid.last_delta, 7.0 / 60.0, EPS)
	assert_near(far.last_delta, 20.0 / 60.0, EPS)
	# Rate invariance: what was handed out plus what is still pending is the
	# elapsed second, so `speed * delta` moves the same distance in any bucket.
	assert_near(mid.tick_sum + _entry(ts, mid).accum, 1.0, EPS, "MID: 4 frames still pending")
	ts.free()


func test_a_long_stall_is_clamped_to_max_tick_delta() -> void:
	var ts := SchedulerScript.new()
	var full := _spy(Vector2.ZERO)
	var far := _spy(Vector2.ZERO)  # no anchor in this test: FAR
	_register(ts, full, true)
	_register(ts, far)
	ts._process(2.0)
	assert_eq(full.tick_count, 1)
	assert_near(full.last_delta, SchedulerScript.MAX_TICK_DELTA, EPS, "FULL: a 2 s frame is clamped")
	assert_eq(far.tick_count, 1)
	assert_near(far.last_delta, SchedulerScript.MAX_TICK_DELTA, EPS, "throttled: the accumulated 2 s is clamped too")
	ts.free()


func test_unregistering_an_entity_mid_loop_tombstones_it() -> void:
	var ts := SchedulerScript.new()
	var killer := _spy(Vector2.ZERO)
	var victim := _spy(Vector2.ZERO)
	_register(ts, killer, true)
	_register(ts, victim, true)  # after the killer in the tick order
	killer.on_tick = func() -> void: ts.unregister(victim)
	ts._process(DT)
	assert_eq(killer.tick_count, 1)
	assert_eq(victim.tick_count, 0, "tombstoned before its turn in the same loop")
	assert_false(ts._by_entity.has(victim))
	assert_eq(ts._entries.size(), 1, "compacted at the end of the same _process call")
	assert_false(ts._needs_compact)
	ts._process(DT)
	assert_eq(killer.tick_count, 2)
	assert_eq(victim.tick_count, 0)
	ts.free()


func test_bucket_thresholds_and_the_combat_floor() -> void:
	var anchor := await _anchor()
	var ts := SchedulerScript.new()
	var spy := _spy(Vector2.ZERO)
	_register(ts, spy)
	var e := _entry(ts, spy)
	spy.global_position = Vector2(ts.near_radius - 1.0, 0.0)
	assert_eq(ts._bucket_for(e), SchedulerScript.Lod.NEAR, "just inside near_radius")
	spy.global_position = Vector2(ts.near_radius + 1.0, 0.0)
	assert_eq(ts._bucket_for(e), SchedulerScript.Lod.MID, "just past near_radius")
	spy.global_position = Vector2(ts.mid_radius + 1.0, 0.0)
	assert_eq(ts._bucket_for(e), SchedulerScript.Lod.FAR, "just past mid_radius")
	# Combat floor: anything with a valid target ticks at >= 20 Hz wherever it is.
	spy.target = anchor.get_node(^"Body") as Area2D
	spy.target_entity = anchor
	assert_true(spy.is_target_valid())
	assert_eq(ts._bucket_for(e), SchedulerScript.Lod.NEAR, "a valid target far from every anchor")
	e.on_screen = true
	assert_eq(ts._bucket_for(e), SchedulerScript.Lod.FULL, "on screen")
	e.on_screen = false
	ts.lod_enabled = false
	assert_eq(ts._bucket_for(e), SchedulerScript.Lod.FULL, "LOD disabled")
	ts.free()


# ---------- helpers ----------

func _spy(pos: Vector2) -> Spy:
	var node := (load(NPC) as PackedScene).instantiate()
	node.set_script(Spy)
	var spy := node as Spy
	spy.position = pos
	add_child(spy)
	return spy


## Register with the private scheduler and zero the random phase register()
## gives a throttled entity, so the tick frames are exact.
func _register(ts: SchedulerScript, spy: Spy, always_full: bool = false) -> void:
	ts.register(spy, always_full)
	_entry(ts, spy).accum = 0.0


func _entry(ts: SchedulerScript, spy: Spy) -> SchedulerScript.Entry:
	return ts._by_entity[spy] as SchedulerScript.Entry


## A frozen Vlad at the origin: the only LOD anchor (EntityRegistry.hero_side).
func _anchor() -> Node2D:
	var v := await spawn_frozen(VLAD, Vector2.ZERO)
	v.global_position = Vector2.ZERO  # undo any wander step taken before it froze
	return v
