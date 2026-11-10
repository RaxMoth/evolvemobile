extends Node2D

## MainMenu — the old entry screen. The main scene is now MenuRoot
## (Scenes/UI/Screens); this one stays reachable from the match result's Main
## Menu button until the Phase 8 screens retire it.
##
## Layout + styling now live in MainMenu.tscn (theme = ui_theme.tres). This
## script handles: button wiring, live currency labels, and a few bits of
## juice (card hover lift, title intro) that are awkward to express purely
## in the scene.

# The match is not preloaded (the boot chain GameManager -> MatchResult ->
# MainMenu would load it before the menu could draw): _ready starts
# GameManager's background load, the play buttons collect it.
const META_SKILL_SCREEN: PackedScene = preload("res://Scenes/UI/MetaSkills/MetaSkillScreen.tscn")
const TUTORIAL_SCENE: PackedScene = preload("res://Scenes/UI/Tutorial/TutorialOverlay.tscn")
const PRE_ROUND_SCENE: PackedScene = preload("res://Scenes/UI/PreRoundSetup/PreRoundSetup.tscn")

@onready var play_as_hero_btn: Button = %PlayAsHero
@onready var play_as_monster_btn: Button = %PlayAsMonster
@onready var hero_skills_btn: Button = %HeroSkills
@onready var hero_updates_btn: Button = %HeroUpdates
@onready var monster_skills_btn: Button = %MonsterSkills
@onready var monster_updates_btn: Button = %MonsterUpdates

@onready var heroes_card: PanelContainer = %HeroesCard
@onready var monster_card: PanelContainer = %MonsterCard
@onready var title_block: VBoxContainer = %TitleBlock

@onready var steel_value: Label = %SteelValue
@onready var leaves_value: Label = %LeavesValue
@onready var gold_value: Label = %GoldValue

@onready var settings_btn: Button = %SettingsButton
@onready var how_to_play_btn: Button = %HowToPlayButton

# Per-hero level labels (hero_id -> Label), built in code and refreshed from
# the PersistedData XP signals. The monster side has a single character.
var _hero_level_labels: Dictionary = {}
var _monster_level_label: Label = null
var _monster_progress_bar: ProgressBar = null

const _HERO_ACCENT := Color(0.62, 0.78, 0.96, 0.92)
const _MONSTER_ACCENT := Color(0.96, 0.62, 0.58, 0.92)
const _ROW_MUTED := Color(0.66, 0.7, 0.74, 0.85)


func _ready() -> void:
	# Clear any leftover pause from a previous match's result screen.
	get_tree().paused = false

	# Load the match while the player looks at the menu (first visit only:
	# GameManager keeps the loaded scene for the session).
	GameManager.request_world_load()

	_wire_play_buttons()
	_wire_skill_buttons()
	if settings_btn:
		settings_btn.pressed.connect(_open_settings)
	if how_to_play_btn:
		how_to_play_btn.pressed.connect(_open_tutorial)
	_setup_card_hover(heroes_card)
	_setup_card_hover(monster_card)
	_refresh_currency()
	PersistedData.currency_changed.connect(_on_currency_changed)

	_build_progression()
	PersistedData.hero_xp_changed.connect(_on_hero_xp_changed)
	PersistedData.monster_xp_changed.connect(_on_monster_xp_changed)

	_play_intro()
	AudioManager.play_music(&"menu")
	_wire_ui_clicks()

	# First run: walk the player through the loop once the intro has settled.
	if not TutorialOverlay.has_been_seen():
		get_tree().create_timer(0.9).timeout.connect(_auto_open_tutorial)


# ============================================
# Intro juice
# ============================================

func _play_intro() -> void:
	# NOTE: these nodes live inside VBox/HBox containers, which overwrite a
	# child's `position` and `size` every layout pass. So we only animate
	# `modulate` and `scale` here — both are left untouched by containers.

	# Wait one frame so containers have laid out and sizes are valid; then
	# pivot each node at its center so the pop-in scales symmetrically.
	await get_tree().process_frame

	if title_block:
		title_block.pivot_offset = title_block.size * 0.5
		title_block.modulate.a = 0.0
		title_block.scale = Vector2(0.92, 0.92)
		var t := create_tween().set_parallel(true)
		t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(title_block, "modulate:a", 1.0, 0.5)
		t.tween_property(title_block, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK)

	# Cards fade + pop in, staggered.
	_intro_card(heroes_card, 0.08)
	_intro_card(monster_card, 0.16)


