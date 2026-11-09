class_name CharacterDetail
extends Control

## One character, opened from its roster card or its rig in the lobby, in two
## modes (the OVERVIEW / SKILL TREE tabs):
##   - OVERVIEW: the character big on its stage (its live rig with the stage
##     idle; a tap cheers), the role pill, "Lv.N" and the XP bar toward the next
##     level, six StatTiles read from its HeroStats or MonsterStats (stat_rows),
##     and its abilities as AbilityTiles (the .tres icon and name; the toggled
##     one shows its description underneath).
##   - SKILL TREE: the stage folds into a compact header (head portrait, name,
##     level, XP), the character's tree as a SkillTreeView
##     (UxTreeModel.from_meta_skills) and the bottom sheet of the selected node:
##     rank and tier, what it gives now and next, its price (in the danger
##     colour when the wallet is short) and UPGRADE, disabled and showing the
##     reason ("Learn a Tier 1 skill first", "Maxed", "Need 340 more") when the
##     node cannot be bought. The tab carries an up-arrow badge with the
##     number of ranks ready to buy.
## show_base_tree() opens the screen on an account-wide tree instead (the
## Growth tab: hero_base or monster_base by side) in TREE mode, without tabs,
## under the side's crest.
##
## UPGRADE only reports upgrade_requested(tree_id, node_id): MenuRoot buys the
## node's next rank (MetaSkillManager.rank_up) and calls refresh() once
## skills_changed or currency_changed fired; the bought node then pops. Every
## connection inside the screen is in CharacterDetail.tscn, and MenuRoot
## connects its signals.

signal back_requested
signal tab_selected(tab_id: StringName)
signal upgrade_requested(tree_id: StringName, node_id: StringName)

enum Mode { OVERVIEW, TREE }

## Captions of the ability slots, in CharacterDef.ability_slots() order.
const SLOT_KINDS: PackedStringArray = ["PASSIVE", "BASIC", "ACTIVE", "ULTIMATE"]
const STAT_ICON_PATH := "res://Assets/UI/Icons/Stats/%s.svg"
## The ability described when a character opens: the ultimate (or the last
## one the character has).
const DEFAULT_ABILITY := 3
const MODE_FADE := 0.2

@export var mode: Mode = Mode.OVERVIEW
## Header art of the account-wide trees (show_base_tree).
@export var crest_heroes: Texture2D
@export var crest_monster: Texture2D

## The character shown; null on an account-wide tree.
var character: CharacterDef = null
## Side of the account-wide tree shown (MatchRewards.Side), -1 for a character.
var base_side: int = -1
## The tree of the SKILL TREE mode and its model (rebuilt by refresh()).
var tree_id: StringName = &""
var model: UxTreeModel = null

## Made here, not as scene sub-resources: the two detail instances in MenuRoot
## must not share their groups.
var _tab_group := ButtonGroup.new()
var _ability_group := ButtonGroup.new()
## The node an UPGRADE was asked for and its rank then (pop once bought).
var _buying: StringName = &""
var _buying_rank: int = 0
var _fade: Tween = null

@onready var _top_bar: TopBar = %TopBar
@onready var _nav: NavBar = %NavBar
@onready var _stage: PanelContainer = %Stage
@onready var _stage_inner: PanelContainer = %StageInner
@onready var _showcase: StageCharacter = %Showcase
@onready var _role_icon: TextureRect = %RoleIcon
@onready var _role: Label = %Role
@onready var _level: Label = %Level
@onready var _xp: ProgressBar = %Xp
@onready var _xp_text: Label = %XpText
@onready var _header: PanelContainer = %Header
@onready var _head_icon: TextureRect = %HeadIcon
@onready var _head_name: Label = %HeadName
@onready var _head_level: Label = %HeadLevel
@onready var _head_xp: ProgressBar = %HeadXp
@onready var _head_blurb: Label = %HeadBlurb
@onready var _tabs: Control = %Tabs
@onready var _overview_tab: Button = %OverviewTab
@onready var _tree_tab: Button = %TreeTab
@onready var _tree_badge: Control = %TreeBadge
@onready var _tree_badge_count: Label = %TreeBadgeCount
@onready var _overview: Control = %Overview
@onready var _stats: GridContainer = %Stats
@onready var _abilities: HBoxContainer = %Abilities
@onready var _ability_name: Label = %AbilityName
@onready var _ability_desc: Label = %AbilityDesc
@onready var _tree_view: SkillTreeView = %TreeView
@onready var _sheet: PanelContainer = %Sheet
@onready var _node_icon: TextureRect = %NodeIcon
@onready var _node_name: Label = %NodeName
@onready var _node_meta: Label = %NodeMeta
@onready var _effect_now: Label = %EffectNow
@onready var _effect_next: Label = %EffectNext
@onready var _cost: Control = %Cost
@onready var _cost_icon: TextureRect = %CostIcon
@onready var _cost_value: Label = %CostValue
@onready var _upgrade: Button = %Upgrade


