class_name BullRamDash
extends AbilityBase

@export var dash_distance: float = 300.0
@export var dash_speed: float = 500.0
@export var knockback_force: float = 200.0

var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO
var dash_remaining: float = 0.0

func _init() -> void:
	ability_name = "Ram Dash"
	ability_type = AbilityType.ACTIVE
	damage = 20.0
	cooldown = 8.0
	description = "Charges forward, damaging and knocking back enemies"

func can_use(caster: Node2D) -> bool:
	return not is_dashing

func execute(caster: Node2D, target: Node2D = null) -> void:
	if not caster or is_dashing:
		return
	
	# Determine dash direction (toward target or forward)
	if target and is_instance_valid(target):
		dash_direction = (target.global_position - caster.global_position).normalized()
	else:
		dash_direction = Vector2.from_angle(caster.sprite.rotation)
	
	is_dashing = true
	dash_remaining = dash_distance
	
	# Start dash process
	caster.get_tree().create_timer(0.0).timeout.connect(_dash_update.bind(caster))
	
	print(caster.name + " charges forward!")

func _dash_update(caster: Node2D) -> void:
	if not is_dashing or not is_instance_valid(caster):
		is_dashing = false
		return
	
	var delta = caster.get_process_delta_time()
	var move_amount = dash_speed * delta
	
	if move_amount >= dash_remaining:
		move_amount = dash_remaining
		is_dashing = false
	
	# Move bull
	var old_pos = caster.global_position
	caster.global_position += dash_direction * move_amount
	dash_remaining -= move_amount
	
	# Check for collisions during dash
	_check_dash_collisions(caster, old_pos)
	
	# Continue dashing
	if is_dashing:
		caster.get_tree().create_timer(0.0).timeout.connect(_dash_update.bind(caster))

func _check_dash_collisions(caster: Node2D, previous_pos: Vector2) -> void:
	# Check for entities hit during dash
	var space_state = caster.get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 40.0  # Hit radius during dash
	query.shape = shape
	query.transform = Transform2D(0, caster.global_position)
	query.collide_with_areas = true
	
	var results = space_state.intersect_shape(query, 32)
	
	for result in results:
		var collider = result.collider
		var entity = _get_entity(collider)
		
		if entity == caster or not entity:
			continue
		
		if entity.is_in_group("Enemy") and entity.has_method("take_damage"):
			entity.take_damage(damage)
			
			# Apply knockback
			if entity.has_method("apply_knockback"):
				entity.apply_knockback(dash_direction * knockback_force)
			
			print(caster.name + " rammed " + entity.name + "!")

func _get_entity(collider: Node) -> Node:
	if collider.has_method("get_parent"):
		return collider.get_parent()
	elif collider.has_method("get_owner"):
		return collider.get_owner()
	return collider
