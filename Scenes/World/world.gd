extends Node2D

@export_group("Monster Spawn")
## README "Monster spawns weak (Stage 1) in Zone 3, random in zone": the
## monster is moved to a random reachable point of this rectangle when the
## match starts. Off = it stays where World.tscn places it.
@export var randomize_monster_spawn: bool = true
@export var monster_spawn_zone: Rect2 = Rect2(3500, 300, 2000, 4800)
## The longest the match start waits for the navigation map to answer, in real
## seconds. With the shipped asynchronous map and region iterations the map
## answers about 10 to 15 physics frames after World enters (0.2 to 0.3 s on a
## desktop at 60 fps, also under CPU load and on fast); if it never does, the
## monster keeps MonsterSlot's spawn (inside the zone) and the match goes on.
@export var nav_wait_limit_sec: float = 10.0

@export_group("Vision")
## Monster-side play: reveal radius of the monster player's VisionArea, wider
## than any hero's (the minimap's fairness rule reads it from that VisionArea).
## Hero radii come from HeroStats (applied by HeroBase._ready).
@export var monster_vision_radius: float = 350.0

var exploration_controller: HeroExplorationController
## Emitted once the monster stands at its match spawn (or placement gave up).
signal monster_placed
## The monster placement's wait is over: this world's navigation map synced
## (map_changed) or nav_wait_limit_sec ran out.
signal _nav_wait_over
var _monster_placed: bool = false
## nav_wait_limit_sec ran out before the monster was placed.
var _nav_wait_expired: bool = false
## Placement tries on a map that answers (each samples up to 32 points of the
## zone) before the monster keeps MonsterSlot's spawn.
const PLACEMENT_TRIES: int = 180

func _ready():
	# Tell GameManager a fresh match has started. This resets per-match
	# state (kills, timer, end-flag) — critical because GameManager is an
	# autoload and its _ready only fires once per game launch, not per match.
	GameManager.start_new_match()
	AudioManager.play_music(&"match")
	_setup_fog()
	_setup_player_vision()
	_setup_exploration_controller()
	_monster_placed = not randomize_monster_spawn
	if randomize_monster_spawn:
		_place_monster()


## The scene placed Grount at (1715, 309), inside the heroes' own spawn zone:
## heroes met the stage-1 monster after ~50 s in half the simulated matches.
## The start waits for the navigation map, not a number of frames: until the
## map answers (GameUtils.nav_map_answers) there is nothing to sample, so each
## miss waits for this world's next map sync (NavigationServer2D.map_changed),
## then tries on the physics frame after it. An unthrottled headless run with
## the asynchronous iterations on passes about 95 physics frames in that wait,
## a 60 fps window about 10 to 15. A map that never answers within
## nav_wait_limit_sec leaves the monster on MonsterSlot's spawn.
func _place_monster() -> void:
	var world := get_world_2d()
	# Real seconds (process_always, ignore_time_scale): neither the match
	# speed nor a pause stretches the limit.
	get_tree().create_timer(nav_wait_limit_sec, true, false, true).timeout.connect(_on_nav_wait_limit)
	NavigationServer2D.map_changed.connect(_on_nav_map_changed)
	var tries := 0
	while tries < PLACEMENT_TRIES:
		await get_tree().physics_frame
		var monster := EntityRegistry.first_monster() as MonsterBase
		if monster == null or not monster.is_alive():
			_finish_monster_placement()
			return
		var from: Vector2 = EntityRegistry.heroes[0].global_position if not EntityRegistry.heroes.is_empty() else global_position
		if not GameUtils.nav_map_answers(world, from):
			if _nav_wait_expired:
				break
			# Nothing to sample yet: wait for the map's next sync or the limit.
			await _nav_wait_over
			continue
		tries += 1
		var spot: Vector2 = GameUtils.random_reachable_point(world, monster_spawn_zone, from, Vector2.INF)
		if spot.is_finite():
			monster.teleport_to(spot)
			_finish_monster_placement()
			return
	push_warning("Monster spawn: %s; keeping the scene position" % (
		"the navigation map did not answer in %.0f s" % nav_wait_limit_sec if _nav_wait_expired
		else "no reachable point in %s" % str(monster_spawn_zone)))
	_finish_monster_placement()


## A sync of this world's navigation map ends the placement's wait.
func _on_nav_map_changed(map: RID) -> void:
	if map == get_world_2d().navigation_map:
		_nav_wait_over.emit()


## nav_wait_limit_sec is over: a placement still waiting for the map gives up.
func _on_nav_wait_limit() -> void:
	_nav_wait_expired = true
	_nav_wait_over.emit()


func _finish_monster_placement() -> void:
	if NavigationServer2D.map_changed.is_connected(_on_nav_map_changed):
		NavigationServer2D.map_changed.disconnect(_on_nav_map_changed)
	_monster_placed = true
	monster_placed.emit()


func _exit_tree() -> void:
	# Leaving the World without a decided match (e.g. a scene change): stop the
	# match clock. "Play Again" re-enters and calls start_new_match() again.
	GameManager.abort_match()


