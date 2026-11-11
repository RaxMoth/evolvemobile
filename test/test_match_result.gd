extends TestCase

## The match result (README "Match result screen"): GameManager shows the new
## MatchResultScreen, which returns to MenuRoot; populate() for each side and
## outcome (ribbon, line, stage, stats, rewards, XP rows, the cast's poses); the
## Opponent Threat's bonus; the XP bars and LEVEL UP!; "upgrades ready" and its
## request to the menu (test_menu_root opens that roster); the buttons and their
## scene-side wiring. Then
## GameManager's side of it: each side's mob kills (killer_side), the played
## side's kills paying the rewards, and the fallen heroes the Result carries.
## Tests that write the save run only in the isolated test user dir.

const SCENE := preload("res://Scenes/UI/Screens/MatchResultScreen.tscn")
const HEROES := MatchRewards.Side.HEROES
const MONSTER := MatchRewards.Side.MONSTER
const WIN := MatchRewards.Outcome.WIN
const LOSS := MatchRewards.Outcome.LOSS
const TIMEOUT := MatchRewards.Outcome.TIMEOUT
const SQUAD: Array[StringName] = [&"irelia", &"vlad", &"ted", &"river"]
## Long enough for the whole intro (it settles by about 1.9 s).
const INTRO_DONE := 2.3

var _side_before: int = HEROES


func before_each() -> void:
	_side_before = GameManager.chosen_side
	if is_isolated():
		PersistedData.wipe_progress(false)


func after_each() -> void:
	GameManager.choose_side(_side_before, false)
	GameManager.take_menu_roster()
	get_tree().paused = false
	if is_isolated():
		PersistedData.wipe_progress(false)


## A result as GameManager builds it: the formula's numbers plus the cast.
func _result(side: int, outcome: int, kills: int = 23, fallen: Array[StringName] = [], threat: int = 0) -> MatchRewards.Result:
	var alive := SQUAD.size() - fallen.size() if outcome != LOSS else 0
	var r := MatchRewards.compute(side, outcome, 754.0, kills, alive, 3, threat)
	r.hero_ids.assign(SQUAD)
	r.fallen_hero_ids.assign(SQUAD if outcome == LOSS and side == HEROES else fallen)
	r.monster_id = &"nyxa"
	return r


## A screen that only reports its buttons, populated with `r`.
func _screen(r: MatchRewards.Result) -> MatchResultScreen:
	var screen := SCENE.instantiate() as MatchResultScreen
	screen.changes_scene = false
	add_child(screen)
	screen.populate(r)
	return screen


func _shown(from: Node, path: String) -> bool:
	return (from.get_node(path) as CanvasItem).visible


func _label(from: Node, path: String) -> String:
	return (from.get_node(path) as Label).text


# ------------------------------------------------------------- the screen ----

func test_game_manager_shows_the_new_screen() -> void:
	assert_eq(GameManager.MATCH_RESULT_SCENE.resource_path, "res://Scenes/UI/Screens/MatchResultScreen.tscn")
	var screen := GameManager.MATCH_RESULT_SCENE.instantiate() as MatchResultScreen
	assert_true(screen != null, "a MatchResultScreen")
	if screen == null:
		return
	assert_eq(screen.process_mode, Node.PROCESS_MODE_ALWAYS, "its buttons work while the match is paused")
	assert_eq(screen.layer, 30)
	assert_true(screen.changes_scene, "a real result changes the scene")
	assert_eq(screen.lobby_scene_path, "res://Scenes/UI/Screens/MenuRoot.tscn", "LOBBY returns to MenuRoot, not the old menu")
	var main_uid := str(ProjectSettings.get_setting("application/run/main_scene"))
	assert_eq(ResourceUID.id_to_text(ResourceLoader.get_resource_uid(screen.lobby_scene_path)), main_uid, "the main scene")
	screen.free()


