extends AbilityBase
class_name RiverBasicAttack

# This single ability handles BOTH sniper and heal modes. All numbers come from
# the resource: `damage` / `ability_range` = sniper shot, `heal_amount` = heal
# per shot, and one cooldown per mode (AbilitySystem reads `cooldown` after
# each execute, so execute sets it to the active mode's value).
@export var sniper_cooldown: float = 1.1
@export var heal_range: float = 150.0
@export var heal_cooldown: float = 1.4
## The heal staff's icon; `icon` is the rifle's. get_display_icon picks one.
@export var heal_icon: Texture2D
## River tree "Triple Shot": each sniper shot also hits up to this many other
## enemies within extra_target_radius of the main target (0 = single target).
@export var extra_targets: int = 0
@export var extra_target_radius: float = 160.0
## River capstone "Deadeye": every crit_every-th sniper shot deals crit_mult x
## its damage (to every target it hits). 0 = off.
@export var crit_every: int = 0
@export var crit_mult: float = 2.5
## River capstone "Chain Heal": each staff heal also heals this many of the
## most hurt other heroes within chain_heal_radius of the healed one (never
## River herself). 0 = off.
@export var extra_heal_targets: int = 0
@export var chain_heal_radius: float = 160.0

## Sniper shots fired by this copy (Deadeye's count).
var _sniper_shots: int = 0

func can_use(caster: Node2D) -> bool:
	return caster is EntityBase and (caster as EntityBase).is_alive()

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


## The HUD shows the weapon River holds: the staff's heal_icon while her
## weapon mode (River.get_weapon_mode) is the heal staff, else the rifle.
## Only reads the mode, never changes it.
func get_display_icon(caster: Node = null) -> Texture2D:
	if heal_icon != null and caster != null and caster.has_method("get_weapon_mode") \
			and caster.get_weapon_mode() == RiverActiveWeaponSwap.WeaponMode.HEAL_STAFF:
		return heal_icon
	return icon


func _execute_sniper(caster: Node2D, target: Node2D) -> void:
	if not is_instance_valid(target) or not is_instance_valid(caster):
		return

	var distance = caster.global_position.distance_to(target.global_position)
	if distance <= effective_range(caster):
		# Apply damage with modifier
		var damage_mult: float = 1.0
		var ability_system := caster.get_node_or_null("AbilitySystem") as AbilitySystem
		if ability_system:
			damage_mult = ability_system.get_damage_multiplier()

		var final_damage: float = damage * damage_mult
		_sniper_shots += 1
		if is_crit_shot():
			final_damage *= crit_mult
		EventBus.deal_damage(caster, target, final_damage, self)

		# Visual feedback
		_create_sniper_effect(caster, target)
		if extra_targets > 0:
			for extra in _extra_targets_near(caster, target):
				EventBus.deal_damage(caster, extra, final_damage, self)
				_create_sniper_effect(caster, extra)

		# Update cooldown to sniper speed
		cooldown = sniper_cooldown

## Deadeye: the last sniper shot was a crit_every-th one.
func is_crit_shot() -> bool:
	return crit_every > 0 and _sniper_shots > 0 and _sniper_shots % crit_every == 0

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
		# Ted's pet (group Hero, not a HeroBase) gets the swing but no HP.
		if target is HeroBase:
			(target as HeroBase).heal(heal_amount)
			if extra_heal_targets > 0:
				_chain_heal(caster, target as HeroBase)

		# Visual feedback
		_create_heal_effect(caster, target)
		
		# Update cooldown to heal speed
		cooldown = heal_cooldown

## Chain Heal: the `extra_heal_targets` most hurt living heroes (lowest HP
## fraction, below full) within chain_heal_radius of `healed`, other than it
## and River, get the same heal.
func _chain_heal(caster: Node2D, healed: HeroBase) -> void:
	var team := TeamRegistry.get_team(TeamRegistry.HEROES)
	if team == null:
		return
	var r_sq: float = chain_heal_radius * chain_heal_radius
	var hurt: Array[HeroBase] = []
	for ally in team.members:
		var hero := ally as HeroBase
		if hero == null or hero == healed or hero == caster or not hero.is_alive() \
				or hero.get_max_health() <= 0.0 or hero.get_health() >= hero.get_max_health() \
				or hero.global_position.distance_squared_to(healed.global_position) > r_sq:
			continue
		hurt.append(hero)
	hurt.sort_custom(func(a: HeroBase, b: HeroBase) -> bool:
		return a.get_health() / a.get_max_health() < b.get_health() / b.get_max_health())
	var tint: Color = UiPalette.get_default().river_light
	for hero in hurt.slice(0, extra_heal_targets):
		hero.heal(heal_amount)
		GameUtils.flash_line(caster.get_parent(), healed.global_position, hero.global_position, tint, 2.0, 0.4)

## F3: Deadeye's count toward the next crit.
func debug_line() -> String:
	var line := super.debug_line()
	if crit_every > 0:
		line += "  deadeye %d/%d" % [_sniper_shots % crit_every, crit_every]
	return line

func _create_sniper_effect(caster: Node2D, target: Node2D) -> void:
	GameUtils.flash_line(caster.get_parent(), caster.global_position, target.global_position, Color.ORANGE, 2.0, 0.3)

func _create_heal_effect(caster: Node2D, target: Node2D) -> void:
	GameUtils.flash_line(caster.get_parent(), caster.global_position, target.global_position, Color.GREEN, 3.0, 0.4)
