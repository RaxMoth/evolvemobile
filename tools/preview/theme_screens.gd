extends Control
## Proof sheet for the theme variations the Phase 3-5 screens use on top of
## the art set (tools/art/make_theme.py "screen variations"): skill-tree nodes
## and capstones in every state with rank pips and the selection ring, branch
## plaques, tier gate chip, detail tabs, flat button, the bottom sheet with its
## labels, chip and evolution bar, and the side frames. Not a production
## screen and not shipped (tools/). Render muted on a copy of the project:
##   godot --path <copy> --audio-driver Dummy --fixed-fps 30
##         --write-movie <dir>/f.png --quit-after 8 res://tools/preview/ThemeScreens.tscn

const UI := "res://Assets/UI/"
const NODE_SIZE := Vector2(84, 84)
const PIP_SIZE := Vector2(14, 14)

@onready var _root: VBoxContainer = $Margin/Root


func _ready() -> void:
	_root.add_child(_label("Skill Tree", &"HeaderLarge"))
	_root.add_child(_tabs())
	_root.add_child(_plaques())
	_root.add_child(_label("Nodes: locked · available · owned · maxed", &"HintLabel"))
	var nodes := _row(22)
	nodes.add_child(_node(&"NodeLocked", "stat_hp", 0, 3, false))
	nodes.add_child(_node(&"NodeAvailable", "stat_damage", 0, 3, false))
	nodes.add_child(_node(&"NodeOwned", "stat_speed", 2, 3, true))
	nodes.add_child(_node(&"NodeMaxed", "stat_armor", 3, 3, false))
	_root.add_child(nodes)
	_root.add_child(_gate())
	_root.add_child(_label("Capstones: locked · available · owned", &"HintLabel"))
	var caps := _row(30)
	caps.add_child(_node(&"CapLocked", "stat_aoe", 0, 1, false))
	caps.add_child(_node(&"CapAvailable", "stat_threat", 0, 1, false))
	caps.add_child(_node(&"CapOwned", "stat_lifesteal", 1, 1, false))
	_root.add_child(caps)
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


func _plaques() -> Control:
	var h := _row(14)
	for branch: String in ["Bulwark", "Oathkeeper", "Vanguard"]:
		var p := PanelContainer.new()
		p.theme_type_variation = &"BranchPlaque"
		p.add_child(_label(branch, &"NavLabel"))
		h.add_child(p)
	return h


## A tree node: the frame variation around a stat glyph, rank pips under it,
## and (selected) the white ring around the frame.
func _node(variation: StringName, glyph: String, rank: int, max_rank: int, selected: bool) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var holder := CenterContainer.new()
	holder.custom_minimum_size = NODE_SIZE + Vector2(14, 14)
	var frame := PanelContainer.new()
	frame.theme_type_variation = variation
	frame.custom_minimum_size = NODE_SIZE
	var icon := _tex("Icons/Stats/" + glyph, Vector2(48, 48))
	if String(variation).ends_with("Locked"):
		icon.self_modulate = UiPalette.LOCKED_MODULATE.lightened(0.35)
		var lock := _tex("Icons/UI/ui_lock", Vector2(30, 30))
		lock.size_flags_horizontal = Control.SIZE_SHRINK_END
		lock.size_flags_vertical = Control.SIZE_SHRINK_END
		frame.add_child(icon)
		frame.add_child(lock)
	else:
		frame.add_child(icon)
	holder.add_child(frame)
	if selected:
		var ring := PanelContainer.new()
		ring.theme_type_variation = &"SelectRing"
		ring.custom_minimum_size = NODE_SIZE + Vector2(12, 12)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(ring)
	v.add_child(holder)
	var pips := _row(4)
	for i in max_rank:
		var pip := PanelContainer.new()
		pip.custom_minimum_size = PIP_SIZE
		if i >= rank:
			pip.theme_type_variation = &"PipOff"
		elif rank == max_rank:
			pip.theme_type_variation = &"PipMax"
		else:
			pip.theme_type_variation = &"PipOn"
		pips.add_child(pip)
	v.add_child(pips)
	return v


func _gate() -> Control:
	var c := CenterContainer.new()
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"GateChip"
	var h := _row(6)
	h.add_child(_tex("Icons/UI/ui_lock", Vector2(22, 22)))
	h.add_child(_label("Lv 5 · 10 pts", &"Caption"))
	chip.add_child(h)
	c.add_child(chip)
	return c


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
	slot.theme_type_variation = &"NodeOwned"
	slot.custom_minimum_size = Vector2(96, 96)
	slot.add_child(_tex("Icons/Stats/stat_speed", Vector2(56, 56)))
	top.add_child(slot)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := _label("Swift Runner", &"HeaderSmall")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.add_child(title)
	for line: Array in [["Rank 2/3 · Vanguard · Tier 2", &"BodyDim"], ["Now: +10% move speed", &"Label"],
			["Next: +15% move speed", &"AmberLabel"], ["Not learned yet by Vlad", &"HintLabel"]]:
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
