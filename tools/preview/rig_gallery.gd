extends ColorRect
## Proof sheet of the SVG character rigs (Scripts/Rig): every built character
## of Assets/Characters (the test fixture only while there is none) as
## CharacterRig puppets. A showcase of three large ones on top, then one row of
## poses per character, all rows at ONE common scale so the characters keep
## their world sizes relative to each other (RigProfile.world_scale). It
## instances the generated bodies and motion profiles, so it shows what the
## match draws. Not shipped (tools/).
## Render muted on a copy of the project (after tools/build_rigs.sh):
##   godot --path <copy> --audio-driver Dummy --fixed-fps 30
##         --write-movie <dir>/f.png --quit-after 90 res://tools/preview/RigGallery.tscn

const POSES: Array[String] = ["idle", "walk", "run", "attack", "hurt", "stage 2"]
## Showcase: character, stage, walking? (characters that are not built are skipped).
const SHOWCASE: Array[Array] = [["river", 1, true], ["grount", 3, false], ["nyxa", 1, false]]
const SHOWCASE_CELL := Vector2(212, 196)
const CELL := Vector2(84, 80)
const NAME_WIDTH := 92.0
## Feet distance from the bottom of a cell, and free room above the tallest head.
const FEET_MARGIN := 8.0
const HEAD_ROOM := 4.0
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
	var ids := RigBuilder.character_dirs(RigBuilder.ROOT)
	var root := RigBuilder.ROOT
	if ids.is_empty():
		ids = RigBuilder.character_dirs(RigBuilder.FIXTURE_ROOT)
		root = RigBuilder.FIXTURE_ROOT
	var bodies: Dictionary[String, PackedScene] = {}
	var profiles: Dictionary[String, RigProfile] = {}
	var row_scale := INF
	for id in ids:
		var dir := "%s/%s/%s" % [root, id, id]
		var body_scene := load(dir + "_body.tscn") as PackedScene
		if body_scene == null:
			continue
		var profile: RigProfile = RigProfile.new()
		if ResourceLoader.exists(dir + "_motion.tres"):
			profile = load(dir + "_motion.tres") as RigProfile
		bodies[id] = body_scene
		profiles[id] = profile
		row_scale = minf(row_scale, _fit(body_scene, profile, CELL))
	_list.add_child(_showcase(bodies, profiles))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", 4)
	_list.add_child(rows)
	rows.add_child(_pose_header())
	for id in bodies:
		rows.add_child(_row(id, bodies[id], profiles[id], row_scale))


## Art scale at which the character's world-size body (RigBody.bounds x
## world_scale, plus a flyer's highest hover) fits a cell standing on its feet.
func _fit(body_scene: PackedScene, profile: RigProfile, cell_size: Vector2) -> float:
	var body := body_scene.instantiate() as RigBody
	var b := body.bounds
	body.free()
	var lift := profile.hover * 1.35 if profile.body_plan == RigProfile.BodyPlan.FLYER else profile.bounce
	var h := (-b.position.y + lift) * profile.world_scale
	var w := 2.0 * maxf(-b.position.x, b.end.x) * profile.world_scale
	return minf((cell_size.y - FEET_MARGIN - HEAD_ROOM) / h, (cell_size.x - HEAD_ROOM) / w)


func _showcase(bodies: Dictionary[String, PackedScene], profiles: Dictionary[String, RigProfile]) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var picks: Array[Array] = []
	for pick in SHOWCASE:
		if bodies.has(String(pick[0])):
			picks.append(pick)
	if picks.is_empty() and not bodies.is_empty():
		picks.append([bodies.keys()[0], 1, true])
	for pick in picks:
		var id := String(pick[0])
		var walking := bool(pick[2])
		var caption := "%s %s" % [id, "walk" if walking else ("stage %d" % int(pick[1]) if int(pick[1]) > 1 else "idle")]
		var art_scale := _fit(bodies[id], profiles[id], SHOWCASE_CELL)
		var rig := _cell(row, bodies[id], profiles[id], SHOWCASE_CELL, art_scale, caption)
		rig.body.set_stage(int(pick[1]))
		if walking:
			rig.puppet_speed = profiles[id].full_speed * 0.6
	return row


func _pose_header() -> Control:
	var row := HBoxContainer.new()
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(NAME_WIDTH, 0)
	row.add_child(spacer)
	for pose in POSES:
		var label := Label.new()
		label.text = pose
		label.theme_type_variation = &"Caption"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(CELL.x + 8.0, 0)
		row.add_child(label)
	return row


func _row(id: String, body_scene: PackedScene, profile: RigProfile, art_scale: float) -> Control:
	var row := HBoxContainer.new()
	var names := VBoxContainer.new()
	names.custom_minimum_size = Vector2(NAME_WIDTH, 0)
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(names)
	var header := Label.new()
	header.text = id
	header.theme_type_variation = &"HeaderSmall"
	names.add_child(header)
	var parts := body_scene.instantiate() as RigBody
	var info := Label.new()
	info.text = "%s\nx%s, %d parts" % [String(RigProfile.BodyPlan.keys()[profile.body_plan]).to_lower(),
		String.num(profile.world_scale, 2), parts.part_order.size()]
	info.theme_type_variation = &"Caption"
	parts.free()
	names.add_child(info)
	for pose in POSES:
		var rig := _cell(row, body_scene, profile, CELL, art_scale, "")
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
	return row


## A card cell holding one puppet rig, feet on the cell's bottom, captioned
## when `caption` is not empty.
func _cell(parent: Control, body_scene: PackedScene, profile: RigProfile, cell_size: Vector2,
		art_scale: float, caption: String) -> CharacterRig:
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 0)
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
	if not caption.is_empty():
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
