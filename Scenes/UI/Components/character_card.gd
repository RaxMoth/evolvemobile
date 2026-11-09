class_name CharacterCard
extends Button

## One roster character as a collection card, in the reference's style: the
## copper CharacterCard frame (crimson with horn spikes for monsters, amber
## when `selected`), a darker inner panel (moss for heroes, plum for monsters)
## with the character, "Lv.N" at the panel's bottom-left, the name, and a pill:
##   - PillProgress "into/needed": XP toward the next permanent level;
##   - PillProgressReady "up-arrow N" plus the red notify dot: N skill ranks of
##     the character's tree can be bought now (CharacterProgress).
## A locked character is a card_locked silhouette of its portrait under the
## padlock, named "???", with a price chip when it can be bought. `rumour` is
## the "???" slot each side ends with (no character, no name, no numbers).
##
## The art is the character's live rig (RigView) when `animated`, or its
## static portrait (<id>.svg) for big grids. Size presets S / M / L scale the
## layout and fonts from the M design (160x262).
##
## Read-only: refresh() reads PersistedData / MetaSkillManager through
## CharacterProgress; screens call it when currencies or skills change.
## apply_progress() shows given numbers (previews, tests).

signal card_pressed(character: CharacterDef)

enum CardSize { S, M, L }

## Card size per preset (gamedesign spec): S for picker rows and the
## pre-round squad, M for the 4-column collection grid, L for the quarry card.
const SIZES: Array[Vector2] = [Vector2(150, 238), Vector2(160, 262), Vector2(280, 446)]
const LOCKED_SHADER := preload("res://Assets/UI/Shaders/card_locked.gdshader")

static var _locked_material: ShaderMaterial = null

@export var character: CharacterDef:
	set(v):
		character = v
		if is_node_ready():
			refresh()
@export var size_preset: CardSize = CardSize.M:
	set(v):
		size_preset = v
		if is_node_ready():
			_apply_size()
## Live rig (true) or the static portrait (false, grids of many cards).
@export var animated: bool = true:
	set(v):
		animated = v
		if is_node_ready():
			_show()
## Picker use: the amber CharacterCardSelected frame.
@export var selected: bool = false:
	set(v):
		selected = v
		if is_node_ready():
			_apply_frame()
## The "???" rumour slot (no character).
@export var rumour: bool = false:
	set(v):
		rumour = v
		if is_node_ready():
			refresh()
## Side of a rumour card; a character card takes its def's side.
@export var monster_side: bool = false:
	set(v):
		monster_side = v
		if is_node_ready():
			_show()

## What the card shows (read by tests and screens).
var level: int = 1
var xp_into: int = 0
var xp_needed: int = 0
var upgrades: int = 0
var unlocked: bool = true

## Each scaled node's M-design values, recorded once in _ready.
var _base_font: Dictionary[Control, int] = {}
var _base_outline: Dictionary[Control, int] = {}
var _base_min: Dictionary[Control, Vector2] = {}
## apply_progress() ran before _ready: show its numbers, not the save's.
var _given := false

@onready var _frame: PanelContainer = %Frame
@onready var _inner: PanelContainer = %Inner
@onready var _portrait: TextureRect = %Portrait
@onready var _rig: RigView = %Rig
@onready var _lock: TextureRect = %Lock
@onready var _level: Label = %Level
@onready var _name: Label = %Name
@onready var _pill: ProgressBar = %Pill
@onready var _up_icon: TextureRect = %UpIcon
@onready var _pill_label: Label = %PillLabel
@onready var _price: PanelContainer = %Price
@onready var _price_icon: TextureRect = %PriceIcon
@onready var _price_label: Label = %PriceLabel
@onready var _rumour_box: Control = %RumourBox
@onready var _rumour_mark: Label = %RumourMark
@onready var _rumour_text: Label = %RumourText
@onready var _dot: TextureRect = %Dot


func _ready() -> void:
	for label: Label in [_level, _name, _pill_label, _price_label, _rumour_mark, _rumour_text]:
		_base_font[label] = label.get_theme_font_size(&"font_size")
		_base_outline[label] = label.get_theme_constant(&"outline_size")
	for c: Control in [_lock, _up_icon, _price_icon, _pill, _dot, %Bottom]:
		_base_min[c] = c.custom_minimum_size
	_rumour_mark.add_theme_color_override(&"font_color", UiPalette.get_default().text_muted)
	_apply_size()
	if _given:
		_show()
	else:
		refresh()


