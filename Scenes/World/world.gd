extends Node2D

var exploration_controller: HeroExplorationController

func _ready():
	# Tell GameManager a fresh match has started. This resets per-match
	# state (kills, timer, end-flag) — critical because GameManager is an
	# autoload and its _ready only fires once per game launch, not per match.
	GameManager.start_new_match()
	_connect_to_game_manager()
	_setup_fog()
	_setup_player_vision()
	_setup_exploration_controller()


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
	print("🎉 HEROES VICTORY!")
	# TODO: Show victory screen

func _on_monster_won():
	print("💀 MONSTER VICTORY!")
	# TODO: Show defeat screen

func _on_match_ended(winner: String, time: float):
	print("🏆 Match ended - Winner: " + winner + " in " + str(round(time * 10) / 10.0) + "s")
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

	var vision_map = {
		"river": 300.0,
		"vlad": 250.0,
		"ted": 220.0,
		"irelia": 200.0
	}

	for hero in heroes:
		if not hero is Node2D:
			continue
		# Skip Ted's pet (also in Hero group but isn't a HeroBase).
		if not (hero is HeroBase):
			continue

		var vision = 200.0
		var hero_name = hero.name.to_lower()

		for key in vision_map:
			if key in hero_name:
				vision = vision_map[key]
				break
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

	for monster in monsters:
		if not (monster is MonsterBase):
			continue
		# Vision scales loosely with hunt-distance budget. 350 is a comfortable
		# hunting cone that still leaves the map feeling explore-able.
		FogOfWarHelper.add_vision_to_hero(monster, 350.0)

func _setup_exploration_controller():
	await get_tree().process_frame
	
	exploration_controller = HeroExplorationController.new()
	exploration_controller.name = "HeroExplorationController"
	exploration_controller.group_exploration_enabled = true
	exploration_controller.group_cohesion_radius = 150.0
	exploration_controller.exploration_update_interval = 2.0
	exploration_controller.exploration_tile_size = 32
	
	add_child(exploration_controller)
	
	# Connect signals
	exploration_controller.exploration_target_reached.connect(_on_exploration_target_reached)
	exploration_controller.monster_detected.connect(_on_monster_detected)
	
	print("Exploration controller initialized")

func _on_exploration_target_reached(position: Vector2) -> void:
	pass

func _on_monster_detected(monster: Node2D) -> void:
	pass

# ============================================
# DEBUG FUNCTIONS (Optional - Press F1 to test)
# ============================================

func _input(event):
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
	print("=== DEBUG: GameManager Check ===")
	print("✓ GameManager (autoload): " + str(GameManager))
	print("  Heroes alive: " + str(GameManager.heroes_alive))
	print("  Monster alive: " + str(GameManager.monster_alive))
	
	# Check entities
	var heroes = get_tree().get_nodes_in_group("Hero")
	var monsters = get_tree().get_nodes_in_group("Monster")
	print("  Heroes in scene: " + str(heroes.size()))
	print("  Monsters in scene: " + str(monsters.size()))
	
	# Check if entities have the signal
	for hero in heroes:
		if hero.has_signal("died"):
			print("  ✓ " + hero.name + " has 'died' signal")
		else:
			print("  ✗ " + hero.name + " MISSING 'died' signal!")
	
	for monster in monsters:
		if monster.has_signal("died"):
			print("  ✓ " + monster.name + " has 'died' signal")
		else:
			print("  ✗ " + monster.name + " MISSING 'died' signal!")

func _debug_kill_heroes():
	print("DEBUG: Killing all heroes")
	var heroes = get_tree().get_nodes_in_group("Hero")
	for hero in heroes:
		EventBus.deal_damage(null, hero, 999999.0, null, DamagePacket.DamageType.TRUE)

func _debug_kill_monster():
	print("DEBUG: Killing monster")
	var monsters = get_tree().get_nodes_in_group("Monster")
	for monster in monsters:
		EventBus.deal_damage(null, monster, 999999.0, null, DamagePacket.DamageType.TRUE)
