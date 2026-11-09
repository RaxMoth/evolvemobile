extends TestCase

## CharacterDetail: the OVERVIEW (stage rig, role, level and XP, six stat
## tiles read from HeroStats / MonsterStats, the ability tiles with their .tres
## icons, names and descriptions), the SKILL TREE mode (compact header, the
## tree view of UxTreeModel.from_meta_skills, the bottom sheet's rank, effects,
## price and UPGRADE with its block reasons, upgrade_requested), the tab badge,
## the account-wide Growth trees under the side's crest, and its own wiring in
## CharacterDetail.tscn. The screen lays out in a 720x1280 SubViewport. Tests
## that write the save run only in the isolated test user dir.

const DETAIL := preload("res://Scenes/UI/Screens/CharacterDetail.tscn")
const HEROES := MatchRewards.Side.HEROES
const MONSTER := MatchRewards.Side.MONSTER

var _viewport: SubViewport = null


func before_each() -> void:
	if is_isolated():
		PersistedData.wipe_progress(false)


func after_each() -> void:
	if _viewport != null:
		_viewport.queue_free()
		_viewport = null
	if is_isolated():
		PersistedData.wipe_progress(false)


func _detail() -> CharacterDetail:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(720, 1280)
	add_child(_viewport)
	var screen := DETAIL.instantiate() as CharacterDetail
	_viewport.add_child(screen)
	return screen


func _def(id: StringName) -> CharacterDef:
	return GameManager.ROSTER.find(id)


func _label(screen: Node, path: String) -> String:
	return (screen.get_node(path) as Label).text


func test_stat_rows_read_the_stats_resources() -> void:
	var irelia := _def(&"irelia")
	var hero := irelia.stats as HeroStats
	var basic := irelia.ability_slots()[1]
	var rows := CharacterDetail.stat_rows(irelia)
	var values: Array = []
	var captions: Array = []
	for row in rows:
		values.append(row[1])
		captions.append(row[2])
	assert_eq(str(captions), str(["Health", "Damage", "Attack speed", "Range", "Move speed", "Vision"]))
	assert_eq(str(values), str([
		CurrencyChip.format_amount(roundi(hero.base_max_health)), CurrencyChip.format_amount(roundi(hero.base_attack_damage)),
		"%.2f/s" % (1.0 / basic.cooldown), CurrencyChip.format_amount(roundi(hero.base_attack_range)),
		CurrencyChip.format_amount(roundi(hero.base_move_speed)), CurrencyChip.format_amount(roundi(hero.vision_radius)),
	]), "Irelia's HeroStats, attack speed from her basic attack")
	assert_eq(values[0], "160")
	assert_eq(values[2], "0.67/s")
	var grount := _def(&"grount")
	var monster := grount.stats as MonsterStats
	rows = CharacterDetail.stat_rows(grount)
	values.clear()
	for row in rows:
		values.append(row[1])
	assert_eq(str(values), str([
		CurrencyChip.format_amount(roundi(monster.stage_1_health)), "×%.1f" % monster.stage_1_damage_multiplier,
		CurrencyChip.format_amount(roundi(monster.stage_1_speed)), "%d XP" % monster.stage_2_xp, "%d XP" % monster.stage_3_xp,
		CurrencyChip.format_amount(roundi(monster.stage_3_health)),
	]), "Grount's MonsterStats")
	assert_eq(values[5], "2,200", "thousands get a comma")
	for row in rows:
		assert_true(ResourceLoader.exists(CharacterDetail.STAT_ICON_PATH % row[0]), "icon %s" % row[0])
	assert_true(CharacterDetail.stat_rows(null).is_empty())