func _intro_card(card: Control, delay: float) -> void:
	if not card:
		return
	card.pivot_offset = card.size * 0.5
	card.modulate.a = 0.0
	card.scale = Vector2(0.94, 0.94)
	var t := create_tween().set_parallel(true)
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(card, "modulate:a", 1.0, 0.45).set_delay(delay)
	t.tween_property(card, "scale", Vector2.ONE, 0.5).set_delay(delay).set_trans(Tween.TRANS_BACK)


# ============================================
# Card hover lift (desktop / pointer feedback)
# ============================================

func _setup_card_hover(card: Control) -> void:
	if not card:
		return
	# Pivot at center so the scale grows symmetrically.
	card.pivot_offset = card.size * 0.5
	card.mouse_entered.connect(_on_card_hover.bind(card, true))
	card.mouse_exited.connect(_on_card_hover.bind(card, false))


func _on_card_hover(card: Control, hovering: bool) -> void:
	card.pivot_offset = card.size * 0.5
	var target := Vector2(1.03, 1.03) if hovering else Vector2.ONE
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(card, "scale", target, 0.18)


# ============================================
# Button wiring
# ============================================

func _wire_play_buttons() -> void:
	if play_as_hero_btn:
		play_as_hero_btn.pressed.connect(_on_play_as_hero)
	if play_as_monster_btn:
		play_as_monster_btn.pressed.connect(_on_play_as_monster)


func _wire_skill_buttons() -> void:
	if hero_skills_btn:
		hero_skills_btn.tooltip_text = "Permanent upgrades for all heroes"  # auto-translated when shown
		hero_skills_btn.pressed.connect(_open_meta_skills.bind(MetaSkillManager.TREE_HERO_BASE))
	if monster_skills_btn:
		monster_skills_btn.tooltip_text = "Permanent upgrades for the monster"
		monster_skills_btn.pressed.connect(_open_meta_skills.bind(MetaSkillManager.TREE_MONSTER_BASE))
	# Per-character trees: the hero button opens the first hero tree, the
	# monster button the monster's own tree (the picker lists the rest).
	if hero_updates_btn:
		hero_updates_btn.tooltip_text = "Individual hero upgrades (Steel)"
		hero_updates_btn.pressed.connect(_open_meta_skills.bind(MetaSkillManager.hero_tree_id(GameManager.KNOWN_HERO_IDS[0])))
	if monster_updates_btn:
		monster_updates_btn.tooltip_text = "Individual monster upgrades (Leaves)"
		monster_updates_btn.pressed.connect(_open_meta_skills.bind(MetaSkillManager.monster_tree_id(GameManager.played_monster_id())))


func _open_meta_skills(preselect_tree_id: StringName) -> void:
	var screen: MetaSkillScreen = META_SKILL_SCREEN.instantiate() as MetaSkillScreen
	screen.initial_tree_id = preselect_tree_id
	# Overlays go under the menu's Root Control (canvas layer 1): a sibling of
	# the CanvasLayers would sit on layer 0, BELOW Root's full-screen STOP area,
	# and never receive a tap.
	%Root.add_child(screen)


func _wire_ui_clicks() -> void:
	# Autoloads cannot be scene [connection] targets, so the click SFX is wired here.
	for btn in [play_as_hero_btn, play_as_monster_btn, hero_skills_btn, hero_updates_btn,
			monster_skills_btn, monster_updates_btn, settings_btn, how_to_play_btn]:
		if btn:
			btn.pressed.connect(AudioManager.play_ui_click)


func _auto_open_tutorial() -> void:
	# Re-check: the player may have opened and finished it within the delay.
	if not TutorialOverlay.has_been_seen():
		_open_tutorial()


func _open_tutorial() -> void:
	if get_node_or_null("TutorialOverlay"):
		return
	add_child(TUTORIAL_SCENE.instantiate())


func _open_settings() -> void:
	%Root.add_child(SettingsScreen.new())


func _on_play_as_hero() -> void:
	GameManager.chosen_side = MatchRewards.Side.HEROES
	if get_node_or_null("PreRoundSetup"):
		return
	# Strategy first (README round structure step 1); the screen persists the
	# MatchConfig and only asks us to start.
	var setup := PRE_ROUND_SCENE.instantiate() as PreRoundSetup
	setup.start_requested.connect(_start_hero_match)
	add_child(setup)


