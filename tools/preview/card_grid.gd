extends Control
## Proof sheet of the menu component kit (Scenes/UI/Components): the
## collection grid of M cards in every state the roster screen will show, the
## top bar's currency chips and the bottom nav bar. Not shipped (tools/).
## Sample numbers, never the save: the cards get apply_progress() and the
## chips a preview_amount, so the sheet looks the same on any machine and
## never writes user://.
##   default page: heroes 4/4 + rumour, monsters (Grount upgrade-ready, Nyxa
##                 and Gorrak locked with prices, rumour), nav on the hero side.
##   "-- --page=sizes": the L quarry card, S cards (one selected, one locked,
##                 a rumour), the lobby's StageCharacters (cheering, the outer
##                 pair flipped; Grount at stage 3, Nyxa locked) and the nav on
##                 the monster side.
## Render muted on a copy of the project:
##   godot --path <copy> --audio-driver Dummy --fixed-fps 30 --resolution 720x1280
##         --write-movie <dir>/f.png --quit-after 60 res://tools/preview/CardGrid.tscn [-- --page=sizes]

const CARD := preload("res://Scenes/UI/Components/CharacterCard.tscn")
const STAGE_CHARACTER := preload("res://Scenes/UI/Components/StageCharacter.tscn")
## Monsters the roster does not ship yet (Gorrak): preview-only defs over
## their built rigs and portraits, locked with the planned prices. An id the
## roster has (Nyxa) shows its real, locked def instead.
const LOCKED_PREVIEW: Array[Array] = [
	["nyxa", 2500],
	["gorrak", 3000],
]

@onready var _list: VBoxContainer = %List
@onready var _top_bar: TopBar = %TopBar
@onready var _nav: NavBar = %NavBar


func _ready() -> void:
	(%Background as ColorRect).color = UiPalette.get_default().bg_base
	for c: Array in [[PersistedData.GOLD, 1840], [PersistedData.STEEL, 1265], [PersistedData.LEAVES, 2860]]:
		_top_bar.chip(c[0]).preview_amount = c[1]
	if OS.get_cmdline_user_args().has("--page=sizes"):
		_sizes_page()
	else:
		_grid_page()


func _grid_page() -> void:
	_top_bar.title = "Collection"
	var heroes := GameManager.ROSTER.heroes
	_list.add_child(_banner("HEROES  %d/%d" % [heroes.size(), heroes.size()], &"BannerHero"))
	var grid := _grid()
	_list.add_child(grid)
	# [level, into, needed, upgrades ready, animated]
	var samples: Array[Array] = [[4, 230, 400, 0, true], [3, 120, 300, 2, true], [2, 80, 200, 0, false], [5, 310, 500, 1, true]]
	for i in heroes.size():
		var s: Array = samples[i % samples.size()]
		var card := _card(grid, heroes[i], CharacterCard.CardSize.M, s[4])
		card.apply_progress(s[0], s[1], s[2], s[3], true)
	_rumour(grid, false, CharacterCard.CardSize.M)
	var monsters: Array[CharacterDef] = []
	monsters.append_array(GameManager.ROSTER.monsters)
	for pick in LOCKED_PREVIEW:
		if GameManager.ROSTER.find(StringName(pick[0])) == null:
			monsters.append(_locked_def(pick[0], pick[1]))
	var owned := monsters.filter(func(d: CharacterDef) -> bool: return d.unlocked_by_default).size()
	_list.add_child(_banner("MONSTERS  %d/%d" % [owned, monsters.size()], &"BannerMonster"))
	grid = _grid()
	_list.add_child(grid)
	for d in monsters:
		var card := _card(grid, d, CharacterCard.CardSize.M, true)
		card.apply_progress(6, 170, 600, 3, d.unlocked_by_default)
	_rumour(grid, true, CharacterCard.CardSize.M)
	_nav.active_tab = &"heroes"
	_nav.notify_tabs = [&"growth", &"monsters"]


