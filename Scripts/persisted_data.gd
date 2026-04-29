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

signal currency_changed(currency: StringName, new_amount: int)
signal hero_xp_changed(hero_id: StringName, new_xp: int)
signal data_loaded
signal data_saved

const SAVE_PATH := "user://save.cfg"
const CURRENT_SAVE_VERSION := 1

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
	var err := _config.load(SAVE_PATH)
	if err == ERR_FILE_NOT_FOUND:
		# First run — write defaults.
		_seed_defaults()
		save_data()
	elif err != OK:
		push_warning("PersistedData: load failed (err %d) — starting fresh." % err)
		_seed_defaults()
	_loaded = true
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


## Deletes the save and re-seeds defaults. Used by a future "reset progress"
## button in the settings menu.
func wipe_progress() -> void:
	_config = ConfigFile.new()
	_seed_defaults()
	save_data()


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

func get_total_matches() -> int:
	return int(_config.get_value(SECTION_META, "total_matches", 0))


func record_match_played() -> void:
	_config.set_value(SECTION_META, "total_matches", get_total_matches() + 1)
