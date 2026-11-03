extends Node
class_name FogOfWarHelper

## Gives an entity fog-of-war vision. World uses it for the monster player's
## VisionArea; heroes carry theirs in HeroBaseClass.tscn, sized by
## HeroBase._ready from HeroStats.

const VISION_SCENE = preload("res://Scenes/World/FogOfWar/VisionArea.tscn")

## Add vision to an entity with a custom radius
static func add_vision_to_hero(hero: Node2D, vision_radius: float = 200.0) -> VisionArea:
	# An entity that already has a VisionArea (every hero, from
	# HeroBaseClass.tscn) keeps it and gets the requested radius.
	if hero.has_node("VisionArea"):
		var existing := hero.get_node("VisionArea") as VisionArea
		if existing:
			existing.set_vision_radius(vision_radius)
		return existing

	var vision = VISION_SCENE.instantiate()
	vision.name = "VisionArea"
	vision.vision_radius = vision_radius
	hero.add_child(vision)
	return vision
