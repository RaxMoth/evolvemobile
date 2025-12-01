extends MonsterBase
class_name Grount

# Just for readable stage names (not used as values)
enum StageNames {VULNERABLE = 1, DANGEROUS = 2, APEX_PREDATOR = 3}

var damage_multiplier: float = 1.0

func _ready() -> void:
	# Configure initial stats before super
	_apply_stage_configuration(1)
	super._ready()
	print(name + " spawned as " + get_stage_name())

# ============================================
# Stage Configuration (Called by base class)
# ============================================

func _on_stage_entered(new_stage: int, _old_stage: int) -> void:
	_apply_stage_configuration(new_stage)
	_update_stage_scale(new_stage)

func _apply_stage_configuration(stage: int) -> void:
	match stage:
		1:  # Vulnerable
			max_health = 800.0
			current_health = max_health
			base_move_speed = 60.0
			damage_multiplier = 1.0
			_configure_stage_1_abilities()
			
		2:  # Dangerous
			var old_max = max_health
			max_health = 1400.0
			current_health += (max_health - old_max)  # Heal on evolution
			base_move_speed = 80.0
			damage_multiplier = 1.4
			_configure_stage_2_abilities()
			
		3:  # Apex Predator
			var old_max = max_health
			max_health = 2200.0
			current_health += (max_health - old_max)  # Heal on evolution
			base_move_speed = 110.0
			damage_multiplier = 2.0
			_configure_stage_3_abilities()
	
	# Update health bar
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

# ============================================
# Ability Configuration per Stage
# ============================================

func _configure_stage_1_abilities() -> void:
	# Stage 1: Weak monster
	if ability_1:  # Front Cleave
		ability_1.damage = 12.0
		ability_1.cooldown = 4.5
		if "cone_angle" in ability_1:
			ability_1.cone_angle = 50.0
	
	if ability_2:  
		ability_2.damage = 18.0
		ability_2.cooldown = 12.0
	
	if ability_3: 
		ability_3.cooldown = 999999.0

func _configure_stage_2_abilities() -> void:
	# Stage 2: Medium power
	if ability_1:
		ability_1.damage = 17.0
		ability_1.cooldown = 3.0
		if "cone_angle" in ability_1:
			ability_1.cone_angle = 60.0
	
	if ability_2:
		ability_2.damage = 25.0
		ability_2.cooldown = 8.0
	
	if ability_3:  # Ground Slam - UNLOCKED
		ability_3.damage = 32.0
		ability_3.cooldown = 15.0
		if "area_of_effect" in ability_3:
			ability_3.area_of_effect = 120.0

func _configure_stage_3_abilities() -> void:
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

# ============================================
# Damage Multiplier System
# ============================================

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

# ============================================
# Visual Scaling per Stage
# ============================================

func _update_stage_scale(stage: int) -> void:
	var target_scale = Vector2.ONE
	
	match stage:
		1:
			target_scale = Vector2(1.0, 1.0)   # Normal
		2:
			target_scale = Vector2(1.25, 1.25) # 25% bigger
		3:
			target_scale = Vector2(1.5, 1.5)   # 50% bigger - APEX
	
	# Smooth growth animation
	var tween = create_tween()
	tween.tween_property(self, "scale", target_scale, 0.5)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

# ============================================
# Helper Methods
# ============================================

func get_stage_name() -> String:
	match current_stage:
		1:
			return "Vulnerable"
		2:
			return "Dangerous"
		3:
			return "APEX PREDATOR"
		_:
			return "Unknown"
