extends AbilityBase
class_name VladUltimateBloodBomb

func _init() -> void:
	ability_name = "Blood Bomb"
	ability_type = AbilityType.ULTIMATE
	damage = 40.0
	area_of_effect = 150.0
	cooldown = 20.0
	description = "Creates a devastating explosion that damages all enemies in range"

func execute(caster: Node2D, _target: Node2D = null, _override_damage: float = -1.0) -> void:
	# Find all entities in range
	var space_state = caster.get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = area_of_effect
	query.shape = shape
	query.transform = Transform2D(0, caster.global_position)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = GameUtils.MASK_HERO_TARGETS
	
	var results = space_state.intersect_shape(query, 32)
	var hit_entities: Array = []
	
	for result in results:
		var collider = result.collider
		var entity = null
		
		# Try to find the entity (might be Area2D or body)
		if collider.has_method("get_parent"):
			entity = collider.get_parent()
		elif collider.has_method("get_owner"):
			entity = collider.get_owner()
		else:
			entity = collider
		
		# Don't damage self
		if entity == caster:
			continue
		
		# Check if it's an enemy (dedupe: never hit one entity twice per cast)
		if entity and entity.is_in_group("Enemy") and not hit_entities.has(entity):
			hit_entities.append(entity)
			EventBus.deal_damage(caster, entity, damage, self)
