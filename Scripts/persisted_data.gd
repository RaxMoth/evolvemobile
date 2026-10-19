extends Node

## PersistedData — single source of truth for all save data.
##
## Backed by ConfigFile at `user://save.cfg`. Sections:
##   [meta]      total_matches, last_played_iso, save_version
##   [currency]  steel, leaves, gold
##   [hero_xp]   river, vlad, ted, irelia (per-character permanent XP)
##   [skills]    <tree_id> = ["skill_id_1", "skill_id_2", ...]
##   [settings]  music_volume, sfx_volume, etc.
##
## Loaded once at startup. Mutations go through helper methods so signals
## fire and so we never have stale reads. Save is explicit (call save()
## after meaningful changes) — we don't write on every set to avoid
## per-frame I/O when many things change in sequence.
##
## Versioning: [meta] save_version. On load, an older file is first copied to
## `save.cfg.v<N>.bak`, then walked up the `_migrate()` ladder one version at
## a time and re-saved. A file without a version key counts as v1 (the first
## shipped layout). Add a new `_migrate_vN_to_vN1()` step + bump
## CURRENT_SAVE_VERSION whenever the layout changes.

signal currency_changed(currency: StringName, new_amount: int)
signal hero_xp_changed(hero_id: StringName, new_xp: int)
signal monster_xp_changed(monster_id: StringName, new_xp: int)
signal data_loaded
signal data_saved

const SAVE_PATH := "user://save.cfg"
## v1: first shipped layout. v2: normalized types (ints for currency/XP,
## strings only in skill lists, volumes clamped) + [meta] created_unix.
const CURRENT_SAVE_VERSION := 2

# --- Permanent-level curve ---
# Level starts at 1. The cost to advance from level L to L+1 is
# XP_PER_LEVEL_STEP * L, so cumulative XP grows quadratically
# (100, 300, 600, 1000, ...). Shared by heroes and the monster.
const XP_PER_LEVEL_STEP := 100

# --- Currency keys (used as ConfigFile keys + signal payloads) ---
const STEEL: StringName = &"steel"
const LEAVES: StringName = &"leaves"
const GOLD: StringName = &"gold"
const ALL_CURRENCIES: Array[StringName] = [STEEL, LEAVES, GOLD]

# --- Section names ---
const SECTION_META := "meta"
const SECTION_CURRENCY := "currency"
const SECTION_HERO_XP := "hero_xp"
const SECTION_MONSTER_XP := "monster_xp"
const SECTION_SKILLS := "skills"
const SECTION_SETTINGS := "settings"

var _config: ConfigFile = ConfigFile.new()
var _loaded: bool = false


func _ready() -> void:
	load_data()


# ============================================
# Load / save
# ============================================

func load_data() -> void:
	_config = ConfigFile.new()
	var err := _config.load(SAVE_PATH)
	if err == ERR_FILE_NOT_FOUND:
		# First run — write defaults.
		_seed_defaults()
		save_data()
	elif err != OK:
		# Keep the unreadable file around for the player instead of silently
		# overwriting it, then start fresh.
		push_warning("PersistedData: load failed (err %d) — starting fresh." % err)
		_backup_save("corrupt")
		_config = ConfigFile.new()
		_seed_defaults()
		save_data()
	else:
		var from_version := get_save_version()
		if from_version < CURRENT_SAVE_VERSION:
			_backup_save("v%d" % from_version)
			_migrate(from_version)
			save_data()
		elif from_version > CURRENT_SAVE_VERSION:
			push_warning("PersistedData: save is from a newer build (v%d, this build writes v%d)." % [from_version, CURRENT_SAVE_VERSION])
	_loaded = true
	# Push saved audio volumes onto the buses now that settings are available.
	AudioSettings.apply_saved()
	LocaleSettings.apply_saved()
	data_loaded.emit()


func save_data() -> void:
	_config.set_value(SECTION_META, "save_version", CURRENT_SAVE_VERSION)
	_config.set_value(SECTION_META, "last_saved_unix", int(Time.get_unix_time_from_system()))
	var err := _config.save(SAVE_PATH)
	if err != OK:
		push_error("PersistedData: save failed (err %d)" % err)
		return
	data_saved.emit()


