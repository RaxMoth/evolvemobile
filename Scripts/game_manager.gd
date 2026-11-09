extends Node

## GameManager — match orchestration: timer, kill tracking, end conditions,
## currency grant, result screen.
##
## Match end paths:
##   • All heroes dead   → MONSTER win  (heroes-side LOSS for the player)
##   • Monster dead      → HEROES win   (heroes-side WIN for the player)
##   • 10-min timeout    → MONSTER win  (heroes failed to find them in time)

signal match_ended(winner: String, time: float)

const MATCH_RESULT_SCENE: PackedScene = preload("res://Scenes/UI/MatchResult/MatchResult.tscn")

# Hard time cap — README "Design Debt: no clear loss condition timer" → fixed.
const DEFAULT_MAX_DURATION_SEC: float = 600.0  # 10 minutes

# ============================================
# State
# ============================================

# Side currently being played. Set by MainMenu before the scene change;
# reads as HEROES by default if the player launched directly into the World.
var chosen_side: int = MatchRewards.Side.HEROES

## World.tscn once MainMenu has loaded it (in the background, see
## main_menu.gd). Held here for the whole session so later menu visits and
## Play Again (reload_current_scene) reuse the cached scene instead of loading
## it again.
var world_scene: PackedScene = null

var max_match_duration: float = DEFAULT_MAX_DURATION_SEC
var match_ended_flag: bool = false  # idempotency guard for _end_match
## True only between World's start_new_match() and the end/abort of that match.
## The clock never runs in menus.
var _match_active: bool = false
## Unpaused GAME time since the match started (not wall clock: a paused tree or
## a backgrounded app must not eat into the 10-minute cap).
var _match_time: float = 0.0
## Largest frame delta the clock accepts (a resume from background can deliver
## one huge delta).
const MAX_CLOCK_STEP: float = 0.25

var heroes_alive: int = 0
var monster_alive: bool = false
var monster_stage_reached: int = 1
var mob_kills: int = 0

# Characters that participated this match, captured at census so permanent XP
# can be awarded even after their nodes are freed by match end.
var _participating_hero_ids: Array[StringName] = []
var _monster_id: StringName = DEFAULT_MONSTER_ID

# Substrings identifying each hero by node name (mirrors world.gd vision_map).
const KNOWN_HERO_IDS: Array[StringName] = [&"river", &"vlad", &"ted", &"irelia"]
# Fallback persistent XP key before the census ran (the roster's default).
const DEFAULT_MONSTER_ID: StringName = &"grount"
## Every playable character (one CharacterDef each). World's MonsterSlot spawns
## ROSTER.resolve_monster(selected_monster_id).
const ROSTER: Roster = preload("res://Scenes/NPCs/roster.tres")
const SETTING_SELECTED_MONSTER: StringName = &"selected_monster"
## The monster of the NEXT match (played or opposed), always a roster id. Set
## through select_monster() by the menus and the sim tools before World loads;
## persisted as a setting.
var selected_monster_id: StringName = DEFAULT_MONSTER_ID


func _ready() -> void:
	# One-time setup. GameManager is autoload, so _ready fires ONCE per game
	# launch — never on scene reload. Per-match state is reset by
	# start_new_match() which world.gd calls on each World _ready.
	# NOTE: GameManager is reachable directly as an autoload (`GameManager.x`)
	# from anywhere — no group is needed, so we don't add_to_group here.
	# ALWAYS so _process keeps running while the result screen pauses the tree;
	# the clock itself only advances while unpaused (see _process).
	process_mode = Node.PROCESS_MODE_ALWAYS
	var saved_monster: Variant = PersistedData.get_setting(SETTING_SELECTED_MONSTER, String(ROSTER.default_monster_id))
	select_monster(StringName(str(saved_monster)), false)
	EventBus.entity_died.connect(_on_entity_died)
	# Record evolution as it happens: the old death-only update paid a monster
	# that WON (or survived to the timeout) as stage 1.
	EventBus.monster_evolved.connect(_on_monster_evolved)
	# No match here: world.gd calls start_new_match() on every World load. The
	# old unconditional call started the 10-minute clock in the main menu, which
	# ended a phantom "match" (result screen + rewards) after 10 idle minutes.


