class_name StrategyRow
extends PanelContainer

## One pre-round strategy dial (PanelInset): its icon, its name, the live
## value in amber ("50%"), the copper slider (step 0.05) and the plain words at
## both ends ("Careful" ... "Reckless"). value_changed re-emits the slider, so
## the screen wires one signal per row in its scene; setting `value` moves the
## slider without a report.

signal value_changed(value: float)

@export var title: String = "":
	set(v):
		title = v
		if is_node_ready():
			_apply()
@export var icon: Texture2D:
	set(v):
		icon = v
		if is_node_ready():
			_apply()
@export var low_text: String = "":
	set(v):
		low_text = v
		if is_node_ready():
			_apply()
@export var high_text: String = "":
	set(v):
		high_text = v
		if is_node_ready():
			_apply()
@export_range(0.0, 1.0, 0.05) var value: float = 0.5:
	set(v):
		value = v
		if is_node_ready():
			_slider.set_value_no_signal(v)
			_show_value()

@onready var _icon: TextureRect = %Icon
@onready var _title: Label = %Title
@onready var _value: Label = %Value
@onready var _slider: HSlider = %Slider
@onready var _low: Label = %Low
@onready var _high: Label = %High


func _ready() -> void:
	_apply()
	_slider.set_value_no_signal(value)
	_show_value()


## The slider (tests drag it through its own value).
func slider() -> HSlider:
	return _slider


## The value as the row shows it ("80%").
func value_text() -> String:
	return _value.text


func _apply() -> void:
	_icon.texture = icon
	_title.text = title
	_low.text = low_text
	_high.text = high_text


func _show_value() -> void:
	_value.text = "%d%%" % roundi(value * 100.0)


# --- scene-side connections (StrategyRow.tscn) ---

func _on_slider_value_changed(v: float) -> void:
	value = v
	value_changed.emit(v)
