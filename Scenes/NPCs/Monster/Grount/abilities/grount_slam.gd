class_name BullGroundSlam
extends AbilityBase

@export var jump_duration: float = 1.0
@export var jump_height: float = 100.0
@export var slam_radius: float = 150.0
## The leap lands on the target (up to this far) instead of always 150 px.
@export var leap_distance: float = 150.0
## Grount tree "Gravity Slam": enemies within this distance of the impact are
## dragged toward it before the damage lands (0 = off; the node adds 200).
@export var pull_radius: float = 0.0
## Pulled enemies stop this far from the impact instead of stacking on it.
## Kept outside MonsterStrategy.cornered_radius (70): a pull must not turn a
## farming monster's slam into a forced "Desperation" fight with heroes.
@export var pull_stop_distance: float = 80.0
## Every target the slam hits is stunned this long (0 = off): Gorrak's Warcry
## Stomp, the same rule as Ram Dash's Stunning Charge.
@export var stun_duration: float = 0.0

## F3 (MonsterBase.debug_meta_line): how many entities the last slam pulled.
var last_pull_count: int = 0

var _airborne: bool = false

# Store effective damage for use in async slam
var _effective_damage: float = 0.0

func _init() -> void:
	ability_name = "Ground Slam"
	ability_type = AbilityType.ULTIMATE
	damage = 30.0
	area_of_effect = 150.0
	cooldown = 12.0
	description = "Leaps into the air and slams the ground"

## Per-stage radius from aoe_per_stage (README: 120 at stage 2, 180 at stage 3),
## keeping any permanent "slam_radius" multiplier (Grount tree g3_slam).
func apply_stage_stats(stage: int) -> void:
	super.apply_stage_stats(stage)
	if area_of_effect > 0.0:
		slam_radius = _modified("slam_radius", area_of_effect)


func is_channeling() -> bool:
	return _airborne


## With Gravity Slam the enemies the pull brings in count as slam targets too.
func get_reach() -> float:
	return maxf(slam_radius, pull_radius)


## The leap lands on the target, at most leap_distance away (execute's rule
## before the wall clamp); leap_distance 0 stomps in place.
func get_cast_center(caster: Node2D, target: Node2D) -> Vector2:
	var to_t: Vector2 = target.global_position - caster.global_position
	if to_t.length() <= leap_distance:
		return target.global_position
	return caster.global_position + to_t.normalized() * leap_distance


func execute(caster: Node2D, target: Node2D = null, override_damage: float = -1.0) -> void:
	if not caster:
		return
	
	# Calculate effective damage
	_effective_damage = override_damage if override_damage >= 0.0 else damage
	
	var start_pos = caster.global_position
	var target_pos = start_pos
	
	# Leap onto the target (capped), never into a wall
	if target and is_instance_valid(target):
		var to_t: Vector2 = target.global_position - caster.global_position
		target_pos = start_pos + to_t.normalized() * minf(leap_distance, to_t.length())
	target_pos = GameUtils.clamp_to_nav_segment(caster.get_world_2d(), start_pos, target_pos)
	_airborne = true
	
	# Animate jump
	_perform_jump(caster, target_pos)

func _perform_jump(caster: Node2D, target_pos: Vector2) -> void:
	# Jump animation using tween
	var tween = caster.create_tween()
	tween.set_parallel(true)
	
	# Move to target position
	tween.tween_property(caster, "global_position", target_pos, jump_duration)
	
	# Simulate height on the SPRITE only: tweening the root scale reset an
	# evolved (1.25×/1.5×) monster back to 1.0.
	var vis: Node2D = (caster as EntityBase).visual_root() if caster is EntityBase else null
	if vis:
		var base: Vector2 = vis.scale
		var mid_tween := caster.create_tween()
		mid_tween.tween_property(vis, "scale", base * 1.2, jump_duration * 0.5)
		# self_modulate on a sprite: the evolution flash (GameUtils.flash_modulate)
		# owns `modulate` and ends it at WHITE, which would cut a mid-leap fade
		# short. A CharacterRig's own modulate has no other writer (its hurt
		# flash tints the body) and reaches the parts; its self_modulate would not.
		var alpha: NodePath = ^"modulate:a" if vis is CharacterRig else ^"self_modulate:a"
		mid_tween.parallel().tween_property(vis, alpha, 0.7, jump_duration * 0.5)
		mid_tween.tween_property(vis, "scale", base, jump_duration * 0.5)
		mid_tween.parallel().tween_property(vis, alpha, 1.0, jump_duration * 0.5)
	
	# Land when the jump completes: a pausable timer (the default, process_always,
	# slammed under the match-result screen while the leap tween stood frozen),
	# connected rather than awaited, so a timer still paused when the match is
	# left dies with this ability copy instead of resuming on a freed instance.
	caster.get_tree().create_timer(jump_duration, false).timeout.connect(_on_leap_landed.bind(caster))


