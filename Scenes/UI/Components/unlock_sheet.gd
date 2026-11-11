class_name UnlockSheet
extends Control

## The confirm sheet of a character purchase (Monster side: Nyxa 2,500 and
## Gorrak 3,000 Leaves). A tap on a locked card in the monster roster or a
## padlocked monster in the lobby opens it (MenuRoot calls open_for); it
## slides up from the bottom edge over a dimmed scrim and shows:
##   - the character as a locked silhouette under the padlock, its name, role
##     and tagline;
##   - the rule (CharacterProgress.unlock_rule): what is still missing, in the
##     danger colour, or that it is met, in moss green with a check;
##   - CANCEL and UNLOCK with the currency icon and the price inside it.
##     UNLOCK is disabled while the rule is unmet, and reads "Need 340 more"
##     (the price in the danger colour) while the wallet is short.
## UNLOCK only reports unlock_confirmed(character): MenuRoot buys it
## (CharacterProgress.unlock) and closes the sheet, or calls refresh() when
## the purchase did not go through. CANCEL, a tap on the scrim and ui_cancel
## close it. While it slides up it holds its TapGuard: the second tap of the
## double tap that opened it never closes it on the scrim. The panel reaches
## the bottom edge (SheetPanel has no bottom border). Every connection inside
## the sheet is in UnlockSheet.tscn.

signal unlock_confirmed(character: CharacterDef)

const SLIDE_TIME := 0.22
## Opacity of the scrim (UiPalette.bg_void) over the screen below.
const SCRIM_ALPHA := 0.72
const CHECK_ICON := preload("res://Assets/UI/Icons/UI/ui_check.svg")
const LOCK_ICON := preload("res://Assets/UI/Icons/UI/ui_lock.svg")

## The character on offer (null while closed).
var character: CharacterDef = null
## What the sheet shows (CharacterProgress.UnlockState), read by tests.
var state: CharacterProgress.UnlockState = CharacterProgress.UnlockState.NOT_FOR_SALE

var _open := false
var _tween: Tween = null

@onready var _scrim: ColorRect = %Scrim
## Full-rect layer holding the bottom-anchored sheet: it slides (position.y
## from the screen height to 0), so the sheet's own anchors never move.
@onready var _slide: Control = %Slide
@onready var _portrait: TextureRect = %Portrait
@onready var _name: Label = %Name
@onready var _role: Label = %Role
@onready var _tagline: Label = %Tagline
@onready var _rule_icon: TextureRect = %RuleIcon
@onready var _rule: Label = %Rule
@onready var _unlock: Button = %Unlock
@onready var _cost_icon: TextureRect = %CostIcon
@onready var _cost_value: Label = %CostValue
@onready var _tap_guard: TapGuard = %TapGuard


func _ready() -> void:
	var palette := UiPalette.get_default()
	_scrim.color = Color(palette.bg_void, SCRIM_ALPHA)
	_portrait.material = CharacterCard.locked_material()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _open and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Slides the sheet up for `def` (a locked character with a price).
func open_for(def: CharacterDef) -> void:
	character = def
	refresh()
	_open = true
	visible = true
	_tap_guard.hold(SLIDE_TIME)
	_kill_tween()
	_scrim.modulate.a = 0.0
	_slide.position.y = size.y
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_scrim, ^"modulate:a", 1.0, SLIDE_TIME)
	_tween.tween_property(_slide, ^"position:y", 0.0, SLIDE_TIME)


## Slides the sheet away and hides it.
func close() -> void:
	if not _open:
		return
	_open = false
	_kill_tween()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(_scrim, ^"modulate:a", 0.0, SLIDE_TIME)
	_tween.tween_property(_slide, ^"position:y", size.y, SLIDE_TIME)
	_tween.chain().tween_callback(_on_closed)


func is_open() -> bool:
	return _open


## Re-reads the rule, the wallet and the price (the save changed).
func refresh() -> void:
	state = CharacterProgress.unlock_state(character)
	if character == null:
		return
	var palette := UiPalette.get_default()
	_portrait.texture = character.portrait
	_name.text = tr("Unlock %s?") % character.get_display_name()
	_role.text = character.role_text
	_tagline.text = character.tagline
	var rule := CharacterProgress.unlock_rule(character)
	var gate_met := CharacterProgress.unlock_gate_met(character)
	_rule.text = rule
	_rule.theme_type_variation = &"NextLabel" if gate_met else &"DangerLabel"
	_rule.visible = not rule.is_empty()
	_rule_icon.texture = CHECK_ICON if gate_met else LOCK_ICON
	_rule_icon.visible = _rule.visible
	var currency := character.currency()
	var short := maxi(0, character.unlock_cost - PersistedData.get_currency(currency))
	_cost_icon.texture = CurrencyChip.icon_for(currency)
	_cost_value.text = CurrencyChip.format_amount(character.unlock_cost)
	_cost_value.add_theme_color_override(&"font_color", palette.danger if short > 0 else palette.color(currency))
	_unlock.disabled = state != CharacterProgress.UnlockState.READY
	_unlock.text = tr("Need %s more") % CurrencyChip.format_amount(short) \
			if state == CharacterProgress.UnlockState.SHORT else tr("UNLOCK")


func _kill_tween() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null


func _on_closed() -> void:
	visible = false
	character = null


# --- scene-side connections (UnlockSheet.tscn) ---

func _on_unlock_pressed() -> void:
	if character != null and state == CharacterProgress.UnlockState.READY:
		unlock_confirmed.emit(character)


func _on_cancel_pressed() -> void:
	close()


func _on_scrim_gui_input(event: InputEvent) -> void:
	var tap := event as InputEventMouseButton
	if tap != null and tap.pressed and tap.button_index == MOUSE_BUTTON_LEFT:
		close()
