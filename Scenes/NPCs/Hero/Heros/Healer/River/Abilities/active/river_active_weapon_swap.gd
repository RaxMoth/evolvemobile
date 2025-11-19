extends AbilityBase
class_name RiverActiveWeaponSwap

enum WeaponMode {
	SNIPER,
	HEAL_STAFF
}

var current_mode: WeaponMode = WeaponMode.SNIPER

func _init() -> void:
	ability_name = "Weapon Swap"
	ability_type = AbilityType.ACTIVE
	cooldown = 1.0  # Short cooldown for quick swapping
	description = "Swap between Sniper Rifle (long range damage) and Heal Staff (heal allies)"

func execute(caster: Node2D, _target: Node2D = null) -> void:
	if current_mode == WeaponMode.SNIPER:
		current_mode = WeaponMode.HEAL_STAFF
	else:
		current_mode = WeaponMode.SNIPER
	
	_update_caster_weapon(caster)

func _update_caster_weapon(caster: Node2D) -> void:
	if not caster.has_node("AbilitySystem"):
		return
	
	var ability_system = caster.get_node("AbilitySystem")
	
	# Swap the basic attack based on mode
	match current_mode:
		WeaponMode.SNIPER:
			# Will use sniper attack
			if caster.has_method("set_weapon_mode"):
				caster.set_weapon_mode("sniper")
		WeaponMode.HEAL_STAFF:
			# Will use heal staff
			if caster.has_method("set_weapon_mode"):
				caster.set_weapon_mode("heal_staff")

func get_current_mode() -> WeaponMode:
	return current_mode

func is_sniper_mode() -> bool:
	return current_mode == WeaponMode.SNIPER

func is_heal_mode() -> bool:
	return current_mode == WeaponMode.HEAL_STAFF
