extends EntityBase
class_name MonsterBase

signal stage_changed(new_stage: int)

@export_group("Monster Stats")
@export var max_health: float = 500.0
@export var base_move_speed: float = 60.0
@export var base_attack_range: float = 80.0

@export_group("Monster Behavior")
@export var base_idle_retarget_time: float = 2.0
@export var base_idle_wander_radius: float = 200.0
@export var base_keep_distance: float = 50.0

@export_group("Evolution System")
@export var evolution_xp_thresholds: Array[int] = [100, 300]
@export var speed_per_stage: float = 0.15

@export_group("Monster Abilities")
@export var ability_1: AbilityBase
@export var ability_2: AbilityBase
@export var ability_3: AbilityBase
@export var passive_ability: AbilityBase

@export_group("Stage Visuals")
@export var stage_1_animation: String = "phase_1"
@export var stage_2_animation: String = "phase_2"
@export var stage_3_animation: String = "phase_3"
@export var enable_stage_effects: bool = true

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var current_stage: int = 1
var current_health: float
var current_xp: float = 0.0
var next_evolution_xp: int = 100

var ability_cooldowns := {
	"ability_1": 0.0,
	"ability_2": 0.0,
	"ability_3": 0.0,
}

func _ready() -> void:
	_setup_monster_combat_role()
	current_health = max_health
	current_stage = 1
	_update_next_evolution_threshold()
	super._ready()

func _process(delta: float) -> void:
	# Update ability cooldowns
	for key in ability_cooldowns.keys():
		if ability_cooldowns[key] > 0.0:
			ability_cooldowns[key] -= delta
	
	# Update passive ability
	if passive_ability:
		passive_ability.on_passive_update(self, delta)

# ============================================
# Combat Setup
# ============================================

func _setup_monster_combat_role() -> void:
	combat_role = Globals.CombatRole.MELEE
	preferred_distance = 45.0
	min_distance = 20.0
	max_distance = 100.0
	strafe_enabled = true
	strafe_speed = 70.0
	strafe_change_interval = 1.5
	_update_combat_for_stage()

func _update_combat_for_stage() -> void:
	match current_stage:
		1:
			strafe_speed = 60.0
			strafe_change_interval = 2.0
		2:
			strafe_speed = 75.0
			strafe_change_interval = 1.5
		3:
			strafe_speed = 90.0
			strafe_change_interval = 1.0

func _is_attack_ready() -> bool:
	return ability_cooldowns.get("ability_1", 0.0) <= 0.0

# ============================================
# XP Value System
# ============================================

func _update_xp_value_for_stage() -> void:
	match current_stage:
		1:
			xp_value = 100.0
		2:
			xp_value = 200.0
		3:
			xp_value = 400.0
		_:
			xp_value = 100.0

# ============================================
# Stage Change Hook (Override in child classes)
# ============================================

func _on_stage_entered(new_stage: int, _old_stage: int) -> void:
	# Common behavior for all monsters
	_update_xp_value_for_stage()
	_update_combat_for_stage()
	
	# Child classes should call super first, then add their own logic

# ============================================
# EntityBase Virtual Method Overrides
# ============================================

func _get_move_speed() -> float:
	return base_move_speed * (1.0 + (current_stage - 1) * speed_per_stage)

func _get_approach_speed() -> float:
	return _get_move_speed() * 1.4

func _get_attack_range() -> float:
	return base_attack_range

func _get_idle_retarget_time() -> float:
	return base_idle_retarget_time

func _get_idle_wander_radius() -> float:
	return base_idle_wander_radius

func _get_keep_distance() -> float:
	return base_keep_distance

func is_alive() -> bool:
	return current_health > 0.0

func get_health() -> float:
	return current_health

func take_damage(amount: float, attacker: Node2D = null) -> void:
	if not is_alive():
		return
	
	last_attacker = attacker
	current_health -= amount
	
	if health_bar:
		health_bar.value = current_health
	
	if current_health <= 0.0:
		current_health = 0.0
		state_chart.send_event("self_dead")

func _get_entity_level() -> int:
	return current_stage

# ============================================
# XP & Evolution System
# ============================================

func gain_xp(amount: float) -> void:
	current_xp += amount
	print(name + " gained " + str(amount) + " XP (Total: " + str(current_xp) + "/" + str(next_evolution_xp) + ")")
	
	_check_evolution()

func _check_evolution() -> void:
	if current_xp >= next_evolution_xp:
		var new_stage = current_stage + 1
		var max_stage = evolution_xp_thresholds.size() + 1
		
		if new_stage <= max_stage:
			_evolve_to_stage(new_stage)

