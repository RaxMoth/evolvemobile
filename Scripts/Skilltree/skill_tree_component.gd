extends Node
class_name SkillTreeComponent

signal skill_unlocked(skill: SkillNode)
signal skill_points_changed(current: int, total_earned: int)
signal level_up(new_level: int)

@export var skill_tree_definition: SkillTree  # The template
@export var skill_points_per_level: int = 1
@export var starting_skill_points: int = 0

var current_level: int = 1
var total_skill_points_earned: int = 0
var spent_skill_points: int = 0
var unlocked_skill_ids: Array[String] = []
var applied_stat_bonuses: Dictionary = {}  # Cumulative bonuses

# Reference to owner entity (hero/monster)
var owner_entity: Node = null

func _ready() -> void:
	owner_entity = get_parent()
	total_skill_points_earned = starting_skill_points
	_initialize_stat_bonuses()

func _initialize_stat_bonuses() -> void:
	applied_stat_bonuses = {
		"max_health": 0.0,
		"attack_damage": 0.0,
		"move_speed": 0.0,
		"attack_speed": 0.0,
		"defense": 0.0,
	}

# ============================================
# Skill Point Management
# ============================================

func get_available_skill_points() -> int:
	return total_skill_points_earned - spent_skill_points

func add_skill_points(amount: int) -> void:
	total_skill_points_earned += amount
	skill_points_changed.emit(get_available_skill_points(), total_skill_points_earned)

func level_up_entity() -> void:
	current_level += 1
	add_skill_points(skill_points_per_level)
	level_up.emit(current_level)
	print(owner_entity.name + " reached level " + str(current_level) + "!")

# ============================================
# Skill Unlocking
# ============================================

func can_unlock_skill(skill_id: String) -> bool:
	# Already unlocked?
	if unlocked_skill_ids.has(skill_id):
		return false
	
	var skill = skill_tree_definition.get_skill_by_id(skill_id)
	if not skill:
		return false
	
	return skill.can_unlock(unlocked_skill_ids, current_level, get_available_skill_points())

func unlock_skill(skill_id: String) -> bool:
	if not can_unlock_skill(skill_id):
		return false
	
	var skill = skill_tree_definition.get_skill_by_id(skill_id)
	if not skill:
		return false
	
	# Spend points
	spent_skill_points += skill.skill_point_cost
	unlocked_skill_ids.append(skill_id)
	
	# Apply effects
	_apply_skill_effects(skill)
	
	# Emit signals
	skill_unlocked.emit(skill)
	skill_points_changed.emit(get_available_skill_points(), total_skill_points_earned)
	
	print(owner_entity.name + " unlocked: " + skill.skill_name)
	return true

# ============================================
# Skill Effects Application
# ============================================

func _apply_skill_effects(skill: SkillNode) -> void:
	match skill.skill_type:
		SkillNode.SkillType.STAT_BOOST:
			_apply_stat_bonuses(skill)
		
		SkillNode.SkillType.ABILITY_UNLOCK:
			_unlock_ability(skill)
		
		SkillNode.SkillType.ABILITY_UPGRADE:
			_upgrade_ability(skill)
		
		SkillNode.SkillType.PASSIVE_UNLOCK:
			_unlock_passive(skill)
		
		SkillNode.SkillType.SPECIAL:
			_apply_custom_effect(skill)

func _apply_stat_bonuses(skill: SkillNode) -> void:
	for stat_name in skill.stat_modifications.keys():
		var bonus = skill.stat_modifications[stat_name]
		
		if not applied_stat_bonuses.has(stat_name):
			applied_stat_bonuses[stat_name] = 0.0
		
		applied_stat_bonuses[stat_name] += bonus
	
	# Apply to entity
	if owner_entity.has_node("HeroStats"):
		var stats = owner_entity.get_node("HeroStats")
		_refresh_entity_stats(stats)

func _refresh_entity_stats(stats: HeroStatsComponent) -> void:
	# Apply all accumulated bonuses
	for stat_name in applied_stat_bonuses.keys():
		var bonus = applied_stat_bonuses[stat_name]
		if bonus > 0:
			stats.add_stat_modifier(stat_name, bonus, false)

func _unlock_ability(skill: SkillNode) -> void:
	if not skill.ability_reference:
		return
	
	# Add ability to entity's ability system
	if owner_entity.has_node("AbilitySystem"):
		var ability_sys = owner_entity.get_node("AbilitySystem")
		# Implementation depends on your ability system structure
		print("Unlocked ability: " + skill.ability_reference.ability_name)

func _upgrade_ability(skill: SkillNode) -> void:
	if not skill.ability_reference:
		return
	
	# Upgrade existing ability
	print("Upgraded ability: " + skill.ability_reference.ability_name)

func _unlock_passive(skill: SkillNode) -> void:
	# Add passive to entity
	print("Unlocked passive: " + skill.skill_name)

func _apply_custom_effect(skill: SkillNode) -> void:
	if skill.custom_effect_script:
		# Execute custom script
		print("Applied custom effect: " + skill.skill_name)

# ============================================
# Query Methods
# ============================================

func is_skill_unlocked(skill_id: String) -> bool:
	return unlocked_skill_ids.has(skill_id)

func get_unlocked_skills() -> Array[SkillNode]:
	var skills: Array[SkillNode] = []
	for skill_id in unlocked_skill_ids:
		var skill = skill_tree_definition.get_skill_by_id(skill_id)
		if skill:
			skills.append(skill)
	return skills

func get_stat_bonus(stat_name: String) -> float:
	return applied_stat_bonuses.get(stat_name, 0.0)

# ============================================
# Save/Load Support
# ============================================

func get_save_data() -> Dictionary:
	return {
		"level": current_level,
		"total_points": total_skill_points_earned,
		"spent_points": spent_skill_points,
		"unlocked_skills": unlocked_skill_ids.duplicate(),
		"stat_bonuses": applied_stat_bonuses.duplicate(),
	}

func load_save_data(data: Dictionary) -> void:
	current_level = data.get("level", 1)
	total_skill_points_earned = data.get("total_points", 0)
	spent_skill_points = data.get("spent_points", 0)
	unlocked_skill_ids = data.get("unlocked_skills", [])
	applied_stat_bonuses = data.get("stat_bonuses", {})
	
	# Reapply all bonuses
	if owner_entity and owner_entity.has_node("HeroStats"):
		_refresh_entity_stats(owner_entity.get_node("HeroStats"))
