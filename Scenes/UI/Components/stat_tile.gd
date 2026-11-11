class_name StatTile
extends PanelContainer

## One number of a character overview (or a result screen): a stat icon, the
## value in display type and a small caption ("160" / "Health"). `bonus` is
## what the player's upgrades add to the value ("+98", in moss green right
## after it; "" hides it). The detail screen fills it from the character's
## stats resource and its owned build.

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
@export var bonus: String = "":
	set(v):
		bonus = v
		if is_node_ready():
			_apply()

@onready var _icon: TextureRect = %Icon
@onready var _value: Label = %Value
@onready var _bonus: Label = %Bonus
@onready var _caption: Label = %Caption


func _ready() -> void:
	_apply()


## Sets all of them at once.
func show_stat(p_icon: Texture2D, p_value: String, p_caption: String, p_bonus: String = "") -> void:
	icon = p_icon
	value = p_value
	caption = p_caption
	bonus = p_bonus


func _apply() -> void:
	_icon.texture = icon
	_value.text = value
	_bonus.text = bonus
	_bonus.visible = not bonus.is_empty()
	_caption.text = caption
