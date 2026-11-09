class_name SkillTreeView
extends Control

## A UxTreeModel as a node graph: one column per branch (a BranchPlaque over
## it when the branch is named), one row per tier, between the rows a dashed
## rule with a GateChip ("Tier 2", padlocked while the tier is closed), and
## requirement links under the nodes (an ink casing with an amber core once
## the parent is owned, dull stone before). Two nodes sharing a cell sit side
## by side. Without named branches (today's trees) each row is centred on its
## own. The rows share the height (min_row_h..max_row_h) and the graph is
## centred vertically; it lays itself out again on resize.
##
## Tapping a node selects it (white ring, small lift) and reports
## node_selected; the character detail shows it in its bottom sheet. build()
## takes a fresh model after every purchase and keeps the selection.

signal node_selected(node_id: StringName)

const NODE_SCENE := preload("res://Scenes/UI/Components/SkillNodeButton.tscn")
const LOCK_TEXTURE := preload("res://Assets/UI/Kit/padlock.svg")
## Link widths: the ink casing and the coloured core on top.
const LINK_CASING := 11.0
const LINK_CORE := 5.0
const RULE_DASH := 14.0
const RULE_GAP := 10.0

## Height of the branch plaque row (only drawn when a branch is named).
@export var header_h: float = 52.0
@export var min_row_h: float = 110.0
@export var max_row_h: float = 156.0
## Two nodes sharing a cell sit this far left and right of its centre.
@export var pair_offset: float = 50.0

var model: UxTreeModel = null
var selected: StringName = &""

var _buttons: Dictionary[StringName, SkillNodeButton] = {}
var _centers: Dictionary[StringName, Vector2] = {}
## Branch plaques (null for an unnamed branch) and gate chips (tier 2 first).
var _plaques: Array[Control] = []
var _chips: Array[Control] = []
var _rule_y: PackedFloat32Array = PackedFloat32Array()


## Shows `m`, replacing the previous graph. The selected node stays selected
## when the new model still has it.
func build(m: UxTreeModel) -> void:
	model = m
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_buttons.clear()
	_centers.clear()
	_plaques.clear()
	_chips.clear()
	if m == null:
		selected = &""
		queue_redraw()
		return
	for b in m.columns():
		_plaques.append(_make_plaque(m.branches[b]) if not m.branches[b].is_empty() else null)
	for t in range(2, m.tiers + 1):
		_chips.append(_make_chip(m.tier_gate_text[t - 1], not m.tier_unlocked(t)))
	for n in m.nodes:
		var b := NODE_SCENE.instantiate() as SkillNodeButton
		b.name = "Node_%s" % n.id
		add_child(b)
		b.setup(n, m.state_of(n), m.can_buy(n))
		# Runtime-instanced: wired here.
		b.node_pressed.connect(select)
		_buttons[n.id] = b
	if not _buttons.has(selected):
		selected = &""
	elif not selected.is_empty():
		_buttons[selected].set_selected(true)
	_layout()


## Selects a node (empty: none) and reports it.
func select(id: StringName) -> void:
	if _buttons.has(selected):
		_buttons[selected].set_selected(false)
	selected = id if _buttons.has(id) else &""
	if not selected.is_empty():
		_buttons[selected].set_selected(true)
	node_selected.emit(selected)


func button(id: StringName) -> SkillNodeButton:
	return _buttons.get(id, null)


func buttons() -> Array[SkillNodeButton]:
	var out: Array[SkillNodeButton] = []
	out.assign(_buttons.values())
	return out


## Purchase juice on one node.
func pop(id: StringName) -> void:
	if _buttons.has(id):
		_buttons[id].pop()


## Centre of a node's ring in this view's coordinates.
func node_center(id: StringName) -> Vector2:
	return _centers.get(id, Vector2.ZERO)


func _make_plaque(text: String) -> Control:
	var plaque := PanelContainer.new()
	plaque.theme_type_variation = &"BranchPlaque"
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"BodyDim"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	plaque.add_child(label)
	add_child(plaque)
	return plaque


