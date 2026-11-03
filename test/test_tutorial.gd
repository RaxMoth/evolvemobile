extends TestCase

## TutorialOverlay: data-driven steps, scene-side button wiring, persisted flag.

const SCENE := "res://Scenes/UI/Tutorial/TutorialOverlay.tscn"


func before_each() -> void:
	if is_isolated():
		PersistedData.wipe_progress(false)


func test_walkthrough_marks_seen_and_frees_itself() -> void:
	if not require_isolated():
		return
	assert_false(TutorialOverlay.has_been_seen())
	var overlay := (load(SCENE) as PackedScene).instantiate() as TutorialOverlay
	add_child(overlay)
	var result := [null]
	overlay.finished.connect(func(completed: bool) -> void: result[0] = completed)
	assert_eq(overlay.progress_label.text, "1 / %d" % TutorialOverlay.STEPS.size())
	assert_true(overlay.back_button.disabled, "no Back on the first step")
	assert_eq(overlay.next_button.text, "Next")
	for i in TutorialOverlay.STEPS.size() - 1:
		overlay.next_button.pressed.emit()
	assert_eq(overlay.current_step(), TutorialOverlay.STEPS.size() - 1)
	assert_eq(overlay.next_button.text, "Got it")
	assert_eq(overlay.title_label.text, String(TutorialOverlay.STEPS[-1].get("title")))
	overlay.back_button.pressed.emit()
	assert_eq(overlay.current_step(), TutorialOverlay.STEPS.size() - 2)
	overlay.next_button.pressed.emit()
	overlay.next_button.pressed.emit()
	assert_eq(result[0], true, "finished(completed=true) after the last step")
	PersistedData.load_data()  # re-read from disk: mark_seen must have saved
	assert_true(TutorialOverlay.has_been_seen())
	await wait_frames(2)
	assert_false(is_instance_valid(overlay), "overlay frees itself")


func test_skip_still_marks_seen() -> void:
	if not require_isolated():
		return
	var overlay := (load(SCENE) as PackedScene).instantiate() as TutorialOverlay
	add_child(overlay)
	var result := [null]
	overlay.finished.connect(func(completed: bool) -> void: result[0] = completed)
	overlay.get_node("%SkipButton").pressed.emit()
	assert_eq(result[0], false)
	assert_true(TutorialOverlay.has_been_seen(), "skipping counts as seen — never nag again")
	assert_true(bool(PersistedData.get_setting(&"tutorial_seen", false)))
