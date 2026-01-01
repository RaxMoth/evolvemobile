extends EntityBase
class_name MonsterBase

signal stage_changed(new_stage: int)

@export_group("Monster Configuration")
@export var monster_stats: MonsterStats
@export var visual_config: MonsterVisualConfig

@export_group("Monster Abilities")
@export var ability_1: AbilityBase
@export var ability_2: AbilityBase
@export var ability_3: AbilityBase
@export var passive_ability: AbilityBase


@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var current_stage: int = 1
var current_health: float
var current_xp: float = 0.0
var damage_multiplier: float = 1.0

var ability_cooldowns := {
	"ability_1": 0.0,
	"ability_2": 0.0,
	"ability_3": 0.0,
}

func _ready() -> void:
	if not monster_stats:
		push_error(name + " missing MonsterStats resource!")
		return
	_apply_stage_configuration(1)
	_setup_monster_combat_role()
	
	super._ready()

func _process(delta: float) -> void:
	for key in ability_cooldowns.keys():
		if ability_cooldowns[key] > 0.0:
			ability_cooldowns[key] -= delta

	if passive_ability:
		passive_ability.on_passive_update(self, delta)
	

func _apply_stage_configuration(stage: int) -> void:
	if not monster_stats:
		return
	
	print("\n▶ Applying Stage ", stage, " Configuration for ", name)
	
	var old_max = current_health if stage > 1 else 0.0
	var new_health = monster_stats.get_health_for_stage(stage)
	
	if stage == 1:
		current_health = new_health
	else:
		current_health += (new_health - old_max)
	
	damage_multiplier = monster_stats.get_damage_mult_for_stage(stage)
	xp_value = monster_stats.get_xp_value_for_stage(stage)
	
	_configure_abilities_for_stage(stage)
	
	if health_bar:
		health_bar.max_value = new_health
		health_bar.value = current_health
	
	_update_stage_scale(stage)

func _get_entity_level() -> int:
	return current_stage

	
func _configure_abilities_for_stage(stage: int) -> void:
	if ability_1:
		ability_1.apply_stage_stats(stage)
		print("  ✓ Ability 1: ", ability_1.ability_name, " - Damage: ", ability_1.damage, ", CD: ", ability_1.cooldown)
	
	if ability_2:
		ability_2.apply_stage_stats(stage)
		print("  ✓ Ability 2: ", ability_2.ability_name, " - Damage: ", ability_2.damage, ", CD: ", ability_2.cooldown)
	
	if ability_3:
		ability_3.apply_stage_stats(stage)
		# Lock ability until stage 2
		if stage < 2:
			ability_3.cooldown = 999999.0
		print("  ✓ Ability 3: ", ability_3.ability_name, " - Damage: ", ability_3.damage, ", CD: ", ability_3.cooldown)

func _update_stage_scale(stage: int) -> void:
	if not monster_stats:
		return
	
	var target_scale = monster_stats.get_scale_for_stage(stage)
	
	var tween = create_tween()
	tween.tween_property(self, "scale", target_scale, 0.5) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)

# ============================================
# Combat Setup (Resource-Driven)
# ============================================

func _setup_monster_combat_role() -> void:
	if not monster_stats:
		return
	
	combat_role = Types.CombatRole.MELEE
	preferred_distance = 45.0
	min_distance = 20.0
	max_distance = 100.0
	strafe_enabled = true
	
	_update_combat_for_stage()

func _update_combat_for_stage() -> void:
	if not monster_stats:
		return
	
	strafe_speed = monster_stats.get_strafe_speed_for_stage(current_stage)
	strafe_change_interval = monster_stats.get_strafe_interval_for_stage(current_stage)

func _is_attack_ready() -> bool:
	return ability_cooldowns.get("ability_1", 0.0) <= 0.0

# ============================================
# Stage Change Hook
# ============================================

func _on_stage_entered(new_stage: int, _old_stage: int) -> void:
	_apply_stage_configuration(new_stage)
	_update_combat_for_stage()


# ============================================
# EntityBase Virtual Method Overrides
# ============================================

func _get_move_speed() -> float:
	if not monster_stats:
		return 60.0
	return monster_stats.get_speed_for_stage(current_stage)

