extends TestCase

## Phase 8.3 retired the pre-overhaul pieces (the old screens are
## test_menu_root.gd's): the pixel AnimatedSprite2D path (no scene carries one,
## no SpriteFrames, no MonsterVisualConfig frame swap or stage tint, no
## animated_sprite on EntityBase; EntityBase.visual_root() is the rig), the
## pixel PNGs (the only raster images left are the ground tileset and the app
## icon), and every hand-written scene, and the rig move libraries, carry a
## uid in their header so references survive a move.

## The raster images the game still uses: the ground tiles and the app icon
## (project.godot config/icon).
const RASTER_ALLOWED: Array[String] = [
	"res://Scenes/World/Assets/tf_jungle_tileset.png",
	"res://Assets/Icon.jpg",
]
## Hand-written resources outside Scenes/ that other files reference.
const UID_RESOURCES: Array[String] = [
	"res://Assets/Characters/_moves/humanoid_moves.tres",
	"res://Assets/Characters/_moves/quadruped_moves.tres",
	"res://Assets/Characters/_moves/flyer_moves.tres",
]
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"


func _files(dir_path: String, suffixes: Array[String], out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	for sub: String in d.get_directories():
		if not sub.begins_with(".") and sub != "addons":
			_files(dir_path.path_join(sub), suffixes, out)
	for f: String in d.get_files():
		for suffix: String in suffixes:
			if f.ends_with(suffix):
				out.append(dir_path.path_join(f))


func test_no_scene_carries_a_pixel_sprite() -> void:
	var scenes: Array[String] = []
	_files("res://Scenes", [".tscn"], scenes)
	_files("res://Assets/Characters", [".tscn"], scenes)
	assert_true(scenes.size() > 40, "found the scenes (%d)" % scenes.size())
	for path: String in scenes:
		var state := (load(path) as PackedScene).get_state()
		for i in state.get_node_count():
			assert_false(state.get_node_type(i) == &"AnimatedSprite2D",
					"%s: %s is an AnimatedSprite2D" % [path, state.get_node_path(i)])
	var resources: Array[String] = []
	_files("res://", [".tres"], resources)
	for path: String in resources:
		var header := FileAccess.get_file_as_string(path).get_slice("\n", 0)
		assert_false(header.contains("type=\"SpriteFrames\""), "%s is a SpriteFrames" % path)
		assert_false(header.contains("MonsterVisualConfig"), "%s is a MonsterVisualConfig" % path)
	assert_false(ResourceLoader.exists("res://Scenes/NPCs/Monster/monster_visual_config.gd"), "MonsterVisualConfig is gone")


func test_effects_target_the_rig_and_no_sprite_is_left() -> void:
	for path: String in [VLAD, GROUNT]:
		var e := await spawn_frozen(path, Vector2(4000, 4000)) as EntityBase
		assert_false("animated_sprite" in e, "%s: no animated_sprite" % path.get_file())
		assert_false("visual_config" in e, "%s: no visual_config" % path.get_file())
		assert_eq(e.visual_root(), e.get_node(^"Rig"), "%s: visual_root() is the rig" % path.get_file())
		var facing := e.get_node_or_null(^"Sprite2D") as Sprite2D
		assert_true(facing != null and not facing.visible, "%s: the hidden facing carrier stays" % path.get_file())
		e.queue_free()
	await wait_frames(1)


func test_only_the_tileset_and_the_app_icon_are_raster_images() -> void:
	var found: Array[String] = []
	_files("res://", [".png", ".jpg", ".jpeg", ".webp"], found)
	var images: Array[String] = []
	for path: String in found:
		if not path.begins_with("res://tools/"):  # tools/art/preview: git-ignored review sheets
			images.append(path)
	images.sort()
	var allowed: Array[String] = RASTER_ALLOWED.duplicate()
	allowed.sort()
	assert_eq(images, allowed, "the pixel sprite PNGs are gone")
	var icon := String(ProjectSettings.get_setting("application/config/icon", ""))
	if icon.begins_with("uid://"):
		icon = ResourceUID.get_id_path(ResourceUID.text_to_id(icon))
	assert_eq(icon, "res://Assets/Icon.jpg", "Icon.jpg is the app icon")


func test_hand_written_scenes_carry_a_uid() -> void:
	var paths: Array[String] = []
	_files("res://Scenes", [".tscn"], paths)
	paths.append_array(UID_RESOURCES)
	for path: String in paths:
		var header := FileAccess.get_file_as_string(path).get_slice("\n", 0)
		assert_true(header.contains("uid=\"uid://"), "%s has a uid in its header" % path)
