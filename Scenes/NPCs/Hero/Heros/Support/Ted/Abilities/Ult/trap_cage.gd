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

## How far toward the palette's `ted` a trapped enemy's drawn body pulses.
const TRAP_TINT_WEIGHT: float = 0.55
## Seconds of each half of the pulse.
const TRAP_PULSE: float = 0.5

var trapped_enemies: Array[Node2D] = []  # Already typed correctly
var cage_active: bool = true
## enemy -> life_id at trap time. A pooled mob that died and respawned keeps
## the same node but a new life_id, so the cage must stop acting on it.
var _trapped_life_ids: Dictionary = {}
var _sprite_tweens: Dictionary = {}  # enemy -> looping tint Tween, killed on expire

func _ready() -> void:
	# Setup collision
	var collision_shape = $CollisionShape2D
	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = cage_radius
	
	# The stakes and the trampled ring are AbilityVfx's (CAGE_CLOSED, emitted
	# by TedUltimateTrapCage once the cage is in the tree).
	
	# body_exited / area_exited are wired in TrapCage.tscn.
	
	# Initial scan for enemies
	_scan_for_enemies()
	
	# Expire after duration: a pausable timer (process_always false), so the
	# pause menu and the result screen hold the cage with the match. It runs in
	# game time (Engine.time_scale), as the match does.
	await get_tree().create_timer(duration, false).timeout
	_expire()

func _process(delta: float) -> void:
	if not cage_active:
		return
	if cage_dps > 0.0:
		_spike_timer += delta
		while _spike_timer >= SPIKE_INTERVAL:
			_spike_timer -= SPIKE_INTERVAL
			_spike()
	
	# Force trapped enemies to stay inside. A freed entry (the monster died
	# and was freed inside the cage; mobs are parked, not freed) is skipped
	# before any typed call: a freed object is no Node2D argument. One that
	# turned cc-immune is let go for good (_release), after the loop.
	var released: Array[Node2D] = []
	for enemy in trapped_enemies:
		if not is_instance_valid(enemy) or not _still_trapped(enemy):
			continue
		if _is_cc_immune(enemy):
			released.append(enemy)
			continue

		var dist = enemy.global_position.distance_to(global_position)
		if dist > cage_radius - 15:
			# Push back inside, at the edge it tried to leave by (the push
			# used to mirror it to the opposite side of the cage).
			var dir: Vector2 = (enemy.global_position - global_position).normalized()
			var push_pos = global_position + dir * (cage_radius - 20)
			# Never through a wall (the push teleports).
			enemy.global_position = GameUtils.clamp_to_nav_segment(get_world_2d(), enemy.global_position, push_pos)
	for enemy in released:
		_release(enemy)

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
		if entity and _is_valid_target(entity) and _is_cc_immune(entity):
			# Presentation: Unstoppable shrugs the cage off (AbilityVfx).
			EventBus.notify_ability_event(entity, (entity as MonsterBase).passive_ability,
					FxEvents.CC_SHRUGGED, global_position)
		if entity and _is_valid_target(entity) and not _is_cc_immune(entity):
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
	
	var entity := _get_entity(node)
	if entity == null or not trapped_enemies.has(entity) or not _still_trapped(entity):
		return
	if _is_cc_immune(entity):
		_release(entity)
		return
	# Teleport back to center of cage
	entity.global_position = global_position


## Lets `enemy` go for good: it turned cc-immune while held (Nyxa's Vampiric
## Rebirth scatters her into bats). The cage forgets it and its tint, so the
## monster that re-forms 400 px away is not pulled back in when the immunity
## ends.
func _release(enemy: Node2D) -> void:
	trapped_enemies.erase(enemy)
	_kill_sprite_tween(enemy)
	_trapped_life_ids.erase(enemy)

## A trapped enemy's drawn body (its CharacterRig, else its sprite:
## EntityBase.visual_root) pulses toward the palette's `ted` and back. Only the
## colour channels are tweened, so a fade of its alpha (Nyxa's scattered bats)
## keeps running.
func _apply_trap_effect(entity: Node2D) -> void:
	var vis: Node2D = (entity as EntityBase).visual_root() if entity is EntityBase else null
	if vis == null:
		return
	var tint: Color = Color.WHITE.lerp(UiPalette.get_default().ted, TRAP_TINT_WEIGHT)
	var tween := vis.create_tween()
	_sprite_tweens[entity] = tween
	tween.set_loops()
	tween.tween_property(vis, ^"modulate:r", tint.r, TRAP_PULSE)
	tween.parallel().tween_property(vis, ^"modulate:g", tint.g, TRAP_PULSE)
	tween.parallel().tween_property(vis, ^"modulate:b", tint.b, TRAP_PULSE)
	tween.tween_property(vis, ^"modulate:r", 1.0, TRAP_PULSE)
	tween.parallel().tween_property(vis, ^"modulate:g", 1.0, TRAP_PULSE)
	tween.parallel().tween_property(vis, ^"modulate:b", 1.0, TRAP_PULSE)

func _still_trapped(enemy: Node2D) -> bool:
	# Same node, same life, still in the tree. Otherwise drop its tint tween.
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
		_clear_tint(enemy)


## Back to the body's own colours, its alpha untouched.
func _clear_tint(enemy: Node2D) -> void:
	if not is_instance_valid(enemy) or not enemy is EntityBase:
		return
	var vis: Node2D = (enemy as EntityBase).visual_root()
	if vis != null:
		vis.modulate = Color(1.0, 1.0, 1.0, vis.modulate.a)

## Gorrak's Unstoppable (MonsterBase.is_cc_immune): the cage never holds him
## (its spikes still hurt whatever overlaps it). Asked every frame, so the
## scattered bats of Nyxa's Vampiric Rebirth fly out of a cage too, and the
## cage lets her go for good (_release).
func _is_cc_immune(entity: Node) -> bool:
	return entity is MonsterBase and (entity as MonsterBase).is_cc_immune()


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
	EventBus.notify_ability_event(self, source_ability, FxEvents.CAGE_OPENED, global_position, cage_radius)
	
	# Stop the trapped enemies' tint (each back to its own colours). An enemy
	# freed inside the cage has no body left to clear; passing it on used to
	# abort here ("previously freed" argument), so the cage never faded or
	# freed itself. Its tween is stopped with whatever else is left below.
	for enemy in trapped_enemies:
		if is_instance_valid(enemy):
			_kill_sprite_tween(enemy)
	for tween: Tween in _sprite_tweens.values():
		if tween and tween.is_valid():
			tween.kill()
	_sprite_tweens.clear()
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