func test_populate_each_side_and_outcome() -> void:
	var cases := [
		[HEROES, WIN, &"BannerVictory", "VICTORY", "The beast is slain"],
		[HEROES, LOSS, &"BannerDefeat", "DEFEAT", "The jungle claims your squad"],
		[HEROES, TIMEOUT, &"BannerDefeat", "TIME UP", "The beast slipped away"],
		[MONSTER, WIN, &"BannerVictoryMonster", "VICTORY", "The jungle is yours"],
		[MONSTER, LOSS, &"BannerDefeat", "DEFEAT", "The hunters prevailed"],
	]
	for c: Array in cases:
		var side: int = c[0]
		var outcome: int = c[1]
		var tag := "%s %s" % ["monster" if side == MONSTER else "heroes", c[3]]
		var monster_side := side == MONSTER
		var r := _result(side, outcome)
		var screen := _screen(r)
		assert_true(screen.result == r, tag)
		assert_eq((screen.get_node(^"%Ribbon") as Control).theme_type_variation, c[2], tag + " ribbon")
		assert_eq(MatchResultScreen.ribbon_variation(side, outcome), c[2], tag)
		assert_eq(_label(screen, "%Outcome"), c[3], tag + " title")
		assert_eq(_label(screen, "%Sub"), "%s  ·  12:34" % c[4], tag + " line and time")
		assert_eq((screen.get_node(^"%Backdrop") as TextureRect).texture,
				MatchResultScreen.MONSTER_BACKDROP if monster_side else MatchResultScreen.HERO_BACKDROP, tag + " stage")
		assert_eq((screen.get_node(^"%StageFrame") as Control).theme_type_variation,
				&"FrameMonster" if monster_side else &"FrameHero", tag + " frame")
		assert_eq((screen.get_node(^"%PlayAgain") as Control).theme_type_variation,
				&"ButtonMonster" if monster_side else &"ButtonPrimary", tag + " PLAY AGAIN")
		# Stats.
		assert_eq((screen.get_node(^"%StatTime") as StatTile).value, "12:34", tag)
		assert_eq((screen.get_node(^"%StatKills") as StatTile).value, "23", tag + " kills")
		assert_eq((screen.get_node(^"%StatKills") as StatTile).caption, "Mobs devoured" if monster_side else "Mobs slain", tag)
		var third := screen.get_node(^"%StatThird") as StatTile
		if monster_side:
			assert_eq([third.value, third.caption], ["Stage 3", "Evolution"], tag)
		else:
			assert_eq([third.value, third.caption], ["%d / 4" % r.heroes_alive, "Survivors"], tag)
		# Rewards: Gold, the side's currency, XP.
		assert_true(_shown(screen, "%Gold"), tag + " gold")
		assert_eq(_shown(screen, "%Steel"), not monster_side, tag + " steel")
		assert_eq(_shown(screen, "%Leaves"), monster_side, tag + " leaves")
		assert_eq((screen.get_node(^"%Gold") as RewardChip).amount, r.gold, tag)
		assert_eq((screen.get_node(^"%Steel") as RewardChip).amount, r.steel, tag)
		assert_eq((screen.get_node(^"%Leaves") as RewardChip).amount, r.leaves, tag)
		var xp := screen.get_node(^"%Xp") as RewardChip
		assert_eq([xp.amount, xp.caption], [r.xp, "XP" if monster_side else "XP each"], tag)
		# The cast and its XP rows.
		var cast := screen.cast()
		var rows := screen.xp_rows()
		assert_eq(cast.size(), 1 if monster_side else 4, tag + " cast")
		assert_eq(rows.size(), cast.size(), tag + " an XP row each")
		assert_eq((screen.get_node(^"%XpGrid") as GridContainer).columns, 1 if monster_side else 2, tag)
		if monster_side:
			assert_eq(cast[0].character.character_id(), &"nyxa", tag + " the match's monster")
			assert_eq(cast[0].stage, 3, tag + " at the stage it reached")
		else:
			assert_eq(cast.map(func(a: StageCharacter) -> StringName: return a.character.character_id()),
					[&"irelia", &"vlad", &"ted", &"river"], tag)
			assert_eq(cast.map(func(a: StageCharacter) -> bool: return a.flip), [false, false, true, true], tag + " facing inward")
		for i in cast.size():
			var down := outcome == LOSS
			assert_eq(cast[i].fallen, down, "%s %s fallen" % [tag, cast[i].name])
			assert_eq(cast[i].is_celebrating(), outcome == WIN, "%s %s celebrates" % [tag, cast[i].name])
			assert_eq(rows[i].fallen, down, tag + " row")
			assert_eq(rows[i].gain, r.xp, tag + " row gain")
			assert_eq(cast[i].mouse_filter, Control.MOUSE_FILTER_IGNORE, tag + " the cast is a picture")
		screen.queue_free()
		await wait_frames(1)


