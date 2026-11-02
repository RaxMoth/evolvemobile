extends TestCase

## GameManager's match clock: game time only, never in menus, stops on abort;
## the monster's stage is recorded as it evolves (not only on its death).


func after_each() -> void:
	get_tree().paused = false
	GameManager.abort_match()
	GameManager.match_ended_flag = true  # the runner's guard: deaths never end a match


func test_clock_runs_only_in_an_active_match_on_unpaused_time() -> void:
	GameManager.abort_match()
	assert_false(GameManager.is_match_active(), "no match outside a World (was: started in the main menu)")
	GameManager.start_new_match()
	assert_true(GameManager.is_match_active())
	await wait_seconds(0.3)
	var t1: float = GameManager.get_match_elapsed()
	assert_true(t1 > 0.15 and t1 < 0.8, "game time advanced (%.3f)" % t1)
	get_tree().paused = true
	await wait_frames(20)
	assert_near(GameManager.get_match_elapsed(), t1, 0.03, "paused time does not count")
	get_tree().paused = false
	GameManager.abort_match()
	var t2: float = GameManager.get_match_elapsed()
	await wait_frames(10)
	assert_eq(GameManager.get_match_elapsed(), t2, "an aborted clock stops")
	assert_false(GameManager.is_match_active())


func test_monster_stage_is_tracked_on_evolution() -> void:
	GameManager.start_new_match()
	assert_eq(GameManager.monster_stage_reached, 1)
	EventBus.notify_monster_evolved(null, 2)
	EventBus.notify_monster_evolved(null, 3)
	assert_eq(GameManager.monster_stage_reached, 3, "a monster that wins at stage 3 is paid as stage 3")