func _ready() -> void:
	_overview_tab.button_group = _tab_group
	_tree_tab.button_group = _tab_group
	for tile in ability_tiles():
		tile.button_group = _ability_group
	_show_node(&"")
	_apply_mode(false)


## Opens `def` in `p_mode`: its stage, numbers, abilities and tree.
func show_character(def: CharacterDef, p_mode: Mode = Mode.OVERVIEW) -> void:
	var new_tree: StringName = def.skill_tree_id() if def != null else &""
	if new_tree != tree_id:
		_tree_view.selected = &""
	character = def
	base_side = -1
	tree_id = new_tree
	var monster := def != null and def.is_monster()
	_top_bar.title = def.get_display_name() if def != null else ""
	_set_currencies(monster)
	_nav.active_tab = own_tab()
	_nav.monster_side = GameManager.chosen_side == MatchRewards.Side.MONSTER
	_stage.theme_type_variation = &"CharacterCardMonster" if monster else &"CharacterCard"
	_stage_inner.theme_type_variation = &"CardInnerMonster" if monster else &"CardInnerHero"
	_showcase.character = def
	_role.text = def.role_text if def != null else ""
	_role_icon.texture = def.role_icon() if def != null else null
	_head_icon.texture = def.head_texture() if def != null else null
	_head_name.text = _top_bar.title
	_head_level.visible = true
	_head_xp.visible = true
	_head_blurb.visible = false
	_tabs.visible = true
	_fill_stats()
	_fill_abilities()
	refresh()
	set_mode(p_mode, false)


## Opens the account-wide tree of `side` (MatchRewards.Side): Hero Base or
## Monster Base, bought with Gold, under the side's crest.
func show_base_tree(side: int) -> void:
	var monster := side == MatchRewards.Side.MONSTER
	var new_tree: StringName = MetaSkillManager.TREE_MONSTER_BASE if monster else MetaSkillManager.TREE_HERO_BASE
	if new_tree != tree_id:
		_tree_view.selected = &""
	character = null
	base_side = MatchRewards.Side.MONSTER if monster else MatchRewards.Side.HEROES
	tree_id = new_tree
	_top_bar.title = "Growth"
	_set_currencies(monster)
	_nav.active_tab = own_tab()
	_nav.monster_side = GameManager.chosen_side == MatchRewards.Side.MONSTER
	_showcase.character = null
	_head_icon.texture = crest_monster if monster else crest_heroes
	_head_level.visible = false
	_head_xp.visible = false
	_head_blurb.visible = true
	_tabs.visible = false
	refresh()
	set_mode(Mode.TREE, false)


## The nav bar tab this screen belongs to.
func own_tab() -> StringName:
	if character == null:
		return &"growth"
	return &"monsters" if character.is_monster() else &"heroes"


## Re-reads the save: level and XP, the tab badge, the tree and the sheet.
## The node an UPGRADE was asked for pops once it gained a rank.
func refresh() -> void:
	if character != null:
		var p := CharacterProgress.progress(character)
		var lv: int = p["level"]
		var into: int = p["into"]
		var needed: int = p["needed"]
		_level.text = tr("Lv.%d") % lv
		_head_level.text = _level.text
		for bar: ProgressBar in [_xp, _head_xp]:
			bar.max_value = maxi(needed, 1)
			bar.value = clampi(into, 0, maxi(needed, 1))
		_xp_text.text = tr("%d / %d XP") % [into, needed]
		var ready_ranks := CharacterProgress.upgrades_ready(character)
		_tree_badge.visible = ready_ranks > 0
		_tree_badge_count.text = str(ready_ranks)
	model = UxTreeModel.from_meta_skills(tree_id, _ability_icons()) if not tree_id.is_empty() else null
	if character == null and model != null:
		_head_name.text = model.title
		_head_blurb.text = model.description
	_tree_view.build(model)
	_show_node(_tree_view.selected)
	if not _buying.is_empty():
		var bought: UxTreeModel.TreeNodeData = model.find(_buying) if model != null else null
		if bought != null and bought.rank > _buying_rank:
			_tree_view.pop(_buying)
		_buying = &""


