extends ColorRect
## Contact sheet of the authored rig moves (Assets/Characters/_moves): one block
## per character with a column per move it plays (its abilities' moves, a mob
## or the fox its attack, then hurt and cheer) and a row per sampled moment
## (three key times of the move), each cell a CharacterRig puppet frozen there
## (play_move(move, t), then no processing). The same bodies, profiles and
## libraries the match uses, every block at one scale per group so sizes
## compare. Not shipped (tools/).
## Render muted on a copy of the project (group = heroes | monsters | small,
## or ids such as irelia,vlad; three characters fill the portrait window):
##   godot --path <copy> --audio-driver Dummy --fixed-fps 30
##         --write-movie <dir>/f.png --quit-after 5 res://tools/preview/MoveSheet.tscn -- group=monsters

const GROUPS: Dictionary[String, Array] = {
	"heroes": ["irelia", "vlad", "ted", "river"],
	"monsters": ["grount", "gorrak", "nyxa"],
	"small": ["pet", "hog", "bat"],
}
const ROSTER := "res://Scenes/NPCs/roster.tres"
const SHADOW_BLOB := preload("res://Assets/Characters/shadow_blob.svg")
const CELL := Vector2(100, 92)
const FEET_MARGIN := 8.0
## Moments shown where the evenly spread key times miss the telling ones.
const KEY_TIMES: Dictionary[StringName, Array] = {
	&"slam": [0.08, 0.5, 1.0],
	&"stomp": [0.2, 0.5, 0.6],
	&"charge": [0.06, 0.3, 0.66],
	&"shriek": [0.1, 0.14, 0.4],
	&"swoop": [0.06, 0.3, 0.48],
	&"cheer": [0.12, 0.22, 0.44],
	&"spin": [0.08, 0.17, 0.3],
	&"twirl": [0.08, 0.16, 0.24],
}
## Showcase grount at this stage (its horns and spikes grow).
const GROUNT_STAGE := 2

## Which characters to show: a GROUPS key or comma-separated ids; a
## "group=<...>" user argument wins.
@export var group: String = "heroes"

@onready var _list: VBoxContainer = $Margin/List


func _ready() -> void:
	color = UiPalette.get_default().bg_base
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("group="):
			group = arg.substr(6)
	var ids: Array = GROUPS.get(group, Array(group.split(",", false)))
	var title := Label.new()
	title.text = "Rig moves: %s" % group
	title.theme_type_variation = &"HeaderLarge"
	_list.add_child(title)
	var art_scale := INF
	for id: String in ids:
		art_scale = minf(art_scale, _fit(id))
	for id: String in ids:
		var block := VBoxContainer.new()
		_list.add_child(block)
		_fill_block(block, id, art_scale)


func _profile(id: String) -> RigProfile:
	return load("res://Assets/Characters/%s/%s_motion.tres" % [id, id]) as RigProfile


func _body_scene(id: String) -> PackedScene:
	return load("res://Assets/Characters/%s/%s_body.tscn" % [id, id]) as PackedScene


## Art scale at which the character (with room for a hop) fits a cell.
func _fit(id: String) -> float:
	var profile := _profile(id)
	var body := _body_scene(id).instantiate() as RigBody
	var b := body.bounds
	body.free()
	var h := (-b.position.y + 24.0 + profile.hover) * profile.world_scale
	var w := 2.0 * maxf(-b.position.x, b.end.x) * profile.world_scale + 8.0
	return minf((CELL.y - FEET_MARGIN) / h, CELL.x / w)


