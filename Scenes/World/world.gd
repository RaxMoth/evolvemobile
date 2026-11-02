extends Node2D

@export_group("Monster Spawn")
## README "Monster spawns weak (Stage 1) in Zone 3, random in zone": the
## monster is moved to a random reachable point of this rectangle when the
## match starts. Off = it stays where World.tscn places it.
@export var randomize_monster_spawn: bool = true
@export var monster_spawn_zone: Rect2 = Rect2(3500, 300, 2000, 4800)

var exploration_controller: HeroExplorationController
## Emitted once the monster stands at its match spawn (or placement gave up).
signal monster_placed
var _monster_placed: bool = false

func _ready():
	# Tell GameManager a fresh match has started. This resets per-match
	# state (kills, timer, end-flag) — critical because GameManager is an
	# autoload and its _ready only fires once per game launch, not per match.
	GameManager.start_new_match()
	AudioManager.play_music(&"match")
	_connect_to_game_manager()
	_setup_fog()
	_setup_player_vision()
	_setup_exploration_controller()
	_monster_placed = not randomize_monster_spawn
	if randomize_monster_spawn:
		_place_monster()


## The scene placed Grount at (1715, 309), inside the heroes' own spawn zone:
## heroes met the stage-1 monster after ~50 s in half the simulated matches.
func _place_monster() -> void:
	# A region's polygons reach the navigation map one sync after the region
	# itself (queries return the origin until then). The per-tile map takes
	# ~1 s to become queryable, so retry for up to 3 s.
	for i in range(180):
		await get_tree().physics_frame
		var monster := EntityRegistry.first_monster() as MonsterBase
		if monster == null or not monster.is_alive():
			_finish_monster_placement()
			return
		var from: Vector2 = EntityRegistry.heroes[0].global_position if not EntityRegistry.heroes.is_empty() else global_position
		var spot: Vector2 = GameUtils.random_reachable_point(get_world_2d(), monster_spawn_zone, from, Vector2.INF)
		if spot.is_finite():
			monster.teleport_to(spot)
			_finish_monster_placement()
			return
	push_warning("Monster spawn: no reachable point in %s; keeping the scene position" % str(monster_spawn_zone))
	_finish_monster_placement()


func _finish_monster_placement() -> void:
	_monster_placed = true
	monster_placed.emit()


func _exit_tree() -> void:
	# Leaving the World without a decided match (e.g. a scene change): stop the
	# match clock. "Play Again" re-enters and calls start_new_match() again.
	GameManager.abort_match()


func _setup_player_vision():
	## Vision = which entity reveals the fog of war as it moves. Whoever
	## the player is controlling sees through their avatar's eyes. The
	## OTHER side stays AI-controlled but doesn't carry vision components,
	## so they appear fogged-out to the player when out of sight.
	if GameManager.chosen_side == MatchRewards.Side.MONSTER:
		_setup_monster_vision()
	else:
		_setup_hero_vision()

func _connect_to_game_manager():
	GameManager.heroes_won.connect(_on_heroes_won)
	GameManager.monster_won.connect(_on_monster_won)
	GameManager.match_ended.connect(_on_match_ended)

func _on_heroes_won():
	Globals.debug_log("🎉 HEROES VICTORY!")
	# TODO: Show victory screen

func _on_monster_won():
	Globals.debug_log("💀 MONSTER VICTORY!")
	# TODO: Show defeat screen

func _on_match_ended(winner: String, time: float):
	Globals.debug_log("🏆 Match ended - Winner: " + winner + " in " + str(round(time * 10) / 10.0) + "s")
	# TODO: Display stats, transition to menu, etc.

func _setup_fog():
	# Explicit type so the parser knows the script's exported properties
	# (the .tscn root is a Node2D, the class_name is on the attached script).
	var fog: FogOfWarSystem = preload("res://Scenes/World/FogOfWar/FogOfWarSystem.tscn").instantiate()
	fog.name = "FogOfWar"
	fog.world_size = Vector2(7500, 6000)
	fog.world_offset = Vector2(0, 0)
	fog.tile_size = 32
	fog.fog_color = Color(0, 0, 0, 0.85)

	add_child(fog)

func _setup_hero_vision():
	## Hero-side: each hero gets their own VisionArea so the team's combined
	## vision drives fog reveal. River sees furthest (scout), Irelia closest.
	await get_tree().process_frame

	var heroes = get_tree().get_nodes_in_group("Hero")
	if heroes.is_empty():
		push_warning("No heroes found! Make sure heroes are in 'Hero' group")
		return

	for hero in heroes:
		# Skip Ted's pet (also in Hero group but isn't a HeroBase).
		if not (hero is HeroBase):
			continue
		# Per-hero reveal radius lives on the HeroStats resource (River sees
		# furthest as the scout, Irelia closest) — no name matching.
		var stats := hero.get_node_or_null("HeroStats") as HeroStatsComponent
		var vision: float = stats.base_stats.vision_radius if stats and stats.base_stats else 200.0
		FogOfWarHelper.add_vision_to_hero(hero, vision)


func _setup_monster_vision():
	## Monster-side: the monster IS the player's avatar — fog reveals
	## around it. Heroes are now the unseen AI threats; the player only
	## spots them when they wander into the monster's vision cone.
	## Wider radius than any single hero (the monster is the apex predator).
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
		# Vision scales loosely with hunt-distance budget. 350 is a comfortable
		# hunting cone that still leaves the map feeling explore-able.
		var monster_vision := FogOfWarHelper.add_vision_to_hero(monster, 350.0)
		if monster_vision:
			monster_vision.feeds_ai_memory = false

	# The AI heroes keep their scene VisionArea (it is their exploration
	# memory) but must not clear the monster player's fog: that leaked their
	# whole path onto the map and the minimap.
	for hero in get_tree().get_nodes_in_group("Hero"):
		var hero_vision := hero.get_node_or_null(^"VisionArea") as VisionArea
		if hero_vision:
			hero_vision.reveals_display = false

const HERO_EXPL_CTRL_SCENE: PackedScene = preload("res://Scenes/NPCs/Hero/HeroExplorationController.tscn")

func _setup_exploration_controller():
	await get_tree().process_frame
	# Scene-based instantiation: defaults (cohesion radius, update interval,
	# tile size, group registration) live in HeroExplorationController.tscn
	# — no per-property setup needed here. Override anything per-world in
	# this scene's instance if you ever want different defaults per map.
	exploration_controller = HERO_EXPL_CTRL_SCENE.instantiate() as HeroExplorationController
	add_child(exploration_controller)
	exploration_controller.exploration_target_reached.connect(_on_exploration_target_reached)
	exploration_controller.monster_detected.connect(_on_monster_detected)

func _on_exploration_target_reached(position: Vector2) -> void:
	pass

func _on_monster_detected(monster: Node2D) -> void:
	pass

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
