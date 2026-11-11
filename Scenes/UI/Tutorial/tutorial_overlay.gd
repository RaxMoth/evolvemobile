class_name TutorialOverlay
extends CanvasLayer

## The "How to play" coach marks, in two chapters:
##   - LOBBY, the first run: MenuRoot opens it once over the lobby (setting
##     `tutorial_seen`) and again when the Codex's guide asks for it. It points
##     at the heroes' campfire, the monsters' lair, the HUNT arch, the tabs
##     that lead to the skill trees (Heroes, Growth, Monsters: the frame spans
##     the nav bar between them) and the Codex tab.
##   - HUD, the first match: MatchHud opens it once (setting
##     `tutorial_hud_seen`). It points at the cooldown slots and the pause
##     and speed buttons. The match runs on under it (it never pauses the
##     tree, so a headless sim plays the same match with or without it).
## A step is data (title, body, anchor). The anchor is a group: the step's
## target is every visible Control in it (the groups are set in the target
## scenes: LobbyScreen, NavBar, HeroHudCard, MonsterHudPanel, MatchHud). The
## scrim darkens all but the target, the SelectRing frames it, the arrow bobs
## toward it and the bubble sits on the side with more room; the frame
## follows the target while it moves (a screen sliding in). A step without a
## target (none, or not shown) centres the bubble over the full scrim.
## The look is theme variations only (SheetPanel, Caption, HeaderSmall,
## BodyDim, PipOn / PipOff, FlatButton, Button, ButtonPrimary, SelectRing);
## the scrim and the arrow take the palette's bg_void and amber.
## TutorialOverlay.tscn owns the layout and the button wiring.

signal finished(completed: bool)

const CHAPTER_LOBBY: StringName = &"lobby"
const CHAPTER_HUD: StringName = &"hud"
## The settings that remember a chapter as seen.
const SETTING_SEEN: StringName = &"tutorial_seen"
const SETTING_HUD_SEEN: StringName = &"tutorial_hud_seen"

## Target groups (anchors).
const TARGET_HERO_STAGE: StringName = &"tutorial_hero_stage"
const TARGET_MONSTER_STAGE: StringName = &"tutorial_monster_stage"
const TARGET_HUNT: StringName = &"tutorial_hunt"
const TARGET_TREES: StringName = &"tutorial_trees"
const TARGET_CODEX: StringName = &"tutorial_codex"
const TARGET_HUD_SLOTS: StringName = &"tutorial_hud_slots"
const TARGET_PAUSE: StringName = &"tutorial_pause"

const LOBBY_STEPS: Array[Dictionary] = [
	{
		"title": "Pick a side",
		"body": "Play the Heroes or the Monster. The Heroes win by killing the monster before it grows too strong. The Monster wins by wiping the team — or by surviving the 10-minute timer.",
		"anchor": &"",
	},
	{
		"title": "The hunters' camp",
		"body": "Tap the campfire to play the Heroes. River, Vlad, Ted and Irelia hunt on their own: you set them up, they fight. Tap a hero to see their skills.",
		"anchor": TARGET_HERO_STAGE,
	},
	{
		"title": "The beast's lair",
		"body": "Tap the lair to play the Monster. Your beast starts weak, eats mob camps to evolve and then hunts the hunters. A locked beast shows its price.",
		"anchor": TARGET_MONSTER_STAGE,
	},
	{
		"title": "HUNT",
		"body": "The arch starts a round for the side you picked: set the hunters' strategy or choose your beast, then go.",
		"anchor": TARGET_HUNT,
	},
	{
		"title": "Grow between matches",
		"body": "Every match pays Steel, Leaves, Gold and XP. Spend them on skill trees: open a character under Heroes or Monsters and tap SKILL TREE. Growth holds the tree a whole side shares.",
		"anchor": TARGET_TREES,
	},
	{
		"title": "The Codex",
		"body": "The Codex keeps this guide and a page for every beast you meet or own.",
		"anchor": TARGET_CODEX,
	},
]

const HUD_STEPS: Array[Dictionary] = [
	{
		"title": "Abilities cast themselves",
		"body": "Your side fights on its own. The ring sweeping over a slot is its cooldown and the number the seconds left; a glowing slot is an ultimate ready to fire.",
		"anchor": TARGET_HUD_SLOTS,
	},
	{
		"title": "Pause and speed",
		"body": "Pause opens the menu: resume, the settings, or back to the lobby. The arrow button next to it speeds the hunt up. Good hunting!",
		"anchor": TARGET_PAUSE,
	},
]

