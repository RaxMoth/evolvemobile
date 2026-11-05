class_name BullRamDash
extends AbilityBase

## Entities this close to the bull's centre are hit as it passes.
const DASH_HIT_RADIUS: float = 40.0

@export var dash_distance: float = 300.0
@export var dash_speed: float = 500.0
## Not implemented: no entity has apply_knockback (see PROGRESS)
@export var knockback_force: float = 200.0
## A targeted dash ends this far in front of the target (Front Cleave range)
## instead of always travelling the full distance and overshooting by 200+ px.
@export var dash_stop_short: float = 40.0
## Grount tree "Stunning Charge": every entity the dash hits is stunned this
## long (0 = no stun).
@export var stun_duration: float = 0.0

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
	var facing: Vector2 = Vector2.from_angle((caster as EntityBase).sprite.rotation)
	dash_remaining = dash_distance
	if target and is_instance_valid(target):
		var to_t: Vector2 = target.global_position - caster.global_position
		dash_direction = to_t.normalized() if to_t.length_squared() > 0.01 else facing
		dash_remaining = clampf(to_t.length() - dash_stop_short, 0.0, dash_distance)
		if dash_remaining <= 0.0:
			# Point-blank (legacy fight logic casts at any range): ram through the
			# target instead of fizzling while the caller spends the cooldown.
			dash_remaining = minf(dash_distance, to_t.length() + dash_stop_short)
	else:
		dash_direction = facing
	if dash_remaining <= 0.0 or dash_direction == Vector2.ZERO:
		return
	
	is_dashing = true

	# Start dash process. One step per frame on pausable timers (the default,
	# process_always, kept a dash sliding under the match-result screen).
	caster.get_tree().create_timer(0.0, false).timeout.connect(_dash_update.bind(caster))

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
	_check_dash_collisions(caster)
	
	# Continue dashing
	if is_dashing:
		caster.get_tree().create_timer(0.0, false).timeout.connect(_dash_update.bind(caster))

## Hit every target within DASH_HIT_RADIUS of the bull, once per dash.
func _check_dash_collisions(caster: Node2D) -> void:
	for entity in GameUtils.entities_in_circle(caster.get_world_2d(), caster.global_position,
			DASH_HIT_RADIUS, GameUtils.MASK_MONSTER_TARGETS, true, caster):
		if _hit_entities.has(entity) or not GameUtils.can_entity_target(caster, entity):
			continue
		EventBus.deal_damage(caster, entity, _effective_damage, self)
		_hit_entities.append(entity)
		if stun_duration > 0.0 and entity is EntityBase:
			(entity as EntityBase).apply_stun(stun_duration)
