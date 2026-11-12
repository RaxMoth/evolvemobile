extends TestCase

## The character detail's texts and numbers (final walkthrough, menus):
##   - every node of every tree shows its whole sheet in English and German at
##     720x1280: the name, the rank line, Now / Next (wrapped), the capstone
##     rule, the gate's reason on its own line and the button's short text;
##     the sheet stays above the nav bar, the tree above the sheet, and in
##     English the sheet keeps its height so the tree does not jump;
##   - node names wrap onto a second line instead of ending in dots, a
##     selected node's name sits below its ring, capstone arches sit clear of
##     the row above, and ability tile names fit two lines;
##   - the overview's stat tiles show the base number and what the player's
##     own build adds, and those numbers are what a spawned hero or monster
##     has in a match (the menus and MetaSkillManager / MonsterBase agree),
##     whatever side is chosen;
##   - the tooltips and ability texts say what the code does.
## The screen lays out in a 720x1280 SubViewport. Tests that write the save
## run only in the isolated test user dir.

const DETAIL := preload("res://Scenes/UI/Screens/CharacterDetail.tscn")
const HEROES := MatchRewards.Side.HEROES
const MONSTER := MatchRewards.Side.MONSTER
const SCREEN := Vector2(720, 1280)
## Top edge of the nav bar's plaques (test_character_detail uses the same).
const NAV_TOP := 1280.0 - 120.0
## Permanent XP of level 8: every tier of a character tree is open.
const LEVEL_8_XP := 2800

var _viewport: SubViewport = null
var _locale := ""
## A line that is only a number and a short unit ("2 s", "15 %").
var _orphan := RegEx.create_from_string("^[-+]?[0-9.,]+ ?[^ ]{0,2}$")


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	if is_isolated():
		PersistedData.wipe_progress(false)


func after_each() -> void:
	if _viewport != null:
		_viewport.queue_free()
		_viewport = null
	TranslationServer.set_locale(_locale)
	if is_isolated():
		PersistedData.wipe_progress(false)


func _detail() -> CharacterDetail:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(SCREEN)
	add_child(_viewport)
	var screen := DETAIL.instantiate() as CharacterDetail
	_viewport.add_child(screen)
	return screen


func _def(id: StringName) -> CharacterDef:
	return GameManager.ROSTER.find(id)


## Every tree as [CharacterDef or null, side]: the roster's, then the two
## account-wide ones.
func _trees() -> Array[Array]:
	var out: Array[Array] = []
	for def in GameManager.ROSTER.all():
		out.append([def, -1])
	out.append([null, HEROES])
	out.append([null, MONSTER])
	return out


func _open(screen: CharacterDetail, entry: Array) -> String:
	var def := entry[0] as CharacterDef
	if def != null:
		screen.show_character(def, CharacterDetail.Mode.TREE)
		return String(def.character_id())
	screen.show_base_tree(entry[1])
	return "base %d" % entry[1]


## Every character at level 8 with an empty wallet.
func _level_everyone() -> void:
	for def in GameManager.ROSTER.all():
		if def.is_monster():
			PersistedData.add_monster_xp(def.character_id(), LEVEL_8_XP)
		else:
			PersistedData.add_hero_xp(def.character_id(), LEVEL_8_XP)


## Every rank of every shown node of every tree, and each tree's first
## capstone equipped.
func _max_everything() -> void:
	for tree_id: StringName in MetaSkillManager.trees:
		var t: MetaSkillTree = MetaSkillManager.get_tree_def(tree_id)
		for n in t.shown_nodes():
			PersistedData.set_skill_rank(tree_id, n.id, n.max_rank)
		var caps := t.capstones()
		if not caps.is_empty():
			PersistedData.set_equipped_capstone(tree_id, caps[0].id)
	MetaSkillManager.skills_changed.emit()


## Width of `text` as `control` draws it (its theme font and size).
func _text_width(control: Control, text: String) -> float:
	var font := control.get_theme_font(&"font")
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, control.get_theme_font_size(&"font_size")).x


## "" when the label shows its whole text, else what is cut.
func _cut(label: Label) -> String:
	if not label.is_visible_in_tree() or label.text.is_empty():
		return ""
	if label.get_visible_line_count() < label.get_line_count():
		return "%d of %d lines" % [label.get_visible_line_count(), label.get_line_count()]
	if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		var need := _text_width(label, label.atr(label.text))
		if need > label.size.x + 0.5:
			return "needs %.0f px, has %.0f" % [need, label.size.x]
	return ""