func _seed_defaults() -> void:
	for c in ALL_CURRENCIES:
		_config.set_value(SECTION_CURRENCY, c, 0)
	_config.set_value(SECTION_META, "total_matches", 0)
	_config.set_value(SECTION_META, "save_version", CURRENT_SAVE_VERSION)
	_config.set_value(SECTION_META, "created_unix", int(Time.get_unix_time_from_system()))


## Version stamp of the loaded file. A file without the key is a v1 save
## (written before versioning was enforced); 0 means nothing is loaded.
func get_save_version() -> int:
	if not _config.has_section_key(SECTION_META, "save_version"):
		return 1 if _config.get_sections().size() > 0 else 0
	return int(_config.get_value(SECTION_META, "save_version", 1))


# ============================================
# Migration
# ============================================

## Copies the current save file next to itself (`save.cfg.<tag>.bak`) before a
## migration or after a failed load. Never throws; a failed backup only warns.
func _backup_save(tag: String) -> void:
	var src := ProjectSettings.globalize_path(SAVE_PATH)
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var dst := ProjectSettings.globalize_path("%s.%s.bak" % [SAVE_PATH, tag])
	var err := DirAccess.copy_absolute(src, dst)
	if err != OK:
		push_warning("PersistedData: could not back up save to %s (err %d)" % [dst, err])


## Walks the save up one version at a time. Each step must be idempotent and
## tolerant of missing keys: a v0/v1 file may predate half the sections.
func _migrate(from_version: int) -> void:
	var v := maxi(from_version, 1)
	if v < 2:
		_migrate_v1_to_v2()
		v = 2
	# if v < 3:
	# 	_migrate_v2_to_v3()
	# 	v = 3
	_config.set_value(SECTION_META, "save_version", CURRENT_SAVE_VERSION)


## v1 → v2: normalize types the first builds wrote loosely (floats / strings
## for currency and XP, mixed-type skill arrays, out-of-range volumes) and
## stamp created_unix so stats screens can show "playing since".
func _migrate_v1_to_v2() -> void:
	for c in ALL_CURRENCIES:
		_config.set_value(SECTION_CURRENCY, c, _as_non_negative_int(_config.get_value(SECTION_CURRENCY, c, 0)))
	for section in [SECTION_HERO_XP, SECTION_MONSTER_XP]:
		if _config.has_section(section):
			for key in _config.get_section_keys(section):
				_config.set_value(section, key, _as_non_negative_int(_config.get_value(section, key, 0)))
	if _config.has_section(SECTION_SKILLS):
		for tree_id in _config.get_section_keys(SECTION_SKILLS):
			var raw: Variant = _config.get_value(SECTION_SKILLS, tree_id, [])
			var cleaned: Array = []
			if raw is Array:
				for entry in raw:
					if (entry is String or entry is StringName) and not cleaned.has(String(entry)):
						cleaned.append(String(entry))
			_config.set_value(SECTION_SKILLS, tree_id, cleaned)
	for key in AudioSettings.VOLUME_KEYS:
		if _config.has_section_key(SECTION_SETTINGS, key):
			var vol: Variant = _config.get_value(SECTION_SETTINGS, key, AudioSettings.DEFAULT_VOLUME)
			var as_float: float = float(vol) if (vol is float or vol is int) else AudioSettings.DEFAULT_VOLUME
			_config.set_value(SECTION_SETTINGS, key, clampf(as_float, 0.0, 1.0))
	_config.set_value(SECTION_META, "total_matches", _as_non_negative_int(_config.get_value(SECTION_META, "total_matches", 0)))
	if not _config.has_section_key(SECTION_META, "created_unix"):
		var first_seen: Variant = _config.get_value(SECTION_META, "last_saved_unix", int(Time.get_unix_time_from_system()))
		_config.set_value(SECTION_META, "created_unix", _as_non_negative_int(first_seen))


static func _as_non_negative_int(value: Variant) -> int:
	if value is int:
		return maxi(value, 0)
	if value is float:
		return maxi(int(round(value)), 0)
	if value is String and (value as String).is_valid_int():
		return maxi((value as String).to_int(), 0)
	return 0


