extends TestCase

## The in-match HUD (Scenes/UI/Hud/MatchHud.tscn under MainCam): hero cards and
## the hero focus across deaths (heroes are freed on death, so the followed
## hero's death must hand the focus and the camera to a living hero, and Tab
## must never select a dead or freed one), the card visuals (head portrait from
## the CharacterDef, slots, HP bands, fallen state), the monster side's panel
## and tracker (the head of the stage the monster reached), the intent
## mapping, and the top bar's pause / follow wiring.

const WORLD := "res://Scenes/World/World.tscn"
const EVOLUTION_ICON := "res://Assets/UI/Icons/Abilities/grount_passive_evolution.svg"
const MONSTER_PANEL := "res://Scenes/UI/Hud/MonsterHudPanel.tscn"
const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const BAT := "res://Scenes/NPCs/Mob/Mobs/Bat/Bat.tscn"
const XP_ROW := "res://Scenes/UI/Components/XpRow.tscn"


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


## hud-2 / hud-10: the panel on a real monster. Closing in on or fighting a
## hero (the chart in Approach or Fight, a HeroBase as target_entity) reads
## HUNTING under FARM and AMBUSH; chasing a Bat, or idle, the strategy names
## it. (The panel tested `target`, the hero's Body Area2D, so it never read
## HUNTING before Stage III's HUNT strategy.)
func test_the_intent_pill_hunts_while_the_monster_engages_a_hero() -> void:
	var g := (await spawn_frozen(GROUNT, Vector2.ZERO)) as MonsterBase
	var hero := await spawn_frozen(VLAD, Vector2(1500, 0))
	var bat := await spawn_frozen(BAT, Vector2(-1500, 0))
	var panel := (load(MONSTER_PANEL) as PackedScene).instantiate() as MonsterHudPanel
	add_child(panel)
	panel.bind_to_monster(g, 4)
	var label := panel.get_node(^"%Intent") as Label
	assert_eq(active_state_of(g), "Idle", "nothing in sight")
	for strategy: MonsterBase.Strategy in [MonsterBase.Strategy.FARM, MonsterBase.Strategy.AMBUSH]:
		g.strategy = strategy
		var own: String = "FARMING" if strategy == MonsterBase.Strategy.FARM else "AMBUSH"
		panel._refresh()
		assert_eq(label.text, own, "idle: the strategy")
		g.set_target(bat)
		g.state_chart.send_event(CombatEvents.ENEMY_ENTERED)
		assert_eq(active_state_of(g), "Approach")
		panel._refresh()
		assert_eq(label.text, own, "%s, chasing a Bat: the strategy" % own)
		g.set_target(hero)
		panel._refresh()
		assert_eq(panel.current_intent(), MonsterHudPanel.Intent.HUNTING, "%s, chasing a hero" % own)
		assert_eq(label.text, "HUNTING", "%s, chasing a hero: the pill" % own)
		g.state_chart.send_event(CombatEvents.ENEMY_FIGHT)
		assert_eq(active_state_of(g), "Fight")
		panel._refresh()
		assert_eq(label.text, "HUNTING", "%s, fighting a hero" % own)
		g.clear_target()
		g.state_chart.send_event(CombatEvents.TARGET_LOST)
		g.state_chart.send_event(CombatEvents.ENEMY_EXITED)
		assert_eq(active_state_of(g), "Idle", "back to idle")
	panel.queue_free()
	for n: Node in [g, hero, bat]:
		n.queue_free()
	await wait_frames(1)


