extends TestCase

## The display's safe area (review components-3, README "Safe area"): SafeArea
## maps DisplayServer.get_display_safe_area() into the viewport, MenuRoot and
## the MatchHud's Root fit themselves inside it. No device or simulator is
## at hand, so the display is faked: the pure mapping gets a phone's numbers,
## and SafeArea.simulated feeds the screens an inset.

const MENU_ROOT := preload("res://Scenes/UI/Screens/MenuRoot.tscn")
const HUD := preload("res://Scenes/UI/Hud/MatchHud.tscn")
## A 1179x2556 px phone with its camera island and home indicator: the safe
## area starts 177 px down and ends 102 px above the bottom edge.
const PHONE := Vector2i(1179, 2556)
const PHONE_SAFE := Rect2i(0, 177, 1179, 2556 - 177 - 102)
## The insets the screens get here (viewport px).
const FAKE := Vector2(100.0, 60.0)

var _world_before: PackedScene = null


func before_each() -> void:
	SafeArea.simulated = Vector2(-1.0, -1.0)
	# MenuRoot starts the background World load unless the session holds the
	# scene: a stand-in keeps this suite from loading the whole match.
	_world_before = GameManager.world_scene
	if GameManager.world_scene == null:
		GameManager.world_scene = PackedScene.new()
	if is_isolated():
		TutorialOverlay.mark_seen()


func after_each() -> void:
	SafeArea.simulated = Vector2(-1.0, -1.0)
	GameManager.world_scene = _world_before


func test_the_display_safe_area_maps_into_the_viewport() -> void:
	# The 720 px wide viewport of that phone is 720 * 2556 / 1179 tall.
	var view := Vector2(720.0, 720.0 * PHONE.y / PHONE.x)
	var inset := SafeArea.from_display(PHONE_SAFE, Rect2i(Vector2i.ZERO, PHONE), view)
	var k := view.y / PHONE.y
	assert_near(inset.x, 177.0 * k, 0.01, "the top inset in viewport px (%.1f)" % inset.x)
	assert_near(inset.y, 102.0 * k, 0.01, "the bottom inset in viewport px (%.1f)" % inset.y)
	assert_eq(SafeArea.from_display(Rect2i(Vector2i.ZERO, PHONE), Rect2i(Vector2i.ZERO, PHONE), view), Vector2.ZERO,
			"a display without cut-outs: no inset")
	assert_eq(SafeArea.from_display(PHONE_SAFE, Rect2i(), view), Vector2.ZERO, "no window: no inset")
	assert_eq(SafeArea.from_display(Rect2i(0, -20, 1179, 2600), Rect2i(Vector2i.ZERO, PHONE), view), Vector2.ZERO,
			"a safe rect beyond the window is no inset")


func test_off_a_phone_there_is_no_inset() -> void:
	if OS.has_feature("mobile"):
		skip("runs on desktop or headless")
		return
	assert_eq(SafeArea.insets(get_viewport()), Vector2.ZERO, "desktop: the screen's safe area says nothing about the window")
	SafeArea.simulated = FAKE
	assert_eq(SafeArea.insets(get_viewport()), FAKE, "a simulated inset wins")


func test_the_menus_fit_inside_the_safe_area() -> void:
	var height := get_viewport().get_visible_rect().size.y
	SafeArea.simulated = FAKE
	var root := MENU_ROOT.instantiate() as MenuRoot
	add_child(root)
	await wait_frames(2)
	assert_near(root.get_global_rect().position.y, FAKE.x, 0.5, "the menu starts under the top inset")
	assert_near(root.get_global_rect().end.y, height - FAKE.y, 0.5, "and ends above the bottom inset")
	var lobby := root.lobby
	var top_bar := lobby.get_node("%TopBar") as Control
	var nav := lobby.get_node("%NavBar") as Control
	assert_true(top_bar.get_global_rect().position.y >= FAKE.x - 0.5, "the top bar is clear of the notch (%.0f)" % top_bar.get_global_rect().position.y)
	assert_true(nav.get_global_rect().end.y <= height - FAKE.y + 0.5, "the nav bar is clear of the home indicator (%.0f)" % nav.get_global_rect().end.y)
	root.queue_free()
	await wait_frames(1)
	SafeArea.simulated = Vector2(-1.0, -1.0)
	var plain := MENU_ROOT.instantiate() as MenuRoot
	add_child(plain)
	await wait_frames(2)
	assert_eq(plain.get_global_rect(), Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size), "no inset: edge to edge as before")
	plain.queue_free()
	await wait_frames(1)
	AudioManager.stop_music()


func test_the_match_hud_fits_inside_the_safe_area() -> void:
	var height := get_viewport().get_visible_rect().size.y
	SafeArea.simulated = FAKE
	var hud := HUD.instantiate() as MatchHud
	add_child(hud)
	await wait_frames(3)
	var pause := hud.get_node(^"%Pause") as Control
	var cards := hud.get_node(^"%HeroCards") as Control
	var panel := hud.get_node(^"%MonsterPanel") as Control
	assert_true(pause.get_global_rect().position.y >= FAKE.x, "the top bar's buttons are clear of the notch (%.0f)" % pause.get_global_rect().position.y)
	assert_true(cards.get_global_rect().end.y <= height - FAKE.y + 0.5, "the hero cards are clear of the home indicator (%.0f)" % cards.get_global_rect().end.y)
	assert_true(panel.get_global_rect().end.y <= height - FAKE.y + 0.5, "so is the monster panel")
	SafeArea.simulated = Vector2(-1.0, -1.0)
	hud._fit_safe_area()
	await wait_frames(1)
	assert_true(pause.get_global_rect().position.y < FAKE.x, "a new inset applies (a resize asks again)")
	hud.queue_free()
	await wait_frames(1)
