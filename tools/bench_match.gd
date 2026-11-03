extends SceneTree

## Headless performance benchmark: loads World.tscn in the stress config (all
## 39 camps active, lazy activation off, `stress_mob_multiplier` mobs per
## slot), lets both sides auto-play and measures the per-frame cost of
## scripts + physics. No rendering is measured (headless). Prints ONE JSON
## line. Use through tools/bench.sh (temp copy, isolated user://).
##
##   godot --headless --fixed-fps 60 --max-fps 0 --path <copy> \
##         -s res://tools/bench_match.gd -- <seed> [warmup_frames] [frames] [multiplier]

const WORLD := "res://Scenes/World/World.tscn"

var _seed: int = 1
var _warmup: int = 600
var _frames: int = 1800
var _multiplier: int = 2
var _frame: int = 0
var _last_us: int = 0
var _frame_ms: Array[float] = []
# Godot's TIME_PROCESS / TIME_PHYSICS_PROCESS monitors hold the slowest frame
# of the last second (refreshed once per second): summed per frame they give
# the mean of those per-second peaks.
var _process_peak_ms: float = 0.0
var _physics_peak_ms: float = 0.0
var _peak_nodes: int = 0
var _peak_mobs: int = 0
var _peak_pairs: int = 0


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
	process_frame.connect(_tick)


func _tick() -> void:
	_frame += 1
	var now := Time.get_ticks_usec()
	if _frame > _warmup:
		_frame_ms.append((now - _last_us) / 1000.0)
		_process_peak_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		_physics_peak_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		_peak_nodes = maxi(_peak_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		_peak_pairs = maxi(_peak_pairs, int(Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS)))
		_peak_mobs = maxi(_peak_mobs, (root.get_node("EntityRegistry").get("mobs") as Array).size())
	_last_us = now
	if _frame >= _warmup + _frames:
		_finish()


func _finish() -> void:
	process_frame.disconnect(_tick)
	var sorted := _frame_ms.duplicate()
	sorted.sort()
	var n: int = sorted.size()
	var total: float = 0.0
	for ms in sorted:
		total += ms
	var out := {
		"seed": _seed,
		"frames": n,
		"multiplier": _multiplier,
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
	}
	print("BENCH_RESULT " + JSON.stringify(out))
	quit()
