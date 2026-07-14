class_name AudioSettings
extends RefCounted

## AudioSettings — maps saved volume settings onto the project's audio buses.
##
## Pure static helpers; no node or instance needed. Volumes are stored as a
## linear 0.0–1.0 value in PersistedData's [settings] section and converted to
## decibels for the AudioServer. The bus layout (Master / Music / SFX) lives in
## `res://default_bus_layout.tres`.

const MASTER_BUS: StringName = &"Master"
const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"

# Setting keys (PersistedData [settings]).
const KEY_MASTER: StringName = &"master_volume"
const KEY_MUSIC: StringName = &"music_volume"
const KEY_SFX: StringName = &"sfx_volume"

const VOLUME_KEYS: Array[StringName] = [KEY_MASTER, KEY_MUSIC, KEY_SFX]
const DEFAULT_VOLUME := 0.8


## Human-facing label for a volume key (used by the settings UI).
static func label_for(key: StringName) -> String:
	match key:
		KEY_MUSIC: return "Music"
		KEY_SFX: return "Effects"
		_: return "Master"


static func _bus_for(key: StringName) -> StringName:
	match key:
		KEY_MUSIC: return MUSIC_BUS
		KEY_SFX: return SFX_BUS
		_: return MASTER_BUS


## Reads every saved volume and applies it to its bus. Call once at startup.
static func apply_saved() -> void:
	for key in VOLUME_KEYS:
		apply_volume(key, get_volume(key))


## Current saved linear volume (0..1) for a key, falling back to the default.
static func get_volume(key: StringName) -> float:
	return clampf(float(PersistedData.get_setting(key, DEFAULT_VOLUME)), 0.0, 1.0)


## Applies a linear volume to the matching bus without persisting it (used for
## live slider feedback).
static func apply_volume(key: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(_bus_for(key))
	if idx < 0:
		return
	linear = clampf(linear, 0.0, 1.0)
	# A true 0 maps to -inf dB; mute the bus instead so it fully silences.
	AudioServer.set_bus_mute(idx, linear <= 0.0)
	if linear > 0.0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))


## Persists and applies a volume change from the settings UI.
static func set_volume(key: StringName, linear: float) -> void:
	linear = clampf(linear, 0.0, 1.0)
	PersistedData.set_setting(key, linear)
	apply_volume(key, linear)
