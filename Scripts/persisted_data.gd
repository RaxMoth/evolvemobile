extends Node

## PersistedData — single source of truth for all save data.
##
## Backed by ConfigFile at `user://save.cfg`. Sections:
##   [meta]      total_matches, last_played_iso, save_version
##   [currency]  steel, leaves, gold
##   [hero_xp]   river, vlad, ted, irelia (per-character permanent XP)
##   [skill_ranks] <tree_id> = {"skill_id_1": 1, "skill_id_2": 3, ...}  (v3+)
##   [capstones] <tree_id> = "node_id"  (v3+; the tree's equipped capstone)
##   [monsters]  owned = ["nyxa", ...]  the locked monsters the player bought
##               (CharacterProgress.unlock; a roster def's unlocked_by_default
##               monster, Grount, is owned without an entry), last_quarry (the
##               monster the heroes hunted last), locked_quarry (the one the
##               pre-round Change picker fixed; "" = random)
##   [codex]     monsters = ["grount", ...]  the quarries the heroes have met
##               (their Codex entries; GameManager.begin_hunt adds them),
##               monsters_seen = N  the monster pages the player has seen
##               (the Codex's "new page" dot counts from here; with the Codex,
##               so Reset Progress clears it)
##   [settings]  music_volume, sfx_volume, etc.
## ([skills] <tree_id> = ["skill_id", ...] was the v1/v2 layout: every listed id
##  migrates to rank 1, so no purchase is lost or re-priced.) [monsters] and
## [codex] need no migration: a save without them owns no bought monster and
## has met no quarry yet.
##
## Loaded once at startup. Mutations go through helper methods so signals
## fire and so we never have stale reads. Save is explicit (call save_data()
## after meaningful changes) — we don't write on every set to avoid
## per-frame I/O when many things change in sequence. Unsaved changes are
## still flushed when the app is paused (backgrounded) or asked to close.
##
## Atomic save: save_data() writes `save.cfg.tmp` and renames it over
## `save.cfg`, so a kill mid-write leaves the previous save intact. If
## `save.cfg` is missing or unreadable on load but the tmp file parses, the
## tmp file (a finished write whose rename never happened) is moved into place.
##
## Versioning: [meta] save_version. On load, an older file is first copied to
## `save.cfg.v<N>.bak`, then walked up the `_migrate()` ladder one version at
## a time and re-saved. A file without a version key counts as v1 (the first
## shipped layout). Add a new `_migrate_vN_to_vN1()` step + bump
## CURRENT_SAVE_VERSION whenever the layout changes.

signal currency_changed(currency: StringName, new_amount: int)
signal hero_xp_changed(hero_id: StringName, new_xp: int)
signal monster_xp_changed(monster_id: StringName, new_xp: int)
## A locked monster joined [monsters] owned (a purchase).
signal monster_owned(monster_id: StringName)
signal data_loaded
signal data_saved

const SAVE_PATH := "user://save.cfg"
const TMP_SAVE_PATH := "user://save.cfg.tmp"
## v1: first shipped layout. v2: normalized types (ints for currency/XP,
## strings only in skill lists, volumes clamped) + [meta] created_unix.
## v3: ranked skill nodes: the [skills] id lists become [skill_ranks] id -> rank
## (every owned id at rank 1); [capstones] holds each tree's equipped capstone.
const CURRENT_SAVE_VERSION := 3

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
const SECTION_SKILLS := "skills"  ## v1/v2 only: read by the v2 -> v3 migration.
const SECTION_SKILL_RANKS := "skill_ranks"
const SECTION_CAPSTONES := "capstones"
const SECTION_MONSTERS := "monsters"
const SECTION_CODEX := "codex"
const SECTION_SETTINGS := "settings"
## Codex kinds (keys of [codex]).
const CODEX_MONSTERS: StringName = &"monsters"

var _config: ConfigFile = ConfigFile.new()
var _loaded: bool = false
## Memory holds changes the file does not have yet: set by every mutator,
## cleared by a successful save_data().
var _dirty: bool = false


func _ready() -> void:
	load_data()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _dirty:
			save_data()


# ============================================
# Load / save
# ============================================