func test_fallen_heroes_lie_down_while_the_rest_celebrate() -> void:
	var fallen: Array[StringName] = [&"vlad"]
	var screen := _screen(_result(HEROES, WIN, 10, fallen))
	for actor in screen.cast():
		var id := actor.character.character_id()
		assert_eq(actor.fallen, id == &"vlad", "%s fallen" % id)
		assert_eq(actor.is_celebrating(), id != &"vlad", "%s celebrates" % id)
	var vlad := screen.cast()[1]
	assert_eq((vlad.get_node(^"%Hop") as Control).modulate, UiPalette.FALLEN_STAGE_MODULATE, "darkened")
	var vlad_rig := vlad.get_node(^"%Rig") as RigView
	assert_true(vlad_rig.greyed, "drained of colour")
	assert_true(vlad_rig.get_node(^"Holder") is CanvasGroup, "the whole body at once (a CanvasGroup)")
	assert_true(vlad_rig.rig != null, "the rig rebuilt inside it")
	assert_false((screen.cast()[0].get_node(^"%Rig") as RigView).greyed, "the standing ones keep their colour")
	assert_true((vlad.get_node(^"%Hop") as Control).rotation_degrees != 0.0, "tipped back")
	assert_false((vlad.get_node(^"%Rig") as RigView).animated, "posed still")
	assert_eq(_label(screen, "%StatThird/Row/Column/Value"), "3 / 4", "three survivors")
	var row := screen.xp_rows()[1]
	assert_true(row.fallen and _shown(row, "%Skull"), "the row's skull")
	assert_eq((row.get_node(^"%Head") as CanvasItem).modulate, UiPalette.FALLEN_MODULATE)
	# TIME UP: the fallen lie down, the survivors stand without cheering.
	var timeout := _screen(_result(HEROES, TIMEOUT, 10, fallen))
	for actor in timeout.cast():
		assert_eq(actor.fallen, actor.character.character_id() == &"vlad")
		assert_false(actor.is_celebrating(), "no cheering at TIME UP")
	# Standing up again.
	vlad.set_fallen(false)
	assert_eq((vlad.get_node(^"%Hop") as Control).rotation_degrees, 0.0)
	assert_false(vlad_rig.greyed)
	assert_true((vlad.get_node(^"%Rig") as RigView).animated)


func test_threat_bonus_on_the_currencies_only() -> void:
	var plain := _screen(_result(HEROES, WIN))
	assert_false(_shown(plain, "%ThreatBonus"), "no bonus at threat 0")
	assert_false(_shown(plain, "%Gold/Column/Foot/Bonus"))
	var r := _result(HEROES, WIN, 23, [], 2)
	var screen := _screen(r)
	assert_true(_shown(screen, "%ThreatBonus"), "threat 2 pays a bonus")
	assert_eq(_label(screen, "%ThreatText"), "Threat 2: +20% Steel and Gold")
	for chip: String in ["%Gold", "%Steel"]:
		assert_eq((screen.get_node(chip) as RewardChip).bonus_pct, 20, chip)
		assert_eq(_label(screen, chip + "/Column/Foot/Bonus"), "+20%", chip)
		assert_true(_shown(screen, chip + "/Column/Foot/Bonus"), chip)
	assert_eq((screen.get_node(^"%Xp") as RewardChip).bonus_pct, 0, "XP has no threat bonus")
	assert_false(_shown(screen, "%Xp/Column/Foot/Bonus"))
	assert_eq(r.gold, MatchRewards.with_threat_bonus(MatchRewards.GOLD_WIN + 23 * MatchRewards.GOLD_PER_KILL, 2), "the formula's bonus")
	var monster := _screen(_result(MONSTER, WIN, 23, [], 4))
	assert_eq(_label(monster, "%ThreatText"), "Threat 4: +40% Leaves and Gold")
	assert_eq((monster.get_node(^"%Leaves") as RewardChip).bonus_pct, 40)


