# ============================================
# MONSTER BASE CLASS (Bosses & Elites)
# Save as: res://characters/base/monster_base_class.gd
#
# For boss monsters and elite enemies with:
# - Phase system (changes behavior at health thresholds)
# - Multiple custom abilities (3 abilities + 1 passive)
# - No fixed active/basic/ult structure (flexible)
# - Complex AI and mechanics
# ============================================
extends EntityBase
class_name MonsterBase

signal phase_changed(new_phase: int)

@export_group("Monster Stats")
@export var max_health: float = 500.0
@export var base_move_speed: float = 60.0
@export var base_attack_range: float = 80.0

@export_group("Monster Behavior")
@export var base_idle_retarget_time: float = 2.0
@export var base_idle_wander_radius: float = 200.0
@export var base_keep_distance: float = 50.0

@export_group("Phase System")
# Health % thresholds for phase changes
# Example: [0.66, 0.33] = Phase 2 at 66% HP, Phase 3 at 33% HP
@export var phase_health_thresholds: Array[float] = [0.66, 0.33]
@export var speed_per_phase: float = 0.15  # 15% speed increase per phase

@export_group("Monster Abilities")
@export var ability_1: AbilityBase  # Primary attack
@export var ability_2: AbilityBase  # Special ability 1
@export var ability_3: AbilityBase  # Special ability 2
@export var passive_ability: AbilityBase  # Passive (always active)

# Animation names in AnimatedSprite2D (e.g., "phase_1", "phase_2", "phase_3")
@export var phase_1_animation: String = "phase_1"
@export var phase_2_animation: String = "phase_2"
@export var phase_3_animation: String = "phase_3"
@export var enable_phase_effects: bool = true  # Visual flash on phase change

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var current_phase: int = 1
var current_health: float
var ability_cooldowns := {
	"ability_1": 0.0,
	"ability_2": 0.0,
	"ability_3": 0.0,
}

func _ready() -> void:
	current_health = max_health
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
# Override EntityBase virtual methods
# ============================================

func _get_move_speed() -> float:
	# Gets faster each phase
	return base_move_speed * (1.0 + (current_phase - 1) * speed_per_phase)

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

# ============================================
# Implement EntityBase abstract methods
# ============================================

func is_alive() -> bool:
	return current_health > 0.0

func get_health() -> float:
	return current_health

func take_damage(amount: float) -> void:
	if not is_alive():
		return
	
	current_health -= amount
	_check_phase_transition()
	
	if current_health <= 0.0:
		current_health = 0.0
		state_chart.send_event("self_dead")
	else:
		print(name + " took " + str(amount) + " damage - Phase " + str(current_phase))

# ============================================
# Phase System
# ============================================

func _check_phase_transition() -> void:
	var health_percent = current_health / max_health
	var new_phase = 1
	
	# Determine which phase based on health thresholds
	for i in range(phase_health_thresholds.size()):
		if health_percent <= phase_health_thresholds[i]:
			new_phase = i + 2  # Phases start at 1, so threshold 0 = phase 2
	
	if new_phase != current_phase:
		_enter_phase(new_phase)



# Override this in specific monsters for phase-specific behavior
func _on_phase_entered(_new_phase: int, _old_phase: int) -> void:
	pass

# ============================================
# Combat with Multiple Abilities
# ============================================

func _on_fight_logic(_delta: float) -> void:
	if not is_target_valid():
		return
	
	# Choose and use ability based on AI logic
	_choose_and_use_ability()

# AI decides which ability to use
func _choose_and_use_ability() -> void:
	# Default AI: More abilities unlock per phase
	match current_phase:
		1:
			# Phase 1: Only ability_1
			_try_use_ability("ability_1", ability_1)
		
		2:
			# Phase 2: Ability_1 and ability_2
			if ability_cooldowns["ability_2"] <= 0.0 and ability_2:
				_try_use_ability("ability_2", ability_2)
			else:
				_try_use_ability("ability_1", ability_1)
		
		_:
			# Phase 3+: All abilities, prioritize by cooldown
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
		print(name + " used " + ability.ability_name + "!")
		return true
	
	return false

# ============================================
# Helper methods for abilities
# ============================================

func get_ability_cooldown(ability_name: String) -> float:
	return ability_cooldowns.get(ability_name, 0.0)

func is_ability_ready(ability_name: String) -> bool:
	return ability_cooldowns.get(ability_name, 0.0) <= 0.0

# ============================================
# Optional: Override for death effects
# ============================================

func _on_dead_state_entered() -> void:
	_on_monster_death()
	super._on_dead_state_entered()

# Override for custom death behavior (cutscenes, loot, etc.)
func _on_monster_death() -> void:
	pass


# Add this to monster_base_class.gd

# ============================================
# PHASE-BASED VISUAL SYSTEM
# ============================================

@export_group("Phase Visuals")


func _enter_phase(phase: int) -> void:
	var old_phase = current_phase
	current_phase = phase
	
	print(name + " entered Phase " + str(current_phase) + "!")
	
	# Reset cooldowns on phase change
	for key in ability_cooldowns.keys():
		ability_cooldowns[key] = 0.0
	
	# VISUAL UPDATE: Switch sprite animation
	_update_phase_visuals(current_phase)
	
	# Emit signal and call override
	phase_changed.emit(current_phase)
	_on_phase_entered(current_phase, old_phase)

func _update_phase_visuals(phase: int) -> void:
	if not animated_sprite:
		return
	
	# Switch to phase-specific animation
	var animation_name: String
	match phase:
		1:
			animation_name = phase_1_animation
		2:
			animation_name = phase_2_animation
		3:
			animation_name = phase_3_animation
		_:
			animation_name = phase_1_animation
	
	# Check if animation exists
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(animation_name):
		animated_sprite.play(animation_name)
		print(name + " switched to animation: " + animation_name)
	else:
		push_warning(name + " missing animation: " + animation_name)
	
	# Optional: Visual effect on phase change
	if enable_phase_effects:
		_play_phase_change_effect(phase)

func _play_phase_change_effect(phase: int) -> void:
	# Flash effect
	if animated_sprite:
		var original_modulate = animated_sprite.modulate
		var flash_color = Color.WHITE
		
		match phase:
			2:
				flash_color = Color(1.5, 1.2, 0.8)  # Orange flash
			3:
				flash_color = Color(1.8, 0.8, 0.8)  # Red flash
		
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", flash_color, 0.2)
		tween.tween_property(animated_sprite, "modulate", original_modulate, 0.3)
	
	# Expanding ring effect
	var effect = Node2D.new()
	get_parent().add_child(effect)
	effect.global_position = global_position
	effect.z_index = 10
	
	# Create effect visuals
	var circle = _create_phase_ring(phase)
	effect.add_child(circle)
	
	var tween = effect.create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "scale", Vector2(5, 5), 0.8)
	tween.tween_property(circle, "modulate:a", 0.0, 0.8)
	tween.tween_callback(effect.queue_free)

func _create_phase_ring(phase: int) -> Line2D:
	var circle = Line2D.new()
	
	# Phase-specific colors
	match phase:
		2:
			circle.default_color = Color.ORANGE
		3:
			circle.default_color = Color.RED
		_:
			circle.default_color = Color.WHITE
	
	circle.width = 4.0
	
	# Draw circle
	for i in range(33):
		var angle = i * TAU / 32
		circle.add_point(Vector2(cos(angle), sin(angle)) * 50)
	
	return circle
