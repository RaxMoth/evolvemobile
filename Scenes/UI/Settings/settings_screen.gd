class_name SettingsScreen
extends Control

## SettingsScreen — full-screen overlay for audio volumes, language, screen
## shake, privacy and progress reset.
##
## Built entirely in code (no .tscn) so it can be dropped in from any menu with
## `add_child(SettingsScreen.new())`. Volume sliders drive the audio buses live
## through AudioSettings and persist on close; the reset button clears the save
## via PersistedData.wipe_progress() behind a two-tap confirm.
##
## Its look is the Jungle Guild theme's: the sheet panel and label / button
## variations, and the palette's scrim and danger tokens (no colour literals).

const _THEME: Theme = preload("res://Scenes/UI/Theme/ui_theme.tres")
## Alpha of the bg_void scrim behind the sheet (the UnlockSheet's).
const SCRIM_ALPHA := 0.72

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
	dim.color = Color(UiPalette.get_default().bg_void, SCRIM_ALPHA)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)


func _build_panel() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	panel.theme_type_variation = &"SheetPanel"
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = tr("SETTINGS")
	title.theme_type_variation = &"HeaderSmall"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var audio_header := _section_header(tr("AUDIO"))
	vbox.add_child(audio_header)

	for key in AudioSettings.VOLUME_KEYS:
		vbox.add_child(_build_volume_row(key))

	vbox.add_child(_hsep())
	vbox.add_child(_section_header(tr("LANGUAGE")))
	vbox.add_child(_build_language_row())
	vbox.add_child(_hsep())
	vbox.add_child(_section_header(tr("DISPLAY")))
	vbox.add_child(_build_shake_row())
	vbox.add_child(_hsep())
	vbox.add_child(_section_header(tr("PRIVACY")))
	vbox.add_child(_build_analytics_row())
	vbox.add_child(_hsep())

	_reset_button = Button.new()
	_reset_button.text = tr("Reset Progress")
	_reset_button.custom_minimum_size = Vector2(0, TOUCH_TARGET)
	_reset_button.add_theme_color_override("font_color", UiPalette.get_default().danger)
	_reset_button.pressed.connect(_on_reset_pressed)
	vbox.add_child(_reset_button)

	var close_button := Button.new()
	close_button.text = tr("Close")
	close_button.custom_minimum_size = Vector2(0, TOUCH_TARGET)
	close_button.theme_type_variation = &"ButtonPrimary"
	close_button.pressed.connect(_on_close_pressed)
	vbox.add_child(close_button)


func _section_header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"Caption"
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
	name_label.theme_type_variation = &"BodyDim"
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
	value_label.theme_type_variation = &"Caption"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(44, 0)
	value_label.text = _percent(slider.value)
	row.add_child(value_label)
	_value_labels[key] = value_label

	return row


func _build_language_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var label := Label.new()
	label.text = tr("Language")
	label.theme_type_variation = &"BodyDim"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(160, TOUCH_TARGET)
	for choice_label in LocaleSettings.CHOICE_LABELS:
		picker.add_item(tr(choice_label))
	picker.select(LocaleSettings.choice_index())
	picker.item_selected.connect(_on_language_selected)
	row.add_child(picker)
	return row


func _on_language_selected(idx: int) -> void:
	LocaleSettings.set_choice_index(idx)
	# Scene-side labels re-translate automatically; this panel is built in
	# code, so rebuild it to pick up the new language immediately.
	_rebuild()


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_value_labels.clear()
	_reset_armed = false
	_build_dim_background()
	_build_panel()


## The match camera's screen shake (GameCamera reads the setting on every
## shake, so it applies from the next hit on).
func _build_shake_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var label := Label.new()
	label.text = tr("Screen shake")
	label.theme_type_variation = &"BodyDim"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var toggle := CheckButton.new()
	toggle.custom_minimum_size = Vector2(0, TOUCH_TARGET)
	toggle.button_pressed = GameCamera.shake_setting_on()
	toggle.toggled.connect(_on_shake_toggled)
	row.add_child(toggle)
	return row


func _on_shake_toggled(enabled: bool) -> void:
	GameCamera.set_shake_setting(enabled)


func _build_analytics_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var label := Label.new()
	label.text = tr("Usage statistics")
	label.theme_type_variation = &"BodyDim"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.tooltip_text = tr("Stored only on this device (user://analytics.jsonl). Nothing is uploaded.")
	row.add_child(label)

	var toggle := CheckButton.new()
	toggle.custom_minimum_size = Vector2(0, TOUCH_TARGET)
	toggle.button_pressed = AnalyticsSink.is_enabled()
	toggle.toggled.connect(_on_analytics_toggled)
	row.add_child(toggle)
	return row


func _on_analytics_toggled(enabled: bool) -> void:
	AnalyticsSink.set_opt_out(not enabled)


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
		_reset_button.text = tr("Tap again to confirm")
		# Disarm after a short window if they don't confirm.
		var timer := get_tree().create_timer(3.0)
		timer.timeout.connect(_disarm_reset)
		return
	PersistedData.wipe_progress()
	_reset_armed = false
	_reset_button.text = tr("Progress Reset")
	_reset_button.disabled = true


func _disarm_reset() -> void:
	if not is_instance_valid(self) or _reset_button == null:
		return
	if _reset_armed:
		_reset_armed = false
		_reset_button.text = tr("Reset Progress")


func _on_close_pressed() -> void:
	PersistedData.save_data()
	queue_free()
