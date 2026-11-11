extends TestCase

## The Jungle Guild UI kit (Assets/UI): the SVG kit, icons and crests that
## tools/art/build.py writes, the theme and the two UI shaders that
## tools/art/make_theme.py writes, and the proof scenes in tools/preview.
## Checks that every SVG imports as a DPITexture (crisp at any canvas scale),
## that every character's ability icons exist, that the mockup's variations
## exist in the theme, that the shaders' default colours are the palette's,
## and that the proof scenes build. The theme itself (Scenes/UI/Theme/
## ui_theme.tres) has its own contract test, test_theme_contract.gd.

const UI_DIR := "res://Assets/UI"
const THEME_PATH := "res://Scenes/UI/Theme/ui_theme.tres"
const COOLDOWN_SHADER := "res://Assets/UI/Shaders/ability_cooldown.gdshader"
const LOCKED_SHADER := "res://Assets/UI/Shaders/card_locked.gdshader"
const MOCKUP_SCENE := "res://tools/preview/ThemeMockup.tscn"
const MOCKUP_SCRIPT := "res://tools/preview/theme_mockup.gd"
const PALETTE_SCENE := "res://tools/preview/PaletteSheet.tscn"
const PALETTE_JSON := "res://tools/art/palette.json"
## Group folder -> SVG count (tools/art/build.py GROUPS; in Lobby the two
## backdrops and the VS badge are hand-drawn from the UX design, the cave
## above the lair, lobby_monsters_top, comes from tools/art/lobby.py).
const GROUP_COUNTS: Dictionary[String, int] = {
	"Kit": 64,
	"Crests": 2,
	"Icons/Abilities": 29,
	"Icons/Currency": 4,
	"Icons/Stats": 16,
	"Icons/Roles": 9,
	"Icons/Nav": 6,
	"Icons/UI": 17,
	"Lobby": 4,
}
## Every character's ability icons, <owner>_<slot>_<ability>.
const ABILITY_ICONS: Array[String] = [
	"irelia_basic_taunting_strike", "irelia_active_divine_shield", "irelia_passive_regeneration",
	"irelia_ult_monster_taunt",
	"vlad_basic_blood_strike", "vlad_active_land_mine", "vlad_passive_bloodlust", "vlad_ult_blood_bomb",
	"ted_basic_claw_swipe", "ted_active_rally_cry", "ted_passive_loyal_companion", "ted_ult_trap_cage",
	"river_basic_sniper", "river_basic_heal", "river_active_weapon_swap", "river_passive_adaptive_movement",
	"river_ult_supply_drop",
	"grount_front_cleave", "grount_ram_dash", "grount_ground_slam", "grount_passive_evolution",
	"nyxa_basic_sonic_screech", "nyxa_active_shadow_swoop", "nyxa_ult_night_swarm", "nyxa_passive_blood_drinker",
	"gorrak_basic_cleaver_chop", "gorrak_active_tusk_axe", "gorrak_ult_warcry_stomp", "gorrak_passive_bristled_hide",
]


