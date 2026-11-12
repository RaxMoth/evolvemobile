class_name SkillTreeView
extends Control

## A UxTreeModel as the reference's tree (gamedesign 1.8):
##   - a BranchPlaque over each named branch, tinted in the branch's colour
##     (UiPalette.branch_color, darkened 35 %);
##   - the tier gutter down the left edge: a wood GutterPlaque per tier with
##     its gate ("Lv / 5" on character trees, "pts / 10" on the base trees),
##     GutterPlaqueLocked with a padlock while the tier is closed;
##   - one row per tier with the nodes as SkillNodeButtons (84 px tiles,
##     capstones 92 px in their stone arch; two nodes sharing a cell sit
##     pair_offset left and right of its centre), and a padlocked "???" slot
##     where the data has a node the game does not have yet;
##   - bezier vines from each prerequisite to the node it opens, drawn under
##     the tiles: a 4.5 px core over a 9 px ink casing, moss_light with a leaf
##     once both ends are owned, moss once the parent is, locked_line before.
## Without named branches each row is centred on its own. The rows share the
## height (min_row_h..max_row_h), a tier of capstones and everything below it
## sits arch_room lower so the arches stay clear of the names above them, the
## last tier keeps room under it for a selected node's two-line name
## (SkillNodeButton.selected_name_overhang), and the graph is centred
## vertically; it lays itself out again on resize.
##
## Tapping a node selects it (white ring, small lift) and reports
## node_selected; the character detail shows it in its bottom sheet. build()
## takes a fresh model after every purchase and keeps the selection; pop(id)
## is the purchase juice (the node pops, its vines fade to their new colour).

signal node_selected(node_id: StringName)

const NODE_SCENE := preload("res://Scenes/UI/Components/SkillNodeButton.tscn")
const LOCK_TEXTURE := preload("res://Assets/UI/Kit/padlock.svg")
const VINE_CASING := 9.0
const VINE_CORE := 4.5
const VINE_STEPS := 16
const LEAF_RADIUS := 3.2
const PLAQUE_DARKEN := 0.35
## The vine recolour after a purchase.
const RECOLOUR_TIME := 0.45

## Height of the branch plaque row (only when a branch is named).
@export var header_h: float = 50.0
@export var plaque_size: Vector2 = Vector2(192, 40)
## Width of the tier gutter on the left, and its plaques.
@export var gutter_w: float = 58.0
@export var gutter_plaque_size: Vector2 = Vector2(52, 84)
@export var min_row_h: float = 118.0
@export var max_row_h: float = 150.0
## Two nodes sharing a cell sit this far left and right of its centre.
@export var pair_offset: float = 50.0
## Extra room above the first tier that holds a capstone: its arch rises above
## the tile, into the names of the row above.
@export var arch_room: float = 12.0

var model: UxTreeModel = null
var selected: StringName = &""

var _buttons: Dictionary[StringName, SkillNodeButton] = {}
## The "coming soon" slots (UxTreeModel.hidden_nodes).
var _slots: Array[SkillNodeButton] = []
## Every button with the node it shows ([SkillNodeButton, TreeNodeData]),
## slots first.
var _placed: Array[Array] = []
## Tile centres in this view's coordinates, shown nodes and slots alike.
var _centers: Dictionary[StringName, Vector2] = {}
## The rows' top edge and height (_layout).
var _rows_top: float = 0.0
var _row_h: float = 0.0
## The first tier holding a capstone (0 = none): from it on the rows sit
## arch_room lower.
var _arch_tier: int = 0
## Branch plaques (null for an unnamed branch) and gutter plaques (tier 1 first).
var _plaques: Array[Control] = []
var _gutter: Array[Control] = []
## The vines as [parent id, child id], their colour in this model and in the
## model before it (the recolour after a purchase starts from that).
var _vines: Array[Array] = []
var _vine_colors: Dictionary[String, Color] = {}
var _vine_colors_before: Dictionary[String, Color] = {}
## Vines fading from their old colour after pop(), and how far along (0..1).
var _recolouring: Dictionary[String, Color] = {}
var _recolour_t: float = 1.0
var _recolour: Tween = null


## Shows `m`, replacing the previous graph. The selected node stays selected
## when the new model still has it.
func build(m: UxTreeModel) -> void:
	model = m
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_buttons.clear()
	_slots.clear()
	_placed.clear()
	_centers.clear()
	_plaques.clear()
	_gutter.clear()
	_vines.clear()
	_vine_colors_before.assign(_vine_colors)
	_vine_colors.clear()
	_stop_recolour()
	if m == null:
		selected = &""
		queue_redraw()
		return
	for b in m.columns():
		_plaques.append(_make_plaque(m.branches[b], UiPalette.branch_color(b, m.monster)) if not m.branches[b].is_empty() else null)
	for t in range(1, m.tiers + 1):
		_gutter.append(_make_gutter_plaque(m.gate_caption(), m.gate_value(t), m.tier_unlocked(t)))
	for n in m.hidden_nodes:
		if n.tier < 1 or n.tier > m.tiers:
			continue
		var slot := NODE_SCENE.instantiate() as SkillNodeButton
		slot.name = "Slot_%s" % n.id
		add_child(slot)
		slot.setup_hidden(n)
		_slots.append(slot)
		_placed.append([slot, n])
	for n in m.nodes:
		var b := NODE_SCENE.instantiate() as SkillNodeButton
		b.name = "Node_%s" % n.id
		add_child(b)
		b.setup(n, m.state_of(n), m.can_buy(n), UiPalette.branch_color(n.branch, m.monster), m.is_equipped(n))
		# Runtime-instanced: wired here.
		b.node_pressed.connect(select)
		_buttons[n.id] = b
		_placed.append([b, n])
		for r in n.requires:
			var parent := m.find(r)
			if parent == null:
				continue
			_vines.append([r, n.id])
			_vine_colors[_vine_key(r, n.id)] = _vine_color(parent.rank > 0, n.rank > 0)
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