func _get_attack_range() -> float:
	return 80.0

func _get_idle_retarget_time() -> float:
	return 2.0

func _get_idle_wander_radius() -> float:
	# Roam freely across the map like heroes!
	return 300.0 # Larger radius for exploration

func _get_keep_distance() -> float:
	return 50.0

func is_alive() -> bool:
	return current_health > 0.0

func get_health() -> float:
	return monster_stats.get_health_for_stage(current_stage) if monster_stats else current_health

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


# ============================================
# XP & Evolution System (Resource-Driven)
# ============================================

func gain_xp(amount: float) -> void:
	current_xp += amount
	
	var next_threshold = _get_next_evolution_threshold()
	print(name + " gained " + str(amount) + " XP (Total: " + str(current_xp) + "/" + str(next_threshold) + ")")
	
	_check_evolution()

func _check_evolution() -> void:
	var next_threshold = _get_next_evolution_threshold()
	
	if current_xp >= next_threshold:
		var new_stage = current_stage + 1
		
		if new_stage <= 3:
			_evolve_to_stage(new_stage)

func _evolve_to_stage(new_stage: int) -> void:
	var old_stage = current_stage
	current_stage = new_stage
	
	print("╔════════════════════════════════════╗")
	print("║  " + name + " EVOLVED TO STAGE " + str(current_stage) + "!  ║")
	print("╚════════════════════════════════════╝")
	
	# Reset cooldowns on evolution
	for key in ability_cooldowns.keys():
		ability_cooldowns[key] = 0.0
		
	if lv_label:
		lv_label.text = str(current_stage)
	# Visual update
	_update_stage_visuals(current_stage)
	
	# Call hook (applies stats from resource)
	_on_stage_entered(current_stage, old_stage)
	
	# Emit signal
	stage_changed.emit(current_stage)

func _get_next_evolution_threshold() -> int:
	if not monster_stats:
		return 999999
	
	return monster_stats.get_xp_threshold_for_stage(current_stage + 1)

# ============================================
# Stage Visuals
# ============================================


func _update_stage_visuals(stage: int) -> void:
	if not animated_sprite or not visual_config:
		return

	var sprite_frames = visual_config.get_sprite_frames_for_stage(stage)
	var animation_name = visual_config.get_animation_name_for_stage(stage)
	if sprite_frames:
		animated_sprite.sprite_frames = sprite_frames

	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(animation_name):
		animated_sprite.play(animation_name)
	else:
		var available_anims = animated_sprite.sprite_frames.get_animation_names()
		if available_anims.size() > 0:
			animated_sprite.play(available_anims[0])
			print(name + " using fallback animation: " + available_anims[0])
		else:
			push_warning(name + " has no animations available!")
	
	if visual_config.enable_stage_effects:
		_play_stage_effect(stage)

func _play_stage_effect(stage: int) -> void:
	# Flash sprite
	if animated_sprite:
		var flash_color = Color.WHITE
		match stage:
			2: flash_color = Color(1.5, 1.2, 0.8) # Orange
			3: flash_color = Color(1.8, 0.8, 0.8) # Red
		
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
		2: circle.default_color = Color.ORANGE
		3: circle.default_color = Color.RED
		_: circle.default_color = Color.YELLOW
	
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
		# Apply damage multiplier from resource
		var effective_damage = ability.damage * damage_multiplier
		ability.execute(self, target_entity, effective_damage)
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
	var next_threshold = _get_next_evolution_threshold()
	if next_threshold >= 999999:
		return 1.0
	
	var prev_threshold = 0
	if current_stage > 1:
		prev_threshold = monster_stats.get_xp_threshold_for_stage(current_stage)
	
	var xp_in_stage = current_xp - prev_threshold
	var xp_needed = next_threshold - prev_threshold
	
	return xp_in_stage / float(xp_needed)

func get_stage() -> int:
	return current_stage

func get_xp() -> float:
	return current_xp

func get_ability_cooldown(ability_name: String) -> float:
	return ability_cooldowns.get(ability_name, 0.0)

func is_ability_ready(ability_name: String) -> bool:
	return ability_cooldowns.get(ability_name, 0.0) <= 0.0
