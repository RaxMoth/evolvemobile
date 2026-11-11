extends TestCase

## Fog grid alignment, the hero cooldown source of truth, and the match's
## minimap inside the MatchHud's frame (both play modes).

const FOG := "res://Scenes/World/FogOfWar/FogOfWarSystem.tscn"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const WORLD := "res://Scenes/World/World.tscn"
const VISION := "res://Scenes/World/FogOfWar/VisionArea.tscn"
## The minimap's place under MainCam: the MatchHud's copper frame.
const MINIMAP_PATH := ^"MainCam/MatchHud/Root/MinimapFrame/MinimapSlot/Minimap"
## README hero vision ranges (HeroStats.vision_radius), by World.tscn node name.
const HERO_VISION := {"River": 300.0, "Vlad": 250.0, "Ted": 220.0, "Irelia": 200.0}


func test_fog_world_snaps_to_whole_tiles_and_covers_border() -> void:
	var fog := (load(FOG) as PackedScene).instantiate() as FogOfWarSystem
	fog.world_size = Vector2(7500, 6000)
	fog.tile_size = 32
	add_child(fog)
	assert_eq(fog.grid_width, 235)
	assert_eq(fog.grid_height, 188)
	assert_eq(fog.world_size, Vector2(7520, 6016), "texture covers exactly the snapped world")
	var border := Vector2(fog.fog_border, fog.fog_border)
	assert_eq(fog.fog_sprite.position, fog.world_offset - border, "static quad starts past the world edge")
	assert_eq(fog.fog_sprite.scale, fog.world_size + border * 2.0)
	fog.reveal_area(Vector2(-10, 50), 8.0)
	assert_false(fog.is_tile_explored(Vector2(5, 50)), "a point left of the map does not reveal column 0")
	fog.reveal_area(Vector2(5, 50), 40.0)
	assert_true(fog.is_tile_explored(Vector2(5, 50)))
	fog.queue_free()


func test_cooldown_progress_follows_the_real_cooldown() -> void:
	var vlad := await spawn_frozen(VLAD, Vector2.ZERO)
	var asys := vlad.get_node("AbilitySystem") as AbilitySystem
	var active := AbilityBase.AbilityType.ACTIVE
	assert_eq(asys.get_cooldown_progress(active), 1.0, "ready before any cast")
	assert_true(asys.use_active(null), "mine cast")
	var total: float = asys.active_ability.cooldown
	assert_near(asys.get_cooldown_progress(active), 0.0, 0.02, "empty right after the cast")
	asys.cooldowns[active] = total * 0.25
	assert_near(asys.get_cooldown_progress(active), 0.75, 0.001, "remaining / total, not a wall-clock timer")
	asys.cooldowns[active] = 0.0
	assert_eq(asys.get_cooldown_progress(active), 1.0)
	vlad.queue_free()


func test_ai_reveals_feed_memory_without_clearing_the_players_fog() -> void:
	var fog := (load(FOG) as PackedScene).instantiate() as FogOfWarSystem
	fog.world_size = Vector2(3200, 3200)
	add_child(fog)
	fog.reveal_area(Vector2(500, 500), 64.0, false)
	assert_true(fog.is_tile_explored(Vector2(500, 500)), "the AI remembers what it explored")
	assert_true(fog.exploration_image.get_pixel(15, 15).r < 0.5, "the player's fog stays closed")
	assert_false(fog.is_revealed(Vector2(500, 500)), "is_revealed reads the player's fog, not the AI's memory")
	fog.reveal_area(Vector2(1500, 1500), 64.0)
	assert_true(fog.exploration_image.get_pixel(46, 46).r > 0.5, "player vision clears the fog")
	assert_true(fog.is_revealed(Vector2(1500, 1500)), "revealed to the player")
	assert_false(fog.is_revealed(Vector2(-40, 1500)), "outside the map is always fogged")
	assert_false(fog.is_revealed(Vector2(1500, 3300)), "below the map too")
	fog.queue_free()