func test_overview_shows_the_character() -> void:
	var screen := _detail()
	await wait_frames(1)
	var irelia := _def(&"irelia")
	screen.show_character(irelia)
	await wait_frames(2)
	assert_eq(screen.mode, CharacterDetail.Mode.OVERVIEW)
	assert_true((screen.get_node("%Stage") as CanvasItem).visible and (screen.get_node("%Overview") as CanvasItem).visible)
	assert_false((screen.get_node("%Header") as CanvasItem).visible or (screen.get_node("%TreeView") as CanvasItem).visible)
	assert_eq((screen.get_node("%Showcase") as StageCharacter).character, irelia, "her rig on the stage")
	assert_eq((screen.get_node("%TopBar") as TopBar).title, "Irelia")
	assert_eq(_label(screen, "%Role"), irelia.role_text)
	assert_true((screen.get_node("%RoleIcon") as TextureRect).texture != null)
	assert_eq(_label(screen, "%Level"), "Lv.%d" % CharacterProgress.level(irelia))
	assert_eq((screen.get_node("%NavBar") as NavBar).active_tab, &"heroes")
	var rows := CharacterDetail.stat_rows(irelia)
	var tiles := screen.stat_tiles()
	assert_eq(tiles.size(), 6)
	for i in tiles.size():
		assert_eq(tiles[i].value, rows[i][1], "tile %d" % i)
		assert_eq(tiles[i].caption, rows[i][2])
		assert_true(tiles[i].icon != null)
	var slots := irelia.ability_slots()
	var abilities := screen.ability_tiles()
	assert_eq(abilities.size(), 4)
	for i in abilities.size():
		assert_eq(abilities[i].ability, slots[i], "slot %d" % i)
		assert_true(abilities[i].visible)
		assert_eq((abilities[i].get_node("%Icon") as TextureRect).texture, slots[i].icon, "the .tres icon")
		assert_eq((abilities[i].get_node("%Name") as Label).text, slots[i].ability_name)
		assert_eq((abilities[i].get_node("%Kind") as Label).text, CharacterDetail.SLOT_KINDS[i])
	assert_true(abilities[3].button_pressed, "the ultimate is described first")
	assert_eq(_label(screen, "%AbilityDesc"), slots[3].description)
	abilities[0].button_pressed = true
	assert_eq(_label(screen, "%AbilityDesc"), slots[0].description, "a tap describes another ability")
	assert_false(abilities[3].button_pressed, "one tile at a time")
	var grount := _def(&"grount")
	screen.show_character(grount)
	assert_eq((screen.get_node("%NavBar") as NavBar).active_tab, &"monsters")
	assert_eq((screen.get_node("%Stage") as Control).theme_type_variation, &"CharacterCardMonster")
	var monster_slots := grount.ability_slots()
	abilities = screen.ability_tiles()
	for i in abilities.size():
		assert_eq(abilities[i].visible, monster_slots[i] != null, "slot %d shown only when it has an ability" % i)
	assert_eq(_label(screen, "%AbilityDesc"), monster_slots[3].description, "Ground Slam")
	var top_bar := screen.get_node("%TopBar") as TopBar
	assert_true(top_bar.chip(PersistedData.LEAVES).visible and not top_bar.chip(PersistedData.STEEL).visible)


func test_level_xp_and_tab_badge_read_the_save() -> void:
	if not require_isolated():
		return
	var irelia := _def(&"irelia")
	PersistedData.add_hero_xp(irelia.character_id(), 230)
	var screen := _detail()
	await wait_frames(1)
	screen.show_character(irelia)
	assert_false((screen.get_node("%TreeBadge") as CanvasItem).visible, "nothing to buy without Steel")
	var p := CharacterProgress.progress(irelia)
	var into: int = p["into"]
	var needed: int = p["needed"]
	assert_eq(_label(screen, "%Level"), "Lv.%d" % CharacterProgress.level(irelia))
	assert_eq(_label(screen, "%XpText"), "%d / %d XP" % [into, needed])
	assert_eq((screen.get_node("%Xp") as ProgressBar).value, float(into))
	assert_eq((screen.get_node("%Xp") as ProgressBar).max_value, float(needed))
	PersistedData.add_currency(PersistedData.STEEL, 200)
	screen.refresh()
	assert_true((screen.get_node("%TreeBadge") as CanvasItem).visible, "ranks ready to buy")
	assert_eq(_label(screen, "%TreeBadgeCount"), str(CharacterProgress.upgrades_ready(irelia)))


