extends Node2D

var exploration_controller: HeroExplorationController

func _ready():
	_setup_fog()
	_setup_hero_vision()
	_setup_exploration_controller()
	
func _setup_fog():
	var fog = preload("res://Scenes/World/FogOfWar/FogOfWarSystem.tscn").instantiate()
	fog.name = "FogOfWar"
	fog.world_size = Vector2(7500, 6000)
	fog.world_offset = Vector2(0, 0)
	fog.tile_size = 32
	fog.fog_color = Color(0, 0, 0, 0.85)
	
	add_child(fog)

func _setup_hero_vision():
	await get_tree().process_frame
	
	var heroes = get_tree().get_nodes_in_group("Hero")
	print("Found ", heroes.size(), " heroes")
	
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
		
		var vision = 200.0
		var hero_name = hero.name.to_lower()
		
		for key in vision_map:
			if key in hero_name:
				vision = vision_map[key]
				break
		FogOfWarHelper.add_vision_to_hero(hero, vision)

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
