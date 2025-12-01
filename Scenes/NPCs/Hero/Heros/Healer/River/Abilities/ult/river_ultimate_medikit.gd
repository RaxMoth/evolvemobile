extends AbilityBase
class_name RiverUltimateMediKit

@export var medikit_scene: PackedScene

func _init() -> void:
	ability_name = "Emergency Supply Drop"
	ability_type = AbilityType.ULTIMATE
	heal_amount = 30.0
	cooldown = 25.0
	description = "Drop a MediKit that heals allies who walk over it"

func can_use(_caster: Node2D) -> bool:
	return medikit_scene != null

func execute(caster: Node2D, _target: Node2D = null, _override_damage: float = -1.0) -> void:
	if not medikit_scene:
		push_error("MediKit scene not assigned!")
		return
	
	# Spawn MediKit at caster's position
	var medikit = medikit_scene.instantiate()
	caster.get_parent().add_child(medikit)
	medikit.global_position = caster.global_position
	
	# Set medikit properties
	if "heal_amount" in medikit:
		medikit.heal_amount = heal_amount
	if "detection_radius" in medikit:
		medikit.detection_radius = 60.0
	if "owner_entity" in medikit:
		medikit.owner_entity = caster
	
	# Visual drop effect
	_create_drop_effect(medikit)

func _create_drop_effect(medikit: Node2D) -> void:
	# Start above and drop down
	var start_pos = medikit.global_position
	medikit.global_position = start_pos + Vector2(0, -100)
	medikit.modulate = Color(1, 1, 1, 0)
	
	var tween = medikit.create_tween()
	tween.set_parallel(true)
	tween.tween_property(medikit, "global_position", start_pos, 0.5)
	tween.tween_property(medikit, "modulate:a", 1.0, 0.3)
	
	# Impact effect
	await medikit.get_tree().create_timer(0.5).timeout
	_create_impact_wave(medikit)

func _create_impact_wave(medikit: Node2D) -> void:
	var wave = Node2D.new()
	medikit.get_parent().add_child(wave)
	wave.global_position = medikit.global_position
	wave.z_index = -1
	
	# Draw expanding circle
	var circle = Line2D.new()
	wave.add_child(circle)
	circle.default_color = Color.GREEN
	circle.width = 2.0
	
	for i in range(33):
		var angle = i * TAU / 32
		circle.add_point(Vector2(cos(angle), sin(angle)) * 10)
	
	var tween = wave.create_tween()
	tween.set_parallel(true)
	tween.tween_property(wave, "scale", Vector2(6, 6), 0.4)
	tween.tween_property(circle, "modulate:a", 0.0, 0.4)
	tween.tween_callback(wave.queue_free)
