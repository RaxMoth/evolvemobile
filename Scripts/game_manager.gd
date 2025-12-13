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
	
	# Wait for all entities to be ready
	await get_tree().process_frame
	await get_tree().process_frame
	
	_connect_death_signals()

func _connect_death_signals() -> void:
	"""Connect to all hero and monster death signals"""
	var all_heroes = get_tree().get_nodes_in_group("Hero")
	var all_monsters = get_tree().get_nodes_in_group("Monster")
	
	# Filter to only actual heroes/monsters (not child nodes)
	var heroes = []
	for node in all_heroes:
		# Check if it's actually a hero (has the EntityBase as parent)
		if node.get_script() and node.has_signal("died"):
			heroes.append(node)
	
	var monsters = []
	for node in all_monsters:
		# Check if it's actually a monster (has the EntityBase as parent)
		if node.get_script() and node.has_signal("died"):
			monsters.append(node)
	
	print("GameManager: Connecting death signals...")
	print("  Found " + str(all_heroes.size()) + " nodes in Hero group")
	print("  Filtered to " + str(heroes.size()) + " actual heroes")
	print("  Found " + str(all_monsters.size()) + " nodes in Monster group")
	print("  Filtered to " + str(monsters.size()) + " actual monsters")
	
	# Update counts
	heroes_alive = heroes.size()
	monster_alive = monsters.size() > 0
	
	if heroes_alive == 0:
		push_warning("GameManager: No heroes found!")
	if not monster_alive:
		push_warning("GameManager: No monsters found!")
	
	# Connect hero deaths
	for hero in heroes:
		hero.died.connect(_on_hero_died.bind(hero))
		print("  ✓ Connected to hero: " + hero.name)
	
	# Connect monster deaths
	for monster in monsters:
		monster.died.connect(_on_monster_died.bind(monster))
		print("  ✓ Connected to monster: " + monster.name)

func _on_hero_died(hero: Node = null) -> void:
	var hero_name = hero.name if hero else "Unknown"
	heroes_alive -= 1
	print("💀 GameManager: Hero '" + hero_name + "' died! Remaining: " + str(heroes_alive))
	
	if heroes_alive <= 0:
		_end_match("Monster", monster_alive)

func _on_monster_died(monster: Node = null) -> void:
	var monster_name = monster.name if monster else "Unknown"
	monster_alive = false
	print("💀 GameManager: Monster '" + monster_name + "' died!")
	_end_match("Heroes", heroes_alive > 0)

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
