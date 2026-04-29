extends Node2D

## MainMenu — entry screen for the game.
##
## Phase 1 wires the absolute basics:
##   • Play (Hero or Monster) → loads World.tscn
##   • Currency display (Steel / Leaves / Gold) at top of screen
##   • Skills / Updates buttons are placeholders (Phase 2 connects them
##     to skill trees)
##
## The elaborate hero/monster selection panels in MainMenu.tscn are
## intentionally left passive for now — they'll be hooked up in Phase 3
## when side selection and per-hero rosters become meaningful.

const WORLD_SCENE: PackedScene = preload("res://Scenes/World/World.tscn")

@onready var play_as_hero_btn: Button = %PlayAsHero
@onready var play_as_monster_btn: Button = %PlayAsMonster
@onready var hero_skills_btn: Button = %HeroSkills
@onready var hero_updates_btn: Button = %HeroUpdates
@onready var monster_skills_btn: Button = %MonsterSkills
@onready var monster_updates_btn: Button = %MonsterUpdates

# Currency HUD — created dynamically so the existing scene layout stays untouched.
var _currency_layer: CanvasLayer
var _steel_label: Label
var _leaves_label: Label
var _gold_label: Label


func _ready() -> void:
	# Make sure we're not still paused from a previous match's result screen.
	get_tree().paused = false

	_wire_play_buttons()
	_wire_placeholder_buttons()
	_build_currency_hud()
	_refresh_currency()
	PersistedData.currency_changed.connect(_on_currency_changed)


# ============================================
# Button wiring
# ============================================

func _wire_play_buttons() -> void:
	if play_as_hero_btn:
		play_as_hero_btn.pressed.connect(_on_play_as_hero)
	if play_as_monster_btn:
		play_as_monster_btn.pressed.connect(_on_play_as_monster)


func _wire_placeholder_buttons() -> void:
	# These buttons exist in the scene but their destinations don't ship
	# until Phase 2 (skill trees). Disable + dim them so they don't look
	# functional yet.
	for btn in [hero_skills_btn, hero_updates_btn, monster_skills_btn, monster_updates_btn]:
		if btn:
			btn.disabled = true
			btn.tooltip_text = "Coming soon"


func _on_play_as_hero() -> void:
	GameManager.chosen_side = MatchRewards.Side.HEROES
	get_tree().change_scene_to_packed.call_deferred(WORLD_SCENE)


func _on_play_as_monster() -> void:
	GameManager.chosen_side = MatchRewards.Side.MONSTER
	get_tree().change_scene_to_packed.call_deferred(WORLD_SCENE)


# ============================================
# Currency HUD
# ============================================

func _build_currency_hud() -> void:
	_currency_layer = CanvasLayer.new()
	_currency_layer.layer = 100
	add_child(_currency_layer)

	var bar := PanelContainer.new()
	bar.anchor_left = 0.0
	bar.anchor_top = 0.0
	bar.anchor_right = 1.0
	bar.anchor_bottom = 0.0
	bar.offset_left = 12
	bar.offset_top = 12
	bar.offset_right = -12
	bar.offset_bottom = 56
	_currency_layer.add_child(bar)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	bar.add_child(hbox)

	_steel_label = _make_currency_label(hbox, "Steel")
	_leaves_label = _make_currency_label(hbox, "Leaves")
	_gold_label = _make_currency_label(hbox, "Gold")


func _make_currency_label(parent: HBoxContainer, currency_name: String) -> Label:
	var lbl := Label.new()
	lbl.text = "%s: 0" % currency_name
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.set_meta("currency_name", currency_name)
	parent.add_child(lbl)
	return lbl


func _refresh_currency() -> void:
	_steel_label.text = "Steel: %d" % PersistedData.get_currency(PersistedData.STEEL)
	_leaves_label.text = "Leaves: %d" % PersistedData.get_currency(PersistedData.LEAVES)
	_gold_label.text = "Gold: %d" % PersistedData.get_currency(PersistedData.GOLD)


func _on_currency_changed(_currency: StringName, _new_amount: int) -> void:
	_refresh_currency()
