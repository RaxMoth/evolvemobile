extends TestCase

## The PreRoundScreen (README "Pre-round screen") beyond the strategy
## (test_match_config) and the quarry (test_quarry_pick): one screen per side
## (the side's sections, top bar and start button), the hunters on the stage,
## the Monster side's picker (an owned monster becomes the player's own, a
## locked one or the rumour picks nothing), the evolution strip, the hidden
## instincts and UNLEASH, the ThreatBox's words on both sides, and the
## screen's wiring in its scenes. Tests that write the save run only in the
## isolated test user dir.

const SCENE := preload("res://Scenes/UI/Screens/PreRoundScreen.tscn")
const THREAT_BOX := preload("res://Scenes/UI/Components/ThreatBox.tscn")
const HEROES := MatchRewards.Side.HEROES
const MONSTER := MatchRewards.Side.MONSTER

var _side_before: int = HEROES


func before_each() -> void:
	_side_before = GameManager.chosen_side
	if is_isolated():
		PersistedData.wipe_progress(false)


func after_each() -> void:
	GameManager.choose_side(_side_before, false)
	if is_isolated():
		PersistedData.wipe_progress(false)


func _screen(side: int) -> PreRoundScreen:
	var screen := SCENE.instantiate() as PreRoundScreen
	add_child(screen)
	screen.open(side)
	return screen


func _def(id: StringName) -> CharacterDef:
	return GameManager.ROSTER.find(id)


## Writes tree id -> (node id -> rank) into the save.
func _own_build(build: Dictionary) -> void:
	for tree_id: StringName in build:
		var ranks: Dictionary = build[tree_id]
		for node_id: StringName in ranks:
			PersistedData.set_skill_rank(tree_id, node_id, int(ranks[node_id]))


func _visible(screen: Control, node: String) -> bool:
	return (screen.get_node(node) as CanvasItem).visible


# ------------------------------------------------------------ the sides ----

func test_each_side_shows_its_own_sections() -> void:
	if not require_isolated():
		return
	var screen := _screen(HEROES)
	var top := screen.get_node("%TopBar") as TopBar
	assert_eq(top.title, "The Hunt")
	assert_true(top.show_steel and not top.show_leaves, "Gold and Steel")
	for node: String in ["%HeroStart", "%Formations", "%Squad", "Scroll/Body/Column/Quarry", "Scroll/Body/Column/Forecast"]:
		assert_true(_visible(screen, node), "%s on the heroes side" % node)
	for node: String in ["%MonsterStart", "%Picker", "%BigMonster", "%MonsterThreat", "Scroll/Body/Column/Evolution"]:
		assert_false(_visible(screen, node), "%s only on the monster side" % node)
	assert_eq((screen.get_node("%StageFrame") as Control).theme_type_variation, &"FrameHero")
	assert_eq((screen.get_node("%StageTitle") as Label).text, "YOUR HUNTERS")
	var squad := screen.squad()
	assert_eq(squad.size(), GameManager.ROSTER.heroes.size(), "the roster's heroes on the stage")
	for i in squad.size():
		assert_eq(squad[i].character, GameManager.ROSTER.heroes[i])
	assert_true(squad[squad.size() - 1].flip, "the right pair faces the fire")
	assert_false(squad[0].flip)
	screen.open(MONSTER)
	assert_eq(top.title, "Your Beast")
	assert_true(top.show_leaves and not top.show_steel, "Gold and Leaves")
	assert_true(_visible(screen, "%MonsterStart"))
	assert_false(_visible(screen, "%HeroStart"))
	assert_false(_visible(screen, "Scroll/Body/Column/Quarry"))
	assert_eq((screen.get_node("%StageFrame") as Control).theme_type_variation, &"FrameMonster")
	assert_eq(screen.squad().size(), squad.size(), "built once")
	screen.open(5)
	assert_false(screen.is_monster(), "anything but MONSTER reads as the heroes")
	screen.queue_free()