func test_chips_count_up_and_bars_pop_level_up() -> void:
	if not require_isolated():
		return
	var r := _result(HEROES, WIN, 23)
	# The rewards are saved before populate: Irelia's 40 XP before the match
	# plus this match's cross Lv.2 (100 XP); Vlad's 500 + gain stay in Lv.3.
	PersistedData.add_hero_xp(&"irelia", 40 + r.xp)
	PersistedData.add_hero_xp(&"vlad", 320 + r.xp)
	assert_true(40 + r.xp >= 100 and 320 + r.xp < 600, "the sample numbers cross one level only for Irelia")
	var screen := _screen(r)
	var gold := screen.get_node(^"%Gold") as RewardChip
	assert_eq(gold.shown, 0, "the count starts at 0")
	var irelia := screen.xp_rows()[0]
	var vlad := screen.xp_rows()[1]
	assert_eq([irelia.total_before, irelia.level], [40, 1], "Irelia's bar starts at her pre-match total")
	assert_eq(vlad.level, 3)
	assert_eq(_label(irelia, "%Gain"), "+%d XP" % r.xp)
	await wait_seconds(INTRO_DONE)
	assert_eq(gold.shown, r.gold, "Gold counted up")
	assert_eq(_label(gold, "%Amount"), "+%s" % CurrencyChip.format_amount(r.gold))
	assert_eq((screen.get_node(^"%Steel") as RewardChip).shown, r.steel, "Steel counted up")
	assert_eq([irelia.level, irelia.levelled_up, _shown(irelia, "%LevelUp")], [2, true, true], "Irelia levelled up")
	assert_eq(_label(irelia, "%Level"), "Lv.2")
	assert_eq([vlad.level, vlad.levelled_up, _shown(vlad, "%LevelUp")], [3, false, false], "Vlad did not")
	var bar := irelia.get_node(^"%Bar") as ProgressBar
	assert_eq([bar.value, bar.max_value], [float(40 + r.xp - 100), 200.0], "the bar inside Lv.2")
	for section in screen.get_node(^"Root/Margin/Column").get_children():
		assert_eq((section as CanvasItem).modulate.a, 1.0, "%s faded in" % section.name)


func test_upgrades_ready_opens_that_sides_roster() -> void:
	if not require_isolated():
		return
	var none := _screen(_result(HEROES, WIN))
	assert_eq(none.upgrades_ready, 0, "a fresh save buys nothing")
	assert_false(_shown(none, "%Upgrades"), "no pill")
	PersistedData.add_currency(PersistedData.STEEL, 100000)
	PersistedData.add_currency(PersistedData.LEAVES, 100000)
	PersistedData.add_currency(PersistedData.GOLD, 100000)
	var screen := _screen(_result(HEROES, WIN))
	var expected := 0
	for id in SQUAD:
		expected += CharacterProgress.upgrades_ready(GameManager.ROSTER.find(id))
	assert_true(expected > 1, "the wallet buys ranks")
	assert_eq(screen.upgrades_ready, expected, "the cast's buyable ranks")
	assert_true(_shown(screen, "%Upgrades"))
	assert_eq(_label(screen, "%UpgradesText"), "%d upgrades ready" % expected)
	var asked: Array[int] = []
	screen.upgrades_requested.connect(func(side: int) -> void: asked.append(side))
	(screen.get_node(^"%Upgrades") as Button).pressed.emit()
	assert_eq(asked, [HEROES], "upgrades_requested(heroes)")
	assert_eq(GameManager.take_menu_roster(), -1, "a screen that keeps the scene asks nothing of the menu")
	var monster := _screen(_result(MONSTER, LOSS))
	monster.upgrades_requested.connect(func(side: int) -> void: asked.append(side))
	(monster.get_node(^"%Upgrades") as Button).pressed.emit()
	assert_eq(asked, [HEROES, MONSTER], "and the monster's side")
	# The request MenuRoot reads on entry, once (test_menu_root opens the menu
	# on it).
	GameManager.request_menu_roster(MONSTER)
	assert_eq(GameManager.take_menu_roster(), MONSTER)
	assert_eq(GameManager.take_menu_roster(), -1, "used up")