## "" when the button's text fits beside what else it holds, else what is cut.
func _cut_button(button: Button, taken: float = 0.0) -> String:
	if not button.is_visible_in_tree():
		return ""
	var room := button.size.x - button.get_theme_stylebox(&"normal").get_minimum_size().x - taken
	if button.icon != null:
		room -= minf(button.icon.get_width(), button.get_theme_constant(&"icon_max_width")) + button.get_theme_constant(&"h_separation")
	var need := _text_width(button, button.atr(button.text))
	return "" if need <= room + 0.5 else "needs %.0f px, has %.0f" % [need, room]


# ---------- the sheet ----------

## Walks every node of the open tree and checks its sheet; returns how many
## nodes it saw.
func _check_sheets(screen: CharacterDetail, tag: String, keeps_height: bool) -> int:
	var view := screen.tree_view()
	var sheet := screen.get_node("%Sheet") as Control
	var upgrade := screen.get_node("%Upgrade") as Button
	var cost := screen.get_node("%Cost") as Control
	var seen := 0
	for n in screen.model.nodes:
		view.select(n.id)
		await wait_frames(1)
		seen += 1
		var where := "%s/%s" % [tag, n.id]
		for path: String in ["%NodeName", "%NodeMeta", "%EffectNow", "%EffectNext", "%CapstoneNote", "%Reason"]:
			var label := screen.get_node(path) as Label
			assert_eq(_cut(label), "", "%s: %s shows '%s' in full" % [where, path, label.atr(label.text)])
		# F4's leftover: a wrapped effect line never leaves a number and its
		# unit alone on the last line (Last Stand's "2 s").
		for path: String in ["%EffectNow", "%EffectNext"]:
			var effect := screen.get_node(path) as Label
			if effect.is_visible_in_tree() and effect.get_line_count() > 1:
				var lines := _wrapped_lines(effect)
				assert_false(_orphan.search(lines[-1]) != null, "%s: %s does not end on '%s' alone" % [where, path, lines[-1]])
		assert_eq(_cut_button(upgrade, cost.size.x + 16.0 if cost.visible else 0.0), "", "%s: UPGRADE fits '%s'" % [where, upgrade.atr(upgrade.text)])
		assert_eq(_cut_button(screen.get_node("%Equip") as Button), "", "%s: EQUIP fits" % where)
		var sheet_rect := sheet.get_global_rect()
		var view_rect := view.get_global_rect()
		assert_true(sheet_rect.end.y <= NAV_TOP + 0.5, "%s: the sheet stays above the nav bar (%.0f)" % [where, sheet_rect.end.y])
		assert_true(view_rect.end.y <= sheet_rect.position.y + 0.5, "%s: the tree stays above the sheet" % where)
		if keeps_height:
			assert_near(sheet_rect.size.y, sheet.custom_minimum_size.y, 0.5, "%s: the sheet keeps its height (the tree does not jump)" % where)
		for b in view.buttons():
			var r := b.get_global_rect()
			assert_true(r.position.y >= view_rect.position.y - 0.5 and r.end.y <= view_rect.end.y + 0.5,
					"%s: %s stays inside the tree view" % [where, b.node_id])
	return seen


## Walkthrough problems 1 and 2 (review menus-3): at level 8 with nothing
## owned (Next lines, prerequisite and point gates, "Need n more") and with
## everything owned (Now lines, both capstone states), in both languages.
func test_every_node_shows_its_whole_sheet_in_english_and_german() -> void:
	if not require_isolated():
		return
	var screen := _detail()
	await wait_frames(1)
	_level_everyone()
	var total := 0
	for node_count in MetaSkillManager.trees.values().map(func(t: MetaSkillTree) -> int: return t.shown_nodes().size()):
		total += int(node_count)
	for pass_name: String in ["nothing owned", "everything owned"]:
		if pass_name == "everything owned":
			_max_everything()
		for locale: String in ["en", "de"]:
			TranslationServer.set_locale(locale)
			var seen := 0
			for entry in _trees():
				var tag := "%s, %s, %s" % [locale, pass_name, _open(screen, entry)]
				await wait_frames(2)
				seen += await _check_sheets(screen, tag, locale == "en")
			assert_eq(seen, total, "%s, %s: every node of every tree" % [locale, pass_name])
	assert_true(total >= 130, "all nine trees (%d nodes)" % total)


