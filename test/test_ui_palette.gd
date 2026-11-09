extends TestCase

## UiPalette is the one runtime colour source. palette.tres and the token
## exports are generated from tools/art/palette.py by
## `python3 tools/art/make_theme.py palette`, which also writes palette.json
## (the same palette as data): a stale palette.tres, a token missing from
## UiPalette or a value edited in only one place fails here.

const PALETTE_JSON := "res://tools/art/palette.json"
const MONSTER_IDS: Array[String] = ["grount", "nyxa", "gorrak"]


## token -> colour, in palette order, from palette.json.
func _art_palette() -> Dictionary[String, Color]:
	var out: Dictionary[String, Color] = {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PALETTE_JSON))
	if not parsed is Dictionary:
		return out
	var groups: Dictionary = parsed
	for title: String in groups:
		for entry: Dictionary in groups[title]:
			out[str(entry["token"])] = Color(str(entry["hex"]))
	return out


func test_palette_tres_matches_the_art_palette() -> void:
	var art := _art_palette()
	assert_true(art.size() >= 100, "palette.json lists the art tokens (%d)" % art.size())
	var palette := UiPalette.get_default()
	assert_true(palette != null, "palette.tres loads as a UiPalette")
	if palette == null:
		return
	var tokens := palette.tokens()
	var names: Array[StringName] = []
	for token: String in art:
		names.append(StringName(token))
	assert_eq(tokens, names, "UiPalette exports exactly the art tokens, in palette order")
	for token: String in art:
		var value := palette.color(StringName(token))
		assert_true(value == art[token], "%s is %s in palette.tres, %s in palette.json"
				% [token, value.to_html(), art[token].to_html()])


func test_unknown_token_is_magenta() -> void:
	var palette := UiPalette.get_default()
	assert_eq(palette.color(&"no_such_token"), Color.MAGENTA, "unknown tokens are loud")
	assert_eq(palette.color(&"resource_name"), Color.MAGENTA, "a non-colour property is not a token")
	assert_eq(UiPalette.new().color(&"ink"), Color.MAGENTA, "a token without a value in palette.tres stays magenta")
	assert_true(palette.color(&"ink") != Color.MAGENTA, "real tokens resolve")


func test_signature_covers_every_character() -> void:
	var palette := UiPalette.get_default()
	var expected: Dictionary[String, Color] = {
		"irelia": palette.irelia,
		"vlad": palette.vlad,
		"ted": palette.ted,
		"river": palette.river,
		"grount": palette.grount,
		"nyxa": palette.monster2,
		"gorrak": palette.monster3,
	}
	assert_eq(UiPalette.SIGNATURE_TOKENS.size(), expected.size(), "one signature per character id")
	for id: String in expected:
		var is_monster := id in MONSTER_IDS
		var fallback := palette.monster if is_monster else palette.hero
		assert_eq(UiPalette.signature(id, is_monster), expected[id], "%s signature" % id)
		assert_true(expected[id] != fallback, "%s has its own colour, not the side accent" % id)
	for hero_id: StringName in GameManager.KNOWN_HERO_IDS:
		assert_true(expected.has(String(hero_id)), "playable hero %s has a signature" % hero_id)
	assert_eq(UiPalette.signature("someone_new", false), palette.hero, "unknown hero -> hero accent")
	assert_eq(UiPalette.signature("someone_new", true), palette.monster, "unknown monster -> monster accent")
