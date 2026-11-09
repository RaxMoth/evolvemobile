class_name AbilitySlot
extends Control

## One in-match ability icon (the MatchHud's hero cards and monster panel).
## AbilitySlot.tscn is 72x72 and scales freely; everything sits under Body,
## the part that pops:
##   - Glow: the ready_glow.gdshader halo behind an ULTIMATE while it is ready;
##   - Icon: the ability tile on 60/72 of the slot under the slot's own copy of
##     ability_cooldown.gdshader: the cooling sector (clockwise from 12
##     o'clock) desaturated and veiled with an amber edge on the sweep line,
##     `locked` greys the icon, `ready_flash` whitens it;
##   - Frame: the kit's slot_basic / slot_active / slot_ult / slot_passive
##     frame for slot_type, slot_locked while locked;
##   - CooldownNumber: the seconds left, rounded up: whole seconds above 1 s,
##     tenths below ("3", "2", "1.0", "0.4");
##   - Lock: the padlock and the stage numeral (set_locked(true, "II")).
## When the ability becomes ready: ready_flash 1 -> 0 over FLASH_TIME, a
## POP_SCALE pop and became_ready.
##
## Two ways to feed it: bind(CooldownSource, slot) polls the source every
## frame (icon, lock, cooldown), so River's basic-attack slot swaps its icon
## with her weapon mode; or a card calls set_cooldown() / set_locked() itself.
## Either way the shader parameter is written only when the progress moved by
## PROGRESS_STEP and the label only when the shown number changes.

## The slot became castable again: its cooldown ran out, or the stage unlocked
## it. `slot` is the bound source slot (-1 for a slot fed by hand).
signal became_ready(slot: int)

## Smallest progress change written to the shader (one sweep has 500 steps).
const PROGRESS_STEP := 0.002
## Progress at or above this counts as ready (the shader stops veiling there).
const READY_AT := 0.999
const POP_SCALE := Vector2(1.18, 1.18)
const POP_UP_TIME := 0.08
const POP_DOWN_TIME := 0.2
## ready_flash runs 1 -> 0 over this many seconds.
const FLASH_TIME := 0.25

## Which frame the slot wears; an ULTIMATE also glows while ready. bind()
## takes it from the source.
@export var slot_type: AbilityBase.AbilityType = AbilityBase.AbilityType.ACTIVE:
	set(v):
		slot_type = v
		if is_node_ready():
			_apply_frame()
			_apply_glow()
## The icon while no source is bound (previews, a card feeding the slot).
@export var icon_texture: Texture2D:
	set(v):
		icon_texture = v
		if is_node_ready():
			_icon.texture = v
## Off for a slot whose cooldown is too short to read.
@export var show_countdown: bool = true

@export_group("Frames")
@export var frame_basic: Texture2D
@export var frame_active: Texture2D
@export var frame_ult: Texture2D
@export var frame_passive: Texture2D
@export var frame_locked: Texture2D

@onready var _body: Control = %Body
@onready var _glow: CanvasItem = %Glow
@onready var _icon: TextureRect = %Icon
@onready var _frame: TextureRect = %Frame
@onready var _number: Label = %CooldownNumber
@onready var _lock: CanvasItem = %Lock
@onready var _lock_text: Label = %LockText

var _source: CooldownSource = null
var _slot: int = -1
var _mat: ShaderMaterial = null
var _shown_progress: float = -1.0
## Tenths of a second the label shows (countdown_tenths; 0 = no label).
var _shown_tenths: int = -1
var _locked: bool = false
var _is_ready: bool = false
## False until the first value after _ready / bind(): the slot takes that
## state without popping (a slot that starts ready is not becoming ready).
var _ready_known: bool = false
var _juice: Tween = null


func _ready() -> void:
	# The slot's own material: every slot sweeps on its own.
	_mat = (_icon.material as ShaderMaterial).duplicate() as ShaderMaterial
	_icon.material = _mat
	if icon_texture:
		_icon.texture = icon_texture
	_apply_frame()
	_apply_glow()
	if _source != null:
		_start()
	else:
		set_process(false)


## Polls `slot` of `source` every frame from now on (null unbinds). May be
## called before the slot enters the tree.
func bind(source: CooldownSource, slot: int) -> void:
	_source = source
	_slot = slot
	if is_node_ready():
		_start()


