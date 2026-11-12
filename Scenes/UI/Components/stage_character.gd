class_name StageCharacter
extends Button

## A tappable roster character standing on a menu stage (the lobby's campfire
## and lair, the detail screen): its live rig (RigView) with a soft
## squash-and-bob idle on top of the rig's own breathing, and cheer() when its
## side is chosen. A locked character stands as a silhouette under a padlock,
## with its price chip and, while unmet, its unlock rule ("Needs a Lv 3
## monster") under the lock when it can be bought.
##
## Individuality: each instance bobs with its own period (bob_period x
## 0.85-1.2) and phase (0..period, applied once: the loop itself has no rest),
## drawn from a PRIVATE RandomNumberGenerator seeded by hash(name) ^
## hash(path), so the same stage looks the same every launch and the global
## RNG (gameplay) is never touched.
##
## Two layers so the idle and the cheer never fight over a property: the idle
## squashes and bobs %Rig, cheer() hops %Hop (its parent).
##
## The match result's cast: celebrate() cheers over and over (a win),
## set_fallen() lays the character down greyed (a fallen hero, a lost match).

signal character_pressed(character: CharacterDef)

## Idle squash at the top of the bob (x grows, y shrinks).
const SQUASH := Vector2(1.025, 0.975)
const CHEER_HEIGHT := 26.0
## Seconds between two hops of celebrate().
const CELEBRATE_REST := 0.7
## A fallen character tips backwards by this much and sags.
const FALLEN_TILT_DEG := -12.0
const FALLEN_SQUASH := Vector2(1.0, 0.94)

@export var character: CharacterDef:
	set(v):
		character = v
		if is_node_ready():
			refresh()
## Evolution stage shown (monsters).
@export_range(1, 3) var stage: int = 1:
	set(v):
		stage = v
		if is_node_ready():
			_rig.stage = stage
## Mirror the character so a group faces inward.
@export var flip: bool = false:
	set(v):
		flip = v
		if is_node_ready():
			_rig.flip = flip
@export var bob_px: float = 3.0
@export var bob_period: float = 1.6

## The idle period this instance drew (seconds).
var period: float = 0.0
## How far into its first bob this instance starts (seconds, 0..period).
var phase: float = 0.0
## True while set_fallen(true) holds (celebrate() does nothing then).
var fallen: bool = false

var _rng := RandomNumberGenerator.new()
var _idle: Tween = null
var _party: Tween = null
var _rest_y := 0.0

@onready var _hop: Control = %Hop
@onready var _rig: RigView = %Rig
@onready var _lock: TextureRect = %Lock
@onready var _lock_info: Control = %LockInfo
@onready var _price_icon: TextureRect = %PriceIcon
@onready var _price_label: Label = %PriceLabel
@onready var _rule: Label = %Rule


func _ready() -> void:
	_rng.seed = hash(name) ^ hash(get_path())
	period = bob_period * _rng.randf_range(0.85, 1.2)
	phase = _rng.randf_range(0.0, period)
	_rig.stage = stage
	_rig.flip = flip
	refresh()
	start_idle()


## Re-reads whether the character is unlocked (silhouette and padlock) and,
## when locked, its price and rule.
func refresh() -> void:
	_rig.character = character
	var locked := character != null and not CharacterProgress.is_unlocked(character)
	_rig.silhouette = locked
	_lock.visible = locked
	var state := CharacterProgress.unlock_state(character)
	_lock_info.visible = locked and state != CharacterProgress.UnlockState.NOT_FOR_SALE
	if not _lock_info.visible:
		return
	var currency := character.currency()
	_price_icon.texture = CurrencyChip.icon_for(currency)
	_price_label.text = CurrencyChip.format_amount(character.unlock_cost)
	_price_label.add_theme_color_override(&"font_color", UiPalette.get_default().color(currency))
	_rule.text = CharacterProgress.unlock_rule_short(character)
	_rule.visible = state == CharacterProgress.UnlockState.GATED and not _rule.text.is_empty()


