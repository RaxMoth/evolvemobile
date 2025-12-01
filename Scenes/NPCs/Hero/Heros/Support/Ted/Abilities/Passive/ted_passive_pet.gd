extends AbilityBase
class_name TedPassivePet

@export var pet_scene: PackedScene

var pet_instance: Node2D = null
var owner_entity: Node2D = null # Changed from 'owner'
var respawn_timer: float = 0.0
const RESPAWN_TIME: float = 10.0

func on_passive_update(entity: Node2D, delta: float) -> void:
	owner_entity = entity
	
	# Spawn pet on first update
	if not pet_instance and pet_scene:
		_spawn_pet()
	
	# Handle respawn timer
	if not is_instance_valid(pet_instance) and respawn_timer > 0.0:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			_spawn_pet()

func _spawn_pet() -> void:
	if not owner_entity or not is_instance_valid(owner_entity):
		return
	
	pet_instance = pet_scene.instantiate()
	
	# FIXED: Spawn as sibling to Ted (same parent node)
	# This makes pet and Ted both children of World/Main, not root
	var parent_node = owner_entity.get_parent()
	if not parent_node:
		push_error("Ted has no parent node - cannot spawn pet!")
		return
	
	# Add to scene tree first
	parent_node.add_child(pet_instance)
	
	# IMPORTANT: Set owner AFTER adding to tree
	# Owner must be a node that's already in the tree
	pet_instance.owner = parent_node
	
	# Set pet's owner reference
	if pet_instance.has_method("set_owner_entity"):
		pet_instance.set_owner_entity(owner_entity)
	elif "owner_entity" in pet_instance:
		pet_instance.owner_entity = owner_entity
	
	# Position pet near Ted
	pet_instance.global_position = owner_entity.global_position + Vector2(30, 0)
	
	# Connect death signal
	if pet_instance.has_signal("died"):
		pet_instance.died.connect(_on_pet_died)
	
	print("Pet spawned for " + owner_entity.name)

func _on_pet_died() -> void:
	print("Pet died! Respawning in " + str(RESPAWN_TIME) + " seconds")
	pet_instance = null
	respawn_timer = RESPAWN_TIME
