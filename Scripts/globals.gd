
extends Node

static func get_entity_from_collider(collider: Node) -> Node2D:
	if collider.has_method("get_owner"):
		var owner = collider.get_owner()
		if owner and owner is Node2D and owner != collider:
			return owner
	
	if collider.has_method("get_parent"):
		var parent = collider.get_parent()
		if parent and parent is Node2D and parent != collider:
			return parent
	
	return collider if collider is Node2D else null
