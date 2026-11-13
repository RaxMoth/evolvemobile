extends TestCase

## The match speed (README "Match Speed"): a running match plays
## GameManager.MATCH_BASE_SPEED game seconds per real second, the HUD's Speed
## button multiplies that by MATCH_FAST_FACTOR, and everything that is not a
## running match plays at 1: the pause menu, the decided match (the death beat
## and the result screen), a scene change, the menus. A headless run keeps
## game time, which keeps the sims and the determinism trace as they were.
## The runner plays 60 frames per real second (--fixed-fps 60), so frames / 60
## is real time here and a frame's delta is Engine.time_scale / 60 game seconds.

const WORLD := "res://Scenes/World/World.tscn"
const HUD := "res://Scenes/UI/Hud/MatchHud.tscn"
const HEROES := MatchRewards.Side.HEROES

var _fast_before: bool = false
var _scaling_before: bool = false


func before_each() -> void:
	_fast_before = GameManager.match_fast
	_scaling_before = GameManager.speed_scaling
	if is_isolated():
		PersistedData.wipe_progress(false)


func after_each() -> void:
	get_tree().paused = false
	GameManager.abort_match()
	GameManager.match_ended_flag = true  # the runner's guard: deaths never end a match
	GameManager.speed_scaling = _scaling_before
	GameManager.set_match_fast(_fast_before, false)
	Engine.time_scale = 1.0
	if is_isolated():
		PersistedData.wipe_progress(false)


func _base() -> float:
	return GameManager.MATCH_BASE_SPEED


func _fast() -> float:
	return GameManager.MATCH_BASE_SPEED * GameManager.MATCH_FAST_FACTOR


func test_the_speeds_are_a_base_and_a_fast_factor() -> void:
	assert_true(_base() >= 1.0 and _base() <= 1.5, "the base speed is a little above real time (%.2f)" % _base())
	assert_true(GameManager.MATCH_FAST_FACTOR > 1.0, "fast is faster")
	GameManager.set_match_fast(false, false)
	assert_near(GameManager.match_speed(), _base(), 0.0001, "normal: the base speed")
	GameManager.set_match_fast(true, false)
	assert_near(GameManager.match_speed(), _fast(), 0.0001, "fast: base x factor")


## The sims, the trace and the tests run headless: no speed scaling, so a
## match there is the same match as before the speed existed.
func test_a_headless_run_keeps_game_time() -> void:
	if DisplayServer.get_name() != "headless":
		skip("needs the headless runner")
		return
	assert_false(GameManager.speed_scaling, "a headless run does not scale the match")
	GameManager.set_match_fast(true, false)
	GameManager.start_new_match()
	await wait_frames(3)
	assert_eq(Engine.time_scale, 1.0, "time scale 1, fast or not")
	var t0: float = GameManager.get_match_elapsed()
	await wait_frames(30)
	assert_near(GameManager.get_match_elapsed() - t0, 0.5, 0.001, "30 frames are 0.5 game seconds")
	assert_true(GameManager.debug_speed_line().begins_with("Speed x1.00  base %.2f  fast" % _base()),
		GameManager.debug_speed_line())


