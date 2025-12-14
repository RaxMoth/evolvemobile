extends AbilityBase
class_name ActiveDash

var dash_direction: Vector2 = Vector2.ZERO
var dash_distance: float = 200.0 # Add explicit dash distance

func _init() -> void:
	ability_name = "Dash"
	ability_type = AbilityType.ACTIVE
	cooldown = 5.0
	duration = 0.2 # Dash duration
	ability_range = 200.0 # Set the dash range

func execute(caster: Node2D, target: Node2D = null, _override_damage: float = -1.0) -> void:
	var direction = Vector2.from_angle(caster.sprite.rotation) if "sprite" in caster else Vector2.RIGHT
	dash_direction = direction.normalized()
	var tween = caster.create_tween()
	tween.tween_property(caster, "global_position",
		caster.global_position + dash_direction * ability_range, duration) # ← Changed here
	
	print(caster.name + " dashed!")