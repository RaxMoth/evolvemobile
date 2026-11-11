extends TestCase

## German for the game's content (final walkthrough, menus problem 6; review
## menus-4, meta-5, heroes-11, menus-9). The English text is the key of every
## row in Assets/Locale/strings.csv, so:
##   - the CSV is well formed: key = English, a German text in every row, the
##     same placeholders in the same order, the same numbers, no German text
##     that is itself another row's key, and the imported translations say
##     what the CSV says;
##   - every content string the game data holds has a German row: the roster's
##     role lines, taglines, field notes, tips and stage names, every ability's
##     name and description, every tree's title, blurb, branches and every
##     node's name and effect text, the tutorial steps and the captions built
##     from ids. A new or edited English text fails here until its German row
##     follows (numbers included: test 1 compares them);
##   - the places that build a line themselves translate its parts (the tree
##     model, the Codex stage chips, the pre-round's evolution strip);
##   - in German no screen shows an English content text and no text is cut or
##     leaves the 720 px screen: the overview and tree of every character,
##     Growth, the Codex, the pre-round of both sides, the unlock sheet, the
##     rosters and the lobby (the skill sheet of every node is
##     test_detail_fit_and_stats' part);
##   - a language switch reaches what is on screen without a restart: the
##     lobby's unlock rules, the match HUD's stage and tally lines, the pause
##     menu's quit button and the tutorial's bubble.
## The screens lay out in a 720x1280 SubViewport. Tests that write the save
## run only in the isolated test user dir.

const CSV := "res://Assets/Locale/strings.csv"
const DETAIL := preload("res://Scenes/UI/Screens/CharacterDetail.tscn")
const CODEX := preload("res://Scenes/UI/Screens/CodexScreen.tscn")
const PRE_ROUND := preload("res://Scenes/UI/Screens/PreRoundScreen.tscn")
const ROSTER := preload("res://Scenes/UI/Screens/RosterScreen.tscn")
const UNLOCK_SHEET := preload("res://Scenes/UI/Components/UnlockSheet.tscn")
const MENU_ROOT := preload("res://Scenes/UI/Screens/MenuRoot.tscn")
const PAUSE_MENU := preload("res://Scenes/UI/Hud/PauseMenu.tscn")
const TUTORIAL := preload("res://Scenes/UI/Tutorial/TutorialOverlay.tscn")
const WORLD := "res://Scenes/World/World.tscn"
const HEROES := MatchRewards.Side.HEROES
const MONSTER := MatchRewards.Side.MONSTER
const SCREEN := Vector2(720, 1280)
## Top edge of the nav bar's plaques (test_character_detail uses the same).
const NAV_TOP := 1280.0 - 120.0
## Permanent XP of level 8: every tier of a character tree is open.
const LEVEL_8_XP := 2800
## Content texts that read the same in German (names and loan words).
const SAME_IN_GERMAN: PackedStringArray = ["Berserker", "Titan", "Stampede", "Riposte", "Hunger", "Tank", "Regeneration", "ULTIMATE"]
## The fewest content strings the data walk must find (338 when written).
const MIN_CONTENT := 330
## The lobby's sign: the game's name stays as it is (and holds the word HUNT).
const GAME_TITLE := "BETTER HUNT"

var _viewport: SubViewport = null
var _locale := ""
var _side_before: int = HEROES
var _world_before: PackedScene = null


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	_side_before = GameManager.chosen_side
	# A MenuRoot in the tree starts the background World load unless the
	# session already holds the scene (see test_menu_root).
	_world_before = GameManager.world_scene
	if is_isolated():
		PersistedData.wipe_progress(false)
		TutorialOverlay.mark_seen()


func after_each() -> void:
	if _viewport != null:
		_viewport.queue_free()
		_viewport = null
	TranslationServer.set_locale(_locale)
	GameManager.world_scene = _world_before
	GameManager.choose_side(_side_before, false)
	get_tree().paused = false
	if is_isolated():
		PersistedData.wipe_progress(false)


# ---------- helpers ----------