func test_a_closed_gate_explains_itself_on_its_own_line() -> void:
	if not require_isolated():
		return
	PersistedData.add_monster_xp(&"grount", LEVEL_8_XP)
	var screen := _detail()
	await wait_frames(1)
	screen.show_character(_def(&"grount"), CharacterDetail.Mode.TREE)
	await wait_frames(2)
	var view := screen.tree_view()
	var upgrade := screen.get_node("%Upgrade") as Button
	var reason := screen.get_node("%Reason") as Label
	view.select(&"g4_titan")
	await wait_frames(1)
	assert_eq(reason.text, "Needs Wider Slam or Gravity Slam or Scar Tissue", "the walkthrough's cut reason")
	assert_true(reason.visible and reason.autowrap_mode != TextServer.AUTOWRAP_OFF, "on a wrapping line")
	assert_eq(_cut(reason), "")
	assert_eq(upgrade.text, "LOCKED")
	assert_true(upgrade.disabled)
	assert_true(reason.get_global_rect().end.y <= upgrade.get_global_rect().position.y, "above the button")
	TranslationServer.set_locale("de")
	screen.refresh()
	await wait_frames(1)
	assert_eq(reason.text, "Benötigt: Breiterer Schlag oder Sogschlag oder Narbengewebe", "the names in German too")
	assert_eq(_cut(reason), "", "577 px on a 285 px button before")
	assert_eq(upgrade.atr(upgrade.text), "GESPERRT")
	screen.show_base_tree(HEROES)
	await wait_frames(2)
	view.select(&"t4_hp")
	await wait_frames(1)
	assert_eq(reason.text, "Noch 18 Punkte ausgeben", "a points gate")
	assert_eq(_cut(reason), "")


# ---------- the tree ----------

## Walkthrough problem 12: names wrap instead of ending in dots, the selected
## node's name clears its ring, and the arches clear the names above them.
func test_node_names_wrap_and_clear_the_ring_and_the_arches() -> void:
	if not require_isolated():
		return
	_level_everyone()
	var screen := _detail()
	await wait_frames(1)
	var wrapped := PackedStringArray()
	for locale: String in ["en", "de"]:
		TranslationServer.set_locale(locale)
		for entry in _trees():
			var tag := "%s, %s" % [locale, _open(screen, entry)]
			await wait_frames(2)
			var view := screen.tree_view()
			for b in view.buttons():
				var label := b.get_node("%NameLabel") as Label
				assert_true(label.get_line_count() <= 2 and label.get_visible_line_count() == label.get_line_count(),
						"%s: '%s' fits two lines (%d)" % [tag, label.text, label.get_line_count()])
				for line in label.get_line_count():
					assert_true(_line_width(label, line) <= label.size.x + 0.5, "%s: '%s' line %d fits its %d px" % [tag, label.text, line, int(label.size.x)])
				if label.get_line_count() == 2 and locale == "en":
					wrapped.append(label.text)
				var r := label.get_global_rect()
				assert_true(r.position.x >= 0.0 and r.end.x <= SCREEN.x + 0.5, "%s: '%s' inside the screen" % [tag, label.text])
				# The selected one (the sheet's node): its name starts below the ring.
				var name_top := label.position.y
				var ring_bottom := b.tile_size() + (SkillNodeButton.RING_OUT if b.is_selected() else 0.0)
				assert_true(name_top >= ring_bottom, "%s: '%s' below its %s" % [tag, label.text, "ring" if b.is_selected() else "tile"])
			# Rows: a capstone's arch ends below the one-line names of the tier above.
			var model := screen.model
			for n in model.nodes:
				if not n.capstone or n.tier < 2:
					continue
				var arch_top := view.node_center(n.id).y - SkillNodeButton.CAP_TILE * 0.5 - SkillNodeButton.ARCH_RISE
				for above in model.nodes:
					if above.tier != n.tier - 1:
						continue
					var name_bottom := view.node_center(above.id).y + SkillNodeButton.TILE * 0.5 + 1.0 + SkillNodeButton.NAME_H
					assert_true(arch_top >= name_bottom, "%s: the arch of %s (%.0f) clears the name of %s (%.0f)" % [tag, n.id, arch_top, above.id, name_bottom])
	for long_name: String in ["Marching Order", "Stunning Charge", "Sharpened Snares", "Disorienting Dive"]:
		assert_true(wrapped.has(long_name), "'%s' (cut with dots before) wraps onto two lines" % long_name)