func test_hero_vision_radius_comes_from_hero_stats() -> void:
	# In both play modes: the radius is applied by HeroBase from HeroStats,
	# overriding the VisionArea.tscn default (100).
	for path in [VLAD, "res://Scenes/NPCs/Hero/Heros/Healer/River/River.tscn"]:
		var hero := await spawn_frozen(path, Vector2.ZERO)
		var want: float = (hero.get_node("HeroStats") as HeroStatsComponent).base_stats.vision_radius
		var vision := hero.get_node("VisionArea") as VisionArea
		assert_near(vision.vision_radius, want, 0.01, "%s sees its HeroStats radius" % hero.name)
		var again := FogOfWarHelper.add_vision_to_hero(hero, 333.0)
		assert_true(again == vision, "the helper reuses the scene VisionArea")
		assert_near(vision.vision_radius, 333.0, 0.01, "and applies the requested radius")
		hero.queue_free()


func test_world_hero_vision_radii_in_both_play_modes() -> void:
	# HeroBase._ready is the only writer of a hero's radius. World adds no hero
	# vision; monster-side play gives the monster a VisionArea of World's
	# monster_vision_radius and keeps the AI heroes off the player's fog.
	var side_before: int = GameManager.chosen_side
	for side: int in [MatchRewards.Side.HEROES, MatchRewards.Side.MONSTER]:
		var monster_side := side == MatchRewards.Side.MONSTER
		var mode := "monster side" if monster_side else "hero side"
		GameManager.chosen_side = side
		var world := (load(WORLD) as PackedScene).instantiate()
		add_child(world)
		await wait_frames(2)
		for hero_name: String in HERO_VISION:
			var vision := world.get_node("Heros/%s/VisionArea" % hero_name) as VisionArea
			assert_near(vision.vision_radius, float(HERO_VISION[hero_name]), 0.01, "%s, %s" % [hero_name, mode])
		_check_minimap(world, mode)
		var grount := (world.get_node("MonsterSlot") as MonsterSlot).monster
		if monster_side:
			# The monster gets its vision once it stands at its match spawn.
			for i in range(240):
				if grount.has_node(^"VisionArea"):
					break
				await wait_physics_frames(1)
			var monster_vision := grount.get_node_or_null(^"VisionArea") as VisionArea
			assert_true(monster_vision != null, "the monster player has vision")
			if monster_vision:
				assert_near(monster_vision.vision_radius, 350.0, 0.01, "World.monster_vision_radius")
				assert_false(monster_vision.feeds_ai_memory, "not the hero AI's memory")
		else:
			assert_false(grount.has_node(^"VisionArea"), "the AI monster carries no vision")
		for hero_name: String in HERO_VISION:
			var vision := world.get_node("Heros/%s/VisionArea" % hero_name) as VisionArea
			assert_near(vision.vision_radius, float(HERO_VISION[hero_name]), 0.01, "%s still, %s" % [hero_name, mode])
			assert_eq(vision.reveals_display, not monster_side, "%s clears the player's fog only on the hero side" % hero_name)
		world.queue_free()
		await wait_frames(2)
	GameManager.chosen_side = side_before
	GameManager.match_ended_flag = true  # the runner's guard; World's start_new_match cleared it
	AudioManager.stop_music()  # World started the match music


## Monster-side play: the heroes' vision never clears the player's fog, not
## even with its first reveal. World used to switch it off only once the
## monster stood at its spawn (up to 3 s in), so the heroes' spawn showed on the
## monster player's map and minimap from the first frame.
func test_heroes_never_reveal_the_monster_players_fog() -> void:
	play_side(1)
	var world := (load(WORLD) as PackedScene).instantiate()
	add_child(world)
	for hero_name: String in HERO_VISION:
		var vision := world.get_node("Heros/%s/VisionArea" % hero_name) as VisionArea
		assert_false(vision.reveals_display, "%s: off before its first reveal" % hero_name)
	var fog := world.get_node("FogOfWar") as FogOfWarSystem
	await wait_frames(3)  # every VisionArea has revealed once
	for hero_name: String in HERO_VISION:
		var hero := world.get_node("Heros/%s" % hero_name) as Node2D
		assert_false(fog.is_revealed(hero.global_position), "%s's spawn stays fogged for the monster player" % hero_name)
		assert_true(fog.is_tile_explored(hero.global_position), "%s: the hero AI's own memory fills" % hero_name)
	world.queue_free()
	await wait_frames(2)
	GameManager.match_ended_flag = true  # the runner's guard; World's start_new_match cleared it
	AudioManager.stop_music()  # World started the match music