## strings.csv without its header: rows of [key, en, de].
func _rows() -> Array[PackedStringArray]:
	var out: Array[PackedStringArray] = []
	var csv := FileAccess.open(CSV, FileAccess.READ)
	assert_true(csv != null, "strings.csv opens")
	if csv == null:
		return out
	assert_eq(csv.get_csv_line(), PackedStringArray(["keys", "en", "de"]), "the header")
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		if row.size() == 1 and row[0].is_empty():
			continue  # the file's last line break
		out.append(row)
	csv.close()
	return out


## English text -> German text, from the CSV.
func _german() -> Dictionary[String, String]:
	var out: Dictionary[String, String] = {}
	for row in _rows():
		if row.size() == 3:
			out[row[0]] = row[2]
	return out


func _matches(pattern: String, text: String) -> PackedStringArray:
	var regex := RegEx.create_from_string(pattern)
	var out := PackedStringArray()
	for m in regex.search_all(text):
		out.append(m.get_string())
	return out


## Every content string of the game data as [where, text]; empty texts are
## left out (a hero has no stage names and no counterplay tip).
func _content() -> Array[Array]:
	var out: Array[Array] = []
	for def in GameManager.ROSTER.all():
		var id := String(def.character_id())
		out.append([id + " role", def.role_text])
		out.append([id + " tagline", def.tagline])
		out.append([id + " field notes", def.codex_notes])
		out.append([id + " tip", def.tip])
		for stage_name in def.stage_names:
			out.append([id + " stage name", stage_name])
		for ability in def.abilities():
			out.append([id + " ability name", ability.ability_name])
			out.append([id + " ability description", ability.description])
	for tree_id: StringName in MetaSkillManager.trees:
		var t: MetaSkillTree = MetaSkillManager.get_tree_def(tree_id)
		out.append(["%s title" % tree_id, t.display_name])
		out.append(["%s blurb" % tree_id, t.description])
		for branch_name in t.branches:
			out.append(["%s branch" % tree_id, branch_name])
		for n in t.nodes:
			out.append(["%s/%s name" % [tree_id, n.id], n.display_name])
			out.append(["%s/%s effect" % [tree_id, n.id], n.description])
	for chapter: StringName in [TutorialOverlay.CHAPTER_LOBBY, TutorialOverlay.CHAPTER_HUD]:
		for step in TutorialOverlay.steps_of(chapter):
			out.append(["tutorial %s title" % chapter, String(step.get("title", ""))])
			out.append(["tutorial %s body" % chapter, String(step.get("body", ""))])
	# Captions the code builds from ids or keeps in constants.
	var roster := ROSTER.instantiate() as RosterScreen
	var filter_keys: Array[StringName] = roster.filters.duplicate()
	roster.free()
	for def in GameManager.ROSTER.all():
		if not filter_keys.has(def.role_filter):
			filter_keys.append(def.role_filter)
	for key in filter_keys:
		out.append(["roster filter", String(key).capitalize()])
	for kind in CharacterDetail.SLOT_KINDS:
		out.append(["ability slot kind", kind])
	for i in range(1, MonsterHudPanel.STAGE_NAMES.size()):
		out.append(["HUD stage name", MonsterHudPanel.STAGE_NAMES[i]])
	for intent_name in MonsterHudPanel.INTENT_NAMES:
		out.append(["HUD intent", intent_name])
	return out.filter(func(entry: Array) -> bool: return not String(entry[1]).is_empty())


func _def(id: StringName) -> CharacterDef:
	return GameManager.ROSTER.find(id)


func _mount(screen: Control) -> void:
	_mount_node(screen)


## Adds `node` (a screen, or an overlay's CanvasLayer) to the 720x1280 viewport.
func _mount_node(node: Node) -> void:
	if _viewport == null:
		_viewport = SubViewport.new()
		_viewport.size = Vector2i(SCREEN)
		add_child(_viewport)
	_viewport.add_child(node)


func _unmount(screen: Control) -> void:
	_viewport.remove_child(screen)
	screen.queue_free()


