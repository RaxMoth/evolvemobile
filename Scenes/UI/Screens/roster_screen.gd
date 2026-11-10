class_name RosterScreen
extends Control

## One side's collection, the nav bar's Heroes or Monsters tab: the side's
## characters from GameManager.ROSTER as a 4-column grid of M CharacterCards
## (live rigs, level, XP or "upgrades ready" pill) followed by the side's one
## "???" rumour card, under a row of role filters (FilterTab buttons with the
## role icons; heroes: all, tank, melee, ranged, support, monsters: all, brute,
## stalker, swarm) and the owned / total count. When the screen opens the cards
## drop in one after another (CARD_STAGGER).
##
## Tapping an owned character asks for its detail (character_requested); so
## does a locked one that can be bought (Nyxa, Gorrak: MenuRoot opens the
## unlock confirm sheet with its rule and price instead). The rumour and a
## locked card without a price shake. The screen only reports: MenuRoot
## connects every signal scene-side, calls open() before it slides the screen
## in and refresh() when the save changes (currencies, skills, purchases).

signal character_requested(character: CharacterDef)
signal back_requested
signal tab_selected(tab_id: StringName)

const CARD_SCENE := preload("res://Scenes/UI/Components/CharacterCard.tscn")
const ALL: StringName = &"all"
## The intro (CharacterCard.play_intro): card i starts i x CARD_STAGGER after
## the first.
const CARD_STAGGER := 0.04
const SHAKE_PX := 8.0
const SHAKE_STEP := 0.04

## MatchRewards.Side values (CharacterDef.HEROES / MONSTER).
@export_enum("Heroes", "Monster") var side: int = CharacterDef.HEROES
## Role filters in row order, "all" first; the icons are
## Assets/UI/Icons/Roles/role_<key>.svg and a key matches CharacterDef.role_filter.
@export var filters: Array[StringName] = [&"all", &"tank", &"melee", &"ranged", &"support"]
## Live rigs on the cards (false: static portraits, for big grids).
@export var animated_cards: bool = true

## The filter shown (kept between visits).
var active_filter: StringName = ALL

var _cards: Array[CharacterCard] = []
var _rumour: CharacterCard = null
## Made here, not as a scene sub-resource: the two roster instances in
## MenuRoot must not share one group.
var _filter_group := ButtonGroup.new()
var _filter_buttons: Dictionary[StringName, Button] = {}

@onready var _top_bar: TopBar = %TopBar
@onready var _filters: HBoxContainer = %Filters
@onready var _count: Label = %Count
@onready var _grid: GridContainer = %Grid
@onready var _empty: Label = %Empty
@onready var _nav: NavBar = %NavBar


func _ready() -> void:
	var monster := is_monster()
	_top_bar.title = "Monsters" if monster else "Heroes"
	_top_bar.show_steel = not monster
	_top_bar.show_leaves = monster
	_nav.active_tab = own_tab()
	_build_filters()


func is_monster() -> bool:
	return side == CharacterDef.MONSTER


## The nav bar tab this screen is.
func own_tab() -> StringName:
	return &"monsters" if is_monster() else &"heroes"


## The side's characters in roster order.
func characters() -> Array[CharacterDef]:
	return GameManager.ROSTER.monsters if is_monster() else GameManager.ROSTER.heroes


## The character cards in grid order (the rumour card is not one of them).
func cards() -> Array[CharacterCard]:
	return _cards


func rumour_card() -> CharacterCard:
	return _rumour


## Before the screen slides in: builds the grid on the first visit, re-reads
## the save and plays the card intro.
func open() -> void:
	if _cards.is_empty() and _rumour == null:
		_build_cards()
	_nav.monster_side = GameManager.chosen_side == MatchRewards.Side.MONSTER
	_nav.active_tab = own_tab()
	refresh()
	set_filter(active_filter)
	play_intro()


## Re-reads levels, XP, ready upgrades and what is owned (the save changed).
func refresh() -> void:
	var owned := 0
	for card in _cards:
		card.refresh()
		if card.unlocked:
			owned += 1
	_count.text = "%d/%d" % [owned, _cards.size()]


## Shows the characters of one role (ALL: everyone and the rumour card).
func set_filter(key: StringName) -> void:
	active_filter = key if _filter_buttons.has(key) else ALL
	if _filter_buttons.has(active_filter):
		_filter_buttons[active_filter].set_pressed_no_signal(true)
	var shown := 0
	for card in _cards:
		card.visible = active_filter == ALL or card.character.role_filter == active_filter
		if card.visible:
			shown += 1
	if _rumour != null:
		_rumour.visible = active_filter == ALL
	_empty.visible = shown == 0 and active_filter != ALL


## The shown cards drop in one after another (fade in, frame grows).
func play_intro() -> void:
	var i := 0
	for card: CharacterCard in _grid.get_children():
		if card.visible:
			card.play_intro(CARD_STAGGER * i)
			i += 1


func _build_filters() -> void:
	for key in filters:
		var b := Button.new()
		b.name = "Filter_%s" % key
		b.theme_type_variation = &"FilterTab"
		b.toggle_mode = true
		b.button_group = _filter_group
		b.custom_minimum_size = Vector2(64, 56)
		b.icon = load(CharacterDef.ROLE_ICON_PATH % key) as Texture2D
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.expand_icon = true
		b.tooltip_text = String(key).capitalize()
		# Runtime-built: wired here.
		b.pressed.connect(set_filter.bind(key))
		_filters.add_child(b)
		_filter_buttons[key] = b
	if _filter_buttons.has(active_filter):
		_filter_buttons[active_filter].set_pressed_no_signal(true)


func _build_cards() -> void:
	for def in characters():
		if def == null:
			continue
		var card := _make_card()
		card.character = def
		_cards.append(card)
	_rumour = _make_card()
	_rumour.rumour = true
	_rumour.monster_side = is_monster()


func _make_card() -> CharacterCard:
	var card := CARD_SCENE.instantiate() as CharacterCard
	card.size_preset = CharacterCard.CardSize.M
	card.animated = animated_cards
	_grid.add_child(card)
	# Runtime-instanced: wired here.
	card.card_pressed.connect(_on_card_pressed.bind(card))
	return card


## A card that opens nothing (the rumour, a locked card without a price)
## shakes side to side.
func _shake(card: Control) -> void:
	var x := card.position.x
	var t := card.create_tween()
	for dx: float in [SHAKE_PX, -SHAKE_PX, SHAKE_PX, -SHAKE_PX, 0.0]:
		t.tween_property(card, ^"position:x", x + dx, SHAKE_STEP)


func _on_card_pressed(character: CharacterDef, card: CharacterCard) -> void:
	if CharacterProgress.unlock_state(character) == CharacterProgress.UnlockState.NOT_FOR_SALE:
		_shake(card)
		return
	character_requested.emit(character)


# --- scene-side connections (RosterScreen.tscn) ---

func _on_top_bar_left_pressed() -> void:
	back_requested.emit()


## The screen stays on its own tab: a tab that does not leave (HUNT's
## pre-round, the codex overlay) must not leave another one lit.
func _on_nav_bar_tab_selected(tab_id: StringName) -> void:
	tab_selected.emit(tab_id)
	_nav.active_tab = own_tab()
