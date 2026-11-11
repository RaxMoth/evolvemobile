class_name PauseMenu
extends Control

## The match's pause menu (a MatchHud child, process_mode ALWAYS in
## PauseMenu.tscn so it works on the paused tree). The HUD's Pause button, the
## Escape key and the Android back button (ui_cancel) open it; it pauses the
## tree while it is up:
##   - RESUME (or ui_cancel again) closes it and unpauses;
##   - SETTINGS opens the SettingsScreen sheet over it (back closes the sheet
##     first);
##   - QUIT TO LOBBY asks for a second tap (a ConfirmButton: armed for 3 s,
##     and the confirming tap counts only ConfirmButton.MIN_GAP after the
##     first, so one double tap never forfeits the match; the match pays
##     nothing), then leaves for the menu (lobby_scene_path); World's exit
##     stops the match clock (GameManager.abort_match). Opening the menu
##     disarms it.
## Theme variations only (PanelLeafy, HeaderLarge, BodyDim, ButtonPrimary,
## Button, ButtonMonster); the scrim takes the palette's bg_void. Every
## connection is in PauseMenu.tscn.

signal opened
signal resumed
signal quit_requested

const SETTINGS_SCENE: PackedScene = preload("res://Scenes/UI/Settings/SettingsScreen.tscn")
## Alpha of the bg_void scrim (the UnlockSheet's).
const SCRIM_ALPHA := 0.72

## Where QUIT TO LOBBY goes: the menu's main scene.
@export_file("*.tscn") var lobby_scene_path: String = "res://Scenes/UI/Screens/MenuRoot.tscn"
## False: QUIT only emits quit_requested and the scene stays (tests).
@export var changes_scene: bool = true

var _leaving: bool = false
var _settings: SettingsScreen = null

@onready var _scrim: ColorRect = %Scrim
@onready var _quit: ConfirmButton = %Quit
@onready var _hint: Label = %Hint


func _ready() -> void:
	_scrim.color = Color(UiPalette.get_default().bg_void, SCRIM_ALPHA)


func is_open() -> bool:
	return visible


## Shows the menu and pauses the match.
func open() -> void:
	if visible:
		return
	_quit.disarm()
	visible = true
	get_tree().paused = true
	opened.emit()


## Closes the menu (and an open settings sheet) and unpauses.
func resume() -> void:
	if not visible:
		return
	if is_instance_valid(_settings):
		_settings.queue_free()
	_settings = null
	visible = false
	get_tree().paused = false
	resumed.emit()


## The settings sheet over the menu, or null.
func settings() -> SettingsScreen:
	return _settings if is_instance_valid(_settings) and not _settings.is_closing() else null


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		resume()


# --- scene-side connections (PauseMenu.tscn) ---

func _on_resume_pressed() -> void:
	resume()


func _on_settings_pressed() -> void:
	if settings() != null:
		return
	_settings = SETTINGS_SCENE.instantiate() as SettingsScreen
	add_child(_settings)


## QUIT armed (its first tap) or disarmed (no second tap in time, the menu
## opened again).
func _on_quit_armed_changed(armed: bool) -> void:
	_quit.text = tr("Tap again to leave") if armed else tr("Quit to lobby")
	_hint.visible = armed


## The second tap: the match is forfeited.
func _on_quit_confirmed() -> void:
	if _leaving:
		return
	_leaving = true
	quit_requested.emit()
	AnalyticsSink.track(&"match_quit", {"elapsed": snappedf(GameManager.get_match_elapsed(), 0.1)})
	if not changes_scene:
		return
	get_tree().paused = false
	# Deferred: never free our own UI from inside its own input callback.
	get_tree().change_scene_to_file.call_deferred(lobby_scene_path)