## The idle loop: squash and rise, then settle, forever, starting `phase`
## seconds into the cycle. Restarting keeps the instance's period and phase.
func start_idle() -> void:
	if _idle:
		_idle.kill()
		_rig.scale = Vector2.ONE
		_rig.position.y = _rest_y
	_on_rig_resized()
	_rest_y = _rig.position.y
	var half := period * 0.5
	_idle = create_tween().set_loops()
	_idle.tween_property(_rig, ^"scale", SQUASH, half).set_trans(Tween.TRANS_SINE)
	_idle.parallel().tween_property(_rig, ^"position:y", _rest_y - bob_px, half).set_trans(Tween.TRANS_SINE)
	_idle.tween_property(_rig, ^"scale", Vector2.ONE, half).set_trans(Tween.TRANS_SINE)
	_idle.parallel().tween_property(_rig, ^"position:y", _rest_y, half).set_trans(Tween.TRANS_SINE)
	# The phase once, outside the loop (an interval inside it would rest in
	# every cycle).
	_idle.custom_step(phase)


## The side was chosen: one hop with a bounce landing after `delay` seconds,
## the rig playing its body plan's cheer move (arms up) on the way.
func cheer(delay: float = 0.0) -> void:
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_callback(_rig.play_move.bind(&"cheer"))
	t.tween_property(_hop, ^"position:y", -CHEER_HEIGHT, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(_hop, ^"position:y", 0.0, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## A win: cheer() after `delay` seconds and then every CELEBRATE_REST, until
## stop_celebrating() or set_fallen().
func celebrate(delay: float = 0.0) -> void:
	stop_celebrating()
	if fallen:
		return
	_party = create_tween()
	_party.tween_interval(delay)
	_party.tween_callback(_celebrate_loop)


func stop_celebrating() -> void:
	if _party:
		_party.kill()
		_party = null
	_hop.position.y = 0.0


func is_celebrating() -> bool:
	return _party != null and _party.is_valid()


func _celebrate_loop() -> void:
	_party = create_tween().set_loops()
	_party.tween_callback(_rig.play_move.bind(&"cheer"))
	_party.tween_property(_hop, ^"position:y", -CHEER_HEIGHT, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_party.tween_property(_hop, ^"position:y", 0.0, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_party.tween_interval(CELEBRATE_REST)


## Fallen (`on`): no idle and no cheering, the rig posed still, drained of
## colour (RigView.greyed) and darkened (UiPalette.FALLEN_STAGE_MODULATE),
## tipped back on its feet; off: standing again.
func set_fallen(on: bool) -> void:
	fallen = on
	stop_celebrating()
	_hop.rotation_degrees = (-FALLEN_TILT_DEG if flip else FALLEN_TILT_DEG) if on else 0.0
	_hop.scale = FALLEN_SQUASH if on else Vector2.ONE
	_hop.modulate = UiPalette.FALLEN_STAGE_MODULATE if on else Color.WHITE
	_rig.greyed = on
	_rig.animated = not on
	if on:
		if _idle:
			_idle.kill()
			_idle = null
			_rig.scale = Vector2.ONE
			_rig.position.y = _rest_y
	elif _idle == null:
		start_idle()


## The squash (and a fallen tilt) pivots on the feet (the bottom centre; %Rig
## fills %Hop). The first layout can resize the rig before _ready; start_idle()
## sets the pivot then.
func _on_rig_resized() -> void:
	if not is_node_ready():
		return
	_rig.pivot_offset = Vector2(_rig.size.x * 0.5, _rig.size.y)
	_hop.pivot_offset = _rig.pivot_offset


func _on_pressed() -> void:
	character_pressed.emit(character)


func _on_button_down() -> void:
	PressFeedback.down(self)


func _on_button_up() -> void:
	PressFeedback.up(self)
