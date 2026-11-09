class_name AbilityTile
extends Button

## One ability of the character overview: its kind (PASSIVE, BASIC, ACTIVE,
## ULTIMATE), its icon (AbilityBase.get_display_icon, as the HUD shows it) and
## its name. The four tiles of a detail
## screen share a ButtonGroup; the toggled-on tile wears the amber frame and
## reports tile_pressed, and the screen shows that ability's description.

signal tile_pressed(index: int)

## Position in the overview row (the screen's slot index).
@export var index: int = 0

## The ability shown (the shared .tres: read it, never modify it).
var ability: AbilityBase = null

@onready var _frame: PanelContainer = %Frame
@onready var _kind: Label = %Kind
@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name


func _ready() -> void:
	_apply_frame()


## Shows `p_ability` under the caption `kind`; null hides the tile.
func show_ability(kind: String, p_ability: AbilityBase) -> void:
	ability = p_ability
	visible = p_ability != null
	if p_ability == null:
		return
	_kind.text = kind
	_icon.texture = p_ability.get_display_icon()
	_name.text = p_ability.ability_name


func _apply_frame() -> void:
	_frame.theme_type_variation = &"CharacterCardSelected" if button_pressed else &"PanelInset"


func _on_toggled(on: bool) -> void:
	_apply_frame()
	if on:
		tile_pressed.emit(index)


func _on_button_down() -> void:
	PressFeedback.down(self)


func _on_button_up() -> void:
	PressFeedback.up(self)
