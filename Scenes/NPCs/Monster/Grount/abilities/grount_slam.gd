class_name BullGroundSlam
extends AbilityBase

@export var jump_duration: float = 1.0
@export var jump_height: float = 100.0
@export var slam_radius: float = 150.0

# Store effective damage for use in async slam
var _effective_damage: float = 0.0

func _init() -> void:
	ability_name = "Ground Slam"
	ability_type = AbilityType.ULTIMATE
	damage = 30.0
	area_of_effect = 150.0
	cooldown = 12.0
	description = "Leaps into the air and slams the ground"

func execute(caster: Node2D, target: Node2D = null, override_damage: float = -1.0) -> void:
	if not caster:
		return
	
	# Calculate effective damage
	_effective_damage = override_damage if override_damage >= 0.0 else damage
	
	var start_pos = caster.global_position
	var target_pos = start_pos
	
	# If target exists, jump toward them
	if target and is_instance_valid(target):
		var direction = (target.global_position - caster.global_position).normalized()
		target_pos = caster.global_position + direction * 150.0
	
	print(caster.name + " leaps into the air!")
	
	# Animate jump
	_perform_jump(caster, start_pos, target_pos)

func _perform_jump(caster: Node2D, start_pos: Vector2, target_pos: Vector2) -> void:
	# Jump animation using tween
	var tween = caster.create_tween()
	tween.set_parallel(true)
	
	# Move to target position
	tween.tween_property(caster, "global_position", target_pos, jump_duration)
	
	# Simulate vertical movement with scale/modulate
	var mid_tween = caster.create_tween()
	mid_tween.tween_property(caster, "scale", Vector2(1.2, 1.2), jump_duration * 0.5)
	mid_tween.tween_property(caster, "scale", Vector2(1.0, 1.0), jump_duration * 0.5)
	mid_tween.tween_property(caster, "modulate:a", 0.7, jump_duration * 0.5)
	mid_tween.tween_property(caster, "modulate:a", 1.0, jump_duration * 0.5)
	
	# Wait for jump to complete
	await caster.get_tree().create_timer(jump_duration).timeout
	
	# SLAM!
	_perform_slam(caster)

func _perform_slam(caster: Node2D) -> void:
	print(caster.name + " SLAMS the ground!")
	
	# Deal AOE damage
	var space_state = caster.get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = slam_radius
	query.shape = shape
	query.transform = Transform2D(0, caster.global_position)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var results = space_state.intersect_shape(query, 32)
	var hit_count = 0
	
	for result in results:
		var collider = result.collider
		var entity = Globals.get_entity_from_collider(collider)
		
		if entity == caster or not entity:
			continue
		
		# FIXED: Proper targeting - Heroes OR Mobs (but not other Monsters)
		var can_hit = false
		if entity.is_in_group("Hero"):
			can_hit = true
		elif entity.is_in_group("Enemy") and not entity.is_in_group("Monster"):
			can_hit = true # Hit Mobs
		
		if can_hit and entity.has_method("take_damage"):
			entity.take_damage(_effective_damage) # Use effective damage!
			hit_count += 1
	
	print("Ground Slam hit " + str(hit_count) + " enemies for " + str(_effective_damage) + " damage each!")
