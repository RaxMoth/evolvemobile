extends MonsterBase
class_name Grount

enum Stage {WEAK = 1, MEDIUM = 2, STRONG = 3}

signal stage_evolved(new_stage: Stage)

var current_stage: Stage = Stage.WEAK
var monster_xp: int = 0
var xp_thresholds: Array[int] = [150, 400] # Stage 2 at 150 XP, Stage 3 at 400 XP
var damage_multiplier: float = 1.0

func _ready() -> void:
	add_to_group("Monster")
	_apply_stage_stats()
	super._ready()
	print(name + " spawned at Stage " + str(current_stage))

func add_monster_xp(amount: int) -> void:
	monster_xp += amount
	print(name + " gained " + str(amount) + " XP (Total: " + str(monster_xp) + "/" + str(_get_next_threshold()) + ")")
	
	# Check for evolution
	if current_stage == Stage.WEAK and monster_xp >= xp_thresholds[0]:
		evolve_to_stage(Stage.MEDIUM)
	elif current_stage == Stage.MEDIUM and monster_xp >= xp_thresholds[1]:
		evolve_to_stage(Stage.STRONG)

func _get_next_threshold() -> int:
	match current_stage:
		Stage.WEAK:
			return xp_thresholds[0]
		Stage.MEDIUM:
			return xp_thresholds[1]
		Stage.STRONG:
			return 999999
	return 999999

func evolve_to_stage(new_stage: Stage) -> void:
	var old_stage = current_stage
	current_stage = new_stage
	_apply_stage_stats()
	_play_evolution_effect()
	stage_evolved.emit(new_stage)
	
	print("╔════════════════════════════════════╗")
	print("║  " + name + " EVOLVED TO STAGE " + str(new_stage) + "!  ║")
	print("╚════════════════════════════════════╝")

func _apply_stage_stats() -> void:
	match current_stage:
		Stage.WEAK:
			max_health = 800.0
			current_health = max_health
			base_move_speed = 60.0
			damage_multiplier = 1.0
			_configure_weak_abilities()
			
		Stage.MEDIUM:
			var old_max = max_health
			max_health = 1400.0
			current_health += (max_health - old_max) # Heal on evolution
			base_move_speed = 80.0
			damage_multiplier = 1.4
			_configure_medium_abilities()
			
		Stage.STRONG:
			var old_max = max_health
			max_health = 2200.0
			current_health += (max_health - old_max) # Heal on evolution
			base_move_speed = 110.0
			damage_multiplier = 2.0
			_configure_strong_abilities()
	
	# Update health bar directly
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

func _configure_weak_abilities() -> void:
	# Stage 1: Weak monster
	if ability_1: # Front Cleave
		ability_1.damage = 12.0
		ability_1.cooldown = 4.5
		if "cone_angle" in ability_1:
			ability_1.cone_angle = 50.0
	
	if ability_2: # Ram Dash
		ability_2.damage = 18.0
		ability_2.cooldown = 12.0
	
	if ability_3: # Ground Slam - LOCKED
		ability_3.cooldown = 999999.0

func _configure_medium_abilities() -> void:
	# Stage 2: Medium power
	if ability_1:
		ability_1.damage = 17.0
		ability_1.cooldown = 3.0
		if "cone_angle" in ability_1:
			ability_1.cone_angle = 60.0
	
	if ability_2:
		ability_2.damage = 25.0
		ability_2.cooldown = 8.0
	
	if ability_3: # Ground Slam - UNLOCKED
		ability_3.damage = 32.0
		ability_3.cooldown = 15.0
		if "area_of_effect" in ability_3:
			ability_3.area_of_effect = 120.0

func _configure_strong_abilities() -> void:
	# Stage 3: ENRAGE MODE
	if ability_1:
		ability_1.damage = 24.0
		ability_1.cooldown = 1.8
		if "cone_angle" in ability_1:
			ability_1.cone_angle = 75.0
	
	if ability_2:
		ability_2.damage = 36.0
		ability_2.cooldown = 5.0
	
	if ability_3:
		ability_3.damage = 50.0
		ability_3.cooldown = 9.0
		if "area_of_effect" in ability_3:
			ability_3.area_of_effect = 180.0
	
	# Increase attack range
	base_attack_range = 70.0

func _try_use_ability(ability_name: String, ability: AbilityBase) -> bool:
	if not ability or ability_cooldowns.get(ability_name, 0.0) > 0.0:
		return false
	
	if ability.can_use(self):
		# Apply damage multiplier based on stage
		var original_damage = ability.damage
		ability.damage = original_damage * damage_multiplier
		
		ability.execute(self, target_entity)
		
		# Restore original damage
		ability.damage = original_damage
		
		ability_cooldowns[ability_name] = ability.cooldown
		return true
	
	return false

