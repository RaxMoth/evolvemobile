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
	# River's weapon mode (River.get_weapon_mode) picks the shot.
	if not caster.has_method("get_weapon_mode"):
		return
	
	var mode: int = caster.get_weapon_mode()
	
	match mode:
		RiverActiveWeaponSwap.WeaponMode.SNIPER:
			_execute_sniper(caster, target)
		RiverActiveWeaponSwap.WeaponMode.HEAL_STAFF:
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


## River only swings the staff at the wounded ally she picked
## (River._find_nearest_wounded_ally), never at herself.
func _execute_heal(caster: Node2D, target: Node2D) -> void:
	if not target or target == caster:
		return
	
	var distance := caster.global_position.distance_to(target.global_position)
	if distance <= heal_range:
		var stats := target.get_node_or_null("HeroStats") as HeroStatsComponent
		if stats:
			stats.heal(heal_amount)
		
		# Visual feedback
		_create_heal_effect(caster, target)
		
		# Update cooldown to heal speed
		cooldown = heal_cooldown

func _create_sniper_effect(caster: Node2D, target: Node2D) -> void:
	GameUtils.flash_line(caster.get_parent(), caster.global_position, target.global_position, Color.ORANGE, 2.0, 0.3)

func _create_heal_effect(caster: Node2D, target: Node2D) -> void:
	GameUtils.flash_line(caster.get_parent(), caster.global_position, target.global_position, Color.GREEN, 3.0, 0.4)
