extends Node

## GameManager — match orchestration: timer, kill tracking, end conditions,
## currency grant, result screen (MatchResultScreen; its Lobby goes back to
## MenuRoot, and its "upgrades ready" asks MenuRoot for that side's roster
## through request_menu_roster()).
##
## Match end paths:
##   • All heroes dead   → MONSTER win  (heroes-side LOSS for the player)
##   • Monster dead      → HEROES win   (heroes-side WIN for the player)
##   • 10-min timeout    → MONSTER win  (heroes failed to find them in time)
##
## A death that decides the match ends it at once (outcome, clock,
## match_ended); the rewards and the save follow at the end of that frame,
## once the kill's XP has reached the monster (an evolution it causes pays).
## Then the match runs on for DEATH_BEAT_SEC so the monster's or the last
## hero's death beat plays (CharacterRig) before the result screen comes up
## over the paused tree (result_shown). In the beat no hit lands: nobody dies
## after the decision and no kill feeds the monster, so the beat, the result
## screen and the rewards agree. A timeout shows the result at once.
##
## Match speed (README "Match Speed"): a running match plays MATCH_BASE_SPEED
## game seconds per real second, times MATCH_FAST_FACTOR while the HUD's speed
## button is on fast (match_speed()). _sync_time_scale() keeps
## Engine.time_scale on that value while a match runs unpaused and on 1
## everywhere else: the pause menu, the death beat, the result screen, the
## menus. A headless run (the sims, the trace, the tests) keeps game time.

signal match_ended(winner: String, time: float)
## The result screen came up and the tree paused under it (the end of the
## death beat, or at once on a timeout). AudioManager silences the world's
## sounds here, so none of them finishes when the player leaves the screen.
signal result_shown

const MATCH_RESULT_SCENE: PackedScene = preload("res://Scenes/UI/Screens/MatchResultScreen.tscn")

# Hard time cap — README "Design Debt: no clear loss condition timer" → fixed.
const DEFAULT_MAX_DURATION_SEC: float = 600.0  # 10 minutes
## Game seconds between the death that decided the match and the result
## screen: the fall and fade of the monster or the last hero
## (CharacterRig.DEATH_TIME) and a breath.
const DEATH_BEAT_SEC: float = CharacterRig.DEATH_TIME + 0.15

# ============================================
# State
# ============================================

# Side currently being played (MatchRewards.Side). The lobby chooses it
# through choose_side(), which persists it, so the next launch opens on the
# same side; reads as HEROES on a fresh save. The sim tools set it directly.
var chosen_side: int = MatchRewards.Side.HEROES
const SETTING_CHOSEN_SIDE: StringName = &"chosen_side"

## Not preloaded: a preload would load the whole match at boot (GameManager ->
## World). The menus call request_world_load() on entry and collect it with
## get_world_scene().
const WORLD_PATH := "res://Scenes/World/World.tscn"
## World.tscn once a menu has loaded it (in the background). Held here for the
## whole session so later menu visits and Play Again (reload_current_scene)
## reuse the cached scene instead of loading it again.
var world_scene: PackedScene = null

var max_match_duration: float = DEFAULT_MAX_DURATION_SEC
var match_ended_flag: bool = false  # idempotency guard for _end_match
## True only between World's start_new_match() and the end/abort of that match.
## The clock never runs in menus.
var _match_active: bool = false
## Unpaused GAME time since the match started (not wall clock: a paused tree or
## a backgrounded app must not eat into the 10-minute cap).
var _match_time: float = 0.0
## Largest frame the clock accepts, in real seconds (a resume from background
## can deliver one huge delta; the delta itself is in game seconds).
const MAX_CLOCK_STEP: float = 0.25
## Counts the matches started and aborted: a result held back for the death
## beat is dropped when its match is no longer the current one.
var _match_serial: int = 0
## True from the death that decided the match until its result screen (the
## death beat): every hit is canceled (_on_damage_requested). Not
## match_ended_flag: the test runner holds that one true.
var _death_beat: bool = false

