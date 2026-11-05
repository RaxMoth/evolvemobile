extends Node2D

## AudioManager — the game's only audio emitter. Autoload (after GameManager).
##
## Sources, in priority order:
##   1. A real asset at res://Assets/Audio/<key>.ogg or .wav (drop files in,
##      no code change — see SFX_KEYS / MUSIC_KEYS for the names).
##   2. A procedurally generated placeholder tone, so the game is never silent
##      while real audio is still being produced.
##
## Buses: SFX for effects (positional, AudioStreamPlayer2D pool, so distant
## fights are quieter and ones out of earshot are skipped), Music for the
## looped track. Volumes come from the
## Settings screen via AudioSettings → PersistedData.
##
## Hooks (code-side: autoloads cannot be targets of scene [connection]s):
##   EventBus.damage_applied → hit / hit_big
##   EventBus.entity_died    → death_mob / death_big
##   EventBus.ability_cast   → cast (ACTIVE) / ult (ULTIMATE)
##   EventBus.monster_evolved → evolve
##   GameManager.match_ended → victory / defeat (non-positional)

const ASSET_DIR := "res://Assets/Audio/"
const SFX_KEYS: Array[StringName] = [&"hit", &"hit_big", &"death_mob", &"death_big", &"cast", &"ult", &"evolve", &"ui_click", &"victory", &"defeat"]
const MUSIC_KEYS: Array[StringName] = [&"menu", &"match"]

## Same key cannot retrigger faster than this (a camp fight fires hits every frame).
const MIN_RETRIGGER_MSEC: int = 50
const POOL_SIZE: int = 10
const SFX_MAX_DISTANCE: float = 1400.0
const PLACEHOLDER_DB: float = -8.0
const MIX_RATE: int = 22050

var _sfx: Dictionary = {}      # key -> AudioStream
var _music: Dictionary = {}    # key -> AudioStream
var _pool: Array[AudioStreamPlayer2D] = []
var _ui_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _last_play_msec: Dictionary = {}  # key -> int
var _current_music: StringName = &""


func _ready() -> void:
	_build_streams()
	_build_players()
	EventBus.damage_applied.connect(_on_damage_applied)
	EventBus.entity_died.connect(_on_entity_died)
	EventBus.ability_cast.connect(_on_ability_cast)
	GameManager.match_ended.connect(_on_match_ended)
	EventBus.monster_evolved.connect(_on_monster_evolved)


# ============================================
# Public API
# ============================================

func has_sfx(key: StringName) -> bool:
	return _sfx.has(key)


## Positional effect. Returns false when unknown, out of earshot or rate-limited.
func play_sfx(key: StringName, pos: Vector2) -> bool:
	if not _sfx.has(key) or not _in_earshot(pos) or not _allow(key):
		return false
	var player := _free_player()
	player.stream = _sfx[key]
	player.global_position = pos
	player.play()
	return true


## Non-positional effect (UI, match end).
func play_global(key: StringName) -> bool:
	if not _sfx.has(key) or not _allow(key):
		return false
	_ui_player.stream = _sfx[key]
	_ui_player.play()
	return true


func play_ui_click() -> void:
	play_global(&"ui_click")


func play_music(key: StringName) -> void:
	if not _music.has(key):
		return
	if _current_music == key and _music_player.playing:
		return
	_current_music = key
	_music_player.stream = _music[key]
	_music_player.play()


func stop_music() -> void:
	_current_music = &""
	_music_player.stop()


func current_music() -> StringName:
	return _current_music


func is_placeholder(key: StringName) -> bool:
	var s: AudioStream = _sfx.get(key, _music.get(key, null))
	return s != null and s.resource_path.is_empty()


# ============================================
# Event hooks
# ============================================

func _on_damage_applied(packet: DamagePacket) -> void:
	if packet == null or packet.amount <= 0.0 or not (packet.target is Node2D):
		return
	var big := packet.target is HeroBase or packet.target is MonsterBase
	play_sfx(&"hit_big" if big else &"hit", (packet.target as Node2D).global_position)


func _on_entity_died(entity: Node, _killer: Node) -> void:
	if not (entity is Node2D):
		return
	var big := entity is HeroBase or entity is MonsterBase
	play_sfx(&"death_big" if big else &"death_mob", (entity as Node2D).global_position)


func _on_ability_cast(caster: Node, ability: AbilityBase, _target: Node) -> void:
	if ability == null or not (caster is Node2D):
		return
	match ability.ability_type:
		AbilityBase.AbilityType.ULTIMATE:
			play_sfx(&"ult", (caster as Node2D).global_position)
		AbilityBase.AbilityType.ACTIVE:
			play_sfx(&"cast", (caster as Node2D).global_position)
		_:
			pass


func _on_monster_evolved(monster: Node, _stage: int) -> void:
	if monster is Node2D:
		play_sfx(&"evolve", (monster as Node2D).global_position)


func _on_match_ended(winner: String, _time: float) -> void:
	# Drop in-flight world SFX so they do not resume when the tree unpauses later.
	for p in _pool:
		p.stop()
	var player_won := (winner == "Heroes") == (GameManager.chosen_side == MatchRewards.Side.HEROES)
	play_global(&"victory" if player_won else &"defeat")


# ============================================
# Internals
# ============================================

