extends CharacterBody2D

signal died
## Presentation only, like EntityBase's: TedsPet.tscn wires both to its
## CharacterRig (a bite plays the attack, a hit the flash). Gameplay never listens.
signal ability_cast(ability: AbilityBase, target: Node)
signal damaged(packet: DamagePacket)

@export var max_health: float = 50.0
@export var move_speed: float = 144.0
@export var attack_damage: float = 9.0
@export var attack_range: float = 60.0
@export var attack_cooldown: float = 1.2

var owner_entity: Node2D = null
var current_health: float
var current_target: Node2D = null
var attack_timer: float = 0.0
var _boost_mult: float = 1.0
var _boost_timer: float = 0.0

const FOLLOW_DISTANCE: float = 100.0
const SEARCH_RADIUS: float = 400.0
## The pet only fights enemies this close to Ted, and drops a target that
## gets 1.5x this far from him. Measured from the pet itself it chased the
## monster across the map and killed it alone, far from every hero.
@export var leash_radius: float = 350.0

## Path distances live on the TedsPet.tscn node; _ready raises its polygon
## search budget (GameUtils.configure_nav_agent).
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D

# Retarget at 4 Hz: the old per-physics-frame group scan walked the whole tree.
const RETARGET_INTERVAL: float = 0.25
var _retarget_timer: float = 0.0

func _enter_tree() -> void:
	# In group "Hero" (TedsPet.tscn) → EntityRegistry.hero_side, not .heroes.
	EntityRegistry.register(self, GameUtils.faction_of(self))

func _exit_tree() -> void:
	EntityRegistry.unregister(self, GameUtils.faction_of(self))

func _ready() -> void:
	current_health = max_health
	_update_health_bar()
	# NOTE: "Hero" group is declared in TedsPet.tscn (`groups=["Hero"]`).
	# No add_to_group() call is needed here.
	
	GameUtils.configure_nav_agent(navigation_agent)
	_setup_navigation_map()

func _setup_navigation_map() -> void:
	# Wait for scene to be ready
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	# The world's default navigation map (the Ground TileMapLayer uses it too).
	if not is_inside_tree():
		return
	var nav_map: RID = get_world_2d().navigation_map
	if not nav_map.is_valid():
		push_warning("Pet navigation map is invalid!")
		return
	
	navigation_agent.set_navigation_map(nav_map)

func set_owner_entity(new_owner: Node2D) -> void:
	owner_entity = new_owner

func _physics_process(delta: float) -> void:
	if not is_instance_valid(owner_entity):
		queue_free()
		return
	
	attack_timer = maxf(0.0, attack_timer - delta)
	if _boost_timer > 0.0:
		_boost_timer -= delta
		if _boost_timer <= 0.0:
			_boost_mult = 1.0
	
	# A dead or pooled (parked) mob is still a valid instance: drop it the way
	# EntityBase.is_target_valid does, and retarget on this frame.
	if current_target != null and not _target_ok():
		current_target = null
		_retarget_timer = 0.0
	
	# Find or maintain target (throttled)
	if current_target == null:
		_retarget_timer -= delta
		if _retarget_timer <= 0.0:
			_retarget_timer = RETARGET_INTERVAL
			_find_target()
	
	# Behavior
	if current_target != null:
		_attack_target(delta)
	else:
		_follow_owner(delta)
	
	move_and_slide()

func _follow_owner(delta: float) -> void:
	if not is_instance_valid(owner_entity):
		return
	
	var distance = global_position.distance_to(owner_entity.global_position)
	
	if distance > FOLLOW_DISTANCE:
		# FIXED: Use navigation to path around obstacles
		_navigate_to_position(owner_entity.global_position, move_speed, delta)
	else:
		velocity = velocity.lerp(Vector2.ZERO, 10.0 * delta)

## Alive, in the tree and still near Ted (a reused pooled node can respawn anywhere).
func _target_ok() -> bool:
	if not (is_instance_valid(current_target) and current_target.is_inside_tree() \
			and EntityRegistry.is_entity_alive(current_target)):
		return false
	var keep: float = leash_radius * 1.5
	return _anchor().distance_squared_to(current_target.global_position) <= keep * keep