## Re-reads the character's level, XP and ready upgrades.
func refresh() -> void:
	if rumour or character == null:
		_show_rumour()
		return
	var p := CharacterProgress.progress(character)
	apply_progress(p["level"], p["into"], p["needed"], CharacterProgress.upgrades_ready(character),
			CharacterProgress.is_unlocked(character))


## Shows these numbers for `character` (refresh() passes the saved ones).
## Before the card is ready they are kept and shown by _ready instead of the
## save's.
func apply_progress(lv: int, into: int, needed: int, ready_upgrades: int, is_unlocked: bool) -> void:
	level = lv
	xp_into = into
	xp_needed = needed
	upgrades = ready_upgrades if is_unlocked else 0
	unlocked = is_unlocked
	if is_node_ready():
		_show()
	else:
		_given = true


func _show() -> void:
	if rumour or character == null:
		_show_rumour()
		return
	_rumour_box.visible = false
	_name.visible = true
	_apply_frame()
	_apply_art()
	_lock.visible = not unlocked
	_level.visible = unlocked
	_pill.visible = unlocked
	_dot.visible = unlocked and upgrades > 0
	_name.text = character.get_display_name() if unlocked else "???"
	_price.visible = not unlocked and character.unlock_cost > 0
	if not unlocked:
		_show_price()
		return
	_level.text = tr("Lv.%d") % level
	var can_upgrade := upgrades > 0
	_pill.theme_type_variation = &"PillProgressReady" if can_upgrade else &"PillProgress"
	# The red pill reads as one solid "ready" chip; otherwise it fills with XP.
	_pill.max_value = maxi(xp_needed, 1)
	_pill.value = _pill.max_value if can_upgrade else float(clampi(xp_into, 0, maxi(xp_needed, 1)))
	_up_icon.visible = can_upgrade
	_pill_label.text = str(upgrades) if can_upgrade else "%d/%d" % [xp_into, xp_needed]


## The "???" slot: locked frame, a big question mark and the rumour line.
func _show_rumour() -> void:
	unlocked = false
	upgrades = 0
	_apply_frame()
	_rig.character = null
	_rig.visible = false
	_portrait.visible = false
	_lock.visible = false
	_level.visible = false
	_name.visible = false
	_pill.visible = false
	_price.visible = false
	_dot.visible = false
	_rumour_box.visible = true


func _apply_frame() -> void:
	var monster := character.is_monster() if character != null and not rumour else monster_side
	var dark := rumour or character == null or not unlocked
	if dark:
		_frame.theme_type_variation = &"CharacterCardLocked"
		_inner.theme_type_variation = &"CardInnerLocked"
		return
	if selected:
		_frame.theme_type_variation = &"CharacterCardSelected"
	else:
		_frame.theme_type_variation = &"CharacterCardMonster" if monster else &"CharacterCard"
	_inner.theme_type_variation = &"CardInnerMonster" if monster else &"CardInnerHero"


## Live rig, static portrait, or the portrait as a locked silhouette.
func _apply_art() -> void:
	var live := animated and unlocked and character.rig_body != null
	_rig.visible = live
	_rig.character = character if live else null
	_portrait.visible = not live
	_portrait.texture = character.portrait
	_portrait.material = null if unlocked else locked_material()


func _show_price() -> void:
	var currency := character.currency()
	_price_icon.texture = CurrencyChip.icon_for(currency)
	_price_label.text = CurrencyChip.format_amount(character.unlock_cost)
	_price_label.add_theme_color_override(&"font_color", UiPalette.get_default().color(currency))


## Layout and type of the size preset, scaled from the M design.
func _apply_size() -> void:
	var card_size := SIZES[size_preset]
	var k := card_size.y / SIZES[CardSize.M].y
	custom_minimum_size = card_size
	size = card_size
	for c: Control in _base_font:
		c.add_theme_font_size_override(&"font_size", roundi(_base_font[c] * k))
		c.add_theme_constant_override(&"outline_size", roundi(_base_outline[c] * k))
	for c: Control in _base_min:
		c.custom_minimum_size = (_base_min[c] * k).round()
	_dot.size = _dot.custom_minimum_size
	_dot.position = Vector2(card_size.x - _dot.size.x * 0.7, -_dot.size.y * 0.3)


## The one locked-silhouette material every card shares (no per-card params).
static func locked_material() -> ShaderMaterial:
	if _locked_material == null:
		_locked_material = ShaderMaterial.new()
		_locked_material.shader = LOCKED_SHADER
	return _locked_material


func _on_pressed() -> void:
	card_pressed.emit(null if rumour else character)


func _on_button_down() -> void:
	PressFeedback.down(self)


func _on_button_up() -> void:
	PressFeedback.up(self)