func test_the_scale_follows_the_running_match() -> void:
	GameManager.speed_scaling = true
	GameManager.set_match_fast(false, false)
	await wait_frames(2)
	assert_eq(Engine.time_scale, 1.0, "no match (a menu): 1")
	GameManager.start_new_match()
	assert_near(Engine.time_scale, _base(), 0.0001, "a running match plays at the base speed from its first frame")
	await wait_frames(3)
	var t0: float = GameManager.get_match_elapsed()
	await wait_frames(30)
	assert_near(GameManager.get_match_elapsed() - t0, 0.5 * _base(), 0.001, "the clock counts game seconds")
	GameManager.set_match_fast(true, false)
	assert_near(Engine.time_scale, _fast(), 0.0001, "fast at once")
	await wait_frames(1)  # the frame under way got its delta at the old scale
	t0 = GameManager.get_match_elapsed()
	await wait_frames(30)
	assert_near(GameManager.get_match_elapsed() - t0, 0.5 * _fast(), 0.001, "and the clock with it")
	assert_eq(GameManager.debug_speed_line(), "Speed x%.2f  base %.2f  fast" % [_fast(), _base()], "the F3 line")
	# A paused tree (the pause menu, the result screen) runs at 1.
	get_tree().paused = true
	await wait_frames(2)
	assert_eq(Engine.time_scale, 1.0, "paused: 1")
	get_tree().paused = false
	await wait_frames(2)
	assert_near(Engine.time_scale, _fast(), 0.0001, "resumed: the match speed again")
	# World's exit (a scene change) stops the match.
	GameManager.abort_match()
	assert_eq(Engine.time_scale, 1.0, "a match that is gone: 1 at once")
	await wait_frames(2)
	assert_eq(Engine.time_scale, 1.0, "and it stays")
	GameManager.set_match_fast(false, false)
	assert_eq(Engine.time_scale, 1.0, "the setting alone scales nothing")


## The death that decides the match puts the scale back before anybody hears
## of it, so the death beat and the result screen play at normal speed.
func test_a_decided_match_plays_at_normal_speed() -> void:
	if not require_isolated():
		return
	var saved := {
		"alive": GameManager.heroes_alive, "time": GameManager._match_time,
		"monster_alive": GameManager.monster_alive, "stage": GameManager.monster_stage_reached,
	}
	play_side(HEROES)
	# No victory jingle: the headless dummy driver never reclaims a playback.
	GameManager.match_ended.disconnect(AudioManager._on_match_ended)
	var scales: Array = []
	var on_end := func(_winner: String, _time: float) -> void: scales.append(Engine.time_scale)
	GameManager.match_ended.connect(on_end)
	GameManager.speed_scaling = true
	GameManager.set_match_fast(true, false)
	GameManager.start_new_match()
	await wait_frames(3)  # the census (no heroes, no monster here)
	assert_near(Engine.time_scale, _fast(), 0.0001, "running fast")
	var grount := MonsterBase.new()
	GameManager._on_entity_died(grount, null)
	assert_false(GameManager.is_match_active(), "the monster's death decides the match")
	assert_eq(scales, [1.0], "match_ended already hears time scale 1")
	await wait_frames(5)
	assert_eq(Engine.time_scale, 1.0, "the death beat plays at 1")
	GameManager.set_match_fast(false, false)
	assert_eq(Engine.time_scale, 1.0, "the button changes nothing in a decided match")
	# The World goes inside the beat: no result screen follows.
	GameManager.abort_match()
	await wait_seconds(GameManager.DEATH_BEAT_SEC + 0.2)
	assert_false(get_tree().paused, "the dropped beat pauses nothing")
	GameManager.match_ended.disconnect(on_end)
	GameManager.match_ended.connect(AudioManager._on_match_ended)
	grount.free()
	GameManager.heroes_alive = saved["alive"]
	GameManager._match_time = saved["time"]
	GameManager.monster_alive = saved["monster_alive"]
	GameManager.monster_stage_reached = saved["stage"]
	GameManager._fallen_hero_ids.clear()


