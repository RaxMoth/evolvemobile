class_name RigBody
extends Node2D

## The cut-out body of one character: GENERATED as Assets/Characters/<id>/<id>_body.tscn
## by tools/build_rigs.sh (never edit the scene by hand; edit src/ and rebuild).
##
## Parts are Sprite2D regions of ONE atlas texture (a character batches into one
## draw), arranged in the art's joint hierarchy and drawn in the art's z order.
## Every part is a scene-unique node, so animation tracks address "%head:rotation"
## whatever the hierarchy. The root's own transform belongs to the CharacterRig
## driving it (flip, squash, art scale); the parts' transforms to the rig's
## procedural layer or an authored move. Nothing here reads gameplay state.

@export var character_id: StringName
## Sheet pixels per art unit (the sheet's svg/scale import option).
@export var sheet_scale: float = 3.0
## Rig origin (the feet) in canvas units of the source art.
@export var origin: Vector2 = Vector2(64, 150)
## Union of the parts' boxes, art units, relative to the origin (UI fitting,
## notifier rects).
@export var bounds: Rect2
## Part names in draw (z) order.
@export var part_order: PackedStringArray
## part name -> the evolution stages it shows in (absent = every stage).
@export var stage_parts: Dictionary
## Evolution stage -> the box of the parts that stage shows (art units, like
## `bounds`); only a body with stage parts has it. drawn_bounds() reads it.
@export var stage_bounds: Dictionary
## proxy node -> part whose local transform it mirrors (see RigBuilder).
@export var proxies: Dictionary

var _rest: Dictionary[String, Transform2D] = {}  ## part -> transform of the generated scene
var _proxy_pairs: Array[Node2D] = []  ## [proxy, source, proxy, source, ...]
## The stage set_stage last showed (a fresh body shows Stage 1).
var _stage: int = 1


func _ready() -> void:
	for n in part_order:
		var p := part(StringName(n))
		if p:
			_rest[n] = p.transform
	for px: String in proxies:
		var proxy := get_node_or_null(NodePath(px)) as Node2D
		var source := part(StringName(proxies[px]))
		if proxy and source:
			_proxy_pairs.append(proxy)
			_proxy_pairs.append(source)


func part(part_name: StringName) -> Node2D:
	return get_node_or_null(NodePath("%" + String(part_name))) as Node2D


func rest_of(part_name: StringName) -> Transform2D:
	var rest: Transform2D = _rest.get(String(part_name), Transform2D.IDENTITY)
	return rest


## Back to the generated pose (pooled reuse, end of an authored move). The
## CharacterRig driving the body only writes the channels that changed, so it
## forgets what it wrote whenever it calls this.
func reset_pose() -> void:
	for n: String in _rest:
		part(StringName(n)).transform = _rest[n]
	sync_proxies()


## Copy each proxied part's local transform onto its proxy (call after posing).
func sync_proxies() -> void:
	for i in range(0, _proxy_pairs.size(), 2):
		_proxy_pairs[i].transform = _proxy_pairs[i + 1].transform


## Shows the parts of one evolution stage (parts without a stage list always show).
func set_stage(stage: int) -> void:
	_stage = stage
	for n: String in stage_parts:
		var p := part(StringName(n))
		if p:
			p.visible = (stage_parts[n] as PackedInt32Array).has(stage)


## Height of the art in units (UI fitting).
func art_height() -> float:
	return bounds.size.y


## The box of the parts drawn now (art units): the stage's own box on a body
## with stage parts (Grount's calf at Stage I is lower and narrower than its
## Stage III horns), else `bounds`. The character's effect anchors read it
## (CharacterRig.mid_body / head_top / half_width); UI fitting, the notifier,
## the shadow and the HP bar keep the union `bounds`.
func drawn_bounds() -> Rect2:
	var box: Rect2 = stage_bounds.get(_stage, bounds)
	return box
