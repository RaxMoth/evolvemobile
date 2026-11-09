extends TestCase

## The menu component kit (Scenes/UI/Components, Scenes/UI/Widgets) and the
## CharacterProgress numbers it shows: the collection card in its normal,
## upgrade-ready, locked-purchasable and rumour states (pill text and
## variation, dot, padlock, price), its size presets, the RigView and
## StageCharacter puppets (fitted, silhouetted, never touching the global
## RNG), the nav bar's ButtonGroup and notify API, and the currency chips.
## Tests that seed XP or currencies write the save, so they run only in the
## isolated test user dir.

const CARD := preload("res://Scenes/UI/Components/CharacterCard.tscn")
const STAGE_CHARACTER := preload("res://Scenes/UI/Components/StageCharacter.tscn")
const NAV_BAR := preload("res://Scenes/UI/Components/NavBar.tscn")
const TOP_BAR := preload("res://Scenes/UI/Components/TopBar.tscn")
const LOCKED_SHADER := preload("res://Assets/UI/Shaders/card_locked.gdshader")
## Irelia's tree: three tier-1 nodes at 100 Steel, three tier-2 nodes at 300.
const HERO_TIER_1 := 3
const HERO_TIER_2 := 3


func before_each() -> void:
	if is_isolated():
		PersistedData.wipe_progress(false)


func _irelia() -> CharacterDef:
	return GameManager.ROSTER.find(&"irelia")


func _grount() -> CharacterDef:
	return GameManager.ROSTER.find(&"grount")


## A locked monster outside the roster, over Nyxa's built art.
func _locked_def(price: int) -> CharacterDef:
	var d := CharacterDef.new()
	d.side = CharacterDef.MONSTER
	d.display_name = "Nyxa"
	d.portrait = load("res://Assets/Characters/nyxa/nyxa.svg") as Texture2D
	d.rig_body = load("res://Assets/Characters/nyxa/nyxa_body.tscn") as PackedScene
	d.rig_profile = load("res://Assets/Characters/nyxa/nyxa_motion.tres") as RigProfile
	d.unlocked_by_default = false
	d.unlock_cost = price
	return d


func _card(def: CharacterDef, animated: bool = true) -> CharacterCard:
	var card := CARD.instantiate() as CharacterCard
	card.character = def
	card.animated = animated
	add_child(card)
	return card


func _node(owner_node: Node, unique: String) -> Node:
	return owner_node.get_node("%" + unique)


func _visible(owner_node: Node, unique: String) -> bool:
	return (_node(owner_node, unique) as CanvasItem).visible


func _text(owner_node: Node, unique: String) -> String:
	return (_node(owner_node, unique) as Label).text


func _variation(owner_node: Node, unique: String) -> StringName:
	return (_node(owner_node, unique) as Control).theme_type_variation


# ------------------------------------------------------------ progress ----

func test_progress_follows_the_xp_curve() -> void:
	if not require_isolated():
		return
	var irelia := _irelia()
	assert_eq(CharacterProgress.level(irelia), 1, "no XP: Lv.1")
	assert_eq(CharacterProgress.xp_into(irelia), 0)
	assert_eq(CharacterProgress.xp_needed(irelia), PersistedData.XP_PER_LEVEL_STEP, "Lv.2 costs one step")
	PersistedData.add_hero_xp(&"irelia", 230)
	assert_eq(CharacterProgress.xp(irelia), 230)
	assert_eq(CharacterProgress.level(irelia), 2, "100 XP reach Lv.2")
	assert_eq(CharacterProgress.xp_into(irelia), 130, "XP inside Lv.2")
	assert_eq(CharacterProgress.xp_needed(irelia), 200, "Lv.3 costs two steps")
	assert_eq(CharacterProgress.level(irelia), PersistedData.level_from_xp(230), "one curve with PersistedData")
	PersistedData.add_monster_xp(&"grount", 500)
	assert_eq(CharacterProgress.xp(_grount()), 500, "monsters read the monster XP section")
	assert_eq(CharacterProgress.level(_grount()), 3, "100 + 200 XP reach Lv.3")
	assert_eq(CharacterProgress.xp_into(_grount()), 200)
	assert_eq(CharacterProgress.xp_needed(_grount()), 300)


