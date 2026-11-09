extends AbilityBase
class_name TedPassivePet

## Loyal Companion: Ted keeps pet_count pets (pet_scene) at his side. Every
## pet slot has its own respawn timer: the first spawn is immediate, a pet
## that died comes back respawn_time seconds later, a pet freed without dying
## (a scene reload) right away. Pets, timers and the Beastmaster multipliers
## all live on this Ted's own copy of the passive, so nothing carries over to
## another Ted or match.

@export var pet_scene: PackedScene

@export_group("Beastmaster")
## hero_ted "Loyal Bond": each pet's max HP x this.
@export var pet_health_mult: float = 1.0
## hero_ted "Sharp Fangs": each pet's bite damage x this.
@export var pet_damage_mult: float = 1.0
## Seconds until a dead pet is back (hero_ted "Never Alone" shortens it).
@export var respawn_time: float = 10.0
## hero_ted capstone "Pack of Two": how many pets Ted keeps (1 x 2).
@export var pet_count: int = 1

## Where slot 0's pet appears next to Ted; further slots go round him.
const PET_OFFSET := Vector2(30, 0)
## The pet's script as a type (it has no class_name: the determinism trace
## fingerprints every entity by its script's global name).
const PetScript := preload("res://Scenes/NPCs/Hero/Heros/Support/Ted/Abilities/Passive/teds_pet.gd")

## One entry per pet slot: the pet, or null while it is dead / not spawned.
var pets: Array[PetScript] = []
## Seconds until each slot's pet respawns; <= 0 = spawn on the next update.
var respawn_timers: Array[float] = []
var owner_entity: Node2D = null # Changed from 'owner'


func on_passive_update(entity: Node2D, delta: float) -> void:
	owner_entity = entity
	if pet_scene == null:
		return
	var count: int = maxi(pet_count, 0)
	if pets.size() != count:
		pets.resize(count)
		respawn_timers.resize(count)
	for slot in count:
		if is_instance_valid(pets[slot]):
			continue
		if respawn_timers[slot] > 0.0:
			respawn_timers[slot] -= delta
			if respawn_timers[slot] > 0.0:
				continue
		_spawn_pet(slot)


## The pets alive right now, in slot order.
func living_pets() -> Array[PetScript]:
	var out: Array[PetScript] = []
	for pet in pets:
		if is_instance_valid(pet):
			out.append(pet)
	return out


## Where slot `slot`'s pet appears relative to Ted.
func pet_offset(slot: int) -> Vector2:
	return PET_OFFSET.rotated(TAU * slot / maxi(pet_count, 1))


func _spawn_pet(slot: int) -> void:
	if not owner_entity or not is_instance_valid(owner_entity):
		return

	var pet := pet_scene.instantiate() as PetScript
	# Before add_child: the pet's _ready fills its HP from max_health.
	pet.max_health *= pet_health_mult
	pet.attack_damage *= pet_damage_mult

	# FIXED: Spawn as sibling to Ted (same parent node)
	# This makes pet and Ted both children of World/Main, not root
	var parent_node = owner_entity.get_parent()
	if not parent_node:
		push_error("Ted has no parent node - cannot spawn pet!")
		pet.queue_free()
		return

	# Add to scene tree first
	parent_node.add_child(pet)

	# IMPORTANT: Set owner AFTER adding to tree
	# Owner must be a node that's already in the tree
	pet.owner = parent_node

	# Set pet's owner reference
	pet.set_owner_entity(owner_entity)

	# Position pet near Ted
	pet.global_position = owner_entity.global_position + pet_offset(slot)

	# Connect death signal
	pet.died.connect(_on_pet_died.bind(slot))
	pets[slot] = pet


func _on_pet_died(slot: int) -> void:
	if slot >= pets.size():
		return
	pets[slot] = null
	respawn_timers[slot] = respawn_time


## F3: the pets alive and, for a dead one, when it is back.
func debug_line() -> String:
	var line := super.debug_line() + "  pets %d/%d" % [living_pets().size(), pets.size()]
	for slot in pets.size():
		if not is_instance_valid(pets[slot]) and respawn_timers[slot] > 0.0:
			line += "  back in %.1f s" % respawn_timers[slot]
	return line