## Review menus-1 (F4's leftover): a selected node's name steps below its
## ring, takes its second line and grows with the selection's scale. Under the
## last tier the view keeps room for it, so it ends above the sheet (a selected
## German two-line capstone name ran 14 px behind it), and a selected node
## draws above the others (a two-line name in the tier above a capstone ran
## under its arch). Every node of every tree, selected in turn, in English and
## German.
func test_a_selected_name_clears_the_sheet_and_the_arches() -> void:
	if not require_isolated():
		return
	_level_everyone()
	var screen := _detail()
	await wait_frames(1)
	var sheet := screen.get_node("%Sheet") as Control
	var two_line_capstones := PackedStringArray()
	for locale: String in ["en", "de"]:
		TranslationServer.set_locale(locale)
		for entry in _trees():
			var tag := "%s, %s" % [locale, _open(screen, entry)]
			await wait_frames(2)
			var view := screen.tree_view()
			var sheet_top := sheet.get_global_rect().position.y
			for n in screen.model.nodes:
				view.select(n.id)
				await wait_seconds(0.15)  # the selection's scale tween (0.12 s)
				var b := view.button(n.id)
				var label := b.get_node("%NameLabel") as Label
				# The label's box is two lines tall: its bottom is where a second
				# line ends.
				var bottom := (label.get_global_transform() * label.size).y
				assert_true(bottom <= sheet_top + 0.5, "%s: selected '%s' ends at %.1f, above the sheet (%.1f)" % [tag, label.text, bottom, sheet_top])
				assert_true(b.z_index > 0, "%s: selected %s draws above the other nodes" % [tag, n.id])
				if n.capstone and label.get_line_count() == 2:
					two_line_capstones.append(label.atr(label.text))
			view.select(&"")
			for b in view.buttons():
				assert_eq(b.z_index, 0, "%s: %s back in line once deselected" % [tag, b.node_id])
	for cap_name: String in ["Mitreißende Provokation", "Vampirische Wiedergeburt"]:
		assert_true(two_line_capstones.has(cap_name), "'%s' (behind the sheet before) is among them (%s)" % [cap_name, str(two_line_capstones)])


## The lines a wrapping label breaks its text into (at spaces, as it does).
func _wrapped_lines(label: Label) -> PackedStringArray:
	var lines := PackedStringArray()
	var current := ""
	for word in label.atr(label.text).split(" "):
		var candidate := word if current.is_empty() else current + " " + word
		if not current.is_empty() and _text_width(label, candidate) > label.size.x:
			lines.append(current)
			current = word
		else:
			current = candidate
	lines.append(current)
	return lines


## Width of one wrapped line of a label, measured with its own font.
func _line_width(label: Label, line: int) -> float:
	var text := label.atr(label.text)
	var words := text.split(" ")
	# The label breaks at spaces: rebuild the lines the same way.
	var lines := PackedStringArray()
	var current := ""
	for word in words:
		var candidate := word if current.is_empty() else current + " " + word
		if not current.is_empty() and _text_width(label, candidate) > label.size.x:
			lines.append(current)
			current = word
		else:
			current = candidate
	lines.append(current)
	return _text_width(label, lines[line]) if line < lines.size() else 0.0


func test_ability_tile_names_fit_two_lines() -> void:
	var screen := _detail()
	await wait_frames(1)
	var two_liners := PackedStringArray()
	for locale: String in ["en", "de"]:
		TranslationServer.set_locale(locale)
		for def in GameManager.ROSTER.all():
			screen.show_character(def)
			await wait_frames(2)
			for tile in screen.ability_tiles():
				if not tile.visible:
					continue
				var label := tile.get_node("%Name") as Label
				var shown := label.atr(label.text)
				assert_true(label.get_line_count() <= 2 and label.get_visible_line_count() == label.get_line_count(),
						"%s %s: '%s' shows in full (%d of %d lines)" % [locale, def.character_id(), shown, label.get_visible_line_count(), label.get_line_count()])
				var r := label.get_global_rect()
				var frame := tile.get_global_rect()
				assert_true(r.position.y >= (tile.get_node("%Kind") as Control).get_global_rect().end.y and r.end.y <= frame.end.y,
						"%s: '%s' inside its tile" % [locale, shown])
				if label.get_line_count() == 2:
					two_liners.append(shown)
	assert_true(two_liners.has("Emergency Supply Drop"), "River's ultimate (cut before) takes two lines")
	assert_true(two_liners.has("Monster-Provokation"), "Irelia's German ultimate (cut before) takes two lines")


# ---------- the overview's numbers ----------

func _row(rows: Array[Array], caption: String) -> Array:
	for row in rows:
		if row[2] == caption:
			return row
	return []


