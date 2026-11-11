extends TestCase

## TutorialOverlay: the two chapters (the camp tour, the first hunt's HUD
## tips) as data, the scene-side button wiring, each chapter's persisted flag,
## and the coach marks: a step frames the visible Controls of its anchor
## group (the scrim's hole, the ring, the arrow, the bubble on the side with
## room), follows them when they move and centres the bubble when the target
## is missing. The anchor groups live in the target scenes.

const SCENE := "res://Scenes/UI/Tutorial/TutorialOverlay.tscn"
const LOBBY := "res://Scenes/UI/Screens/LobbyScreen.tscn"
const NAV_BAR := "res://Scenes/UI/Components/NavBar.tscn"
const HERO_CARD := "res://Scenes/UI/Hud/HeroHudCard.tscn"
const MONSTER_PANEL := "res://Scenes/UI/Hud/MonsterHudPanel.tscn"
const MATCH_HUD := "res://Scenes/UI/Hud/MatchHud.tscn"


func before_each() -> void:
	if is_isolated():
		PersistedData.wipe_progress(false)


func _overlay(chapter: StringName = TutorialOverlay.CHAPTER_LOBBY) -> TutorialOverlay:
	var overlay := (load(SCENE) as PackedScene).instantiate() as TutorialOverlay
	overlay.chapter = chapter
	add_child(overlay)
	return overlay


func test_walkthrough_marks_seen_and_frees_itself() -> void:
	if not require_isolated():
		return
	assert_false(TutorialOverlay.has_been_seen())
	var overlay := _overlay()
	var steps := TutorialOverlay.LOBBY_STEPS
	var result := [null]
	overlay.finished.connect(func(completed: bool) -> void: result[0] = completed)
	assert_eq(overlay.progress_label.text, "1 / %d" % steps.size())
	assert_true(overlay.back_button.disabled, "no Back on the first step")
	assert_eq(overlay.next_button.text, "Next")
	for i in steps.size() - 1:
		overlay.next_button.pressed.emit()
	assert_eq(overlay.current_step(), steps.size() - 1)
	assert_eq(overlay.next_button.text, "Got it")
	assert_eq(overlay.title_label.text, String(steps[-1].get("title")))
	overlay.back_button.pressed.emit()
	assert_eq(overlay.current_step(), steps.size() - 2)
	overlay.next_button.pressed.emit()
	overlay.next_button.pressed.emit()
	assert_eq(result[0], true, "finished(completed=true) after the last step")
	PersistedData.load_data()  # re-read from disk: mark_seen must have saved
	assert_true(TutorialOverlay.has_been_seen())
	assert_false(TutorialOverlay.has_been_seen(TutorialOverlay.CHAPTER_HUD), "each chapter has its own flag")
	await wait_frames(2)
	assert_false(is_instance_valid(overlay), "overlay frees itself")


func test_skip_still_marks_seen() -> void:
	if not require_isolated():
		return
	var overlay := _overlay()
	var result := [null]
	overlay.finished.connect(func(completed: bool) -> void: result[0] = completed)
	overlay.get_node("%SkipButton").pressed.emit()
	assert_eq(result[0], false)
	assert_true(TutorialOverlay.has_been_seen(), "skipping counts as seen — never nag again")
	assert_true(bool(PersistedData.get_setting(&"tutorial_seen", false)))


func test_hud_chapter_has_its_own_steps_and_flag() -> void:
	if not require_isolated():
		return
	var overlay := _overlay(TutorialOverlay.CHAPTER_HUD)
	assert_eq(overlay.steps(), TutorialOverlay.HUD_STEPS)
	assert_eq((overlay.get_node("%Kicker") as Label).text, "FIRST HUNT")
	assert_eq((overlay.get_node("%Pips") as Node).get_child_count(), TutorialOverlay.HUD_STEPS.size(), "a pip per step")
	assert_eq(overlay.current_anchor(), TutorialOverlay.TARGET_HUD_SLOTS, "it starts on the cooldown slots")
	overlay.get_node("%SkipButton").pressed.emit()
	assert_true(TutorialOverlay.has_been_seen(TutorialOverlay.CHAPTER_HUD))
	assert_false(TutorialOverlay.has_been_seen(), "the camp tour is still unseen")
	TutorialOverlay.forget(TutorialOverlay.CHAPTER_HUD)
	assert_false(TutorialOverlay.has_been_seen(TutorialOverlay.CHAPTER_HUD), "the Codex can switch the tips on again")


