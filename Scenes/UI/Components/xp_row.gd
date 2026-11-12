class_name XpRow
extends PanelContainer

## One character's permanent XP after a match (MatchResultScreen): its head
## portrait in a ring of its signature colour, the name, "+N XP" and an XpBar
## that play() fills from the pre-match total to the new one on the level curve
## (PersistedData.level_progress, the "Lv.N" of the cards). Crossing a level on
## the way pops the red LEVEL UP! pill (%Pill, in a PopSlot so the Foot row's
## layout cannot reset its scale). A fallen hero keeps its XP but reads greyed
## (UiPalette.FALLEN_MODULATE) under a skull.

## Seconds the bar takes to fill.
const FILL_TIME := 0.9
## Width of the portrait ring.
const RING_WIDTH := 3
## The LEVEL UP! pill pops in from this scale.
const LEVEL_UP_FROM := Vector2(0.3, 0.3)

## The character shown (its head, name and signature colour).
@export var character: CharacterDef:
	set(v):
		character = v
		if is_node_ready():
			_apply_character()
## The evolution stage the monster reached in the match: its head shows that
## stage (CharacterDef.head_texture). 1 for heroes.
@export var stage: int = 1:
	set(v):
		stage = v
		if is_node_ready():
			_apply_character()
## Permanent XP before this match.
@export var total_before: int = 0
## XP this match earned.
@export var gain: int = 0:
	set(v):
		gain = v
		if is_node_ready():
			_gain.text = tr("+%d XP") % gain
@export var fallen: bool = false:
	set(v):
		fallen = v
		if is_node_ready():
			_apply_fallen()

## The level the bar shows now.
var level: int = 1
## True once the fill crossed a level (the pill popped).
var levelled_up: bool = false

var _fill: Tween = null
var _pop: Tween = null

@onready var _portrait: Panel = %Portrait
@onready var _head: TextureRect = %Head
@onready var _skull: TextureRect = %Skull
@onready var _name: Label = %Name
@onready var _gain: Label = %Gain
@onready var _bar: ProgressBar = %Bar
@onready var _level: Label = %Level
@onready var _level_up: Control = %LevelUp
@onready var _pill: Control = %Pill


func _ready() -> void:
	_apply_character()
	_apply_fallen()
	_gain.text = tr("+%d XP") % gain
	_level_up.visible = false
	_show_total(float(total_before))


## Fills the bar from total_before to total_before + gain after `delay`
## seconds, popping LEVEL UP! where it crosses a level.
func play(delay: float = 0.0) -> void:
	if _fill:
		_fill.kill()
	levelled_up = false
	_level_up.visible = false
	_show_total(float(total_before))
	_fill = create_tween()
	_fill.tween_interval(delay)
	_fill.tween_method(_show_total, float(total_before), float(total_before + gain), FILL_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _apply_character() -> void:
	if character == null:
		return
	_head.texture = character.head_texture(stage)
	_name.text = character.get_display_name()
	var sb := get_theme_stylebox(&"panel", &"HudPanel").duplicate() as StyleBoxFlat
	if sb == null:
		return
	sb.bg_color = UiPalette.get_default().panel_inset
	sb.border_color = UiPalette.signature(String(character.character_id()), character.is_monster())
	sb.set_border_width_all(RING_WIDTH)
	_portrait.add_theme_stylebox_override(&"panel", sb)


func _apply_fallen() -> void:
	_skull.visible = fallen
	_head.modulate = UiPalette.FALLEN_MODULATE if fallen else Color.WHITE


func _show_total(total: float) -> void:
	var progress := PersistedData.level_progress(roundi(total))
	var now: int = progress["level"]
	var into: int = progress["into"]
	var needed: int = progress["needed"]
	_bar.max_value = maxf(1.0, float(needed))
	_bar.value = float(into)
	_level.text = tr("Lv.%d") % now
	if now > level and _fill != null:
		_pop_level_up()
	level = now


func _pop_level_up() -> void:
	levelled_up = true
	_level_up.visible = true
	if _pop:
		_pop.kill()
	_pill.scale = LEVEL_UP_FROM
	_pop = create_tween()
	_pop.tween_property(_pill, ^"scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
