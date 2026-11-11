class_name CharacterDetail
extends Control

## One character, opened from its roster card or its rig in the lobby, in two
## modes (the OVERVIEW / SKILL TREE tabs):
##   - OVERVIEW: the character big on its stage (its live rig with the stage
##     idle; a tap cheers), the role pill, "Lv.N" and the XP bar toward the next
##     level, six StatTiles (stat_rows: the base number from its HeroStats or
##     MonsterStats and, in green, what the owned ranks of its own tree and its
##     side's base tree add: "160 +98"), and its abilities as AbilityTiles (the
##     display icon and name; the toggled one shows its description
##     underneath).
##   - SKILL TREE: the stage folds into a compact header (head portrait, name,
##     ranks owned / open, level, XP), the character's tree as a SkillTreeView
##     (UxTreeModel.from_ranked_manager) and the bottom sheet of the selected
##     node: "Rank r/max · branch · Tier t", what it gives now (white) and next
##     (green), both wrapping so every text is read in full, and UPGRADE with
##     the currency and the price (in the danger colour when the wallet is
##     short). A node that cannot be bought disables the button: "Need 340
##     more" and "Maxed" on it, and for a closed gate "LOCKED" with the reason
##     on its own amber line above ("Needs Lv 5", "Spend 3 more points",
##     "Needs Plated or Unbreakable"). A capstone carries the one-capstone
##     rule on a line of its own, worded for its state (not owned, equipped,
##     owned but not equipped); once owned it gets EQUIP (EQUIPPED with a
##     check on the one that applies) and nothing left to buy. The sheet keeps
##     one height (its minimum in the scene) so the tree does not jump between
##     nodes, and grows only for a text that needs more. It opens on the first
##     node that can be bought (UxTreeModel.suggested_node), never on an empty
##     selection. The tab carries an up-arrow badge with the number of ranks
##     ready to buy.
## show_base_tree() opens the screen on an account-wide tree instead (the
## Growth tab: hero_base or monster_base by side) in TREE mode under the
## side's crest. In place of the mode tabs it has the HEROES / MONSTER tabs,
## which switch between the two trees; each carries the red dot while its
## tree has a rank to buy now (base_tree_ready).
## The nav bar's arch glows in the colour of the shown character's or tree's
## side (shown_side): it starts that side's hunt (MenuRoot).
##
## UPGRADE only reports upgrade_requested(tree_id, node_id): MenuRoot buys the
## node's next rank (MetaSkillManager.rank_up) and calls refresh() once
## skills_changed or currency_changed fired; the bought node then pops and its
## vines recolour (SkillTreeView.pop), while the top bar's chip counts down.
## EQUIP reports equip_requested(tree_id, node_id) the same way
## (MetaSkillManager.equip_capstone). Every connection inside the screen is in
## CharacterDetail.tscn, and MenuRoot connects its signals.

signal back_requested
signal tab_selected(tab_id: StringName)
signal upgrade_requested(tree_id: StringName, node_id: StringName)
signal equip_requested(tree_id: StringName, node_id: StringName)

enum Mode { OVERVIEW, TREE }

## Captions of the ability slots, in CharacterDef.ability_slots() order.
const SLOT_KINDS: PackedStringArray = ["PASSIVE", "BASIC", "ACTIVE", "ULTIMATE"]
const STAT_ICON_PATH := "res://Assets/UI/Icons/Stats/%s.svg"
## The check on EQUIPPED (the tree shows the same one on the equipped arch).
const EQUIPPED_ICON := preload("res://Assets/UI/Icons/UI/ui_check.svg")
## The one-capstone rule on a capstone's sheet, by its state.
const CAPSTONE_RULE := "Only one capstone is active per character. Switching is free."
const CAPSTONE_EQUIPPED := "Equipped: this capstone is the active one. Switching is free."
const CAPSTONE_NOT_EQUIPPED := "Not equipped: another capstone is active. Switching is free."
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
var _side_group := ButtonGroup.new()
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
@onready var _head_ranks: Label = %HeadRanks
@onready var _head_level: Label = %HeadLevel
@onready var _head_xp: ProgressBar = %HeadXp
@onready var _head_blurb: Label = %HeadBlurb
@onready var _tabs: Control = %Tabs
@onready var _overview_tab: Button = %OverviewTab
@onready var _tree_tab: Button = %TreeTab
@onready var _tree_badge: Control = %TreeBadge
@onready var _tree_badge_count: Label = %TreeBadgeCount
@onready var _side_tabs: Control = %SideTabs
@onready var _heroes_side: Button = %HeroesSide
@onready var _monster_side: Button = %MonsterSide
@onready var _heroes_side_dot: CanvasItem = %HeroesSideDot
@onready var _monster_side_dot: CanvasItem = %MonsterSideDot
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
@onready var _capstone_note: Label = %CapstoneNote
@onready var _reason: Label = %Reason
@onready var _cost: Control = %Cost
@onready var _cost_icon: TextureRect = %CostIcon
@onready var _cost_value: Label = %CostValue
@onready var _upgrade: Button = %Upgrade
@onready var _equip: Button = %Equip