func _svgs(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	for sub: String in d.get_directories():
		_svgs(dir_path.path_join(sub), out)
	for f: String in d.get_files():
		if f.ends_with(".svg"):
			out.append(dir_path.path_join(f))


func test_every_ui_svg_imports_as_a_dpitexture() -> void:
	var paths: Array[String] = []
	_svgs(UI_DIR, paths)
	var expected := 0
	for group: String in GROUP_COUNTS:
		var in_group: Array[String] = []
		_svgs(UI_DIR.path_join(group), in_group)
		assert_eq(in_group.size(), GROUP_COUNTS[group], "SVGs in Assets/UI/%s" % group)
		expected += GROUP_COUNTS[group]
	assert_eq(paths.size(), expected, "no SVG outside the kit groups")
	for path: String in paths:
		var tex := load(path) as Texture2D
		assert_true(tex is DPITexture, "%s imports as a DPITexture (got %s)" % [path, tex.get_class() if tex else "null"])
		if tex != null:
			assert_true(tex.get_width() > 0 and tex.get_height() > 0, "%s has a size" % path)


func test_every_character_has_its_ability_icons() -> void:
	var dir := UI_DIR.path_join("Icons/Abilities")
	for icon_name: String in ABILITY_ICONS:
		var path := dir.path_join(icon_name + ".svg")
		assert_true(ResourceLoader.exists(path), "ability icon %s" % path)
		var tex := load(path) as Texture2D
		if tex != null:
			assert_eq(tex.get_size(), Vector2(64, 64), "%s is a 64x64 tile" % icon_name)
	for hero_id: StringName in GameManager.KNOWN_HERO_IDS:
		var owned := ABILITY_ICONS.filter(func(n: String) -> bool: return n.begins_with(String(hero_id) + "_"))
		assert_true(owned.size() >= 4, "%s has an icon per slot (%d)" % [hero_id, owned.size()])


func test_mockup_variations_exist_in_the_theme() -> void:
	var theme := load(THEME_PATH) as Theme
	var source := FileAccess.get_file_as_string(MOCKUP_SCRIPT)
	var re := RegEx.create_from_string("&\"([A-Z][A-Za-z]+)\"")
	var types := theme.get_type_list()
	var checked := 0
	for m: RegExMatch in re.search_all(source):
		var variation := m.get_string(1)
		assert_true(types.has(variation), "theme type %s used by theme_mockup.gd" % variation)
		checked += 1
	assert_true(checked > 30, "theme_mockup.gd names its variations (%d)" % checked)


## Default of `uniform vec4 <uniform> : source_color = vec4(r, g, b, a);`.
func _uniform_default(code: String, uniform: String) -> Color:
	var re := RegEx.create_from_string(
			"uniform vec4 " + uniform + " : source_color = vec4\\(([0-9.]+), ([0-9.]+), ([0-9.]+), ([0-9.]+)\\)")
	var m := re.search(code)
	if m == null:
		return Color.MAGENTA
	return Color(float(m.get_string(1)), float(m.get_string(2)), float(m.get_string(3)), float(m.get_string(4)))


func _assert_rgb(actual: Color, expected: Color, msg: String) -> void:
	assert_near(actual.r, expected.r, 0.002, msg + " r")
	assert_near(actual.g, expected.g, 0.002, msg + " g")
	assert_near(actual.b, expected.b, 0.002, msg + " b")


func test_shader_defaults_are_palette_colours() -> void:
	var palette := UiPalette.get_default()
	var cooldown := load(COOLDOWN_SHADER) as Shader
	var locked := load(LOCKED_SHADER) as Shader
	assert_true(cooldown != null and locked != null, "both UI shaders load")
	if cooldown == null or locked == null:
		return
	for uniform: String in ["progress", "ready_flash", "locked", "veil_color", "edge_color", "edge_width"]:
		assert_true(cooldown.code.contains("uniform ") and cooldown.code.contains(" " + uniform + " "),
				"ability_cooldown declares %s" % uniform)
	var veil := _uniform_default(cooldown.code, "veil_color")
	_assert_rgb(veil, palette.cooldown_veil, "veil_color is cooldown_veil")
	assert_near(veil.a, UiPalette.COOLDOWN_VEIL_ALPHA, 0.001, "veil alpha")
	_assert_rgb(_uniform_default(cooldown.code, "edge_color"), palette.amber, "edge_color is amber")
	_assert_rgb(_uniform_default(locked.code, "fill"), palette.locked_fill, "fill is locked_fill")
	_assert_rgb(_uniform_default(locked.code, "rim"), palette.locked_line, "rim is locked_line")


func test_palette_sheet_shows_every_token() -> void:
	var sheet := (load(PALETTE_SCENE) as PackedScene).instantiate()
	add_child(sheet)
	await wait_frames(1)
	var flow := sheet.get_node("Margin/Flow")
	var swatches := 0
	var headers := 0
	for child in flow.get_children():
		if child is Label:
			headers += 1
		else:
			swatches += 1
	var palette := UiPalette.get_default()
	assert_eq(swatches, palette.tokens().size(), "one swatch per palette token")
	var groups: Variant = JSON.parse_string(FileAccess.get_file_as_string(PALETTE_JSON))
	assert_true(groups is Dictionary, "palette.json parses")
	if groups is Dictionary:
		assert_eq(headers, (groups as Dictionary).size(), "one title per palette.py group")
	assert_eq((sheet as ColorRect).color, palette.bg_base, "screen colour from the palette")


func test_theme_mockup_builds() -> void:
	var mockup := (load(MOCKUP_SCENE) as PackedScene).instantiate() as Control
	add_child(mockup)
	await wait_frames(2)
	var rects := mockup.find_children("*", "TextureRect", true, false)
	assert_true(rects.size() > 50, "the mockup shows the kit and icons (%d TextureRects)" % rects.size())
	for rect: Node in rects:
		assert_true((rect as TextureRect).texture != null, "%s has its texture" % mockup.get_path_to(rect))
	var shaded := 0
	for rect: Node in rects:
		var mat := (rect as TextureRect).material as ShaderMaterial
		if mat != null:
			shaded += 1
	assert_true(shaded >= 15, "ability slots and locked portraits use the UI shaders (%d)" % shaded)