func test_buttons_and_their_wiring() -> void:
	var screen := _screen(_result(HEROES, WIN))
	for path: String in ["%Lobby", "%PlayAgain", "%Upgrades"]:
		var links := (screen.get_node(path) as BaseButton).pressed.get_connections()
		assert_eq(links.size(), 1, "%s is wired once" % path)
		if links.size() == 1:
			assert_true((links[0]["callable"] as Callable).get_object() == screen, "%s to the screen" % path)
	var said: Array[String] = []
	screen.lobby_requested.connect(func() -> void: said.append("lobby"))
	screen.play_again_requested.connect(func() -> void: said.append("again"))
	(screen.get_node(^"%Lobby") as Button).pressed.emit()
	(screen.get_node(^"%PlayAgain") as Button).pressed.emit()
	assert_eq(said, ["lobby", "again"])
	assert_true(screen.is_inside_tree(), "changes_scene = false keeps the scene")


func test_result_strings_are_translated() -> void:
	TranslationServer.set_locale("de")
	var screen := _screen(_result(MONSTER, WIN, 23, [], 1))
	assert_eq((screen.get_node(^"%StatKills") as StatTile).caption, "Mobs verschlungen")
	assert_eq(_label(screen, "%ThreatText"), "Bedrohung 1: +10% Blätter und Gold")
	assert_eq(_label(screen, "%Sub"), "Der Dschungel gehört dir  ·  12:34")
	TranslationServer.set_locale("en")


# ------------------------------------------------------- GameManager's side ----

func test_killer_side_and_the_kill_counters() -> void:
	var hero := HeroBase.new()
	var monster := MonsterBase.new()
	var pet := Node2D.new()
	pet.add_to_group(&"Hero")
	var mob := MobBase.new()
	var other := Node2D.new()
	assert_eq(GameManager.killer_side(hero), HEROES, "a hero")
	assert_eq(GameManager.killer_side(pet), HEROES, "Ted's pet (group Hero)")
	assert_eq(GameManager.killer_side(monster), MONSTER, "the monster")
	assert_eq(GameManager.killer_side(mob), -1, "a mob")
	assert_eq(GameManager.killer_side(other), -1)
	assert_eq(GameManager.killer_side(null), -1, "no killer")
	var before := [GameManager.mob_kills, GameManager.hero_mob_kills, GameManager.monster_mob_kills]
	for killer: Node in [hero, pet, monster, monster, null, other]:
		GameManager._on_entity_died(mob, killer)
	assert_eq(GameManager.mob_kills - int(before[0]), 6, "mob_kills counts every mob death")
	assert_eq(GameManager.hero_mob_kills - int(before[1]), 2, "the heroes' (hero and pet)")
	assert_eq(GameManager.monster_mob_kills - int(before[2]), 2, "the monster's")
	var side := GameManager.chosen_side
	GameManager.chosen_side = HEROES
	assert_eq(GameManager.played_side_kills(), GameManager.hero_mob_kills)
	GameManager.chosen_side = MONSTER
	assert_eq(GameManager.played_side_kills(), GameManager.monster_mob_kills)
	GameManager.chosen_side = side
	GameManager.mob_kills = int(before[0])
	GameManager.hero_mob_kills = int(before[1])
	GameManager.monster_mob_kills = int(before[2])
	for o: Node in [hero, monster, pet, mob, other]:
		o.free()