func test_upgrades_ready_counts_buyable_nodes() -> void:
	if not require_isolated():
		return
	var irelia := _irelia()
	var tree := irelia.skill_tree_id()
	assert_eq(CharacterProgress.upgrades_ready(irelia), 0, "nothing affordable without Steel")
	PersistedData.add_currency(PersistedData.STEEL, 100)
	assert_eq(CharacterProgress.upgrades_ready(irelia), HERO_TIER_1, "every tier-1 node is affordable, tier 2 is gated")
	assert_eq(CharacterProgress.upgrades_ready(_grount()), 0, "Steel buys nothing in a Leaves tree")
	assert_true(MetaSkillManager.unlock(tree, &"i1_hp"))
	assert_eq(CharacterProgress.upgrades_ready(irelia), 0, "the Steel is spent")
	PersistedData.add_currency(PersistedData.STEEL, 300)
	assert_eq(CharacterProgress.upgrades_ready(irelia), HERO_TIER_1 - 1 + HERO_TIER_2,
			"owned nodes do not count, the opened tier 2 does")
	assert_eq(CharacterProgress.upgrades_ready(_locked_def(100)), 0, "a locked character has none")


func test_unlocked_comes_from_the_def() -> void:
	for d in GameManager.ROSTER.all():
		assert_true(CharacterProgress.is_unlocked(d), "%s ships unlocked" % d.character_id())
	assert_false(CharacterProgress.is_unlocked(_locked_def(2500)))
	assert_false(CharacterProgress.is_unlocked(null))


# --------------------------------------------------------------- cards ----

func test_normal_card_shows_level_and_xp() -> void:
	if not require_isolated():
		return
	PersistedData.add_hero_xp(&"irelia", 230)
	var card := _card(_irelia())
	assert_eq(_text(card, "Level"), "Lv.2")
	assert_eq(_text(card, "Name"), "Irelia")
	assert_eq(_text(card, "PillLabel"), "130/200", "XP into / needed")
	assert_eq(_variation(card, "Pill"), &"PillProgress")
	var pill := _node(card, "Pill") as ProgressBar
	assert_near(pill.value / pill.max_value, 130.0 / 200.0, 0.001, "the pill fills with the XP")
	assert_false(_visible(card, "UpIcon"), "no up arrow")
	assert_false(_visible(card, "Dot"), "no notify dot")
	assert_false(_visible(card, "Lock"))
	assert_false(_visible(card, "Price"))
	assert_false(_visible(card, "RumourBox"))
	assert_eq(_variation(card, "Frame"), &"CharacterCard", "copper hero frame")
	assert_eq(_variation(card, "Inner"), &"CardInnerHero")
	assert_true(_visible(card, "Rig") and not _visible(card, "Portrait"), "animated: the live rig")
	var rig := (_node(card, "Rig") as RigView).rig
	assert_true(rig != null, "the rig is built")
	card.refresh()
	assert_true((_node(card, "Rig") as RigView).rig == rig, "a refresh keeps the running rig")
	card.animated = false
	assert_true(_visible(card, "Portrait") and not _visible(card, "Rig"), "static: the portrait")
	assert_eq((_node(card, "Portrait") as TextureRect).texture, _irelia().portrait)
	assert_true((_node(card, "Portrait") as TextureRect).material == null, "in colour")
	card.selected = true
	assert_eq(_variation(card, "Frame"), &"CharacterCardSelected", "picker selection")


func test_upgrade_ready_card_turns_red() -> void:
	if not require_isolated():
		return
	PersistedData.add_currency(PersistedData.STEEL, 100)
	var card := _card(_irelia(), false)
	assert_eq(card.upgrades, HERO_TIER_1)
	assert_eq(_text(card, "PillLabel"), str(HERO_TIER_1), "the up arrow and N")
	assert_true(_visible(card, "UpIcon"), "the up arrow")
	assert_eq(_variation(card, "Pill"), &"PillProgressReady", "red pill")
	assert_true(_visible(card, "Dot"), "notify dot")
	assert_eq(_text(card, "Level"), "Lv.1", "the level still shows")
	assert_true(MetaSkillManager.unlock(_irelia().skill_tree_id(), &"i1_dmg"))
	card.refresh()
	assert_eq(_variation(card, "Pill"), &"PillProgress", "back to XP once nothing is affordable")
	assert_eq(_text(card, "PillLabel"), "0/100")
	assert_false(_visible(card, "Dot"))