# --- Match speed ---
## The match's base speed: game seconds per real second while a match runs at
## the speed button's normal setting. The one number that sets the time scale
## of a round (the clock, cooldowns, movement, effects and the HUD all follow
## it); how fast each character walks is its own data (README "Match Speed").
const MATCH_BASE_SPEED: float = 1.2
## The speed button's fast setting: the base speed times this.
const MATCH_FAST_FACTOR: float = 2.0
const SETTING_MATCH_FAST: StringName = &"match_fast"
## The player's choice on the HUD's speed button, kept between matches and
## sessions (set_match_fast).
var match_fast: bool = false
## False in a headless run (the sims, the determinism trace, the tests): with
## nobody watching, a match keeps game time (Engine.time_scale 1) and plays
## exactly as it always did. tools/bench.sh's speed argument and the speed
## tests turn it on.
var speed_scaling: bool = DisplayServer.get_name() != "headless"

var heroes_alive: int = 0
var monster_alive: bool = false
var monster_stage_reached: int = 1
## Every mob death this match, whoever killed it (the determinism trace hashes
## it: keep its meaning).
var mob_kills: int = 0
## The mobs each side killed (killer_side()): the heroes' (a hero, Ted's pet,
## or a trap, mine or cage, which name their caster) and the monster's own. The
## played side's count (played_side_kills()) pays the rewards and shows in the
## HUD's kills chip and the result.
var hero_mob_kills: int = 0
var monster_mob_kills: int = 0
## This match's Opponent Threat (README "Opponent Threat"), taken when it
## starts (MetaSkillManager.opponent_threat(), from the played side's save):
## the AI opponent's build and the rewards' bonus. Entities read the same
## value at their spawn.
var match_threat: int = 0

# Characters that participated this match, captured at census so permanent XP
# can be awarded even after their nodes are freed by match end.
var _participating_hero_ids: Array[StringName] = []
## The heroes that died this match, in order (MatchRewards.Result.fallen_hero_ids).
var _fallen_hero_ids: Array[StringName] = []
var _monster_id: StringName = DEFAULT_MONSTER_ID
## The side whose roster MenuRoot opens on its next entry (the match result's
## "upgrades ready"); -1 = none. request_menu_roster() / take_menu_roster().
var _menu_roster_side: int = -1

# Substrings identifying each hero by node name (mirrors world.gd vision_map).
const KNOWN_HERO_IDS: Array[StringName] = [&"river", &"vlad", &"ted", &"irelia"]
# Fallback persistent XP key before the census ran (the roster's default).
const DEFAULT_MONSTER_ID: StringName = &"grount"
## Every playable character (one CharacterDef each). World's MonsterSlot spawns
## ROSTER.resolve_monster(selected_monster_id).
const ROSTER: Roster = preload("res://Scenes/NPCs/roster.tres")
## The player's own monster (Monster side), an owned one: written by
## choose_monster() (and select_monster(id) with persist), read back by
## played_monster_id().
const SETTING_SELECTED_MONSTER: StringName = &"selected_monster"
## The monster of the NEXT match (played or hunted), always a roster id.
## begin_hunt() sets it for the chosen side right before the menus load World
## (the quarry, or the player's own monster); the sim tools set it with
## select_monster(id, false). Starts as the saved own monster.
var selected_monster_id: StringName = DEFAULT_MONSTER_ID

# --- Heroes side: tonight's quarry ---
# The pool is every roster monster the save has played enough matches to meet
# (PersistedData total matches >= CharacterDef.opponent_after_matches: Grount 0,
# Nyxa 3, Gorrak 6), independent of what the Monster side owns. The pick is
# random among the pool, never the last quarry again while the pool has two or
# more, unless the pre-round Change picker locked one (lock_quarry).
## Draws the random quarry. PRIVATE: the global RNG drives gameplay (and the
## determinism trace) and is never touched by a menu pick.
var _quarry_rng := RandomNumberGenerator.new()
## This session's random pick, kept until a hunt starts, so reopening the
## pre-round shows the same quarry.
var _rolled_quarry: StringName = &""


