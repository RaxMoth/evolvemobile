extends TestCase

## Fog grid alignment and the hero panel's cooldown source of truth.

const FOG := "res://Scenes/World/FogOfWar/FogOfWarSystem.tscn"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"


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
	var vlad := await spawn_entity(VLAD, Vector2.ZERO)
	TickScheduler.unregister(vlad)
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
