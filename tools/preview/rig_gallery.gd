extends ColorRect
## Proof sheet of the SVG character rigs (Scripts/Rig): every built character
## (RigBuilder.ROOTS: Assets/Characters, then the test fixture) as CharacterRig
## puppets, the first one large, then one row of poses each. It instances the
## generated bodies, so it shows what the match draws. Not shipped (tools/).
## Render muted on a copy of the project (after tools/build_rigs.sh):
##   godot --path <copy> --audio-driver Dummy --fixed-fps 30
##         --write-movie <dir>/f.png --quit-after 90 res://tools/preview/RigGallery.tscn

const POSES: Array[String] = ["idle", "walk", "run", "attack", "hurt", "stage 2"]
const CELL := Vector2(100, 128)
const CELL_SCALE := 2.0
const SHOWCASE := Vector2(320, 300)
const SHOWCASE_SCALE := 4.6
## Feet distance from the bottom of a cell.
const FEET_MARGIN := 14.0
## Every this many frames the attack and hurt cells replay their reaction.
const REPLAY_FRAMES := 30

var _attackers: Array[CharacterRig] = []
var _hurting: Array[CharacterRig] = []
var _frame := 0

@onready var _list: VBoxContainer = $Margin/List


func _ready() -> void:
	color = UiPalette.get_default().bg_base
	var title := Label.new()
	title.text = "Rig gallery"
	title.theme_type_variation = &"HeaderLarge"
	_list.add_child(title)
	var first := true
	for dir_root in RigBuilder.ROOTS:
		for id in RigBuilder.character_dirs(dir_root):
			var dir := "%s/%s/%s" % [dir_root, id, id]
			var body_scene := load(dir + "_body.tscn") as PackedScene
			var profile: RigProfile = RigProfile.new()
			if ResourceLoader.exists(dir + "_motion.tres"):
				profile = load(dir + "_motion.tres") as RigProfile
			if body_scene == null:
				continue
			if first:
				_list.add_child(_showcase(body_scene, profile))
				first = false
			_list.add_child(_row(id, body_scene, profile))


func _showcase(body_scene: PackedScene, profile: RigProfile) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for speed in [0.0, profile.full_speed * 0.6]:
		var rig := _cell(row, body_scene, profile, SHOWCASE, SHOWCASE_SCALE, "idle" if speed == 0.0 else "walk")
		rig.puppet_speed = speed
	return row


func _row(id: String, body_scene: PackedScene, profile: RigProfile) -> Control:
	var box := VBoxContainer.new()
	var parts := body_scene.instantiate() as RigBody
	var header := Label.new()
	header.text = "%s  %s, %d parts" % [id, RigProfile.BodyPlan.keys()[profile.body_plan].to_lower(), parts.part_order.size()]
	header.theme_type_variation = &"HeaderSmall"
	parts.free()
	box.add_child(header)
	var row := HBoxContainer.new()
	box.add_child(row)
	for pose in POSES:
		var rig := _cell(row, body_scene, profile, CELL, CELL_SCALE, pose)
		match pose:
			"walk":
				rig.puppet_speed = profile.full_speed * 0.5
			"run":
				rig.puppet_speed = profile.full_speed
			"attack":
				_attackers.append(rig)
			"hurt":
				_hurting.append(rig)
			"stage 2":
				rig.body.set_stage(2)
	return box


## A card cell holding one puppet rig, feet on the cell's bottom, captioned.
func _cell(parent: Control, body_scene: PackedScene, profile: RigProfile, cell_size: Vector2,
		art_scale: float, caption: String) -> CharacterRig:
	var column := VBoxContainer.new()
	parent.add_child(column)
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardInner"
	column.add_child(card)
	var stage := Control.new()
	stage.custom_minimum_size = cell_size
	card.add_child(stage)
	var holder := Node2D.new()
	holder.position = Vector2(cell_size.x * 0.5, cell_size.y - FEET_MARGIN)
	holder.scale = Vector2.ONE * art_scale
	stage.add_child(holder)
	var rig := CharacterRig.new()
	rig.profile = profile
	rig.tier = CharacterRig.Tier.FULL
	var body := body_scene.instantiate() as RigBody
	rig.add_child(body)
	rig.body = body
	holder.add_child(rig)
	var label := Label.new()
	label.text = caption
	label.theme_type_variation = &"Caption"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	return rig


func _process(_delta: float) -> void:
	_frame += 1
	if _frame % REPLAY_FRAMES == 10:
		for rig in _attackers:
			rig.play_move(&"attack")
		for rig in _hurting:
			rig.play_hurt()
