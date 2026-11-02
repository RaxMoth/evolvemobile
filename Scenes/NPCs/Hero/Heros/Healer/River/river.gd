extends HeroBase
class_name River

enum WeaponMode {
	SNIPER,
	HEAL_STAFF
}

@export_group("Healer Behavior")
## Heal targets at or below this HP fraction. River's blackboard query
## skips fully-healthy allies so she only swaps to staff for real injuries.
@export var heal_threshold_pct: float = 0.95
## Maximum range to consider an ally for healing.
@export var heal_max_range: float = 150.0
## Switch to the heal staff when an ally within heal_watch_range drops below
## this HP fraction; switch back to the sniper once every ally there is above
## sniper_return_pct (hysteresis so she does not flip-flop).
@export var heal_switch_pct: float = 0.6
@export var sniper_return_pct: float = 0.85
@export var heal_watch_range: float = 350.0

var current_weapon_mode: WeaponMode = WeaponMode.SNIPER

func _ready() -> void:
	# Healer archetype: don't pull threat through healing. The default 1.0
	# is fine; lower could be set if heals start aggro-ing in playtests.
	super._ready()

	if ability_system and ability_system.active_ability:
		ability_system.ability_used.connect(_on_ability_used)

func _on_ability_used(ability: AbilityBase) -> void:
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
	if not ability_system:
		return

## Read by RiverBasicAttack.execute (0 = sniper, 1 = heal staff). Without it
## the basic attack returned early and River never fired or healed.
func get_weapon_mode() -> int:
	return int(current_weapon_mode)

func _get_attack_range() -> float:
	# Mode ranges scale with the permanent attack_range upgrades (HeroStats).
	var mult: float = 1.0
	if stats and stats.base_stats and stats.base_stats.base_attack_range > 0.0:
		mult = stats.get_attack_range() / stats.base_stats.base_attack_range
	match current_weapon_mode:
		WeaponMode.HEAL_STAFF:
			return heal_max_range * mult
		_:
			return 300.0 * mult

## The weapon swap IS River's active: decide from the team's health instead
## of "fire when fighting".
func _should_auto_use_active() -> bool:
	return _want_heal_mode() != (current_weapon_mode == WeaponMode.HEAL_STAFF)


func _use_active_now() -> void:
	# The swap needs no target (River may be between fights when an ally drops).
	if ability_system:
		ability_system.use_active(null)


func _want_heal_mode() -> bool:
	var team := TeamRegistry.get_team(TeamRegistry.HEROES)
	if team == null:
		return false
	var limit: float = sniper_return_pct if current_weapon_mode == WeaponMode.HEAL_STAFF else heal_switch_pct
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


func _get_move_speed() -> float:
	var base_speed = super._get_move_speed()

	if ability_system and ability_system.passive_ability:
		if ability_system.passive_ability.has_method("get_speed_multiplier"):
			var multiplier = ability_system.passive_ability.get_speed_multiplier()
			return base_speed * multiplier
	
	return base_speed

func _on_fight_logic(delta: float) -> void:
	if not ability_system:
		return
	
	match current_weapon_mode:
		WeaponMode.SNIPER:
			if is_target_valid() and target_entity.is_in_group("Enemy"):
				ability_system.use_basic_attack(target_entity)
		
		WeaponMode.HEAL_STAFF:
			var ally = _find_nearest_wounded_ally()
			if ally:
				ability_system.use_basic_attack(ally)
			else:
				pass

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
	if w2d.global_position.distance_to(global_position) > heal_max_range:
		return null
	return w2d

func _on_approach_state_processing(delta: float) -> void:
	match current_weapon_mode:
		WeaponMode.SNIPER:
			super._on_approach_state_processing(delta)
		
		WeaponMode.HEAL_STAFF:
			var ally = _find_nearest_wounded_ally()
			if ally:
				var distance = global_position.distance_to(ally.global_position)
				if distance <= 150.0:
					var dir: Vector2 = (ally.global_position - global_position).normalized()
					sprite.rotation = dir.angle()
				else:
					move_toward_point(ally.global_position, move_speed, delta)
			else:
				super._on_approach_state_processing(delta)
