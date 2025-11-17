extends Resource
class_name SkillNode

enum SkillType {
	STAT_BOOST,      # Increase stats (health, damage, speed)
	ABILITY_UNLOCK,  # Unlock new ability
	ABILITY_UPGRADE, # Improve existing ability
	PASSIVE_UNLOCK,  # Add new passive effect
	SPECIAL          # Custom effects
}

@export_group("Skill Identity")
@export var skill_id: String = ""  # Unique identifier
@export var skill_name: String = "Unnamed Skill"
@export var description: String = ""
@export var icon: Texture2D
@export var skill_type: SkillType = SkillType.STAT_BOOST

@export_group("Requirements")
@export var required_level: int = 1
@export var skill_point_cost: int = 1
@export var prerequisite_skills: Array[String] = []  # IDs of required skills

@export_group("Effects")
@export var stat_modifications: Dictionary = {}
# Example: {"max_health": 20, "attack_damage": 5, "move_speed": 10}

@export var ability_reference: AbilityBase  # For ability unlocks/upgrades
@export var custom_effect_script: GDScript  # For special effects

@export_group("Visual")
@export var tier: int = 1  # Which row in skill tree (1=bottom, 5=top)
@export var position_in_tier: int = 0  # Position within the tier

# Check if this skill can be unlocked
func can_unlock(unlocked_skills: Array[String], current_level: int, available_points: int) -> bool:
	# Check level requirement
	if current_level < required_level:
		return false
	
	# Check skill points
	if available_points < skill_point_cost:
		return false
	
	# Check prerequisites
	for prereq_id in prerequisite_skills:
		if not unlocked_skills.has(prereq_id):
			return false
	
	return true

func get_effect_description() -> String:
	var text = ""
	
	match skill_type:
		SkillType.STAT_BOOST:
			for stat_name in stat_modifications.keys():
				var value = stat_modifications[stat_name]
				text += "\n+" + str(value) + " " + stat_name.capitalize()
		
		SkillType.ABILITY_UNLOCK:
			if ability_reference:
				text += "\nUnlocks: " + ability_reference.ability_name
		
		SkillType.ABILITY_UPGRADE:
			if ability_reference:
				text += "\nUpgrades: " + ability_reference.ability_name
	
	return text
