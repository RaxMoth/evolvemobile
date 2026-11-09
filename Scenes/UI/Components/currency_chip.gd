class_name CurrencyChip
extends PanelContainer

## One currency in a top bar: its icon and the amount ("1,840"), live from
## PersistedData. When it changes (rewards, purchases) the amount counts to
## the new value over COUNT_TIME (down after a purchase) and pops. The icon
## follows `currency` (Assets/UI/Icons/Currency/currency_<id>.svg).

const ICON_PATH := "res://Assets/UI/Icons/Currency/currency_%s.svg"
const POP_SCALE := Vector2(1.25, 1.25)
const COUNT_TIME := 0.4

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

## The amount on the label (between the old and the new one while counting).
var _shown: int = 0
var _count: Tween = null

@onready var _icon: TextureRect = %Icon
@onready var _amount: Label = %Amount


func _ready() -> void:
	_show()
	# An autoload cannot be a connection source in a scene.
	PersistedData.currency_changed.connect(_on_currency_changed)


func amount() -> int:
	return preview_amount if preview_amount >= 0 else PersistedData.get_currency(StringName(currency))


## The amount the label shows now (mid-count while it counts).
func shown_amount() -> int:
	return _shown


func _show() -> void:
	_icon.texture = icon_for(StringName(currency))
	if _count != null:
		_count.kill()
		_count = null
	_set_shown(amount())


func _set_shown(v: int) -> void:
	_shown = v
	_amount.text = format_amount(v)


func _count_step(v: float) -> void:
	_set_shown(roundi(v))


func _on_currency_changed(changed: StringName, new_amount: int) -> void:
	if changed != StringName(currency) or preview_amount >= 0:
		return
	if _count != null:
		_count.kill()
	_count = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_count.tween_method(_count_step, float(_shown), float(new_amount), COUNT_TIME)
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