func _ready() -> void:
	_overview_tab.button_group = _tab_group
	_tree_tab.button_group = _tab_group
	_heroes_side.button_group = _side_group
	_monster_side.button_group = _side_group
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
	_nav.monster_side = monster
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
	_side_tabs.visible = false
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
	_nav.monster_side = monster
	_showcase.character = null
	_head_icon.texture = crest_monster if monster else crest_heroes
	_head_level.visible = false
	_head_xp.visible = false
	_head_blurb.visible = true
	_tabs.visible = false
	_side_tabs.visible = true
	# set_pressed_no_signal does not release the group's other button.
	_heroes_side.set_pressed_no_signal(not monster)
	_monster_side.set_pressed_no_signal(monster)
	refresh()
	set_mode(Mode.TREE, false)


## The side of what is shown (MatchRewards.Side): the character's, or the
## account-wide tree's.
func shown_side() -> int:
	if character != null:
		return MatchRewards.Side.MONSTER if character.is_monster() else MatchRewards.Side.HEROES
	return MatchRewards.Side.MONSTER if base_side == MatchRewards.Side.MONSTER else MatchRewards.Side.HEROES


## True while `side`'s account-wide tree has a rank the player can buy now
## (the dots on Growth's side tabs and on the nav bars' Growth tab).
static func base_tree_ready(side: int) -> bool:
	var tree: StringName = MetaSkillManager.TREE_MONSTER_BASE if side == MatchRewards.Side.MONSTER else MetaSkillManager.TREE_HERO_BASE
	var ready_now: bool = MetaSkillManager.card_progress(tree)["upgrade_ready"]
	return ready_now


## The nav bar tab this screen belongs to.
func own_tab() -> StringName:
	if character == null:
		return &"growth"
	return &"monsters" if character.is_monster() else &"heroes"


## Re-reads the save: level and XP, the overview's numbers, the tab badge, the
## tree and the sheet. With nothing selected (a tree opened fresh) the sheet
## shows the model's suggested node. The node an UPGRADE was asked for pops
## once it gained a rank.
func refresh() -> void:
	if character != null:
		_fill_stats()
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
	model = UxTreeModel.from_ranked_manager(tree_id, _ability_icons()) if not tree_id.is_empty() else null
	if character == null:
		_heroes_side_dot.visible = base_tree_ready(MatchRewards.Side.HEROES)
		_monster_side_dot.visible = base_tree_ready(MatchRewards.Side.MONSTER)
	if character == null and model != null:
		_head_name.text = model.title
		_head_blurb.text = model.description
	_head_ranks.visible = model != null
	if model != null:
		_head_ranks.text = tr("Ranks %d/%d") % [model.ranks_owned(), model.ranks_open()]
	_tree_view.build(model)
	if model != null and _tree_view.selected.is_empty():
		# select() reports node_selected: the sheet follows (scene connection).
		_tree_view.select(model.suggested_node())
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


