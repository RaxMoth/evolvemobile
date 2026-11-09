extends TestCase

## CharacterDetail: the OVERVIEW (stage rig, role, level and XP, six stat
## tiles read from HeroStats / MonsterStats, the ability tiles with their
## display icons, names and descriptions), the SKILL TREE mode (compact header
## with the rank totals, the tree view of UxTreeModel.from_ranked_manager with
## its gutter, plaques and vines, the sheet opening on the suggested node, its
## rank line, effects, price inside UPGRADE with the block reasons, EQUIP on
## capstones, upgrade_requested / equip_requested, the purchase juice), the tab
## badge, the account-wide Growth trees under the side's crest, every tree
## fitting 720x1280, the top bar's counting chip, and its own wiring in
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
		assert_eq((abilities[i].get_node("%Icon") as TextureRect).texture, slots[i].get_display_icon(), "the display icon")
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
	var palette := UiPalette.get_default()
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
	assert_eq(_label(screen, "%HeadRanks"), "Ranks 0/%d" % screen.model.ranks_open(), "ranks owned / open")
	var view := screen.tree_view()
	assert_eq(view.buttons().size(), screen.model.nodes.size())
	assert_eq(view.slots().size(), screen.model.hidden_nodes.size(), "a slot per hidden capstone")
	assert_eq(view.gutter_plaques().size(), 4, "a gutter plaque per tier")
	assert_eq(view.branch_plaques().size(), 3)
	var upgrade := screen.get_node("%Upgrade") as Button
	var equip := screen.get_node("%Equip") as Button
	var cost := screen.get_node("%CostValue") as Label
	assert_eq(view.selected, &"g1_dmg", "nothing to buy: the sheet opens on the first open node")
	assert_eq(_label(screen, "%NodeName"), "Heavy Horns")
	assert_true(upgrade.disabled, "no Leaves")
	assert_eq(upgrade.text, "Need 40 more")
	assert_true((screen.get_node("%Cost") as CanvasItem).visible, "the price, inside UPGRADE")
	assert_eq(cost.text, "40")
	assert_eq(cost.get_theme_color(&"font_color"), palette.danger, "a price the wallet cannot pay")
	assert_eq((screen.get_node("%CostIcon") as TextureRect).texture, CurrencyChip.icon_for(PersistedData.LEAVES))
	assert_false(equip.visible, "only capstones equip")
	view.select(&"g4_titan")
	assert_eq(_label(screen, "%NodeName"), "Titan Form")
	assert_eq(_label(screen, "%NodeMeta"), "Rank 0/1 · Hide · Tier 4 · Capstone", "rank, branch, tier")
	assert_eq(_label(screen, "%EffectNow"), "Not learned yet")
	assert_eq(_label(screen, "%EffectNext"), "Next: Stage 3: +50% size, +500 HP, +20 range")
	assert_true(upgrade.disabled)
	assert_eq(upgrade.text, "Needs Lv 8", "character trees open tier 4 at Grount Lv 8")
	assert_false((screen.get_node("%Cost") as CanvasItem).visible, "the gate stops it, not the price")
	assert_true(equip.visible and equip.disabled, "a capstone shows EQUIP, usable once owned")
	assert_eq(equip.text, "EQUIP")
	view.select(&"g1_dmg")
	PersistedData.add_currency(PersistedData.LEAVES, 150)
	screen.refresh()
	assert_eq(view.selected, &"g1_dmg", "the selection survives a refresh")
	assert_false(upgrade.disabled)
	assert_eq(upgrade.text, "UPGRADE")
	assert_eq(cost.get_theme_color(&"font_color"), screen.get_theme_color(&"font_color", &"Counter"), "an affordable price")
	assert_true(view.button(&"g1_dmg").buyable, "the red +")
	assert_eq(view.vine_color(&"g1_dmg", &"g2_cleavecd"), palette.locked_line, "a vine from a node not owned")
	var asked: Array[String] = []
	screen.upgrade_requested.connect(func(tree: StringName, node: StringName) -> void: asked.append("%s/%s" % [tree, node]))
	upgrade.pressed.emit()
	assert_eq(str(asked), str(["monster_grount/g1_dmg"]), "UPGRADE only asks")
	assert_false(MetaSkillManager.is_unlocked(grount.skill_tree_id(), &"g1_dmg"), "the screen never buys itself")
	assert_true(MetaSkillManager.unlock(grount.skill_tree_id(), &"g1_dmg"))
	screen.refresh()
	var bought := view.button(&"g1_dmg")
	assert_eq(bought.state, UxTreeModel.NodeState.OWNED, "rank 1 of 5")
	assert_true(bought.scale.x > 1.1, "the bought node pops")
	assert_eq(view.vine_color(&"g1_dmg", &"g2_cleavecd"), palette.moss, "its vines light up")
	assert_true(view.is_recolouring(), "fading from the old colour")
	assert_eq(_label(screen, "%NodeMeta"), "Rank 1/5 · Horns · Tier 1")
	assert_eq(_label(screen, "%EffectNow"), "Now: +10% damage")
	assert_eq(_label(screen, "%EffectNext"), "Next: +14% damage")
	assert_eq(_label(screen, "%HeadRanks"), "Ranks 1/%d" % screen.model.ranks_open())
	assert_eq(upgrade.text, "UPGRADE", "rank 2 costs 60 of the 110 left")
	assert_eq(cost.text, "60")
	await wait_seconds(SkillTreeView.RECOLOUR_TIME + 0.1)
	assert_false(view.is_recolouring(), "the recolour settles")
	PersistedData.add_currency(PersistedData.LEAVES, 1000)
	for i in 4:
		assert_true(MetaSkillManager.rank_up(grount.skill_tree_id(), &"g1_dmg"))
	screen.refresh()
	assert_eq(view.button(&"g1_dmg").state, UxTreeModel.NodeState.MAXED)
	assert_eq(_label(screen, "%EffectNow"), "Now: +22% damage")
	assert_eq(upgrade.text, "Maxed")
	assert_false((screen.get_node("%Cost") as CanvasItem).visible)
	(screen.get_node("%OverviewTab") as BaseButton).pressed.emit()
	assert_eq(screen.mode, CharacterDetail.Mode.OVERVIEW)
	assert_true((screen.get_node("%Stage") as CanvasItem).visible)