func _start_hero_match(config: MatchConfig) -> void:
	GameManager.begin_hunt(config.quarry_id)
	get_tree().change_scene_to_packed.call_deferred(GameManager.get_world_scene())


func _on_play_as_monster() -> void:
	GameManager.chosen_side = MatchRewards.Side.MONSTER
	GameManager.begin_hunt()
	get_tree().change_scene_to_packed.call_deferred(GameManager.get_world_scene())


# ============================================
# Permanent progression (per-character levels)
# ============================================

## Builds a compact "Progression" strip on each side card, inserted just above
## the Filler spacer so it sits under the description. Labels are cached so the
## PersistedData XP signals can update them in place without a rebuild.
func _build_progression() -> void:
	_hero_level_labels.clear()

	var hero_panel := _make_progression_panel(_HERO_ACCENT)
	for hero_id in GameManager.KNOWN_HERO_IDS:
		var value := _add_level_row(hero_panel, _display_name(hero_id))
		value.text = tr("Lv %d") % PersistedData.level_from_xp(PersistedData.get_hero_xp(hero_id))
		_hero_level_labels[hero_id] = value
	_insert_before_filler(heroes_card, hero_panel)

	var monster_panel := _make_progression_panel(_MONSTER_ACCENT)
	var monster_id: StringName = GameManager.played_monster_id()
	_monster_level_label = _add_level_row(monster_panel, _display_name(monster_id))
	_monster_progress_bar = ProgressBar.new()
	_monster_progress_bar.custom_minimum_size = Vector2(0, 6)
	_monster_progress_bar.show_percentage = false
	_monster_progress_bar.modulate = _MONSTER_ACCENT
	monster_panel.add_child(_monster_progress_bar)
	_refresh_monster_progress(PersistedData.get_monster_xp(monster_id))
	_insert_before_filler(monster_card, monster_panel)


func _make_progression_panel(accent: Color) -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 4)
	var header := Label.new()
	header.text = "PROGRESSION"  # key: the Label auto-translates and re-translates on language change
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 0.55))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(header)
	return panel


## Adds a "Name .......... Lv N" row and returns the (right-aligned) value Label.
func _add_level_row(panel: VBoxContainer, character_name: String) -> Label:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = character_name
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", _ROW_MUTED)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var value_label := Label.new()
	value_label.add_theme_font_size_override("font_size", 13)
	value_label.add_theme_color_override("font_color", _ROW_MUTED)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	panel.add_child(row)
	return value_label


## Inserts `panel` into a side card's VBox just above its Filler spacer.
func _insert_before_filler(card: Control, panel: Control) -> void:
	var vbox := card.get_node("VBox") as VBoxContainer
	vbox.add_child(panel)
	var filler := vbox.get_node_or_null("Filler")
	if filler:
		vbox.move_child(panel, filler.get_index())


func _display_name(character_id: StringName) -> String:
	return String(character_id).capitalize()


func _refresh_monster_progress(total_xp: int) -> void:
	if _monster_level_label == null:
		return
	var prog := PersistedData.level_progress(total_xp)
	_monster_level_label.text = tr("Lv %d") % int(prog.level)
	if _monster_progress_bar:
		_monster_progress_bar.max_value = maxf(1.0, float(prog.needed))
		_monster_progress_bar.value = float(prog.into)


func _on_hero_xp_changed(hero_id: StringName, new_xp: int) -> void:
	if _hero_level_labels.has(hero_id):
		var value: Label = _hero_level_labels[hero_id]
		value.text = tr("Lv %d") % PersistedData.level_from_xp(new_xp)


func _on_monster_xp_changed(monster_id: StringName, new_xp: int) -> void:
	if monster_id == GameManager.played_monster_id():
		_refresh_monster_progress(new_xp)


# ============================================
# Currency labels (live)
# ============================================

func _refresh_currency() -> void:
	steel_value.text = str(PersistedData.get_currency(PersistedData.STEEL))
	leaves_value.text = str(PersistedData.get_currency(PersistedData.LEAVES))
	gold_value.text = str(PersistedData.get_currency(PersistedData.GOLD))


func _on_currency_changed(_currency: StringName, _new_amount: int) -> void:
	_refresh_currency()