## Alpha of the bg_void scrim (the UnlockSheet's).
const SCRIM_ALPHA := 0.72
## Room between the target and the ring (px).
const RING_PAD := 10.0
## Gap between the ring and the bubble; the arrow sits in it.
const BUBBLE_GAP := 76.0
const SIDE_MARGIN := 16.0
const BUBBLE_MAX_WIDTH := 600.0
## The frame glides to the next target in this time.
const MOVE_TIME := 0.25
## The arrow bobs this far toward the target and back, every BOB_TIME.
const BOB_PX := 10.0
const BOB_TIME := 0.45

## Which walkthrough this overlay plays (CHAPTER_LOBBY / CHAPTER_HUD).
@export var chapter: StringName = CHAPTER_LOBBY

var _step: int = 0
## The scrim's hole and the ring (Root coordinates); `_framed` false = none.
var _hole := Rect2()
var _framed := false
## The target's rect when the frame last moved (to follow it).
var _target := Rect2()
var _move: Tween = null
var _bob: Tween = null

@onready var title_label: Label = %Title
@onready var body_label: Label = %Body
@onready var progress_label: Label = %Progress
@onready var back_button: Button = %BackButton
@onready var next_button: Button = %NextButton
@onready var _kicker: Label = %Kicker
@onready var _dim: Control = %Dim
@onready var _ring: Control = %Ring
@onready var _arrow: Control = %Arrow
@onready var _bubble: Control = %Bubble
@onready var _pips: HBoxContainer = %Pips


## The steps of `p_chapter`, in order.
static func steps_of(p_chapter: StringName) -> Array[Dictionary]:
	return HUD_STEPS if p_chapter == CHAPTER_HUD else LOBBY_STEPS


static func _setting_of(p_chapter: StringName) -> StringName:
	return SETTING_HUD_SEEN if p_chapter == CHAPTER_HUD else SETTING_SEEN


static func has_been_seen(p_chapter: StringName = CHAPTER_LOBBY) -> bool:
	return bool(PersistedData.get_setting(_setting_of(p_chapter), false))


static func mark_seen(p_chapter: StringName = CHAPTER_LOBBY) -> void:
	PersistedData.set_setting(_setting_of(p_chapter), true)
	PersistedData.save_data()


## The chapter plays again the next time its trigger comes (the Codex guide's
## "show the hunt tips again").
static func forget(p_chapter: StringName) -> void:
	PersistedData.set_setting(_setting_of(p_chapter), false)
	PersistedData.save_data()


func _ready() -> void:
	var palette := UiPalette.get_default()
	_arrow.modulate = palette.amber
	_ring.self_modulate = palette.amber
	# Keys: the labels and buttons translate them and follow a language switch.
	_kicker.text = "FIRST HUNT" if chapter == CHAPTER_HUD else "HOW TO PLAY"
	_build_pips()
	_show_step(0)


func steps() -> Array[Dictionary]:
	return steps_of(chapter)


func current_step() -> int:
	return _step


## The anchor of the step shown ("" when it has none).
func current_anchor() -> StringName:
	var anchor: StringName = steps()[_step].get("anchor", &"")
	return anchor


## True while the step shown frames a target.
func is_framed() -> bool:
	return _framed


## The scrim's hole around the target (Root coordinates).
func hole() -> Rect2:
	return _hole


## The screen rect of every visible Control in `group`, merged; an empty
## Rect2 when none is shown.
func target_rect(group: StringName) -> Rect2:
	var out := Rect2()
	if group == &"" or not is_inside_tree():
		return out
	var found := false
	for node in get_tree().get_nodes_in_group(group):
		var c := node as Control
		if c == null or not c.is_visible_in_tree():
			continue
		var xf := c.get_global_transform_with_canvas()
		var r := Rect2(xf.origin, c.size * xf.get_scale()).abs()
		out = out.merge(r) if found else r
		found = true
	return out


func _show_step(index: int) -> void:
	var list := steps()
	_step = clampi(index, 0, list.size() - 1)
	var step: Dictionary = list[_step]
	title_label.text = String(step.get("title", ""))
	body_label.text = String(step.get("body", ""))
	progress_label.text = "%d / %d" % [_step + 1, list.size()]
	back_button.disabled = _step == 0
	next_button.text = "Got it" if _step == list.size() - 1 else "Next"
	var i := 0
	for pip: PanelContainer in _pips.get_children():
		pip.theme_type_variation = &"PipOn" if i <= _step else &"PipOff"
		i += 1
	_target = target_rect(current_anchor())
	_place(true)


