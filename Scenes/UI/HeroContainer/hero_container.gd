extends Control

@onready var hero_panels = {
	"River": $MarginContainer/HeroHBoxContainer/Hero1,
	"Vlad": $MarginContainer/HeroHBoxContainer/Hero2,
	"Ted": $MarginContainer/HeroHBoxContainer/Hero3,
	"Irelia": $MarginContainer/HeroHBoxContainer/Hero4
}

var hero_assignments = {}
var cooldown_trackers = {} # Track active cooldowns

func _ready() -> void:
	await get_tree().process_frame
	print("=== HeroContainer _ready() ===")
	_assign_heroes()

func _assign_heroes() -> void:
	var heroes = get_tree().get_nodes_in_group("Hero")
	print("Found ", heroes.size(), " heroes in group")
	
	for hero in heroes:
		if not hero.has_node("HeroStats"):
			print("  - ", hero.name, " has no HeroStats!")
			continue
		
		var stats = hero.get_node("HeroStats")
		var hero_name = stats.base_stats.hero_name
		print("  - Assigning hero: ", hero_name)
		
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
		
		if not stats.health_changed.is_connected(_on_hero_health_changed):
			stats.health_changed.connect(_on_hero_health_changed.bind(health_bar))
	
	# Setup abilities with cooldown tracking
	_setup_ability_icons(hero, panel)

func _setup_ability_icons(hero: Node, panel: Control) -> void:
	print("    Setting up abilities for: ", hero.name)
	var ability_system = hero.get_node_or_null("AbilitySystem")
	if not ability_system:
		print("      ERROR: No AbilitySystem found!")
		return
	
	var ability_container = panel.get_node_or_null("VBoxContainer/AbilityContainer")
	if not ability_container:
		print("      ERROR: No AbilityContainer found!")
		return
	
	# Get icon nodes
	var active_icon = ability_container.get_node_or_null("Active")
	var basic_icon = ability_container.get_node_or_null("BasicAttack")
	var ult_icon = ability_container.get_node_or_null("Ultimate")
	var passive_icon = ability_container.get_node_or_null("Passive")
	
	# Setup passive (no cooldown)
	if passive_icon and ability_system.passive_ability:
		passive_icon.texture = ability_system.passive_ability.icon
		print("      ✓ Set icon for Passive: ", ability_system.passive_ability.ability_name)
	
	# Setup active
	if active_icon and ability_system.active_ability:
		active_icon.texture = ability_system.active_ability.icon
		_setup_cooldown_shader(active_icon)
		ability_system.ability_used.connect(func(used_ability):
			if used_ability.ability_type == AbilityBase.AbilityType.ACTIVE:
				print("✅ Active ability used: ", used_ability.ability_name)
				_animate_cooldown(active_icon, used_ability.cooldown)
		)
		print("      ✓ Connected Active: ", ability_system.active_ability.ability_name)
	
	# Setup basic attack
	if basic_icon and ability_system.basic_attack:
		basic_icon.texture = ability_system.basic_attack.icon
		_setup_cooldown_shader(basic_icon)
		ability_system.ability_used.connect(func(used_ability):
			if used_ability.ability_type == AbilityBase.AbilityType.BASIC_ATTACK:
				print("✅ BasicAttack used: ", used_ability.ability_name)
				_animate_cooldown(basic_icon, used_ability.cooldown)
		)
		print("      ✓ Connected BasicAttack: ", ability_system.basic_attack.ability_name)
	
	# Setup ultimate
	if ult_icon and ability_system.ultimate_ability:
		ult_icon.texture = ability_system.ultimate_ability.icon
		_setup_cooldown_shader(ult_icon)
		ability_system.ability_used.connect(func(used_ability):
			if used_ability.ability_type == AbilityBase.AbilityType.ULTIMATE:
				print("✅ Ultimate used: ", used_ability.ability_name)
				_animate_cooldown(ult_icon, used_ability.cooldown)
		)
		print("      ✓ Connected Ultimate: ", ability_system.ultimate_ability.ability_name)

func _setup_cooldown_shader(icon_node: TextureRect) -> void:
	"""Add shader material for radial cooldown effect"""
	var shader = load("res://Scenes/UI/HeroContainer/ability_cooldown.gdshader")
	
	if not shader:
		push_error("Failed to load cooldown shader at: res://Scenes/UI/HeroContainer/ability_cooldown.gdshader")
		return
	
	var shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter("progress", 1.0) # Start ready
	shader_material.set_shader_parameter("overlay_color", Color(0, 0, 0, 0.7))
	icon_node.material = shader_material

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

func _on_ability_used(used_ability: AbilityBase, icon_node: TextureRect, ability: AbilityBase, hero_name: String, slot_name: String) -> void:
	print("🔔 SIGNAL RECEIVED! Hero: ", hero_name, " | Slot: ", slot_name)
	print("  Used ability: ", used_ability.ability_name, " (Type: ", used_ability.ability_type, ")")
	print("  Expected ability: ", ability.ability_name, " (Type: ", ability.ability_type, ")")
	
	# Compare by TYPE instead of instance ID
	if used_ability.ability_type != ability.ability_type:
		print("  ❌ Types don't match! Ignoring.")
		return
	
	print("  ✅ Types match! Starting cooldown animation for ", ability.cooldown, "s")
	# Start cooldown animation
	_animate_cooldown(icon_node, ability.cooldown)


func _animate_cooldown(icon_node: TextureRect, cooldown_duration: float) -> void:
	"""Animate radial cooldown indicator"""
	if not icon_node.material:
		print("  ❌ No material on icon node!")
		return
	
	var elapsed = 0.0
	var tracker_id = icon_node.get_instance_id()
	cooldown_trackers[tracker_id] = true
	
	print("  ⏱️ Animation started for ", icon_node.name)
	
	# Animate from 0 to 1 (empty to full)
	while elapsed < cooldown_duration:
		if not is_instance_valid(icon_node) or not cooldown_trackers.get(tracker_id, false):
			break
		
		elapsed += get_process_delta_time()
		var progress = elapsed / cooldown_duration
		icon_node.material.set_shader_parameter("progress", progress)
		
		await get_tree().process_frame
	
	# Ensure it ends at 1.0 (ready)
	if is_instance_valid(icon_node):
		icon_node.material.set_shader_parameter("progress", 1.0)
		print("  ✅ Animation complete for ", icon_node.name)
	
	cooldown_trackers.erase(tracker_id)