func _ready() -> void:
	# One-time setup. GameManager is autoload, so _ready fires ONCE per game
	# launch — never on scene reload. Per-match state is reset by
	# start_new_match() which world.gd calls on each World _ready.
	# NOTE: GameManager is reachable directly as an autoload (`GameManager.x`)
	# from anywhere — no group is needed, so we don't add_to_group here.
	# ALWAYS so _process keeps running while the result screen pauses the tree;
	# the clock itself only advances while unpaused (see _process).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_quarry_rng.randomize()
	load_saved_choices()
	EventBus.entity_died.connect(_on_entity_died)
	# The death beat: connected before any entity's listener (Irelia's shield),
	# so a canceled hit uses up no shield.
	EventBus.damage_requested.connect(_on_damage_requested)
	# Record evolution as it happens: the old death-only update paid a monster
	# that WON (or survived to the timeout) as stage 1.
	EventBus.monster_evolved.connect(_on_monster_evolved)
	# No match here: world.gd calls start_new_match() on every World load. The
	# old unconditional call started the 10-minute clock in the main menu, which
	# ended a phantom "match" (result screen + rewards) after 10 idle minutes.


## The player's saved choices: the own monster, the side, the match speed.
## An unknown id or a value of the wrong type reads as the default
## (PersistedData.get_setting), so a damaged save never breaks the menu.
func load_saved_choices() -> void:
	var saved_monster: Variant = PersistedData.get_setting(SETTING_SELECTED_MONSTER, String(ROSTER.default_monster_id))
	select_monster(StringName(str(saved_monster)), false)
	var saved_side: Variant = PersistedData.get_setting(SETTING_CHOSEN_SIDE, MatchRewards.Side.HEROES)
	choose_side(int(saved_side), false)
	match_fast = bool(PersistedData.get_setting(SETTING_MATCH_FAST, false))


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


## The player's own monster (Monster side): the saved choice while the player
## owns it (CharacterProgress.is_unlocked), else the roster default.
func played_monster_id() -> StringName:
	var saved := StringName(str(PersistedData.get_setting(SETTING_SELECTED_MONSTER, "")))
	var def := ROSTER.find(saved)
	if def != null and def.is_monster() and CharacterProgress.is_unlocked(def):
		return saved
	return ROSTER.resolve_monster(ROSTER.default_monster_id).character_id()


## Makes an owned monster the player's own (Monster side) and persists it;
## the next Monster-side hunt plays it (begin_hunt). False (nothing changes)
## for a monster the player does not own.
func choose_monster(monster_id: StringName) -> bool:
	var def := ROSTER.find(monster_id)
	if def == null or not def.is_monster() or not CharacterProgress.is_unlocked(def):
		return false
	PersistedData.set_setting(SETTING_SELECTED_MONSTER, String(monster_id))
	PersistedData.save_data()
	return true


## The Heroes-side quarry pool, in roster order (see "tonight's quarry" above).
func quarry_pool() -> Array[StringName]:
	var out: Array[StringName] = []
	var played := PersistedData.get_total_matches()
	for d in ROSTER.monsters:
		if d != null and played >= d.opponent_after_matches:
			out.append(d.character_id())
	return out


## Hunts still to play before `def` joins the quarry pool (0: in it). The
## Change picker's silhouettes read "appears after N hunts".
func hunts_until_quarry(def: CharacterDef) -> int:
	return 0 if def == null else maxi(0, def.opponent_after_matches - PersistedData.get_total_matches())


## A random quarry from `pool` drawn with `rng`, never `last` while the pool
## has two or more; the roster default for an empty pool.
func roll_quarry(pool: Array[StringName], last: StringName, rng: RandomNumberGenerator) -> StringName:
	var picks: Array[StringName] = []
	for id in pool:
		if pool.size() < 2 or id != last:
			picks.append(id)
	if picks.is_empty():
		return ROSTER.default_monster_id
	return picks[rng.randi_range(0, picks.size() - 1)]


## Tonight's quarry: the locked one while it is in the pool, else this
## session's random pick (rolled on first ask, kept until a hunt starts).
func next_quarry() -> StringName:
	var pool := quarry_pool()
	var locked := locked_quarry()
	if locked != &"":
		return locked
	if not pool.has(_rolled_quarry):
		_rolled_quarry = roll_quarry(pool, PersistedData.get_last_quarry(), _quarry_rng)
	return _rolled_quarry


## The quarry the Change picker fixed while it is in the pool; &"" = random.
func locked_quarry() -> StringName:
	var locked := PersistedData.get_locked_quarry()
	return locked if locked != &"" and quarry_pool().has(locked) else &""


