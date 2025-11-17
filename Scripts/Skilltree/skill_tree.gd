extends Resource
class_name SkillTree

@export var tree_name: String = "Skill Tree"
@export var tree_owner: String = "Hero"  # "Vlad", "Dragon", etc.
@export var skills: Array[SkillNode] = []

func get_skill_by_id(skill_id: String) -> SkillNode:
	for skill in skills:
		if skill.skill_id == skill_id:
			return skill
	return null

func get_skills_by_tier(tier: int) -> Array[SkillNode]:
	var tier_skills: Array[SkillNode] = []
	for skill in skills:
		if skill.tier == tier:
			tier_skills.append(skill)
	return tier_skills

func get_max_tier() -> int:
	var max_t = 0
	for skill in skills:
		if skill.tier > max_t:
			max_t = skill.tier
	return max_t
