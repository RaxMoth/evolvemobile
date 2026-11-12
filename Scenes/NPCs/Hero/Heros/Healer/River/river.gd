extends HeroBase
class_name River

@export_group("Healer Behavior")
## Heal targets at or below this HP fraction. River's blackboard query
## skips fully-healthy allies so she only swaps to staff for real injuries.
@export var heal_threshold_pct: float = 0.95
## Switch to the heal staff when an ally within heal_watch_range drops below
## this HP fraction; switch back to the sniper once every ally there is above
## sniper_return_pct (hysteresis so she does not flip-flop).
@export var heal_switch_pct: float = 0.6
@export var sniper_return_pct: float = 0.85
@export var heal_watch_range: float = 350.0

## Read by RiverBasicAttack.execute (a RiverActiveWeaponSwap.WeaponMode:
## 0 = sniper, 1 = heal staff). The mode lives only on this River's own copy
## of the Weapon Swap active, which flips it; without one she stays a sniper.
func get_weapon_mode() -> int:
	var swap: RiverActiveWeaponSwap = (ability_system.active_ability as RiverActiveWeaponSwap) if ability_system else null
	return swap.get_current_mode() if swap else RiverActiveWeaponSwap.WeaponMode.SNIPER

func _in_heal_mode() -> bool:
	return get_weapon_mode() == RiverActiveWeaponSwap.WeaponMode.HEAL_STAFF

## The heal staff's reach: heal_range of this River's own basic-attack copy.
## Ally selection and the heal itself use it unscaled; only the Fight gate
## (_get_attack_range) scales it with the attack_range upgrades.
func _heal_range() -> float:
	var basic: RiverBasicAttack = (ability_system.basic_attack as RiverBasicAttack) if ability_system else null
	return basic.heal_range if basic else 0.0

func _get_attack_range() -> float:
	# Mode ranges scale with the permanent attack_range upgrades (HeroStats).
	var mult: float = 1.0
	if stats and stats.base_stats and stats.base_stats.base_attack_range > 0.0:
		mult = stats.get_attack_range() / stats.base_stats.base_attack_range
	if _in_heal_mode():
		return _heal_range() * mult
	return 300.0 * mult

## The weapon swap IS River's active: decide from the team's health instead
## of "fire when fighting".
func _should_auto_use_active() -> bool:
	return _want_heal_mode() != _in_heal_mode()


func _use_active_now() -> void:
	# The swap needs no target (River may be between fights when an ally drops).
	if ability_system:
		ability_system.use_active(null)


func _want_heal_mode() -> bool:
	var team := TeamRegistry.get_team(TeamRegistry.HEROES)
	if team == null:
		return false
	var limit: float = sniper_return_pct if _in_heal_mode() else heal_switch_pct
	var r_sq := heal_watch_range * heal_watch_range
	for ally in team.members:
		if ally == self or not is_instance_valid(ally) or not (ally is HeroBase):
			continue
		var h := ally as HeroBase
		if not h.is_alive() or h.global_position.distance_squared_to(global_position) > r_sq:
			continue
		if h.get_max_health() > 0.0 and h.get_health() / h.get_max_health() < limit:
			return true
	return false


## Emergency Supply Drop: only when the kit would heal someone, a hero within
## its pickup radius of her (herself included) who misses at least its heal
## (RiverUltimateMediKit.count_reached). It used to go off on the enemy count
## around her target, with everyone at full HP.
func _should_auto_use_ultimate() -> bool:
	var kit: AbilityBase = ability_system.ultimate_ability if ability_system else null
	return kit != null and kit.count_reached(self, null, 1) >= 1


## The kit needs no target: she may drop it between fights.
func use_ultimate() -> bool:
	if not ability_system or not is_ultimate_ready():
		return false
	return ability_system.use_ultimate(target_entity as Node2D if is_target_valid() else null)


## Adaptive passive: the speed boost after taking damage.
func _get_move_speed() -> float:
	var base_speed := super._get_move_speed()
	var adaptive: RiverPassiveAdaptive = (ability_system.passive_ability as RiverPassiveAdaptive) if ability_system else null
	if adaptive:
		return base_speed * adaptive.get_speed_multiplier()
	return base_speed

func _on_fight_logic(_delta: float) -> void:
	if not ability_system:
		return
	
	match get_weapon_mode():
		RiverActiveWeaponSwap.WeaponMode.SNIPER:
			if is_target_valid() and target_entity.is_in_group("Enemy"):
				ability_system.use_basic_attack(target_entity)
		
		RiverActiveWeaponSwap.WeaponMode.HEAL_STAFF:
			var ally := _find_nearest_wounded_ally()
			if ally:
				ability_system.use_basic_attack(ally)

func _find_nearest_wounded_ally() -> Node2D:
	## Healer target selection via the team blackboard. Picks the lowest-HP
	## ally below heal_threshold_pct, then verifies they're in range.
	## Reading from the blackboard means we skip the per-call group walk
	## (the blackboard's `members` is maintained as entities register/exit).
	var team := TeamRegistry.get_team(TeamRegistry.HEROES)
	if team == null:
		return null
	var wounded := team.find_lowest_hp_ally(heal_threshold_pct, self)
	if wounded == null or not (wounded is Node2D):
		return null
	var w2d := wounded as Node2D
	if w2d.global_position.distance_to(global_position) > _heal_range():
		return null
	return w2d

func _on_approach_state_processing(delta: float) -> void:
	match get_weapon_mode():
		RiverActiveWeaponSwap.WeaponMode.SNIPER:
			super._on_approach_state_processing(delta)
		
		RiverActiveWeaponSwap.WeaponMode.HEAL_STAFF:
			var ally := _find_nearest_wounded_ally()
			if ally:
				var distance := global_position.distance_to(ally.global_position)
				if distance <= _heal_range():
					var dir: Vector2 = (ally.global_position - global_position).normalized()
					sprite.rotation = dir.angle()
				elif is_instance_valid(navigation_agent_2d):
					# Path to the ally: a straight line went through walls.
					_set_nav_target_lazy(ally.global_position)
					_steer_along_nav(move_speed, delta)
				else:
					move_toward_point(ally.global_position, move_speed, delta)
			else:
				super._on_approach_state_processing(delta)
