class_name TutorialOverlay
extends CanvasLayer

## First-run "How to play" walkthrough. Shown automatically once (PersistedData
## setting `tutorial_seen`) and on demand from the main menu's "How to play"
## button. The steps are data; TutorialOverlay.tscn owns layout and wiring.

signal finished(completed: bool)

const SETTING_SEEN: StringName = &"tutorial_seen"
## Alpha of the bg_void scrim behind the panel (the UnlockSheet's).
const SCRIM_ALPHA := 0.72

const STEPS: Array[Dictionary] = [
	{
		"title": "Pick a side",
		"body": "Play the Heroes or the Monster. The Heroes win by killing the monster before it grows too strong. The Monster wins by wiping the team — or by surviving the 10-minute timer.",
	},
	{
		"title": "Heroes: four AI companions",
		"body": "River, Vlad, Ted and Irelia explore the jungle on their own, clear mob camps for XP and hunt the monster once it is spotted. Tap a hero's panel to follow them. Your job is the setup, not the fight.",
	},
	{
		"title": "Monster: farm, evolve, ambush",
		"body": "Grount starts weak. Eat mob camps to reach Stage 2 (100 XP) and Stage 3 (300 XP), then strike. Stay in the fog until you are ready — the heroes only see what their scouts reveal.",
	},
	{
		"title": "Grow between matches",
		"body": "Every match pays Steel (heroes), Leaves (monster) and Gold, plus permanent XP for each character. Spend them in the Base skill trees from the main menu — upgrades apply to every future match.",
	},
]

@onready var title_label: Label = %Title
@onready var body_label: Label = %Body
@onready var progress_label: Label = %Progress
@onready var back_button: Button = %BackButton
@onready var next_button: Button = %NextButton

var _step: int = 0


static func has_been_seen() -> bool:
	return bool(PersistedData.get_setting(SETTING_SEEN, false))


static func mark_seen() -> void:
	PersistedData.set_setting(SETTING_SEEN, true)
	PersistedData.save_data()


func _ready() -> void:
	(%Dim as ColorRect).color = Color(UiPalette.get_default().bg_void, SCRIM_ALPHA)
	_show_step(0)


func current_step() -> int:
	return _step


func _show_step(index: int) -> void:
	_step = clampi(index, 0, STEPS.size() - 1)
	var step: Dictionary = STEPS[_step]
	title_label.text = tr(String(step.get("title", "")))
	body_label.text = tr(String(step.get("body", "")))
	progress_label.text = "%d / %d" % [_step + 1, STEPS.size()]
	back_button.disabled = _step == 0
	next_button.text = tr("Got it") if _step == STEPS.size() - 1 else tr("Next")


# --- scene-side connections (TutorialOverlay.tscn) ---

func _on_next_pressed() -> void:
	if _step >= STEPS.size() - 1:
		_finish(true)
	else:
		_show_step(_step + 1)


func _on_back_pressed() -> void:
	_show_step(_step - 1)


func _on_skip_pressed() -> void:
	_finish(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish(false)


func _finish(completed: bool) -> void:
	mark_seen()
	AnalyticsSink.track(&"tutorial_finished", {"completed": completed, "step": _step + 1})
	finished.emit(completed)
	queue_free()
