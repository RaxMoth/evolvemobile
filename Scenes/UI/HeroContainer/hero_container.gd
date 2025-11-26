extends Control

@onready var hero_panels = {
	"River": $MarginContainer/HeroHBoxContainer/Hero1,
	"Vlad": $MarginContainer/HeroHBoxContainer/Hero2,
	"Ted": $MarginContainer/HeroHBoxContainer/Hero3,
	"Irelia": $MarginContainer/HeroHBoxContainer/Hero4
}

var hero_assignments = {}

func _ready() -> void:
	await get_tree().process_frame  # Wait for heroes to spawn
	_assign_heroes()

func _assign_heroes() -> void:
	var heroes = get_tree().get_nodes_in_group("Hero")
	
	for hero in heroes:
		if not hero.has_node("HeroStats"):
			continue
		
		var stats = hero.get_node("HeroStats")
		var hero_name = stats.base_stats.hero_name
		
		if hero_name in hero_panels:
			_setup_hero_panel(hero, hero_panels[hero_name])
			hero_assignments[hero_name] = hero

func _setup_hero_panel(hero: Node, panel: Control) -> void:
	var stats = hero.get_node("HeroStats")
	
	# Set hero name
	var name_label = panel.get_node_or_null("VBoxContainer/HeroName")
	if name_label:
		name_label.text = stats.base_stats.hero_name
	
	# Set portrait
	var portrait = panel.get_node_or_null("VBoxContainer/HeroPortrait")
	if portrait and stats.base_stats.portrait:
		portrait.texture = stats.base_stats.portrait
	
	# Set health bar
	var health_bar = panel.get_node_or_null("VBoxContainer/HealthBar")
	if health_bar:
		health_bar.max_value = stats.current_stats.max_health
		health_bar.value = stats.current_stats.current_health
		
		# Only connect if not already connected
		if not stats.health_changed.is_connected(_on_hero_health_changed):
			stats.health_changed.connect(_on_hero_health_changed.bind(health_bar))
	
	# Setup abilities
	_setup_ability_icons(hero, panel)

func _setup_ability_icons(hero: Node, panel: Control) -> void:
	var ability_system = hero.get_node_or_null("AbilitySystem")
	if not ability_system:
		print("Warning: No AbilitySystem found for hero")
		return
	
	var ability_container = panel.get_node_or_null("VBoxContainer/AbilityContainer")
	if not ability_container:
		print("Warning: No AbilityContainer found in panel")
		return
	
	# Map ability slots to UI elements
	var ability_slots = {
		"Passive": ability_container.get_node_or_null("Passive"),
		"Active": ability_container.get_node_or_null("Active"),
		"BasicAttack": ability_container.get_node_or_null("BasicAttack"),
		"Ultimate": ability_container.get_node_or_null("Ultimate")
	}
	
	# Setup each ability icon
	for slot_name in ability_slots:
		var icon_node = ability_slots[slot_name]
		if not icon_node:
			print("Warning: Ability slot '" + slot_name + "' not found")
			continue
		
		var ability = null
		match slot_name:
			"Passive":
				ability = ability_system.passive_ability
			"Active":
				ability = ability_system.active_ability
			"BasicAttack":
				ability = ability_system.basic_attack
			"Ultimate":
				ability = ability_system.ultimate_ability
		
		if ability and ability.icon:
			icon_node.texture = ability.icon
		
		# Connect cooldown updates (only for active abilities, not passive)
		if slot_name != "Passive" and ability:
			var callback = _on_ability_used.bind(icon_node, ability)
			
			# Only connect if not already connected
			if not ability_system.ability_used.is_connected(callback):
				ability_system.ability_used.connect(callback)

func _on_hero_health_changed(current: float, max_health: float, health_bar: ProgressBar) -> void:
	if not is_instance_valid(health_bar):
		return
		
	health_bar.max_value = max_health
	health_bar.value = current
	
	# Color coding
	var health_percent = current / max_health
	if health_percent > 0.5:
		health_bar.modulate = Color.GREEN
	elif health_percent > 0.25:
		health_bar.modulate = Color.YELLOW
	else:
		health_bar.modulate = Color.RED

func _on_ability_used(ability_name: String, icon_node: TextureRect, ability: AbilityBase) -> void:
	if not ability or not is_instance_valid(icon_node):
		return
	
	# Dim icon during cooldown
	icon_node.modulate = Color(1.0, 1.0, 1.0, 0.5)
	
	# Wait for cooldown
	await get_tree().create_timer(ability.cooldown).timeout
	
	# Restore icon
	if is_instance_valid(icon_node):
		icon_node.modulate = Color.WHITE