## rig-7: Grount's Stage II and III portraits (horns, spikes and eyes grow)
## are the heads of the stage he reached: the monster panel's portrait when
## he evolves, the heroes' enemy tracker (MatchHud._head_of) and the result
## screen's XP row. They shipped unused: the HUD head stayed the Stage I calf.
func test_heads_follow_the_monster_stage() -> void:
	var def := GameManager.ROSTER.find(&"grount")
	assert_eq(def.stage_portraits.size(), 2, "Grount has a Stage II and a Stage III portrait")
	var g := (await spawn_frozen(GROUNT, Vector2.ZERO)) as MonsterBase
	var panel := (load(MONSTER_PANEL) as PackedScene).instantiate() as MonsterHudPanel
	add_child(panel)
	panel.bind_to_monster(g, 4)
	var head := panel.get_node(^"%Head") as TextureRect
	assert_true((head.texture as AtlasTexture).atlas == def.portrait, "Stage I: the calf")
	for stage in [2, 3]:
		evolve_to(g, stage)
		panel._refresh()
		var tex := head.texture as AtlasTexture
		assert_true(tex.atlas == def.stage_portraits[stage - 2], "Stage %d: its own portrait" % stage)
		var k := float(tex.atlas.get_width()) / CharacterDef.PORTRAIT_CANVAS.x
		assert_eq(tex.region, Rect2(def.stage_head_regions[stage - 2].position * k, def.stage_head_regions[stage - 2].size * k),
				"Stage %d: its own head crop" % stage)
		var tracked := MatchHud._head_of(&"grount", stage) as AtlasTexture
		assert_true(tracked.atlas == def.stage_portraits[stage - 2], "Stage %d: the heroes' tracker too" % stage)
	assert_true((MatchHud._head_of(&"vlad", 3) as AtlasTexture).atlas == GameManager.ROSTER.find(&"vlad").portrait,
			"a character without stage portraits keeps its own")
	var row := (load(XP_ROW) as PackedScene).instantiate() as XpRow
	row.character = def
	row.stage = 3
	add_child(row)
	assert_true(((row.get_node(^"%Head") as TextureRect).texture as AtlasTexture).atlas == def.stage_portraits[1],
			"the result screen's XP row: the stage he reached")
	for n: Node in [row, panel, g]:
		n.queue_free()
	await wait_frames(1)


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

	# A fallen hero's card greys out under the skull, and its slots go dead:
	# they used to freeze on their last countdown ("6" under the skull).
	var fallen_system := first.hero.get_node("AbilitySystem") as AbilitySystem
	for kind: AbilityBase.AbilityType in [AbilityBase.AbilityType.ACTIVE, AbilityBase.AbilityType.ULTIMATE]:
		fallen_system.cooldowns[kind] = 6.0
		fallen_system._cooldown_totals[kind] = 20.0
	await wait_frames(2)  # the slots poll in _process
	var fallen_ult := first.get_node(^"%Ult") as AbilitySlot
	assert_true((fallen_ult.get_node(^"%CooldownNumber") as Label).visible, "the ultimate was counting down")
	_kill(first.hero)
	assert_true(first.is_dead(), "card 0 knows its hero fell")
	for wait: int in [0, 3]:  # at once, and after the hero is freed
		await wait_frames(wait)
		for slot_name: String in ["Passive", "Active", "Ult", "Weapon"]:
			var slot := first.get_node("%" + slot_name) as AbilitySlot
			var where := "%s, %d frames after the fall" % [slot_name, wait]
			assert_true(slot.is_dead(), "dead slot: " + where)
			assert_false((slot.get_node(^"%CooldownNumber") as Label).visible, "no countdown: " + where)
			assert_false((slot.get_node(^"%Glow") as CanvasItem).visible, "no glow: " + where)
			var mat := (slot.get_node(^"%Icon") as TextureRect).material as ShaderMaterial
			assert_near(float(mat.get_shader_parameter(&"progress")), 1.0, 0.0001, "no sweep: " + where)
			assert_near(float(mat.get_shader_parameter(&"locked")), 1.0, 0.0001, "greyed: " + where)
	assert_false((hud.cards[2].get_node(^"%Ult") as AbilitySlot).is_dead(), "a living hero's slots stay alive")
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
	# The slot row uses the width left of the tally: 56 px for the passive,
	# 68 / 68 / 72 px for the abilities (they were 44 and 56 / 56 / 62), inside
	# the card and clear of the tally and the EVOLVE bar.
	var card := panel.get_node(^"Card") as Control
	var tally := panel.get_node(^"%Tally") as Control
	var evo := panel.get_node(^"%Evo") as Control
	var sizes: Dictionary[String, float] = {"Passive": 56.0, "A1": 68.0, "A2": 68.0, "A3": 72.0}
	var last_right := 0.0
	for slot_name: String in sizes:
		var slot := panel.get_node("%" + slot_name) as Control
		assert_eq(slot.size, Vector2.ONE * sizes[slot_name], "%s: its size" % slot_name)
		assert_true(slot.size.x >= 44.0, "%s: at least 44 px" % slot_name)
		assert_true(slot.position.x >= last_right + 8.0, "%s: clear of the slot before it" % slot_name)
		assert_true(slot.position.y >= evo.position.y + evo.size.y, "%s: under the EVOLVE bar" % slot_name)
		assert_true(slot.position.y + slot.size.y <= card.size.y, "%s: inside the card" % slot_name)
		last_right = slot.position.x + slot.size.x
	assert_true(last_right <= tally.position.x, "the row ends left of the tally")
	assert_true(last_right >= 0.6 * card.size.x, "and fills the width (it ended at 374 of 684 px)")
	panel._refresh()  # the panel polls at 10 Hz: read it and the monster in one go
	var intent := panel.get_node(^"%Intent") as Label
	var engaging: bool = active_state_of(grount) in ["Approach", "Fight"] and grount.is_target_valid() \
			and grount.target_entity is HeroBase
	var plan := MonsterHudPanel.intent_of(grount.strategy, grount.is_resting(), engaging)
	assert_eq(intent.text, MonsterHudPanel.INTENT_NAMES[plan], "the intent pill names the plan")
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


