extends Node

signal heroes_won
signal monster_won
signal match_ended(winner: String, time: float)

var match_start_time: float
var heroes_alive: int = 0
var monster_alive: bool = false

func _ready() -> void:
	add_to_group("GameManager")
	match_start_time = Time.get_ticks_msec() / 1000.0

	print("GameManager _ready() called")

	# Wait for all entities to be ready, then take an initial census.
	await get_tree().process_frame
	await get_tree().process_frame

	_initial_census()
	# Single bus subscription handles every future death — no per-entity binding.
	EventBus.entity_died.connect(_on_entity_died)

func _initial_census() -> void:
	# Only count "real" heroes (HeroBase) — Ted's pet is also in the Hero group
	# but is a CharacterBody2D, not a HeroBase, so it must not affect the count.
	heroes_alive = 0
	for node in get_tree().get_nodes_in_group("Hero"):
		if node is HeroBase:
			heroes_alive += 1

	var monster_count := 0
	for node in get_tree().get_nodes_in_group("Monster"):
		if node is MonsterBase:
			monster_count += 1
	monster_alive = monster_count > 0

	print("GameManager: Initial census — heroes=", heroes_alive, " monsters=", monster_count)
	if heroes_alive == 0:
		push_warning("GameManager: No heroes found!")
	if not monster_alive:
		push_warning("GameManager: No monsters found!")

func _on_entity_died(entity: Node, _killer: Node) -> void:
	if not is_instance_valid(entity):
		return
	if entity is MonsterBase:
		monster_alive = false
		print("💀 GameManager: Monster '" + entity.name + "' died!")
		_end_match("Heroes", heroes_alive > 0)
	elif entity is HeroBase:
		heroes_alive -= 1
		print("💀 GameManager: Hero '" + entity.name + "' died! Remaining: " + str(heroes_alive))
		if heroes_alive <= 0:
			_end_match("Monster", monster_alive)
	# Mobs and pets fire entity_died too, but we don't track them here.

func _end_match(winner: String, victory: bool) -> void:
	var match_duration = (Time.get_ticks_msec() / 1000.0) - match_start_time
	
	if victory:
		print("🏆 " + winner.to_upper() + " WIN!")
		print("⏱️  Match duration: " + str(round(match_duration * 10) / 10.0) + " seconds")
		
		match_ended.emit(winner, match_duration)
		
		if winner == "Heroes":
			heroes_won.emit()
		else:
			monster_won.emit()
		
		_show_victory_screen(winner, match_duration)
	
	# Freeze game
	get_tree().paused = true

func _show_victory_screen(winner: String, duration: float) -> void:
	# TODO: Create victory UI
	pass