func _play_evolution_effect() -> void:
	var effect_color = Color.ORANGE if current_stage == Stage.MEDIUM else Color.RED
	
	# Create expanding ring effect
	var effect = Node2D.new()
	get_parent().add_child(effect)
	effect.global_position = global_position
	effect.z_index = 10
	
	var tween = effect.create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "scale", Vector2(8, 8), 1.0)
	tween.tween_property(effect, "modulate:a", 0.0, 1.0)
	tween.tween_callback(effect.queue_free)
	
	# Change sprite tint
	if has_node("Sprite2D"):
		var sprite = get_node("Sprite2D")
		if current_stage == Stage.STRONG:
			sprite.modulate = Color(1.5, 0.8, 0.8) # Red enrage
		elif current_stage == Stage.MEDIUM:
			sprite.modulate = Color(1.2, 1.0, 0.8) # Orange warning
	
	# Screen shake
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("apply_shake"):
		camera.apply_shake(20.0, 0.8)

func get_stage_name() -> String:
	match current_stage:
		Stage.WEAK:
			return "Vulnerable"
		Stage.MEDIUM:
			return "Dangerous"
		Stage.STRONG:
			return "APEX PREDATOR"
	return "Unknown"
	
	
func _on_phase_entered(new_phase: int, old_phase: int) -> void:
	super._on_phase_entered(new_phase, old_phase)
	
	# Switch sprite animation based on evolution stage
	_update_visual_stage(new_phase)
	
	# Keep existing behavior
	match new_phase:
		1:
			_configure_weak_abilities()
		2:
			_configure_medium_abilities()
		3:
			_configure_strong_abilities()

func _update_visual_stage(stage: int) -> void:
	# Switch AnimatedSprite2D animation
	if has_node("AnimatedSprite2D"):
		var anim_sprite = $AnimatedSprite2D
		
		# Animation names must match what you set up in SpriteFrames
		var animation_name = "phase_" + str(stage)
		
		if anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(animation_name):
			anim_sprite.play(animation_name)
			print("Grount visual stage: " + animation_name)
		else:
			push_warning("Missing animation: " + animation_name + " - Create it in AnimatedSprite2D!")
	
	# Optional: Evolution flash effect
	_play_evolution_visual_effect(stage)
	
	# Optional: Scale up with each stage
	_update_stage_scale(stage)

func _play_evolution_visual_effect(stage: int) -> void:
	# Flash the sprite
	if has_node("AnimatedSprite2D"):
		var anim_sprite = $AnimatedSprite2D
		var original_modulate = anim_sprite.modulate
		
		var flash_color = Color.WHITE
		match stage:
			2:
				flash_color = Color(1.5, 1.2, 0.8)  # Orange
			3:
				flash_color = Color(1.8, 0.8, 0.8)  # Red
		
		var tween = create_tween()
		tween.tween_property(anim_sprite, "modulate", flash_color, 0.2)
		tween.tween_property(anim_sprite, "modulate", original_modulate, 0.4)
	
	# Expanding ring (keep your existing effect or use this)
	_create_evolution_ring_effect(stage)

func _create_evolution_ring_effect(stage: int) -> void:
	var effect = Node2D.new()
	get_parent().add_child(effect)
	effect.global_position = global_position
	effect.z_index = 10
	
	var circle = Line2D.new()
	effect.add_child(circle)
	
	# Stage-specific colors
	match stage:
		2:
			circle.default_color = Color.ORANGE
		3:
			circle.default_color = Color.RED
		_:
			circle.default_color = Color.YELLOW
	
	circle.width = 5.0
	
	# Draw circle
	for i in range(33):
		var angle = i * TAU / 32
		circle.add_point(Vector2(cos(angle), sin(angle)) * 60)
	
	# Animate
	var tween = effect.create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "scale", Vector2(4, 4), 1.0)
	tween.tween_property(circle, "modulate:a", 0.0, 1.0)
	tween.tween_callback(effect.queue_free)

func _update_stage_scale(stage: int) -> void:
	# Make Grount physically grow with each stage
	var target_scale = Vector2.ONE
	
	match stage:
		1:
			target_scale = Vector2(1.0, 1.0)  # Normal
		2:
			target_scale = Vector2(1.25, 1.25)  # 25% bigger
		3:
			target_scale = Vector2(1.5, 1.5)  # 50% bigger - APEX
	
	# Smooth growth animation
	var tween = create_tween()
	tween.tween_property(self, "scale", target_scale, 0.5)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