func test_the_sheet_opens_on_a_buyable_node() -> void:
	if not require_isolated():
		return
	var irelia := _def(&"irelia")
	PersistedData.add_currency(PersistedData.STEEL, 200)
	var screen := _detail()
	await wait_frames(1)
	screen.show_character(irelia, CharacterDetail.Mode.TREE)
	var view := screen.tree_view()
	assert_eq(view.selected, screen.model.suggested_node())
	assert_true(screen.model.can_buy(screen.model.find(view.selected)), "the first node the wallet can buy")
	assert_eq(view.selected, &"i1_hp", "top left first")
	assert_true(view.button(view.selected).is_selected())
	assert_eq(_label(screen, "%NodeName"), "Reinforced Plate", "never 'Tap a node'")
	assert_false((screen.get_node("%Upgrade") as Button).disabled)
	view.select(&"i1_speed")
	screen.show_character(_def(&"vlad"), CharacterDetail.Mode.TREE)
	assert_eq(view.selected, screen.model.suggested_node(), "another tree opens on its own suggestion")
	screen.show_character(irelia, CharacterDetail.Mode.TREE)
	assert_eq(view.selected, &"i1_hp")


## Two of Irelia's capstones owned: the equipped one says EQUIPPED, the other
## offers EQUIP and reports equip_requested; a bought capstone only equips.
func test_capstones_equip_from_the_sheet() -> void:
	if not require_isolated():
		return
	var irelia := _def(&"irelia")
	var tree_id := irelia.skill_tree_id()
	PersistedData.add_hero_xp(&"irelia", 2800)
	for id: StringName in [&"i1_hp", &"i2_hp", &"i3_hp", &"ir_regen", &"i2_rallycd", &"ir_aegis", &"ir_laststand", &"ir_guardian"]:
		PersistedData.set_skill_rank(tree_id, id, 1)
	PersistedData.set_equipped_capstone(tree_id, &"ir_guardian")
	var screen := _detail()
	await wait_frames(1)
	screen.show_character(irelia, CharacterDetail.Mode.TREE)
	var view := screen.tree_view()
	var upgrade := screen.get_node("%Upgrade") as Button
	var equip := screen.get_node("%Equip") as Button
	assert_true(view.button(&"ir_guardian").equipped, "the check on the equipped capstone")
	assert_false(view.button(&"ir_laststand").equipped)
	assert_true(view.button(&"ir_guardian").capstone)
	view.select(&"ir_guardian")
	assert_true(equip.visible and equip.disabled)
	assert_eq(equip.text, "EQUIPPED")
	assert_false(upgrade.visible, "nothing left to buy")
	view.select(&"ir_laststand")
	assert_eq(equip.text, "EQUIP")
	assert_false(equip.disabled)
	var asked: Array[String] = []
	screen.equip_requested.connect(func(tree: StringName, node: StringName) -> void: asked.append("%s/%s" % [tree, node]))
	equip.pressed.emit()
	assert_eq(str(asked), str(["hero_irelia/ir_laststand"]), "EQUIP only asks")
	assert_eq(MetaSkillManager.equipped_capstone(tree_id), &"ir_guardian", "the screen never equips itself")
	assert_true(MetaSkillManager.equip_capstone(tree_id, &"ir_laststand"))
	screen.refresh()
	assert_eq(view.selected, &"ir_laststand")
	assert_eq(equip.text, "EQUIPPED")
	assert_true(view.button(&"ir_laststand").equipped and not view.button(&"ir_guardian").equipped)
	view.select(&"ir_banner")
	assert_true(upgrade.visible and equip.visible and equip.disabled, "not owned: UPGRADE, and EQUIP waiting")