## Every character at level 8, every monster owned and met, and a full wallet.
func _own_everything() -> void:
	for def in GameManager.ROSTER.all():
		if def.is_monster():
			PersistedData.add_monster_xp(def.character_id(), LEVEL_8_XP)
			PersistedData.add_owned_monster(def.character_id())
			PersistedData.add_codex_entry(PersistedData.CODEX_MONSTERS, def.character_id())
		else:
			PersistedData.add_hero_xp(def.character_id(), LEVEL_8_XP)


## What a Label or Button draws: its text in the current language.
func _shown(control: Control) -> String:
	var label := control as Label
	if label != null:
		var text := String(label.atr(label.text))
		return text.to_upper() if label.uppercase else text
	var button := control as Button
	return String(button.atr(button.text)) if button != null else ""


## The visible Labels and Buttons below `root` that show a text.
func _text_controls(root: Node, out: Array[Control] = []) -> Array[Control]:
	for child in root.get_children():
		var item := child as CanvasItem
		if item != null and not item.is_visible_in_tree():
			continue
		var control := child as Control
		if (control is Label or control is Button) and not _shown(control).is_empty():
			out.append(control)
		_text_controls(child, out)
	return out


func _width(control: Control, text: String) -> float:
	return control.get_theme_font(&"font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, control.get_theme_font_size(&"font_size")).x


## "" when the label shows its whole text, else what is cut: lines that do
## not show, a line wider than a label that does not wrap, or a word wider
## than a label that does (it would break inside the word).
func _cut(label: Label) -> String:
	if label.get_visible_line_count() < label.get_line_count():
		return "%d of %d lines" % [label.get_visible_line_count(), label.get_line_count()]
	var pieces := PackedStringArray()
	for line in _shown(label).split("\n"):
		if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
			pieces.append(line)
			continue
		for word in line.split(" "):
			# A label may also break after a hyphen.
			var parts := word.split("-")
			for i in parts.size():
				pieces.append(parts[i] + ("-" if i < parts.size() - 1 else ""))
	for piece in pieces:
		var need := _width(label, piece)
		if need > label.size.x + 0.5:
			return "'%s' needs %.0f px, has %.0f" % [piece, need, label.size.x]
	return ""


## "" when the button's text fits beside its icon (an icon above the text, as
## on the nav tabs, takes no width). The UPGRADE button's price chip is
## test_detail_fit_and_stats' part.
func _cut_button(button: Button) -> String:
	var room := button.size.x - button.get_theme_stylebox(&"normal").get_minimum_size().x
	if button.icon != null and button.vertical_icon_alignment == VERTICAL_ALIGNMENT_CENTER:
		room -= minf(button.icon.get_width(), button.get_theme_constant(&"icon_max_width")) + button.get_theme_constant(&"h_separation")
	var need := _width(button, _shown(button))
	return "" if need <= room + 0.5 else "needs %.0f px, has %.0f" % [need, room]


## English content texts whose German differs, with their upper-case forms
## (plaques, toasts): what must not show on a German screen.
func _english_only() -> PackedStringArray:
	var german := _german()
	var out := PackedStringArray()
	for entry in _content():
		var en := String(entry[1])
		if german.get(en, en) == en or out.has(en):
			continue
		out.append(en)
		if en.to_upper() != en and en.to_upper() != String(german[en]).to_upper():
			out.append(en.to_upper())
	return out


## The English content text `shown` still holds as a whole word or phrase, or "".
func _english_in(shown: String, english: PackedStringArray, german: Dictionary[String, String]) -> String:
	# A line that is a key shows that key's German: only a line built from
	# parts can carry an untranslated one.
	if german.has(shown) and german[shown] != shown:
		return shown
	for en in english:
		var at := shown.find(en)
		while at >= 0:
			var before := shown.substr(at - 1, 1) if at > 0 else " "
			var after := shown.substr(at + en.length(), 1) if at + en.length() < shown.length() else " "
			if not _is_letter(before) and not _is_letter(after):
				return en
			at = shown.find(en, at + 1)
	return ""


func _is_letter(c: String) -> bool:
	return c.to_upper() != c.to_lower()


## Checks every text of `root`: nothing cut, inside the screen's width, and in
## German no English content. Returns how many texts it saw.
func _check_screen(root: Node, tag: String, english: PackedStringArray, german: Dictionary[String, String]) -> int:
	var controls := _text_controls(root)
	var in_german := TranslationServer.get_locale() == "de"
	for control in controls:
		var shown := _shown(control)
		var where := "%s: %s '%s'" % [tag, control.name, shown.left(60)]
		var rect := control.get_global_rect()
		assert_true(rect.position.x >= -0.5 and rect.end.x <= SCREEN.x + 0.5, "%s inside the screen (%.0f..%.0f)" % [where, rect.position.x, rect.end.x])
		if control is Label:
			assert_eq(_cut(control as Label), "", "%s shows in full" % where)
		else:
			assert_eq(_cut_button(control as Button), "", "%s fits its button" % where)
		if in_german and shown != GAME_TITLE:
			assert_eq(_english_in(shown, english, german), "", "%s: no English left" % where)
	return controls.size()


# ---------- the CSV ----------

func test_every_row_has_german_with_the_same_placeholders_and_numbers() -> void:
	var rows := _rows()
	assert_true(rows.size() >= 500, "the content rows are in (%d rows)" % rows.size())
	var german: Dictionary[String, String] = {}
	for row in rows:
		assert_eq(row.size(), 3, "three columns: %s" % str(row))
		if row.size() != 3:
			continue
		var en := row[1]
		var de := row[2]
		assert_eq(row[0], en, "the key is the English text")
		assert_false(german.has(en), "one row per key: %s" % en)
		assert_false(de.strip_edges().is_empty(), "German for: %s" % en)
		# GDScript's % fills placeholders by position, {v} is the rank's value.
		assert_eq(_matches("%(?:\\.\\d+)?[dsf]|%%|\\{v\\}", de), _matches("%(?:\\.\\d+)?[dsf]|%%|\\{v\\}", en), "the same placeholders in order: %s | %s" % [en, de])
		var en_numbers := Array(_matches("\\d+(?:\\.\\d+)?", en))
		var de_numbers := Array(_matches("\\d+(?:\\.\\d+)?", de))
		en_numbers.sort()
		de_numbers.sort()
		assert_eq(de_numbers, en_numbers, "the same numbers: %s | %s" % [en, de])
		german[en] = de
	# A German text that a Label translates once more must stay as it is.
	for en: String in german:
		var de := german[en]
		assert_true(not german.has(de) or german[de] == de, "'%s' -> '%s' is not itself a key with another German" % [en, de])
	# The imported translations say what the CSV says.
	for locale: String in ["en", "de"]:
		TranslationServer.set_locale(locale)
		var stale := PackedStringArray()
		for en: String in german:
			if String(TranslationServer.translate(en)) != (en if locale == "en" else german[en]):
				stale.append(en)
		assert_eq(stale, PackedStringArray(), "%s: strings.%s.translation matches strings.csv (tools/build_locale.sh)" % [locale, locale])


func test_every_content_string_has_a_german_row() -> void:
	var german := _german()
	var content := _content()
	var seen: Dictionary[String, bool] = {}
	for entry in content:
		var where := String(entry[0])
		var en := String(entry[1])
		seen[en] = true
		assert_true(german.has(en), "%s has a row in strings.csv: %s" % [where, en])
		if not german.has(en):
			continue
		assert_false(german[en].strip_edges().is_empty(), "%s has German: %s" % [where, en])
		if not SAME_IN_GERMAN.has(en):
			assert_true(german[en] != en, "%s is translated, not copied: %s" % [where, en])
	assert_true(seen.size() >= MIN_CONTENT, "the walk finds the content (%d strings)" % seen.size())
	# The walk reaches every kind of text.
	for sample: String in ["Tank · Leader", "Bullcalf", "Force the monster to attack Irelia for 5 seconds", "Hero Base Upgrades",
			"Bulwark", "Iron Skin", "+{v}% max HP", "The Codex", "Brute", "ULTIMATE", "DANGEROUS"]:
		assert_true(seen.has(sample), "the walk covers '%s'" % sample)
	TranslationServer.set_locale("de")
	assert_eq(String(TranslationServer.translate("Iron Skin")), "Eisenhaut")
	assert_eq(String(TranslationServer.translate("Tank · Leader")), "Tank · Anführerin")


# ---------- the places that build a line ----------

func test_the_tree_model_is_in_the_current_language() -> void:
	if not require_isolated():
		return
	PersistedData.add_monster_xp(&"grount", LEVEL_8_XP)
	var tree_id := MetaSkillManager.monster_tree_id(&"grount")
	var m := UxTreeModel.from_ranked_manager(tree_id)
	assert_eq(m.title, "Grount — Alpha Bull")
	assert_eq(m.branches, PackedStringArray(["Horns", "Hide", "Charge"]))
	assert_eq(m.find(&"g3_slam").name, "Wider Slam")
	assert_eq(m.block_reason(m.find(&"g4_titan")), "Needs Wider Slam or Gravity Slam or Scar Tissue")
	TranslationServer.set_locale("de")
	m = UxTreeModel.from_ranked_manager(tree_id)
	assert_eq(m.title, "Grount — Alphastier")
	assert_eq(m.description, "Grounts persönliche Verbesserungen. Mit Blättern gekauft.")
	assert_eq(m.branches, PackedStringArray(["Hörner", "Haut", "Ansturm"]))
	assert_eq(m.find(&"g3_slam").name, "Breiterer Schlag")
	assert_eq(m.find(&"g3_slam").effect_at(1), "Bodenschlag: +20% Radius", "the value is filled into the German line")
	assert_eq(m.find(&"g1_stun").effect_at(1), "Rammsturm betäubt für 0.5 s")
	assert_eq(m.block_reason(m.find(&"g4_titan")), "Benötigt: Breiterer Schlag oder Sogschlag oder Narbengewebe",
			"the walkthrough's mixed line ('Benötigt Wider Slam oder ...')")
	var base := UxTreeModel.from_ranked_manager(MetaSkillManager.TREE_HERO_BASE)
	assert_eq(base.title, "Basisverbesserungen der Helden")
	assert_eq(base.find(&"t1_hp").effect_at(3), "+10% max. LP")
	assert_eq(base.find(&"hb_startlvl").effect_at(1), "Helden beginnen jede Partie auf Level 2")
	# The detail screen's sheet shows the model's words.
	var screen := DETAIL.instantiate() as CharacterDetail
	_mount(screen)
	await wait_frames(1)
	screen.show_character(_def(&"irelia"), CharacterDetail.Mode.TREE)
	await wait_frames(2)
	screen.tree_view().select(&"ir_laststand")
	await wait_frames(1)
	assert_eq((screen.get_node("%NodeName") as Label).text, "Letztes Gefecht")
	assert_eq((screen.get_node("%NodeMeta") as Label).text, "Rang 0/1 · Bollwerk · Ebene 4 · Schlussstein")
	assert_eq((screen.get_node("%EffectNext") as Label).text,
			"Als Nächstes: Einmal pro Partie überlebt Irelia einen tödlichen Treffer mit 1 LP und ist 2 s lang unverwundbar")
	var plaques := PackedStringArray()
	for plaque in screen.tree_view().branch_plaques():
		plaques.append((plaque.get_child(0) as Label).text)
	assert_eq(plaques, PackedStringArray(["BOLLWERK", "EIDWAHRERIN", "VORHUT"]))


func test_stage_names_are_translated_where_a_line_is_built() -> void:
	if not require_isolated():
		return
	_own_everything()
	TranslationServer.set_locale("de")
	var codex := CODEX.instantiate() as CodexScreen
	_mount(codex)
	codex.open()
	await wait_frames(2)
	var grount: CodexEntry = null
	for entry in codex.monster_entries():
		if entry.character == _def(&"grount"):
			grount = entry
	assert_true(grount != null, "Grount has a page")
	assert_eq(grount.stage_texts(), PackedStringArray(["I · Stierkalb", "II · Wüterich", "III · Alphastier"]))
	var role := grount.get_node("%Role") as Label
	assert_eq(String(role.atr(role.text)), "Koloss · Der Stier", "a Label translates a text that is a key")
	var notes := grount.get_node("%Notes") as Label
	assert_true(String(notes.atr(notes.text)).begins_with("Beginnt als Kalb"))
	_unmount(codex)
	var pre_round := PRE_ROUND.instantiate() as PreRoundScreen
	_mount(pre_round)
	GameManager.choose_monster(&"nyxa")
	pre_round.open(MONSTER)
	await wait_frames(2)
	assert_eq((pre_round.get_node("%EvoName3") as Label).text, "Stufe III\nDämmermatriarchin")
	var monster_role := pre_round.get_node("%MonsterRole") as Label
	assert_eq(String(monster_role.atr(monster_role.text)), "Pirscherin · Die Fledermaus")


# ---------- the screens in German ----------

## The overview of every character with each ability's description open, and
## its tree; Growth's two trees.
func test_german_detail_screens_show_no_english_and_cut_nothing() -> void:
	if not require_isolated():
		return
	_own_everything()
	var german := _german()
	var english := _english_only()
	var screen := DETAIL.instantiate() as CharacterDetail
	_mount(screen)
	await wait_frames(1)
	for locale: String in ["en", "de"]:
		TranslationServer.set_locale(locale)
		var texts := 0
		for def in GameManager.ROSTER.all():
			var id := String(def.character_id())
			screen.show_character(def)
			await wait_frames(2)
			for tile in screen.ability_tiles():
				tile.button_pressed = true
				await wait_frames(2)
				var tag := "%s overview %s, ability %d" % [locale, id, tile.index]
				texts += _check_screen(screen, tag, english, german)
				var overview := screen.get_node("%Overview") as Control
				assert_true(overview.get_global_rect().end.y <= NAV_TOP + 0.5, "%s: the description ends above the nav bar (%.0f)" % [tag, overview.get_global_rect().end.y])
			screen.show_character(def, CharacterDetail.Mode.TREE)
			await wait_frames(2)
			texts += _check_screen(screen, "%s tree %s" % [locale, id], english, german)
		for side: int in [HEROES, MONSTER]:
			screen.show_base_tree(side)
			await wait_frames(2)
			texts += _check_screen(screen, "%s growth %d" % [locale, side], english, german)
			var header := screen.get_node("%Header") as Control
			var tabs := screen.get_node("%SideTabs") as Control
			assert_true(header.get_global_rect().end.y <= tabs.get_global_rect().position.y + 0.5, "%s growth %d: the header ends above the side tabs" % [locale, side])
		assert_true(texts > 1000, "%s: the screens were read (%d texts)" % [locale, texts])


func test_german_codex_pre_round_and_sheets_show_no_english_and_cut_nothing() -> void:
	if not require_isolated():
		return
	var german := _german()
	var english := _english_only()
	for locale: String in ["en", "de"]:
		TranslationServer.set_locale(locale)
		PersistedData.wipe_progress(false)
		PersistedData.add_currency(PersistedData.LEAVES, 100)
		# The unlock sheet of the monsters still to buy.
		var sheet := UNLOCK_SHEET.instantiate() as UnlockSheet
		_mount(sheet)
		for id: StringName in [&"nyxa", &"gorrak"]:
			sheet.open_for(_def(id))
			await wait_seconds(UnlockSheet.SLIDE_TIME + 0.1)
			assert_true(_check_screen(sheet, "%s unlock %s" % [locale, id], english, german) >= 5)
			sheet.close()
			await wait_seconds(UnlockSheet.SLIDE_TIME + 0.1)
		_unmount(sheet)
		_own_everything()
		# The Codex: the guide, every monster's page and every hero's.
		var codex := CODEX.instantiate() as CodexScreen
		_mount(codex)
		codex.open()
		for page: StringName in [CodexScreen.PAGE_GUIDE, CodexScreen.PAGE_MONSTERS, CodexScreen.PAGE_HEROES]:
			codex.show_page(page)
			await wait_frames(3)
			assert_true(_check_screen(codex, "%s codex %s" % [locale, page], english, german) >= 20)
		for entry in codex.monster_entries() + codex.hero_entries():
			var row := entry.get_node("%Stages") as Control
			if row.is_visible_in_tree():
				assert_true(row.get_global_rect().end.x <= entry.get_global_rect().end.x, "%s codex %s: the stage chips stay on the page" % [locale, entry.character.character_id()])
		_unmount(codex)
		# The pre-round: every quarry with its sheet, every own monster.
		var pre_round := PRE_ROUND.instantiate() as PreRoundScreen
		_mount(pre_round)
		pre_round.open(HEROES)
		for def in GameManager.ROSTER.monsters:
			pre_round._show_quarry(def)
			await wait_frames(2)
			assert_true(_check_screen(pre_round, "%s pre-round quarry %s" % [locale, def.character_id()], english, german) >= 20)
		pre_round.open_sheet()
		await wait_seconds(PreRoundScreen.SHEET_TIME + 0.1)
		_check_screen(pre_round.get_node("%QuarrySheet"), "%s pre-round quarry sheet" % locale, english, german)
		pre_round.open(MONSTER)
		for def in GameManager.ROSTER.monsters:
			pre_round._show_monster(def)
			await wait_frames(2)
			assert_true(_check_screen(pre_round, "%s pre-round monster %s" % [locale, def.character_id()], english, german) >= 10)
		_unmount(pre_round)
		# The rosters.
		for side: int in [HEROES, MONSTER]:
			var roster := ROSTER.instantiate() as RosterScreen
			roster.side = side
			_mount(roster)
			roster.open()
			await wait_seconds(0.6)
			_check_screen(roster, "%s roster %d" % [locale, side], english, german)
			_unmount(roster)


# ---------- a language switch ----------

## Review menus-9: the lobby's unlock rules were formatted once and stayed in
## the old language under an otherwise German lobby.
func test_a_language_switch_reaches_the_lobby() -> void:
	if not require_isolated():
		return
	if GameManager.world_scene == null:
		GameManager.world_scene = PackedScene.new()
	var root := MENU_ROOT.instantiate() as MenuRoot
	_mount(root)
	await wait_frames(2)
	var rules: Array[Label] = []
	for label in _text_controls(root.lobby):
		if label.name == &"Rule":
			rules.append(label as Label)
	assert_eq(rules.size(), 2, "Nyxa and Gorrak wait behind their rule")
	for rule in rules:
		assert_eq(rule.text, "Needs a Lv 3 monster")
	LocaleSettings.apply_choice("de")  # what the settings sheet's picker calls
	await wait_frames(2)
	for rule in rules:
		assert_eq(rule.text, "Benötigt Lv-3-Monster", "the rule follows without a restart")
	var german := _german()
	_check_screen(root.lobby, "de lobby", _english_only(), german)
	LocaleSettings.apply_choice("en")
	await wait_frames(2)
	for rule in rules:
		assert_eq(rule.text, "Needs a Lv 3 monster", "and back")


## The pause menu's settings switch the language in a match: the monster
## panel's stage, evolve and tally lines and the tracker's stage follow.
func test_a_language_switch_reaches_the_match_hud() -> void:
	for side: int in [MONSTER, HEROES]:
		GameManager.chosen_side = side
		var world := (load(WORLD) as PackedScene).instantiate()
		add_child(world)
		var hud := (world.get_node("MainCam") as GameCamera).hud
		for i in range(60):
			if hud.is_processing():
				break
			await wait_frames(1)
		GameManager.match_ended_flag = true
		var panel := hud.get_node(^"%MonsterPanel") as MonsterHudPanel
		var stage := panel.get_node(^"%StageText") as Label
		var tally := panel.get_node(^"%Tally") as Label
		var evo := panel.get_node(^"%EvoText") as Label
		var enemy_stage := hud.get_node(^"%EnemyStage") as Label
		if side == MONSTER:
			panel._refresh()
			assert_eq(stage.text, "STAGE I · VULNERABLE")
			assert_true(tally.text.begins_with("Heroes slain  0 / 4"))
			assert_true(evo.text.begins_with("EVOLVE  0 / "))
		else:
			assert_eq(enemy_stage.text, "STAGE I")
		# The tree is paused while the settings are open: nothing polls.
		get_tree().paused = true
		TranslationServer.set_locale("de")
		if side == MONSTER:
			assert_eq(stage.text, "STUFE I · VERWUNDBAR", "written again at once, on the paused tree")
			assert_true(tally.text.begins_with("Helden erlegt  0 / 4"))
			assert_true(evo.text.begins_with("ENTWICKLUNG  0 / "))
			var intent := panel.get_node(^"%Intent") as Label
			assert_eq(intent.text, String(TranslationServer.translate(MonsterHudPanel.INTENT_NAMES[panel.current_intent()])))
		else:
			assert_eq(enemy_stage.text, "STUFE I")
		TranslationServer.set_locale("en")
		assert_eq(stage.text if side == MONSTER else enemy_stage.text, "STAGE I · VULNERABLE" if side == MONSTER else "STAGE I", "and back")
		get_tree().paused = false
		world.queue_free()
		await wait_frames(2)
		AudioManager.stop_music()


func test_the_pause_menus_quit_button_follows_the_language() -> void:
	var menu := PAUSE_MENU.instantiate() as PauseMenu
	menu.changes_scene = false
	add_child(menu)
	menu.open()
	var quit := menu.get_node("%Quit") as ConfirmButton
	quit.pressed.emit()
	assert_eq(String(quit.atr(quit.text)), "Tap again to leave")
	TranslationServer.set_locale("de")
	assert_eq(String(quit.atr(quit.text)), "Zum Verlassen erneut tippen", "armed in English, read in German")
	quit.disarm()
	assert_eq(String(quit.atr(quit.text)), "Zur Lobby")
	TranslationServer.set_locale("en")
	assert_eq(String(quit.atr(quit.text)), "Quit to lobby", "disarmed in German, read in English")
	menu.resume()


## Opened in German and read in English: the bubble's controls hold keys, not
## translated lines. Every step of both chapters fits its bubble in German.
func test_the_tutorial_follows_the_language_and_fits_in_german() -> void:
	if not require_isolated():
		return
	var german := _german()
	var english := _english_only()
	TranslationServer.set_locale("de")
	for chapter: StringName in [TutorialOverlay.CHAPTER_LOBBY, TutorialOverlay.CHAPTER_HUD]:
		var overlay := TUTORIAL.instantiate() as TutorialOverlay
		overlay.chapter = chapter
		_mount_node(overlay)
		await wait_frames(2)
		var steps := TutorialOverlay.steps_of(chapter)
		for i in steps.size():
			await wait_frames(2)
			assert_eq(_shown(overlay.title_label), german[String(steps[i].get("title"))], "%s step %d in German" % [chapter, i + 1])
			assert_true(_check_screen(overlay, "de tutorial %s step %d" % [chapter, i + 1], english, german) >= 5)
			if i < steps.size() - 1:
				overlay.next_button.pressed.emit()
		assert_eq(_shown(overlay.next_button), "Verstanden")
		TranslationServer.set_locale("en")
		assert_eq(_shown(overlay.title_label), String(steps[-1].get("title")), "%s: the open step follows the switch" % chapter)
		assert_eq(_shown(overlay.body_label), String(steps[-1].get("body")))
		assert_eq(_shown(overlay.next_button), "Got it")
		assert_eq(_shown(overlay.get_node("%Kicker") as Label), "FIRST HUNT" if chapter == TutorialOverlay.CHAPTER_HUD else "HOW TO PLAY")
		TranslationServer.set_locale("de")
		_viewport.remove_child(overlay)
		overlay.queue_free()
