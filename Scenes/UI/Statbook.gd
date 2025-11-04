extends Control
class_name HeroStatBook

@onready var hero_name_label: Label = $HeroName
@onready var level_label: Label = $Level
@onready var stats_container: VBoxContainer = $StatsContainer

var hero_stats: HeroStatsComponent

func display_hero(stats: HeroStatsComponent) -> void:
	hero_stats = stats
	_update_display()
	
	# Connect to stat changes for live updates
	stats.stat_changed.connect(_on_stat_changed)
	stats.leveled_up.connect(_on_level_up)

func _update_display() -> void:
	if not hero_stats or not hero_stats.base_stats:
		return
	
	hero_name_label.text = hero_stats.base_stats.hero_name
	level_label.text = "Level " + str(hero_stats.level)
	
	# Clear old stats
	for child in stats_container.get_children():
		child.queue_free()
	
	# Display all stats
	_add_stat_row("Health", hero_stats.get_current_health(), hero_stats.get_max_health())
	_add_stat_row("Damage", hero_stats.get_attack_damage())
	_add_stat_row("Move Speed", hero_stats.get_move_speed())
	_add_stat_row("Attack Range", hero_stats.get_attack_range())
	_add_stat_row("Attack Speed", hero_stats.get_attack_speed_multiplier(), 1.0, "x")

func _add_stat_row(stat_name: String, current: float, max_val: float = -1.0, suffix: String = "") -> void:
	var label = Label.new()
	if max_val > 0:
		label.text = stat_name + ": " + str(int(current)) + " / " + str(int(max_val)) + suffix
	else:
		label.text = stat_name + ": " + str(snapped(current, 0.1)) + suffix
	stats_container.add_child(label)

func _on_stat_changed(stat_name: String, old_value: float, new_value: float) -> void:
	_update_display()

func _on_level_up(new_level: int) -> void:
	_update_display()