## The moves `id` plays: its roster abilities' (basic / active / ultimate, or
## the monster's three slots, plus River's heal staff and a cleave's
## Whirlwind), else the attack; then hurt and cheer.
func _moves_of(id: String) -> Array[StringName]:
	var out: Array[StringName] = []
	var roster := load(ROSTER) as Roster
	for def in roster.all():
		if String(def.character_id()) != id:
			continue
		var scene := (load(def.scene_path) as PackedScene).instantiate()
		var abilities: Array[AbilityBase] = []
		var system := scene.get_node_or_null(^"AbilitySystem") as AbilitySystem
		if system:
			abilities.assign([system.basic_attack, system.active_ability, system.ultimate_ability])
		else:
			for slot in ["ability_1", "ability_2", "ability_3"]:
				abilities.append(scene.get(slot) as AbilityBase)
		for a in abilities:
			if a == null:
				continue
			out.append(a.move_name if a.move_name != &"" else CharacterRig.default_move(a.ability_type))
			if a is RiverBasicAttack and (a as RiverBasicAttack).heal_move_name != &"":
				out.append((a as RiverBasicAttack).heal_move_name)
			if a is BullFrontCleave and (a as BullFrontCleave).full_circle_move_name != &"":
				out.append((a as BullFrontCleave).full_circle_move_name)
		scene.free()
	if out.is_empty():
		out.append(&"attack")
	for m: StringName in [&"hurt", &"cheer"]:
		if not out.has(m):
			out.append(m)
	return out


## Three telling moments of a move: KEY_TIMES, else key times spread over it.
func _times(lib: AnimationLibrary, move: StringName) -> Array[float]:
	var out: Array[float] = []
	if KEY_TIMES.has(move):
		out.assign(KEY_TIMES[move])
		return out
	var anim := lib.get_animation(move)
	var keys: Array[float] = []
	for i in anim.get_track_count():
		for k in anim.track_get_key_count(i):
			var t := anim.track_get_key_time(i, k)
			if t > 0.05 and t < anim.length - 0.05 and not keys.has(t):
				keys.append(t)
	keys.sort()
	if keys.is_empty():
		keys.append(anim.length * 0.5)
	for f: float in [0.0, 0.5, 1.0]:
		var t := keys[roundi(f * (keys.size() - 1))]
		if not out.has(t):
			out.append(t)
	return out


## The block's parents are in the tree before its cells: a puppet must be
## ready before play_move poses it.
func _fill_block(block: VBoxContainer, id: String, art_scale: float) -> void:
	var profile := _profile(id)
	var lib := profile.moves
	block.add_theme_constant_override(&"separation", 2)
	var header := Label.new()
	header.text = "%s  (%s)" % [id, String(RigProfile.BodyPlan.keys()[profile.body_plan]).to_lower()]
	header.theme_type_variation = &"HeaderSmall"
	block.add_child(header)
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override(&"separation", 4)
	block.add_child(grid)
	for move in _moves_of(id):
		var column := VBoxContainer.new()
		column.add_theme_constant_override(&"separation", 2)
		grid.add_child(column)
		var name_label := Label.new()
		name_label.text = String(move)
		name_label.theme_type_variation = &"Caption"
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(name_label)
		if lib == null or not lib.has_animation(move):
			continue
		for t in _times(lib, move):
			_cell(column, id, profile, art_scale, move, t)


## A card cell holding one puppet frozen at `t` seconds into `move`.
func _cell(parent: Control, id: String, profile: RigProfile, art_scale: float, move: StringName, t: float) -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardInner"
	parent.add_child(card)
	var stage := Control.new()
	stage.custom_minimum_size = CELL
	card.add_child(stage)
	var caption := Label.new()
	caption.text = "%.2f" % t
	caption.theme_type_variation = &"Caption"
	caption.position = Vector2(3, 0)
	stage.add_child(caption)
	var holder := Node2D.new()
	holder.position = Vector2(CELL.x * 0.45, CELL.y - FEET_MARGIN)
	holder.scale = Vector2.ONE * art_scale
	stage.add_child(holder)
	var rig := CharacterRig.new()
	rig.profile = profile
	rig.tier = CharacterRig.Tier.FULL
	var shadow := Sprite2D.new()
	shadow.texture = SHADOW_BLOB
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rig.add_child(shadow)
	rig.shadow = shadow
	var body := _body_scene(id).instantiate() as RigBody
	rig.add_child(body)
	rig.body = body
	holder.add_child(rig)
	if id == "grount":
		body.set_stage(GROUNT_STAGE)
	rig.play_move(move, t)
	rig.set_process(false)