func test_tree_mode_and_the_sheet() -> void:
	if not require_isolated():
		return
	var grount := _def(&"grount")
	var screen := _detail()
	await wait_frames(1)
	screen.show_character(grount)
	(screen.get_node("%TreeTab") as BaseButton).pressed.emit()
	assert_eq(screen.mode, CharacterDetail.Mode.TREE)
	await wait_frames(2)
	assert_false((screen.get_node("%Stage") as CanvasItem).visible, "the stage folds away")
	assert_true((screen.get_node("%Header") as CanvasItem).visible and (screen.get_node("%Sheet") as CanvasItem).visible)
	assert_true((screen.get_node("%TreeTab") as BaseButton).button_pressed)
	assert_eq(screen.tree_id, grount.skill_tree_id())
	assert_true((screen.get_node("%HeadIcon") as TextureRect).texture is AtlasTexture, "the head portrait")
	var view := screen.tree_view()
	assert_eq(view.buttons().size(), screen.model.nodes.size())
	var upgrade := screen.get_node("%Upgrade") as Button
	assert_true(upgrade.disabled, "nothing selected yet")
	assert_eq(_label(screen, "%NodeName"), "Tap a node")
	view.select(&"g4_titan")
	assert_eq(_label(screen, "%NodeName"), "Titan Form")
	assert_eq(_label(screen, "%NodeMeta"), "Rank 0/1 · Tier 4")
	assert_eq(_label(screen, "%EffectNow"), "Not learned yet")
	assert_eq(_label(screen, "%EffectNext"), "Next: Stage 3: +50% size, +500 HP, +20 range")
	assert_true(upgrade.disabled)
	assert_eq(upgrade.text, "Learn a Tier 3 skill first")
	view.select(&"g1_dmg")
	assert_true(upgrade.disabled, "no Leaves")
	assert_eq(upgrade.text, "Need 100 more")
	var cost := screen.get_node("%CostValue") as Label
	assert_eq(cost.text, "100")
	assert_eq(cost.get_theme_color(&"font_color"), UiPalette.get_default().danger, "a price the wallet cannot pay")
	PersistedData.add_currency(PersistedData.LEAVES, 150)
	screen.refresh()
	assert_eq(view.selected, &"g1_dmg", "the selection survives a refresh")
	assert_false(upgrade.disabled)
	assert_eq(upgrade.text, "UPGRADE")
	assert_true(view.button(&"g1_dmg").buyable, "the red dot")
	var asked: Array[String] = []
	screen.upgrade_requested.connect(func(tree: StringName, node: StringName) -> void: asked.append("%s/%s" % [tree, node]))
	upgrade.pressed.emit()
	assert_eq(str(asked), str(["monster_grount/g1_dmg"]), "UPGRADE only asks")
	assert_false(MetaSkillManager.is_unlocked(grount.skill_tree_id(), &"g1_dmg"), "the screen never buys itself")
	assert_true(MetaSkillManager.unlock(grount.skill_tree_id(), &"g1_dmg"))
	screen.refresh()
	var bought := view.button(&"g1_dmg")
	assert_eq(bought.state, UxTreeModel.NodeState.MAXED)
	assert_true(bought.scale.x > 1.1, "the bought node pops")
	assert_eq(_label(screen, "%EffectNow"), "Now: +10% Damage")
	assert_eq(upgrade.text, "Maxed")
	assert_false((screen.get_node("%Cost") as CanvasItem).visible)
	(screen.get_node("%OverviewTab") as BaseButton).pressed.emit()
	assert_eq(screen.mode, CharacterDetail.Mode.OVERVIEW)
	assert_true((screen.get_node("%Stage") as CanvasItem).visible)


