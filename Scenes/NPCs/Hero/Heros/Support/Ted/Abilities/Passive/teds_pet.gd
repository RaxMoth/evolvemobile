extends CharacterBody2D

signal died

@export var max_health: float = 50.0
@export var move_speed: float = 120.0
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

# ADDED: Navigation system
var navigation_agent: NavigationAgent2D = null

# Retarget at 4 Hz: the old per-physics-frame group scan walked the whole tree.
const RETARGET_INTERVAL: float = 0.25
var _retarget_timer: float = 0.0

func _enter_tree() -> void:
	# In group "Hero" (TedsPet.tscn) → EntityRegistry.hero_side, not .heroes.
	EntityRegistry.register(self)

func _exit_tree() -> void:
	EntityRegistry.unregister(self)

func _ready() -> void:
	current_health = max_health
	# NOTE: "Hero" group is declared in TedsPet.tscn (`groups=["Hero"]`).
	# No add_to_group() call is needed here.
	
	# CRITICAL: Set up navigation agent
	_setup_navigation_agent()
	_setup_navigation_map()

func _setup_navigation_agent() -> void:
	# Create NavigationAgent2D if it doesn't exist
	if not has_node("NavigationAgent2D"):
		navigation_agent = NavigationAgent2D.new()
		navigation_agent.name = "NavigationAgent2D"
		add_child(navigation_agent)
	else:
		navigation_agent = $NavigationAgent2D
	
	# Configure navigation
	navigation_agent.path_desired_distance = 6.0
	navigation_agent.target_desired_distance = 4.0
	navigation_agent.avoidance_enabled = false
	navigation_agent.radius = 10.0

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
	Globals.debug_log("Pet navigation setup complete!")

func set_owner_entity(new_owner: Node2D) -> void:
	owner_entity = new_owner
	Globals.debug_log("Pet owner set to: " + owner_entity.name)

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

## Alive, in the tree and not absurdly far (a reused pooled node can respawn anywhere).
func _target_ok() -> bool:
	return is_instance_valid(current_target) and current_target.is_inside_tree() \
		and EntityRegistry.is_entity_alive(current_target) \
		and global_position.distance_squared_to(current_target.global_position) <= SEARCH_RADIUS * SEARCH_RADIUS * 2.25

func _find_target() -> void:
	current_target = EntityRegistry.nearest(EntityRegistry.enemies, global_position, SEARCH_RADIUS)

func _attack_target(delta: float) -> void:
	if not _target_ok():
		current_target = null
		return
	
	var distance = global_position.distance_to(current_target.global_position)
	
	if distance > attack_range:
		# FIXED: Use navigation to path around obstacles
		_navigate_to_position(current_target.global_position, move_speed, delta)
	else:
		# Stop and attack
		velocity = velocity.lerp(Vector2.ZERO, 10.0 * delta)
		
		if attack_timer <= 0.0:
			_perform_attack()
			attack_timer = attack_cooldown / _boost_mult

# NEW: Navigation helper function
func _navigate_to_position(target_pos: Vector2, speed: float, delta: float) -> void:
	if not navigation_agent:
		# Fallback to direct movement if navigation fails
		var direction = (target_pos - global_position).normalized()
		velocity = direction * speed
		return
	
	# Set navigation target
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
	
	# Rotate sprite to face movement direction (optional)
	if has_node("Sprite2D") and direction.length_squared() > 0.01:
		$Sprite2D.rotation = direction.angle()

func _perform_attack() -> void:
	if not _target_ok():
		return
	EventBus.deal_damage(self, current_target, attack_damage, null)

func _receive_damage(packet: DamagePacket) -> void:
	# A dying pet (queued free) must not emit `died` twice.
	if current_health <= 0.0:
		return
	current_health -= packet.amount

	if current_health <= 0.0:
		died.emit()
		EventBus.notify_died(self, packet.source)
		queue_free()

## Rally Cry: faster attacks for `duration` seconds.
func set_attack_speed_boost(multiplier: float, duration: float = 5.0) -> void:
	_boost_mult = maxf(multiplier, 0.01)
	_boost_timer = duration

func is_alive() -> bool:
	return current_health > 0.0
