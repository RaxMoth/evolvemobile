class_name RigView
extends Control

## A roster character's animated rig inside UI: lobby showcases, the collection
## cards, the match result. The same <id>_body.tscn and CharacterRig the match
## draws, in puppet mode (no entity: always awake, facing right), fitted to this
## Control: the art's box (RigBody.bounds, mirrored with `flip`, raised by a
## flyer's highest hover or a walker's bounce) scaled to fit inside it, feet
## on the bottom edge minus `padding`, the box centred horizontally. Refits on
## resize.
##
## `silhouette` = a locked character: the whole body is multiplied down to the
## palette's locked_fill (one modulate on the holder, so the parts' own ink
## outlines read as one solid shape). For grids of many cards set
## `animated = false`: the rig is posed once and never processes. A hidden
## view (a menu screen under another one, a filtered-out card) sleeps too and
## wakes when it shows again.
##
## Presentation only: the rig never touches the global RNG (its idle phase
## comes from a private one), so menus cannot disturb a match's determinism.

const SHADOW_BLOB := preload("res://Assets/Characters/shadow_blob.svg")

## The character to show (its rig_body and rig_profile). Null = empty.
## Setting the same character again keeps the running rig.
@export var character: CharacterDef:
	set(v):
		if v == character:
			return
		character = v
		if is_node_ready():
			_rebuild()
## Evolution stage the body shows (monsters; 1 for heroes).
@export_range(1, 3) var stage: int = 1:
	set(v):
		stage = v
		if rig:
			rig.body.set_stage(stage)
## False: posed once, never processed (big grids).
@export var animated: bool = true:
	set(v):
		animated = v
		_apply_awake()
@export var silhouette: bool = false:
	set(v):
		silhouette = v
		_apply_silhouette()
## Mirror the character (a group on a stage facing inward).
@export var flip: bool = false:
	set(v):
		flip = v
		_fit()
## Fraction of the height kept free above and below the art.
@export_range(0.0, 0.4) var padding: float = 0.08:
	set(v):
		padding = v
		_fit()
## World px/s the puppet walks in place (0 = idle).
@export var walk_speed: float = 0.0:
	set(v):
		walk_speed = v
		if rig:
			rig.puppet_speed = walk_speed
## Ground contact shadow under the feet, as in the match (read when the rig
## is built).
@export var shadow: bool = true

var rig: CharacterRig = null
var _holder: Node2D = null


func _init() -> void:
	# A picture inside cards and buttons: taps go to them. A scene can still
	# set another filter (scene values apply after _init).
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	resized.connect(_fit)
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_apply_awake()


func _rebuild() -> void:
	if _holder:
		_holder.queue_free()
		_holder = null
		rig = null
	if character == null or character.rig_body == null or character.rig_profile == null:
		return
	_holder = Node2D.new()
	_holder.name = "Holder"
	add_child(_holder)
	var profile := character.rig_profile
	var body := character.rig_body.instantiate() as RigBody
	rig = CharacterRig.new()
	rig.name = "Rig"
	rig.profile = profile
	rig.tier = CharacterRig.Tier.FULL
	rig.puppet_speed = walk_speed
	if shadow:
		var blob := Sprite2D.new()
		blob.name = "Shadow"
		blob.texture = SHADOW_BLOB
		blob.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		rig.add_child(blob)
		# Sized by the rig itself, by the match's rule (shadow_radius_for).
		rig.shadow = blob
	rig.add_child(body)
	rig.body = body
	_holder.add_child(rig)
	body.set_stage(stage)
	_apply_awake()
	_apply_silhouette()
	_fit()


func play_move(move: StringName) -> void:
	if rig:
		rig.play_move(move)


func play_hurt() -> void:
	if rig:
		rig.play_hurt()


## Holder scale and feet position that fit the art inside this Control.
func _fit() -> void:
	if rig == null:
		return
	var profile := character.rig_profile
	# The art's box around the feet origin (art units), raised by the highest
	# lift so a bat that floats above its origin stays inside the Control. A
	# puppet always faces right, so the box is mirrored only by `flip`; it is
	# centred, not the feet (a boar's head reaches further than its tail).
	var b := rig.body.bounds
	var left := -b.end.x if flip else b.position.x
	var right := -b.position.x if flip else b.end.x
	var top := b.position.y
	if profile.body_plan == RigProfile.BodyPlan.FLYER:
		top -= profile.hover * 1.35
	else:
		top -= profile.bounce
	var bottom := maxf(b.end.y, 0.0)
	var art := Vector2(right - left, bottom - top) * profile.world_scale
	if art.x <= 0.0 or art.y <= 0.0:
		return
	var avail := size * (1.0 - 2.0 * padding)
	var s := minf(avail.x / art.x, avail.y / art.y)
	var centre_x := (left + right) * 0.5 * profile.world_scale * s
	_holder.scale = Vector2(-s if flip else s, s)
	_holder.position = Vector2(size.x * 0.5 - centre_x, size.y * (1.0 - padding) - bottom * profile.world_scale * s)


## The rig animates while the view is animated and shown.
func _apply_awake() -> void:
	if rig:
		rig.set_on_screen(animated and is_visible_in_tree())


func _apply_silhouette() -> void:
	if _holder:
		_holder.modulate = UiPalette.get_default().locked_fill if silhouette else Color.WHITE
