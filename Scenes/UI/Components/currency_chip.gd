class_name CurrencyChip
extends PanelContainer

## One currency in a top bar: its icon and the amount ("1,840"), live from
## PersistedData. The amount pops when it changes (rewards, purchases). The
## icon follows `currency` (Assets/UI/Icons/Currency/currency_<id>.svg).

const ICON_PATH := "res://Assets/UI/Icons/Currency/currency_%s.svg"
const POP_SCALE := Vector2(1.25, 1.25)

## PersistedData.GOLD / STEEL / LEAVES.
@export_enum("gold", "steel", "leaves") var currency: String = "gold":
	set(v):
		currency = v
		if is_node_ready():
			_show()
## Preview scenes: a fixed amount instead of the save file (-1 = live).
@export var preview_amount: int = -1:
	set(v):
		preview_amount = v
		if is_node_ready():
			_show()

@onready var _icon: TextureRect = %Icon
@onready var _amount: Label = %Amount


func _ready() -> void:
	_show()
	# An autoload cannot be a connection source in a scene.
	PersistedData.currency_changed.connect(_on_currency_changed)


func amount() -> int:
	return preview_amount if preview_amount >= 0 else PersistedData.get_currency(StringName(currency))


func _show() -> void:
	_icon.texture = icon_for(StringName(currency))
	_amount.text = format_amount(amount())


func _on_currency_changed(changed: StringName, new_amount: int) -> void:
	if changed != StringName(currency) or preview_amount >= 0:
		return
	_amount.text = format_amount(new_amount)
	_amount.pivot_offset = _amount.size * 0.5
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_amount, ^"scale", POP_SCALE, 0.08)
	t.tween_property(_amount, ^"scale", Vector2.ONE, 0.18)


## The currency's icon (null for an unknown id).
static func icon_for(currency_id: StringName) -> Texture2D:
	var path := ICON_PATH % currency_id
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## 1840 -> "1,840", -12000 -> "-12,000".
static func format_amount(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out
