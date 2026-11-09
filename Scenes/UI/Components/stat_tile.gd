class_name StatTile
extends PanelContainer

## One number of a character overview (or a result screen): a stat icon, the
## value in display type and a small caption ("160" / "Health"). The detail
## screen fills it from the character's stats resource.

@export var icon: Texture2D:
	set(v):
		icon = v
		if is_node_ready():
			_apply()
@export var value: String = "":
	set(v):
		value = v
		if is_node_ready():
			_apply()
@export var caption: String = "":
	set(v):
		caption = v
		if is_node_ready():
			_apply()

@onready var _icon: TextureRect = %Icon
@onready var _value: Label = %Value
@onready var _caption: Label = %Caption


func _ready() -> void:
	_apply()


## Sets all three at once.
func show_stat(p_icon: Texture2D, p_value: String, p_caption: String) -> void:
	icon = p_icon
	value = p_value
	caption = p_caption


func _apply() -> void:
	_icon.texture = icon
	_value.text = value
	_caption.text = caption