func _sizes_page() -> void:
	_top_bar.title = "Tonight's quarry"
	_top_bar.show_steel = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	_list.add_child(row)
	var quarry := _card(row, GameManager.ROSTER.find(&"grount"), CharacterCard.CardSize.L, true)
	quarry.apply_progress(7, 420, 700, 0, true)
	var side := VBoxContainer.new()
	side.add_theme_constant_override(&"separation", 8)
	row.add_child(side)
	var small := HBoxContainer.new()
	small.add_theme_constant_override(&"separation", 12)
	side.add_child(small)
	var heroes := GameManager.ROSTER.heroes
	_card(small, heroes[0], CharacterCard.CardSize.S, false).apply_progress(3, 40, 300, 1, true)
	var picked := _card(small, heroes[1], CharacterCard.CardSize.S, false)
	picked.apply_progress(1, 0, 100, 0, true)
	picked.selected = true
	var small2 := HBoxContainer.new()
	small2.add_theme_constant_override(&"separation", 12)
	side.add_child(small2)
	_card(small2, _locked_def("gorrak", 3000), CharacterCard.CardSize.S, false).apply_progress(1, 0, 100, 0, false)
	_rumour(small2, true, CharacterCard.CardSize.S)
	_list.add_child(_banner("AT THE CAMPFIRE", &"BannerHero"))
	var stage := HBoxContainer.new()
	stage.alignment = BoxContainer.ALIGNMENT_CENTER
	stage.add_theme_constant_override(&"separation", 0)
	_list.add_child(stage)
	for i in heroes.size():
		var sc := STAGE_CHARACTER.instantiate() as StageCharacter
		sc.name = "Stage%s" % String(heroes[i].character_id()).capitalize()
		sc.character = heroes[i]
		sc.flip = i >= 2
		sc.custom_minimum_size = Vector2(170, 200)
		stage.add_child(sc)
		sc.cheer(0.5 + 0.05 * i)
	var lair := HBoxContainer.new()
	lair.alignment = BoxContainer.ALIGNMENT_CENTER
	_list.add_child(lair)
	for pick: Array in [["grount", 3], ["nyxa", 1]]:
		var def := GameManager.ROSTER.find(StringName(pick[0]))
		if def == null:
			def = _locked_def(pick[0], 2500)
		var sc := STAGE_CHARACTER.instantiate() as StageCharacter
		sc.name = "Lair%s" % String(pick[0]).capitalize()
		sc.character = def
		sc.stage = pick[1]
		sc.custom_minimum_size = Vector2(240, 180)
		lair.add_child(sc)
	_nav.monster_side = true
	_nav.active_tab = &"hunt"
	_nav.notify_tabs = [&"codex"]


func _card(parent: Control, def: CharacterDef, preset: CharacterCard.CardSize, animated: bool) -> CharacterCard:
	var card := CARD.instantiate() as CharacterCard
	card.character = def
	card.size_preset = preset
	card.animated = animated
	parent.add_child(card)
	return card


func _rumour(parent: Control, monster: bool, preset: CharacterCard.CardSize) -> void:
	var card := CARD.instantiate() as CharacterCard
	card.rumour = true
	card.monster_side = monster
	card.size_preset = preset
	parent.add_child(card)


## A locked monster that is not in the roster yet, over its built art.
func _locked_def(id: String, price: int) -> CharacterDef:
	var d := CharacterDef.new()
	d.side = CharacterDef.MONSTER
	d.display_name = id.capitalize()
	d.portrait = load("res://Assets/Characters/%s/%s.svg" % [id, id]) as Texture2D
	d.rig_body = load("res://Assets/Characters/%s/%s_body.tscn" % [id, id]) as PackedScene
	d.rig_profile = load("res://Assets/Characters/%s/%s_motion.tres" % [id, id]) as RigProfile
	d.unlocked_by_default = false
	d.unlock_cost = price
	return d


func _grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override(&"h_separation", 16)
	g.add_theme_constant_override(&"v_separation", 12)
	return g


func _banner(title: String, variation: StringName) -> Control:
	var c := CenterContainer.new()
	var b := PanelContainer.new()
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(300, 52)
	var l := Label.new()
	l.text = title
	l.theme_type_variation = &"BannerTitle"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(l)
	c.add_child(b)
	return c