## Switches between OVERVIEW and SKILL TREE (an account tree is always TREE).
func set_mode(m: Mode, animate: bool = true) -> void:
	mode = Mode.TREE if character == null else m
	_apply_mode(animate)


## The six numbers of the overview for `def`: [icon key, value, caption],
## read from its HeroStats (the basic attack's cooldown gives the attack
## speed) or its MonsterStats (stage I numbers and the evolution thresholds).
static func stat_rows(def: CharacterDef) -> Array[Array]:
	var rows: Array[Array] = []
	if def == null:
		return rows
	if def.stats is HeroStats:
		var s := def.stats as HeroStats
		var slots := def.ability_slots()
		var basic: AbilityBase = slots[1] if slots.size() > 1 else null
		var rate := "-"
		if basic != null and basic.cooldown > 0.0:
			rate = "%.2f/s" % (1.0 / basic.cooldown)
		rows.append(["stat_hp", _number(s.base_max_health), "Health"])
		rows.append(["stat_damage", _number(s.base_attack_damage), "Damage"])
		rows.append(["stat_attack_speed", rate, "Attack speed"])
		rows.append(["stat_range", _number(s.base_attack_range), "Range"])
		rows.append(["stat_speed", _number(s.base_move_speed), "Move speed"])
		rows.append(["stat_vision", _number(s.vision_radius), "Vision"])
	elif def.stats is MonsterStats:
		var m := def.stats as MonsterStats
		var xp_format := TranslationServer.translate("%d XP")
		rows.append(["stat_hp", _number(m.stage_1_health), "Health"])
		rows.append(["stat_damage", "×%.1f" % m.stage_1_damage_multiplier, "Damage"])
		rows.append(["stat_speed", _number(m.stage_1_speed), "Move speed"])
		rows.append(["stat_xp", xp_format % m.stage_2_xp, "Stage II"])
		rows.append(["stat_level", xp_format % m.stage_3_xp, "Stage III"])
		rows.append(["stat_threat", _number(m.stage_3_health), "Health at Stage III"])
	return rows