func test_locked_purchasable_card() -> void:
	var card := _card(_locked_def(6000))
	assert_false(card.unlocked)
	assert_true(_visible(card, "Lock"), "padlock")
	assert_eq(_text(card, "Name"), "???")
	assert_false(_visible(card, "Level"), "no level")
	assert_false(_visible(card, "Pill"), "no pill")
	assert_false(_visible(card, "Dot"))
	assert_true(_visible(card, "Price"), "price chip")
	assert_eq(_text(card, "PriceLabel"), "6,000")
	assert_eq((_node(card, "PriceIcon") as TextureRect).texture, CurrencyChip.icon_for(PersistedData.LEAVES), "monsters cost Leaves")
	assert_eq((_node(card, "PriceLabel") as Label).get_theme_color(&"font_color"), UiPalette.get_default().leaves,
			"price in the currency's palette colour")
	var portrait := _node(card, "Portrait") as TextureRect
	assert_true(portrait.visible and not _visible(card, "Rig"), "the static portrait, even when animated")
	assert_true(portrait.material is ShaderMaterial and (portrait.material as ShaderMaterial).shader == LOCKED_SHADER,
			"card_locked silhouette")
	assert_eq(_variation(card, "Frame"), &"CharacterCardLocked")
	assert_eq(_variation(card, "Inner"), &"CardInnerLocked")
	var free_lock := _card(_locked_def(0))
	assert_true(_visible(free_lock, "Lock") and not _visible(free_lock, "Price"), "no price chip without a price")


func test_rumour_card() -> void:
	var card := CARD.instantiate() as CharacterCard
	card.rumour = true
	card.monster_side = true
	add_child(card)
	assert_true(_visible(card, "RumourBox"), "the question mark and the rumour line")
	assert_eq(_text(card, "RumourMark"), "?")
	for hidden: String in ["Lock", "Level", "Name", "Pill", "Price", "Dot", "Rig", "Portrait"]:
		assert_false(_visible(card, hidden), "rumour hides %s" % hidden)
	assert_eq(_variation(card, "Frame"), &"CharacterCardLocked")
	var got: Array = []
	card.card_pressed.connect(func(d: CharacterDef) -> void: got.append(d))
	card.pressed.emit()
	assert_eq(got, [null], "a rumour card reports no character")


func test_monster_card_and_press() -> void:
	var card := _card(_grount())
	card.apply_progress(6, 170, 600, 3, true)
	assert_eq(_variation(card, "Frame"), &"CharacterCardMonster", "crimson monster frame")
	assert_eq(_variation(card, "Inner"), &"CardInnerMonster")
	assert_eq(_text(card, "Level"), "Lv.6")
	assert_eq(_text(card, "PillLabel"), "3")
	assert_eq(_variation(card, "Pill"), &"PillProgressReady")
	card.apply_progress(6, 170, 600, 0, true)
	assert_eq(_text(card, "PillLabel"), "170/600")
	var got: Array = []
	card.card_pressed.connect(func(d: CharacterDef) -> void: got.append(d))
	card.pressed.emit()
	assert_eq(got, [_grount()], "the card reports its character")


func test_size_presets_scale_the_card() -> void:
	var card := _card(_grount(), false)
	var m_font := (_node(card, "Level") as Label).get_theme_font_size(&"font_size")
	var expected: Array[Vector2] = [Vector2(150, 238), Vector2(160, 262), Vector2(280, 446)]
	for preset: int in [CharacterCard.CardSize.S, CharacterCard.CardSize.M, CharacterCard.CardSize.L]:
		card.size_preset = preset as CharacterCard.CardSize
		assert_eq(card.custom_minimum_size, expected[preset], "preset %d size" % preset)
		assert_eq(card.size, expected[preset])
	assert_true((_node(card, "Level") as Label).get_theme_font_size(&"font_size") > m_font, "L type is larger")
	card.size_preset = CharacterCard.CardSize.M
	assert_eq((_node(card, "Level") as Label).get_theme_font_size(&"font_size"), m_font, "back to the M type")


