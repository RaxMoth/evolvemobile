extends AbilityBase
class_name IreliaPassiveRegeneration

@export_group("Last Stand")
## hero_irelia capstone "Last Stand": once per match the hit that would kill
## Irelia leaves her at 1 HP instead (Irelia._survives_lethal_hit), and every
## hit for last_stand_duration seconds after it is canceled.
@export var last_stand: bool = false
@export var last_stand_duration: float = 2.0

## The one Last Stand of this copy (one per Irelia per match) is used up.
var _last_stand_spent: bool = false


func on_passive_update(caster: Node2D, delta: float) -> void:
	var hero := caster as HeroBase
	if not hero:
		return
	var current_health: float = hero.get_health()
	if current_health < hero.get_max_health() and current_health > 0.0:
		hero.heal(heal_amount * delta)


## Spends the Last Stand: true once per match while the node is equipped.
func claim_last_stand() -> bool:
	if not last_stand or _last_stand_spent:
		return false
	_last_stand_spent = true
	return true


func debug_line() -> String:
	var line := super.debug_line()
	if last_stand:
		line += "  last stand " + ("spent" if _last_stand_spent else "ready")
	return line