## The top bar's Speed button, right of Pause: one arrow at the normal speed,
## two arrows on the amber button at the fast one; the choice is saved; the
## pause menu and leaving the World restore 1.
func test_the_speed_button_switches_the_match_speed() -> void:
	if not require_isolated():
		return
	GameManager.speed_scaling = true
	GameManager.set_match_fast(false, false)
	play_side(HEROES)
	var world := (load(WORLD) as PackedScene).instantiate()
	add_child(world)
	var hud := (world.get_node("MainCam") as GameCamera).hud
	await wait_frames(3)
	var speed := hud.get_node(^"%Speed") as Button
	var pause := hud.get_node(^"%Pause") as Button
	assert_true(GameManager.is_match_active())
	assert_near(Engine.time_scale, _base(), 0.0001, "the match starts at the base speed")
	assert_true(speed.icon != null and speed.icon.resource_path.ends_with("ui_fast_forward.svg"), "two arrows")
	assert_true(speed.icon != pause.icon and speed.icon != hud.play_icon, "not the pause or play icon")
	assert_eq(speed.theme_type_variation, &"ButtonRound", "on the grey button at the normal speed")
	var icon := speed.icon
	assert_true(speed.size.x >= 44.0 and speed.size.y >= 44.0, "a touch target (%s)" % str(speed.size))
	var gap := speed.position.x - (pause.position.x + pause.size.x)
	assert_true(gap >= 4.0 and gap <= 12.0 and is_equal_approx(speed.position.y, pause.position.y),
		"right of Pause (gap %.0f px)" % gap)
	for other: String in ["Root/Top/ClockChip", "%EnemyMonster", "%EnemyHeroes", "Root/Top/KillsChip", "Root/Top/Follow"]:
		var c := hud.get_node(other) as Control
		assert_false(c.get_global_rect().intersects(speed.get_global_rect()), "%s is clear of the button" % other)
	assert_true(speed.is_in_group(TutorialOverlay.TARGET_PAUSE), "the first-match tip frames it with Pause")
	assert_eq(speed.tooltip_text, "Match speed")

	speed.pressed.emit()
	assert_true(GameManager.match_fast, "a press switches to fast")
	assert_near(Engine.time_scale, _fast(), 0.0001, "the match runs at base x factor at once")
	assert_true(speed.icon == icon, "the same two arrows")
	assert_eq(speed.theme_type_variation, &"ButtonRoundPrimary", "on the amber button: lit")
	assert_eq(PersistedData.get_setting(GameManager.SETTING_MATCH_FAST, false), true, "the choice is in the save")

	# The pause menu runs at normal speed and gives the match its speed back.
	pause.pressed.emit()
	assert_true(get_tree().paused and hud.pause_menu().is_open())
	await wait_frames(2)
	assert_eq(Engine.time_scale, 1.0, "the pause menu plays at 1")
	pause.pressed.emit()
	await wait_frames(2)
	assert_false(get_tree().paused)
	assert_near(Engine.time_scale, _fast(), 0.0001, "resumed: fast again")

	speed.pressed.emit()
	assert_false(GameManager.match_fast, "a second press goes back")
	assert_near(Engine.time_scale, _base(), 0.0001)
	assert_true(speed.icon == icon and speed.theme_type_variation == &"ButtonRound")
	assert_eq(PersistedData.get_setting(GameManager.SETTING_MATCH_FAST, true), false, "saved too")

	# Leaving the World (a scene change) restores 1; the choice stays.
	speed.pressed.emit()
	world.queue_free()
	await wait_frames(2)
	assert_eq(Engine.time_scale, 1.0, "no match: 1")
	assert_true(GameManager.match_fast, "the choice is kept for the next match")
	var next := (load(HUD) as PackedScene).instantiate() as MatchHud
	add_child(next)
	assert_eq((next.get_node(^"%Speed") as Button).theme_type_variation, &"ButtonRoundPrimary", "the next match's button shows it")
	await wait_frames(3)  # the HUD binds two frames after _ready
	AudioManager.stop_music()  # World started the match music


