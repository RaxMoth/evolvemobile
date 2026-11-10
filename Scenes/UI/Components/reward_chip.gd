class_name RewardChip
extends PanelContainer

## One reward of a finished match (MatchResultScreen): the currency or XP icon,
## "+N" in display type and a caption ("Gold", "XP each"). play() counts the
## number up from 0 and pops it when it lands. A reward the Opponent Threat
## raised shows its bonus under the number ("+20%", amber); XP never has one.

## Seconds the count-up takes.
const COUNT_TIME := 0.7
## The number's pop when the count lands.
const POP_SCALE := Vector2(1.25, 1.25)

@export var icon: Texture2D:
	set(v):
		icon = v
		if is_node_ready():
			_icon.texture = icon
@export var caption: String = "":
	set(v):
		caption = v
		if is_node_ready():
			_caption.text = caption
## The amount earned (the count-up's end).
@export var amount: int = 0:
	set(v):
		amount = v
		if is_node_ready():
			_show(float(amount))
## The Opponent Threat's bonus on this reward in percent (0 = none shown).
@export var bonus_pct: int = 0:
	set(v):
		bonus_pct = v
		if is_node_ready():
			_apply_bonus()

## The number the label shows now (the count-up's progress).
var shown: int = 0

var _count: Tween = null

@onready var _icon: TextureRect = %Icon
@onready var _amount: Label = %Amount
@onready var _caption: Label = %Caption
@onready var _bonus: Label = %Bonus


func _ready() -> void:
	_icon.texture = icon
	_caption.text = caption
	_apply_bonus()
	_show(float(amount))


## Counts from 0 up to `amount` after `delay` seconds, then pops the number.
func play(delay: float = 0.0) -> void:
	if _count:
		_count.kill()
	_show(0.0)
	_count = create_tween()
	_count.tween_interval(delay)
	_count.tween_method(_show, 0.0, float(amount), COUNT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_count.tween_callback(_pop)


func _show(value: float) -> void:
	shown = roundi(value)
	_amount.text = "+%s" % CurrencyChip.format_amount(shown)


func _apply_bonus() -> void:
	_bonus.visible = bonus_pct > 0
	_bonus.text = "+%d%%" % bonus_pct


func _pop() -> void:
	_amount.pivot_offset = _amount.size * 0.5
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_amount, ^"scale", POP_SCALE, 0.08)
	t.tween_property(_amount, ^"scale", Vector2.ONE, 0.2)