## Walkthrough problem 3: Irelia's tiles after Reinforced Plate 5/5,
## Unbreakable and Bulwark, plus Hero Base ranks.
func test_overview_tiles_show_what_the_owned_ranks_add() -> void:
	if not require_isolated():
		return
	var irelia := _def(&"irelia")
	var tree_id := irelia.skill_tree_id()
	var screen := _detail()
	await wait_frames(1)
	screen.show_character(irelia)
	await wait_frames(1)
	var tiles := screen.stat_tiles()
	assert_eq(tiles[0].value, "160")
	assert_eq(tiles[0].bonus, "", "nothing bought yet")
	PersistedData.set_skill_rank(tree_id, &"i1_hp", 5)       # +20% max HP
	PersistedData.set_skill_rank(tree_id, &"i2_hp", 1)       # +12%
	PersistedData.set_skill_rank(tree_id, &"i3_hp", 1)       # +20%
	PersistedData.set_skill_rank(tree_id, &"i1_dmg", 2)      # +8% attack damage
	PersistedData.set_skill_rank(tree_id, &"i1_speed", 3)    # +9% move speed
	PersistedData.set_skill_rank(tree_id, &"i2_atkspd", 1)   # +10% attack speed
	PersistedData.set_skill_rank(MetaSkillManager.TREE_HERO_BASE, &"t1_hp", 3)  # +10% max HP
	screen.refresh()  # what MenuRoot calls after a purchase
	assert_eq(tiles[0].value, "160", "the base number stays")
	assert_eq(tiles[0].bonus, "+%d" % roundi(160.0 * 1.2 * 1.12 * 1.2 * 1.1 - 160.0), "the four health nodes multiply")
	assert_eq(tiles[0].bonus, "+124")
	assert_true((tiles[0].get_node("%Bonus") as CanvasItem).visible)
	assert_eq((tiles[0].get_node("%Bonus") as Control).theme_type_variation, &"NextLabel", "in the sheet's green")
	assert_eq(tiles[1].value + " " + tiles[1].bonus, "5 +0.4", "a small stat keeps a tenth")
	assert_eq(tiles[2].value + " " + tiles[2].bonus, "0.67/s +0.07", "the basic attack recovers 10% faster")
	assert_eq(tiles[3].value + " " + tiles[3].bonus, "120 ", "no range node")
	assert_eq(tiles[4].value + " " + tiles[4].bonus, "75 +7")
	assert_eq(tiles[5].bonus, "", "no node changes the vision")
	# Veteran Squad: heroes start at level 2, one level of growth on top.
	PersistedData.set_skill_rank(MetaSkillManager.TREE_HERO_BASE, &"hb_startlvl", 1)
	screen.refresh()
	var stats := irelia.stats as HeroStats
	assert_eq(tiles[0].bonus, "+%d" % roundi((160.0 + stats.health_per_level) * 1.2 * 1.12 * 1.2 * 1.1 - 160.0), "the start level's growth counts")
	# Only the equipped capstone applies, and the monster's trees do not.
	PersistedData.set_skill_rank(MetaSkillManager.TREE_MONSTER_BASE, &"mt1_hp", 3)
	var before := tiles[0].bonus
	screen.refresh()
	assert_eq(tiles[0].bonus, before, "Monster Base does not reach a hero")
	for i in tiles.size():
		assert_true(tiles[i].size.x <= 220.5, "tile %d keeps its width (%.0f)" % [i, tiles[i].size.x])


