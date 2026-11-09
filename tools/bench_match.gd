extends SceneTree

## Headless performance benchmark: loads World.tscn in the stress config (all
## 39 camps active, lazy activation off, `stress_mob_multiplier` mobs per
## slot), lets both sides auto-play and measures the per-frame cost of
## scripts + physics. No rendering is measured (headless). Prints ONE JSON
## line. Use through tools/bench.sh (temp copy, isolated user://).
##
##   godot --headless --fixed-fps 60 --max-fps 0 --path <copy> \
##         -s res://tools/bench_match.gd -- <seed> [warmup_frames] [frames] [multiplier] [onscreen] [rigs_awake]
##
## CharacterRigs follow the same on-screen marking (onscreen=1); rigs_awake=1
## wakes EVERY rig (the zoomed-out worst case). `rigs_awake_mean` is the mean
## number of animating rigs (CharacterRig.awake_count()); a rig without a body
## (a character not migrated to SVG art yet) never wakes.
##
## `lod_counts` is the mean number of TickScheduler entries per LOD bucket.
## Headless, nothing is drawn, so the VisibleOnScreenNotifier2D signals never
## fire and every mob stays off screen (NEAR/MID/FAR, 20/10/3 Hz): only the
## always-full heroes and monster tick every frame. On a device every mob
## inside the camera rect ticks at FULL rate. `onscreen` = 1 emulates that:
## each frame, mobs inside the MainCam rect (grown by ONSCREEN_MARGIN) are
## marked on screen in TickScheduler, as the notifier would. The headless
## viewport measures 1280x1280, so at default_zoom 2 the rect is 640x640
## world px (a 720x1280 portrait phone shows 360x640). The frame_ms_* stats
## leave the marking time out; cpu_s and the *_peak_ms monitors include it.

const WORLD := "res://Scenes/World/World.tscn"
## World px added around the camera rect (a notifier fires on its AABB, not
## on the mob's origin).
const ONSCREEN_MARGIN: float = 64.0

var _seed: int = 1
var _warmup: int = 600
var _frames: int = 1800
var _multiplier: int = 2
var _onscreen: bool = false
var _rigs_awake: bool = false
var _frame: int = 0
var _last_us: int = 0
var _frame_ms: Array[float] = []
# Time the last tick spent in _mark_on_screen (left out of _frame_ms).
var _mark_us: int = 0
# Godot's TIME_PROCESS / TIME_PHYSICS_PROCESS monitors hold the slowest frame
# of the last second (refreshed once per second): summed per frame they give
# the mean of those per-second peaks.
var _process_peak_ms: float = 0.0
var _physics_peak_ms: float = 0.0
var _peak_nodes: int = 0
var _peak_mobs: int = 0
var _peak_pairs: int = 0
# Per-bucket sums of TickScheduler.bucket_counts(), one sample per frame.
var _lod_sums: Array[int] = [0, 0, 0, 0]
var _rig_sum: int = 0
# CharacterRig's script (by path: a -s script must not name project classes).
var _rig_script: Script
# Autoloads and the camera, resolved once the world is in the tree.
var _scheduler: Node
var _registry: Node
var _cam: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_seed = int(args[0])
	if args.size() > 1:
		_warmup = int(args[1])
	if args.size() > 2:
		_frames = int(args[2])
	if args.size() > 3:
		_multiplier = int(args[3])
	if args.size() > 4:
		_onscreen = int(args[4]) != 0
	if args.size() > 5:
		_rigs_awake = int(args[5]) != 0
	_rig_script = load("res://Scripts/Rig/character_rig.gd")
	_rig_script.set("force_awake", _rigs_awake)
	# Autoloads are only reachable through the root once the tree runs.
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	seed(_seed)
	root.get_node("GameManager").set("chosen_side", 0)
	var world := (load(WORLD) as PackedScene).instantiate()
	var spawns := world.get_node("Spawns")
	spawns.set("min_active_spawns", 39)
	spawns.set("max_active_spawns", 39)
	spawns.set("enable_lazy_activation", false)
	spawns.set("stress_mob_multiplier", _multiplier)
	root.add_child(world)
	current_scene = world
	_scheduler = root.get_node("TickScheduler")
	_registry = root.get_node("EntityRegistry")
	_cam = world.get_node("MainCam")
	process_frame.connect(_tick)


func _tick() -> void:
	_frame += 1
	var now := Time.get_ticks_usec()
	if _frame > _warmup:
		# The bench's own marking (last tick, ~0.1 ms) is not game cost.
		_frame_ms.append((now - _last_us - _mark_us) / 1000.0)
		_process_peak_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		_physics_peak_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		_peak_nodes = maxi(_peak_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		_peak_pairs = maxi(_peak_pairs, int(Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS)))
		_peak_mobs = maxi(_peak_mobs, (_registry.get("mobs") as Array).size())
		_rig_sum += int(_rig_script.call("awake_count"))
		var counts: Array = _scheduler.call("bucket_counts")
		for i in _lod_sums.size():
			_lod_sums[i] += int(counts[i])
	_last_us = now
	# TickScheduler reads the flags at its next rebucket (every 0.25 s).
	if _onscreen:
		var mark_start := Time.get_ticks_usec()
		_mark_on_screen()
		_mark_us = Time.get_ticks_usec() - mark_start
	if _frame >= _warmup + _frames:
		_finish()


func _mark_on_screen() -> void:
	var rect: Rect2 = _cam.call("get_viewport_rect_in_world")
	rect = rect.grow(ONSCREEN_MARGIN)
	for m in _registry.get("mobs") as Array:
		if is_instance_valid(m):
			var on := rect.has_point((m as Node2D).global_position)
			_scheduler.call("set_on_screen", m, on)
			var rig := (m as Node).get_node_or_null(^"Rig")
			if rig and not _rigs_awake:
				rig.call("set_on_screen", on)


func _finish() -> void:
	process_frame.disconnect(_tick)
	var sorted := _frame_ms.duplicate()
	sorted.sort()
	var n: int = sorted.size()
	var total: float = 0.0
	for ms in sorted:
		total += ms
	var lod_counts := {}
	for i in _lod_sums.size():
		lod_counts[_scheduler.call("lod_name", i)] = snappedf(_lod_sums[i] / maxf(1.0, n), 0.1)
	var out := {
		"seed": _seed,
		"frames": n,
		"multiplier": _multiplier,
		"onscreen": 1 if _onscreen else 0,
		"rigs_awake": 1 if _rigs_awake else 0,
		"frame_ms_mean": snappedf(total / maxf(1.0, n), 0.001),
		"frame_ms_p50": snappedf(sorted[int(n * 0.5)], 0.001),
		"frame_ms_p95": snappedf(sorted[int(n * 0.95)], 0.001),
		"frame_ms_p99": snappedf(sorted[int(n * 0.99)], 0.001),
		"frame_ms_max": snappedf(sorted[n - 1], 0.001),
		"process_peak_ms": snappedf(_process_peak_ms / maxf(1.0, n), 0.001),
		"physics_peak_ms": snappedf(_physics_peak_ms / maxf(1.0, n), 0.001),
		"peak_nodes": _peak_nodes,
		"peak_mobs": _peak_mobs,
		"peak_collision_pairs": _peak_pairs,
		"lod_counts": lod_counts,
		"rigs_awake_mean": snappedf(_rig_sum / maxf(1.0, n), 0.1),
	}
	print("BENCH_RESULT " + JSON.stringify(out))
	quit()
