extends Node

## TickScheduler — AI level-of-detail. EntityBase registers from _enter_tree
## and receives `_tick(delta)` at a rate chosen by how close it is to the
## action. `_tick` calls `StateChart.step()`, which the addon routes to the
## active leaf's `state_stepped` signal (connected scene-side in
## NPCBaseClass.tscn). The state chart still owns every state and transition;
## this node only decides how often the active state's logic runs.
##
## Buckets are ANCHOR-based (distance to the nearest hero / pet / monster via
## EntityRegistry), not camera-based: lazy activation only spawns mobs within
## ~300 px of a hero, so camera distance would throttle exactly the mobs that
## are fighting an off-screen hero. The camera only drives visual LOD
## (sprite animation pause) via each entity's VisibleOnScreenNotifier2D.
##
##   FULL  every frame — always_full (heroes, monster) or on screen
##   NEAR  20 Hz       — has a target / in combat, or within near_radius
##   MID   10 Hz       — within mid_radius
##   FAR    3 Hz       — everything else
##
## `delta` handed to _tick is the wall time since THIS entity's last tick
## (clamped to MAX_TICK_DELTA), so `speed * delta` movement and `timer -=
## delta` cooldowns stay rate-invariant.

enum Lod { FULL, NEAR, MID, FAR }

const REBUCKET_INTERVAL: float = 0.25
## Hitch guard: after a long stall an entity gets at most this much delta.
const MAX_TICK_DELTA: float = 0.5
const INTERVALS: Array[float] = [0.0, 1.0 / 20.0, 1.0 / 10.0, 1.0 / 3.0]
const LOD_NAMES: Array[String] = ["FULL", "NEAR", "MID", "FAR"]

@export var near_radius: float = 450.0
@export var mid_radius: float = 1200.0
## false = tick everything every frame (A/B measurement with the F3 overlay).
@export var lod_enabled: bool = true


class Entry:
	var entity: EntityBase
	var accum: float = 0.0
	var lod: int = Lod.FAR
	var on_screen: bool = false
	var always_full: bool = false
	var dead: bool = false


var _entries: Array[Entry] = []
var _by_entity: Dictionary = {}  # EntityBase -> Entry
var _rebucket_timer: float = 0.0
var _needs_compact: bool = false
var _counts: Array[int] = [0, 0, 0, 0]


# ============================================
# Registration (called from EntityBase._enter_tree / _exit_tree)
# ============================================

func register(entity: EntityBase, always_full: bool = false) -> void:
	if entity == null or _by_entity.has(entity):
		return
	var e := Entry.new()
	e.entity = entity
	e.always_full = always_full
	e.lod = Lod.FULL if always_full else Lod.FAR
	# Phase spread so 150 mobs in one bucket don't all tick on the same frame.
	e.accum = randf() * INTERVALS[e.lod]
	_entries.append(e)
	_by_entity[entity] = e


func unregister(entity: EntityBase) -> void:
	var e: Entry = _by_entity.get(entity, null)
	if e == null:
		return
	# Tombstone: never mutate _entries while the tick loop may be iterating.
	e.dead = true
	_by_entity.erase(entity)
	_needs_compact = true


func set_on_screen(entity: EntityBase, on: bool) -> void:
	var e: Entry = _by_entity.get(entity, null)
	if e != null:
		e.on_screen = on


# ============================================
# Debug queries (F3 overlay)
# ============================================

func lod_of(entity: EntityBase) -> int:
	var e: Entry = _by_entity.get(entity, null)
	return e.lod if e != null else Lod.FULL


func lod_name(lod: int) -> String:
	return LOD_NAMES[clampi(lod, 0, LOD_NAMES.size() - 1)]


func bucket_counts() -> Array[int]:
	return _counts


# ============================================
# Tick loop
# ============================================

func _process(delta: float) -> void:
	_rebucket_timer -= delta
	var rebucket := _rebucket_timer <= 0.0
	if rebucket:
		_rebucket_timer += REBUCKET_INTERVAL
		_counts.fill(0)

	# Iterate the live array in place, up to its size before the loop. A handler
	# inside step() may kill / unregister other entities or spawn new ones, and
	# neither moves an entry: register() only appends (a new entry sits at index
	# >= n and first ticks next frame), unregister() only tombstones, and
	# compaction runs after the loop. So indices 0..n-1 hold the same entries,
	# in the same order, for the whole loop.
	var n: int = _entries.size()
	for i in n:
		var e: Entry = _entries[i]
		if e.dead:
			continue
		var ent := e.entity
		if not is_instance_valid(ent) or not ent.is_inside_tree():
			continue
		if rebucket:
			var new_lod := _bucket_for(e)
			if new_lod != e.lod:
				e.lod = new_lod
				e.accum = 0.0
			_counts[e.lod] += 1
		if e.lod == Lod.FULL:
			ent._tick(minf(delta, MAX_TICK_DELTA))
			continue
		e.accum += delta
		if e.accum >= INTERVALS[e.lod]:
			ent._tick(minf(e.accum, MAX_TICK_DELTA))
			e.accum = 0.0

	if _needs_compact:
		_needs_compact = false
		var kept: Array[Entry] = []
		for e in _entries:
			if not e.dead:
				kept.append(e)
		_entries = kept


func _bucket_for(e: Entry) -> int:
	if not lod_enabled or e.always_full or e.on_screen:
		return Lod.FULL
	var ent := e.entity
	# Combat floor: anything with a target reacts at >= 20 Hz wherever it is.
	if ent.is_target_valid():
		return Lod.NEAR
	var d_sq := EntityRegistry.nearest_anchor_dist_sq(ent.global_position)
	if d_sq < near_radius * near_radius:
		return Lod.NEAR
	if d_sq < mid_radius * mid_radius:
		return Lod.MID
	return Lod.FAR
