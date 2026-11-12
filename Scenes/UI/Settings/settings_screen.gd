class_name SettingsScreen
extends Control

## The settings sheet: it slides up from the bottom over a bg_void scrim, the
## UnlockSheet's way, from the lobby's gear (MenuRoot) and from the match's
## pause menu (PauseMenu). SettingsScreen.tscn holds the whole layout and its
## wiring; this script only reads and writes the settings:
##   - AUDIO: a slider per volume key (AudioSettings.VOLUME_KEYS, bound to the
##     key in the scene); the buses follow live, the save on close;
##   - LANGUAGE: System / English / Deutsch (LocaleSettings); the scene's
##     labels re-translate themselves, the picker's items are refilled;
##   - DISPLAY: the match camera's screen shake (GameCamera reads the setting
##     on every shake);
##   - PRIVACY: the local usage statistics (AnalyticsSink opt-out);
##   - RESET PROGRESS wipes the save (PersistedData.wipe_progress) behind a
##     second tap (a ConfirmButton: armed for 3 s, and the confirming tap
##     counts only ConfirmButton.MIN_GAP after the first, so one double tap
##     never wipes); the lobby's sheet only (allow_reset: the pause menu's
##     sheet has no reset, a running match would pay into the wiped save);
##   - CLOSE, the round close button, a tap on the scrim and ui_cancel (the
##     Android back button) save and close it.
## While it slides up it holds its TapGuard: the second tap of the double tap
## that opened it never closes it on the scrim.
## The look is theme variations only (SheetPanel, HeaderLarge, Caption,
## PanelInset, BodyDim, HintLabel, ButtonRound, ButtonMonster, ButtonPrimary);
## the scrim takes the palette's bg_void.

## The sheet was closed (it frees itself right after).
signal closed

## Alpha of the bg_void scrim behind the sheet (the UnlockSheet's).
const SCRIM_ALPHA := 0.72
const SLIDE_TIME := 0.22

## Offers RESET PROGRESS. The pause menu turns it off before adding the sheet:
## no reset in a running match.
@export var allow_reset: bool = true

var _closing: bool = false

@onready var _scrim: ColorRect = %Scrim
## The sheet's holder (full rect, the sheet anchored to its bottom): it slides.
@onready var _slide: Control = %Slide
@onready var _language: OptionButton = %Language
@onready var _shake: CheckButton = %Shake
@onready var _analytics: CheckButton = %Analytics
@onready var _reset_button: ConfirmButton = %Reset
@onready var _tap_guard: TapGuard = %TapGuard
## The volume sliders and their percentages by setting key (each slider's
## value_changed is bound to its key in the scene).
@onready var _sliders: Dictionary[StringName, HSlider] = {
	AudioSettings.KEY_MASTER: %Master,
	AudioSettings.KEY_MUSIC: %Music,
	AudioSettings.KEY_SFX: %Effects,
}
@onready var _values: Dictionary[StringName, Label] = {
	AudioSettings.KEY_MASTER: %MasterValue,
	AudioSettings.KEY_MUSIC: %MusicValue,
	AudioSettings.KEY_SFX: %EffectsValue,
}


func _ready() -> void:
	_scrim.color = Color(UiPalette.get_default().bg_void, SCRIM_ALPHA)
	for key: StringName in _sliders:
		var volume := _sliders[key]
		volume.set_value_no_signal(AudioSettings.get_volume(key))
		_values[key].text = percent(volume.value)
	_fill_languages()
	_shake.set_pressed_no_signal(GameCamera.shake_setting_on())
	_analytics.set_pressed_no_signal(AnalyticsSink.is_enabled())
	_reset_button.visible = allow_reset
	_slide_in()


## "80%" for 0.8.
static func percent(linear: float) -> String:
	return "%d%%" % int(round(linear * 100.0))


## The volume slider of a setting key (AudioSettings.KEY_*), or null.
func slider(key: StringName) -> HSlider:
	return _sliders[key] if _sliders.has(key) else null


## Saves the settings and slides the sheet away (it frees itself).
func close() -> void:
	if _closing:
		return
	_closing = true
	PersistedData.save_data()
	closed.emit()
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(_slide, ^"position:y", size.y, SLIDE_TIME)
	t.tween_property(_scrim, ^"modulate:a", 0.0, SLIDE_TIME)
	t.chain().tween_callback(queue_free)


func is_closing() -> bool:
	return _closing


func _slide_in() -> void:
	_tap_guard.hold(SLIDE_TIME)
	_scrim.modulate.a = 0.0
	_slide.position.y = size.y
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_scrim, ^"modulate:a", 1.0, SLIDE_TIME)
	t.tween_property(_slide, ^"position:y", 0.0, SLIDE_TIME)


func _fill_languages() -> void:
	_language.clear()
	for choice_label in LocaleSettings.CHOICE_LABELS:
		_language.add_item(tr(choice_label))
	_language.select(LocaleSettings.choice_index())


## The scene's labels re-translate on their own; the picker's items and the
## reset button's state text are ours.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_fill_languages()
		_show_reset_text()


func _show_reset_text() -> void:
	if _reset_button.disabled:
		_reset_button.text = tr("Progress Reset")
	elif _reset_button.is_armed():
		_reset_button.text = tr("Tap again to confirm")
	else:
		_reset_button.text = tr("Reset Progress")


func _unhandled_input(event: InputEvent) -> void:
	if not _closing and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


# --- scene-side connections (SettingsScreen.tscn) ---

func _on_volume_changed(value: float, key: StringName) -> void:
	AudioSettings.set_volume(key, value)
	if _values.has(key):
		_values[key].text = percent(value)


func _on_language_selected(idx: int) -> void:
	LocaleSettings.set_choice_index(idx)


func _on_shake_toggled(enabled: bool) -> void:
	GameCamera.set_shake_setting(enabled)


func _on_analytics_toggled(enabled: bool) -> void:
	AnalyticsSink.set_opt_out(not enabled)


## RESET PROGRESS armed (its first tap) or disarmed (no second tap in time).
func _on_reset_armed_changed(_armed: bool) -> void:
	_show_reset_text()


## The second tap: the save is wiped and the button is done.
func _on_reset_confirmed() -> void:
	PersistedData.wipe_progress()
	_reset_button.disabled = true
	_show_reset_text()


func _on_close_pressed() -> void:
	close()


func _on_scrim_gui_input(event: InputEvent) -> void:
	var tap := event as InputEventMouseButton
	if tap != null and tap.pressed and tap.button_index == MOUSE_BUTTON_LEFT:
		close()