func load_data() -> void:
	_config = ConfigFile.new()
	_dirty = false
	var err := _config.load(SAVE_PATH)
	if err != OK and _recover_tmp_save(err):
		err = OK
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
	# ConfigFile.save() truncates the file before writing it, so never point
	# it at the live save: write the sibling, then swap it in with one rename.
	var err := _config.save(TMP_SAVE_PATH)
	if err != OK:
		push_error("PersistedData: save failed (err %d)" % err)
		return
	err = DirAccess.rename_absolute(ProjectSettings.globalize_path(TMP_SAVE_PATH), ProjectSettings.globalize_path(SAVE_PATH))
	if err != OK:
		# The finished write stays in the tmp file; load_data() falls back to
		# it if save.cfg is gone or unreadable.
		push_error("PersistedData: could not move %s over %s (err %d)" % [TMP_SAVE_PATH, SAVE_PATH, err])
		return
	_dirty = false
	data_saved.emit()


## After save.cfg failed to load with `load_err`: if the tmp file of a save
## whose rename never happened parses, move it into place and use it as
## _config. The unreadable save.cfg (if any) is backed up first. Returns false,
## leaving _config alone, when there is nothing to recover.
func _recover_tmp_save(load_err: Error) -> bool:
	if not FileAccess.file_exists(TMP_SAVE_PATH):
		return false
	var recovered := ConfigFile.new()
	if recovered.load(TMP_SAVE_PATH) != OK:
		return false
	push_warning("PersistedData: save.cfg unreadable (err %d) — recovering %s." % [load_err, TMP_SAVE_PATH])
	if load_err != ERR_FILE_NOT_FOUND:
		_backup_save("corrupt")
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(TMP_SAVE_PATH), ProjectSettings.globalize_path(SAVE_PATH))
	if err != OK:
		# Still play on the recovered data; the next save_data() retries the move.
		push_error("PersistedData: could not move %s over %s (err %d)" % [TMP_SAVE_PATH, SAVE_PATH, err])
		_dirty = true
	_config = recovered
	return true


func _seed_defaults() -> void:
	_dirty = true
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
	if v < 3:
		_migrate_v2_to_v3()
		v = 3
	# if v < 4:
	# 	_migrate_v3_to_v4()
	# 	v = 4
	_config.set_value(SECTION_META, "save_version", CURRENT_SAVE_VERSION)
	_dirty = true


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


## v2 → v3: every unlocked id becomes rank 1 of its (now ranked) node, so the
## save plays exactly as before (rank 1 has the old value). Ids are kept
## verbatim, even ones no tree defines any more: a node renamed or removed later
## must not silently eat the purchase (MetaSkillManager ignores unknown ids).
## Idempotent: an id already in [skill_ranks] keeps its rank. The old [skills]
## section is dropped; get_unlocked_skills() is its view now. No [capstones]
## key is written: a tree without one equips its first owned capstone
## (MetaSkillManager.equipped_capstone), so Titan Form owners keep it.
func _migrate_v2_to_v3() -> void:
	if not _config.has_section(SECTION_SKILLS):
		return
	for tree_id: String in _config.get_section_keys(SECTION_SKILLS):
		var raw: Variant = _config.get_value(SECTION_SKILLS, tree_id, [])
		var ranks: Dictionary = {}
		var existing: Variant = _config.get_value(SECTION_SKILL_RANKS, tree_id, {})
		if existing is Dictionary:
			ranks = (existing as Dictionary).duplicate()
		if raw is Array:
			for entry: Variant in raw:
				if (entry is String or entry is StringName) and not ranks.has(String(entry)):
					ranks[String(entry)] = 1
		if not ranks.is_empty():
			_config.set_value(SECTION_SKILL_RANKS, tree_id, ranks)
	_config.erase_section(SECTION_SKILLS)


static func _as_non_negative_int(value: Variant) -> int:
	if value is int:
		return maxi(value, 0)
	if value is float:
		return maxi(int(round(value)), 0)
	if value is String and (value as String).is_valid_int():
		return maxi((value as String).to_int(), 0)
	return 0