## The overview's numbers are the ones a spawned hero has: the same ranks,
## stacked by the same MetaSkillManager code.
func test_overview_numbers_are_what_a_hero_spawns_with() -> void:
	if not require_isolated():
		return
	play_side(HEROES)
	for def in GameManager.ROSTER.heroes:
		var tree_id := def.skill_tree_id()
		var t := def.skill_tree_def()
		# Every stat node of the hero's tree at its top rank, its first capstone.
		for n in t.shown_nodes():
			if not n.capstone:
				PersistedData.set_skill_rank(tree_id, n.id, n.max_rank)
		PersistedData.set_skill_rank(tree_id, t.capstones()[0].id, 1)
		PersistedData.set_equipped_capstone(tree_id, t.capstones()[0].id)
	for n in MetaSkillManager.get_tree_def(MetaSkillManager.TREE_HERO_BASE).shown_nodes():
		PersistedData.set_skill_rank(MetaSkillManager.TREE_HERO_BASE, n.id, n.max_rank)
	for def in GameManager.ROSTER.heroes:
		var base := def.stats as HeroStats
		var hero := (await spawn_frozen(def.scene_path, Vector2.ZERO)) as HeroBase
		var live := hero.stats
		var owned := MetaSkillManager.owned_hero_stats(base)
		var id := def.character_id()
		assert_eq(owned.level, live.level, "%s: the start level" % id)
		assert_true(live.level == 2, "%s starts at level 2 with Veteran Squad" % id)
		assert_near(owned.get_max_health(), live.get_max_health(), 0.001, "%s max HP" % id)
		assert_near(owned.get_attack_damage(), live.get_attack_damage(), 0.001, "%s attack damage" % id)
		assert_near(owned.get_attack_range(), live.get_attack_range(), 0.001, "%s range" % id)
		assert_near(owned.get_move_speed(), live.get_move_speed(), 0.001, "%s move speed" % id)
		assert_near(owned.get_attack_speed_multiplier(), live.get_attack_speed_multiplier(), 0.001, "%s attack speed" % id)
		owned.free()
		var rows := CharacterDetail.stat_rows(def)
		assert_eq(_row(rows, "Health")[3], "+%d" % roundi(live.get_max_health() - base.base_max_health), "%s: the Health tile" % id)
		assert_eq(_row(rows, "Move speed")[3], "+%d" % roundi(live.get_move_speed() - base.base_move_speed), "%s: the Move speed tile" % id)
		# Review menus-2: Damage and Range against the spawn too (a dropped
		# range node passed before).
		assert_eq(_row(rows, "Damage")[3], CharacterDetail._bonus(base.base_attack_damage, live.get_attack_damage()), "%s: the Damage tile" % id)
		assert_eq(_row(rows, "Range")[3], CharacterDetail._bonus(base.base_attack_range, live.get_attack_range()), "%s: the Range tile" % id)
		if id in [&"river", &"ted"]:
			assert_true(String(_row(rows, "Range")[3]).begins_with("+"), "%s's range nodes show (%s)" % [id, _row(rows, "Range")[3]])
		var abilities := hero.get_node("AbilitySystem") as AbilitySystem
		var rate := live.get_attack_speed_multiplier() / abilities.basic_attack.cooldown
		assert_eq(_row(rows, "Attack speed")[3], "+%.2f" % snappedf(rate - 1.0 / def.ability_slots()[1].cooldown, 0.01), "%s: the Attack speed tile" % id)
		hero.queue_free()
		await wait_frames(2)


