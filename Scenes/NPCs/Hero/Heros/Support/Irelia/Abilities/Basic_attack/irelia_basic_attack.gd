extends BasicStrike
class_name IreliaBasicAttack

## Taunting strike: flat threat added on the struck enemy's threat table per
## hit (on top of damage × taunt_strength). Without it a 5-damage tank never
## out-threatened the DPS, so mob packs stayed on whoever pulled them.
@export var taunt_threat: float = 40.0

func _on_hit(caster: Node2D, target: Node2D) -> void:
	if taunt_threat > 0.0 and is_instance_valid(target):
		var team: TeamBlackboard = TeamRegistry.team_of(target)
		if team:
			team.bump_threat(target, caster, taunt_threat)