func _make_chip(text: String, closed: bool) -> Control:
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"GateChip"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if closed:
		var lock := TextureRect.new()
		lock.texture = LOCK_TEXTURE
		lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock.custom_minimum_size = Vector2(16, 18)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lock)
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"HintLabel"
	row.add_child(label)
	chip.add_child(row)
	add_child(chip)
	return chip


## Places plaques, chips and nodes for the current size.
func _layout() -> void:
	_rule_y.clear()
	if model == null or model.tiers <= 0:
		queue_redraw()
		return
	var cols := maxi(model.columns(), 1)
	var col_w := size.x / cols
	var named := false
	for p in _plaques:
		named = named or p != null
	var head := header_h if named else 0.0
	var row_h := clampf((size.y - head) / model.tiers, min_row_h, max_row_h)
	var top := maxf((size.y - head - row_h * model.tiers) * 0.5, 0.0)
	for b in _plaques.size():
		var plaque := _plaques[b]
		if plaque == null:
			continue
		plaque.size = Vector2(col_w - 16.0, header_h - 12.0)
		plaque.position = Vector2(b * col_w + 8.0, top + 4.0)
	var rows_top := top + head
	for i in _chips.size():
		var chip := _chips[i]
		var y := rows_top + (i + 1) * row_h
		_rule_y.append(y)
		chip.reset_size()
		chip.position = Vector2((size.x - chip.size.x) * 0.5, y - chip.size.y * 0.5)
	# Cells (branch, tier) holding two nodes place them side by side.
	var cells: Dictionary[Vector2i, Array] = {}
	# Columns each tier uses (x = first, y = last): unnamed branches centre
	# every row on its own.
	var spans: Dictionary[int, Vector2i] = {}
	for n in model.nodes:
		var key := Vector2i(n.branch, n.tier)
		if not cells.has(key):
			cells[key] = []
		cells[key].append(n)
		var span: Vector2i = spans.get(n.tier, Vector2i(n.branch, n.branch))
		spans[n.tier] = Vector2i(mini(span.x, n.branch), maxi(span.y, n.branch))
	for key: Vector2i in cells:
		var cell: Array = cells[key]
		var shift := 0.0
		if not named:
			shift = size.x * 0.5 - (spans[key.y].x + spans[key.y].y + 1) * 0.5 * col_w
		for i in cell.size():
			var n := cell[i] as UxTreeModel.TreeNodeData
			var cx := (key.x + 0.5) * col_w + shift
			if cell.size() > 1:
				cx += pair_offset * (2.0 * i / (cell.size() - 1) - 1.0)
			# The ring sits a little above the row's middle: its pips hang below.
			var cy := rows_top + (key.y - 0.5) * row_h - 8.0
			_centers[n.id] = Vector2(cx, cy)
			_buttons[n.id].position = Vector2(cx, cy) - Vector2.ONE * SkillNodeButton.RING * 0.5
	queue_redraw()


func _draw() -> void:
	if model == null:
		return
	var palette := UiPalette.get_default()
	for y in _rule_y:
		var x := 12.0
		while x < size.x - 12.0:
			draw_line(Vector2(x, y), Vector2(minf(x + RULE_DASH, size.x - 12.0), y), palette.divider, 2.0)
			x += RULE_DASH + RULE_GAP
	var half := SkillNodeButton.RING * 0.5
	for n in model.nodes:
		for r in n.requires:
			if not _centers.has(r) or not _centers.has(n.id):
				continue
			var a: Vector2 = _centers[r] + Vector2(0.0, half + 14.0)
			var b: Vector2 = _centers[n.id] - Vector2(0.0, half + 4.0)
			var parent := model.find(r)
			var lit := parent != null and parent.rank > 0
			var mid := (a.y + b.y) * 0.5
			var pts := PackedVector2Array([a, Vector2(a.x, mid), Vector2(b.x, mid), b])
			draw_polyline(pts, palette.ink, LINK_CASING, true)
			draw_polyline(pts, palette.amber if lit else palette.stone_dark, LINK_CORE, true)


func _on_resized() -> void:
	_layout()