## Nearest living enemy to the pet that is within leash_radius of Ted.
func _find_target() -> void:
	var anchor: Vector2 = _anchor()
	var leash_sq: float = leash_radius * leash_radius
	var best: Node2D = null
	var best_sq: float = SEARCH_RADIUS * SEARCH_RADIUS
	for e in EntityRegistry.enemies:
		if not is_instance_valid(e) or not e.is_inside_tree() or not EntityRegistry.is_entity_alive(e):
			continue
		if anchor.distance_squared_to(e.global_position) > leash_sq:
			continue
		var d_sq: float = global_position.distance_squared_to(e.global_position)
		if d_sq < best_sq:
			best_sq = d_sq
			best = e
	current_target = best


func _anchor() -> Vector2:
	return owner_entity.global_position if is_instance_valid(owner_entity) else global_position

func _attack_target(delta: float) -> void:
	if not _target_ok():
		current_target = null
		return
	
	# From the edge of an evolved monster (EntityBase.range_to).
	var distance: float = global_position.distance_to(current_target.global_position) - EntityBase.reach_bonus_of(current_target)
	
	if distance > attack_range:
		# FIXED: Use navigation to path around obstacles
		_navigate_to_position(current_target.global_position, move_speed, delta)
	else:
		# Stop and attack
		velocity = velocity.lerp(Vector2.ZERO, 10.0 * delta)
		_face(current_target.global_position - global_position)
		
		if attack_timer <= 0.0:
			_perform_attack()
			attack_timer = attack_cooldown / _boost_mult

# NEW: Navigation helper function
func _navigate_to_position(target_pos: Vector2, speed: float, delta: float) -> void:
	if not navigation_agent:
		# Fallback to direct movement if navigation fails
		velocity = (target_pos - global_position).normalized() * speed
		return
	
	# Re-path only when the target moved: every assignment requests a new path,
	# and this ran every physics frame.
	if navigation_agent.target_position.distance_squared_to(target_pos) > 16.0 * 16.0 \
			or navigation_agent.is_navigation_finished():
		navigation_agent.target_position = target_pos
	
	# Check if we have a valid path
	if navigation_agent.is_navigation_finished():
		velocity = velocity.lerp(Vector2.ZERO, 10.0 * delta)
		return
	
	# Get next position from navigation
	var next_pos = navigation_agent.get_next_path_position()
	var direction = (next_pos - global_position).normalized()
	
	# Move along the path
	velocity = direction * speed
	
	_face(direction)


## Turns the facing carrier (the hidden Sprite2D the rig mirrors by) along
## `direction`: the path while it runs, its victim while it bites. A target
## already in bite range (the next mob of a camp, one that walked round it)
## used to be bitten facing away. Presentation only: nothing in gameplay
## reads the pet's Sprite2D.
func _face(direction: Vector2) -> void:
	if direction.length_squared() > 0.01 and has_node(^"Sprite2D"):
		($Sprite2D as Node2D).rotation = direction.angle()

func _perform_attack() -> void:
	if not _target_ok():
		return
	ability_cast.emit(null, current_target)
	EventBus.deal_damage(self, current_target, attack_damage, null)

func _receive_damage(packet: DamagePacket) -> void:
	# A dying pet (queued free) must not emit `died` twice; the hit lands
	# nowhere.
	if current_health <= 0.0:
		packet.canceled = true
		return
	current_health -= packet.amount
	_update_health_bar()
	damaged.emit(packet)

	if current_health <= 0.0:
		died.emit()
		EventBus.notify_died(self, packet.source)
		queue_free()

## Mobs and the monster can target the pet now: keep its bar honest. The bar
## is the in-world HpBar2D every entity draws (a themed ProgressBar is too
## small to read at this size), in the fox's own EntityHud (TedsPet.tscn):
## above the bodies, stacking with the heroes' bars.
func _update_health_bar() -> void:
	var bar := get_node_or_null(^"%HealthBar") as HpBar2D
	if bar:
		bar.set_values(maxf(current_health, 0.0), max_health)


## Rally Cry: faster attacks for `duration` seconds.
func set_attack_speed_boost(multiplier: float, duration: float = 5.0) -> void:
	_boost_mult = maxf(multiplier, 0.01)
	_boost_timer = duration

func is_alive() -> bool:
	return current_health > 0.0
