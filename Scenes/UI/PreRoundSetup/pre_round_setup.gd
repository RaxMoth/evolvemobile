class_name PreRoundSetup
extends CanvasLayer

## Pre-round strategy screen for the hero side (README "Round Structure" step 1).
## Emits start_requested(config) — the caller changes the scene; this screen
## only edits and persists a MatchConfig. Layout + button wiring live in
## PreRoundSetup.tscn; slider value_changed needs bound args, so it is wired here.
## It names tonight's quarry (GameManager.next_quarry(), "NEW QUARRY" on a
## first sighting) and hands it on in the config's quarry_id; the Change picker
## and the banner are the new pre-round screen's (Phase 8).

signal start_requested(config: MatchConfig)
signal cancelled

@onready var aggression_slider: HSlider = %AggressionSlider
@onready var farming_slider: HSlider = %FarmingSlider
@onready var exploration_slider: HSlider = %ExplorationSlider
@onready var aggression_value: Label = %AggressionValue
@onready var farming_value: Label = %FarmingValue
@onready var exploration_value: Label = %ExplorationValue
@onready var formation_picker: OptionButton = %FormationPicker
@onready var preview_label: Label = %Preview
@onready var quarry_label: Label = %Quarry

## The monster this hunt faces (GameManager.next_quarry() when the screen opens).
var quarry_id: StringName = &""

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
	formation_picker.item_selected.connect(func(_i: int) -> void: _refresh_preview())
	_refresh_preview()
	quarry_id = GameManager.next_quarry()
	var quarry := GameManager.ROSTER.find(quarry_id)
	quarry_label.text = tr("Tonight's quarry: %s") % (quarry.get_display_name() if quarry != null else String(quarry_id))
	if GameManager.is_new_quarry(quarry_id):
		quarry_label.text += "  ·  " + tr("NEW QUARRY")


func collect_config() -> MatchConfig:
	var cfg := MatchConfig.new()
	cfg.aggression = aggression_slider.value
	cfg.farming = farming_slider.value
	cfg.exploration = exploration_slider.value
	cfg.formation = clampi(formation_picker.selected, 0, MatchConfig.Formation.size() - 1) as MatchConfig.Formation
	cfg.quarry_id = quarry_id
	return cfg


func _on_slider_changed(value: float, label: Label) -> void:
	label.text = _percent(value)
	_refresh_preview()


## Plain-words preview of what the AI will actually do with these values.
func _refresh_preview() -> void:
	if preview_label == null:
		return
	var cfg := collect_config()
	preview_label.text = tr("Ultimates fire at %d+ enemies or when an ally drops below %d%% HP. Mob camps weigh %d vs. 100 for the monster. New targets every %.1f s, scanning %d px ahead, %d px apart.") % [
		cfg.auto_ult_min_enemies(), roundi(cfg.auto_ult_panic_hp_pct() * 100.0), roundi(cfg.priority_mob()),
		cfg.exploration_update_interval(), roundi(cfg.search_radius()), roundi(cfg.formation_spread_px())]


func _percent(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)


# --- scene-side connections (PreRoundSetup.tscn) ---

func _on_start_pressed() -> void:
	var cfg := collect_config()
	cfg.save_to_settings()
	AnalyticsSink.track(&"pre_round_setup", {
		"aggression": cfg.aggression, "farming": cfg.farming,
		"exploration": cfg.exploration, "formation": int(cfg.formation),
		"quarry": String(cfg.quarry_id),
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
