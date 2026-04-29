extends CanvasLayer
class_name MatchResultScreen

## MatchResultScreen — overlay shown when a match ends.
## Populated by GameManager via `populate(result)`. Stays visible while
## the world is paused (process_mode = ALWAYS) so its buttons still work.

# Preloaded packed scene → bypasses runtime path resolution, never silently
# fails on a typo. change_scene_to_packed is the safest way to swap scenes.
const MAIN_MENU_SCENE: PackedScene = preload("res://Scenes/UI/MainMenu/MainMenu.tscn")

@onready var outcome_label: Label = %OutcomeLabel
@onready var duration_value: Label = %DurationValue
@onready var kills_value: Label = %KillsValue
@onready var survivors_row: HBoxContainer = %SurvivorsRow
@onready var survivors_value: Label = %SurvivorsValue
@onready var stage_row: HBoxContainer = %StageRow
@onready var stage_value: Label = %StageValue
@onready var steel_row: HBoxContainer = %SteelRow
@onready var steel_value: Label = %SteelValue
@onready var leaves_row: HBoxContainer = %LeavesRow
@onready var leaves_value: Label = %LeavesValue
@onready var gold_value: Label = %GoldValue
@onready var play_again_btn: Button = %PlayAgainButton
@onready var main_menu_btn: Button = %MainMenuButton


func _ready() -> void:
	# Stay responsive while the world is paused. Explicitly mark the buttons
	# too — relying on PROCESS_MODE_INHERIT through the CenterContainer →
	# PanelContainer chain has bitten us before. Belt-and-suspenders.
	process_mode = Node.PROCESS_MODE_ALWAYS
	play_again_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	main_menu_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	play_again_btn.pressed.connect(_on_play_again)
	main_menu_btn.pressed.connect(_on_main_menu)


func populate(result: MatchRewards.Result) -> void:
	if not is_inside_tree():
		# populate() may be called before _ready completes — defer until
		# @onready vars resolve.
		await ready

	outcome_label.text = MatchRewards.outcome_label(result.outcome)
	outcome_label.modulate = _color_for_outcome(result.outcome)

	duration_value.text = MatchRewards.format_duration(result.duration_sec)
	kills_value.text = str(result.mob_kills)

	# Side-specific stat row visibility.
	if result.side == MatchRewards.Side.HEROES:
		survivors_row.visible = true
		stage_row.visible = false
		survivors_value.text = "%d / 4" % result.heroes_alive
	else:
		survivors_row.visible = false
		stage_row.visible = true
		stage_value.text = "Stage %d" % result.monster_stage

	# Currency rows — only show what was actually earned.
	steel_row.visible = result.steel > 0
	leaves_row.visible = result.leaves > 0
	steel_value.text = "+%d" % result.steel
	leaves_value.text = "+%d" % result.leaves
	gold_value.text = "+%d" % result.gold


func _color_for_outcome(outcome: int) -> Color:
	match outcome:
		MatchRewards.Outcome.WIN: return Color(0.4, 1.0, 0.5)
		MatchRewards.Outcome.LOSS: return Color(1.0, 0.4, 0.4)
		MatchRewards.Outcome.TIMEOUT: return Color(1.0, 0.85, 0.3)
	return Color.WHITE


# ============================================
# Buttons
# ============================================

func _on_play_again() -> void:
	get_tree().paused = false
	# Reload the current scene cleanly. Defer so we don't free our own UI
	# from inside its own input callback.
	get_tree().reload_current_scene.call_deferred()


func _on_main_menu() -> void:
	get_tree().paused = false
	# change_scene_to_packed with a preload is the most reliable scene swap —
	# no path lookup, no Error to silently swallow inside call_deferred.
	get_tree().change_scene_to_packed.call_deferred(MAIN_MENU_SCENE)