## The "coming soon" slots of the hidden nodes.
func slots() -> Array[SkillNodeButton]:
	return _slots.duplicate()


## The tier gutter's plaques, tier 1 first.
func gutter_plaques() -> Array[Control]:
	return _gutter.duplicate()


## The branch plaques by column (null for an unnamed branch).
func branch_plaques() -> Array[Control]:
	return _plaques.duplicate()


## Colour a vine from `parent_id` to `child_id` is drawn in (once a purchase's
## recolour has run); Color.TRANSPARENT when there is no such vine.
func vine_color(parent_id: StringName, child_id: StringName) -> Color:
	return _vine_colors.get(_vine_key(parent_id, child_id), Color.TRANSPARENT)


## Whether a purchase's vine recolour is running.
func is_recolouring() -> bool:
	return not _recolouring.is_empty()


## Purchase juice after a rank of `id` was bought (build() has the new model):
## the node pops, and its vines whose colour changed fade from the old colour
## to the new one.
func pop(id: StringName) -> void:
	if _buttons.has(id):
		_buttons[id].pop()
	_stop_recolour()
	for v in _vines:
		if v[0] != id and v[1] != id:
			continue
		var key := _vine_key(v[0], v[1])
		var before: Color = _vine_colors_before.get(key, _vine_colors[key])
		if before != _vine_colors[key]:
			_recolouring[key] = before
	if _recolouring.is_empty():
		return
	_recolour_t = 0.0
	_recolour = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_recolour.tween_method(_set_recolour, 0.0, 1.0, RECOLOUR_TIME)
	_recolour.tween_callback(_stop_recolour)


## Centre of a node's tile in this view's coordinates.
func node_center(id: StringName) -> Vector2:
	return _centers.get(id, Vector2.ZERO)


func _vine_key(parent_id: StringName, child_id: StringName) -> String:
	return "%s>%s" % [parent_id, child_id]


func _vine_color(parent_owned: bool, child_owned: bool) -> Color:
	var palette := UiPalette.get_default()
	if parent_owned and child_owned:
		return palette.moss_light
	return palette.moss if parent_owned else palette.locked_line


func _set_recolour(t: float) -> void:
	_recolour_t = t
	queue_redraw()


func _stop_recolour() -> void:
	if _recolour != null:
		_recolour.kill()
		_recolour = null
	_recolouring.clear()
	_recolour_t = 1.0
	queue_redraw()


func _make_plaque(text: String, color: Color) -> Control:
	var plaque := PanelContainer.new()
	plaque.theme_type_variation = &"BranchPlaque"
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = text.to_upper()
	label.theme_type_variation = &"Counter"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	plaque.add_child(label)
	add_child(plaque)
	# The plaque's own copy of the theme's BranchPlaque, in the branch colour.
	var box := plaque.get_theme_stylebox(&"panel").duplicate() as StyleBoxFlat
	if box != null:
		box.bg_color = color.darkened(PLAQUE_DARKEN)
		plaque.add_theme_stylebox_override(&"panel", box)
	return plaque


func _make_gutter_plaque(caption: String, value: int, open: bool) -> Control:
	var plaque := PanelContainer.new()
	plaque.theme_type_variation = &"GutterPlaque" if open else &"GutterPlaqueLocked"
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := Label.new()
	top.text = caption
	top.theme_type_variation = &"GutterCaption" if open else &"GutterCaptionLocked"
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(top)
	var number := Label.new()
	number.text = str(value)
	number.theme_type_variation = &"GutterNumber" if open else &"GutterNumberLocked"
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(number)
	if not open:
		var lock := TextureRect.new()
		lock.texture = LOCK_TEXTURE
		lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock.custom_minimum_size = Vector2(18, 20)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(lock)
	plaque.add_child(column)
	add_child(plaque)
	return plaque


