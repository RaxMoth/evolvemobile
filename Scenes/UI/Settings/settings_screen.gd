class_name SettingsScreen
extends Control

## SettingsScreen — full-screen overlay for audio volumes and progress reset.
##
## Built entirely in code (no .tscn) so it can be dropped in from any menu with
## `add_child(SettingsScreen.new())`. Volume sliders drive the audio buses live
## through AudioSettings and persist on close; the reset button clears the save
## via PersistedData.wipe_progress() behind a two-tap confirm.

const _THEME: Theme = preload("res://Scenes/UI/Theme/ui_theme.tres")

const _PANEL_BG := Color(0.10, 0.12, 0.14, 0.98)
const _ACCENT := Color(0.62, 0.78, 0.96, 0.92)
const _MUTED := Color(0.66, 0.70, 0.74, 0.85)
const _DANGER := Color(0.90, 0.42, 0.40, 1.0)

# Per-key percentage labels, refreshed as their slider moves.
var _value_labels: Dictionary = {}

var _reset_button: Button = null
var _reset_armed: bool = false


## Minimum height of anything a thumb must hit (Apple HIG 44 pt, Material 48 dp).
const TOUCH_TARGET: float = 48.0

func _init() -> void:
	theme = _THEME
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	_build_dim_background()
	_build_panel()


# ============================================
# Layout
# ============================================

func _build_dim_background() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.75)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)


func _build_panel() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = _PANEL_BG
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(28)
	sb.border_color = Color(_ACCENT.r, _ACCENT.g, _ACCENT.b, 0.25)
	sb.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", _ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var audio_header := _section_header("AUDIO")
	vbox.add_child(audio_header)

	for key in AudioSettings.VOLUME_KEYS:
		vbox.add_child(_build_volume_row(key))

	vbox.add_child(_hsep())

	_reset_button = Button.new()
	_reset_button.text = "Reset Progress"
	_reset_button.custom_minimum_size = Vector2(0, TOUCH_TARGET)
	_reset_button.add_theme_color_override("font_color", _DANGER)
	_reset_button.pressed.connect(_on_reset_pressed)
	vbox.add_child(_reset_button)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(0, TOUCH_TARGET)
	close_button.pressed.connect(_on_close_pressed)
	vbox.add_child(close_button)


func _section_header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(_ACCENT.r, _ACCENT.g, _ACCENT.b, 0.55))
	return label


func _hsep() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	return sep


func _build_volume_row(key: StringName) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_label := Label.new()
	name_label.text = AudioSettings.label_for(key)
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", _MUTED)
	name_label.custom_minimum_size = Vector2(90, 0)
	row.add_child(name_label)

	var slider := HSlider.new()
	# Thumb-sized grab area; the visual track stays thin.
	slider.custom_minimum_size = Vector2(0, TOUCH_TARGET)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = AudioSettings.get_volume(key)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_FILL
	slider.value_changed.connect(_on_volume_changed.bind(key))
	row.add_child(slider)

	var value_label := Label.new()
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.add_theme_color_override("font_color", _MUTED)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(44, 0)
	value_label.text = _percent(slider.value)
	row.add_child(value_label)
	_value_labels[key] = value_label

	return row


func _percent(linear: float) -> String:
	return "%d%%" % int(round(linear * 100.0))


# ============================================
# Signals
# ============================================

func _on_volume_changed(value: float, key: StringName) -> void:
	AudioSettings.set_volume(key, value)
	if _value_labels.has(key):
		var label: Label = _value_labels[key]
		label.text = _percent(value)


func _on_reset_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_button.text = "Tap again to confirm"
		# Disarm after a short window if they don't confirm.
		var timer := get_tree().create_timer(3.0)
		timer.timeout.connect(_disarm_reset)
		return
	PersistedData.wipe_progress()
	_reset_armed = false
	_reset_button.text = "Progress Reset"
	_reset_button.disabled = true


func _disarm_reset() -> void:
	if not is_instance_valid(self) or _reset_button == null:
		return
	if _reset_armed:
		_reset_armed = false
		_reset_button.text = "Reset Progress"


func _on_close_pressed() -> void:
	PersistedData.save_data()
	queue_free()
