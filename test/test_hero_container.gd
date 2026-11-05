extends TestCase

## The hero roster (HeroContainer) and the camera across hero deaths. Heroes
## are freed on death, so the followed hero's death must hand the focus (and
## the camera) to a living hero, and Tab must never select a dead or freed one.

const WORLD := "res://Scenes/World/World.tscn"


func test_followed_hero_death_and_tab_pick_living_heroes() -> void:
	var side_before: int = GameManager.chosen_side
	GameManager.chosen_side = MatchRewards.Side.HEROES
	var world := (load(WORLD) as PackedScene).instantiate()
	add_child(world)
	var cam := world.get_node("MainCam") as GameCamera
	var ui := cam.hero_ui
	for i in range(60):  # the roster builds its panels two frames after _ready
		if ui.panels.size() == 4:
			break
		await wait_frames(1)
	# Hero deaths must not end the match: World's start_new_match cleared the
	# runner's guard.
	GameManager.match_ended_flag = true
	assert_eq(ui.panels.size(), 4, "one panel per hero")
	var emitted: Array[Node] = []
	ui.hero_selected.connect(func(h: Node) -> void: emitted.append(h))

	var first: Node = ui.active_hero
	assert_true(_living_hero(first), "a living hero has the focus at match start")
	assert_true(cam.follow_target == first, "the camera starts on it")

	# The followed hero dies: the focus and the camera move to a living hero.
	_kill(first)
	await wait_frames(1)
	assert_false(is_instance_valid(first), "the dead hero was freed")
	var focus: Node = ui.active_hero
	assert_true(_living_hero(focus), "the focus moved to a living hero")
	assert_true(cam.follow_target == focus, "the camera follows the new focus")
	assert_eq(emitted.size(), 1, "one hero_selected for the hand-over")

	# Another hero dies: the focus stays. In its death frame the dead hero is
	# still a valid instance, and Tab must skip it all the same.
	var bystander: Node = null
	for p in ui.panels:
		if _living_hero(p.hero) and p.hero != focus:
			bystander = p.hero
			break
	_kill(bystander)
	assert_true(ui.active_hero == focus, "a bystander's death leaves the focus alone")
	assert_eq(emitted.size(), 1, "and selects nobody")
	assert_true(is_instance_valid(bystander), "still in its death frame")
	for i in range(4):
		ui.cycle_to_next_hero()
	await wait_frames(1)
	for i in range(4):
		ui.cycle_to_next_hero()
	assert_eq(emitted.size(), 9, "every Tab selected a hero")
	var tabbed: Dictionary = {}
	for h in emitted.slice(1):
		assert_true(_living_hero(h), "Tab selected a living hero")
		tabbed[h] = true
	assert_eq(tabbed.size(), 2, "Tab cycles the two living heroes")
	assert_true(cam.follow_target == ui.active_hero, "the camera follows the Tab focus")

	# Everyone dies: the last hand-over finds nobody, and Tab does nothing.
	for p in ui.panels:
		if _living_hero(p.hero) and p.hero != ui.active_hero:
			_kill(p.hero)
	assert_eq(emitted.size(), 9, "bystander deaths select nobody")
	var last: Node = ui.active_hero
	_kill(last)
	await wait_frames(1)
	ui.cycle_to_next_hero()
	assert_eq(emitted.size(), 9, "no living hero: nothing is selected")

	world.queue_free()
	await wait_frames(2)
	GameManager.chosen_side = side_before
	GameManager.match_ended_flag = true
	AudioManager.stop_music()  # World started the match music


## Untyped: a freed hero cannot be passed as a Node argument.
func _living_hero(n: Variant) -> bool:
	return is_instance_valid(n) and n is HeroBase and (n as HeroBase).is_alive()


func _kill(hero: Node) -> void:
	var h := hero as HeroBase
	for i in range(5):  # a Divine Shield may absorb the first hit
		if not h.is_alive():
			break
		EventBus.deal_damage(null, h, 1.0e7)
	assert_false(h.is_alive(), "%s is dead" % h.name)
