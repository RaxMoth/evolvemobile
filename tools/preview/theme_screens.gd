extends Control
## Proof sheet for the theme variations the Phase 3-5 screens use on top of
## the art set (tools/art/make_theme.py "screen variations"): skill-tree nodes
## (the real SkillNodeButton: NodeTile in the branch colours, pips, the red "+"
## badge, the selection ring) and capstones in their arch in every state,
## branch plaques, the tier gutter's plaques, detail tabs, flat button, the
## bottom sheet with its labels, chip and evolution bar, and the side frames.
## Not a production screen and not shipped (tools/). Render muted on a copy of
## the project:
##   godot --path <copy> --audio-driver Dummy --fixed-fps 30
##         --write-movie <dir>/f.png --quit-after 8 res://tools/preview/ThemeScreens.tscn

const UI := "res://Assets/UI/"
const NODE_SCENE := preload("res://Scenes/UI/Components/SkillNodeButton.tscn")
const LOCKED := UxTreeModel.NodeState.LOCKED
const AVAILABLE := UxTreeModel.NodeState.AVAILABLE
const OWNED := UxTreeModel.NodeState.OWNED
const MAXED := UxTreeModel.NodeState.MAXED

@onready var _root: VBoxContainer = $Margin/Root


func _ready() -> void:
	_root.add_child(_label("Skill Tree", &"HeaderLarge"))
	_root.add_child(_tabs())
	_plaques()
	_root.add_child(_label("Nodes: locked · open, buyable · owned, selected · maxed", &"HintLabel"))
	var nodes := _row(40)
	_root.add_child(nodes)
	_node(nodes, "Iron Skin", "stat_hp", 0, 3, LOCKED, 0)
	_node(nodes, "Sharp Edge", "stat_damage", 0, 3, AVAILABLE, 0, true)
	_node(nodes, "Light Step", "stat_speed", 2, 3, OWNED, 1, false, false, true)
	_node(nodes, "Plated", "stat_armor", 3, 3, MAXED, 2)
	_root.add_child(_gutter())
	_root.add_child(_label("Capstones: locked · open · owned · equipped", &"HintLabel"))
	var caps := _row(30)
	_root.add_child(caps)
	_node(caps, "Last Stand", "stat_hp", 0, 1, LOCKED, 0)
	_node(caps, "Guardian Angel", "stat_heal", 0, 1, AVAILABLE, 1, true)
	_node(caps, "Rallying Taunt", "stat_threat", 1, 1, MAXED, 2)
	_node(caps, "Titan Form", "stat_hp", 1, 1, MAXED, 1, false, true)
	_root.add_child(_frames())
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(spacer)
	_root.add_child(_sheet())


func _svg(path: String) -> Texture2D:
	return load(UI + path + ".svg") as Texture2D


