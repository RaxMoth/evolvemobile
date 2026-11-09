class_name TopBar
extends MarginContainer

## The meta screens' top bar: a round button on the left (back, or settings on
## the lobby), an optional title, and the currency chips of the screen's side
## on the right (Gold always; Steel for heroes, Leaves for the monster).
## Screens connect left_pressed scene-side.

signal left_pressed

@export var left_icon: Texture2D:
	set(v):
		left_icon = v
		if is_node_ready():
			_apply()
@export var show_left: bool = true:
	set(v):
		show_left = v
		if is_node_ready():
			_apply()
@export var title: String = "":
	set(v):
		title = v
		if is_node_ready():
			_apply()
@export var show_gold: bool = true:
	set(v):
		show_gold = v
		if is_node_ready():
			_apply()
@export var show_steel: bool = true:
	set(v):
		show_steel = v
		if is_node_ready():
			_apply()
@export var show_leaves: bool = true:
	set(v):
		show_leaves = v
		if is_node_ready():
			_apply()

@onready var _left: Button = %Left
@onready var _title: Label = %Title


func _ready() -> void:
	_apply()


## The chip of one currency (PersistedData.GOLD / STEEL / LEAVES), or null.
func chip(currency: StringName) -> CurrencyChip:
	for c: CurrencyChip in [%Gold, %Steel, %Leaves]:
		if StringName(c.currency) == currency:
			return c
	return null


func _apply() -> void:
	if left_icon:
		_left.icon = left_icon
	_left.visible = show_left
	_title.text = title
	(%Gold as Control).visible = show_gold
	(%Steel as Control).visible = show_steel
	(%Leaves as Control).visible = show_leaves


func _on_left_pressed() -> void:
	left_pressed.emit()
