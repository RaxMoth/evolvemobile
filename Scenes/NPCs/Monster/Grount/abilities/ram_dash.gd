class_name BullRamDash
extends AbilityBase

@export var dash_distance: float = 300.0
@export var dash_speed: float = 500.0
@export var knockback_force: float = 200.0
## A targeted dash ends this far in front of the target (Front Cleave range)
## instead of always travelling the full distance and overshooting by 200+ px.
@export var dash_stop_short: float = 40.0

var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO
var dash_remaining: float = 0.0
var _effective_damage: float = 0.0 # Store effective damage for dash duration
var _hit_entities: Array = [] # Track entities already hit during this dash

func _init() -> void:
	ability_name = "Ram Dash"
	ability_type = AbilityType.ACTIVE
	damage = 20.0
	cooldown = 8.0
	description = "Charges forward, damaging and knocking back enemies"

func can_use(_caster: Node2D) -> bool:
	return not is_dashing

func is_channeling() -> bool:
	return is_dashing

func get_reach() -> float:
	return dash_distance + dash_stop_short

func execute(caster: Node2D, target: Node2D = null, override_damage: float = -1.0) -> void:
	if not caster or is_dashing:
		return
	
	# Calculate effective damage
	_effective_damage = override_damage if override_damage >= 0.0 else damage
	_hit_entities.clear() # Reset hit tracking
	
	# Toward the target (stopping short), or along the facing for an escape dash.
	dash_remaining = dash_distance
	if target and is_instance_valid(target):
		var to_t: Vector2 = target.global_position - caster.global_position
		dash_direction = to_t.normalized()
		dash_remaining = clampf(to_t.length() - dash_stop_short, 0.0, dash_distance)
	else:
		dash_direction = Vector2.from_angle(caster.sprite.rotation)
	if dash_remaining <= 0.0 or dash_direction == Vector2.ZERO:
		return
	
	is_dashing = true

	# Start dash process
	caster.get_tree().create_timer(0.0).timeout.connect(_dash_update.bind(caster))

func _dash_update(caster: Node2D) -> void:
	if not is_dashing or not is_instance_valid(caster):
		is_dashing = false
		return
	
	var delta = caster.get_process_delta_time()
	var move_amount = dash_speed * delta
	
	if move_amount >= dash_remaining:
		move_amount = dash_remaining
		is_dashing = false
	
	# Move bull — never off the navigation mesh (a wall stops the dash)
	var old_pos: Vector2 = caster.global_position
	var wanted: Vector2 = old_pos + dash_direction * move_amount
	var new_pos: Vector2 = GameUtils.clamp_to_nav_segment(caster.get_world_2d(), old_pos, wanted)
	caster.global_position = new_pos
	dash_remaining -= move_amount
	if new_pos.distance_squared_to(wanted) > 0.01:
		is_dashing = false  # hit a wall
	
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
	shape.radius = 40.0 # Hit radius during dash
	query.shape = shape
	query.transform = Transform2D(0, caster.global_position)
	query.collide_with_areas = true
	# Bodies too: Ted's pet is a CharacterBody2D on LAYER_BODY_HERO (entity roots are
	# plain Node2Ds, so it is the only physics body these masks can return).
	query.collide_with_bodies = true
	query.collision_mask = GameUtils.MASK_MONSTER_TARGETS
	
	var results = space_state.intersect_shape(query, 32)
	
	for result in results:
		var collider = result.collider
		var entity = Globals.get_entity_from_collider(collider)
		
		if entity == caster or not entity:
			continue
		
		# Don't hit the same entity twice during one dash
		if _hit_entities.has(entity):
			continue
		
		# FIXED: Proper targeting - Heroes OR Mobs (but not other Monsters)
		var can_hit = false
		if entity.is_in_group("Hero"):
			can_hit = true
		elif entity.is_in_group("Enemy") and not entity.is_in_group("Monster"):
			can_hit = true # Hit Mobs
		
		if can_hit:
			EventBus.deal_damage(caster, entity, _effective_damage, self)
			_hit_entities.append(entity) # Mark as hit

			# Apply knockback
			if entity.has_method("apply_knockback"):
				entity.apply_knockback(dash_direction * knockback_force)