func test_wiring_lives_in_the_scenes() -> void:
	var screen := SCENE.instantiate() as PreRoundScreen
	for path: String in ["HeroStart", "MonsterStart", "Scroll/Body/Column/Quarry/QuarryInfo/Change",
			"QuarrySheet/Slide/Sheet/Column/Random", "QuarrySheet/Slide/Sheet/Column/Head/Close"]:
		var links := (screen.get_node(path) as BaseButton).pressed.get_connections()
		assert_eq(links.size(), 1, "%s is wired" % path)
		for c: Dictionary in links:
			var flags: int = c["flags"]
			assert_true(flags & CONNECT_PERSIST != 0, "%s in PreRoundScreen.tscn" % path)
	for row: String in ["Aggression", "Farming", "Exploration"]:
		var source := screen.get_node("Scroll/Body/Column/Sliders/" + row) as StrategyRow
		assert_eq(source.value_changed.get_connections().size(), 1, "%s is wired" % row)
	for tile: String in ["Tight", "Spread", "Line"]:
		var source := screen.get_node("Scroll/Body/Column/Formations/" + tile) as ChoiceTile
		assert_eq(source.chosen.get_connections().size(), 1, "%s is wired" % tile)
	screen.free()


# ---------------------------------------------------------- the monster ----

func test_the_picker_switches_owned_monsters() -> void:
	if not require_isolated():
		return
	PersistedData.add_owned_monster(&"nyxa")
	var screen := _screen(MONSTER)
	assert_eq(screen.monster, _def(GameManager.played_monster_id()), "opens on the player's own monster")
	var cards := screen.picker_cards()
	assert_eq(cards.size(), GameManager.ROSTER.monsters.size() + 1, "every roster monster and the rumour slot")
	assert_true(cards[cards.size() - 1].rumour)
	var by_id: Dictionary[StringName, CharacterCard] = {}
	for c in cards:
		if not c.rumour:
			by_id[c.character.character_id()] = c
	assert_true(by_id[&"grount"].selected, "the own monster's card is picked")
	assert_true(by_id[&"nyxa"].unlocked, "a bought monster")
	assert_false(by_id[&"gorrak"].unlocked, "a locked one")
	by_id[&"nyxa"].pressed.emit()
	assert_eq(screen.monster, _def(&"nyxa"))
	assert_eq(GameManager.played_monster_id(), &"nyxa", "it becomes the player's own (choose_monster)")
	assert_true(by_id[&"nyxa"].selected and not by_id[&"grount"].selected)
	assert_eq((screen.get_node("%BigMonster") as StageCharacter).character, _def(&"nyxa"), "big in the lair")
	assert_eq((screen.get_node("%MonsterName") as Label).text, "Nyxa  ·  Lv.1")
	assert_eq((screen.get_node("%MonsterRole") as Label).text, _def(&"nyxa").role_text)
	by_id[&"gorrak"].pressed.emit()
	assert_eq(GameManager.played_monster_id(), &"nyxa", "a locked monster picks nothing")
	assert_eq(screen.monster, _def(&"nyxa"))
	cards[cards.size() - 1].pressed.emit()
	assert_eq(screen.monster, _def(&"nyxa"), "nor does the rumour")
	by_id[&"grount"].pressed.emit()
	assert_eq(GameManager.played_monster_id(), &"grount", "and back: the owned monsters switch freely")
	screen.queue_free()
	var again := _screen(MONSTER)
	assert_eq(again.monster, _def(&"grount"), "the next visit opens on the last pick")
	again.queue_free()


func test_evolution_strip_and_unleash() -> void:
	if not require_isolated():
		return
	PersistedData.add_owned_monster(&"nyxa")
	GameManager.choose_monster(&"nyxa")
	var screen := _screen(MONSTER)
	var nyxa := _def(&"nyxa")
	for i in 3:
		var rig := screen.get_node("%%Evo%d" % (i + 1)) as RigView
		assert_eq(rig.character, nyxa)
		assert_eq(rig.stage, i + 1)
		assert_false(rig.animated, "posed once")
	assert_eq((screen.get_node("%EvoName1") as Label).text, "Stage I\n%s" % nyxa.stage_name(1))
	assert_eq((screen.get_node("%EvoName3") as Label).text, "Stage III\n%s" % nyxa.stage_name(3))
	assert_false(_visible(screen, "%Instincts"), "instincts stay hidden until their presets are balanced")
	assert_false(_visible(screen, "%InstinctHeader"))
	assert_eq(screen.instinct, PreRoundScreen.DEFAULT_INSTINCT)
	assert_true((screen.get_node("%Ambusher") as ChoiceTile).button_pressed, "Ambusher: today's behaviour")
	var got: Array[String] = []
	screen.monster_start_requested.connect(func(id: StringName, inst: StringName) -> void: got.append("%s %s" % [id, inst]))
	(screen.get_node("%MonsterStart") as BaseButton).pressed.emit()
	assert_eq(", ".join(got), "nyxa ambusher")
	screen.queue_free()


