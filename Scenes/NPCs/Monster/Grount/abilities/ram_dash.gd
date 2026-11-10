class_name BullRamDash
extends AbilityBase

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
## Entities this close to the bull's centre are hit as it passes: the half
## width of the lane the dash sweeps (was the const DASH_HIT_RADIUS).
@export var dash_hit_radius: float = 40.0

@export_group("Trample")
## Grount capstone "Trample": the dash sweeps a trample_hit_radius lane, and
## from trample_from_stage on it recharges in trample_cooldown_mult of its
## cooldown (x0.5: twice as fast). Off by default.
@export var trample: bool = false
@export var trample_hit_radius: float = 70.0
@export var trample_from_stage: int = 3
@export var trample_cooldown_mult: float = 0.5

@export_group("Echo Strike")
## Nyxa capstone "Echo Strike": a targeted dash turns at its end and runs back
## the length it came along the same lane, hitting everything again (the hit
## list is cleared). An escape dash (no target) never turns. Off by default.
@export var double_pass: bool = false

var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO
var dash_remaining: float = 0.0
var _effective_damage: float = 0.0 # Store effective damage for dash duration
var _hit_entities: Array = [] # Track entities already hit during this dash
## Echo Strike: the return pass is still to come (set by a targeted cast).
var _return_pending: bool = false
## Distance this pass moved so far: the length of the return pass.
var _travelled: float = 0.0

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


## Half width of the lane a dash hits: Trample's wider one when owned.
func get_hit_radius() -> float:
	return trample_hit_radius if trample else dash_hit_radius


## The stage's numbers, then Trample's faster recharge from its stage on (a
## locked dash keeps its parked cooldown).
func apply_stage_stats(stage: int) -> void:
	super.apply_stage_stats(stage)
	if trample and stage >= trample_from_stage and is_unlocked_at(stage):
		cooldown *= trample_cooldown_mult

func execute(caster: Node2D, target: Node2D = null, override_damage: float = -1.0) -> void:
	if not caster or is_dashing:
		return
	
	# Calculate effective damage
	_effective_damage = override_damage if override_damage >= 0.0 else damage
	_hit_entities.clear() # Reset hit tracking
	_travelled = 0.0
	_return_pending = double_pass and target != null and is_instance_valid(target)
	
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
	# Presentation: the lane and the trail (AbilityVfx).
	EventBus.notify_ability_event(caster, self, FxEvents.DASH_STARTED,
			caster.global_position + dash_direction * dash_remaining, get_hit_radius())

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
	_travelled += old_pos.distance_to(new_pos)
	if new_pos.distance_squared_to(wanted) > 0.01:
		is_dashing = false  # hit a wall
	
	# Check for collisions during dash
	_check_dash_collisions(caster)
	if not is_dashing and _return_pending:
		_begin_return_pass()
		if is_dashing:
			EventBus.notify_ability_event(caster, self, FxEvents.DASH_TURNED,
					caster.global_position + dash_direction * dash_remaining, get_hit_radius())
	if not is_dashing:
		EventBus.notify_ability_event(caster, self, FxEvents.DASH_ENDED, caster.global_position)
	
	# Continue dashing
	if is_dashing:
		caster.get_tree().create_timer(0.0, false).timeout.connect(_dash_update.bind(caster))

## Echo Strike: turn around and run back the distance this pass travelled,
## along the same lane, with a fresh hit list (the target is passed again).
func _begin_return_pass() -> void:
	_return_pending = false
	dash_direction = -dash_direction
	dash_remaining = _travelled
	_travelled = 0.0
	_hit_entities.clear()
	is_dashing = dash_remaining > 0.0


## Hit every target within get_hit_radius() of the bull, once per pass.
func _check_dash_collisions(caster: Node2D) -> void:
	for entity in GameUtils.entities_in_circle(caster.get_world_2d(), caster.global_position,
			get_hit_radius(), GameUtils.MASK_MONSTER_TARGETS, true, caster):
		if _hit_entities.has(entity) or not GameUtils.can_entity_target(caster, entity):
			continue
		deal(caster, entity, _effective_damage)
		_hit_entities.append(entity)
		if stun_duration > 0.0 and entity is EntityBase:
			(entity as EntityBase).apply_stun(stun_duration)
			EventBus.notify_ability_event(entity, self, FxEvents.STUNNED, entity.global_position, stun_duration)


## F3 (MonsterBase.debug_meta_line): the capstones this dash carries; "" on
## a fresh save.
func debug_tag() -> String:
	var tags: PackedStringArray = []
	if trample:
		tags.append("trample %d px" % roundi(get_hit_radius()))
	if double_pass:
		tags.append("echo")
	return " ".join(tags)