## The six numbers of the overview for `def`: [icon key, value, caption,
## bonus]. `value` is the base number from its HeroStats (the basic attack's
## cooldown gives the attack speed) or its MonsterStats (stage I health, the
## basic ability's hit and the move speed, the evolution thresholds and the
## Stage III health). `bonus` is what the player's own build adds to it in a
## match ("+98", "-15" on a threshold, "" for nothing): the owned ranks of the
## character's tree and its side's base tree with the equipped capstone,
## stacked by MetaSkillManager the way a spawn stacks them (owned_hero_stats
## on a HeroStatsComponent, owned_monster_modifiers through MonsterBase's
## build_* numbers, owned_ability for the basic attack).
static func stat_rows(def: CharacterDef) -> Array[Array]:
	var rows: Array[Array] = []
	if def == null:
		return rows
	var slots := def.ability_slots()
	var basic: AbilityBase = slots[1] if slots.size() > 1 else null
	if def.stats is HeroStats:
		var s := def.stats as HeroStats
		var owned := MetaSkillManager.owned_hero_stats(s)
		var rate := "-"
		var rate_bonus := ""
		if basic != null and basic.cooldown > 0.0:
			var owned_basic := MetaSkillManager.owned_ability(def.skill_tree_id(), basic)
			var base_rate := 1.0 / basic.cooldown
			rate = "%.2f/s" % base_rate
			if owned_basic.cooldown > 0.0:
				rate_bonus = _bonus(base_rate, owned.get_attack_speed_multiplier() / owned_basic.cooldown, 0.01)
		rows.append(["stat_hp", _number(s.base_max_health), "Health", _bonus(s.base_max_health, owned.get_max_health())])
		rows.append(["stat_damage", _number(s.base_attack_damage), "Damage", _bonus(s.base_attack_damage, owned.get_attack_damage())])
		rows.append(["stat_attack_speed", rate, "Attack speed", rate_bonus])
		rows.append(["stat_range", _number(s.base_attack_range), "Range", _bonus(s.base_attack_range, owned.get_attack_range())])
		rows.append(["stat_speed", _number(s.base_move_speed), "Move speed", _bonus(s.base_move_speed, owned.get_move_speed())])
		rows.append(["stat_vision", _number(s.vision_radius), "Vision", ""])
		owned.free()
	elif def.stats is MonsterStats:
		var m := def.stats as MonsterStats
		var mods := MetaSkillManager.owned_monster_modifiers(m.monster_id)
		var xp_format := TranslationServer.translate("%d XP")
		var hit := "-"
		var hit_bonus := ""
		if basic != null:
			# Copies: the stage's numbers are written into the ability.
			var stock := basic.duplicate() as AbilityBase
			stock.apply_stage_stats(1)
			var owned_basic := MetaSkillManager.owned_ability(def.skill_tree_id(), basic)
			owned_basic.apply_stage_stats(1)
			var stock_hit := MonsterBase.build_ability_damage(m, stock, 1, {})
			hit = _number(stock_hit)
			hit_bonus = _bonus(stock_hit, MonsterBase.build_ability_damage(m, owned_basic, 1, mods))
		rows.append(["stat_hp", _number(m.stage_1_health), "Health", _bonus(m.stage_1_health, MonsterBase.build_max_health(m, 1, mods))])
		rows.append(["stat_damage", hit, "Damage", hit_bonus])
		rows.append(["stat_speed", _number(m.stage_1_speed), "Move speed", _bonus(m.stage_1_speed, MonsterBase.build_move_speed(m, 1, mods))])
		rows.append(["stat_xp", xp_format % m.stage_2_xp, "Stage II", _bonus(m.stage_2_xp, MonsterBase.build_evolution_xp(m, 2, mods))])
		rows.append(["stat_level", xp_format % m.stage_3_xp, "Stage III", _bonus(m.stage_3_xp, MonsterBase.build_evolution_xp(m, 3, mods))])
		rows.append(["stat_threat", _number(m.stage_3_health), "Health at Stage III", _bonus(m.stage_3_health, MonsterBase.build_max_health(m, 3, mods))])
	return rows


