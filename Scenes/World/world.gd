extends Node2D

func _ready():
	_setup_fog()
	_setup_hero_vision()

func _setup_fog():
	var fog = preload("res://Scenes/World/FogOfWar/FogOfWarSystemOptimized.tscn").instantiate()
	fog.name = "FogOfWar"
	fog.world_size = Vector2(2000, 2000)
	fog.world_offset = Vector2(0, 0)
	fog.tile_size = 32
	fog.fog_color = Color(0, 0, 0, 0.85)
	fog.reveal_smoothness = 1.5

	add_child(fog)

func _setup_hero_vision():
	await get_tree().process_frame
	
	var heroes = get_tree().get_nodes_in_group("Hero")
	print("Found ", heroes.size(), " heroes")
	
	if heroes.is_empty():
		push_warning("No heroes found! Make sure heroes are in 'Hero' group")
		return

	var vision_map = {
		"river": 300.0,   # Scout - best vision
		"vlad": 250.0,    # DPS - good vision
		"ted": 220.0,     # Pet master
		"irelia": 200.0   # Tank - standard
	}
	
	for hero in heroes:
		if not hero is Node2D:
			continue
		
		# Determine vision radius
		var vision = 200.0  # default
		var hero_name = hero.name.to_lower()
		
		for key in vision_map:
			if key in hero_name:
				vision = vision_map[key]
				break
		
		# Add vision to hero
		FogOfWarHelper.add_vision_to_hero(hero, vision)
		print("  ✓ ", hero.name, " vision: ", vision)