## Reset Progress: clears currency, XP, skill ranks, equipped capstones, the
## bought monsters, the quarry history, the Codex and match counters but KEEPS the [settings] section (volumes, language,
## analytics opt-out, tutorial flag, last match strategy) — those are device
## preferences, not progress.
## `keep_settings = false` is the factory reset the tests use.
func wipe_progress(keep_settings: bool = true) -> void:
	var kept: Dictionary = {}
	if keep_settings and _config.has_section(SECTION_SETTINGS):
		for key in _config.get_section_keys(SECTION_SETTINGS):
			kept[key] = _config.get_value(SECTION_SETTINGS, key)
	# Every id that had XP drops back to 0: tell the listeners (main menu
	# level rows and monster bar) after the save, as for currency.
	var hero_ids := _section_keys(SECTION_HERO_XP)
	var monster_ids := _section_keys(SECTION_MONSTER_XP)
	_config = ConfigFile.new()
	_seed_defaults()
	for key in kept:
		_config.set_value(SECTION_SETTINGS, key, kept[key])
	save_data()
	for c in ALL_CURRENCIES:
		currency_changed.emit(c, 0)
	for id in hero_ids:
		hero_xp_changed.emit(StringName(id), 0)
	for id in monster_ids:
		monster_xp_changed.emit(StringName(id), 0)


func _section_keys(section: String) -> PackedStringArray:
	return _config.get_section_keys(section) if _config.has_section(section) else PackedStringArray()


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
	_dirty = true
	currency_changed.emit(currency, new_total)


func spend_currency(currency: StringName, amount: int) -> bool:
	if amount <= 0:
		return true
	var current := get_currency(currency)
	if current < amount:
		return false
	var new_total := current - amount
	_config.set_value(SECTION_CURRENCY, currency, new_total)
	_dirty = true
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
	_dirty = true
	hero_xp_changed.emit(hero_id, new_total)


func get_monster_xp(monster_id: StringName) -> int:
	return int(_config.get_value(SECTION_MONSTER_XP, monster_id, 0))


func add_monster_xp(monster_id: StringName, amount: int) -> void:
	if amount <= 0:
		return
	var new_total := get_monster_xp(monster_id) + amount
	_config.set_value(SECTION_MONSTER_XP, monster_id, new_total)
	_dirty = true
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
# Skill-tree ranks (MetaSkillManager is the API)
# ============================================

## node id (String) -> rank (int >= 1) of every owned node of a tree. A copy:
## write back with set_skill_rank.
func get_skill_ranks(tree_id: StringName) -> Dictionary:
	var raw: Variant = _config.get_value(SECTION_SKILL_RANKS, tree_id, {})
	var out: Dictionary = {}
	if raw is Dictionary:
		var saved := raw as Dictionary
		for id: Variant in saved:
			var rank := int(saved[id])
			if rank >= 1:
				out[String(id)] = rank
	return out


## Ranks owned of one node; 0 = not owned.
func get_skill_rank(tree_id: StringName, node_id: StringName) -> int:
	var raw: Variant = _config.get_value(SECTION_SKILL_RANKS, tree_id, {})
	if raw is Dictionary:
		return maxi(int((raw as Dictionary).get(String(node_id), 0)), 0)
	return 0


## Rank 0 removes the node. Never saves by itself.
func set_skill_rank(tree_id: StringName, node_id: StringName, rank: int) -> void:
	var ranks := get_skill_ranks(tree_id)
	if rank <= 0:
		ranks.erase(String(node_id))
	else:
		ranks[String(node_id)] = rank
	_config.set_value(SECTION_SKILL_RANKS, tree_id, ranks)
	_dirty = true


## The pre-rank view, for callers that only care about "owned": the ids owned
## at rank >= 1 (Array of String).
func get_unlocked_skills(tree_id: StringName) -> Array:
	return get_skill_ranks(tree_id).keys()


## Own exactly `ids`: each at the rank already owned, else rank 1 (test
## fixtures and old callers).
func set_unlocked_skills(tree_id: StringName, ids: Array) -> void:
	var old := get_skill_ranks(tree_id)
	var ranks: Dictionary = {}
	for id: Variant in ids:
		ranks[String(id)] = maxi(1, int(old.get(String(id), 0)))
	_config.set_value(SECTION_SKILL_RANKS, tree_id, ranks)
	_dirty = true


## The capstone the player equipped in a tree, as saved; &"" when none was
## (MetaSkillManager.equipped_capstone resolves that to the first owned one).
func get_equipped_capstone(tree_id: StringName) -> StringName:
	return StringName(String(_config.get_value(SECTION_CAPSTONES, tree_id, "")))


## &"" clears the tree's choice. Never saves by itself.
func set_equipped_capstone(tree_id: StringName, node_id: StringName) -> void:
	if node_id == &"":
		if _config.has_section_key(SECTION_CAPSTONES, tree_id):
			_config.erase_section_key(SECTION_CAPSTONES, tree_id)
	else:
		_config.set_value(SECTION_CAPSTONES, tree_id, String(node_id))
	_dirty = true