## Whole numbers with thousands commas ("2,200"), others with one decimal.
static func _number(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return CurrencyChip.format_amount(roundi(v))
	return "%.1f" % v


func stat_tiles() -> Array[StatTile]:
	var out: Array[StatTile] = []
	for c in _stats.get_children():
		if c is StatTile:
			out.append(c as StatTile)
	return out


func ability_tiles() -> Array[AbilityTile]:
	var out: Array[AbilityTile] = []
	for c in _abilities.get_children():
		if c is AbilityTile:
			out.append(c as AbilityTile)
	return out


func tree_view() -> SkillTreeView:
	return _tree_view


func _set_currencies(monster: bool) -> void:
	_top_bar.show_steel = not monster
	_top_bar.show_leaves = monster


func _fill_stats() -> void:
	var rows := stat_rows(character)
	var tiles := stat_tiles()
	for i in tiles.size():
		var tile := tiles[i]
		tile.visible = i < rows.size()
		if i < rows.size():
			var row: Array = rows[i]
			tile.show_stat(load(STAT_ICON_PATH % row[0]) as Texture2D, row[1], row[2])


func _fill_abilities() -> void:
	var slots: Array[AbilityBase] = []
	if character != null:
		slots = character.ability_slots()
	var tiles := ability_tiles()
	var shown := -1
	for i in tiles.size():
		var ability: AbilityBase = slots[i] if i < slots.size() else null
		tiles[i].show_ability(SLOT_KINDS[i] if i < SLOT_KINDS.size() else "", ability)
		if ability != null and (shown < 0 or i <= DEFAULT_ABILITY):
			shown = i
	if shown >= 0:
		tiles[shown].button_pressed = true
	_show_ability(shown)


func _show_ability(index: int) -> void:
	var tiles := ability_tiles()
	var ability: AbilityBase = tiles[index].ability if index >= 0 and index < tiles.size() else null
	if ability == null:
		_ability_name.text = ""
		_ability_desc.text = ""
		return
	_ability_name.text = "%s  ·  %s" % [ability.ability_name, tr(SLOT_KINDS[index]).capitalize()]
	_ability_desc.text = ability.description


## ability_name -> icon of the character's abilities (fallback node icons).
func _ability_icons() -> Dictionary:
	var icons := {}
	if character != null:
		for ability in character.abilities():
			icons[ability.ability_name] = ability.icon
	return icons


## The bottom sheet for node `id` (empty: nothing selected yet).
func _show_node(id: StringName) -> void:
	var n: UxTreeModel.TreeNodeData = null
	if model != null and not id.is_empty():
		n = model.find(id)
	if n == null:
		_node_icon.texture = null
		_node_name.text = "Tap a node"
		_node_meta.text = ""
		_effect_now.text = ""
		_effect_next.text = ""
		_cost.visible = false
		_upgrade.text = "UPGRADE"
		_upgrade.disabled = true
		return
	_node_icon.texture = n.icon
	_node_name.text = n.name
	var meta := tr("Rank %d/%d · Tier %d") % [n.rank, n.max_rank(), n.tier]
	if n.branch < model.columns() and not model.branches[n.branch].is_empty():
		meta += " · " + model.branches[n.branch]
	_node_meta.text = meta
	_effect_now.text = tr("Now: %s") % n.effect_at(n.rank) if n.rank > 0 else tr("Not learned yet")
	var maxed := n.rank >= n.max_rank()
	_effect_next.text = "" if maxed else tr("Next: %s") % n.effect_at(n.rank + 1)
	_cost.visible = not maxed
	_cost_icon.texture = CurrencyChip.icon_for(model.currency)
	_cost_value.text = CurrencyChip.format_amount(n.next_cost())
	if model.affordable(n):
		_cost_value.remove_theme_color_override(&"font_color")
	else:
		_cost_value.add_theme_color_override(&"font_color", UiPalette.get_default().danger)
	var reason := model.block_reason(n)
	if not reason.is_empty():
		_upgrade.text = reason
		_upgrade.disabled = true
	elif not model.affordable(n):
		_upgrade.text = tr("Need %s more") % CurrencyChip.format_amount(n.next_cost() - model.wallet)
		_upgrade.disabled = true
	else:
		_upgrade.text = "UPGRADE"
		_upgrade.disabled = false


func _apply_mode(animate: bool) -> void:
	var tree := mode == Mode.TREE
	_overview_tab.set_pressed_no_signal(not tree)
	_tree_tab.set_pressed_no_signal(tree)
	_stage.visible = not tree
	_overview.visible = not tree
	_header.visible = tree
	_tree_view.visible = tree
	_sheet.visible = tree
	if _fade != null:
		_fade.kill()
		_fade = null
	for c: CanvasItem in [_stage, _overview, _header, _tree_view, _sheet]:
		c.modulate.a = 1.0
	if not animate:
		return
	_fade = create_tween().set_parallel()
	for c: CanvasItem in ([_header, _tree_view, _sheet] if tree else [_stage, _overview]):
		c.modulate.a = 0.0
		_fade.tween_property(c, ^"modulate:a", 1.0, MODE_FADE)


# --- scene-side connections (CharacterDetail.tscn) ---

func _on_overview_tab_pressed() -> void:
	set_mode(Mode.OVERVIEW)


func _on_tree_tab_pressed() -> void:
	set_mode(Mode.TREE)


func _on_ability_tile_pressed(index: int) -> void:
	_show_ability(index)


func _on_showcase_pressed(_def: CharacterDef) -> void:
	_showcase.cheer()


func _on_tree_view_node_selected(node_id: StringName) -> void:
	_show_node(node_id)


func _on_upgrade_pressed() -> void:
	if model == null:
		return
	var n := model.find(_tree_view.selected)
	if n == null:
		return
	_buying = n.id
	_buying_rank = n.rank
	upgrade_requested.emit(tree_id, n.id)


func _on_top_bar_left_pressed() -> void:
	back_requested.emit()


## The screen stays on its own tab: a tab that does not leave (HUNT's
## pre-round, the codex overlay) must not leave another one lit.
func _on_nav_bar_tab_selected(tab_id: StringName) -> void:
	tab_selected.emit(tab_id)
	_nav.active_tab = own_tab()