# ----------------------------------------------------- rigs and stages ----

func test_rig_view_fits_and_leaves_the_global_rng_alone() -> void:
	seed(4242)
	var expected := randi()
	seed(4242)
	var view := RigView.new()
	view.size = Vector2(140, 180)
	view.character = _grount()
	add_child(view)
	var stage := STAGE_CHARACTER.instantiate() as StageCharacter
	stage.character = _irelia()
	add_child(stage)
	await wait_frames(3)
	assert_eq(randi(), expected, "puppets and idles never draw from the global RNG")
	assert_true(view.rig != null and view.rig.is_processing(), "an animated puppet processes")
	assert_eq(view.mouse_filter, Control.MOUSE_FILTER_IGNORE, "taps go to the card or button")
	var holder := view.rig.get_parent() as Node2D
	var b := view.rig.body.bounds
	var art_h := (maxf(b.end.y, 0.0) - b.position.y + _grount().rig_profile.bounce) * _grount().rig_profile.world_scale * holder.scale.y
	assert_true(art_h <= view.size.y + 0.5, "the art fits the height (%.1f <= %.1f)" % [art_h, view.size.y])
	var k := _grount().rig_profile.world_scale * holder.scale.y
	var left := holder.position.x + b.position.x * k
	var right := holder.position.x + b.end.x * k
	assert_true(left >= 0.0 and right <= view.size.x, "the art fits the width (%.1f..%.1f)" % [left, right])
	assert_near(left, view.size.x - right, 0.01, "the art box is centred")
	view.flip = true
	assert_true(holder.scale.x < 0.0, "flip mirrors")
	assert_near(holder.position.x - b.end.x * k, view.size.x - (holder.position.x - b.position.x * k), 0.01,
			"the mirrored box is centred too")
	view.silhouette = true
	assert_eq(holder.modulate, UiPalette.get_default().locked_fill, "silhouette in locked_fill")
	view.animated = false
	assert_false(view.rig.is_processing(), "posed once")
	view.character = null
	assert_true(view.rig == null, "no character, no rig")


func test_stage_character_idles_per_instance_and_cheers() -> void:
	var a := STAGE_CHARACTER.instantiate() as StageCharacter
	a.name = "StageA"
	a.character = _irelia()
	add_child(a)
	var b := STAGE_CHARACTER.instantiate() as StageCharacter
	b.name = "StageB"
	b.character = _irelia()
	add_child(b)
	assert_true(a.period != b.period, "each instance bobs with its own period")
	for sc: StageCharacter in [a, b]:
		assert_true(sc.period >= sc.bob_period * 0.85 and sc.period <= sc.bob_period * 1.2,
				"%s period %.3f within 0.85-1.2 x bob_period" % [sc.name, sc.period])
	var lock_b := _node(b, "Lock") as CanvasItem
	assert_false(lock_b.visible, "an owned character has no padlock")
	var locked := STAGE_CHARACTER.instantiate() as StageCharacter
	locked.character = _locked_def(2500)
	add_child(locked)
	assert_true(_visible(locked, "Lock"), "padlock")
	assert_true((_node(locked, "Rig") as RigView).silhouette, "silhouette")
	var hop := _node(b, "Hop") as Control
	b.cheer(0.0)
	await wait_seconds(0.12)
	assert_true(hop.position.y < -5.0, "the cheer hops (%.1f)" % hop.position.y)
	await wait_seconds(0.4)
	assert_near(hop.position.y, 0.0, 0.5, "and lands")


func test_stage_character_period_is_seeded_by_name_and_path() -> void:
	var first := STAGE_CHARACTER.instantiate() as StageCharacter
	first.name = "Seeded"
	add_child(first)
	var period := first.period
	remove_child(first)
	first.free()
	var second := STAGE_CHARACTER.instantiate() as StageCharacter
	second.name = "Seeded"
	add_child(second)
	assert_eq(second.period, period, "same name and path, same idle")


