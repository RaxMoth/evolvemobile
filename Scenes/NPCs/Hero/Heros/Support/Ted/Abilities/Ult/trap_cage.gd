extends Area2D
class_name TrapCage

@export var duration: float = 6.0
@export var cage_radius: float = 150.0
## Spiked Cage (TedUltimateTrapCage.cage_dps): every SPIKE_INTERVAL the
## enemies overlapping the cage take cage_dps x SPIKE_INTERVAL. 0 = no spikes.
@export var cage_dps: float = 0.0
const SPIKE_INTERVAL: float = 1.0

## The caster and ability the spikes deal for (set before _ready).
var source: Node2D = null
var source_ability: AbilityBase = null
var _spike_timer: float = 0.0

var trapped_enemies: Array[Node2D] = []  # Already typed correctly
var cage_active: bool = true
## enemy -> life_id at trap time. A pooled mob that died and respawned keeps
## the same node but a new life_id, so the cage must stop acting on it.
var _trapped_life_ids: Dictionary = {}
var _sprite_tweens: Dictionary = {}  # enemy -> looping flash Tween, killed on expire

func _ready() -> void:
	# Setup collision
	var collision_shape = $CollisionShape2D
	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = cage_radius
	
	# Visual
	queue_redraw()
	
	# body_exited / area_exited are wired in TrapCage.tscn.
	
	# Initial scan for enemies
	_scan_for_enemies()
	
	# Expire after duration
	await get_tree().create_timer(duration).timeout
	_expire()

func _draw() -> void:
	if not cage_active:
		return
	
	# Draw cage bars
	var num_bars = 16
	for i in range(num_bars):
		var angle = i * TAU / num_bars
		var start = Vector2(cos(angle), sin(angle)) * (cage_radius - 10)
		var end = Vector2(cos(angle), sin(angle)) * cage_radius
		draw_line(start, end, Color(0.8, 0.3, 0.3), 4.0)
	
	# Draw circle outline
	draw_arc(Vector2.ZERO, cage_radius, 0, TAU, 64, Color.RED, 2.0)
	draw_arc(Vector2.ZERO, cage_radius - 10, 0, TAU, 64, Color(1, 0.5, 0.5, 0.5), 1.0)

func _process(delta: float) -> void:
	if not cage_active:
		return
	if cage_dps > 0.0:
		_spike_timer += delta
		while _spike_timer >= SPIKE_INTERVAL:
			_spike_timer -= SPIKE_INTERVAL
			_spike()
	
	# Force trapped enemies to stay inside
	for enemy in trapped_enemies:
		if not _still_trapped(enemy):
			continue
		
		var dist = enemy.global_position.distance_to(global_position)
		if dist > cage_radius - 15:
			# Push back inside, at the edge it tried to leave by (the push
			# used to mirror it to the opposite side of the cage).
			var dir: Vector2 = (enemy.global_position - global_position).normalized()
			var push_pos = global_position + dir * (cage_radius - 20)
			# Never through a wall (the push teleports).
			enemy.global_position = GameUtils.clamp_to_nav_segment(get_world_2d(), enemy.global_position, push_pos)

## One Spiked Cage tick: every valid enemy whose body overlaps the cage, once.
func _spike() -> void:
	var src: Node2D = source if is_instance_valid(source) else null
	var hit: Dictionary[Node2D, bool] = {}
	for area in get_overlapping_areas():
		var entity := _get_entity(area) as EntityBase
		if entity == null or hit.has(entity) or not _is_valid_target(entity):
			continue
		hit[entity] = true
		var amount: float = cage_dps * SPIKE_INTERVAL
		if source_ability:
			source_ability.deal(src, entity, amount)
		else:
			EventBus.deal_damage(src, entity, amount)

func _scan_for_enemies() -> void:
	# Runs once, from _ready: entities_in_circle returns each entity once.
	for node in GameUtils.entities_in_circle(get_world_2d(), global_position, cage_radius,
			GameUtils.MASK_HERO_TARGETS, false):
		var entity := node as EntityBase
		if entity and _is_valid_target(entity):
			trapped_enemies.append(entity)
			_trapped_life_ids[entity] = entity.get("life_id")
			_apply_trap_effect(entity)

func _on_body_exited(body: Node2D) -> void:
	_prevent_exit(body)

func _on_area_exited(area: Area2D) -> void:
	_prevent_exit(area.get_parent() if area.get_parent() is Node2D else null)

func _prevent_exit(node: Node) -> void:
	if not cage_active or not node:
		return
	
	var entity = _get_entity(node)
	
	# FIXED: Check if entity is Node2D before checking array
	if entity and entity is Node2D and trapped_enemies.has(entity) and _still_trapped(entity):
		# Teleport back to center of cage
		entity.global_position = global_position

func _apply_trap_effect(entity: Node2D) -> void:
	# Visual indicator that enemy is trapped
	if entity.has_node("Sprite2D"):
		var sprite = entity.get_node("Sprite2D")
		var original_modulate = sprite.modulate
		
		var tween = sprite.create_tween()
		_sprite_tweens[entity] = tween
		tween.set_loops()
		tween.tween_property(sprite, "modulate", Color(1, 0.5, 0.5), 0.5)
		tween.tween_property(sprite, "modulate", original_modulate, 0.5)

func _still_trapped(enemy: Node2D) -> bool:
	# Same node, same life, still in the tree. Otherwise drop its flash tween.
	if is_instance_valid(enemy) and enemy.is_inside_tree() \
			and enemy.get("life_id") == _trapped_life_ids.get(enemy):
		return true
	_kill_sprite_tween(enemy)
	return false

func _kill_sprite_tween(enemy: Node2D) -> void:
	if _sprite_tweens.has(enemy):
		var tween: Tween = _sprite_tweens[enemy]
		if tween and tween.is_valid():
			tween.kill()
		_sprite_tweens.erase(enemy)

func _is_valid_target(entity: EntityBase) -> bool:
	if not entity.is_alive():
		return false
	
	# Trap monsters and enemies, not heroes
	if entity.is_in_group("Enemy") and not entity.is_in_group("Hero"):
		return true
	
	if entity.is_in_group("Monster"):
		return true
	
	return false

func _get_entity(node: Node) -> Node2D:
	# Resolve the ENTITY ROOT from a collider (the entity's Body Area2D) or
	# from the root itself. The old version returned the Area2D (it is a
	# Node2D too), so the cage was teleporting collision shapes, not mobs.
	if node == null:
		return null
	if node is EntityBase:
		return node
	var by_owner := node.get_owner()
	if by_owner is EntityBase:
		return by_owner
	var by_parent := node.get_parent()
	if by_parent is EntityBase:
		return by_parent
	return null

func _expire() -> void:
	cage_active = false
	
	# Clear visual effects on trapped enemies (kill the looping tweens first)
	for enemy in trapped_enemies:
		_kill_sprite_tween(enemy)
		if is_instance_valid(enemy) and enemy.has_node("Sprite2D"):
			var sprite = enemy.get_node("Sprite2D")
			sprite.modulate = Color.WHITE
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
