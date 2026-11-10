extends TestCase

## The in-match HUD (Scenes/UI/Hud/MatchHud.tscn under MainCam): hero cards and
## the hero focus across deaths (heroes are freed on death, so the followed
## hero's death must hand the focus and the camera to a living hero, and Tab
## must never select a dead or freed one), the card visuals (head portrait from
## the CharacterDef, slots, HP bands, fallen state), the monster side's panel
## and tracker, the intent mapping, and the top bar's pause / follow wiring.

const WORLD := "res://Scenes/World/World.tscn"
const EVOLUTION_ICON := "res://Assets/UI/Icons/Abilities/grount_passive_evolution.svg"


func test_intent_mapping() -> void:
	const FARM := MonsterBase.Strategy.FARM
	const AMBUSH := MonsterBase.Strategy.AMBUSH
	const HUNT := MonsterBase.Strategy.HUNT
	const RETREAT := MonsterBase.Strategy.RETREAT
	assert_eq(MonsterHudPanel.intent_of(FARM, false, false), MonsterHudPanel.Intent.FARMING)
	assert_eq(MonsterHudPanel.intent_of(AMBUSH, false, false), MonsterHudPanel.Intent.AMBUSH)
	assert_eq(MonsterHudPanel.intent_of(HUNT, false, false), MonsterHudPanel.Intent.HUNTING)
	assert_eq(MonsterHudPanel.intent_of(RETREAT, false, false), MonsterHudPanel.Intent.RETREAT)
	assert_eq(MonsterHudPanel.intent_of(FARM, true, false), MonsterHudPanel.Intent.RETREAT, "resting reads as a retreat")
	assert_eq(MonsterHudPanel.intent_of(AMBUSH, false, true), MonsterHudPanel.Intent.HUNTING, "a sprung ambush hunts")
	assert_eq(MonsterHudPanel.intent_of(FARM, false, true), MonsterHudPanel.Intent.HUNTING, "a cornered farmer hunts")
	assert_eq(MonsterHudPanel.intent_of(RETREAT, false, true), MonsterHudPanel.Intent.RETREAT, "retreat wins")


func test_clock_and_hp_band_helpers() -> void:
	assert_eq(MatchHud.clock_text(0), "00:00")
	assert_eq(MatchHud.clock_text(222), "03:42")
	assert_eq(MatchHud.clock_text(605), "10:05")
	assert_eq(HeroHudCard.hp_band(1.0), 0)
	assert_eq(HeroHudCard.hp_band(0.51), 0)
	assert_eq(HeroHudCard.hp_band(0.5), 1, "amber at half")
	assert_eq(HeroHudCard.hp_band(0.26), 1)
	assert_eq(HeroHudCard.hp_band(0.25), 2, "danger at a quarter")
	assert_eq(HeroHudCard.hp_band(0.0), 2)