## The Change picker: fix the quarry to `monster_id` (one of the pool) or,
## with &"" (Random), go back to a random pick each hunt. Persisted.
func lock_quarry(monster_id: StringName) -> void:
	if monster_id != &"" and not quarry_pool().has(monster_id):
		return
	PersistedData.set_locked_quarry(monster_id)
	PersistedData.save_data()


## True until the heroes have hunted `monster_id` once: its NEW QUARRY flag.
## The first hunt adds its Codex entry (begin_hunt).
func is_new_quarry(monster_id: StringName) -> bool:
	return not PersistedData.has_codex_entry(PersistedData.CODEX_MONSTERS, monster_id)


## The menus call this right before they load World (HUNT, Play Again): it
## sets the match's monster for the chosen side. The Heroes side hunts
## `quarry_id` when it is in the pool, else next_quarry(), records it as the
## last quarry and adds its Codex entry (a first sighting); the Monster side
## plays played_monster_id(). The sim tools never call it: they pick the
## monster with select_monster.
func begin_hunt(quarry_id: StringName = &"") -> void:
	if chosen_side == MatchRewards.Side.HEROES:
		var id := quarry_id if quarry_pool().has(quarry_id) else next_quarry()
		select_monster(id, false)
		PersistedData.set_last_quarry(selected_monster_id)
		PersistedData.add_codex_entry(PersistedData.CODEX_MONSTERS, selected_monster_id)
		_rolled_quarry = &""
	else:
		select_monster(played_monster_id(), false)
	PersistedData.save_data()


## The side the player plays next (the lobby's choice). Anything but MONSTER
## reads as HEROES, so a corrupt setting never breaks the menu.
func choose_side(side: int, persist: bool = true) -> void:
	chosen_side = MatchRewards.Side.MONSTER if side == MatchRewards.Side.MONSTER else MatchRewards.Side.HEROES
	if persist:
		PersistedData.set_setting(SETTING_CHOSEN_SIDE, chosen_side)
		PersistedData.save_data()


## Starts loading World.tscn on a worker thread while the player is in the
## menu (first visit of the session only; get_world_scene() collects it).
func request_world_load() -> void:
	if world_scene == null and ResourceLoader.load_threaded_get_status(WORLD_PATH) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(WORLD_PATH)


## The World scene, from the session cache or else from the background load
## request_world_load() started (blocks until it finishes). Collects that load
## at most once: a second load_threaded_get for the same request returns null.
## Falls back to a plain load if no request is pending or it failed.
func get_world_scene() -> PackedScene:
	if world_scene == null:
		var scene: PackedScene = null
		if ResourceLoader.load_threaded_get_status(WORLD_PATH) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			scene = ResourceLoader.load_threaded_get(WORLD_PATH) as PackedScene
		if scene == null:
			scene = load(WORLD_PATH) as PackedScene
		world_scene = scene
	return world_scene


func start_new_match() -> void:
	## Called by world.gd on each World scene load (initial launch + every
	## "Play Again"). Resets per-match state so kills/timer don't carry
	## over from a previous match.
	_match_serial += 1
	_match_time = 0.0
	_match_active = true
	match_ended_flag = false
	_death_beat = false
	heroes_alive = 0
	monster_alive = false
	monster_stage_reached = 1
	mob_kills = 0
	hero_mob_kills = 0
	monster_mob_kills = 0
	match_threat = MetaSkillManager.opponent_threat()
	_participating_hero_ids.clear()
	_fallen_hero_ids.clear()
	_sync_time_scale()

	await get_tree().process_frame
	await get_tree().process_frame
	_initial_census()


func _process(delta: float) -> void:
	# Every frame: a pause (the pause menu, the result screen) has no signal.
	_sync_time_scale()
	if not _match_active or match_ended_flag:
		return
	if not get_tree().paused:
		_match_time += minf(delta, MAX_CLOCK_STEP * Engine.time_scale)
	# Check the hard cap every frame.
	if _elapsed() >= max_match_duration:
		_end_match_timeout()


func _elapsed() -> float:
	return _match_time


## World is leaving the tree without a decided match (scene change): stop the
## clock so nothing ends a match that no longer exists.
func abort_match() -> void:
	_match_serial += 1
	_match_active = false
	_death_beat = false
	_sync_time_scale()


func is_match_active() -> bool:
	return _match_active and not match_ended_flag


# ============================================
# Match speed
# ============================================