## The Minimap lives in the MatchHud's frame (no MainCam CanvasLayer, no FPS
## label: F3 has the frame timings), fills its slot with its own frame hidden,
## shows the fog, and a tap on it reaches MatchHud.select_hero.
func _check_minimap(world: Node, mode: String) -> void:
	var cam := world.get_node("MainCam") as GameCamera
	assert_true(cam.get_node_or_null(^"CanvasLayer") == null, "MainCam has no old HUD layer, %s" % mode)
	var mm := world.get_node_or_null(MINIMAP_PATH) as Minimap
	assert_true(mm != null, "the minimap sits in the HUD frame, %s" % mode)
	if mm == null:
		return
	assert_false((mm.get_node(^"%Frame") as CanvasItem).visible, "its own frame is hidden, %s" % mode)
	var slot := mm.get_parent() as Control
	assert_eq(slot.size, Vector2(156, 124), "the frame's slot, %s" % mode)
	assert_eq(mm.size, slot.size, "the map fills the slot, %s" % mode)
	assert_true(mm.fog_view.texture != null, "the fog is bound, %s" % mode)
	assert_true(mm.hero_picked.is_connected(cam.hud.select_hero), "a tap focuses through the HUD, %s" % mode)


func test_monster_player_vision_does_not_feed_the_hero_ai_memory() -> void:
	var fog := (load(FOG) as PackedScene).instantiate() as FogOfWarSystem
	fog.world_size = Vector2(3200, 3200)
	add_child(fog)
	fog.reveal_area(Vector2(800, 800), 64.0, true, false)
	assert_true(fog.exploration_image.get_pixel(25, 25).r > 0.5, "the monster player sees it")
	assert_false(fog.is_tile_explored(Vector2(800, 800)), "the hero AI did not explore it")
	fog.queue_free()


func test_vision_skips_reveals_while_it_stays_in_its_tile() -> void:
	# A source that has not left its 32 px fog tile (a hero in a fight, a
	# resting monster) would reveal the same tiles again, which writes nothing.
	await wait_frames(1)  # the fogs earlier tests freed have left the tree
	var fog := (load(FOG) as PackedScene).instantiate() as FogOfWarSystem
	fog.world_size = Vector2(3200, 3200)
	add_child(fog)
	assert_true(EntityRegistry.singleton(&"FogOfWar") == fog, "the vision finds this fog")
	var vision := (load(VISION) as PackedScene).instantiate() as VisionArea
	vision.vision_radius = 64.0
	add_child(vision)
	vision.set_process(false)  # the test drives every reveal
	var img := fog.exploration_image
	vision.global_position = Vector2(484, 484)  # tile (15, 15)
	vision._update_vision()
	assert_true(img.get_pixel(15, 15).r > 0.5, "the first reveal runs")
	# Canary: any reveal_area() call from tile (15, 15) on would clear it again.
	img.set_pixel(16, 15, Color.BLACK)
	var before := img.get_data()
	vision.global_position = Vector2(511, 510)  # still tile (15, 15)
	vision._update_vision()
	assert_true(img.get_pixel(16, 15).r < 0.5, "same tile: reveal_area not re-entered")
	assert_true(img.get_data() == before, "same tile: no pixel changed")
	vision.global_position = Vector2(516, 500)  # tile (16, 15)
	vision._update_vision()
	assert_true(img.get_pixel(16, 15).r > 0.5, "the next tile reveals")
	img.set_pixel(17, 15, Color.BLACK)
	vision.set_vision_radius(65.0)
	vision._update_vision()
	assert_true(img.get_pixel(17, 15).r > 0.5, "a new radius reveals again in the same tile")
	vision.reveals_display = false
	vision._update_vision()
	img.set_pixel(17, 15, Color.BLACK)
	vision.reveals_display = true
	vision._update_vision()
	assert_true(img.get_pixel(17, 15).r > 0.5, "a changed flag reveals again in the same tile")
	vision.queue_free()
	fog.queue_free()