func test_hero_cards_show_the_roster_and_the_real_slots() -> void:
	var side_before: int = GameManager.chosen_side
	GameManager.chosen_side = MatchRewards.Side.HEROES
	var world := (load(WORLD) as PackedScene).instantiate()
	add_child(world)
	var cam := world.get_node("MainCam") as GameCamera
	var hud := cam.hud
	assert_true(hud != null and hud == cam.get_node(^"MatchHud"), "MainCam.hud is wired to its MatchHud")
	for i in range(60):  # the HUD binds two frames after _ready
		if hud.cards.size() == 4:
			break
		await wait_frames(1)
	GameManager.match_ended_flag = true  # hero deaths must not end the match
	assert_eq(hud.cards.size(), 4, "one card per hero")
	assert_true((hud.get_node(^"%HeroCards") as CanvasItem).visible, "hero cards on the heroes side")
	assert_false((hud.get_node(^"%MonsterPanel") as CanvasItem).visible, "no monster panel")
	assert_true((hud.get_node(^"%EnemyHead") as TextureRect).texture is AtlasTexture, "the monster's head in the tracker")
	var pal := UiPalette.get_default()

	for card in hud.cards:
		var hero := card.hero as HeroBase
		var def := GameManager.ROSTER.find(MetaSkillManager.hero_id_of(hero))
		assert_true(def != null, "%s is in the roster" % hero.name)
		var head := (card.get_node(^"%Head") as TextureRect).texture as AtlasTexture
		assert_true(head != null and head.atlas == def.portrait, "%s: head from the portrait SVG" % hero.name)
		var k := float(def.portrait.get_width()) / CharacterDef.PORTRAIT_CANVAS.x
		assert_eq(head.region, Rect2(def.head_region.position * k, def.head_region.size * k), "%s: head_region" % hero.name)
		assert_eq((card.get_node(^"%Name") as Label).text, def.get_display_name())
		var ring := (card.get_node(^"%Portrait") as Panel).get_theme_stylebox(&"panel") as StyleBoxFlat
		assert_true(ring != null and ring.border_color == UiPalette.signature(String(def.character_id()), false),
			"%s: signature ring" % hero.name)
		var system := hero.get_node("AbilitySystem") as AbilitySystem
		var passive := card.get_node(^"%Passive") as AbilitySlot
		var active := card.get_node(^"%Active") as AbilitySlot
		var ult := card.get_node(^"%Ult") as AbilitySlot
		assert_eq(passive.slot_type, AbilityBase.AbilityType.PASSIVE)
		assert_eq(active.slot_type, AbilityBase.AbilityType.ACTIVE)
		assert_eq(ult.slot_type, AbilityBase.AbilityType.ULTIMATE)
		assert_true(passive.icon_texture == system.passive_ability.get_display_icon(hero), "%s: passive icon" % hero.name)
		assert_true((active.get_node(^"%Icon") as TextureRect).texture == system.active_ability.get_display_icon(hero),
			"%s: the active slot polls its ability" % hero.name)
		assert_true((ult.get_node(^"%Icon") as TextureRect).texture == system.ultimate_ability.get_display_icon(hero),
			"%s: the ultimate slot polls its ability" % hero.name)

	# The first card has the focus: lifted, amber border; the others rest.
	await wait_seconds(0.2)
	var first := hud.cards[0]
	assert_true(first.is_active() and hud.active_hero == first.hero, "card 0 has the focus at match start")
	assert_true(cam.follow_target == first.hero, "the camera starts on it")
	var first_panel := first.get_node(^"%Card") as Panel
	assert_eq(first_panel.theme_type_variation, &"HudPanelSelected")
	assert_near(first_panel.position.y, -HeroHudCard.LIFT, 0.01, "the selected card lifts")
	var second_panel := hud.cards[1].get_node(^"%Card") as Panel
	assert_eq(second_panel.theme_type_variation, &"HudPanel")
	assert_near(second_panel.position.y, 0.0, 0.01)

	# HP bands: the amber and danger fills are built once and reused.
	var card := hud.cards[1]
	var bar := card.get_node(^"%Hp") as ProgressBar
	var healthy := bar.get_theme_stylebox(&"fill")
	card._on_health_changed(30.0, 100.0)
	var hurt := bar.get_theme_stylebox(&"fill") as StyleBoxFlat
	assert_true(hurt != null and hurt.bg_color == pal.amber, "amber at 30 %")
	assert_near(bar.value, 30.0, 0.01)
	card._on_health_changed(10.0, 100.0)
	assert_true((bar.get_theme_stylebox(&"fill") as StyleBoxFlat).bg_color == pal.danger, "danger at 10 %")
	card._on_health_changed(90.0, 100.0)
	assert_true(bar.get_theme_stylebox(&"fill") == healthy, "the theme's HpBarHero fill when healthy")
	card._on_health_changed(30.0, 100.0)
	assert_true(bar.get_theme_stylebox(&"fill") == hurt, "the same amber box again")
	card._on_health_changed(100.0, 100.0)

	# Selecting a card emits hero_selected and moves the camera's target.
	var target := card.hero
	card.pressed.emit()
	assert_true(hud.active_hero == target and card.is_active() and not first.is_active(), "the pressed card takes the focus")
	assert_true(cam.follow_target == target, "MatchHud.hero_selected -> MainCam.switch_to_hero")
	assert_true(hud.hero_at(0) == first.hero and hud.hero_at(4) == null, "hero_at (the 1-4 keys)")

	# A fallen hero's card greys out under the skull.
	_kill(first.hero)
	await wait_frames(1)
	assert_true(first.is_dead(), "card 0 knows its hero fell")
	assert_eq(first.modulate, UiPalette.FALLEN_MODULATE)
	assert_true((first.get_node(^"%Down") as CanvasItem).visible, "the skull shows")
	assert_true(hud.active_hero == target, "a bystander's death leaves the focus alone")

	world.queue_free()
	await wait_frames(2)
	GameManager.chosen_side = side_before
	GameManager.match_ended_flag = true
	AudioManager.stop_music()  # World started the match music