## The HUD's speed button: the normal or the fast setting, for this match and
## the next ones (`persist` false: not written to the save).
func set_match_fast(fast: bool, persist: bool = true) -> void:
	match_fast = fast
	if persist:
		PersistedData.set_setting(SETTING_MATCH_FAST, fast)
		PersistedData.save_data()
	_sync_time_scale()


## Game seconds per real second of a running match at the player's setting.
func match_speed() -> float:
	return MATCH_BASE_SPEED * (MATCH_FAST_FACTOR if match_fast else 1.0)


## Puts Engine.time_scale where the match is: match_speed() while a match runs
## unpaused, 1 for everything else (the pause menu, the death beat, the
## result screen, a scene change, the menus) and for a run without
## speed_scaling. Engine.time_scale scales every delta, timer, tween and
## effect, so the whole match speeds up as one.
func _sync_time_scale() -> void:
	var running := speed_scaling and is_match_active() and not get_tree().paused
	var time_scale := match_speed() if running else 1.0
	if not is_equal_approx(Engine.time_scale, time_scale):
		Engine.time_scale = time_scale


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


## The death beat: the decided match deals no damage until its result screen.
func _on_damage_requested(packet: DamagePacket) -> void:
	if _death_beat:
		packet.canceled = true


## True during the death beat (from the deciding death to the result screen).
func in_death_beat() -> bool:
	return _death_beat


func _on_entity_died(entity: Node, killer: Node) -> void:
	if not is_instance_valid(entity):
		return

	# Kill counters: every mob death, and each side's own (the rewards).
	if entity is MobBase:
		mob_kills += 1
		match killer_side(killer):
			MatchRewards.Side.HEROES:
				hero_mob_kills += 1
			MatchRewards.Side.MONSTER:
				monster_mob_kills += 1

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
		_end_match_with_outcome(MatchRewards.Outcome.WIN, DEATH_BEAT_SEC)
	elif entity is HeroBase:
		heroes_alive -= 1
		_fallen_hero_ids.append(_hero_id_from(entity))
		if heroes_alive <= 0:
			_end_match_with_outcome(MatchRewards.Outcome.LOSS, DEATH_BEAT_SEC)


# ============================================
# End-of-match flow
# ============================================

func _end_match_timeout() -> void:
	# Monster auto-wins on timeout — heroes failed to find them.
	_end_match_with_outcome(MatchRewards.Outcome.TIMEOUT)


## Ends the match now: the outcome, the clock and match_ended. `beat` > 0 (a
## deciding death) settles the rewards at the end of this frame and holds the
## result screen and the pause back that many game seconds (the death beat, in
## which no hit lands); a timeout settles and shows the result at once.
func _end_match_with_outcome(outcome: int, beat: float = 0.0) -> void:
	if match_ended_flag:
		return
	match_ended_flag = true
	_match_active = false
	# The death beat and the result screen play at normal speed.
	_sync_time_scale()

	var duration := _elapsed()
	# match_ended feeds analytics, audio and the sim. `outcome` is the
	# heroes' perspective; the result takes the played side's.
	if outcome == MatchRewards.Outcome.WIN:
		match_ended.emit("Heroes", duration)
	else:
		match_ended.emit("Monster", duration)

	if beat > 0.0:
		_death_beat = true
		var beat_timer := get_tree().create_timer(beat, false)
		# Deferred: we are inside the deciding entity_died, and the kill's XP
		# reaches the monster only after it (EntityBase._on_dead_state_entered),
		# so an evolution it causes is in monster_stage_reached by then.
		_settle_after_death.call_deferred(outcome, duration, beat_timer, _match_serial)
		return
	var result := _settle(outcome, duration)
	_show_result(result)


## The result of the decided match (the PLAYED side's view), paid into the
## save.
func _settle(outcome: int, duration: float) -> MatchRewards.Result:
	# The played side's kills pay (README "Earning Rates v2": a kill by the
	# played side), not every mob death.
	var result := MatchRewards.compute(
		chosen_side,
		MatchRewards.outcome_for_side(chosen_side, outcome),
		duration,
		played_side_kills(),
		maxi(0, heroes_alive),
		monster_stage_reached,
		match_threat
	)
	result.hero_ids.assign(_participating_hero_ids)
	result.fallen_hero_ids.assign(_fallen_hero_ids)
	result.monster_id = _monster_id
	_apply_rewards_to_save(result)
	return result