func test_the_top_bar_counts_down_after_a_purchase() -> void:
	if not require_isolated():
		return
	PersistedData.add_currency(PersistedData.LEAVES, 200)
	var screen := _detail()
	await wait_frames(1)
	screen.show_character(_def(&"grount"), CharacterDetail.Mode.TREE)
	var chip := (screen.get_node("%TopBar") as TopBar).chip(PersistedData.LEAVES)
	assert_eq(chip.shown_amount(), 200)
	assert_true(MetaSkillManager.rank_up(MetaSkillManager.monster_tree_id(&"grount"), &"g1_dmg"))
	await wait_frames(3)
	assert_true(chip.shown_amount() < 200 and chip.shown_amount() > 160, "counting down (%d)" % chip.shown_amount())
	await wait_seconds(CurrencyChip.COUNT_TIME + 0.1)
	assert_eq(chip.shown_amount(), 160)
	assert_eq((chip.get_node("%Amount") as Label).text, "160")


func test_tree_fits_the_portrait_screen() -> void:
	var screen := _detail()
	await wait_frames(1)
	var screens: Array[Array] = []
	for def in GameManager.ROSTER.all():
		screens.append([def, -1])
	screens.append([null, HEROES])
	screens.append([null, MONSTER])
	for entry in screens:
		var def := entry[0] as CharacterDef
		var tag := "base %d" % entry[1]
		if def != null:
			tag = String(def.character_id())
		if def != null:
			screen.show_character(def, CharacterDetail.Mode.TREE)
		else:
			screen.show_base_tree(entry[1])
		await wait_frames(2)
		var view := screen.tree_view()
		var rect := view.get_global_rect()
		var sheet := (screen.get_node("%Sheet") as Control).get_global_rect()
		assert_true(rect.end.y <= sheet.position.y + 0.5, "%s: the tree stays above the sheet" % tag)
		assert_true(sheet.end.y <= 1280.0 - 120.0, "%s: the sheet stays above the nav bar (%.0f)" % [tag, sheet.end.y])
		var tiers: Dictionary[int, float] = {}
		var pieces: Array[SkillNodeButton] = view.buttons()
		pieces.append_array(view.slots())
		for b in pieces:
			var r := b.get_global_rect()
			var label := "%s/%s" % [tag, b.node_id]
			assert_true(r.position.x >= 0.0 and r.end.x <= 720.5, "%s inside the screen (%s)" % [label, str(r)])
			assert_true(r.position.y >= rect.position.y - 0.5 and r.end.y <= rect.end.y + 0.5, "%s inside the view" % label)
			if b.capstone:
				assert_true(r.position.y - SkillNodeButton.ARCH_RISE >= rect.position.y - 0.5, "%s: its arch too" % label)
			var name_rect := (b.get_node("%NameLabel") as Control).get_global_rect()
			assert_true(name_rect.position.x >= 0.0 and name_rect.end.x <= 720.5, "%s: its name fits" % label)
		for n in screen.model.nodes:
			var y := view.node_center(n.id).y
			if tiers.has(n.tier):
				assert_near(y, tiers[n.tier], 0.5, "%s tier %d on one row" % [tag, n.tier])
			tiers[n.tier] = y
		for t in range(2, screen.model.tiers + 1):
			assert_true(tiers[t] > tiers[t - 1], "%s: tier %d below tier %d" % [tag, t, t - 1])
		for plaque: Control in view.gutter_plaques() + view.branch_plaques():
			if plaque == null:
				continue
			var r := plaque.get_global_rect()
			assert_true(r.position.x >= 0.0 and r.end.x <= 720.5 and r.position.y >= rect.position.y - 0.5
					and r.end.y <= rect.end.y + 0.5, "%s: plaque inside the view (%s)" % [tag, str(r)])


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
		"%TreeTab": &"pressed", "%TreeView": &"node_selected", "%Upgrade": &"pressed", "%Equip": &"pressed",
		"%Showcase": &"character_pressed",
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
