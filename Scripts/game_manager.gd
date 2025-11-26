extends Node
class_name GameManager

signal heroes_won
signal monster_won
signal match_ended(winner: String, time: float)

var match_start_time: float
var heroes_alive: int = 4
var monster_alive: bool = true

func _ready() -> void:
	match_start_time = Time.get_ticks_msec() / 1000.0
	_connect_death_signals()

func _connect_death_signals() -> void:
	# Connect to all hero death signals
	var heroes = get_tree().get_nodes_in_group("Hero")
	for hero in heroes:
		if hero.has_signal("died"):
			hero.died.connect(_on_hero_died)
	
	# Connect to monster death
	var monsters = get_tree().get_nodes_in_group("Monster")
	for monster in monsters:
		if monster.has_signal("died"):
			monster.died.connect(_on_monster_died)

func _on_hero_died() -> void:
	heroes_alive -= 1
	print("Hero died! Remaining: " + str(heroes_alive))
	
	if heroes_alive <= 0:
		_end_match("Monster", monster_alive)

func _on_monster_died() -> void:
	monster_alive = false
	print("Monster died!")
	_end_match("Heroes", heroes_alive > 0)

func _end_match(winner: String, victory: bool) -> void:
	var match_duration = (Time.get_ticks_msec() / 1000.0) - match_start_time
	
	if victory:
		print(winner + " WIN! Match duration: " + str(match_duration) + "s")
		match_ended.emit(winner, match_duration)
		
		if winner == "Heroes":
			heroes_won.emit()
		else:
			monster_won.emit()
		
		# Show victory screen
		_show_victory_screen(winner, match_duration)
	
	# Freeze game
	get_tree().paused = true

func _show_victory_screen(winner: String, duration: float) -> void:
	# Create victory UI
	pass