## A pool player further than SFX_MAX_DISTANCE from the screen centre plays
## silently, yet it would still claim the key's retrigger slot and a voice. So
## play_sfx culls before _allow() and _free_player(): an off-screen hit can no
## longer mute the on-screen hit right after it. With no current camera
## nothing is culled.
func _in_earshot(pos: Vector2) -> bool:
	var cam := get_viewport().get_camera_2d()
	return cam == null \
		or pos.distance_squared_to(cam.get_screen_center_position()) <= SFX_MAX_DISTANCE * SFX_MAX_DISTANCE


func _allow(key: StringName) -> bool:
	var now := Time.get_ticks_msec()
	var last: int = int(_last_play_msec.get(key, -MIN_RETRIGGER_MSEC))
	if now - last < MIN_RETRIGGER_MSEC:
		return false
	_last_play_msec[key] = now
	return true


func _free_player() -> AudioStreamPlayer2D:
	# Idle voice if any; otherwise steal the voice furthest along (nearly done).
	var victim: AudioStreamPlayer2D = _pool[0]
	var furthest := -1.0
	for p in _pool:
		if not p.playing:
			return p
		var pos := p.get_playback_position()
		if pos > furthest:
			furthest = pos
			victim = p
	return victim


func _build_players() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer2D.new()
		p.bus = AudioSettings.SFX_BUS
		p.max_distance = SFX_MAX_DISTANCE
		p.attenuation = 1.5
		p.volume_db = PLACEHOLDER_DB
		add_child(p)
		_pool.append(p)
	_ui_player = AudioStreamPlayer.new()
	# UI cues, the match-end jingle and music must survive the result screen's
	# tree pause; the positional pool stays pausable with the world.
	_ui_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_ui_player.bus = AudioSettings.SFX_BUS
	_ui_player.volume_db = PLACEHOLDER_DB
	add_child(_ui_player)
	_music_player = AudioStreamPlayer.new()
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player.bus = AudioSettings.MUSIC_BUS
	_music_player.volume_db = PLACEHOLDER_DB - 4.0
	add_child(_music_player)


func _build_streams() -> void:
	for key in SFX_KEYS:
		_sfx[key] = _load_asset(key)
		if _sfx[key] == null:
			_sfx[key] = _placeholder_sfx(key)
	for key in MUSIC_KEYS:
		_music[key] = _load_asset(key)
		if _music[key] == null:
			_music[key] = _placeholder_music(key)


func _load_asset(key: StringName) -> AudioStream:
	for ext in ["ogg", "wav"]:
		var path := "%s%s.%s" % [ASSET_DIR, key, ext]
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null


# --- placeholder synthesis -----------------------------------------------

func _placeholder_sfx(key: StringName) -> AudioStreamWAV:
	match key:
		&"hit":       return _tone(180.0, 90.0, 0.06, 0.45, 0.5)
		&"hit_big":   return _tone(140.0, 70.0, 0.09, 0.5, 0.6)
		&"death_mob": return _tone(440.0, 110.0, 0.25, 0.5, 0.1)
		&"death_big": return _tone(220.0, 55.0, 0.6, 0.6, 0.2)
		&"cast":      return _tone(500.0, 900.0, 0.12, 0.4, 0.0)
		&"ult":       return _tone(300.0, 1200.0, 0.45, 0.5, 0.05)
		&"evolve":    return _tone(220.0, 880.0, 0.7, 0.55, 0.0)
		&"ui_click":  return _tone(1200.0, 800.0, 0.025, 0.3, 0.0)
		&"victory":   return _tone(440.0, 880.0, 0.8, 0.5, 0.0)
		&"defeat":    return _tone(330.0, 110.0, 0.9, 0.5, 0.0)
	return _tone(440.0, 440.0, 0.1, 0.3, 0.0)


## Decaying sine sweep with optional noise blend — 16-bit mono.
static func _tone(freq_start: float, freq_end: float, duration: float, volume: float, noise: float) -> AudioStreamWAV:
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var progress := t / duration
		var env := (1.0 - progress) * (1.0 - progress)
		var f := lerpf(freq_start, freq_end, progress)
		phase += TAU * f / float(MIX_RATE)
		var sample := sin(phase)
		if noise > 0.0:
			sample = lerpf(sample, randf_range(-1.0, 1.0), noise)
		data.encode_s16(i * 2, int(clampf(sample * env * volume, -1.0, 1.0) * 32767.0))
	return _wav(data, false)


## Two slow alternating chords with a soft tremolo, looped — a placeholder pad.
func _placeholder_music(key: StringName) -> AudioStreamWAV:
	var chords: Array = [[110.0, 164.81, 220.0], [87.31, 130.81, 174.61]] if key == &"menu" \
		else [[98.0, 146.83, 196.0], [73.42, 110.0, 146.83]]
	var bar := 3.0
	var n := int(bar * 2.0 * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var chord: Array = chords[int(t / bar) % 2]
		var sample := 0.0
		for f in chord:
			sample += sin(TAU * float(f) * t) / chord.size()
		var tremolo := 0.85 + 0.15 * sin(TAU * 0.5 * t)
		# Crossfade the bar edges so the loop and the chord changes do not click.
		var edge := minf(1.0, minf(fmod(t, bar), bar - fmod(t, bar)) / 0.15)
		data.encode_s16(i * 2, int(clampf(sample * tremolo * edge * 0.25, -1.0, 1.0) * 32767.0))
	return _wav(data, true)


static func _wav(data: PackedByteArray, looped: bool) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	if looped:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		@warning_ignore("integer_division")
		wav.loop_end = data.size() / 2
	return wav
