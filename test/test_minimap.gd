extends TestCase

## Minimap mapping + fairness rules, the picture's place under the dots and
## its scale (the whole world), and a rendered check of both (skipped by the
## headless runner, which draws nothing).

const SCENE := "res://Scenes/UI/Minimap/Minimap.tscn"
const FOG := "res://Scenes/World/FogOfWar/FogOfWarSystem.tscn"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"
## Largest channel difference a rendered pixel may have from its colour (the
## picture is drawn at FOG_ALPHA over the clear colour).
const PIXEL_EPS := 0.06


## The world maps onto map_rect(), the fog picture's rect (2 px inside the
## Control, the frame's border), and back.
func test_world_map_round_trip_and_clamping() -> void:
	var mm := (load(SCENE) as PackedScene).instantiate() as Minimap
	add_child(mm)
	mm.size = Vector2(160, 128)
	mm.set_world_bounds(Vector2(100, 200), Vector2(1000, 800))
	assert_eq(mm.map_rect(), Rect2(2, 2, 156, 124), "the picture's rect")
	assert_eq(mm.map_rect(), Rect2(mm.fog_view.position, mm.fog_view.size))
	assert_eq(mm.world_to_map(Vector2(100, 200)), Vector2(2, 2))
	assert_eq(mm.world_to_map(Vector2(1100, 1000)), Vector2(158, 126))
	assert_eq(mm.world_to_map(Vector2(600, 600)), Vector2(80, 64))
	assert_eq(mm.world_to_map(Vector2(-5000, -5000)), Vector2(2, 2), "clamped")
	assert_eq(mm.map_to_world(Vector2(80, 64)), Vector2(600, 600))
	assert_eq(mm.map_to_world(Vector2(2, 2)), Vector2(100, 200))
	assert_eq(mm.map_to_world(Vector2(160, 128)), Vector2(1100, 1000), "a tap on the border clamps")
	mm.queue_free()


## The parent draws the dots and the camera frame; a child normally draws over
## its parent, so the fog picture (95 % opaque) hid every dot. Frame and FogView
## draw behind the parent instead.
func test_dots_draw_above_the_fog_picture() -> void:
	var mm := (load(SCENE) as PackedScene).instantiate() as Minimap
	add_child(mm)
	assert_true(mm.fog_view.get_parent() == mm, "the picture is the minimap's child")
	assert_true(mm.fog_view.show_behind_parent, "the fog picture draws under the dots")
	assert_true((mm.get_node(^"%Frame") as CanvasItem).show_behind_parent, "so does the map's own frame")
	assert_true(mm.get_node(^"%Frame").get_index() < mm.fog_view.get_index(), "the frame under the picture")
	mm.queue_free()


## The exploration texture has one texel per 32 px fog tile (235 x 188 for the
## match's world): tiled 1:1 it showed only the top-left 152 x 120 tiles. It
## is scaled to the view, so the texel of a world point lies where
## world_to_map() puts that point.
func test_fog_picture_covers_the_whole_world() -> void:
	var fog := (load(FOG) as PackedScene).instantiate() as FogOfWarSystem
	fog.world_size = Vector2(7500, 6000)
	add_child(fog)
	var mm := (load(SCENE) as PackedScene).instantiate() as Minimap
	add_child(mm)
	assert_true(mm.fog_view.texture == fog.exploration_texture, "the fog's texture is bound")
	assert_eq(mm.fog_view.stretch_mode, TextureRect.STRETCH_SCALE, "scaled to the view, not tiled")
	assert_eq(mm.fog_view.expand_mode, TextureRect.EXPAND_IGNORE_SIZE, "whatever the texture's size")
	var rect := mm.map_rect()
	var grid := Vector2(fog.grid_width, fog.grid_height)
	var texel := rect.size / grid  # one fog tile on the map
	for world_pos: Vector2 in [Vector2(16, 16), Vector2(3000, 2500), Vector2(4900, 3900), Vector2(7500, 6000)]:
		var cell := fog.grid_cell(world_pos)
		var drawn := Rect2(rect.position + Vector2(cell) * texel, texel)  # where STRETCH_SCALE draws that texel
		assert_true(drawn.grow(0.01).has_point(mm.world_to_map(world_pos)),
			"world %s: its fog tile is drawn at %s, the dot at %s" % [world_pos, drawn, mm.world_to_map(world_pos)])
	mm.queue_free()
	fog.queue_free()
	await wait_frames(1)


## Rendered: the pixel at a hero's map position is the hero dot's colour (not
## the fog picture's), a reveal lights the pixel world_to_map() returns for it,
## also in the far corner of the world, and unexplored ground stays dark.
func test_rendered_dot_and_reveal_land_on_their_map_pixels() -> void:
	if DisplayServer.get_name() == "headless":
		skip("needs a renderer: run test_minimap.gd in a window (muted)")
		return
	play_side(0)  # heroes: their own dots always show
	var palette := UiPalette.get_default()
	var fog := (load(FOG) as PackedScene).instantiate() as FogOfWarSystem
	fog.world_size = Vector2(7500, 6000)
	fog.visible = false  # only the minimap's picture matters here
	add_child(fog)
	var layer := CanvasLayer.new()
	add_child(layer)
	var mm := (load(SCENE) as PackedScene).instantiate() as Minimap
	layer.add_child(mm)
	mm.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	mm.position = Vector2(40, 40)
	# Off screen in world space; inside the picture on the map.
	var hero := await spawn_frozen(VLAD, Vector2(3000, 2500))
	var near_hero := Vector2(3000, 2200)   # revealed with the hero's surroundings
	var far_corner := Vector2(7000, 5600)  # past the 4864 x 3840 px the tiled picture ended at
	var unexplored := Vector2(5000, 800)
	fog.reveal_area(hero.global_position, 400.0)
	fog.reveal_area(far_corner, 200.0)
	await wait_frames(3)  # the fog uploads its texture, the map redraws
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var explored_color := palette.color(mm.explored_token)
	var fog_color := palette.color(mm.unexplored_token)
	_assert_pixel(img, mm, hero.global_position, palette.color(mm.hero_token), "the hero's dot")
	_assert_pixel(img, mm, near_hero, explored_color, "explored ground next to the hero")
	_assert_pixel(img, mm, far_corner, explored_color, "a reveal in the far corner of the world")
	_assert_pixel(img, mm, unexplored, fog_color, "unexplored ground")
	hero.queue_free()
	layer.queue_free()
	fog.queue_free()
	await wait_frames(1)


func _assert_pixel(img: Image, mm: Minimap, world_pos: Vector2, want: Color, what: String) -> void:
	var at := Vector2i((mm.global_position + mm.world_to_map(world_pos)).floor())
	var got := img.get_pixel(at.x, at.y)
	var off := maxf(absf(got.r - want.r), maxf(absf(got.g - want.g), absf(got.b - want.b)))
	assert_true(off <= PIXEL_EPS, "%s: pixel %s is #%s, expected #%s" % [what, at, got.to_html(false), want.to_html(false)])


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
