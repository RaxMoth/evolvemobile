extends AbilityBase
class_name RiverBasicAttack

# This single ability handles BOTH sniper and heal modes. All numbers come from
# the resource: `damage` / `ability_range` = sniper shot, `heal_amount` = heal
# per shot, and one cooldown per mode (AbilitySystem reads `cooldown` after
# each execute, so execute sets it to the active mode's value).
@export var sniper_cooldown: float = 1.1
@export var heal_range: float = 150.0
@export var heal_cooldown: float = 1.4
## River tree "Triple Shot": each sniper shot also hits up to this many other
## enemies within extra_target_radius of the main target (0 = single target).
@export var extra_targets: int = 0
@export var extra_target_radius: float = 160.0

func can_use(caster: Node2D) -> bool:
	if not caster.has_method("is_alive") or not caster.is_alive():
		return false
	return true

func execute(caster: Node2D, target: Node2D = null, _override_damage: float = -1.0) -> void:
	# Check current weapon mode from River
	if not caster.has_method("get_weapon_mode"):
		return
	
	var mode = caster.get_weapon_mode()
	
	match mode:
		0: # SNIPER mode
			_execute_sniper(caster, target)
		1: # HEAL_STAFF mode
			_execute_heal(caster, target)

func _execute_sniper(caster: Node2D, target: Node2D) -> void:
	if not is_instance_valid(target) or not is_instance_valid(caster):
		return

	var distance = caster.global_position.distance_to(target.global_position)
	if distance <= effective_range(caster):
		# Apply damage with modifier
		var damage_mult = 1.0
		if caster.has_node("AbilitySystem"):
			var ability_system = caster.get_node("AbilitySystem")
			damage_mult = ability_system.get_damage_multiplier()

		var final_damage = damage * damage_mult
		EventBus.deal_damage(caster, target, final_damage, self)

		# Visual feedback
		_create_sniper_effect(caster, target)
		if extra_targets > 0:
			for extra in _extra_targets_near(caster, target):
				EventBus.deal_damage(caster, extra, final_damage, self)
				_create_sniper_effect(caster, extra)

		# Update cooldown to sniper speed
		cooldown = sniper_cooldown

## The `extra_targets` closest living enemies around the main target.
func _extra_targets_near(caster: Node2D, primary: Node2D) -> Array[Node2D]:
	var r_sq: float = extra_target_radius * extra_target_radius
	var at: Vector2 = primary.global_position
	var found: Array[Node2D] = []
	for e in EntityRegistry.targets_for(caster):
		if e == primary or not is_instance_valid(e) or not EntityRegistry.is_entity_alive(e):
			continue
		if e.global_position.distance_squared_to(at) <= r_sq:
			found.append(e)
	found.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(at) < b.global_position.distance_squared_to(at))
	return found.slice(0, extra_targets)


func _execute_heal(caster: Node2D, target: Node2D) -> void:
	# If no target, find nearest ally
	if not target:
		target = _find_nearest_ally(caster)
	
	if not target:
		return
	
	# Don't heal self
	if target == caster:
		return
	
	var distance = caster.global_position.distance_to(target.global_position)
	if distance <= heal_range:
		# Apply healing
		if target.has_method("heal"):
			target.heal(heal_amount)
		elif target.has_node("HeroStats"):
			var stats = target.get_node("HeroStats")
			stats.heal(heal_amount)
		
		# Visual feedback
		_create_heal_effect(caster, target)
		
		# Update cooldown to heal speed
		cooldown = heal_cooldown

func _find_nearest_ally(caster: Node2D) -> Node2D:
	var heroes = caster.get_tree().get_nodes_in_group("Hero")
	var nearest: Node2D = null
	var nearest_distance := INF
	
	for hero in heroes:
		if hero == caster:
			continue
		
		if not hero.has_method("is_alive") or not hero.is_alive():
			continue
		
		var distance = caster.global_position.distance_to(hero.global_position)
		if distance < nearest_distance and distance <= heal_range:
			nearest_distance = distance
			nearest = hero
	
	return nearest

func _create_sniper_effect(caster: Node2D, target: Node2D) -> void:
	var line = Line2D.new()
	caster.get_parent().add_child(line)
	line.add_point(caster.global_position)
	line.add_point(target.global_position)
	line.default_color = Color.ORANGE
	line.width = 2.0
	line.z_index = 10
	
	var tween = line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.3)
	tween.tween_callback(line.queue_free)

func _create_heal_effect(caster: Node2D, target: Node2D) -> void:
	var line = Line2D.new()
	caster.get_parent().add_child(line)
	line.add_point(caster.global_position)
	line.add_point(target.global_position)
	line.default_color = Color.GREEN
	line.width = 3.0
	line.z_index = 10
	
	var tween = line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.4)
	tween.tween_callback(line.queue_free)

# Return current stats based on mode
func get_current_range(caster: Node2D) -> float:
	if caster.has_method("get_weapon_mode"):
		return ability_range if caster.get_weapon_mode() == 0 else heal_range
	return ability_range

func get_current_cooldown(caster: Node2D) -> float:
	if caster.has_method("get_weapon_mode"):
		return sniper_cooldown if caster.get_weapon_mode() == 0 else heal_cooldown
	return sniper_cooldown