# ============================================
# Monsters: the bought ones and the Heroes-side quarry
# ============================================

## Ids of the monsters the player bought ([monsters] owned), in purchase order.
## Monsters a roster def owns by default are not listed
## (CharacterProgress.is_unlocked reads both).
func get_owned_monsters() -> Array[StringName]:
	return _id_list(SECTION_MONSTERS, "owned")


func owns_monster(monster_id: StringName) -> bool:
	return get_owned_monsters().has(monster_id)


## Adds a bought monster (monster_owned fires once). Never saves by itself.
func add_owned_monster(monster_id: StringName) -> void:
	if monster_id == &"" or owns_monster(monster_id):
		return
	_append_id(SECTION_MONSTERS, "owned", monster_id)
	monster_owned.emit(monster_id)


## The monster of the last Heroes-side hunt (&"" before the first one).
func get_last_quarry() -> StringName:
	return StringName(String(_config.get_value(SECTION_MONSTERS, "last_quarry", "")))


func set_last_quarry(monster_id: StringName) -> void:
	_config.set_value(SECTION_MONSTERS, "last_quarry", String(monster_id))
	_dirty = true


## The quarry the pre-round Change picker fixed; &"" = a random one each hunt.
func get_locked_quarry() -> StringName:
	return StringName(String(_config.get_value(SECTION_MONSTERS, "locked_quarry", "")))


func set_locked_quarry(monster_id: StringName) -> void:
	_config.set_value(SECTION_MONSTERS, "locked_quarry", String(monster_id))
	_dirty = true


# ============================================
# Codex (what the player has met)
# ============================================

## The entries of one Codex kind (CODEX_MONSTERS: the quarries met), in the
## order they were added.
func get_codex_entries(kind: StringName) -> Array[StringName]:
	return _id_list(SECTION_CODEX, String(kind))


func has_codex_entry(kind: StringName, id: StringName) -> bool:
	return get_codex_entries(kind).has(id)


## Adds an entry; true when it is new (a first sighting). Never saves by itself.
func add_codex_entry(kind: StringName, id: StringName) -> bool:
	if id == &"" or has_codex_entry(kind, id):
		return false
	_append_id(SECTION_CODEX, String(kind), id)
	return true


## How many pages of a Codex kind the player has seen (the Codex writes it
## when it opens). It lives with the Codex, so Reset Progress clears it.
func get_codex_seen(kind: StringName) -> int:
	return _as_non_negative_int(_config.get_value(SECTION_CODEX, _codex_seen_key(kind), 0))


func set_codex_seen(kind: StringName, count: int) -> void:
	_config.set_value(SECTION_CODEX, _codex_seen_key(kind), maxi(count, 0))
	_dirty = true


static func _codex_seen_key(kind: StringName) -> String:
	return "%s_seen" % kind


## A saved list of ids (Strings in the file), typed; anything else in it is
## skipped, so a hand-edited or damaged list never breaks a read.
func _id_list(section: String, key: String) -> Array[StringName]:
	var out: Array[StringName] = []
	var raw: Variant = _config.get_value(section, key, [])
	if raw is Array:
		for entry: Variant in raw:
			if (entry is String or entry is StringName) and not String(entry).is_empty() and not out.has(StringName(entry)):
				out.append(StringName(entry))
	return out


func _append_id(section: String, key: String, id: StringName) -> void:
	var ids: Array = []
	for existing in _id_list(section, key):
		ids.append(String(existing))
	ids.append(String(id))
	_config.set_value(section, key, ids)
	_dirty = true


# ============================================
# Settings (audio volumes, controls, etc.)
# ============================================

func get_setting(key: StringName, default_value: Variant = null) -> Variant:
	return _config.get_value(SECTION_SETTINGS, key, default_value)


func set_setting(key: StringName, value: Variant) -> void:
	_config.set_value(SECTION_SETTINGS, key, value)
	_dirty = true


# ============================================
# Match counter (used by stats screens)
# ============================================

func is_loaded() -> bool:
	return _loaded


func get_total_matches() -> int:
	return int(_config.get_value(SECTION_META, "total_matches", 0))


func record_match_played() -> void:
	_config.set_value(SECTION_META, "total_matches", get_total_matches() + 1)
	_dirty = true
