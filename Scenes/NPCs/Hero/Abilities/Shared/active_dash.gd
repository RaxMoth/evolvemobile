extends AbilityBase
class_name ActiveDash

var dash_direction: Vector2 = Vector2.ZERO

func _init() -> void:
	ability_name = "Dash"
	ability_type = AbilityType.ACTIVE
	range = 150.0  # Dash distance
	cooldown = 5.0
	duration = 0.2  # Dash duration

func execute(caster: Node2D, target: Node2D = null) -> void:
	# Dash in the direction the caster is facing
	var direction = Vector2.from_angle(caster.sprite.rotation) if "sprite" in caster else Vector2.RIGHT
	dash_direction = direction.normalized()
	
	# Create a tween for smooth dash
	var tween = caster.create_tween()
	tween.tween_property(caster, "global_position", 
		caster.global_position + dash_direction * range, duration)
	
	print(caster.name + " dashed!")
