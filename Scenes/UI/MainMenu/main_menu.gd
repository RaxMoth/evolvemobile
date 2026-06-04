extends Node2D

## MainMenu — entry screen.
##
## Layout + styling now live in MainMenu.tscn (theme = ui_theme.tres). This
## script handles: button wiring, live currency labels, and a few bits of
## juice (card hover lift, title intro) that are awkward to express purely
## in the scene.

const WORLD_SCENE: PackedScene = preload("res://Scenes/World/World.tscn")
const META_SKILL_SCREEN: PackedScene = preload("res://Scenes/UI/MetaSkills/MetaSkillScreen.tscn")

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


func _ready() -> void:
	# Clear any leftover pause from a previous match's result screen.
	get_tree().paused = false

	_wire_play_buttons()
	_wire_skill_buttons()
	_setup_card_hover(heroes_card)
	_setup_card_hover(monster_card)
	_refresh_currency()
	PersistedData.currency_changed.connect(_on_currency_changed)

	_play_intro()


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
		hero_skills_btn.tooltip_text = "Permanent upgrades for all heroes"
		hero_skills_btn.pressed.connect(_open_meta_skills.bind(MetaSkillManager.TREE_HERO_BASE))
	if monster_skills_btn:
		monster_skills_btn.tooltip_text = "Permanent upgrades for the monster"
		monster_skills_btn.pressed.connect(_open_meta_skills.bind(MetaSkillManager.TREE_MONSTER_BASE))
	# Roster / individual trees ship later — keep disabled for now.
	for btn in [hero_updates_btn, monster_updates_btn]:
		if btn:
			btn.disabled = true
			btn.tooltip_text = "Coming soon"


func _open_meta_skills(preselect_tree_id: StringName) -> void:
	var screen: MetaSkillScreen = META_SKILL_SCREEN.instantiate() as MetaSkillScreen
	add_child(screen)
	await get_tree().process_frame
	for i in screen._tree_ids.size():
		if screen._tree_ids[i] == preselect_tree_id:
			screen.tree_picker.select(i)
			screen._show_tree(preselect_tree_id)
			break


func _on_play_as_hero() -> void:
	GameManager.chosen_side = MatchRewards.Side.HEROES
	get_tree().change_scene_to_packed.call_deferred(WORLD_SCENE)


func _on_play_as_monster() -> void:
	GameManager.chosen_side = MatchRewards.Side.MONSTER
	get_tree().change_scene_to_packed.call_deferred(WORLD_SCENE)


# ============================================
# Currency labels (live)
# ============================================

func _refresh_currency() -> void:
	steel_value.text = str(PersistedData.get_currency(PersistedData.STEEL))
	leaves_value.text = str(PersistedData.get_currency(PersistedData.LEAVES))
	gold_value.text = str(PersistedData.get_currency(PersistedData.GOLD))


func _on_currency_changed(_currency: StringName, _new_amount: int) -> void:
	_refresh_currency()