## Reset Progress: clears currency, XP, skills and match counters but KEEPS the
## [settings] section (volumes, language, analytics opt-out, tutorial flag,
## last match strategy) — those are device preferences, not progress.
## `keep_settings = false` is the factory reset the tests use.
func wipe_progress(keep_settings: bool = true) -> void:
	var kept: Dictionary = {}
	if keep_settings and _config.has_section(SECTION_SETTINGS):
		for key in _config.get_section_keys(SECTION_SETTINGS):
			kept[key] = _config.get_value(SECTION_SETTINGS, key)
	_config = ConfigFile.new()
	_seed_defaults()
	for key in kept:
		_config.set_value(SECTION_SETTINGS, key, kept[key])
	save_data()
	for c in ALL_CURRENCIES:
		currency_changed.emit(c, 0)


# ============================================
# Currency
# ============================================

func get_currency(currency: StringName) -> int:
	return int(_config.get_value(SECTION_CURRENCY, currency, 0))


func add_currency(currency: StringName, amount: int) -> void:
	if amount <= 0:
		return
	var new_total := get_currency(currency) + amount
	_config.set_value(SECTION_CURRENCY, currency, new_total)
	currency_changed.emit(currency, new_total)


func spend_currency(currency: StringName, amount: int) -> bool:
	if amount <= 0:
		return true
	var current := get_currency(currency)
	if current < amount:
		return false
	var new_total := current - amount
	_config.set_value(SECTION_CURRENCY, currency, new_total)
	currency_changed.emit(currency, new_total)
	return true


func can_afford(currency: StringName, amount: int) -> bool:
	return get_currency(currency) >= amount


# ============================================
# Per-hero permanent XP
# ============================================

func get_hero_xp(hero_id: StringName) -> int:
	return int(_config.get_value(SECTION_HERO_XP, hero_id, 0))


func add_hero_xp(hero_id: StringName, amount: int) -> void:
	if amount <= 0:
		return
	var new_total := get_hero_xp(hero_id) + amount
	_config.set_value(SECTION_HERO_XP, hero_id, new_total)
	hero_xp_changed.emit(hero_id, new_total)


func get_monster_xp(monster_id: StringName) -> int:
	return int(_config.get_value(SECTION_MONSTER_XP, monster_id, 0))


func add_monster_xp(monster_id: StringName, amount: int) -> void:
	if amount <= 0:
		return
	var new_total := get_monster_xp(monster_id) + amount
	_config.set_value(SECTION_MONSTER_XP, monster_id, new_total)
	monster_xp_changed.emit(monster_id, new_total)


# ============================================
# Level curve (derived from permanent XP)
# ============================================

## Highest level fully reached with `total_xp` (level 1 at 0 XP).
func level_from_xp(total_xp: int) -> int:
	return level_progress(total_xp).level


## Breaks a raw XP total into its level and progress toward the next level.
## Returns {level: int, into: int, needed: int} where `into` is XP earned
## inside the current level and `needed` is the cost of the next level.
func level_progress(total_xp: int) -> Dictionary:
	var level := 1
	var remaining := maxi(total_xp, 0)
	var cost := XP_PER_LEVEL_STEP
	while remaining >= cost:
		remaining -= cost
		level += 1
		cost = XP_PER_LEVEL_STEP * level
	return {"level": level, "into": remaining, "needed": cost}


# ============================================
# Skill-tree unlocks
# ============================================

func get_unlocked_skills(tree_id: StringName) -> Array:
	## Returns Array[String]; empty if no saved data.
	return _config.get_value(SECTION_SKILLS, tree_id, []) as Array


func set_unlocked_skills(tree_id: StringName, ids: Array) -> void:
	_config.set_value(SECTION_SKILLS, tree_id, ids)


# ============================================
# Settings (audio volumes, controls, etc.)
# ============================================

func get_setting(key: StringName, default_value: Variant = null) -> Variant:
	return _config.get_value(SECTION_SETTINGS, key, default_value)


func set_setting(key: StringName, value: Variant) -> void:
	_config.set_value(SECTION_SETTINGS, key, value)


# ============================================
# Match counter (used by stats screens)
# ============================================

func is_loaded() -> bool:
	return _loaded


func get_total_matches() -> int:
	return int(_config.get_value(SECTION_META, "total_matches", 0))


func record_match_played() -> void:
	_config.set_value(SECTION_META, "total_matches", get_total_matches() + 1)