## The same for the monsters: MonsterBase's build_* numbers against a spawned
## monster at Stage I and Stage III, Titan Form and Apex Predator included.
func test_overview_numbers_are_what_a_monster_spawns_with() -> void:
	if not require_isolated():
		return
	play_side(MONSTER)
	for n in MetaSkillManager.get_tree_def(MetaSkillManager.TREE_MONSTER_BASE).shown_nodes():
		PersistedData.set_skill_rank(MetaSkillManager.TREE_MONSTER_BASE, n.id, n.max_rank)
	for def in GameManager.ROSTER.monsters:
		var tree_id := def.skill_tree_id()
		var t := def.skill_tree_def()
		for n in t.shown_nodes():
			if not n.capstone:
				PersistedData.set_skill_rank(tree_id, n.id, n.max_rank)
		# Grount's Hide capstone is Titan Form; the others take their first.
		var cap: StringName = &"g4_titan" if t.find_node(&"g4_titan") != null else t.capstones()[0].id
		PersistedData.set_skill_rank(tree_id, cap, 1)
		PersistedData.set_equipped_capstone(tree_id, cap)
	for def in GameManager.ROSTER.monsters:
		var stats := def.stats as MonsterStats
		var id := def.character_id()
		var mods := MetaSkillManager.owned_monster_modifiers(id)
		var m := (await spawn_frozen(def.scene_path, Vector2.ZERO)) as MonsterBase
		var basic := MetaSkillManager.owned_ability(def.skill_tree_id(), def.ability_slots()[1])
		basic.apply_stage_stats(1)
		assert_near(MonsterBase.build_max_health(stats, 1, mods), m.get_max_health(), 0.001, "%s max HP at Stage I" % id)
		assert_near(MonsterBase.build_move_speed(stats, 1, mods), m._get_move_speed(), 0.001, "%s move speed" % id)
		assert_eq(MonsterBase.build_evolution_xp(stats, 2, mods), m._get_next_evolution_threshold(), "%s XP to Stage II" % id)
		assert_near(MonsterBase.build_ability_damage(stats, basic, 1, mods), m.effective_ability_damage(m.ability_1), 0.001, "%s basic hit at Stage I" % id)
		var rows := CharacterDetail.stat_rows(def)
		assert_eq(_row(rows, "Health")[3], "+%d" % roundi(m.get_max_health() - stats.stage_1_health), "%s: the Health tile" % id)
		assert_eq(_row(rows, "Stage II")[3], "-%d" % (stats.stage_2_xp - m._get_next_evolution_threshold()), "%s: the Stage II tile" % id)
		assert_eq(_row(rows, "Move speed")[3], "+%d" % roundi(m._get_move_speed() - stats.stage_1_speed), "%s: the Move speed tile" % id)
		assert_true(String(_row(rows, "Damage")[3]).begins_with("+"), "%s: the Damage tile grows (%s)" % [id, _row(rows, "Damage")[3]])
		# Review menus-2: the exact bonus of one Stage I hit of the spawned
		# monster over the stock one (a tile built at another stage passed).
		var stock := def.ability_slots()[1].duplicate() as AbilityBase
		stock.apply_stage_stats(1)
		var stock_hit := MonsterBase.build_ability_damage(stats, stock, 1, {})
		assert_eq(_row(rows, "Damage")[1], CharacterDetail._number(stock_hit), "%s: the Damage tile's base is the stock hit" % id)
		assert_eq(_row(rows, "Damage")[3], CharacterDetail._bonus(stock_hit, m.effective_ability_damage(m.ability_1)), "%s: the Damage tile is the spawn's hit" % id)
		# Stage II: the threshold to Stage III; then Stage III itself.
		m.gain_xp(float(m._get_next_evolution_threshold()))
		assert_eq(m.current_stage, 2)
		assert_eq(MonsterBase.build_evolution_xp(stats, 3, mods), m._get_next_evolution_threshold(), "%s XP to Stage III" % id)
		m.gain_xp(10000.0)
		assert_eq(m.current_stage, 3)
		assert_near(MonsterBase.build_max_health(stats, 3, mods), m.get_max_health(), 0.001, "%s max HP at Stage III" % id)
		assert_eq(_row(rows, "Health at Stage III")[3], "+%s" % CurrencyChip.format_amount(roundi(m.get_max_health() - stats.stage_3_health)), "%s: the Stage III tile" % id)
		basic.apply_stage_stats(3)
		assert_near(MonsterBase.build_ability_damage(stats, basic, 3, mods), m.effective_ability_damage(m.ability_1), 0.001, "%s basic hit at Stage III (Apex Predator)" % id)
		await wait_seconds(0.7)  # the stage scale tween
		m.queue_free()
		await wait_frames(2)
	# Titan Form's flat HP is in Grount's Stage III tile, and only there.
	var grount := _def(&"grount")
	var g := grount.stats as MonsterStats
	var with_titan := MetaSkillManager.owned_monster_modifiers(&"grount")
	PersistedData.set_skill_rank(grount.skill_tree_id(), &"g4_rampage", 1)
	PersistedData.set_equipped_capstone(grount.skill_tree_id(), &"g4_rampage")
	var without := MetaSkillManager.owned_monster_modifiers(&"grount")
	assert_near(MonsterBase.build_max_health(g, 3, with_titan) - MonsterBase.build_max_health(g, 3, without), MonsterBase.TITAN_BONUS_HEALTH, 0.001, "only the equipped capstone counts")
	assert_near(MonsterBase.build_max_health(g, 2, with_titan), MonsterBase.build_max_health(g, 2, without), 0.001, "Titan Form starts at Stage III")
	# The overview shows the player's own monster, whatever side is chosen.
	var monster_side := str(CharacterDetail.stat_rows(grount))
	play_side(HEROES)
	assert_eq(str(CharacterDetail.stat_rows(grount)), monster_side, "the AI build never shows in the overview")