func test_followed_hero_death_and_tab_pick_living_heroes() -> void:
	var side_before: int = GameManager.chosen_side
	GameManager.chosen_side = MatchRewards.Side.HEROES
	var world := (load(WORLD) as PackedScene).instantiate()
	add_child(world)
	var cam := world.get_node("MainCam") as GameCamera
	var ui := cam.hud
	for i in range(60):  # the HUD builds its cards two frames after _ready
		if ui.cards.size() == 4:
			break
		await wait_frames(1)
	# Hero deaths must not end the match: World's start_new_match cleared the
	# runner's guard.
	GameManager.match_ended_flag = true
	assert_eq(ui.cards.size(), 4, "one card per hero")
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
	for c in ui.cards:
		if _living_hero(c.hero) and c.hero != focus:
			bystander = c.hero
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
	for c in ui.cards:
		if _living_hero(c.hero) and c.hero != ui.active_hero:
			_kill(c.hero)
	assert_eq(emitted.size(), 9, "bystander deaths select nobody")
	var last: Node = ui.active_hero
	_kill(last)
	assert_true(ui.active_hero == null, "nobody left to follow")
	await wait_frames(1)
	ui.cycle_to_next_hero()
	assert_eq(emitted.size(), 9, "no living hero: nothing is selected")
	assert_true(ui.hero_at(0) == null, "a freed hero is no key target")

	world.queue_free()
	await wait_frames(2)
	GameManager.chosen_side = side_before
	GameManager.match_ended_flag = true
	AudioManager.stop_music()  # World started the match music


func test_top_bar_pause_and_follow() -> void:
	var side_before: int = GameManager.chosen_side
	GameManager.chosen_side = MatchRewards.Side.HEROES
	var world := (load(WORLD) as PackedScene).instantiate()
	add_child(world)
	var cam := world.get_node("MainCam") as GameCamera
	var hud := cam.hud
	await wait_frames(3)
	var pause := hud.get_node(^"%Pause") as Button
	assert_eq(pause.process_mode, Node.PROCESS_MODE_ALWAYS, "the pause button works while paused")
	assert_true(GameManager.is_match_active())
	pause.pressed.emit()
	assert_true(get_tree().paused, "Pause pauses the match")
	assert_true(pause.icon == hud.play_icon, "and shows the play icon")
	pause.pressed.emit()
	assert_false(get_tree().paused, "and resumes it")
	assert_true(pause.icon == hud.pause_icon)
	GameManager.match_ended_flag = true
	pause.pressed.emit()
	assert_false(get_tree().paused, "no pause once the match is decided")

	# Follow: MatchHud.follow_requested -> MainCam.recenter (MainCam.tscn).
	cam.debug_mode = true
	cam.global_position = Vector2(-5000, -5000)
	(hud.get_node(^"Root/Top/Follow") as Button).pressed.emit()
	assert_false(cam.debug_mode, "Follow leaves the fly-cam")
	assert_eq(cam.global_position, cam.follow_target.global_position + cam.follow_offset, "and centres on the target")

	# Top bar labels.
	await wait_seconds(0.3)
	assert_eq((hud.get_node(^"%Kills") as Label).text, str(GameManager.played_side_kills()), "the played side's kills")
	assert_eq((hud.get_node(^"%Clock") as Label).text, MatchHud.clock_text(floori(GameManager.get_match_elapsed())))

	world.queue_free()
	await wait_frames(2)
	GameManager.chosen_side = side_before
	GameManager.match_ended_flag = true
	AudioManager.stop_music()