func _setup_player_vision():
	## Vision = which entity reveals the fog of war as it moves. Whoever
	## the player is controlling sees through their avatar's eyes. Every hero
	## carries a scene VisionArea sized from HeroStats by HeroBase._ready
	## (it is also the hero AI's exploration memory), so hero-side play needs
	## nothing here; monster-side play gives the monster one and stops the
	## AI heroes' vision from clearing the player's fog.
	if GameManager.chosen_side == MatchRewards.Side.MONSTER:
		_keep_hero_vision_off_the_players_fog()
		_setup_monster_vision()


## Monster-side play: the AI heroes keep their scene VisionArea (it is their
## exploration memory) but must not clear the monster player's fog: that leaked
## their whole path onto the map and the minimap. Called from _ready, before
## any VisionArea has processed a frame: waiting for the monster's placement
## first let every hero's first reveal draw their spawn onto the minimap.
func _keep_hero_vision_off_the_players_fog() -> void:
	for hero in get_tree().get_nodes_in_group("Hero"):
		var hero_vision := hero.get_node_or_null(^"VisionArea") as VisionArea
		if hero_vision:
			hero_vision.reveals_display = false

func _setup_fog():
	# Explicit type so the parser knows the script's exported properties
	# (the .tscn root is a Node2D, the class_name is on the attached script).
	var fog: FogOfWarSystem = preload("res://Scenes/World/FogOfWar/FogOfWarSystem.tscn").instantiate()
	fog.name = "FogOfWar"
	fog.world_size = Vector2(7500, 6000)
	fog.world_offset = Vector2(0, 0)
	fog.tile_size = 32

	add_child(fog)

func _setup_monster_vision():
	## Monster-side: the monster IS the player's avatar — fog reveals
	## around it. Heroes are now the unseen AI threats; the player only
	## spots them when they wander into the monster's vision cone.
	## Wider radius than any single hero (monster_vision_radius).
	await get_tree().process_frame

	var monsters = get_tree().get_nodes_in_group("Monster")
	if monsters.is_empty():
		push_warning("Monster-side play but no monster found in 'Monster' group!")
		return

	# Vision only once the monster stands at its match spawn: revealing at the
	# scene position first left a cleared circle where it never was.
	if not _monster_placed:
		await monster_placed
	for monster in monsters:
		if not (monster is MonsterBase) or not is_instance_valid(monster):
			continue
		var monster_vision := FogOfWarHelper.add_vision_to_hero(monster, monster_vision_radius)
		if monster_vision:
			monster_vision.feeds_ai_memory = false

const HERO_EXPL_CTRL_SCENE: PackedScene = preload("res://Scenes/NPCs/Hero/HeroExplorationController.tscn")

func _setup_exploration_controller():
	await get_tree().process_frame
	# Scene-based instantiation: defaults (cohesion radius, update interval,
	# tile size, group registration) live in HeroExplorationController.tscn
	# — no per-property setup needed here. Override anything per-world in
	# this scene's instance if you ever want different defaults per map.
	exploration_controller = HERO_EXPL_CTRL_SCENE.instantiate() as HeroExplorationController
	add_child(exploration_controller)

# ============================================
# DEBUG FUNCTIONS (Optional - Press F1 to test)
# ============================================

func _input(event: InputEvent) -> void:
	# Debug kill/inspect keys never ship to players.
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed:
		# Press F1 for debug info
		if event.keycode == KEY_F1:
			_debug_game_manager()
		# Press K to kill all heroes
		elif event.keycode == KEY_K:
			_debug_kill_heroes()
		# Press M to kill monster
		elif event.keycode == KEY_M:
			_debug_kill_monster()

func _debug_game_manager():
	Globals.debug_log("=== DEBUG: GameManager Check ===")
	Globals.debug_log("✓ GameManager (autoload): " + str(GameManager))
	Globals.debug_log("  Heroes alive: " + str(GameManager.heroes_alive))
	Globals.debug_log("  Monster alive: " + str(GameManager.monster_alive))
	
	# Check entities
	var heroes = get_tree().get_nodes_in_group("Hero")
	var monsters = get_tree().get_nodes_in_group("Monster")
	Globals.debug_log("  Heroes in scene: " + str(heroes.size()))
	Globals.debug_log("  Monsters in scene: " + str(monsters.size()))
	
	# Check if entities have the signal
	for hero in heroes:
		if hero.has_signal("died"):
			Globals.debug_log("  ✓ " + hero.name + " has 'died' signal")
		else:
			Globals.debug_log("  ✗ " + hero.name + " MISSING 'died' signal!")
	
	for monster in monsters:
		if monster.has_signal("died"):
			Globals.debug_log("  ✓ " + monster.name + " has 'died' signal")
		else:
			Globals.debug_log("  ✗ " + monster.name + " MISSING 'died' signal!")

func _debug_kill_heroes():
	Globals.debug_log("DEBUG: Killing all heroes")
	var heroes = get_tree().get_nodes_in_group("Hero")
	for hero in heroes:
		EventBus.deal_damage(null, hero, 999999.0, null, DamagePacket.DamageType.TRUE)

func _debug_kill_monster():
	Globals.debug_log("DEBUG: Killing monster")
	var monsters = get_tree().get_nodes_in_group("Monster")
	for monster in monsters:
		EventBus.deal_damage(null, monster, 999999.0, null, DamagePacket.DamageType.TRUE)