## Picks the next match's monster. An unknown or removed id falls back to the
## roster default, so a stale save or sim argument never breaks a match.
func select_monster(monster_id: StringName, persist: bool = true) -> void:
	var def := ROSTER.resolve_monster(monster_id)
	selected_monster_id = def.character_id() if def != null else DEFAULT_MONSTER_ID
	if persist:
		PersistedData.set_setting(SETTING_SELECTED_MONSTER, String(selected_monster_id))
		PersistedData.save_data()


func selected_monster_def() -> CharacterDef:
	return ROSTER.resolve_monster(selected_monster_id)


func start_new_match() -> void:
	## Called by world.gd on each World scene load (initial launch + every
	## "Play Again"). Resets per-match state so kills/timer don't carry
	## over from a previous match.
	_match_time = 0.0
	_match_active = true
	match_ended_flag = false
	heroes_alive = 0
	monster_alive = false
	monster_stage_reached = 1
	mob_kills = 0
	_participating_hero_ids.clear()

	await get_tree().process_frame
	await get_tree().process_frame
	_initial_census()


func _process(delta: float) -> void:
	if not _match_active or match_ended_flag:
		return
	if not get_tree().paused:
		_match_time += minf(delta, MAX_CLOCK_STEP)
	# Check the hard cap every frame.
	if _elapsed() >= max_match_duration:
		_end_match_timeout()


func _elapsed() -> float:
	return _match_time


## World is leaving the tree without a decided match (scene change): stop the
## clock so nothing ends a match that no longer exists.
func abort_match() -> void:
	_match_active = false


func is_match_active() -> bool:
	return _match_active and not match_ended_flag


# ============================================
# Initial census + entity tracking
# ============================================

func _initial_census() -> void:
	heroes_alive = 0
	_participating_hero_ids.clear()
	for node in get_tree().get_nodes_in_group("Hero"):
		if node is HeroBase:
			heroes_alive += 1
			var hero_id := _hero_id_from(node)
			if hero_id not in _participating_hero_ids:
				_participating_hero_ids.append(hero_id)

	var monster_count := 0
	for node in get_tree().get_nodes_in_group("Monster"):
		if node is MonsterBase:
			monster_count += 1
			var m := node as MonsterBase
			_monster_id = m.monster_stats.monster_id if m.monster_stats and m.monster_stats.monster_id != &"" else StringName(node.name.to_lower())
	monster_alive = monster_count > 0


func _hero_id_from(node: Node) -> StringName:
	## Persistent character id: HeroStats.hero_id (the save key), with the old
	## name-substring convention only as a fallback for unconfigured heroes.
	var from_stats := MetaSkillManager.hero_id_of(node)
	if from_stats != &"":
		return from_stats
	var lowered := node.name.to_lower()
	for known in KNOWN_HERO_IDS:
		if String(known) in lowered:
			return known
	return StringName(lowered)


func _on_monster_evolved(_monster: Node, stage: int) -> void:
	monster_stage_reached = maxi(monster_stage_reached, stage)


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

	# Match-end checks (only while a match is running).
	if not is_match_active():
		return
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
	_match_active = false

	var duration := _elapsed()
	# `outcome` is the heroes' perspective (match_ended below keeps it).
	# Rewards, label and jingle must use the PLAYED side's perspective.
	var player_outcome := MatchRewards.outcome_for_side(chosen_side, outcome)
	var result := MatchRewards.compute(
		chosen_side,
		player_outcome,
		duration,
		mob_kills,
		maxi(0, heroes_alive),
		monster_stage_reached
	)

	# match_ended feeds analytics, audio and the sim.
	if outcome == MatchRewards.Outcome.WIN:
		match_ended.emit("Heroes", duration)
	else:
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

	# Permanent XP — persisted per participating character on the played side.
	if result.xp > 0:
		if result.side == MatchRewards.Side.HEROES:
			for hero_id in _participating_hero_ids:
				PersistedData.add_hero_xp(hero_id, result.xp)
		else:
			PersistedData.add_monster_xp(_monster_id, result.xp)

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

func get_match_elapsed() -> float:
	return _elapsed()


func get_mob_kills() -> int:
	return mob_kills
