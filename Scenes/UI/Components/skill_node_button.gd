class_name SkillNodeButton
extends Button

## One node of a skill tree (SkillTreeView) in the reference's look
## (gamedesign 1.8): an 84 px NodeTile around the node's 60 px icon (a
## capstone's tile is 92 px and stands in a stone arch drawn behind it), the
## rank pips inside the tile's bottom edge, the node's name underneath (a name
## too long for its width wraps onto a second line), the red "+" badge
## (BadgeReady, gently pulsing) while its next rank can be bought and afforded,
## and a check on the tree's equipped capstone.
##
## The tile wears its branch's colour (`accent`, UiPalette.branch_color): a
## dark fill of it, and a rim that is the branch colour once owned, darker
## while the node is open, gold (rank_max) once maxed. A locked node keeps the
## theme's NodeTile (near-black, locked_line rim) with its icon dimmed to
## UiPalette.LOCKED_ICON_MODULATE. setup() shows a UxTreeModel node;
## setup_hidden() a node the game does not have yet (a padlocked "???" slot
## that cannot be pressed). The view connects node_pressed.

signal node_pressed(node_id: StringName)

## Tile sizes; the button is NAME_H taller (the name hangs below the tile).
const TILE := 84.0
const CAP_TILE := 92.0
const NAME_H := 18.0
## Height of the name label: two lines, so a long name wraps instead of ending
## in dots. The second line hangs below the button, in the row's gap.
const NAME_LINES_H := 32.0
## How far the selection ring reaches beyond the tile: a selected node's name
## moves down by it, clear of the ring.
const RING_OUT := 7.0
const ICON := 60.0
## The padlock of a "coming soon" slot.
const HIDDEN_ICON := 36.0
## Width of the name under a tile sharing its cell, and under a tile alone in
## its cell or a capstone (set_name_width).
const NAME_W := 100.0
const WIDE_NAME_W := 150.0
## How far a capstone's arch rises above its tile, and how far above the tile
## its apex sits (where a vine ends).
const ARCH_RISE := 22.0
const ARCH_APEX := 13.0
const ARCH_STEPS := 12
const SELECTED_SCALE := Vector2(1.08, 1.08)
const POP_SCALE := Vector2(1.25, 1.25)
const BADGE_PULSE := Vector2(1.2, 1.2)
## Shades of the branch colour: the tile's fill, the rim of an owned node, the
## rim of an open one and the arch's stone.
const FILL_DARKEN := 0.6
const OWNED_LIGHTEN := 0.15
const OPEN_DARKEN := 0.2
const ARCH_DARKEN := 0.55
const LOCK_TEXTURE := preload("res://Assets/UI/Kit/padlock.svg")

var node_id: StringName = &""
var state: UxTreeModel.NodeState = UxTreeModel.NodeState.LOCKED
## The next rank can be bought now (the red "+").
var buyable: bool = false
var capstone: bool = false
## The tree's equipped capstone (the check).
var equipped: bool = false
## The branch colour the tile wears.
var accent: Color = Color.WHITE

## This node's own copy of the theme's NodeTile, recoloured by _paint().
var _tile_box: StyleBoxFlat = null
## Width of the name label (set_name_width).
var _name_w: float = NAME_W
var _pulse: Tween = null
var _scale_tween: Tween = null

@onready var _select: Control = %Select
@onready var _tile: PanelContainer = %Tile
@onready var _icon: TextureRect = %Icon
@onready var _pips: HBoxContainer = %Pips
@onready var _name: Label = %NameLabel
@onready var _badge: TextureRect = %Badge
@onready var _plus: Control = %Plus


func _ready() -> void:
	_tile_box = _tile.get_theme_stylebox(&"panel").duplicate() as StyleBoxFlat
	if _tile_box == null:
		_tile_box = StyleBoxFlat.new()
	_tile.add_theme_stylebox_override(&"panel", _tile_box)
	_fit(TILE, ICON)


## Shows `n` in `node_state` in the branch colour `p_accent`; `can_buy` shows
## the red "+", `p_equipped` the check of the equipped capstone.
func setup(n: UxTreeModel.TreeNodeData, node_state: UxTreeModel.NodeState, can_buy: bool,
		p_accent: Color, p_equipped: bool = false) -> void:
	node_id = n.id
	state = node_state
	buyable = can_buy
	capstone = n.capstone
	equipped = p_equipped
	accent = p_accent
	tooltip_text = n.name
	_fit(CAP_TILE if capstone else TILE, ICON)
	var locked := node_state == UxTreeModel.NodeState.LOCKED
	_icon.texture = n.icon
	_icon.modulate = UiPalette.LOCKED_ICON_MODULATE if locked else Color.WHITE
	_name.text = n.name
	_name.theme_type_variation = &"NodeNameLocked" if locked else &"NodeName"
	_badge.visible = p_equipped
	_plus.visible = can_buy
	_set_pips(n.rank, n.max_rank(), node_state == UxTreeModel.NodeState.MAXED)
	_paint()
	_set_pulse(can_buy)


## A node the data has but the game does not yet (UxTreeModel.hidden_nodes): a
## locked tile (or arch) with a padlock and "???", which ignores taps.
func setup_hidden(n: UxTreeModel.TreeNodeData) -> void:
	node_id = n.id
	state = UxTreeModel.NodeState.LOCKED
	buyable = false
	capstone = n.capstone
	equipped = false
	disabled = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_text = ""
	_fit(CAP_TILE if capstone else TILE, HIDDEN_ICON)
	_icon.texture = LOCK_TEXTURE
	_icon.modulate = UiPalette.LOCKED_ICON_MODULATE
	_name.text = "???"
	_name.theme_type_variation = &"NodeNameLocked"
	_badge.visible = false
	_plus.visible = false
	_set_pips(0, 0, false)
	_paint()
	_set_pulse(false)


