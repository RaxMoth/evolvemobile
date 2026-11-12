extends HeroBase
class_name River

@export_group("Healer Behavior")
## The staff heals allies below this HP fraction (_staff_patient), so a
## nearly healthy ally is not worth a swing.
@export var heal_threshold_pct: float = 0.95
## Switch to the heal staff when an ally within heal_watch_range drops below
## this HP fraction; switch back to the sniper once every ally there is above
## sniper_return_pct (hysteresis so she does not flip-flop).
@export var heal_switch_pct: float = 0.6
@export var sniper_return_pct: float = 0.85
@export var heal_watch_range: float = 350.0

## The rifle's reach on a fresh save (the README's 300; the attack_range
## upgrades scale it).
const SNIPER_RANGE: float = 300.0
## Staff mode: River walks toward her patient until it is within this fraction
## of the staff's heal_range, and heals as soon as it is within the range, so
## a patient on the move does not leave her stopping and starting at the edge.
const STAFF_CLOSE_IN: float = 0.8

## Read by RiverBasicAttack.execute (a RiverActiveWeaponSwap.WeaponMode:
## 0 = sniper, 1 = heal staff). The mode lives only on this River's own copy
## of the Weapon Swap active, which flips it; without one she stays a sniper.
func get_weapon_mode() -> int:
	var swap: RiverActiveWeaponSwap = (ability_system.active_ability as RiverActiveWeaponSwap) if ability_system else null
	return swap.get_current_mode() if swap else RiverActiveWeaponSwap.WeaponMode.SNIPER

func _in_heal_mode() -> bool:
	return get_weapon_mode() == RiverActiveWeaponSwap.WeaponMode.HEAL_STAFF

## The heal staff's reach: heal_range of this River's own basic-attack copy,
## unscaled (RiverBasicAttack._execute_heal checks the same number).
func _heal_range() -> float:
	var basic: RiverBasicAttack = (ability_system.basic_attack as RiverBasicAttack) if ability_system else null
	return basic.heal_range if basic else 0.0

## The Fight gate is the rifle's in both modes (300 px x the attack_range
## upgrades), so a swap never changes where she stands in a fight. The staff
## does not use it: in staff mode the patient decides (_staff_step). The staff
## mode used to return the heal range here, 150 px under her min_distance of
## 180, so the gate could never open and she neither healed nor shot.
func _get_attack_range() -> float:
	var mult: float = 1.0
	if stats and stats.base_stats and stats.base_stats.base_attack_range > 0.0:
		mult = stats.get_attack_range() / stats.base_stats.base_attack_range
	return SNIPER_RANGE * mult

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

## The rifle in a fight. The staff is never swung from here: in staff mode
## _staff_step serves the patient before the Fight logic runs, and without a
## patient she is about to swap back.
func _on_fight_logic(_delta: float) -> void:
	if ability_system and not _in_heal_mode() and is_target_valid() and target_entity.is_in_group("Enemy"):
		ability_system.use_basic_attack(target_entity)


## The staff's patient: the most hurt living hero (lowest HP fraction, below
## heal_threshold_pct) within heal_watch_range of River, never River herself
## (the staff heals others) or Ted's fox (no HeroBase); null when nobody there
## needs a heal.
func _staff_patient() -> HeroBase:
	var team := TeamRegistry.get_team(TeamRegistry.HEROES)
	if team == null:
		return null
	var best: HeroBase = null
	var best_pct: float = heal_threshold_pct
	var r_sq := heal_watch_range * heal_watch_range
	for ally in team.members:
		if ally == self or not is_instance_valid(ally) or not (ally is HeroBase):
			continue
		var hero := ally as HeroBase
		if not hero.is_alive() or hero.get_max_health() <= 0.0 \
				or hero.global_position.distance_squared_to(global_position) > r_sq:
			continue
		var pct: float = hero.get_health() / hero.get_max_health()
		if pct < best_pct:
			best_pct = pct
			best = hero
	return best


## Staff mode, in every state of her chart (Idle, Approach, Fight): the
## patient (_staff_patient) comes first. Further than STAFF_CLOSE_IN of the
## staff's reach she walks to it (along the navigation path); within the reach
## she heals it whenever the staff is ready (a flinch does not stop a heal),
## facing it while she stands. false = nobody to heal: the state's own logic
## runs (a fight goes on as with the rifle).
func _staff_step(delta: float) -> bool:
	var patient := _staff_patient()
	if patient == null:
		return false
	var to_patient: Vector2 = patient.global_position - global_position
	var distance: float = to_patient.length()
	var reach: float = _heal_range()
	if distance > reach * STAFF_CLOSE_IN:
		if is_instance_valid(navigation_agent_2d):
			_set_nav_target_lazy(patient.global_position)
			_steer_along_nav(move_speed, delta)
		else:
			move_toward_point(patient.global_position, move_speed, delta)
	else:
		_face(to_patient, delta)
	if distance <= reach and _is_attack_ready() and ability_system:
		ability_system.use_basic_attack(patient)
	return true


## Staff mode heals between fights too: she would otherwise walk into the next
## fight still holding the staff next to the ally she swapped for.
func _on_idle_state_processing(delta: float) -> void:
	if _in_heal_mode() and _staff_step(delta):
		# The idle goal is stale after the walk: pick a fresh one next tick.
		_idle_timer = 0.0
		return
	super._on_idle_state_processing(delta)


func _on_approach_state_processing(delta: float) -> void:
	if _in_heal_mode() and is_target_valid() and _staff_step(delta):
		return
	super._on_approach_state_processing(delta)


func _on_fight_state_processing(delta: float) -> void:
	if _in_heal_mode() and is_target_valid() and _staff_step(delta):
		return
	super._on_fight_state_processing(delta)
