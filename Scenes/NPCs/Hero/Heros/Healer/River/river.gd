extends HeroBase
class_name River

enum WeaponMode {
	SNIPER,
	HEAL_STAFF
}

var current_weapon_mode: WeaponMode = WeaponMode.SNIPER

func _ready() -> void:
	super._ready()
	
	# Connect to active ability for weapon swap
	if ability_system and ability_system.active_ability:
		ability_system.ability_used.connect(_on_ability_used)

func _on_ability_used(ability: AbilityBase) -> void:
	# Update weapon mode when swap is used
	if ability is RiverActiveWeaponSwap:
		current_weapon_mode = ability.get_current_mode()
		_update_attack_range()

func set_weapon_mode(mode: String) -> void:
	match mode:
		"sniper":
			current_weapon_mode = WeaponMode.SNIPER
		"heal_staff":
			current_weapon_mode = WeaponMode.HEAL_STAFF
	
	_update_attack_range()

func _update_attack_range() -> void:
	# Adjust behavior based on weapon
	if not ability_system:
		return
	
	# The basic attack abilities handle their own range
	# But we can adjust targeting here if needed

func _get_attack_range() -> float:
	# Override to change range based on weapon mode
	match current_weapon_mode:
		WeaponMode.SNIPER:
			return 300.0  # Long range
		WeaponMode.HEAL_STAFF:
			return 150.0  # Medium range
	return super._get_attack_range()

func _get_move_speed() -> float:
	var base_speed = super._get_move_speed()
	
	# Apply passive speed boost if active
	if ability_system and ability_system.passive_ability:
		if ability_system.passive_ability.has_method("get_speed_multiplier"):
			var multiplier = ability_system.passive_ability.get_speed_multiplier()
			return base_speed * multiplier
	
	return base_speed

# Override fight logic to handle weapon modes
func _on_fight_logic(delta: float) -> void:
	if not ability_system:
		return
	
	match current_weapon_mode:
		WeaponMode.SNIPER:
			# Attack enemies with sniper
			if is_target_valid() and target_entity.is_in_group("Enemy"):
				ability_system.use_basic_attack(target_entity)
		
		WeaponMode.HEAL_STAFF:
			# Find and heal allies
			var ally = _find_nearest_wounded_ally()
			if ally:
				ability_system.use_basic_attack(ally)
			else:
				# No allies to heal, maybe switch to sniper?
				# For now, just don't attack
				pass

func _find_nearest_wounded_ally() -> Node2D:
	var heroes = get_tree().get_nodes_in_group("Hero")
	var nearest: Node2D = null
	var nearest_distance := INF
	
	for hero in heroes:
		if hero == self:
			continue
		
		if not hero.has_method("is_alive") or not hero.is_alive():
			continue
		
		# Check if hero needs healing
		if hero.has_method("get_health"):
			var health_percent = hero.get_health() / hero.max_health
			if health_percent >= 0.95:  # Almost full health
				continue
		
		var distance = global_position.distance_to(hero.global_position)
		if distance < nearest_distance and distance <= 150.0:
			nearest_distance = distance
			nearest = hero
	
	return nearest

# Override approach to handle both enemy and ally targeting
func _on_approach_state_processing(delta: float) -> void:
	match current_weapon_mode:
		WeaponMode.SNIPER:
			# Normal enemy approach
			super._on_approach_state_processing(delta)
		
		WeaponMode.HEAL_STAFF:
			# Approach wounded allies
			var ally = _find_nearest_wounded_ally()
			if ally:
				var distance = global_position.distance_to(ally.global_position)
				if distance <= 150.0:
					# In range, start healing
					var dir: Vector2 = (ally.global_position - global_position).normalized()
					sprite.rotation = dir.angle()
				else:
					# Move closer
					move_toward_point(ally.global_position, approach_speed, delta)
			else:
				# No allies to heal, stay put or wander
				super._on_approach_state_processing(delta)