# ----------------------------------------------------------- nav, chips ----

func test_nav_bar_tabs_form_one_group() -> void:
	var nav := NAV_BAR.instantiate() as NavBar
	add_child(nav)
	var ids: Array[StringName] = []
	for t in nav.tabs():
		ids.append(t.tab_id)
	var order: Array[StringName] = [&"heroes", &"growth", &"hunt", &"codex", &"monsters"]
	assert_eq(ids, order, "bar order")
	var group := nav.tabs()[0].button_group
	assert_true(group != null, "a ButtonGroup")
	for t in nav.tabs():
		assert_true(t.button_group == group and t.toggle_mode, "%s is a toggle in the group" % t.tab_id)
		assert_eq(t.button_pressed, t.tab_id == &"hunt", "%s pressed only if active" % t.tab_id)
	assert_true(nav.tab(&"hunt") is NavArch, "HUNT is the arch")
	var got: Array[StringName] = []
	nav.tab_selected.connect(func(id: StringName) -> void: got.append(id))
	nav.tab(&"heroes").pressed.emit()
	var heroes_only: Array[StringName] = [&"heroes"]
	assert_eq(got, heroes_only, "tab_selected reports the tab")
	assert_eq(nav.active_tab, &"heroes")
	for t in nav.tabs():
		assert_eq(t.button_pressed, t.tab_id == &"heroes", "%s lit only if chosen" % t.tab_id)
	nav.notify_tabs = [&"growth"]
	assert_true((nav.tab(&"growth").get_node(^"Dot") as CanvasItem).visible, "growth dot")
	assert_false((nav.tab(&"codex").get_node(^"Dot") as CanvasItem).visible)
	nav.set_notify(&"codex", true)
	nav.set_notify(&"growth", false)
	var codex_only: Array[StringName] = [&"codex"]
	assert_eq(nav.notify_tabs, codex_only)
	var palette := UiPalette.get_default()
	assert_eq((nav.tab(&"hunt") as NavArch).glow_color, palette.amber, "hero side: amber arch")
	nav.monster_side = true
	assert_eq((nav.tab(&"hunt") as NavArch).glow_color, palette.monster, "monster side: crimson arch")
	var other := NAV_BAR.instantiate() as NavBar
	add_child(other)
	assert_true(other.tabs()[0].button_group != group, "every bar has its own group")


func test_currency_chips_and_top_bar() -> void:
	assert_eq(CurrencyChip.format_amount(0), "0")
	assert_eq(CurrencyChip.format_amount(999), "999")
	assert_eq(CurrencyChip.format_amount(1840), "1,840")
	assert_eq(CurrencyChip.format_amount(1000000), "1,000,000")
	assert_eq(CurrencyChip.format_amount(-12000), "-12,000")
	if not require_isolated():
		return
	var bar := TOP_BAR.instantiate() as TopBar
	bar.title = "Heroes"
	bar.show_leaves = false
	add_child(bar)
	var gold := bar.chip(PersistedData.GOLD)
	assert_eq(_text(gold, "Amount"), "0")
	PersistedData.add_currency(PersistedData.GOLD, 1840)
	assert_eq(_text(gold, "Amount"), "1,840", "live from PersistedData")
	assert_eq((_node(gold, "Icon") as TextureRect).texture, CurrencyChip.icon_for(PersistedData.GOLD))
	assert_false(bar.chip(PersistedData.LEAVES).visible, "the side's chips only")
	assert_true(bar.chip(PersistedData.STEEL).visible)
	bar.chip(PersistedData.STEEL).preview_amount = 5
	assert_eq(_text(bar.chip(PersistedData.STEEL), "Amount"), "5", "preview amount")
	assert_eq(_text(bar, "Title"), "Heroes")
	var pressed: Array = []
	bar.left_pressed.connect(func() -> void: pressed.append(true))
	(_node(bar, "Left") as Button).pressed.emit()
	assert_eq(pressed.size(), 1, "left_pressed")