func test_monster_side_panel_and_tracker() -> void:
	var side_before: int = GameManager.chosen_side
	GameManager.chosen_side = MatchRewards.Side.MONSTER
	var world := (load(WORLD) as PackedScene).instantiate()
	add_child(world)
	var hud := (world.get_node("MainCam") as GameCamera).hud
	var panel := hud.get_node(^"%MonsterPanel") as MonsterHudPanel
	for i in range(60):
		if panel.monster != null:
			break
		await wait_frames(1)
	GameManager.match_ended_flag = true
	var grount := (world.get_node("MonsterSlot") as MonsterSlot).monster as MonsterBase
	assert_true(panel.monster == grount, "the panel shows the match's monster")
	assert_true(panel.visible and not (hud.get_node(^"%HeroCards") as CanvasItem).visible, "monster panel, no hero cards")
	assert_true(hud.cards.is_empty(), "no hero focus on the monster side")
	assert_true((hud.get_node(^"%EnemyHeroes") as CanvasItem).visible and not (hud.get_node(^"%EnemyMonster") as CanvasItem).visible,
		"the tracker shows the heroes")
	var chips: Array[Control] = []
	for c in hud.get_node(^"%HeroRow").get_children():
		if (c as CanvasItem).visible:
			chips.append(c as Control)
	assert_eq(chips.size(), 4, "a chip per hero")
	assert_true((chips[0].get_node(^"Head") as TextureRect).texture is AtlasTexture, "with its head")

	var def := GameManager.ROSTER.find(&"grount")
	assert_eq((panel.get_node(^"%Name") as Label).text, def.get_display_name().to_upper())
	assert_true(((panel.get_node(^"%Head") as TextureRect).texture as AtlasTexture).atlas == def.portrait, "head from the portrait")
	assert_true((panel.get_node(^"%StageText") as Label).text.begins_with("STAGE I "), "Stage I")
	assert_eq((panel.get_node(^"%Pip1") as Control).theme_type_variation, &"PillReady")
	assert_eq((panel.get_node(^"%Pip2") as Control).theme_type_variation, &"Pill")
	var slam := panel.get_node(^"%A3") as AbilitySlot
	assert_true(slam.is_locked(), "Ground Slam is locked at Stage I")
	assert_eq((slam.get_node(^"%LockText") as Label).text, "II")
	var passive := panel.get_node(^"%Passive") as AbilitySlot
	assert_true(passive.visible and passive.icon_texture != null
		and passive.icon_texture.resource_path == EVOLUTION_ICON, "Grount's passive slot shows Evolution")
	panel._refresh()  # the panel polls at 10 Hz: read it and the monster in one go
	var intent := panel.get_node(^"%Intent") as Label
	assert_eq(intent.text, MonsterHudPanel.INTENT_NAMES[panel.current_intent()], "the intent pill names the plan")
	assert_eq((panel.get_node(^"%HpText") as Label).text, "%d / %d" % [roundi(grount.get_health()), roundi(grount.get_max_health())])
	assert_true((panel.get_node(^"%Evo") as CanvasItem).visible, "evolving")

	grount.gain_xp(1000.0)
	assert_eq(grount.get_stage(), 2)
	await wait_seconds(0.25)
	assert_true((panel.get_node(^"%StageText") as Label).text.begins_with("STAGE II "), "Stage II")
	assert_eq((panel.get_node(^"%Pip2") as Control).theme_type_variation, &"PillReady")
	assert_false(slam.is_locked(), "Ground Slam unlocks at Stage II")

	var victim: HeroBase = null
	for h in get_tree().get_nodes_in_group("Hero"):
		if h is HeroBase:
			victim = h as HeroBase
			break
	_kill(victim)
	assert_true((panel.get_node(^"%Tally") as Label).text.begins_with("Heroes slain  1 / 4"), "the tally counts the fall")
	await wait_seconds(0.3)
	var fallen := 0
	for chip in chips:
		if chip.modulate == UiPalette.FALLEN_MODULATE:
			fallen += 1
	assert_eq(fallen, 1, "the tracker greys the fallen hero")

	world.queue_free()
	await wait_frames(2)
	GameManager.chosen_side = side_before
	GameManager.match_ended_flag = true
	AudioManager.stop_music()


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
