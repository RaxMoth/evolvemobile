extends MonsterBase
class_name Grount

enum StageNames {VULNERABLE = 1, DANGEROUS = 2, APEX_PREDATOR = 3}

var damage_multiplier: float = 1.0

func _ready() -> void:
	add_to_group("Monster")
	_apply_stage_configuration(1)
	super._ready()
	
	print("═══════════════════════════════════════")
	print("║ ", name, " SPAWNED")
	print("║ Stage: ", get_stage_name())
	print("║ Groups: ", get_groups())
	print("═══════════════════════════════════════")

# ============================================
# Stage Change - Grount-Specific Behavior
# ============================================

func _on_stage_entered(new_stage: int, old_stage: int) -> void:
	# Call parent first for common behavior
	super._on_stage_entered(new_stage, old_stage)
	
	# Then add grount-specific behavior
	_apply_stage_configuration(new_stage)
	_update_stage_scale(new_stage)

func _apply_stage_configuration(stage: int) -> void:
	print("\n▶ Applying Stage ", stage, " Configuration for ", name)
	
	match stage:
		1: # Vulnerable
			max_health = 800.0
			current_health = max_health
			base_move_speed = 60.0
			damage_multiplier = 1.0
			
		2: # Dangerous
			var old_max = max_health
			max_health = 1400.0
			current_health += (max_health - old_max)
			base_move_speed = 80.0
			damage_multiplier = 1.4
			
		3: # Apex Predator
			var old_max = max_health
			max_health = 2200.0
			current_health += (max_health - old_max)
			base_move_speed = 110.0
			damage_multiplier = 2.0
	
	# Apply stage stats to abilities
	_configure_abilities_for_stage(stage)
	
	# Update health bar
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	
	print("  ✓ HP: ", current_health, "/", max_health)
	print("  ✓ Speed: ", base_move_speed)
	print("  ✓ Damage Multiplier: ", damage_multiplier)

func _configure_abilities_for_stage(stage: int) -> void:
	if ability_1:
		ability_1.apply_stage_stats(stage)
		print("  ✓ Ability 1: ", ability_1.ability_name, " - Damage: ", ability_1.damage, ", CD: ", ability_1.cooldown)
	
	if ability_2:
		ability_2.apply_stage_stats(stage)
		print("  ✓ Ability 2: ", ability_2.ability_name, " - Damage: ", ability_2.damage, ", CD: ", ability_2.cooldown)
	
	if ability_3:
		ability_3.apply_stage_stats(stage)
		# Lock Ground Slam until stage 2
		if stage < 2:
			ability_3.cooldown = 999999.0
		print("  ✓ Ability 3: ", ability_3.ability_name, " - Damage: ", ability_3.damage, ", CD: ", ability_3.cooldown)

# ============================================
# Combat - Override with Damage Multiplier
# ============================================

func _try_use_ability(ability_name: String, ability: AbilityBase) -> bool:
	if not ability:
		print("❌ ", name, " - No ability assigned for ", ability_name)
		return false
	
	if ability_cooldowns.get(ability_name, 0.0) > 0.0:
		print("⏳ ", name, " - ", ability.ability_name, " on cooldown (", ability_cooldowns[ability_name], "s)")
		return false
	
	if not ability.can_use(self):
		print("❌ ", name, " - ", ability.ability_name, " can't be used")
		return false
	
	# Calculate effective damage with multiplier
	var effective_damage = ability.damage * damage_multiplier
	
	print("\n🎯 ", name, " USING ABILITY:")
	print("  • Ability: ", ability.ability_name)
	print("  • Base Damage: ", ability.damage)
	print("  • Multiplier: ", damage_multiplier)
	print("  • Effective Damage: ", effective_damage)
	print("  • Target: ", target_entity.name if is_instance_valid(target_entity) else "NONE")
	print("  • Target Groups: ", target_entity.get_groups() if is_instance_valid(target_entity) else "N/A")
	
	# Pass effective damage as parameter
	ability.execute(self, target_entity, effective_damage)
	
	ability_cooldowns[ability_name] = ability.cooldown
	return true

# ============================================
# Visuals
# ============================================

func _update_stage_scale(stage: int) -> void:
	var target_scale = Vector2.ONE
	
	match stage:
		1:
			target_scale = Vector2(1.0, 1.0)
		2:
			target_scale = Vector2(1.25, 1.25)
		3:
			target_scale = Vector2(1.5, 1.5)
	
	var tween = create_tween()
	tween.tween_property(self, "scale", target_scale, 0.5) \
		.set_trans(Tween.TRANS_BACK) \
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
