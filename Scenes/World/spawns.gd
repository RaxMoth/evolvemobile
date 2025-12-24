extends Node
class_name SpawnManager

@export_group("Spawn Configuration")
@export var min_active_spawns: int = 26
@export var max_active_spawns: int = 30
@export var auto_activate_on_ready: bool = true

var all_spawn_areas: Array[MobSpawnArea] = []
var active_spawn_areas: Array[MobSpawnArea] = []

func _ready() -> void:
	if auto_activate_on_ready:
		randomize_spawns()

func randomize_spawns() -> void:
	"""Randomly select and activate spawns"""
	_collect_all_spawns()
	_deactivate_all_spawns()
	_activate_random_spawns()
	
	print("SpawnManager: Activated " + str(active_spawn_areas.size()) + " out of " + str(all_spawn_areas.size()) + " spawns")

func _collect_all_spawns() -> void:
	"""Find all spawn areas as children of this node"""
	all_spawn_areas.clear()
	
	for child in get_children():
		if child is MobSpawnArea:
			all_spawn_areas.append(child)
	
	print("SpawnManager: Found " + str(all_spawn_areas.size()) + " total spawn areas")

func _deactivate_all_spawns() -> void:
	"""Disable all spawns initially"""
	for spawn in all_spawn_areas:
		spawn.auto_spawn_on_ready = false
		spawn.set_process(false)
		spawn.visible = false

func _activate_random_spawns() -> void:
	"""Randomly select and activate spawns"""
	active_spawn_areas.clear()
	
	var num_to_activate = randi_range(min_active_spawns, max_active_spawns)
	num_to_activate = min(num_to_activate, all_spawn_areas.size())
	
	var shuffled = all_spawn_areas.duplicate()
	shuffled.shuffle()
	
	for i in range(num_to_activate):
		var spawn = shuffled[i]
		_activate_spawn(spawn)
		active_spawn_areas.append(spawn)

func _activate_spawn(spawn: MobSpawnArea) -> void:
	"""Enable and initialize a spawn area"""
	spawn.set_process(true)
	spawn.visible = true
	spawn.auto_spawn_on_ready = true
	
	if spawn.has_method("spawn_mobs"):
		spawn.spawn_mobs()

func get_active_spawns() -> Array[MobSpawnArea]:
	"""Get list of currently active spawns"""
	return active_spawn_areas

func get_total_spawns() -> int:
	"""Get total number of spawn areas"""
	return all_spawn_areas.size()

func get_active_count() -> int:
	"""Get number of active spawns"""
	return active_spawn_areas.size()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R and event.shift_pressed:
			print("Re-randomizing spawns...")
			randomize_spawns()