## hud-8: the first match's HUD tips never open over the pause menu. Their
## delay (HUD_TUTORIAL_DELAY) is a pausable timer: a pause menu opened right
## after the HUD binds holds them back for as long as it is up, and they open
## HUD_TUTORIAL_DELAY of running match after the resume.
func test_the_hud_tips_wait_for_the_pause_menu() -> void:
	if not require_isolated():
		return
	TutorialOverlay.forget(TutorialOverlay.CHAPTER_HUD)
	var side_before: int = GameManager.chosen_side
	GameManager.chosen_side = MatchRewards.Side.HEROES
	var world := (load(WORLD) as PackedScene).instantiate()
	add_child(world)
	var hud := (world.get_node("MainCam") as GameCamera).hud
	for i in range(60):  # the HUD binds two frames after _ready
		if hud.cards.size() == 4:
			break
		await wait_frames(1)
	hud.pause_menu().open()
	await wait_seconds(MatchHud.HUD_TUTORIAL_DELAY * 2.0)  # an always-processing timer: runs while paused
	var over_the_menu := _tips(hud)
	hud.pause_menu().resume()
	assert_eq(over_the_menu, 0, "no tips over the pause menu")
	await wait_seconds(MatchHud.HUD_TUTORIAL_DELAY * 0.5)
	assert_eq(_tips(hud), 0, "half the delay after the resume: not yet")
	await wait_seconds(MatchHud.HUD_TUTORIAL_DELAY * 0.5 + 0.1)
	assert_eq(_tips(hud), 1, "the delay of running match after the resume: the tips")
	world.queue_free()
	await wait_frames(2)
	TutorialOverlay.mark_seen(TutorialOverlay.CHAPTER_HUD)
	GameManager.chosen_side = side_before
	GameManager.match_ended_flag = true
	get_tree().paused = false
	AudioManager.stop_music()


func _tips(hud: MatchHud) -> int:
	var count := 0
	for child in hud.get_children():
		if child is TutorialOverlay and not child.is_queued_for_deletion():
			count += 1
	return count
