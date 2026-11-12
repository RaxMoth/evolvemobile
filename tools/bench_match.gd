extends SceneTree

## Headless performance benchmark: loads World.tscn in the stress config (all
## 39 camps active, lazy activation off, `stress_mob_multiplier` mobs per
## slot), lets both sides auto-play and measures the per-frame cost of
## scripts + physics. No rendering is measured (headless). Prints ONE JSON
## line. Use through tools/bench.sh (temp copy, isolated user://).
##
##   godot --headless --fixed-fps 60 --max-fps 0 --path <copy> \
##         -s res://tools/bench_match.gd -- <seed> [warmup_frames] [frames] [multiplier] [onscreen] [rigs_awake] [speed] [monster=<id>]
##
## "monster=<id>" picks the roster monster (GameManager.select_monster, not
## persisted; as in tools/sim_match.gd); without it the roster default plays.
## The result names it ("monster").
##
## The match keeps playing during the window and can end inside it (a seed
## whose heroes find the monster early). GameManager then pauses the tree, so
## the frames after it would time an idle tree: the run stops there and
## reports `ended_at_frame` (frames since start; -1 = the match outlived the
## window) with fewer measured `frames` (0 when it ended in the warm-up).
## tools/bench.sh flags such runs.
##
## CharacterRigs follow the same on-screen marking (onscreen=1); rigs_awake=1
## wakes EVERY rig (the zoomed-out worst case). `rigs_awake_mean` is the mean
## number of animating rigs (CharacterRig.awake_count()); a rig without a body
## (a character not migrated to SVG art yet) never wakes.
##
## `speed` is the match speed a player watches at (README "Match Speed"): 0
## (default) keeps game time as every headless run does, 1 plays the match's
## base speed and 2 the speed button's fast setting
## (GameManager.speed_scaling / set_match_fast). Engine.time_scale then
## stretches every frame's delta, so one frame covers `time_scale` / 60 game
## seconds (the result's "time_scale") and the mobs' 20/10/3 Hz AI ticks come
## that much more often per frame: the frame cost a device pays at that speed.
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
## leave the marking time out; cpu_s includes it.
##
## Every frame_ms sample is the time from one tick to the next inside the
## window: the first tick only starts the clock, so a warm-up of 0 does not
## time the world's loading as a frame. `frame_peak_ms` is the mean of the
## slowest frame of each PEAK_BLOCK measured frames (one game second): the
## spikes of the window itself. (Godot's TIME_PROCESS monitor is the slowest
## frame of the last wall-clock second, which at an unlocked frame rate
## reaches back hundreds of frames, into the warm-up and the world load.)

const WORLD := "res://Scenes/World/World.tscn"
## World px added around the camera rect (a notifier fires on its AABB, not
## on the mob's origin).
const ONSCREEN_MARGIN: float = 64.0
## Measured frames per frame_peak_ms block.
const PEAK_BLOCK := 60

var _seed: int = 1
var _warmup: int = 600
var _frames: int = 1800
var _multiplier: int = 2
var _onscreen: bool = false
var _rigs_awake: bool = false
## 0 = game time, 1 = the match's base speed, 2 = its fast setting.
var _speed: int = 0
## Engine.time_scale in the measured window.
var _time_scale: float = 1.0
## Roster id from "monster=<id>"; empty = the selection GameManager loaded.
var _monster_id: String = ""
## _frame when GameManager's match_ended fired; -1 while the match runs.
var _ended_at: int = -1
var _done: bool = false
var _frame: int = 0
var _last_us: int = 0
var _frame_ms: Array[float] = []
# Time the last tick spent in _mark_on_screen (left out of _frame_ms).
var _mark_us: int = 0
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
	var args := PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("monster="):
			_monster_id = arg.trim_prefix("monster=")
		else:
			args.append(arg)
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
	if args.size() > 6:
		_speed = int(args[6])
	_rig_script = load("res://Scripts/Rig/character_rig.gd")
	_rig_script.set("force_awake", _rigs_awake)
	# Autoloads are only reachable through the root once the tree runs.
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	seed(_seed)
	var gm := root.get_node("GameManager")
	gm.set("chosen_side", 0)
	if _monster_id != "":
		gm.call("select_monster", StringName(_monster_id), false)
	gm.connect("match_ended", _on_match_ended)
	if _speed > 0:
		gm.set("speed_scaling", true)
		gm.call("set_match_fast", _speed > 1, false)
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
	var now := Time.get_ticks_usec()
	if _last_us == 0:
		# The first tick starts the clock: before it lies the world's loading.
		_last_us = now
		return
	_frame += 1
	if _frame > _warmup:
		# The bench's own marking (last tick, ~0.1 ms) is not game cost.
		_frame_ms.append((now - _last_us - _mark_us) / 1000.0)
		_time_scale = Engine.time_scale
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


func _on_match_ended(_winner: String, _game_time: float) -> void:
	if _ended_at < 0:
		_ended_at = _frame
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
	if _done:
		return
	_done = true
	process_frame.disconnect(_tick)
	var n: int = _frame_ms.size()
	var sorted := _frame_ms.duplicate()
	sorted.sort()
	if sorted.is_empty():
		sorted.append(0.0)  # the match ended in the warm-up: zeros, nothing was measured
	var last: int = sorted.size() - 1
	var total: float = 0.0
	for ms in sorted:
		total += ms
	var lod_counts := {}
	for i in _lod_sums.size():
		lod_counts[_scheduler.call("lod_name", i)] = snappedf(_lod_sums[i] / maxf(1.0, n), 0.1)
	var out := {
		"seed": _seed,
		"monster": String(root.get_node("GameManager").get("selected_monster_id")),
		"frames": n,
		"ended_at_frame": _ended_at,
		"multiplier": _multiplier,
		"onscreen": 1 if _onscreen else 0,
		"rigs_awake": 1 if _rigs_awake else 0,
		"time_scale": snappedf(_time_scale, 0.01),
		"frame_ms_mean": snappedf(total / maxf(1.0, n), 0.001),
		"frame_ms_p50": snappedf(sorted[int(n * 0.5)], 0.001),
		"frame_ms_p95": snappedf(sorted[int(n * 0.95)], 0.001),
		"frame_ms_p99": snappedf(sorted[int(n * 0.99)], 0.001),
		"frame_ms_max": snappedf(sorted[last], 0.001),
		"frame_peak_ms": snappedf(_block_peak_ms(), 0.001),
		"peak_nodes": _peak_nodes,
		"peak_mobs": _peak_mobs,
		"peak_collision_pairs": _peak_pairs,
		"lod_counts": lod_counts,
		"rigs_awake_mean": snappedf(_rig_sum / maxf(1.0, n), 0.1),
	}
	print("BENCH_RESULT " + JSON.stringify(out))
	quit()


## The mean over blocks of PEAK_BLOCK measured frames (the last one may be
## shorter) of each block's slowest frame; 0 when nothing was measured.
func _block_peak_ms() -> float:
	var total := 0.0
	var blocks := 0
	for start in range(0, _frame_ms.size(), PEAK_BLOCK):
		var block_max := 0.0
		for i in range(start, mini(start + PEAK_BLOCK, _frame_ms.size())):
			block_max = maxf(block_max, _frame_ms[i])
		total += block_max
		blocks += 1
	return total / maxf(1.0, blocks)