func test_shown_instincts_pick_one() -> void:
	var screen := SCENE.instantiate() as PreRoundScreen
	screen.show_instincts = true
	add_child(screen)
	screen.open(MONSTER)
	assert_true(_visible(screen, "%Instincts"))
	var ravager := screen.get_node("%Ravager") as ChoiceTile
	ravager.button_pressed = true
	assert_eq(screen.instinct, &"ravager")
	assert_false((screen.get_node("%Ambusher") as ChoiceTile).button_pressed, "one instinct at a time")
	assert_eq(ravager.get_node("%Frame").theme_type_variation, &"CharacterCardMonster", "the crimson frame")
	screen.queue_free()


# ------------------------------------------------------------- threat ----

func test_threat_box_on_both_sides() -> void:
	if not require_isolated():
		return
	var box := THREAT_BOX.instantiate() as ThreatBox
	add_child(box)
	var grount := _def(&"grount")
	box.show_for(HEROES, grount)
	assert_eq(box.threat, 0, "a fresh save")
	assert_eq((box.get_node("%Title") as Label).text, "Threat 0")
	assert_eq((box.get_node("%Build") as Label).text, "AI build: no upgrades yet")
	assert_false((box.get_node("%Bonus") as Control).visible, "no bonus at threat 0")
	assert_eq((box.get_node("%Hint") as Label).text, grount.tip, "the quarry's counterplay tip")
	# The heroes hold the threat-4 AI build: power = 8 base + 12 per hero = 20.
	_own_build(MetaSkillManager.side_ai_build(HEROES, &"", MetaSkillManager.MAX_THREAT))
	var t := MetaSkillManager.threat_for(HEROES, &"grount")
	assert_true(t > 0, "a built squad raises the threat")
	box.show_for(HEROES, grount)
	assert_eq(box.threat, t)
	assert_eq((box.get_node("%Title") as Label).text, "Threat %d" % t)
	assert_eq((box.get_node("%Bonus") as Label).text, "+%d%% rewards" % (t * 10))
	assert_eq((box.get_node("%Build") as Label).text, "AI build: %d %s ranks + %d base ranks" % [
		MetaSkillManager.ai_build_size(&"monster_grount", t), grount.get_display_name(),
		MetaSkillManager.ai_build_size(MetaSkillManager.TREE_MONSTER_BASE, t)])
	PersistedData.wipe_progress(false)
	_own_build(MetaSkillManager.side_ai_build(MONSTER, &"grount", MetaSkillManager.MAX_THREAT))
	t = MetaSkillManager.threat_for(MONSTER, &"grount")
	box.show_for(MONSTER, grount)
	assert_eq(box.threat, t)
	assert_true(t > 0)
	var per_hero := MetaSkillManager.ai_build_size(MetaSkillManager.hero_tree_id(&"irelia"), t)
	assert_eq(box.character_ranks.size(), GameManager.ROSTER.heroes.size(), "one count per AI hero")
	var same := true
	for r in box.character_ranks:
		same = same and r == per_hero
	var expected := "AI heroes: %d ranks each + %d base ranks" % [per_hero, MetaSkillManager.ai_build_size(MetaSkillManager.TREE_HERO_BASE, t)]
	if same:
		assert_eq((box.get_node("%Build") as Label).text, expected)
	else:
		assert_true((box.get_node("%Build") as Label).text.contains("/"), "uneven builds listed per hero")
	assert_eq((box.get_node("%Hint") as Label).text, "The AI heroes grow as your monster gains ranks.")
	box.queue_free()
	var screen := _screen(MONSTER)
	assert_eq((screen.get_node("%MonsterThreat") as ThreatBox).threat, t, "the monster side's box")
	screen.open(HEROES)
	assert_eq((screen.get_node("%QuarryThreat") as ThreatBox).threat, MetaSkillManager.threat_for(HEROES, screen.quarry.character_id()),
			"the quarry's box")
	assert_eq((screen.get_node("%QuarryCard") as CharacterCard).level, (screen.get_node("%QuarryThreat") as ThreatBox).threat + 1,
			"the quarry card reads Lv.(T+1)")
	screen.queue_free()