func _on_leap_landed(caster: Node2D) -> void:
	if not is_instance_valid(caster) or not caster.is_inside_tree():
		_airborne = false
		return
	
	# SLAM!
	_perform_slam(caster)
	_airborne = false

func _perform_slam(caster: Node2D) -> void:
	# Gravity Slam first: the damage lands on the pulled positions.
	_pull_enemies(caster)
	for entity in GameUtils.entities_in_circle(caster.get_world_2d(), caster.global_position,
			slam_radius, GameUtils.MASK_MONSTER_TARGETS, true, caster):
		if GameUtils.can_entity_target(caster, entity):
			deal(caster, entity, _effective_damage)
			if stun_duration > 0.0 and entity is EntityBase:
				(entity as EntityBase).apply_stun(stun_duration)


## Gravity Slam: drag every living slam target within pull_radius of the impact
## toward it, stopping pull_stop_distance short and only along the navigation
## mesh (a wall or a corner stops the pull: GameUtils.clamp_to_nav_segment).
## Distances are centre to centre; anything already closer stays put. An idle
## camp mob pulled past its camp's edge is held at the edge by its own leash on
## its next tick; a hero mid-Dash is carried on by the dash tween.
func _pull_enemies(caster: Node2D) -> void:
	last_pull_count = 0
	if pull_radius <= 0.0:
		return
	var center: Vector2 = caster.global_position
	var world: World2D = caster.get_world_2d()
	var r_sq: float = pull_radius * pull_radius
	var stop_sq: float = pull_stop_distance * pull_stop_distance
	# hero_side (heroes + Ted's pet) and mobs: disjoint, de-duplicated lists,
	# so every entity moves at most once per slam.
	for e in EntityRegistry.targets_for(caster):
		if not is_instance_valid(e) or e == caster or e.is_queued_for_deletion() \
				or not GameUtils.can_entity_target(caster, e):
			continue
		if not EntityRegistry.is_entity_alive(e):
			continue  # corpses stay where they fell
		var off: Vector2 = e.global_position - center
		var d_sq: float = off.length_squared()
		if d_sq > r_sq or d_sq <= stop_sq:
			continue
		var wanted: Vector2 = center + off.normalized() * pull_stop_distance
		var dest: Vector2 = GameUtils.clamp_to_nav_segment(world, e.global_position, wanted)
		if dest.distance_squared_to(e.global_position) < 0.01:
			continue  # pinned against a wall: not moved
		if e is EntityBase:
			(e as EntityBase).displace_to(dest)
		else:
			e.global_position = dest  # Ted's pet (CharacterBody2D) re-paths every physics frame
		_sync_collision_transforms(e)
		last_pull_count += 1


## A moved node's collision shapes reach the physics server only at the next
## transform flush. Push them now, so the slam's overlap query right after the
## pull tests each target where the pull left it: one hit rule (its Body circle
## overlaps the slam circle) whether a target was pulled there or stood there.
## Ted's pet's CharacterBody2D still moves on the next physics step; its own
## "Body" Area2D carries the hit, and a pull only ever brings a target closer.
static func _sync_collision_transforms(node: Node) -> void:
	if node is CollisionObject2D:
		(node as CollisionObject2D).force_update_transform()
	for c in node.get_children():
		_sync_collision_transforms(c)
