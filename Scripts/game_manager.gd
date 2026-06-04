extends Node

## GameManager — match orchestration: timer, kill tracking, end conditions,
## currency grant, result screen.
##
## Match end paths:
##   • All heroes dead   → MONSTER win  (heroes-side LOSS for the player)
##   • Monster dead      → HEROES win   (heroes-side WIN for the player)
##   • 10-min timeout    → MONSTER win  (heroes failed to find them in time)

signal heroes_won
signal monster_won
signal match_ended(winner: String, time: float)
signal match_timer_changed(remaining: float)

const MATCH_RESULT_SCENE: PackedScene = preload("res://Scenes/UI/MatchResult/MatchResult.tscn")

# Hard time cap — README "Design Debt: no clear loss condition timer" → fixed.
const DEFAULT_MAX_DURATION_SEC: float = 600.0  # 10 minutes

# ============================================
# State
# ============================================

# Side currently being played. Set by MainMenu before the scene change;
# reads as HEROES by default if the player launched directly into the World.
var chosen_side: int = MatchRewards.Side.HEROES

var max_match_duration: float = DEFAULT_MAX_DURATION_SEC
var match_start_time: float
var match_ended_flag: bool = false  # idempotency guard for _end_match

var heroes_alive: int = 0
var monster_alive: bool = false
var monster_stage_reached: int = 1
var mob_kills: int = 0


func _ready() -> void:
	# One-time setup. GameManager is autoload, so _ready fires ONCE per game
	# launch — never on scene reload. Per-match state is reset by
	# start_new_match() which world.gd calls on each World _ready.
	# NOTE: GameManager is reachable directly as an autoload (`GameManager.x`)
	# from anywhere — no group is needed, so we don't add_to_group here.
	process_mode = Node.PROCESS_MODE_ALWAYS  # timer ticks even during brief pauses
	EventBus.entity_died.connect(_on_entity_died)
	# Initial match — in case the player launched straight into World.tscn.
	start_new_match()


func start_new_match() -> void:
	## Called by world.gd on each World scene load (initial launch + every
	## "Play Again"). Resets per-match state so kills/timer don't carry
	## over from a previous match.
	match_start_time = Time.get_ticks_msec() / 1000.0
	match_ended_flag = false
	heroes_alive = 0
	monster_alive = false
	monster_stage_reached = 1
	mob_kills = 0

	await get_tree().process_frame
	await get_tree().process_frame
	_initial_census()


func _process(_delta: float) -> void:
	if match_ended_flag:
		return
	# Tick the visible match timer + check the hard cap.
	var elapsed: float = _elapsed()
	var remaining: float = maxf(0.0, max_match_duration - elapsed)
	match_timer_changed.emit(remaining)
	if remaining <= 0.0:
		_end_match_timeout()


func _elapsed() -> float:
	return (Time.get_ticks_msec() / 1000.0) - match_start_time


# ============================================
# Initial census + entity tracking
# ============================================

func _initial_census() -> void:
	heroes_alive = 0
	for node in get_tree().get_nodes_in_group("Hero"):
		if node is HeroBase:
			heroes_alive += 1

	var monster_count := 0
	for node in get_tree().get_nodes_in_group("Monster"):
		if node is MonsterBase:
			monster_count += 1
	monster_alive = monster_count > 0


func _on_entity_died(entity: Node, _killer: Node) -> void:
	if not is_instance_valid(entity):
		return

	# Kill counters (used by reward calc).
	if entity is MobBase:
		mob_kills += 1

	# Track the highest stage the monster reached so the result screen and
	# reward formula know what we faced.
	if entity is MonsterBase:
		var m := entity as MonsterBase
		if m.has_method("get_stage"):
			monster_stage_reached = maxi(monster_stage_reached, m.get_stage())

	# Match-end checks.
	if entity is MonsterBase:
		monster_alive = false
		_end_match_with_outcome(MatchRewards.Outcome.WIN)
	elif entity is HeroBase:
		heroes_alive -= 1
		if heroes_alive <= 0:
			_end_match_with_outcome(MatchRewards.Outcome.LOSS)


# ============================================
# End-of-match flow
# ============================================

func _end_match_timeout() -> void:
	# Monster auto-wins on timeout — heroes failed to find them.
	_end_match_with_outcome(MatchRewards.Outcome.TIMEOUT)


func _end_match_with_outcome(outcome: int) -> void:
	if match_ended_flag:
		return
	match_ended_flag = true

	var duration := _elapsed()
	var result := MatchRewards.compute(
		chosen_side,
		outcome,
		duration,
		mob_kills,
		maxi(0, heroes_alive),
		monster_stage_reached
	)

	# Emit legacy signals for any listeners (world.gd hooks them).
	if outcome == MatchRewards.Outcome.WIN:
		heroes_won.emit()
		match_ended.emit("Heroes", duration)
	else:
		monster_won.emit()
		match_ended.emit("Monster", duration)

	_apply_rewards_to_save(result)
	_show_result_screen(result)
	get_tree().paused = true


func _apply_rewards_to_save(result: MatchRewards.Result) -> void:
	if result.steel > 0:
		PersistedData.add_currency(PersistedData.STEEL, result.steel)
	if result.leaves > 0:
		PersistedData.add_currency(PersistedData.LEAVES, result.leaves)
	if result.gold > 0:
		PersistedData.add_currency(PersistedData.GOLD, result.gold)
	PersistedData.record_match_played()
	PersistedData.save_data()


func _show_result_screen(result: MatchRewards.Result) -> void:
	var screen: MatchResultScreen = MATCH_RESULT_SCENE.instantiate()
	# Add to current scene root so the screen lives until the next reload /
	# scene change (which is exactly when its buttons free it).
	var host: Node = get_tree().current_scene
	if host == null:
		host = get_tree().root
	host.add_child(screen)
	screen.populate(result)


# ============================================
# Public read-only helpers (HUDs / debug overlay can use these)
# ============================================

func get_match_remaining() -> float:
	if match_ended_flag:
		return 0.0
	return maxf(0.0, max_match_duration - _elapsed())


func get_match_elapsed() -> float:
	return _elapsed()


func get_mob_kills() -> int:
	return mob_kills
