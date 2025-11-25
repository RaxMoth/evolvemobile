extends Control
class_name HeroContainer

## Displays hero stats and abilities in the UI

var hero_slots: Array[Dictionary] = []
var tracked_heroes: Array[Node2D] = []

# Define the expected hero order
var hero_order: Array[String] = ["River", "Vlad", "Ted", "Irelia"]

func _ready() -> void:
	# Get all hero slot containers
	var hbox = $MarginContainer/HeroHBoxContainer
	
	for i in range(1, 5):
		var hero_panel = hbox.get_node_or_null("Hero" + str(i))
		if hero_panel:
			var slot = {
				"panel": hero_panel,
				"name_label": hero_panel.get_node("VBoxContainer/HeroName"),
				"portrait": hero_panel.get_node("VBoxContainer/HeroPortrait"),
				"health_bar": hero_panel.get_node("VBoxContainer/HealthBar"),
				"passive_icon": hero_panel.get_node("VBoxContainer/AbilityContainer/Passive"),
				"active_icon": hero_panel.get_node("VBoxContainer/AbilityContainer/Active"),
				"basic_icon": hero_panel.get_node("VBoxContainer/AbilityContainer/BasicAttack"),
				"ultimate_icon": hero_panel.get_node("VBoxContainer/AbilityContainer/Ultimate"),
				"hero": null,
				"expected_name": hero_order[i - 1] if i - 1 < hero_order.size() else ""
			}
			hero_slots.append(slot)
			slot.panel.visible = false  # Hide until hero assigned
	
	# Wait for heroes to spawn
	await get_tree().create_timer(0.5).timeout
	_find_and_assign_heroes()

func _find_and_assign_heroes() -> void:
	var heroes = get_tree().get_nodes_in_group("Hero")
	
	# Sort heroes by name to match expected order
	var hero_map = {}
	for hero in heroes:
		if hero is Node2D:
			# Extract base name (handle names like "River2", "Vlad@123", etc.)
			var hero_name = hero.name
			for expected_name in hero_order:
				if expected_name.to_lower() in hero_name.to_lower():
					hero_map[expected_name] = hero
					break
	
	# Assign heroes to their correct slots
	for i in range(hero_slots.size()):
		var expected_name = hero_slots[i].expected_name
		if hero_map.has(expected_name):
			assign_hero_to_slot(i, hero_map[expected_name])
		else:
			# If expected hero not found, try to assign any unassigned hero
			for hero in heroes:
				if hero not in tracked_heroes:
					assign_hero_to_slot(i, hero)
					break

func assign_hero_to_slot(slot_index: int, hero: Node2D) -> void:
	if slot_index < 0 or slot_index >= hero_slots.size():
		return
	
	var slot = hero_slots[slot_index]
	slot.hero = hero
	tracked_heroes.append(hero)
	
	# Show the panel
	slot.panel.visible = true
	
	# Set hero name from stats
	var hero_name = hero.name
	if hero.has_node("HeroStats"):
		var hero_stats_component = hero.get_node("HeroStats")
		if hero_stats_component.base_stats:
			var stats = hero_stats_component.base_stats
			hero_name = stats.hero_name
			slot.name_label.text = stats.hero_name
			
			# Set portrait if available
			if stats.portrait:
				slot.portrait.texture = stats.portrait
		else:
			slot.name_label.text = hero_name
	else:
		slot.name_label.text = hero_name
	
	# Setup health bar
	if hero.has_node("HeroStats"):
		var hero_stats = hero.get_node("HeroStats")
		slot.health_bar.max_value = hero_stats.get_max_health()
		slot.health_bar.value = hero_stats.get_current_health()
		
		# Connect to health changes
		if not hero_stats.health_changed.is_connected(_on_hero_health_changed):
			hero_stats.health_changed.connect(_on_hero_health_changed.bind(slot))
	
	# Setup ability icons
	if hero.has_node("AbilitySystem"):
		var ability_system = hero.get_node("AbilitySystem")
		
		if ability_system.passive_ability and ability_system.passive_ability.icon:
			slot.passive_icon.texture = ability_system.passive_ability.icon
		
		if ability_system.active_ability and ability_system.active_ability.icon:
			slot.active_icon.texture = ability_system.active_ability.icon
		
		if ability_system.basic_attack and ability_system.basic_attack.icon:
			slot.basic_icon.texture = ability_system.basic_attack.icon
		
		if ability_system.ultimate_ability and ability_system.ultimate_ability.icon:
			slot.ultimate_icon.texture = ability_system.ultimate_ability.icon
	
	print("Assigned ", hero_name, " (", hero.name, ") to slot ", slot_index + 1)

func _on_hero_health_changed(current: float, max_hp: float, slot: Dictionary) -> void:
	if not is_instance_valid(slot.health_bar):
		return
	
	slot.health_bar.max_value = max_hp
	slot.health_bar.value = current
	
	# Color code health bar
	var health_percent = current / max_hp
	if health_percent > 0.5:
		slot.health_bar.modulate = Color.GREEN
	elif health_percent > 0.25:
		slot.health_bar.modulate = Color.YELLOW
	else:
		slot.health_bar.modulate = Color.RED

func _process(_delta: float) -> void:
	# Update cooldown overlays if needed
	_update_ability_cooldowns()

func _update_ability_cooldowns() -> void:
	for slot in hero_slots:
		if not slot.hero or not is_instance_valid(slot.hero):
			continue
		
		if not slot.hero.has_node("AbilitySystem"):
			continue
		
		var ability_system = slot.hero.get_node("AbilitySystem")
		
		# Update ability icons based on cooldown state
		_update_ability_icon(slot.active_icon, ability_system, AbilityBase.AbilityType.ACTIVE)
		_update_ability_icon(slot.ultimate_icon, ability_system, AbilityBase.AbilityType.ULTIMATE)

func _update_ability_icon(icon: TextureRect, ability_system: AbilitySystem, ability_type: int) -> void:
	if not is_instance_valid(icon):
		return
	
	if ability_system.is_on_cooldown(ability_type):
		icon.modulate = Color(0.5, 0.5, 0.5, 0.7)  # Dim when on cooldown
	else:
		icon.modulate = Color.WHITE  # Full brightness when ready

# Helper to manually reassign heroes if needed
func reassign_heroes() -> void:
	tracked_heroes.clear()
	for slot in hero_slots:
		slot.hero = null
		slot.panel.visible = false
	_find_and_assign_heroes()