## The end of a match: the played side's kills pay (not every mob death), and
## the Result carries the cast and the heroes that fell.
func test_match_end_pays_the_played_sides_kills() -> void:
	if not require_isolated():
		return
	var saved := {
		"active": GameManager._match_active, "ended": GameManager.match_ended_flag,
		"alive": GameManager.heroes_alive, "time": GameManager._match_time,
		"kills": [GameManager.mob_kills, GameManager.hero_mob_kills, GameManager.monster_mob_kills],
		"threat": GameManager.match_threat, "monster": GameManager._monster_id,
	}
	var heroes_before: Array[StringName] = GameManager._participating_hero_ids.duplicate()
	GameManager.chosen_side = HEROES
	GameManager._participating_hero_ids.assign(SQUAD)
	GameManager._fallen_hero_ids.clear()
	GameManager._monster_id = &"grount"
	GameManager.match_threat = 0
	GameManager._match_time = 125.0
	GameManager.heroes_alive = 4
	GameManager._match_active = true
	GameManager.match_ended_flag = false
	GameManager.mob_kills = 12
	GameManager.hero_mob_kills = 7
	GameManager.monster_mob_kills = 3
	# No victory jingle: the headless dummy driver never reclaims a playback.
	GameManager.match_ended.disconnect(AudioManager._on_match_ended)
	# Vlad falls (where heroes_alive drops), then the monster dies.
	var vlad := HeroBase.new()
	vlad.name = "Vlad"
	GameManager._on_entity_died(vlad, null)
	assert_eq(GameManager.heroes_alive, 3)
	GameManager._end_match_with_outcome(WIN)
	var screen: MatchResultScreen = null
	for node in get_tree().root.get_children():
		if node is MatchResultScreen:
			screen = node
	assert_true(screen != null, "the result screen is up")
	assert_true(get_tree().paused, "over the paused match")
	if screen != null:
		var r := screen.result
		assert_eq(r.mob_kills, 7, "the heroes' kills, not every mob death (12)")
		assert_eq(r.steel, MatchRewards.CURRENCY_WIN + 7 * MatchRewards.CURRENCY_PER_KILL + 2 * MatchRewards.CURRENCY_PER_MINUTE
				+ 3 * MatchRewards.CURRENCY_PER_SURVIVOR, "Steel pays 7 kills")
		assert_eq(r.hero_ids, SQUAD, "the census")
		var fell: Array[StringName] = [&"vlad"]
		assert_eq(r.fallen_hero_ids, fell, "the hero that fell")
		assert_eq(r.monster_id, &"grount")
		assert_eq(_label(screen, "%StatKills/Row/Column/Value"), "7", "the tally shows the same count")
		assert_true(screen.cast()[1].fallen, "Vlad lies down")
		assert_eq(PersistedData.get_currency(PersistedData.STEEL), r.steel, "saved before populate")
		screen.queue_free()
	get_tree().paused = false
	GameManager.match_ended.connect(AudioManager._on_match_ended)
	vlad.free()
	GameManager._match_active = saved["active"]
	GameManager.match_ended_flag = saved["ended"]
	GameManager.heroes_alive = saved["alive"]
	GameManager._match_time = saved["time"]
	var kills: Array = saved["kills"]
	GameManager.mob_kills = kills[0]
	GameManager.hero_mob_kills = kills[1]
	GameManager.monster_mob_kills = kills[2]
	GameManager.match_threat = saved["threat"]
	GameManager._monster_id = saved["monster"]
	GameManager._participating_hero_ids.assign(heroes_before)
	GameManager._fallen_hero_ids.clear()
	await wait_frames(2)