## Places plaques, the gutter, slots and nodes for the current size.
func _layout() -> void:
	if model == null or model.tiers <= 0:
		queue_redraw()
		return
	var cols := maxi(model.columns(), 1)
	var col_w := (size.x - gutter_w) / cols
	var named := false
	for p in _plaques:
		named = named or p != null
	var head := header_h if named else 0.0
	_arch_tier = 0
	for entry in _placed:
		var n := entry[1] as UxTreeModel.TreeNodeData
		if n.capstone and (_arch_tier == 0 or n.tier < _arch_tier):
			_arch_tier = n.tier
	var arch := arch_room if _arch_tier > 0 else 0.0
	# Under the last tier: room for a selected node's two-line name, as far as
	# it hangs below the node's bottom (a capstone's, the larger tile).
	var tail := SkillNodeButton.selected_name_overhang(SkillNodeButton.CAP_TILE)
	_row_h = clampf((size.y - head - arch - tail) / model.tiers, min_row_h, max_row_h)
	var top := maxf((size.y - head - arch - tail - _row_h * model.tiers) * 0.5, 0.0)
	_rows_top = top + head
	for b in _plaques.size():
		var plaque := _plaques[b]
		if plaque == null:
			continue
		plaque.size = Vector2(minf(plaque_size.x, col_w - 12.0), plaque_size.y)
		plaque.position = Vector2(gutter_w + (b + 0.5) * col_w - plaque.size.x * 0.5, top + (head - plaque_size.y) * 0.5)
	for i in _gutter.size():
		_gutter[i].size = gutter_plaque_size
		_gutter[i].position = Vector2(0.0, _tile_y(i + 1) - gutter_plaque_size.y * 0.5)
	# Cells (branch, tier) holding two nodes place them side by side; a slot
	# takes its place in its cell like a node.
	var cells: Dictionary[Vector2i, Array] = {}
	# Columns each tier uses (x = first, y = last): unnamed branches centre
	# every row on its own.
	var spans: Dictionary[int, Vector2i] = {}
	for entry in _placed:
		var n := entry[1] as UxTreeModel.TreeNodeData
		var key := Vector2i(n.branch, n.tier)
		if not cells.has(key):
			cells[key] = []
		cells[key].append(entry[0])
		var span: Vector2i = spans.get(n.tier, Vector2i(n.branch, n.branch))
		spans[n.tier] = Vector2i(mini(span.x, n.branch), maxi(span.y, n.branch))
	for key: Vector2i in cells:
		var cell: Array = cells[key]
		var shift := 0.0
		if not named:
			shift = (size.x - gutter_w) * 0.5 - (spans[key.y].x + spans[key.y].y + 1) * 0.5 * col_w
		# A node alone in its cell may use most of the column for its name.
		var name_w := SkillNodeButton.NAME_W if cell.size() > 1 else minf(SkillNodeButton.WIDE_NAME_W, col_w - 12.0)
		for i in cell.size():
			var b := cell[i] as SkillNodeButton
			b.set_name_width(name_w)
			var cx := gutter_w + (key.x + 0.5) * col_w + shift
			if cell.size() > 1:
				cx += pair_offset * (2.0 * i / (cell.size() - 1) - 1.0)
			var center := Vector2(cx, _tile_y(key.y))
			_centers[b.node_id] = center
			var half := b.tile_size() * 0.5
			b.position = center - Vector2(half, half)
	queue_redraw()


## Y of the tile centres of `tier`: a little above the row's middle, as the
## names hang below the tiles; arch_room lower from the capstones' tier on.
func _tile_y(tier: int) -> float:
	var arch := arch_room if _arch_tier > 0 and tier >= _arch_tier else 0.0
	return _rows_top + (tier - 0.5) * _row_h - SkillNodeButton.NAME_H * 0.5 + 2.0 + arch


func _draw() -> void:
	if model == null:
		return
	var palette := UiPalette.get_default()
	for v in _vines:
		var parent := _buttons.get(v[0], null) as SkillNodeButton
		var child := _buttons.get(v[1], null) as SkillNodeButton
		if parent == null or child == null:
			continue
		var a: Vector2 = _centers[v[0]] + Vector2(0.0, parent.tile_size() * 0.5)
		var b: Vector2 = _centers[v[1]] - Vector2(0.0, child.tile_size() * 0.5)
		if child.capstone:
			b.y -= SkillNodeButton.ARCH_APEX
		var key := _vine_key(v[0], v[1])
		var color: Color = _vine_colors[key]
		if _recolouring.has(key):
			color = _recolouring[key].lerp(color, _recolour_t)
		var mid := (a.y + b.y) * 0.5
		var pts := PackedVector2Array()
		for i in VINE_STEPS + 1:
			pts.append(a.bezier_interpolate(Vector2(a.x, mid), Vector2(b.x, mid), b, float(i) / VINE_STEPS))
		draw_polyline(pts, palette.ink, VINE_CASING, true)
		draw_polyline(pts, color, VINE_CORE, true)
		if color == palette.moss_light:
			var leaf := a.bezier_interpolate(Vector2(a.x, mid), Vector2(b.x, mid), b, 0.5) + Vector2(6.0, -2.0)
			draw_circle(leaf, LEAF_RADIUS + 1.8, palette.ink)
			draw_circle(leaf, LEAF_RADIUS, palette.leaf)


func _on_resized() -> void:
	_layout()