## Side of the tile (84 or 92 px).
func tile_size() -> float:
	return _tile.size.x


## Gives the name `width` px, centred under the tile (the view: wide for a node
## alone in its cell).
func set_name_width(width: float) -> void:
	_name_w = width
	_place_name()


## The white selection ring and a small lift; the name steps below the ring.
func set_selected(on: bool) -> void:
	_select.visible = on
	_place_name()
	_tween_scale(SELECTED_SCALE if on else Vector2.ONE, 0.12, Tween.TRANS_QUAD)


func is_selected() -> bool:
	return _select.visible


## Purchase juice: the node pops and settles back.
func pop() -> void:
	var rest := SELECTED_SCALE if is_selected() else Vector2.ONE
	scale = POP_SCALE
	_tween_scale(rest, 0.3, Tween.TRANS_BACK)


## The name, centred under the tile (under the ring while selected).
func _place_name() -> void:
	var tile := tile_size()
	_name.size = Vector2(_name_w, NAME_LINES_H)
	_name.position = Vector2((tile - _name_w) * 0.5, tile + 1.0 + (RING_OUT if _select.visible else 0.0))


## Lays the parts out around a `tile` px tile with an `icon_px` px icon.
func _fit(tile: float, icon_px: float) -> void:
	_name_w = WIDE_NAME_W if capstone else NAME_W
	custom_minimum_size = Vector2(tile, tile + NAME_H)
	size = custom_minimum_size
	pivot_offset = Vector2(tile, tile) * 0.5
	_tile.position = Vector2.ZERO
	_tile.size = Vector2(tile, tile)
	_select.position = Vector2(-7.0, -7.0)
	_select.size = Vector2(tile + 14.0, tile + 14.0)
	# The icon sits a little high: the pips take the tile's bottom edge.
	_icon.position = Vector2((tile - icon_px) * 0.5, (tile - icon_px) * 0.5 - 4.0)
	_icon.size = Vector2(icon_px, icon_px)
	_pips.position = Vector2(0.0, tile - 16.0)
	_pips.size = Vector2(tile, 10.0)
	_place_name()
	_plus.position = Vector2(tile - 20.0, -8.0)
	_badge.position = Vector2(-9.0, -9.0)


## Recolours the tile (and the arch) for the state and the branch colour.
func _paint() -> void:
	var palette := UiPalette.get_default()
	var locked := state == UxTreeModel.NodeState.LOCKED
	_tile_box.bg_color = palette.locked_fill if locked else accent.darkened(FILL_DARKEN)
	_tile_box.border_color = _rim(palette)
	queue_redraw()


func _rim(palette: UiPalette) -> Color:
	match state:
		UxTreeModel.NodeState.MAXED:
			return palette.rank_max
		UxTreeModel.NodeState.OWNED:
			return accent.lightened(OWNED_LIGHTEN)
		UxTreeModel.NodeState.AVAILABLE:
			return accent.darkened(OPEN_DARKEN)
	return palette.locked_line


## A capstone's stone arch behind its tile (drawn before the children): walls
## from the tile's foot up to 42 % of its height, then a flattened half
## circle; branch-dark stone with a gold rim once owned, the branch colour
## while open, locked_fill and locked_line while closed. The foot stays open.
func _draw() -> void:
	if not capstone:
		return
	var palette := UiPalette.get_default()
	var tile := _tile.size.x
	var w := tile + 8.0
	var h := tile + ARCH_RISE
	var origin := Vector2(-4.0, -ARCH_RISE)
	var spring := h * 0.42
	var pts := PackedVector2Array([origin + Vector2(0.0, h), origin + Vector2(0.0, spring)])
	for i in range(1, ARCH_STEPS):
		var ang := PI + PI * i / ARCH_STEPS
		pts.append(origin + Vector2(w * 0.5 + cos(ang) * w * 0.5, spring + sin(ang) * w * 0.5 * 0.82))
	pts.append(origin + Vector2(w, spring))
	pts.append(origin + Vector2(w, h))
	var locked := state == UxTreeModel.NodeState.LOCKED
	var owned := state == UxTreeModel.NodeState.OWNED or state == UxTreeModel.NodeState.MAXED
	var rim := palette.rank_max if owned else (palette.locked_line if locked else accent)
	draw_colored_polygon(pts, palette.locked_fill if locked else accent.darkened(ARCH_DARKEN))
	draw_polyline(pts, palette.ink, 7.0, true)
	draw_polyline(pts, rim, 3.5, true)


func _set_pips(rank: int, max_rank: int, maxed: bool) -> void:
	for c in _pips.get_children():
		_pips.remove_child(c)
		c.queue_free()
	for i in max_rank:
		var pip := PanelContainer.new()
		pip.custom_minimum_size = Vector2(12, 10)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i >= rank:
			pip.theme_type_variation = &"PipOff"
		else:
			pip.theme_type_variation = &"PipMax" if maxed else &"PipOn"
		_pips.add_child(pip)


func _set_pulse(on: bool) -> void:
	if _pulse != null:
		_pulse.kill()
		_pulse = null
	_plus.scale = Vector2.ONE
	if not on:
		return
	_plus.pivot_offset = _plus.size * 0.5
	_pulse = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(_plus, ^"scale", BADGE_PULSE, 0.6)
	_pulse.tween_property(_plus, ^"scale", Vector2.ONE, 0.6)


func _tween_scale(to: Vector2, time: float, trans: Tween.TransitionType) -> void:
	if _scale_tween != null:
		_scale_tween.kill()
	_scale_tween = create_tween().set_trans(trans).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, ^"scale", to, time)


func _on_pressed() -> void:
	node_pressed.emit(node_id)
