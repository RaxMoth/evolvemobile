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
## 0.85-1.2) and phase, drawn from a PRIVATE RandomNumberGenerator seeded by
## hash(name) ^ hash(path), so the same stage looks the same every launch and
## the global RNG (gameplay) is never touched.
##
## Two layers so the idle and the cheer never fight over a property: the idle
## squashes and bobs %Rig, cheer() hops %Hop (its parent).

signal character_pressed(character: CharacterDef)

## Idle squash at the top of the bob (x grows, y shrinks).
const SQUASH := Vector2(1.025, 0.975)
const CHEER_HEIGHT := 26.0

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

var _rng := RandomNumberGenerator.new()
var _idle: Tween = null
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


## The idle loop: after a random share of one period, squash and rise, then
## settle, forever. Restarting keeps the instance's period and phase.
func start_idle() -> void:
	if _idle:
		_idle.kill()
	_on_rig_resized()
	_rest_y = _rig.position.y
	var half := period * 0.5
	_idle = create_tween().set_loops()
	_idle.tween_interval(_rng.randf_range(0.0, period))
	_idle.tween_property(_rig, ^"scale", SQUASH, half).set_trans(Tween.TRANS_SINE)
	_idle.parallel().tween_property(_rig, ^"position:y", _rest_y - bob_px, half).set_trans(Tween.TRANS_SINE)
	_idle.tween_property(_rig, ^"scale", Vector2.ONE, half).set_trans(Tween.TRANS_SINE)
	_idle.parallel().tween_property(_rig, ^"position:y", _rest_y, half).set_trans(Tween.TRANS_SINE)


## The side was chosen: one hop with a bounce landing after `delay` seconds.
func cheer(delay: float = 0.0) -> void:
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_property(_hop, ^"position:y", -CHEER_HEIGHT, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(_hop, ^"position:y", 0.0, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## The squash pivots on the feet (the rig's bottom centre). The first layout
## can resize the rig before _ready; start_idle() sets the pivot then.
func _on_rig_resized() -> void:
	if not is_node_ready():
		return
	_rig.pivot_offset = Vector2(_rig.size.x * 0.5, _rig.size.y)


func _on_pressed() -> void:
	character_pressed.emit(character)


func _on_button_down() -> void:
	PressFeedback.down(self)


func _on_button_up() -> void:
	PressFeedback.up(self)
