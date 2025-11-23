extends Node
class_name FogOfWarHelper

## Helper to add fog of war vision to heroes
## Each hero gets their own vision area with customizable radius

const VISION_SCENE = preload("res://Scenes/World/FogOfWar/VisionArea.tscn")

## Add vision to a specific hero with custom radius
static func add_vision_to_hero(hero: Node2D, vision_radius: float = 200.0) -> VisionArea:
	# Check if already has vision
	if hero.has_node("VisionArea"):
		print("Hero already has vision: ", hero.name)
		return hero.get_node("VisionArea")
	
	# Create and add vision area
	var vision = VISION_SCENE.instantiate()
	vision.name = "VisionArea"
	vision.vision_radius = vision_radius
	hero.add_child(vision)
	
	print("Added vision to hero: ", hero.name, " with radius: ", vision_radius)
	return vision

## Add vision to all heroes in scene (finds them automatically)
static func add_vision_to_all_heroes(vision_radius: float = 200.0) -> int:
	var tree = Engine.get_main_loop() as SceneTree
	if not tree:
		push_error("Could not get SceneTree")
		return 0
	
	var heroes = tree.get_nodes_in_group("Hero")
	var count = 0
	
	for hero in heroes:
		if hero is Node2D:
			add_vision_to_hero(hero, vision_radius)
			count += 1
	
	print("Added vision to ", count, " heroes")
	return count

## Remove vision from a hero
static func remove_vision_from_hero(hero: Node2D) -> void:
	if hero.has_node("VisionArea"):
		var vision = hero.get_node("VisionArea")
		vision.queue_free()
		print("Removed vision from hero: ", hero.name)

## Change vision radius for a hero
static func set_hero_vision_radius(hero: Node2D, new_radius: float) -> void:
	if hero.has_node("VisionArea"):
		var vision = hero.get_node("VisionArea")
		vision.set_vision_radius(new_radius)
		print("Changed ", hero.name, " vision to: ", new_radius)
	else:
		push_warning("Hero has no VisionArea: ", hero.name)
