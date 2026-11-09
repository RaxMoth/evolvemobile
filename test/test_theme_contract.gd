extends TestCase

## The Jungle Guild theme (Scenes/UI/Theme/ui_theme.tres, written by
## tools/art/make_theme.py) is the one theme of every screen: the project
## setting gui/theme/custom points at it, every theme_type_variation a scene
## or UI script names exists in it, every StyleBoxTexture resolves, display
## text is Lilita One with the engine font behind it for missing glyphs, the
## variations the Phase 3-5 screens need exist, and the UX prototype's names
## for looks the art set already has stay out (art names are canonical).

const THEME_PATH := "res://Scenes/UI/Theme/ui_theme.tres"
const DISPLAY_FONT := "res://Assets/Fonts/LilitaOne-Regular.ttf"
const FONT_LICENCE := "res://Assets/Fonts/LilitaOne-OFL.txt"
const STRINGS_CSV := "res://Assets/Locale/strings.csv"
## Folders whose scenes and scripts may name a theme_type_variation.
const SCAN_DIRS: Array[String] = ["res://Scenes", "res://Scripts"]
## Variations for the skill tree, pre-round, lobby and detail screens, with
## the type each one extends.
const SCREEN_VARIATIONS: Dictionary[String, String] = {
	"NodeTile": "PanelContainer", "BadgeReady": "PanelContainer",
	"GutterPlaque": "PanelContainer", "GutterPlaqueLocked": "PanelContainer",
	"NodeName": "Label", "NodeNameLocked": "Label", "GutterCaption": "Label", "GutterCaptionLocked": "Label",
	"GutterNumber": "Label", "GutterNumberLocked": "Label", "NowLabel": "Label", "NextLabel": "Label",
	"PipOn": "PanelContainer", "PipOff": "PanelContainer", "PipMax": "PanelContainer",
	"BranchPlaque": "PanelContainer", "SheetPanel": "PanelContainer",
	"ChipPanel": "PanelContainer", "SelectRing": "PanelContainer",
	"FrameHero": "PanelContainer", "FrameMonster": "PanelContainer",
	"EvoBar": "ProgressBar", "TabButton": "Button", "FlatButton": "Button",
	"BigNumberLabel": "Label", "HintLabel": "Label", "AmberLabel": "Label",
}
## UX prototype name -> the art name that replaces it (make_theme.py).
const UX_RENAMES: Dictionary[String, String] = {
	"CardPanel": "CharacterCard", "CardSelected": "CharacterCardSelected",
	"CardLocked": "CharacterCardLocked", "PrimaryButton": "ButtonPrimary",
	"MonsterButton": "ButtonMonster", "MossButton": "ButtonHero", "FilterButton": "FilterTab",
	"LevelLabel": "CardLevel", "PillPanel": "Pill", "HpBar": "HpBarHero",
	"MonsterHpBar": "HpBarMonster", "HudCard": "HudPanel", "HudCardSelected": "HudPanelSelected",
	"TitleLabel": "HeaderLarge", "HeaderLabel": "HeaderSmall", "MutedLabel": "Caption",
	"SmallLabel": "BodyDim",
}
## Display text (Lilita One): levels, headers, banners, counters, cooldown
## numbers, nav labels, buttons.
const DISPLAY_TYPES: Array[String] = [
	"CardLevel", "PillText", "HeaderLarge", "HeaderSmall", "BannerTitle", "Counter",
	"CooldownNumber", "NavLabel", "DangerLabel", "BigNumberLabel", "AmberLabel",
	"Button", "ButtonPrimary", "ButtonCopper", "ButtonHero", "ButtonMonster",
	"NavPlaque", "NavArch", "ProgressBar", "HpBarHero",
]
## Small body text (the emboldened engine font).
const BODY_TYPES: Array[String] = ["Label", "CardName", "Caption", "BodyDim", "TooltipLabel", "HintLabel"]


func _theme() -> Theme:
	return load(THEME_PATH) as Theme


