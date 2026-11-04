extends AbilityBase
class_name RiverActiveWeaponSwap

## River's two weapons. The current mode lives only here, on River's own copy
## of this active (AbilitySystem.make_abilities_unique): River.get_weapon_mode()
## and RiverBasicAttack read it, and only execute() changes it.
enum WeaponMode {
	SNIPER,
	HEAL_STAFF
}

var current_mode: WeaponMode = WeaponMode.SNIPER

func execute(_caster: Node2D, _target: Node2D = null, _override_damage: float = -1.0) -> void:
	if current_mode == WeaponMode.SNIPER:
		current_mode = WeaponMode.HEAL_STAFF
	else:
		current_mode = WeaponMode.SNIPER

func get_current_mode() -> WeaponMode:
	return current_mode
