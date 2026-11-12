extends TestCase

## AudioManager: placeholder streams for every key, rate limiting, earshot
## culling, music switching.

var _cam: Camera2D = null


func after_each() -> void:
	# The other tests play at the origin and rely on there being no camera.
	if _cam != null:
		_cam.free()
		_cam = null


func test_every_key_has_a_stream() -> void:
	for key in AudioManager.SFX_KEYS:
		assert_true(AudioManager.has_sfx(key), "sfx %s" % key)
	# No real assets are shipped yet, so everything is a generated placeholder.
	assert_true(AudioManager.is_placeholder(&"hit"))
	assert_true(AudioManager.is_placeholder(&"menu"))


func test_same_key_is_rate_limited() -> void:
	# The rate limit runs on the wall clock (Time.get_ticks_msec) while the suite
	# runs at a fixed fps, so wait in real time. The first wait clears a "cast"
	# played by an earlier test. The refusal is checked only when the clock says
	# both plays fell inside the window: a stall of the machine between them
	# (swap, load) lets the second through for the right reason, so that
	# attempt is tried again.
	var inside_the_window := false
	for attempt in 5:
		OS.delay_msec(60)
		var start := Time.get_ticks_msec()
		assert_true(AudioManager.play_sfx(&"cast", Vector2.ZERO), "first play goes through (attempt %d)" % attempt)
		var second := AudioManager.play_sfx(&"cast", Vector2.ZERO)
		if Time.get_ticks_msec() - start < AudioManager.MIN_RETRIGGER_MSEC:
			assert_false(second, "retrigger inside 50 ms is dropped")
			inside_the_window = true
			break
	assert_true(inside_the_window, "the two plays fell inside the window in one of 5 attempts")
	assert_true(AudioManager.play_sfx(&"ult", Vector2.ZERO), "a different key is independent")
	OS.delay_msec(60)
	assert_true(AudioManager.play_sfx(&"cast", Vector2.ZERO), "allowed again after the window")


func test_out_of_earshot_is_culled_before_the_rate_limit() -> void:
	_cam = Camera2D.new()
	add_child(_cam)
	_cam.make_current()
	assert_true(get_viewport().get_camera_2d() == _cam, "the test camera is current")
	# Clear a "hit" an earlier test may have played (see the rate-limit test).
	OS.delay_msec(60)
	assert_false(AudioManager.play_sfx(&"hit", Vector2(5000, 0)), "beyond SFX_MAX_DISTANCE is culled")
	assert_true(AudioManager.play_sfx(&"hit", Vector2.ZERO),
		"a culled hit does not claim the slot of the audible hit right after it")


func test_music_switches_and_stops() -> void:
	AudioManager.play_music(&"menu")
	assert_eq(AudioManager.current_music(), &"menu")
	AudioManager.play_music(&"match")
	assert_eq(AudioManager.current_music(), &"match")
	AudioManager.stop_music()
	assert_eq(AudioManager.current_music(), &"")
	AudioManager.play_music(&"nope")
	assert_eq(AudioManager.current_music(), &"", "unknown keys are ignored")
