extends TestCase

## AudioManager: placeholder streams for every key, rate limiting, music switching.

func test_every_key_has_a_stream() -> void:
	for key in AudioManager.SFX_KEYS:
		assert_true(AudioManager.has_sfx(key), "sfx %s" % key)
	# No real assets are shipped yet, so everything is a generated placeholder.
	assert_true(AudioManager.is_placeholder(&"hit"))
	assert_true(AudioManager.is_placeholder(&"menu"))


func test_same_key_is_rate_limited() -> void:
	# The rate limit runs on the wall clock (Time.get_ticks_msec) while the suite
	# runs at a fixed fps, so wait in real time. The first wait clears a "cast"
	# played by an earlier test.
	OS.delay_msec(60)
	assert_true(AudioManager.play_sfx(&"cast", Vector2.ZERO), "first play goes through")
	assert_false(AudioManager.play_sfx(&"cast", Vector2.ZERO), "retrigger inside 50 ms is dropped")
	assert_true(AudioManager.play_sfx(&"ult", Vector2.ZERO), "a different key is independent")
	OS.delay_msec(60)
	assert_true(AudioManager.play_sfx(&"cast", Vector2.ZERO), "allowed again after the window")


func test_music_switches_and_stops() -> void:
	AudioManager.play_music(&"menu")
	assert_eq(AudioManager.current_music(), &"menu")
	AudioManager.play_music(&"match")
	assert_eq(AudioManager.current_music(), &"match")
	AudioManager.stop_music()
	assert_eq(AudioManager.current_music(), &"")
	AudioManager.play_music(&"nope")
	assert_eq(AudioManager.current_music(), &"", "unknown keys are ignored")
