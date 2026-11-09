class_name SkillNodeButton
extends Button

## One node of a skill tree (SkillTreeView): an 84 px ring around the node's
## icon, its rank pips underneath, a padlock while it is locked, a star once it
## is maxed and the red notify dot (gently pulsing) while its next rank can be
## bought. Capstones use the square Cap* frame. The look is the theme's:
##   NodeLocked / NodeAvailable / NodeOwned / NodeMaxed (CapLocked /
##   CapAvailable / CapOwned), PipOn / PipOff / PipMax, SelectRing.
## setup() shows a UxTreeModel node; the view connects node_pressed.

signal node_pressed(node_id: StringName)

## Size of the ring (the button is taller: the pips hang below it).
const RING := 84.0
const SELECTED_SCALE := Vector2(1.08, 1.08)
const POP_SCALE := Vector2(1.25, 1.25)
const DOT_PULSE := Vector2(1.2, 1.2)
const LOCK_TEXTURE := preload("res://Assets/UI/Kit/padlock.svg")
const STAR_TEXTURE := preload("res://Assets/UI/Icons/UI/ui_star.svg")

var node_id: StringName = &""
var state: UxTreeModel.NodeState = UxTreeModel.NodeState.LOCKED
## The next rank can be bought now (the red dot).
var buyable: bool = false

var _pulse: Tween = null
var _scale_tween: Tween = null

@onready var _select: Control = %Select
@onready var _ring: PanelContainer = %Ring
@onready var _icon: TextureRect = %Icon
@onready var _pips: HBoxContainer = %Pips
@onready var _badge: TextureRect = %Badge
@onready var _dot: TextureRect = %Dot


func _ready() -> void:
	pivot_offset = Vector2(size.x * 0.5, RING * 0.5)


## Shows `n` in `node_state`; `can_buy` lights the red dot.
func setup(n: UxTreeModel.TreeNodeData, node_state: UxTreeModel.NodeState, can_buy: bool) -> void:
	node_id = n.id
	state = node_state
	buyable = can_buy
	tooltip_text = n.name
	_icon.texture = n.icon
	var locked := node_state == UxTreeModel.NodeState.LOCKED
	_icon.modulate = UiPalette.LOCKED_ICON_MODULATE if locked else Color.WHITE
	_ring.theme_type_variation = _frame(n.capstone, node_state)
	_badge.visible = locked or node_state == UxTreeModel.NodeState.MAXED
	_badge.texture = LOCK_TEXTURE if locked else STAR_TEXTURE
	_dot.visible = can_buy
	_set_pips(n.rank, n.max_rank(), node_state == UxTreeModel.NodeState.MAXED)
	_set_pulse(can_buy)


## The white selection ring and a small lift.
func set_selected(on: bool) -> void:
	_select.visible = on
	_tween_scale(SELECTED_SCALE if on else Vector2.ONE, 0.12, Tween.TRANS_QUAD)


func is_selected() -> bool:
	return _select.visible


## Purchase juice: the node pops and settles back.
func pop() -> void:
	var rest := SELECTED_SCALE if is_selected() else Vector2.ONE
	scale = POP_SCALE
	_tween_scale(rest, 0.3, Tween.TRANS_BACK)


static func _frame(capstone: bool, node_state: UxTreeModel.NodeState) -> StringName:
	match node_state:
		UxTreeModel.NodeState.LOCKED:
			return &"CapLocked" if capstone else &"NodeLocked"
		UxTreeModel.NodeState.AVAILABLE:
			return &"CapAvailable" if capstone else &"NodeAvailable"
		UxTreeModel.NodeState.OWNED:
			return &"CapOwned" if capstone else &"NodeOwned"
	return &"CapOwned" if capstone else &"NodeMaxed"


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
	_dot.scale = Vector2.ONE
	if not on:
		return
	_dot.pivot_offset = _dot.size * 0.5
	_pulse = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(_dot, ^"scale", DOT_PULSE, 0.6)
	_pulse.tween_property(_dot, ^"scale", Vector2.ONE, 0.6)


func _tween_scale(target: Vector2, time: float, trans: Tween.TransitionType) -> void:
	if _scale_tween != null:
		_scale_tween.kill()
	_scale_tween = create_tween().set_trans(trans).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, ^"scale", target, time)


func _on_pressed() -> void:
	node_pressed.emit(node_id)