func test_tree_fits_the_portrait_screen() -> void:
	var screen := _detail()
	await wait_frames(1)
	for def in GameManager.ROSTER.all():
		screen.show_character(def, CharacterDetail.Mode.TREE)
		await wait_frames(2)
		var view := screen.tree_view()
		var rect := view.get_global_rect()
		var sheet := (screen.get_node("%Sheet") as Control).get_global_rect()
		assert_true(rect.end.y <= sheet.position.y + 0.5, "%s: the tree stays above the sheet" % def.character_id())
		assert_true(sheet.end.y <= 1280.0 - 120.0, "%s: the sheet stays above the nav bar (%.0f)" % [def.character_id(), sheet.end.y])
		var tiers: Dictionary[int, float] = {}
		for n in screen.model.nodes:
			var b := view.button(n.id)
			var r := b.get_global_rect()
			assert_true(r.position.x >= 0.0 and r.end.x <= 720.5, "%s/%s inside the screen (%s)" % [def.character_id(), n.id, str(r)])
			assert_true(r.position.y >= rect.position.y - 0.5 and r.end.y <= rect.end.y + 0.5, "%s/%s inside the view" % [def.character_id(), n.id])
			if tiers.has(n.tier):
				assert_near(r.position.y, tiers[n.tier], 0.5, "%s tier %d on one row" % [def.character_id(), n.tier])
			tiers[n.tier] = r.position.y
		for t in range(2, screen.model.tiers + 1):
			assert_true(tiers[t] > tiers[t - 1], "%s: tier %d below tier %d" % [def.character_id(), t, t - 1])


func test_growth_trees_follow_the_side() -> void:
	var screen := _detail()
	await wait_frames(1)
	screen.show_base_tree(MONSTER)
	assert_eq(screen.tree_id, MetaSkillManager.TREE_MONSTER_BASE)
	assert_eq(screen.mode, CharacterDetail.Mode.TREE, "an account tree is always a tree")
	assert_true(screen.character == null)
	assert_false((screen.get_node("%Tabs") as CanvasItem).visible, "no overview to switch to")
	assert_eq((screen.get_node("%HeadIcon") as TextureRect).texture, screen.crest_monster, "under the monster crest")
	assert_eq(_label(screen, "%HeadName"), MetaSkillManager.get_tree_def(MetaSkillManager.TREE_MONSTER_BASE).display_name)
	assert_true((screen.get_node("%HeadBlurb") as CanvasItem).visible)
	assert_false((screen.get_node("%HeadXp") as CanvasItem).visible)
	assert_eq((screen.get_node("%NavBar") as NavBar).active_tab, &"growth")
	assert_eq((screen.get_node("%TopBar") as TopBar).title, "Growth")
	assert_eq(screen.model.currency, PersistedData.GOLD)
	screen.set_mode(CharacterDetail.Mode.OVERVIEW)
	assert_eq(screen.mode, CharacterDetail.Mode.TREE)
	screen.show_base_tree(HEROES)
	assert_eq(screen.tree_id, MetaSkillManager.TREE_HERO_BASE)
	assert_eq((screen.get_node("%HeadIcon") as TextureRect).texture, screen.crest_heroes)
	assert_true(screen.crest_heroes != null and screen.crest_monster != null, "set in the scene")
	screen.show_character(_def(&"vlad"))
	assert_true((screen.get_node("%Tabs") as CanvasItem).visible, "a character has both tabs again")


func test_wiring_lives_in_the_scene() -> void:
	var screen := DETAIL.instantiate() as CharacterDetail
	var expected: Dictionary[String, StringName] = {
		"%TopBar": &"left_pressed", "%NavBar": &"tab_selected", "%OverviewTab": &"pressed",
		"%TreeTab": &"pressed", "%TreeView": &"node_selected", "%Upgrade": &"pressed", "%Showcase": &"character_pressed",
	}
	for i in 4:
		expected["%%Abilities/Ability%d" % i] = &"tile_pressed"
	for path: String in expected:
		var links := screen.get_node(path).get_signal_connection_list(expected[path])
		assert_eq(links.size(), 1, "%s.%s is wired" % [path, expected[path]])
		for c: Dictionary in links:
			var flags: int = c["flags"]
			assert_true(flags & CONNECT_PERSIST != 0, "%s: in CharacterDetail.tscn" % path)
	screen.free()