## Every character's tiles fit their third of the row with every rank owned,
## in both languages.
func test_overview_tiles_fit_with_everything_owned() -> void:
	if not require_isolated():
		return
	_max_everything()
	var screen := _detail()
	await wait_frames(1)
	for locale: String in ["en", "de"]:
		TranslationServer.set_locale(locale)
		for def in GameManager.ROSTER.all():
			screen.show_character(def)
			await wait_frames(2)
			var tiles := screen.stat_tiles()
			var bonuses := 0
			for i in tiles.size():
				var tag := "%s %s tile %d ('%s %s')" % [locale, def.character_id(), i, tiles[i].value, tiles[i].bonus]
				assert_true(tiles[i].size.x <= 220.5, "%s keeps its width (%.0f)" % [tag, tiles[i].size.x])
				assert_true(tiles[i].get_global_rect().end.x <= SCREEN.x - 15.5, "%s inside the screen" % tag)
				assert_eq(_cut(tiles[i].get_node("%Caption") as Label), "", "%s: its caption" % tag)
				bonuses += 0 if tiles[i].bonus.is_empty() else 1
			assert_true(bonuses >= 3, "%s %s: the build shows (%d tiles with a bonus)" % [locale, def.character_id(), bonuses])


# ---------- texts ----------

## Whole seconds without ".0", as the descriptions write them.
func _seconds(v: float) -> String:
	return String.num(v, 2).trim_suffix(".0")


## Walkthrough problem 15: a monster ability whose damage drops from one stage
## to the next says how often it is cast, so a stage never reads like a nerf.
func test_a_damage_drop_comes_with_its_cooldown() -> void:
	var checked := PackedStringArray()
	for def in GameManager.ROSTER.monsters:
		for ability in def.abilities():
			var dmg := ability.damage_per_stage
			var drops := false
			for stage in range(maxi(ability.unlock_stage, 1), dmg.size()):
				drops = drops or dmg[stage] < dmg[stage - 1]
			if not drops:
				continue
			checked.append(ability.ability_name)
			for stage in range(maxi(ability.unlock_stage, 1), dmg.size() + 1):
				var want := "Stage %d: %s" % [stage, _seconds(dmg[stage - 1])]
				assert_true(ability.description.contains(want), "%s names its Stage %d damage (%s)" % [ability.ability_name, stage, ability.description])
				var every := "every %s s" % _seconds(ability.cooldown_per_stage[stage - 1])
				assert_true(ability.description.contains(every), "%s says '%s' (%s)" % [ability.ability_name, every, ability.description])
	for expected: String in ["Front Cleave", "Ground Slam", "Sonic Screech"]:
		assert_true(checked.has(expected), "%s drops at a later stage" % expected)


## Review heroes-10 and monsters-11: four tooltips that disagreed with the code.
func test_tooltips_say_what_the_code_does() -> void:
	var bloodlust := _def(&"vlad").ability_slots()[0] as VladPassiveBloodlust
	assert_true(bloodlust.description.contains("up to +%d%% damage and +%d%% attack speed" % [
			roundi((bloodlust.max_damage_bonus - 1.0) * 100.0), roundi((bloodlust.max_attack_speed_bonus - 1.0) * 100.0)]),
			"Bloodlust is a ramp to its maximum (%s)" % bloodlust.description)
	assert_true(bloodlust.description.begins_with("Below %d%% health" % roundi(bloodlust.health_threshold * 100.0)))
	var adaptive := _def(&"river").ability_slots()[0] as RiverPassiveAdaptive
	var pct := roundi((adaptive.speed_boost_multiplier - 1.0) * 100.0)
	assert_true(adaptive.description.contains("%d%% movement speed and %d%% attack speed" % [pct, pct]),
			"Adaptive Movement also speeds her attacks (%s)" % adaptive.description)
	assert_true(adaptive.description.contains("%d seconds" % roundi(adaptive.boost_duration)))
	var dash := _def(&"grount").ability_slots()[2] as BullRamDash
	var trample := MetaSkillManager.get_tree_def(&"monster_grount").find_node(&"g4_stampede")
	assert_true(trample.effect_text(1).contains("within %d px of his path" % roundi(dash.trample_hit_radius)),
			"Trample's 70 px is a half width (%s)" % trample.effect_text(1))
	assert_false(trample.effect_text(1).contains("wide lane"))
	var herd := MetaSkillManager.get_tree_def(&"monster_gorrak").find_node(&"gk_warband")
	assert_true(herd.effect_text(1).contains("cast at a hero"), "Call of the Herd needs a hero as the target (%s)" % herd.effect_text(1))
	TranslationServer.set_locale("de")
	for text: String in [bloodlust.description, adaptive.description, trample.description, herd.description]:
		assert_true(String(TranslationServer.translate(text)) != text, "German: %s" % text)
	assert_true(trample.effect_text(1).contains("70 px") and trample.effect_text(1) != trample.description, "the sheet shows the German line")
	assert_true(herd.effect_text(1).contains("250 px") and herd.effect_text(1).contains("Helden"))
