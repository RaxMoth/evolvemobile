extends Node

## AnalyticsSink — buffers gameplay events and appends them as JSON lines to
## user://analytics.jsonl. Local only for now; a remote provider can be plugged
## in later through `set_provider(callable)` without touching the call sites.
##
## Events are small dictionaries: {"t": unix seconds, "name": ..., ...props}.
## Respects the PersistedData setting `analytics_opt_out` (Settings screen).
##
## Hooks (autoloads cannot be scene [connection] targets):
##   PersistedData.data_loaded      → session_start
##   GameManager.match_ended        → match_ended
##   MetaSkillManager.skill_unlocked → skill_unlocked
## Other call sites (tutorial) call track() directly.

const LOG_PATH := "user://analytics.jsonl"
const SETTING_OPT_OUT: StringName = &"analytics_opt_out"
const FLUSH_INTERVAL: float = 5.0
const FLUSH_AT_EVENTS: int = 20

var _buffer: Array[Dictionary] = []
var _flush_timer: float = 0.0
var _provider: Callable = Callable()
var _events_written: int = 0


func _ready() -> void:
	PersistedData.data_loaded.connect(_on_data_loaded)
	GameManager.match_ended.connect(_on_match_ended)
	MetaSkillManager.skill_unlocked.connect(_on_skill_unlocked)
	if PersistedData.is_loaded():
		_on_data_loaded()


func _process(delta: float) -> void:
	_flush_timer += delta
	if _flush_timer >= FLUSH_INTERVAL:
		_flush_timer = 0.0
		flush()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		flush()


func _exit_tree() -> void:
	flush()


# ============================================
# Public API
# ============================================

func is_enabled() -> bool:
	return not bool(PersistedData.get_setting(SETTING_OPT_OUT, false))


func set_opt_out(opt_out: bool) -> void:
	PersistedData.set_setting(SETTING_OPT_OUT, opt_out)
	PersistedData.save_data()
	if opt_out:
		_buffer.clear()


## Record one event. `props` must be JSON-serializable.
func track(event_name: StringName, props: Dictionary = {}) -> void:
	if not is_enabled():
		return
	var event: Dictionary = {"t": int(Time.get_unix_time_from_system()), "name": String(event_name)}
	event.merge(props)
	_buffer.append(event)
	if _provider.is_valid():
		_provider.call(event)
	if _buffer.size() >= FLUSH_AT_EVENTS:
		flush()


## Append buffered events to the log file. Returns the number written.
func flush() -> int:
	if _buffer.is_empty():
		return 0
	var file := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE)
	if file == null:
		push_warning("AnalyticsSink: cannot open %s (err %d); dropping %d events" % [LOG_PATH, FileAccess.get_open_error(), _buffer.size()])
		_buffer.clear()
		return 0
	file.seek_end()
	var written := 0
	for event in _buffer:
		file.store_line(JSON.stringify(event))
		written += 1
	file.close()
	_buffer.clear()
	_events_written += written
	return written


func pending_count() -> int:
	return _buffer.size()


func events_written() -> int:
	return _events_written


## Future remote backend: receives every event dictionary as it is tracked.
func set_provider(provider: Callable) -> void:
	_provider = provider


# ============================================
# Hooks
# ============================================

func _on_data_loaded() -> void:
	track(&"session_start", {
		"save_version": PersistedData.get_save_version(),
		"total_matches": PersistedData.get_total_matches(),
	})


func _on_match_ended(winner: String, duration: float) -> void:
	track(&"match_ended", {
		"winner": winner,
		"duration_sec": int(duration),
		"side": "heroes" if GameManager.chosen_side == MatchRewards.Side.HEROES else "monster",
		"monster": String(GameManager.selected_monster_id),
		"mob_kills": GameManager.get_mob_kills(),
		"monster_stage": GameManager.monster_stage_reached,
	})


func _on_skill_unlocked(tree_id: StringName, node_id: StringName) -> void:
	track(&"skill_unlocked", {"tree": String(tree_id), "node": String(node_id)})