func _files(dir_path: String, exts: Array[String], out: Array[String]) -> void:
	for sub: String in DirAccess.get_directories_at(dir_path):
		_files(dir_path.path_join(sub), exts, out)
	for f: String in DirAccess.get_files_at(dir_path):
		if f.get_extension() in exts:
			out.append(dir_path.path_join(f))


func test_the_project_theme_is_ui_theme() -> void:
	assert_eq(ProjectSettings.get_setting("gui/theme/custom", ""), THEME_PATH, "gui/theme/custom")
	var project_theme := ThemeDB.get_project_theme()
	assert_true(project_theme != null, "the project theme loads")
	if project_theme != null:
		assert_eq(project_theme.resource_path, THEME_PATH, "the project theme is ui_theme.tres")
	assert_eq(ResourceLoader.get_resource_uid(THEME_PATH), ResourceUID.text_to_id("uid://eroe1xxhr5fc"),
			"ui_theme.tres keeps the uid the UI scenes reference")


func test_every_variation_a_scene_names_exists() -> void:
	var theme := _theme()
	var types := theme.get_type_list()
	var re := RegEx.create_from_string("theme_type_variation = &\"([A-Za-z0-9_]+)\"")
	var paths: Array[String] = []
	for dir_path: String in SCAN_DIRS:
		_files(dir_path, ["tscn", "gd"], paths)
	var named := 0
	for path: String in paths:
		for m: RegExMatch in re.search_all(FileAccess.get_file_as_string(path)):
			var variation := m.get_string(1)
			named += 1
			assert_true(types.has(variation), "%s names theme type %s" % [path, variation])
			assert_true(not ClassDB.class_exists(variation) and theme.get_type_variation_base(variation) != &"",
					"%s: %s is a variation with a base type" % [path, variation])
	assert_true(named >= 2, "the scan finds the scenes' variations (%d)" % named)


func test_every_stylebox_texture_and_icon_resolves() -> void:
	var theme := _theme()
	var textured := 0
	for type_name: String in theme.get_type_list():
		for sb_name: String in theme.get_stylebox_list(type_name):
			var sb := theme.get_stylebox(sb_name, type_name)
			assert_true(sb != null, "%s/styles/%s" % [type_name, sb_name])
			if sb is StyleBoxTexture:
				textured += 1
				var tex := (sb as StyleBoxTexture).texture
				assert_true(tex is DPITexture, "%s/styles/%s texture resolves to a DPITexture" % [type_name, sb_name])
				if tex != null:
					assert_true(tex.get_width() > 0 and tex.get_height() > 0, "%s/styles/%s has a size" % [type_name, sb_name])
		for icon_name: String in theme.get_icon_list(type_name):
			assert_true(theme.get_icon(icon_name, type_name) is DPITexture, "%s/icons/%s resolves" % [type_name, icon_name])
		for font_name: String in theme.get_font_list(type_name):
			assert_true(theme.get_font(font_name, type_name) != null, "%s/fonts/%s resolves" % [type_name, font_name])
	assert_true(textured > 40, "the theme is built over the SVG kit (%d texture styleboxes)" % textured)


func test_display_text_is_lilita_one_over_the_body_font() -> void:
	var theme := _theme()
	var body := theme.default_font as FontVariation
	assert_true(body != null and body.base_font == null, "font_body is a FontVariation over the engine font")
	if body == null:
		return
	assert_near(body.variation_embolden, 0.25, 0.001, "font_body embolden")
	for type_name: String in DISPLAY_TYPES:
		var font := theme.get_font(&"font", type_name) as FontVariation
		assert_true(font != null, "%s has a font" % type_name)
		if font == null:
			continue
		assert_true(font.base_font is FontFile and font.base_font.resource_path == DISPLAY_FONT,
				"%s uses Lilita One" % type_name)
		assert_true(font.fallbacks.size() == 1 and font.fallbacks[0] == body, "%s falls back to font_body" % type_name)
	for type_name: String in BODY_TYPES:
		assert_eq(theme.get_font(&"font", type_name), body, "%s uses font_body" % type_name)
	assert_true(FileAccess.get_file_as_string(FONT_LICENCE).contains("SIL OPEN FONT LICENSE Version 1.1"),
			"the OFL licence ships next to the font")


