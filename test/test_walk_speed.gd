extends TestCase

## Faster rounds (batch P1, README "Match Speed"): every character walks
## WALK_FACTOR (x1.2) as fast as before P1, heroes, monsters, mobs and Ted's
## fox alike, so the ratios between them stay. The numbers live in the data
## (HeroStats, MonsterStats, the mob scenes, TedsPet), not in a hidden
## multiplier; the percent effects (Enrage, Rebirth's flight, Adaptive
## Movement, the tree nodes) multiply on top as before. Each rig's
## `full_speed` (walk blend 1.0) is its character's walk speed, so the usual
## walk swings the legs fully; the steps follow the distance walked
## (`stride`), so the feet do not slide at any speed.

const BAT := "res://Scenes/NPCs/Mob/Mobs/Bat/Bat.tscn"
const HOG := "res://Scenes/NPCs/Mob/Mobs/Hog/Hog.tscn"
const PET := "res://Scenes/NPCs/Hero/Heros/Support/Ted/Abilities/Passive/TedsPet.tscn"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const WALK_FACTOR := 1.2
## Before P1, px per game second. Heroes: base, per level, strafe. Monsters:
## stage 1, 2, 3.
const BEFORE := {
	&"irelia": [75.0, 1.0, 55.0],
	&"vlad": [80.0, 1.2, 75.0],
	&"ted": [85.0, 1.5, 50.0],
	&"river": [85.0, 1.5, 70.0],
	&"grount": [60.0, 80.0, 110.0],
	&"nyxa": [85.0, 105.0, 125.0],
	&"gorrak": [56.0, 64.0, 74.0],
}
## Mob scenes before P1: walk speed, strafe speed.
const BEFORE_MOBS := {BAT: [150.0, 40.0], HOG: [70.0, 40.0]}
const BEFORE_PET := 120.0


func before_each() -> void:
	if is_isolated():
		PersistedData.wipe_progress(false)


func after_each() -> void:
	if is_isolated():
		PersistedData.wipe_progress(false)


func _roster() -> Array[CharacterDef]:
	var defs: Array[CharacterDef] = []
	defs.append_array(GameManager.ROSTER.heroes)
	defs.append_array(GameManager.ROSTER.monsters)
	return defs


## The speeds a character's data walks at, in BEFORE's order.
func _walk_numbers(def: CharacterDef) -> Array[float]:
	if def.is_monster():
		var m := def.stats as MonsterStats
		return [m.stage_1_speed, m.stage_2_speed, m.stage_3_speed]
	var h := def.stats as HeroStats
	return [h.base_move_speed, h.speed_per_level, h.strafe_speed]


## The walk speed its rig counts as a full walk: a hero's base speed, a
## monster's Stage 1 speed (the walk blend stays full at the faster stages).
func _walk_speed(def: CharacterDef) -> float:
	return _walk_numbers(def)[0]


## The RigProfile a scene gives its Rig node, read from the scene file (no
## instance: instancing an entity registers it and draws from the global RNG).
func _rig_profile_of(scene_path: String) -> RigProfile:
	var state := (load(scene_path) as PackedScene).get_state()
	for i in state.get_node_count():
		if state.get_node_name(i) != &"Rig":
			continue
		for p in state.get_node_property_count(i):
			if state.get_node_property_name(i, p) == &"profile":
				return state.get_node_property_value(i, p) as RigProfile
	return null


func _scene_value(scene_path: String, key: String) -> float:
	var node: Node = (load(scene_path) as PackedScene).instantiate()
	var value := float(node.get(key))
	node.free()
	return value


func test_every_walker_is_a_fifth_faster() -> void:
	var seen := 0
	for def in _roster():
		var id := def.character_id()
		assert_true(BEFORE.has(id), "%s: its speed before P1 is in the table" % id)
		if not BEFORE.has(id):
			continue
		seen += 1
		var before: Array = BEFORE[id]
		var now := _walk_numbers(def)
		for i in now.size():
			assert_near(now[i], float(before[i]) * WALK_FACTOR, 0.0001, "%s speed number %d" % [id, i])
	assert_eq(seen, BEFORE.size(), "every character of the table is on the roster")
	for path: String in BEFORE_MOBS:
		var before: Array = BEFORE_MOBS[path]
		assert_near(_scene_value(path, "base_move_speed"), float(before[0]) * WALK_FACTOR, 0.0001, path.get_file() + " walk")
		assert_near(_scene_value(path, "strafe_speed"), float(before[1]) * WALK_FACTOR, 0.0001, path.get_file() + " strafe")
	assert_near(_scene_value(PET, "move_speed"), BEFORE_PET * WALK_FACTOR, 0.0001, "Ted's fox")


func test_every_rig_walks_fully_at_its_walk_speed() -> void:
	for def in _roster():
		var id := def.character_id()
		var profile := _rig_profile_of(def.scene_path)
		assert_true(profile != null, "%s: the scene's rig has a motion profile" % id)
		if profile == null:
			continue
		assert_near(profile.full_speed, _walk_speed(def), 0.0001, "%s: full_speed is the walk speed" % id)
		assert_eq(def.rig_profile, profile, "%s: the menus' profile is the match's" % id)
	for path: String in [BAT, HOG]:
		var profile := _rig_profile_of(path)
		assert_near(profile.full_speed, _scene_value(path, "base_move_speed"), 0.0001, path.get_file() + ": full_speed")
	assert_near(_rig_profile_of(PET).full_speed, _scene_value(PET, "move_speed"), 0.0001, "the fox: full_speed")


## One game second of walking (60 steps of 1/60 s, as the sims step) takes a
## level 1 Vlad 96 px, 20 % more than the 80 before P1.
func test_a_hero_covers_a_fifth_more_ground_per_game_second() -> void:
	var region := await bake_nav_rect(Rect2(0, 0, 2000, 400))
	var vlad := await spawn_frozen(VLAD, Vector2(100, 200)) as EntityBase
	vlad.global_position = Vector2(100, 200)
	var speed: float = vlad.move_speed
	assert_near(speed, 80.0 * WALK_FACTOR, 0.0001, "Vlad at level 1 without an aura")
	for i in 60:
		vlad.move_toward_point(Vector2(1900, 200), speed, 1.0 / 60.0)
	assert_near(vlad.global_position.x - 100.0, 80.0 * WALK_FACTOR, 0.01, "one game second: 96 px (80 before)")
	# Along a navigation path the same: the step is speed x delta.
	vlad.global_position = Vector2(100, 300)
	vlad._set_nav_target(Vector2(1900, 300))
	await wait_physics_frames(2)
	for i in 60:
		vlad._steer_along_nav(speed, 1.0 / 60.0)
	assert_near(vlad.global_position.distance_to(Vector2(100, 300)), 80.0 * WALK_FACTOR, 1.0, "a path walk too")
	for n in [vlad, region]:
		n.queue_free()
	await wait_physics_frames(6)