func _evolve_to_stage(new_stage: int) -> void:
	var old_stage = current_stage
	current_stage = new_stage
	
	print("╔════════════════════════════════════╗")
	print("║  " + name + " EVOLVED TO STAGE " + str(current_stage) + "!  ║")
	print("╚════════════════════════════════════╝")
	
	_update_next_evolution_threshold()
	
	# Reset cooldowns on evolution
	for key in ability_cooldowns.keys():
		ability_cooldowns[key] = 0.0
	
	# Visual update
	_update_stage_visuals(current_stage)
	
	# Call hook (child classes override this)
	_on_stage_entered(current_stage, old_stage)
	
	# Emit signal
	stage_changed.emit(current_stage)

func _update_next_evolution_threshold() -> void:
	var stage_index = current_stage - 1
	
	if stage_index < evolution_xp_thresholds.size():
		next_evolution_xp = evolution_xp_thresholds[stage_index]
	else:
		next_evolution_xp = 999999

# ============================================
# Stage Visuals
# ============================================

func _update_stage_visuals(stage: int) -> void:
	if not animated_sprite:
		return
	
	# Switch animation
	var animation_name: String
	match stage:
		1:
			animation_name = stage_1_animation
		2:
			animation_name = stage_2_animation
		3:
			animation_name = stage_3_animation
		_:
			animation_name = stage_1_animation
	
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(animation_name):
		animated_sprite.play(animation_name)
	else:
		push_warning(name + " missing animation: " + animation_name)
	
	# Visual effects
	if enable_stage_effects:
		_play_stage_effect(stage)

func _play_stage_effect(stage: int) -> void:
	# Flash sprite
	if animated_sprite:
		var flash_color = Color.WHITE
		match stage:
			2:
				flash_color = Color(1.5, 1.2, 0.8) # Orange
			3:
				flash_color = Color(1.8, 0.8, 0.8) # Red
		
		var original = animated_sprite.modulate
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", flash_color, 0.2)
		tween.tween_property(animated_sprite, "modulate", original, 0.3)
	
	# Expanding ring effect
	var effect = Node2D.new()
	get_parent().add_child(effect)
	effect.global_position = global_position
	effect.z_index = 10
	
	var circle = Line2D.new()
	effect.add_child(circle)
	
	match stage:
		2:
			circle.default_color = Color.ORANGE
		3:
			circle.default_color = Color.RED
		_:
			circle.default_color = Color.YELLOW
	
	circle.width = 5.0
	for i in range(33):
		var angle = i * TAU / 32
		circle.add_point(Vector2(cos(angle), sin(angle)) * 50)
	
	var tween = effect.create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "scale", Vector2(5, 5), 0.8)
	tween.tween_property(circle, "modulate:a", 0.0, 0.8)
	tween.tween_callback(effect.queue_free)

# ============================================
# Combat & AI
# ============================================

func _on_fight_logic(_delta: float) -> void:
	if not is_target_valid():
		return
	
	_choose_and_use_ability()

func _choose_and_use_ability() -> void:
	match current_stage:
		1:
			_try_use_ability("ability_1", ability_1)
		2:
			if ability_cooldowns["ability_2"] <= 0.0 and ability_2:
				_try_use_ability("ability_2", ability_2)
			else:
				_try_use_ability("ability_1", ability_1)
		_:
			# Stage 3: Prioritize abilities
			if ability_cooldowns["ability_3"] <= 0.0 and ability_3:
				_try_use_ability("ability_3", ability_3)
			elif ability_cooldowns["ability_2"] <= 0.0 and ability_2:
				_try_use_ability("ability_2", ability_2)
			else:
				_try_use_ability("ability_1", ability_1)

func _try_use_ability(ability_name: String, ability: AbilityBase) -> bool:
	if not ability or ability_cooldowns.get(ability_name, 0.0) > 0.0:
		return false
	
	if ability.can_use(self):
		ability.execute(self, target_entity)
		ability_cooldowns[ability_name] = ability.cooldown
		return true
	
	return false

# ============================================
# Death
# ============================================

func _on_dead_state_entered() -> void:
	_on_monster_death()
	super._on_dead_state_entered()

func _on_monster_death() -> void:
	# Override in child classes for custom death behavior
	pass

# ============================================
# Helper Methods
# ============================================

func get_evolution_progress() -> float:
	if current_stage >= evolution_xp_thresholds.size() + 1:
		return 1.0
	
	var prev_threshold = 0
	if current_stage > 1:
		prev_threshold = evolution_xp_thresholds[current_stage - 2]
	
	var xp_in_stage = current_xp - prev_threshold
	var xp_needed = next_evolution_xp - prev_threshold
	
	return xp_in_stage / float(xp_needed)

func get_stage() -> int:
	return current_stage

func get_xp() -> float:
	return current_xp

func get_next_evolution_xp() -> int:
	return next_evolution_xp

func get_ability_cooldown(ability_name: String) -> float:
	return ability_cooldowns.get(ability_name, 0.0)

func is_ability_ready(ability_name: String) -> bool:
	return ability_cooldowns.get(ability_name, 0.0) <= 0.0
