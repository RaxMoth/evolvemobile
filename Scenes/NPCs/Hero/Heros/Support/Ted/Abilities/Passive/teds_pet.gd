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

const FOLLOW_DISTANCE: float = 100.0
const SEARCH_RADIUS: float = 400.0

# ADDED: Navigation system
var navigation_agent: NavigationAgent2D = null

func _ready() -> void:
	current_health = max_health
	add_to_group("Hero")
	
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
	
	# Find the navigation map from the World's Ground tilemap
	var parent = get_parent()
	if not parent:
		push_warning("Pet has no parent - cannot setup navigation!")
		return
	
	var tilemap_layer = parent.get_node_or_null("Ground")
	if not tilemap_layer or not tilemap_layer.has_method("get_navigation_map"):
		push_warning("Pet cannot find Ground tilemap for navigation!")
		return
	
	var nav_map = tilemap_layer.get_navigation_map()
	if not nav_map.is_valid():
		push_warning("Pet navigation map is invalid!")
		return
	
	navigation_agent.set_navigation_map(nav_map)
	print("Pet navigation setup complete!")

func set_owner_entity(new_owner: Node2D) -> void:
	owner_entity = new_owner
	print("Pet owner set to: " + owner_entity.name)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(owner_entity):
		queue_free()
		return
	
	attack_timer = max(0.0, attack_timer - delta)
	
	# Find or maintain target
	if not is_instance_valid(current_target):
		_find_target()
	
	# Behavior
	if current_target and is_instance_valid(current_target):
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

func _find_target() -> void:
	var enemies = get_tree().get_nodes_in_group("Enemy")
	var closest_enemy: Node2D = null
	var closest_distance: float = SEARCH_RADIUS
	
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.has_method("is_alive"):
			continue
		
		if not enemy.is_alive():
			continue
		
		var distance = global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy
	
	current_target = closest_enemy

func _attack_target(delta: float) -> void:
	if not is_instance_valid(current_target):
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
			attack_timer = attack_cooldown

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
	if not is_instance_valid(current_target):
		return
	
	if current_target.has_method("take_damage"):
		current_target.take_damage(attack_damage)

func take_damage(amount: float) -> void:
	current_health -= amount
	
	if current_health <= 0.0:
		died.emit()
		queue_free()

func is_alive() -> bool:
	return current_health > 0.0