## The camp tour points at the lobby's stages, the HUNT arch and the Codex tab;
## the hunt tips at the cooldown slots and the pause and speed buttons.
func test_the_steps_point_at_the_lobby_and_the_hud() -> void:
	var anchors: Array[StringName] = []
	for step in TutorialOverlay.LOBBY_STEPS + TutorialOverlay.HUD_STEPS:
		anchors.append(step.get("anchor", &""))
	for target: StringName in [TutorialOverlay.TARGET_HERO_STAGE, TutorialOverlay.TARGET_MONSTER_STAGE, TutorialOverlay.TARGET_HUNT, TutorialOverlay.TARGET_CODEX, TutorialOverlay.TARGET_HUD_SLOTS, TutorialOverlay.TARGET_PAUSE]:
		assert_true(anchors.has(target), "a step points at %s" % target)
	# The groups are set in the target scenes.
	var lobby := (load(LOBBY) as PackedScene).instantiate()
	assert_true(lobby.get_node("%HeroStage").is_in_group(TutorialOverlay.TARGET_HERO_STAGE))
	assert_true(lobby.get_node("%MonsterStage").is_in_group(TutorialOverlay.TARGET_MONSTER_STAGE))
	lobby.free()
	var nav := (load(NAV_BAR) as PackedScene).instantiate() as NavBar
	assert_true(nav.get_node("%Arch").is_in_group(TutorialOverlay.TARGET_HUNT))
	assert_true(nav.tab(&"codex").is_in_group(TutorialOverlay.TARGET_CODEX))
	nav.free()
	for path: String in [HERO_CARD, MONSTER_PANEL]:
		var card := (load(path) as PackedScene).instantiate()
		var slots := 0
		for slot in card.find_children("*", "", true, false):
			if slot.is_in_group(TutorialOverlay.TARGET_HUD_SLOTS):
				assert_true(slot is AbilitySlot, "%s: only ability slots" % path)
				slots += 1
		assert_true(slots >= 3, "%s: its cooldown slots are anchors" % path)
		card.free()
	var hud := (load(MATCH_HUD) as PackedScene).instantiate()
	assert_true(hud.get_node("%Pause").is_in_group(TutorialOverlay.TARGET_PAUSE))
	assert_true(hud.get_node("%Speed").is_in_group(TutorialOverlay.TARGET_PAUSE), "the same tip frames the speed button")
	hud.free()


func test_a_step_frames_its_target() -> void:
	if not require_isolated():
		return
	var target := Control.new()
	target.position = Vector2(200, 900)
	target.size = Vector2(120, 80)
	add_child(target)
	target.add_to_group(TutorialOverlay.TARGET_HUNT)
	var overlay := _overlay()
	overlay._show_step(3)
	assert_eq(overlay.current_anchor(), TutorialOverlay.TARGET_HUNT)
	assert_true(overlay.is_framed(), "a visible target is framed")
	await wait_seconds(TutorialOverlay.MOVE_TIME + 0.1)
	var hole := overlay.hole()
	assert_true(hole.encloses(Rect2(target.position, target.size)), "the hole lets the target through")
	var ring := overlay.get_node("%Ring") as Control
	assert_true(ring.visible)
	assert_eq(Rect2(ring.position, ring.size), hole, "the ring frames the hole")
	var bubble := overlay.get_node("%Bubble") as Control
	assert_true(bubble.get_global_rect().end.y <= hole.position.y, "a low target gets the bubble above it")
	assert_true((overlay.get_node("%Arrow") as Control).visible, "and the arrow")
	# It follows a moving target (a screen sliding in).
	target.position.y = 150
	await wait_frames(2)
	assert_true(overlay.hole().encloses(Rect2(target.position, target.size)), "the frame follows its target")
	assert_true(bubble.get_global_rect().position.y >= overlay.hole().end.y, "a high target gets the bubble below it")
	# A hidden target: no frame, the bubble centred.
	target.visible = false
	await wait_frames(2)
	assert_false(overlay.is_framed())
	assert_false(ring.visible)
	overlay.queue_free()
	target.queue_free()


func test_a_step_without_a_target_centres_the_bubble() -> void:
	if not require_isolated():
		return
	var overlay := _overlay()
	assert_eq(overlay.current_anchor(), &"", "the first step is the rules")
	assert_false(overlay.is_framed())
	await wait_frames(2)
	var bubble := overlay.get_node("%Bubble") as Control
	var view := (overlay.get_node("%Dim") as Control).size
	assert_near(bubble.get_global_rect().get_center().y, view.y * 0.5, 2.0, "centred")
	overlay.queue_free()


## Theme variations only: no overrides of colours, fonts or styles in the scene.
func test_the_overlay_uses_theme_variations_only() -> void:
	var overlay := (load(SCENE) as PackedScene).instantiate()
	for node in overlay.find_children("*", "Control", true, true):
		var c := node as Control
		for prop in c.get_property_list():
			var prop_name: String = prop["name"]
			if prop_name.begins_with("theme_override_colors") or prop_name.begins_with("theme_override_fonts") \
					or prop_name.begins_with("theme_override_styles") or prop_name.begins_with("theme_override_font_sizes"):
				assert_true(c.get(prop_name) == null, "%s overrides %s" % [c.name, prop_name])
	overlay.free()
