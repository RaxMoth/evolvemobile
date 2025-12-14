class_name BullFrontCleave
extends AbilityBase

@export var cone_angle: float = 60.0
@export var cone_range: float = 80.0
@export var cone_angle_per_stage: Array[float] = [50.0, 60.0, 75.0]

func _init() -> void:
	ability_name = "Front Cleave"
	ability_type = AbilityType.ACTIVE
	damage = 15.0
	cooldown = 3.0
	description = "Attacks enemies in a frontal cone"

func apply_stage_stats(stage: int) -> void:
	super.apply_stage_stats(stage)
	if cone_angle_per_stage.size() >= stage and stage > 0:
		cone_angle = cone_angle_per_stage[stage - 1]

func execute(caster: Node2D, target: Node2D = null, override_damage: float = -1.0) -> void:
	var effective_damage = override_damage if override_damage >= 0.0 else damage
	
	var sprite = caster.get_node("Sprite2D")
	var forward_dir = Vector2.from_angle(sprite.rotation)
	
	var space_state = caster.get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = cone_range
	query.shape = shape
	query.transform = Transform2D(0, caster.global_position)
	query.collide_with_areas = true
	
	var results = space_state.intersect_shape(query, 32)

	var hit_count = 0
	var checked_entities: Array = [] # Track which actual entities we've checked
	
	for result in results:
		var collider = result.collider
		var entity = Globals.get_entity_from_collider(collider)
		
		if not entity or entity == caster:
			continue
		
		# Skip if we already checked this entity (multiple colliders per entity)
		if checked_entities.has(entity):
			continue
		
		checked_entities.append(entity)
		
		# Check if entity is in front cone
		var to_entity = (entity.global_position - caster.global_position).normalized()
		var angle_to_entity = forward_dir.angle_to(to_entity)
		
		if abs(angle_to_entity) > deg_to_rad(cone_angle / 2.0):
			print("║   ❌ NOT IN CONE")
			continue
		
		print("║   ✓ IN CONE")
		
		# Check targeting
		var can_hit = false
		if entity.is_in_group("Hero"):
			can_hit = true
			print("║   ✓ CAN HIT (Hero)")
		elif entity.is_in_group("Enemy") and not entity.is_in_group("Monster"):
			can_hit = true
			print("║   ✓ CAN HIT (Mob)")
		else:
			print("║   ❌ CANNOT HIT")
		
		if can_hit and entity.has_method("take_damage"):
			print("║   💥 DEALING ", effective_damage, " DAMAGE")
			entity.take_damage(effective_damage)
			hit_count += 1
			print("║   ✓ DAMAGE DEALT!")
		elif can_hit:
			print("║   ❌ No take_damage method!")

	print("║ RESULT: Hit ", hit_count, " enemies")
	
	_create_cleave_effect(caster, forward_dir)


func _create_cleave_effect(caster: Node2D, direction: Vector2) -> void:
	var effect = Node2D.new()
	caster.get_parent().add_child(effect)
	effect.global_position = caster.global_position
	effect.rotation = direction.angle()
	
	var tween = effect.create_tween()
	tween.tween_property(effect, "modulate:a", 0.0, 0.3)
	tween.tween_callback(effect.queue_free)