## Whole numbers with thousands commas ("2,200"), others with one decimal.
static func _number(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return CurrencyChip.format_amount(roundi(v))
	return "%.1f" % v


## What the owned build adds to `base`, as the tile shows it: "+98", "-15",
## "+0.3"; "" when it adds nothing. Rounded to `step`: whole numbers for a
## big stat, a tenth for a small one (5 damage), 0.01 for a rate.
static func _bonus(base: float, real: float, step: float = 0.0) -> String:
	if step <= 0.0:
		step = 1.0 if absf(base) >= 20.0 else 0.1
	var delta := snappedf(real - base, step)
	if is_zero_approx(delta):
		return ""
	var amount := "%.2f" % absf(delta) if step < 0.1 else _number(absf(delta))
	return ("+" if delta > 0.0 else "-") + amount


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
			tile.show_stat(load(STAT_ICON_PATH % row[0]) as Texture2D, row[1], row[2], row[3])


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
	_ability_name.text = "%s  ·  %s" % [tr(ability.ability_name), tr(SLOT_KINDS[index]).capitalize()]
	_ability_desc.text = ability.description


## ability_name -> icon of the character's abilities (fallback node icons).
func _ability_icons() -> Dictionary:
	var icons := {}
	if character != null:
		for ability in character.abilities():
			icons[ability.ability_name] = ability.get_display_icon()
	return icons


## The bottom sheet for node `id` (empty: an empty tree). A line that has
## nothing to say hides, so the sheet's rows never leave a gap.
func _show_node(id: StringName) -> void:
	var n: UxTreeModel.TreeNodeData = null
	if model != null and not id.is_empty():
		n = model.find(id)
	if n == null:
		_node_icon.texture = null
		_node_name.text = "Tap a node"
		_node_meta.text = ""
		_effect_now.visible = false
		_effect_next.visible = false
		_capstone_note.visible = false
		_reason.visible = false
		_cost.visible = false
		_upgrade.visible = true
		_upgrade.text = "UPGRADE"
		_upgrade.disabled = true
		_equip.visible = false
		return
	_node_icon.texture = n.icon
	_node_name.text = n.name
	var meta := tr("Rank %d/%d · Tier %d") % [n.rank, n.max_rank(), n.tier]
	if n.branch < model.columns() and not model.branches[n.branch].is_empty():
		meta = tr("Rank %d/%d · %s · Tier %d") % [n.rank, n.max_rank(), model.branches[n.branch], n.tier]
	if n.capstone:
		meta += " · " + tr("Capstone")
	_node_meta.text = meta
	var owned := n.rank > 0
	var maxed := n.rank >= n.max_rank()
	var equipped := model.is_equipped(n)
	# A node not learned yet says so in its rank line ("Rank 0/3"): only what
	# the next rank gives follows.
	_effect_now.visible = owned
	_effect_now.text = tr("Now: %s") % n.effect_at(n.rank) if owned else ""
	_effect_next.visible = not maxed
	_effect_next.text = "" if maxed else tr("Next: %s") % n.effect_at(n.rank + 1)
	# Only one capstone applies: said on every capstone, in its state's words
	# and colour (muted rule, green on the equipped one, amber on an owned one
	# that waits for EQUIP).
	_capstone_note.visible = n.capstone
	if equipped:
		_capstone_note.text = CAPSTONE_EQUIPPED
		_capstone_note.theme_type_variation = &"NextLabel"
	elif owned:
		_capstone_note.text = CAPSTONE_NOT_EQUIPPED
		_capstone_note.theme_type_variation = &"AmberLabel"
	else:
		_capstone_note.text = CAPSTONE_RULE
		_capstone_note.theme_type_variation = &"HintLabel"
	# A bought capstone has nothing left to buy: it only equips.
	_upgrade.visible = not (n.capstone and maxed)
	_equip.visible = n.capstone and owned
	_equip.text = "EQUIPPED" if equipped else "EQUIP"
	# The check stands right before the word (an icon centres apart from it).
	_equip.icon = EQUIPPED_ICON if equipped else null
	_equip.alignment = HORIZONTAL_ALIGNMENT_LEFT if equipped else HORIZONTAL_ALIGNMENT_CENTER
	_equip.disabled = not model.can_equip(n)
	var reason := model.block_reason(n)
	# A closed gate (level, points, prerequisite) is explained on its own
	# wrapped line; the button only says LOCKED.
	var gated := not reason.is_empty() and not maxed
	_reason.visible = gated
	_reason.text = reason if gated else ""
	# The price shows while it is what stands between the player and the rank.
	_cost.visible = reason.is_empty()
	_cost_icon.texture = CurrencyChip.icon_for(model.currency)
	_cost_value.text = CurrencyChip.format_amount(n.next_cost())
	if model.affordable(n):
		_cost_value.remove_theme_color_override(&"font_color")
	else:
		_cost_value.add_theme_color_override(&"font_color", UiPalette.get_default().danger)
	_upgrade.alignment = HORIZONTAL_ALIGNMENT_LEFT if _cost.visible else HORIZONTAL_ALIGNMENT_CENTER
	if gated:
		_upgrade.text = "LOCKED"
		_upgrade.disabled = true
	elif maxed:
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


## Growth's HEROES / MONSTER tabs: the other side's account-wide tree.
func _on_side_tab_pressed(side: int) -> void:
	if character == null and side != base_side:
		show_base_tree(side)


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


func _on_equip_pressed() -> void:
	if model == null:
		return
	var n := model.find(_tree_view.selected)
	if n != null and model.can_equip(n):
		equip_requested.emit(tree_id, n.id)


func _on_top_bar_left_pressed() -> void:
	back_requested.emit()


## The screen stays on its own tab: a tab that does not leave (HUNT's
## pre-round, the codex overlay) must not leave another one lit.
func _on_nav_bar_tab_selected(tab_id: StringName) -> void:
	tab_selected.emit(tab_id)
	_nav.active_tab = own_tab()