func _tex(path: String, px: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = _svg(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = px
	return t


func _label(text: String, variation: StringName) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _row(separation: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", separation)
	return h


func _tabs() -> Control:
	var h := _row(4)
	var group := ButtonGroup.new()
	for tab: String in ["Overview", "Stats", "Skill tree"]:
		var b := Button.new()
		b.text = tab
		b.theme_type_variation = &"TabButton"
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = tab == "Skill tree"
		h.add_child(b)
	var flat := Button.new()
	flat.text = "Change"
	flat.icon = _svg("Icons/UI/ui_swap")
	flat.theme_type_variation = &"FlatButton"
	h.add_child(flat)
	return h


## The branch plaques, each tinted like SkillTreeView's (the row joins the
## sheet first: a plaque reads its theme's stylebox once it is in the tree).
func _plaques() -> void:
	var h := _row(14)
	_root.add_child(h)
	var names := ["Bulwark", "Oathkeeper", "Vanguard"]
	for i in names.size():
		var p := PanelContainer.new()
		p.theme_type_variation = &"BranchPlaque"
		p.custom_minimum_size = Vector2(192, 40)
		p.add_child(_label(String(names[i]).to_upper(), &"Counter"))
		h.add_child(p)
		var box := p.get_theme_stylebox(&"panel").duplicate() as StyleBoxFlat
		if box != null:
			box.bg_color = UiPalette.branch_color(i, false).darkened(SkillTreeView.PLAQUE_DARKEN)
			p.add_theme_stylebox_override(&"panel", box)


## A SkillNodeButton (a capstone when max_rank is 1) in `row`: `rank` of
## `max_rank` owned in `node_state`, in branch `branch`'s hero colour.
func _node(row: Control, title: String, glyph: String, rank: int, max_rank: int, node_state: UxTreeModel.NodeState,
		branch: int, buyable: bool = false, equipped: bool = false, selected: bool = false) -> void:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(150, 102 + SkillNodeButton.ARCH_RISE)
	row.add_child(holder)
	var b := NODE_SCENE.instantiate() as SkillNodeButton
	holder.add_child(b)
	var n := UxTreeModel.TreeNodeData.new()
	n.id = StringName(title)
	n.name = title
	n.icon = _svg("Icons/Stats/" + glyph)
	n.capstone = max_rank == 1
	n.branch = branch
	n.rank = rank
	for i in max_rank:
		n.rank_costs.append(100 * (i + 1))
	b.setup(n, node_state, buyable, UiPalette.branch_color(branch, false), equipped)
	b.position = Vector2((150 - b.tile_size()) * 0.5, SkillNodeButton.ARCH_RISE)
	if selected:
		b.set_selected(true)


## The tier gutter's plaques: an open tier ("Lv 3") and a closed one.
func _gutter() -> Control:
	var h := _row(16)
	for spec: Array in [["Lv", 3, true], ["Lv", 8, false], ["pts", 10, true], ["pts", 18, false]]:
		var open: bool = spec[2]
		var plaque := PanelContainer.new()
		plaque.theme_type_variation = &"GutterPlaque" if open else &"GutterPlaqueLocked"
		plaque.custom_minimum_size = Vector2(52, 84)
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 0)
		v.add_child(_label(str(spec[0]), &"GutterCaption" if open else &"GutterCaptionLocked"))
		v.add_child(_label(str(spec[1]), &"GutterNumber" if open else &"GutterNumberLocked"))
		if not open:
			v.add_child(_tex("Kit/padlock", Vector2(18, 20)))
		plaque.add_child(v)
		h.add_child(plaque)
	return h


func _frames() -> Control:
	var h := _row(16)
	for side: Array in [[&"FrameHero", "Heroes", &"HeroAccentLabel"], [&"FrameMonster", "Monster", &"MonsterAccentLabel"]]:
		var f := PanelContainer.new()
		f.theme_type_variation = side[0]
		f.custom_minimum_size = Vector2(300, 110)
		var l := _label(str(side[1]), side[2])
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		f.add_child(l)
		h.add_child(f)
	return h


## The bottom sheet of the skill tree: node name, rank line, now / next,
## cost chip, the evolution bar and the upgrade button.
func _sheet() -> Control:
	var sheet := PanelContainer.new()
	sheet.theme_type_variation = &"SheetPanel"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	var slot := PanelContainer.new()
	slot.theme_type_variation = &"PanelInset"
	slot.custom_minimum_size = Vector2(96, 96)
	slot.add_child(_tex("Icons/Stats/stat_speed", Vector2(56, 56)))
	top.add_child(slot)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := _label("Swift Runner", &"HeaderSmall")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.add_child(title)
	for line: Array in [["Rank 2/3 · Vanguard · Tier 2", &"HintLabel"], ["Now: +10% move speed", &"NowLabel"],
			["Next: +15% move speed", &"NextLabel"]]:
		var l := _label(str(line[0]), line[1])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		text.add_child(l)
	top.add_child(text)
	var big := _label("340", &"BigNumberLabel")
	big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(big)
	v.add_child(top)
	var evo := HBoxContainer.new()
	evo.add_theme_constant_override("separation", 10)
	evo.add_child(_label("Stage II", &"Counter"))
	var bar := ProgressBar.new()
	bar.theme_type_variation = &"EvoBar"
	bar.custom_minimum_size = Vector2(0, 22)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.value = 60.0
	evo.add_child(bar)
	v.add_child(evo)
	var buy := HBoxContainer.new()
	buy.add_theme_constant_override("separation", 12)
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"ChipPanel"
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cost := _row(6)
	cost.add_child(_tex("Icons/Currency/currency_gold", Vector2(32, 32)))
	cost.add_child(_label("340", &"Counter"))
	chip.add_child(cost)
	buy.add_child(chip)
	var upgrade := Button.new()
	upgrade.text = "UPGRADE"
	upgrade.theme_type_variation = &"ButtonPrimary"
	upgrade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade.custom_minimum_size = Vector2(0, 74)
	buy.add_child(upgrade)
	v.add_child(buy)
	sheet.add_child(v)
	return sheet
