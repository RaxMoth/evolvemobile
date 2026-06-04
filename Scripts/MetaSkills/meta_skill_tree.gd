class_name MetaSkillTree
extends Resource

## MetaSkillTree — a named collection of MetaSkillNodes that belong
## together (e.g. all the "Hero Base" upgrades). The tree's id is also
## the key used in PersistedData (`get_unlocked_skills(tree_id)`).

@export var id: StringName = &""
@export var display_name: String = "Tree"
@export var description: String = ""
@export var nodes: Array[MetaSkillNode] = []


func find_node(node_id: StringName) -> MetaSkillNode:
	for n in nodes:
		if n.id == node_id:
			return n
	return null


func nodes_in_tier(tier: int) -> Array[MetaSkillNode]:
	var out: Array[MetaSkillNode] = []
	for n in nodes:
		if n.tier == tier:
			out.append(n)
	return out


func max_tier() -> int:
	var t: int = 0
	for n in nodes:
		if n.tier > t:
			t = n.tier
	return t
