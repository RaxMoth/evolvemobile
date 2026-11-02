class_name BullGroundSlam
extends AbilityBase

@export var jump_duration: float = 1.0
@export var jump_height: float = 100.0
@export var slam_radius: float = 150.0
## The leap lands on the target (up to this far) instead of always 150 px.
@export var leap_distance: float = 150.0

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


func get_reach() -> float:
	return slam_radius


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
	Globals.debug_log(caster.name, " leaps into the air!")
	
	# Animate jump
	_perform_jump(caster, start_pos, target_pos)

func _perform_jump(caster: Node2D, start_pos: Vector2, target_pos: Vector2) -> void:
	# Jump animation using tween
	var tween = caster.create_tween()
	tween.set_parallel(true)
	
	# Move to target position
	tween.tween_property(caster, "global_position", target_pos, jump_duration)
	
	# Simulate height on the SPRITE only: tweening the root scale reset an
	# evolved (1.25×/1.5×) monster back to 1.0.
	var vis: Node2D = caster.get_node_or_null(^"AnimatedSprite2D") as Node2D
	if vis:
		var base: Vector2 = vis.scale
		var mid_tween := caster.create_tween()
		mid_tween.tween_property(vis, "scale", base * 1.2, jump_duration * 0.5)
		mid_tween.parallel().tween_property(vis, "modulate:a", 0.7, jump_duration * 0.5)
		mid_tween.tween_property(vis, "scale", base, jump_duration * 0.5)
		mid_tween.parallel().tween_property(vis, "modulate:a", 1.0, jump_duration * 0.5)
	
	# Wait for jump to complete
	var tree := caster.get_tree()
	await tree.create_timer(jump_duration).timeout
	if not is_instance_valid(caster) or not caster.is_inside_tree():
		_airborne = false
		return
	
	# SLAM!
	_perform_slam(caster)
	_airborne = false

func _perform_slam(caster: Node2D) -> void:
	Globals.debug_log(caster.name, " SLAMS the ground!")
	
	# Deal AOE damage
	var space_state = caster.get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = slam_radius
	query.shape = shape
	query.transform = Transform2D(0, caster.global_position)
	query.collide_with_areas = true
	# Bodies too: Ted's pet is a CharacterBody2D on LAYER_BODY_HERO (entity roots are
	# plain Node2Ds, so it is the only physics body these masks can return).
	query.collide_with_bodies = true
	query.collision_mask = GameUtils.MASK_MONSTER_TARGETS
	
	var results = space_state.intersect_shape(query, 32)
	var hit_count = 0
	var hit_entities: Array = []
	
	for result in results:
		var collider = result.collider
		var entity = Globals.get_entity_from_collider(collider)
		
		if entity == caster or not entity or hit_entities.has(entity):
			continue
		hit_entities.append(entity)
		
		# FIXED: Proper targeting - Heroes OR Mobs (but not other Monsters)
		var can_hit = false
		if entity.is_in_group("Hero"):
			can_hit = true
		elif entity.is_in_group("Enemy") and not entity.is_in_group("Monster"):
			can_hit = true # Hit Mobs
		
		if can_hit:
			EventBus.deal_damage(caster, entity, _effective_damage, self)
			hit_count += 1
