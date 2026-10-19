class_name PreRoundSetup
extends CanvasLayer

## Pre-round strategy screen for the hero side (README "Round Structure" step 1).
## Emits start_requested(config) — the caller changes the scene; this screen
## only edits and persists a MatchConfig. Layout + button wiring live in
## PreRoundSetup.tscn; slider value_changed needs bound args, so it is wired here.

signal start_requested(config: MatchConfig)
signal cancelled

@onready var aggression_slider: HSlider = %AggressionSlider
@onready var farming_slider: HSlider = %FarmingSlider
@onready var exploration_slider: HSlider = %ExplorationSlider
@onready var aggression_value: Label = %AggressionValue
@onready var farming_value: Label = %FarmingValue
@onready var exploration_value: Label = %ExplorationValue
@onready var formation_picker: OptionButton = %FormationPicker

const FORMATION_LABELS: Array[String] = ["Tight", "Spread", "Line"]


func _ready() -> void:
	var cfg := MatchConfig.from_settings()
	aggression_slider.value = cfg.aggression
	farming_slider.value = cfg.farming
	exploration_slider.value = cfg.exploration
	formation_picker.clear()
	for label in FORMATION_LABELS:
		formation_picker.add_item(tr(label))
	formation_picker.select(int(cfg.formation))
	for pair in [[aggression_slider, aggression_value], [farming_slider, farming_value], [exploration_slider, exploration_value]]:
		var slider: HSlider = pair[0]
		var label: Label = pair[1]
		slider.value_changed.connect(_on_slider_changed.bind(label))
		label.text = _percent(slider.value)


func collect_config() -> MatchConfig:
	var cfg := MatchConfig.new()
	cfg.aggression = aggression_slider.value
	cfg.farming = farming_slider.value
	cfg.exploration = exploration_slider.value
	cfg.formation = clampi(formation_picker.selected, 0, MatchConfig.Formation.size() - 1) as MatchConfig.Formation
	return cfg


func _on_slider_changed(value: float, label: Label) -> void:
	label.text = _percent(value)


func _percent(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)


# --- scene-side connections (PreRoundSetup.tscn) ---

func _on_start_pressed() -> void:
	var cfg := collect_config()
	cfg.save_to_settings()
	AnalyticsSink.track(&"pre_round_setup", {
		"aggression": cfg.aggression, "farming": cfg.farming,
		"exploration": cfg.exploration, "formation": int(cfg.formation),
	})
	start_requested.emit(cfg)
	queue_free()


func _on_back_pressed() -> void:
	cancelled.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()