func test_display_font_has_every_translated_glyph() -> void:
	var font := _theme().get_font(&"font", &"HeaderLarge")
	var csv := FileAccess.open(STRINGS_CSV, FileAccess.READ)
	assert_true(csv != null, "strings.csv opens")
	if font == null or csv == null:
		return
	var missing := {}
	var rows := 0
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		rows += 1
		for text: String in row:
			for i in text.length():
				var code: int = text.unicode_at(i)
				if code >= 32 and not font.has_char(code):
					missing[String.chr(code)] = true
	csv.close()
	assert_true(rows > 10, "strings.csv has rows (%d)" % rows)
	assert_eq(missing.keys(), [], "every English and German glyph renders in display text")
	for umlaut: String in ["Ä", "Ö", "Ü", "ä", "ö", "ü", "ß"]:
		assert_true((font as FontVariation).base_font.has_char(umlaut.unicode_at(0)), "Lilita One draws %s" % umlaut)


func test_screen_variations_exist() -> void:
	var theme := _theme()
	for variation: String in SCREEN_VARIATIONS:
		assert_eq(theme.get_type_variation_base(variation), StringName(SCREEN_VARIATIONS[variation]),
				"%s extends %s" % [variation, SCREEN_VARIATIONS[variation]])
	# Skill-tree nodes are flat square tiles: the theme holds the locked look,
	# SkillNodeButton recolours its own copy per branch (UiPalette.branch_color).
	var palette := UiPalette.get_default()
	var tile := theme.get_stylebox(&"panel", &"NodeTile") as StyleBoxFlat
	assert_true(tile != null, "NodeTile is a StyleBoxFlat")
	if tile != null:
		_assert_rgb(tile.bg_color, palette.locked_fill, "NodeTile fill")
		_assert_rgb(tile.border_color, palette.locked_line, "NodeTile rim")
		assert_eq(tile.border_width_left, 4, "a 4 px rim")
		assert_eq(tile.corner_radius_top_left, 14, "rounded square")
	var badge := theme.get_stylebox(&"panel", &"BadgeReady") as StyleBoxFlat
	assert_true(badge != null, "BadgeReady is a StyleBoxFlat")
	if badge != null:
		_assert_rgb(badge.bg_color, palette.upgrade_ready, "the red + badge")
	for pair: Array in [[&"GutterPlaque", palette.wood_dark], [&"GutterPlaqueLocked", palette.locked_fill]]:
		var sb := theme.get_stylebox(&"panel", pair[0]) as StyleBoxFlat
		assert_true(sb != null, "%s is a StyleBoxFlat" % pair[0])
		if sb != null:
			_assert_rgb(sb.bg_color, pair[1], "%s fill" % pair[0])
	_assert_rgb(theme.get_color(&"font_color", &"NextLabel"), palette.moss_light, "Next: in moss green")
	_assert_rgb(theme.get_color(&"font_color", &"NowLabel"), palette.text, "Now: in white")
	_assert_rgb(theme.get_color(&"font_color", &"NodeNameLocked"), palette.text_muted, "a locked node's name")
	for gone: String in ["NodeLocked", "NodeAvailable", "NodeOwned", "NodeMaxed", "CapLocked", "CapAvailable", "CapOwned", "GateChip"]:
		assert_false(theme.get_type_list().has(gone), "%s left with the round rings" % gone)


## The theme writes colours with 4 significant digits.
func _assert_rgb(actual: Color, expected: Color, msg: String) -> void:
	assert_near(actual.r, expected.r, 0.002, msg + " r")
	assert_near(actual.g, expected.g, 0.002, msg + " g")
	assert_near(actual.b, expected.b, 0.002, msg + " b")


func test_art_names_are_canonical() -> void:
	var types := _theme().get_type_list()
	for ux_name: String in UX_RENAMES:
		assert_true(types.has(UX_RENAMES[ux_name]), "art type %s exists" % UX_RENAMES[ux_name])
		assert_false(types.has(ux_name), "UX name %s is renamed to %s" % [ux_name, UX_RENAMES[ux_name]])