## The death beat: the decided match is settled at the end of the deciding
## death's frame and runs on (its clock stopped, the HUD's pause off, no hit
## landing) until `beat_timer` (game time), then the result screen comes up
## over the paused tree. Dropped, paying nothing, when that World is gone by
## then (abort_match) or a new match began.
func _settle_after_death(outcome: int, duration: float, beat_timer: SceneTreeTimer, serial: int) -> void:
	if serial != _match_serial or not match_ended_flag:
		return
	var result := _settle(outcome, duration)
	if beat_timer.time_left > 0.0:
		await beat_timer.timeout
	if serial != _match_serial or not match_ended_flag:
		return
	_show_result(result)


## The result screen over the paused tree (result_shown).
func _show_result(result: MatchRewards.Result) -> void:
	_death_beat = false
	_show_result_screen(result)
	get_tree().paused = true
	result_shown.emit()


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
	var screen := MATCH_RESULT_SCENE.instantiate() as MatchResultScreen
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


## The played side's mob kills: the heroes' on the Heroes side, the monster's
## own on the Monster side (the HUD's kills chip, the rewards, the result).
func played_side_kills() -> int:
	return monster_mob_kills if chosen_side == MatchRewards.Side.MONSTER else hero_mob_kills


## The side a killing blow came from: MONSTER for a MonsterBase, HEROES for a
## HeroBase or anything else in the "Hero" group (Ted's pet; traps, mines and
## the cage deal their damage as their caster), -1 for the rest (a mob, a freed
## source, World's debug kill).
func killer_side(killer: Node) -> int:
	if killer == null or not is_instance_valid(killer):
		return -1
	if killer is MonsterBase:
		return MatchRewards.Side.MONSTER
	if killer is HeroBase or killer.is_in_group(&"Hero"):
		return MatchRewards.Side.HEROES
	return -1


## The match result's "upgrades ready": the next MenuRoot opens `side`'s
## roster (MatchRewards.Side) on entry.
func request_menu_roster(side: int) -> void:
	_menu_roster_side = MatchRewards.Side.MONSTER if side == MatchRewards.Side.MONSTER else MatchRewards.Side.HEROES


## The roster side MenuRoot should open on entry, once (-1: none); clears it.
func take_menu_roster() -> int:
	var side := _menu_roster_side
	_menu_roster_side = -1
	return side


## The F3 overlay's speed line: Engine.time_scale now, the base speed and the
## speed button's setting ("Speed x2.40  base 1.20  fast").
func debug_speed_line() -> String:
	return "Speed x%.2f  base %.2f  %s%s" % [Engine.time_scale, MATCH_BASE_SPEED,
		"fast" if match_fast else "normal", "" if speed_scaling else "  (game time: headless)"]


## The F3 overlay's threat line: the played side and its power ranks P, the
## threat, and the AI opponent's build ("AI monster: 6 nyxa + 4 base ranks";
## "AI heroes: 6/6/6/6 + 4 base ranks", one count per roster hero). P is read
## now, the threat when the match started.
func debug_threat_line() -> String:
	var heroes_played: bool = chosen_side == MatchRewards.Side.HEROES
	var power: int = MetaSkillManager.power_ranks(chosen_side, selected_monster_id)
	var ai_text: String
	if heroes_played:
		ai_text = "AI monster: %d %s + %d base ranks" % [
			MetaSkillManager.ai_build_size(MetaSkillManager.monster_tree_id(selected_monster_id), match_threat),
			selected_monster_id,
			MetaSkillManager.ai_build_size(MetaSkillManager.TREE_MONSTER_BASE, match_threat)]
	else:
		var counts: Array[String] = []
		for id in ROSTER.hero_ids():
			counts.append(str(MetaSkillManager.ai_build_size(MetaSkillManager.hero_tree_id(id), match_threat)))
		ai_text = "AI heroes: %s + %d base ranks" % ["/".join(counts),
			MetaSkillManager.ai_build_size(MetaSkillManager.TREE_HERO_BASE, match_threat)]
	return "Threat %d  played %s P %d  %s" % [match_threat, "heroes" if heroes_played else "monster", power, ai_text]