## A toast runs on game time like the match, but it holds at least
## TOAST_MIN_REAL_HOLD real seconds: at the fast speed 2.2 game seconds
## would be under a second.
func test_a_toast_stays_readable_at_the_fast_speed() -> void:
	GameManager.speed_scaling = true
	GameManager.set_match_fast(true, false)
	GameManager.start_new_match()
	var hud := (load(HUD) as PackedScene).instantiate() as MatchHud
	add_child(hud)
	await wait_frames(3)
	assert_near(Engine.time_scale, _fast(), 0.0001)
	var toast := hud.get_node(^"%Toast") as Control
	hud.show_toast("VLAD HAS FALLEN")
	var full := 0  # frames at full alpha
	var frames := 0
	while hud.current_toast() != "" and frames < 900:
		await wait_frames(1)
		frames += 1
		if toast.visible and toast.modulate.a > 0.999:
			full += 1
	assert_eq(hud.current_toast(), "", "the toast ends")
	assert_true(full / 60.0 >= MatchHud.TOAST_MIN_REAL_HOLD - 0.02,
		"fully visible for %.2f real seconds at x%.1f" % [full / 60.0, _fast()])
	assert_true(frames / 60.0 < MatchHud.TOAST_HOLD, "and still shorter than at real time (%.2f s)" % (frames / 60.0))
	# At the base speed the 2.2 game seconds are long enough as they are.
	GameManager.set_match_fast(false, false)
	hud.show_toast("GROUNT EVOLVED · STAGE II")
	full = 0
	frames = 0
	while hud.current_toast() != "" and frames < 900:
		await wait_frames(1)
		frames += 1
		if toast.visible and toast.modulate.a > 0.999:
			full += 1
	assert_near(full / 60.0, (MatchHud.TOAST_HOLD + MatchHud.TOAST_POP - MatchHud.TOAST_FADE_IN) / _base(), 0.06,
		"the usual hold in game time at the base speed")


## Review flow-3: the real-time floor holds whenever the speed changes. A
## toast that starts at the base speed and is sped up the frame it reaches
## full alpha still stays fully visible TOAST_MIN_REAL_HOLD real seconds (it
## gave 1.00 s when the floor was fixed as game time at the start).
func test_a_toast_keeps_its_floor_when_the_speed_changes() -> void:
	GameManager.speed_scaling = true
	GameManager.set_match_fast(false, false)
	GameManager.start_new_match()
	var hud := (load(HUD) as PackedScene).instantiate() as MatchHud
	add_child(hud)
	await wait_frames(3)
	assert_near(Engine.time_scale, _base(), 0.0001)
	var toast := hud.get_node(^"%Toast") as Control
	hud.show_toast("VLAD HAS FALLEN")
	var full := 0
	var frames := 0
	while hud.current_toast() != "" and frames < 900:
		await wait_frames(1)
		frames += 1
		if toast.visible and toast.modulate.a > 0.999:
			if full == 0:
				GameManager.set_match_fast(true, false)
			full += 1
	assert_near(Engine.time_scale, _fast(), 0.0001, "sped up mid-toast")
	assert_eq(hud.current_toast(), "", "the toast ends")
	assert_true(full / 60.0 >= MatchHud.TOAST_MIN_REAL_HOLD - 0.02,
		"fully visible for %.2f real seconds after the speed-up" % (full / 60.0))
	# Paused, neither hold runs: the toast waits for the resume.
	hud.show_toast("GROUNT EVOLVED · STAGE II")
	await wait_frames(30)
	get_tree().paused = true
	await wait_frames(150)
	assert_eq(hud.current_toast(), "GROUNT EVOLVED · STAGE II", "a pause holds the toast")
	get_tree().paused = false
	hud.queue_free()
	await wait_frames(1)


func test_the_speed_strings_are_translated() -> void:
	var before := TranslationServer.get_locale()
	TranslationServer.set_locale("de")
	assert_eq(TranslationServer.translate("Match speed"), "Spieltempo")
	for step in TutorialOverlay.HUD_STEPS:
		for key: String in ["title", "body"]:
			var text := String(step[key])
			assert_true(TranslationServer.translate(text) != text, "German for \"%s\"" % text.left(30))
	TranslationServer.set_locale(before)


# ---------- step size (fix batch G2, README "Watched match against the sims") ----------

const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"
## The sims' step and a phone's on fast at 30 fps (2.4 / 30 game seconds).
const STEPS: Array[float] = [1.0 / 60.0, 0.08]


## Mean game seconds between the casts of `cast` over `seconds`, stepping
## `tick` (a cooldown update, then a cast as soon as one is ready) by `step`.
func _mean_interval(step: float, seconds: float, tick: Callable, cast: Callable) -> float:
	var times: Array[float] = []
	var t := 0.0
	while t < seconds:
		tick.call(step)
		t += step
		if cast.call():
			times.append(t)
	if times.size() < 2:
		return INF
	return (times[times.size() - 1] - times[0]) / float(times.size() - 1)


