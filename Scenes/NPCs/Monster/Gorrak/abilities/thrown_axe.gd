class_name ThrownAxe
extends AbilityBase

## Gorrak's Tusk Axe: a spinning axe flies from him toward the target, up to
## `ability_range` px at `axe_speed`, and hits every target within
## `hit_radius` of it once. Walls stop the outbound flight early (the
## navigation-mesh segment clamp, like Ram Dash). With `returns` it then flies
## back to his hand and can hit each target once more on the way back.
## `stun_duration` (0 = off; the tree's Concussive Axe) stuns every target it
## hits.
##
## Not a node and not a timer: a point that moves. MonsterBase._process steps
## it through tick_active on the monster's own copy, one overlap query per
## frame while it flies. It cannot be thrown again while it flies (can_use).
## VfxManager draws the spinning axe at axe_position and MonsterBase's F3 line
## reads debug_tag(); neither writes anything here.

@export var axe_speed: float = 520.0
@export var hit_radius: float = 28.0
@export var returns: bool = true
## Every target the axe hits is stunned this long (0 = off).
@export var stun_duration: float = 0.0

## World position of the axe while it flies (VfxManager reads it).
var axe_position: Vector2 = Vector2.ZERO
var _flying: bool = false
var _returning: bool = false
var _travel_left: float = 0.0
var _dir: Vector2 = Vector2.RIGHT
var _axe_damage: float = 0.0
## Targets hit on the current leg (out, then back): each once per leg.
var _hit: Array[Node2D] = []


func _init() -> void:
	ability_name = "Tusk Axe"
	ability_type = AbilityType.ACTIVE
	damage = 10.0
	ability_range = 260.0
	cooldown = 7.0
	description = "Throws a spinning axe that flies out and back"


func is_flying() -> bool:
	return _flying


## True on the way back to his hand.
func is_returning() -> bool:
	return _flying and _returning


## The outbound direction of the last throw (a unit vector).
func direction() -> Vector2:
	return _dir


## The axe is in the air: no second throw until it is back.
func can_use(_caster: Node2D) -> bool:
	return not _flying


## Thrown at the target (else along the caster's facing), from the caster.
func execute(caster: Node2D, target: Node2D = null, override_damage: float = -1.0) -> void:
	_axe_damage = override_damage if override_damage >= 0.0 else damage
	_dir = Vector2.from_angle((caster as EntityBase).sprite.rotation)
	if target != null and is_instance_valid(target):
		var to_t: Vector2 = target.global_position - caster.global_position
		if to_t.length_squared() > 0.01:
			_dir = to_t.normalized()
	axe_position = caster.global_position
	_travel_left = ability_range
	_returning = false
	_hit.clear()
	_flying = true


func tick_active(caster: Node2D, delta: float) -> void:
	if not _flying:
		return
	if not is_instance_valid(caster) or not (caster as EntityBase).is_alive():
		_flying = false
		return
	var step: float = axe_speed * delta
	if not _returning:
		var move: float = minf(step, _travel_left)
		var wanted: Vector2 = axe_position + _dir * move
		var new_pos: Vector2 = GameUtils.clamp_to_nav_segment(caster.get_world_2d(), axe_position, wanted)
		_travel_left -= move
		var blocked: bool = new_pos.distance_squared_to(wanted) > 0.01
		axe_position = new_pos
		_hit_around(caster)
		if _travel_left <= 0.0 or blocked:
			if not returns:
				_flying = false
				return
			_returning = true
			_hit.clear()
	else:
		var to_c: Vector2 = caster.global_position - axe_position
		if to_c.length() <= step:
			axe_position = caster.global_position
			_flying = false
			return
		axe_position += to_c.normalized() * step
		_hit_around(caster)


func _hit_around(caster: Node2D) -> void:
	for entity in GameUtils.entities_in_circle(caster.get_world_2d(), axe_position, hit_radius,
			GameUtils.MASK_MONSTER_TARGETS, true, caster):
		if _hit.has(entity) or not GameUtils.can_entity_target(caster, entity):
			continue
		_hit.append(entity)
		deal(caster, entity, _axe_damage)
		if stun_duration > 0.0 and entity is EntityBase:
			(entity as EntityBase).apply_stun(stun_duration)


## F3 (MonsterBase.debug_meta_line): where the axe is ("!" = flying).
func debug_tag() -> String:
	if not _flying:
		return "axe in hand"
	return "axe! flying back" if _returning else "axe! flying out"