## Frames the target (or none) and places the bubble and the arrow;
## `animate` glides the frame from where it was.
func _place(animate: bool = false) -> void:
	var view := _dim.size
	var framed := _target.has_area()
	var to := _target.grow(RING_PAD) if framed else Rect2()
	if _move != null:
		_move.kill()
		_move = null
	if animate and framed and _framed:
		_move = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_move.tween_method(_set_hole, _hole, to, MOVE_TIME)
	else:
		_set_hole(to)
	_framed = framed
	_ring.visible = framed
	_arrow.visible = framed
	var margin := maxf(SIDE_MARGIN, (view.x - BUBBLE_MAX_WIDTH) * 0.5)
	_bubble.offset_left = margin
	_bubble.offset_right = -margin
	if not framed:
		_bubble.grow_vertical = Control.GROW_DIRECTION_BOTH
		_set_bubble_y(view.y * 0.5)
		_stop_bob()
		return
	# The bubble goes to the side with more room; the arrow points from it.
	var below := to.get_center().y < view.y * 0.5
	var arrow_y: float
	if below:
		_bubble.grow_vertical = Control.GROW_DIRECTION_END
		_set_bubble_y(to.end.y + BUBBLE_GAP)
		arrow_y = to.end.y + BUBBLE_GAP * 0.5
	else:
		_bubble.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_set_bubble_y(to.position.y - BUBBLE_GAP)
		arrow_y = to.position.y - BUBBLE_GAP * 0.5
	var half := _arrow.size * 0.5
	var x := clampf(to.get_center().x, margin + half.x, view.x - margin - half.x)
	_arrow.pivot_offset = half
	# The art points up: below the target it stays, above it turns over.
	_arrow.rotation_degrees = 0.0 if below else 180.0
	_arrow.position = Vector2(x, arrow_y) - half
	_start_bob(-1.0 if below else 1.0)


func _set_bubble_y(y: float) -> void:
	_bubble.offset_top = y
	_bubble.offset_bottom = y


func _set_hole(rect: Rect2) -> void:
	_hole = rect
	_ring.position = rect.position
	_ring.size = rect.size
	_dim.queue_redraw()


func _start_bob(direction: float) -> void:
	_stop_bob()
	var rest := _arrow.position.y
	_bob = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob.tween_property(_arrow, ^"position:y", rest + BOB_PX * direction, BOB_TIME)
	_bob.tween_property(_arrow, ^"position:y", rest, BOB_TIME)


func _stop_bob() -> void:
	if _bob != null:
		_bob.kill()
		_bob = null


func _build_pips() -> void:
	for i in steps().size():
		var pip := PanelContainer.new()
		pip.custom_minimum_size = Vector2(14, 14)
		pip.theme_type_variation = &"PipOff"
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pips.add_child(pip)


## The frame follows its target while that moves (a screen sliding in, the
## HUD laying out its cards).
func _process(_delta: float) -> void:
	if _move != null and _move.is_running():
		return
	var now := target_rect(current_anchor())
	if not now.is_equal_approx(_target):
		_target = now
		_place()


# --- scene-side connections (TutorialOverlay.tscn) ---

## The scrim: everything but the hole around the target.
func _on_dim_draw() -> void:
	if not is_node_ready():
		return
	var color := Color(UiPalette.get_default().bg_void, SCRIM_ALPHA)
	var full := Rect2(Vector2.ZERO, _dim.size)
	if not _framed and not (_move != null and _move.is_running()):
		_dim.draw_rect(full, color)
		return
	var h := _hole.intersection(full)
	_dim.draw_rect(Rect2(0.0, 0.0, full.size.x, h.position.y), color)
	_dim.draw_rect(Rect2(0.0, h.end.y, full.size.x, full.size.y - h.end.y), color)
	_dim.draw_rect(Rect2(0.0, h.position.y, h.position.x, h.size.y), color)
	_dim.draw_rect(Rect2(h.end.x, h.position.y, full.size.x - h.end.x, h.size.y), color)


## A new screen size (rotation, a window resize) places everything again.
func _on_dim_resized() -> void:
	if is_node_ready():
		_place()


func _on_next_pressed() -> void:
	if _step >= steps().size() - 1:
		_finish(true)
	else:
		_show_step(_step + 1)


func _on_back_pressed() -> void:
	_show_step(_step - 1)


func _on_skip_pressed() -> void:
	_finish(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish(false)


func _finish(completed: bool) -> void:
	if is_queued_for_deletion():
		return
	mark_seen(chapter)
	AnalyticsSink.track(&"tutorial_finished", {"completed": completed, "step": _step + 1, "chapter": String(chapter)})
	finished.emit(completed)
	queue_free()
