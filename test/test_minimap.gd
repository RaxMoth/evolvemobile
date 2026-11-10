extends TestCase

## Minimap mapping + fairness rules (no fog system needed for these).

const SCENE := "res://Scenes/UI/Minimap/Minimap.tscn"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"


func test_world_map_round_trip_and_clamping() -> void:
	var mm := (load(SCENE) as PackedScene).instantiate() as Minimap
	add_child(mm)
	mm.size = Vector2(160, 128)
	mm.set_world_bounds(Vector2(100, 200), Vector2(1000, 800))
	assert_eq(mm.world_to_map(Vector2(100, 200)), Vector2.ZERO)
	assert_eq(mm.world_to_map(Vector2(1100, 1000)), Vector2(160, 128))
	assert_eq(mm.world_to_map(Vector2(600, 600)), Vector2(80, 64))
	assert_eq(mm.world_to_map(Vector2(-5000, -5000)), Vector2.ZERO, "clamped")
	assert_eq(mm.map_to_world(Vector2(80, 64)), Vector2(600, 600))
	mm.queue_free()


func test_fairness_rules() -> void:
	var mm := (load(SCENE) as PackedScene).instantiate() as Minimap
	add_child(mm)
	var vlad := await spawn_entity(VLAD, Vector2(0, 0))
	var grount := await spawn_entity(GROUNT, Vector2(3000, 0))
	assert_false(mm.monster_visible_to_heroes(grount.global_position), "monster far outside Vlad's 250 px vision")
	assert_true(mm.monster_visible_to_heroes(Vector2(200, 0)), "inside vision")
	assert_false(mm.hero_visible_to_monster(vlad.global_position))
	assert_true(mm.hero_visible_to_monster(Vector2(3200, 0)))
	vlad.queue_free()
	grount.queue_free()
	mm.queue_free()


## The dots, the camera frame and the fog map are palette tokens (the sides'
## accents, the text colour, moss ground and the warm near-black fog), and the
## map's own frame is the HUD panel variation.
func test_colours_come_from_the_palette() -> void:
	var palette := UiPalette.get_default()
	var mm := (load(SCENE) as PackedScene).instantiate() as Minimap
	add_child(mm)
	assert_eq(mm._hero_color, palette.hero)
	assert_eq(mm._monster_color, palette.monster)
	var pet := palette.hero_light
	pet.a = Minimap.PET_ALPHA
	assert_eq(mm._pet_color, pet)
	var frame := palette.text
	frame.a = Minimap.CAMERA_FRAME_ALPHA
	assert_eq(mm._camera_frame_color, frame)
	var fog := mm.fog_view.material as ShaderMaterial
	var explored := palette.moss
	explored.a = Minimap.FOG_ALPHA
	var unexplored := palette.bg_void
	unexplored.a = Minimap.FOG_ALPHA
	assert_eq(fog.get_shader_parameter(&"explored_color"), explored, "explored ground")
	assert_eq(fog.get_shader_parameter(&"unexplored_color"), unexplored, "fog")
	assert_eq((mm.get_node(^"%Frame") as Control).theme_type_variation, &"HudPanel", "its own frame is the HUD panel")
	mm.queue_free()