## A cooldown that ended inside a frame left its overshoot unused, so a swing
## came on the first frame after it: 1.04 s instead of 1.0 for Vlad at 0.08 s
## a step (about 4 % fewer hits), 2.56 s instead of 2.5 for Grount's cleave.
## The overshoot (at most one frame) now counts toward the next cooldown.
func test_attacks_keep_their_pace_at_any_step() -> void:
	var vlad := await spawn_frozen(VLAD, Vector2(0, 0))
	var asys: AbilitySystem = (vlad as HeroBase).ability_system
	asys.set_process(false)  # stepped by hand below
	var basic := AbilityBase.AbilityType.BASIC_ATTACK
	var g := await spawn_frozen(GROUNT, Vector2(2000, 0))  # far: the cleave hits nobody
	g.set_process(false)
	for step: float in STEPS:
		asys.cooldowns[basic] = 0.0
		var hero := _mean_interval(step, 60.0, func(dt: float) -> void: asys._process(dt),
				func() -> bool: return not asys.is_on_cooldown(basic) and asys.use_basic_attack(null))
		assert_near(hero, asys.basic_attack.cooldown, 0.01, "Vlad swings every %.2f s at a %.3f s step" % [asys.basic_attack.cooldown, step])
		g.ability_cooldowns["ability_1"] = 0.0
		var cleave := _mean_interval(step, 120.0, func(dt: float) -> void: g._process(dt),
				func() -> bool: return g.is_ability_ready("ability_1") and g._cast("ability_1", g.ability_1, vlad))
		assert_near(cleave, g.ability_1.cooldown, 0.02, "Grount cleaves every %.2f s at a %.3f s step" % [g.ability_1.cooldown, step])
	for n in [vlad, g]:
		n.queue_free()


const HOG := "res://Scenes/NPCs/Mob/Mobs/Hog/Hog.tscn"


## A mob swung on its next AI tick after its AttackTimer ran out, so off screen
## (20 Hz, as in every sim) each swing came up to 0.05 s late, and the frame's
## overshoot was lost. The next swing now starts from the repeating timer,
## with that overshoot, while the mob can keep swinging; once it cannot (its
## target gone), the timer stops and nothing swings on its own. The swing
## here lasts 60.5 frames: the old swings took at least 61 frames each.
func test_a_mob_swings_at_its_pace_whatever_its_tick_rate() -> void:
	var vlad := await spawn_frozen(VLAD, Vector2(0, 0))
	var hog := (await spawn_entity(HOG, Vector2(30, 0))) as MobBase  # inside its 20-40 px band
	var swing: float = hog.attack_cooldown + 0.5 / 60.0
	hog.attack_timer.wait_time = swing
	var frames: Array[int] = []
	var on_hit := func(p: DamagePacket) -> void:
		if p.source == hog:
			frames.append(Engine.get_process_frames())
	EventBus.damage_applied.connect(on_hit)
	for i in 600:
		await get_tree().process_frame
		if frames.size() >= 6:
			break
	EventBus.damage_applied.disconnect(on_hit)
	assert_eq(frames.size(), 6, "six swings landed")
	assert_eq(TickScheduler.lod_name(TickScheduler.lod_of(hog)), "NEAR", "the Hog's AI ticks at 20 Hz")
	if frames.size() == 6:
		# The runner steps 1/60 s a frame.
		var mean: float = float(frames[5] - frames[0]) / 5.0 / 60.0
		assert_near(mean, swing, 1.0 / 60.0 / 5.0, "a swing every %.4f s (%.4f s)" % [swing, mean])
	vlad.queue_free()
	await wait_seconds(swing + 0.1)
	assert_true(hog.attack_timer.is_stopped() and not hog.attacking, "its target gone: the timer stopped")
	hog.queue_free()
	await wait_frames(2)