## Mirrors a cooldown: progress 0 = just cast, 1 = ready; remaining in
## seconds. Ignored while locked.
func set_cooldown(progress: float, remaining: float) -> void:
	if _locked:
		return
	_write_progress(progress)
	var now_ready := progress >= READY_AT
	_show_seconds(0.0 if now_ready or not show_countdown else remaining)
	_set_ready(now_ready)


## Locked: the padlock with `hint` under it (the unlock stage's numeral, "II"),
## the icon greyed with no sweep and no number, the slot_locked frame.
## Unlocking into a ready ability pops the slot.
func set_locked(locked: bool, hint: String = "") -> void:
	_lock_text.text = hint
	if locked == _locked:
		return
	_locked = locked
	_lock.visible = locked
	_mat.set_shader_parameter(&"locked", 1.0 if locked else 0.0)
	if locked:
		_write_progress(1.0)
		_show_seconds(0.0)
		_ready_known = true
		_is_ready = false
	_apply_frame()
	_apply_glow()


func is_locked() -> bool:
	return _locked


## Tenths of a second a countdown shows for `remaining`, rounded up: whole
## seconds above 1 s (2.3 -> 30), tenths up to 1 s (0.95 -> 10, 0.31 -> 4),
## 0 when nothing is left.
static func countdown_tenths(remaining: float) -> int:
	if remaining > 1.0:
		return ceili(remaining) * 10
	if remaining > 0.0:
		return maxi(1, ceili(remaining * 10.0 - 0.001))
	return 0


## The label for countdown_tenths(): "3", "1.0", "0.4", or "" for 0.
static func countdown_text(tenths: int) -> String:
	if tenths <= 0:
		return ""
	if tenths > 10:
		return str(roundi(tenths * 0.1))
	return "%.1f" % (tenths * 0.1)


func _start() -> void:
	_ready_known = false
	if _source == null or not _source.is_valid():
		_source = null
		set_process(false)
		return
	slot_type = _source.slot_type(_slot)
	_poll()
	set_process(true)


func _process(_delta: float) -> void:
	_poll()


func _poll() -> void:
	if not _source.is_valid():
		_source = null
		set_process(false)
		return
	var tex := _source.icon(_slot)
	if tex != _icon.texture:
		_icon.texture = tex
	var now_locked := _source.locked(_slot)
	if now_locked != _locked:
		set_locked(now_locked, _source.lock_hint(_slot) if now_locked else "")
	if not now_locked:
		set_cooldown(_source.progress(_slot), _source.remaining(_slot))


func _write_progress(p: float) -> void:
	# Small steps are skipped, but reaching 1.0 is always written, so a ready
	# icon never keeps a sliver of veil.
	if absf(p - _shown_progress) < PROGRESS_STEP and (p < 1.0 or _shown_progress >= 1.0):
		return
	_shown_progress = p
	_mat.set_shader_parameter(&"progress", p)


func _show_seconds(remaining: float) -> void:
	var tenths := countdown_tenths(remaining)
	if tenths == _shown_tenths:
		return
	_shown_tenths = tenths
	_number.text = countdown_text(tenths)
	_number.visible = tenths > 0


func _set_ready(now_ready: bool) -> void:
	if not _ready_known:
		_ready_known = true
		_is_ready = now_ready
		_apply_glow()
		return
	if now_ready == _is_ready:
		return
	_is_ready = now_ready
	_apply_glow()
	if now_ready:
		_play_ready()


func _play_ready() -> void:
	became_ready.emit(_slot)
	if _juice:
		_juice.kill()
	_body.pivot_offset = _body.size * 0.5
	_juice = create_tween().set_parallel(true)
	_juice.tween_method(_set_flash, 1.0, 0.0, FLASH_TIME)
	_juice.tween_property(_body, ^"scale", POP_SCALE, POP_UP_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_juice.tween_property(_body, ^"scale", Vector2.ONE, POP_DOWN_TIME).set_delay(POP_UP_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_flash(value: float) -> void:
	_mat.set_shader_parameter(&"ready_flash", value)


func _apply_frame() -> void:
	_frame.texture = frame_locked if _locked else _frame_for(slot_type)


func _frame_for(kind: AbilityBase.AbilityType) -> Texture2D:
	match kind:
		AbilityBase.AbilityType.BASIC_ATTACK:
			return frame_basic
		AbilityBase.AbilityType.ULTIMATE:
			return frame_ult
		AbilityBase.AbilityType.PASSIVE:
			return frame_passive
	return frame_active


func _apply_glow() -> void:
	_glow.visible = slot_type == AbilityBase.AbilityType.ULTIMATE and _is_ready and not _locked
