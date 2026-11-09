extends SceneTree

## Writes Data/SkillTrees/<tree_id>.tres (one MetaSkillTree each, its nodes as
## sub-resources) from the seed data in Scripts/MetaSkills/skill_tree_data_v2.gd:
##   godot --headless --path <copy> -s res://tools/build_skill_trees.gd [-- [--force] <tree_id> ...]
## Use tools/build_skill_trees.sh: it runs this on a temp copy and copies the
## written files back. No id = all nine trees.
##
## A ONE-OFF: the .tres files are the trees now and are edited in the inspector
## (a later batch unhides its nodes there), so an existing file is kept unless
## --force is given. Prints "TREE <id> ..." per tree, "TREE_OUT <res path>" per
## written file and "TREE built <n>, kept <k>, of <m>"; exit 1 when a tree could
## not be written.

## Loaded by path: a -s script does not name project classes.
const DATA := preload("res://Scripts/MetaSkills/skill_tree_data_v2.gd")
const TREE_SCRIPT := preload("res://Scripts/MetaSkills/meta_skill_tree.gd")
const NODE_SCRIPT := preload("res://Scripts/MetaSkills/meta_skill_node.gd")
const OUT_DIR := "res://Data/SkillTrees"
## PersistedData.GOLD / STEEL / LEAVES.
const GOLD := &"gold"
const STEEL := &"steel"
const LEAVES := &"leaves"


func _initialize() -> void:
	var args := Array(OS.get_cmdline_user_args())
	var force := args.has("--force")
	args.erase("--force")
	var data: Dictionary = DATA.trees()
	var ids: Array = args if not args.is_empty() else data.keys()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var built := 0
	var kept := 0
	for raw: Variant in ids:
		var tree_id := StringName(str(raw))
		if not data.has(tree_id):
			push_error("TREE: unknown tree %s (known: %s)" % [tree_id, ", ".join(PackedStringArray(data.keys()))])
			continue
		var path := "%s/%s.tres" % [OUT_DIR, tree_id]
		if FileAccess.file_exists(path) and not force:
			print("TREE %s kept: %s exists (--force overwrites)" % [tree_id, path])
			kept += 1
			continue
		var t := _build_tree(tree_id, data[tree_id])
		var err := ResourceSaver.save(t, path)
		print("TREE %s -> %s (%d nodes, %d hidden, %s)" % [tree_id, path, t.nodes.size(), _hidden_count(t), error_string(err)])
		if err != OK:
			continue
		built += 1
		print("TREE_OUT " + path)
	print("TREE built %d, kept %d, of %d" % [built, kept, ids.size()])
	quit(0 if built + kept == ids.size() else 1)


func _build_tree(tree_id: StringName, specs: Array) -> TREE_SCRIPT:
	var t := TREE_SCRIPT.new()
	var title: Array = DATA.TITLES[tree_id]
	t.id = tree_id
	t.display_name = title[0]
	t.description = title[1]
	t.branches = PackedStringArray(DATA.BRANCHES[tree_id])
	var side_wide := String(tree_id).ends_with("_base")
	if side_wide:
		t.gate_kind = TREE_SCRIPT.GateKind.POINTS
		t.tier_gates.assign(DATA.BASE_TIER_POINTS)
	else:
		t.gate_kind = TREE_SCRIPT.GateKind.LEVEL
		t.tier_gates.assign(DATA.CHARACTER_TIER_LEVEL)
		t.owner_id = StringName(String(tree_id).get_slice("_", 1))
	t.ai_build_order.assign(DATA.ai_build_order().get(tree_id, []))
	var currency := GOLD if side_wide else (STEEL if String(tree_id).begins_with("hero_") else LEAVES)
	for spec: Dictionary in specs:
		t.nodes.append(_build_node(spec, currency))
	return t


func _build_node(spec: Dictionary, currency: StringName) -> NODE_SCRIPT:
	var n := NODE_SCRIPT.new()
	n.id = spec["id"]
	# Readable, stable sub-resource ids in the .tres ("t1_dmg", not "Resource_x7k2p").
	n.resource_scene_unique_id = String(n.id)
	n.display_name = spec["name"]
	n.description = spec["desc"]
	n.tier = spec["tier"]
	n.branch = spec["branch"]
	n.currency = currency
	var costs: Array = DATA.COSTS[spec["cost"]]
	var ranks: Array = spec["ranks"]
	n.cost = costs[0]
	n.max_rank = ranks.size()
	if ranks.size() > 1:
		n.rank_costs.assign(costs)
		n.rank_values.assign(ranks)
	n.stat_name = spec["stat"]
	n.stat_value = ranks[0]
	n.stat_multiplicative = spec["mult"]
	n.ability_name = spec["ability"]
	n.requires.assign(spec["requires"])
	n.capstone = spec["capstone"]
	n.hidden = spec["hidden"]
	return n


func _hidden_count(t: TREE_SCRIPT) -> int:
	var count := 0
	for n in t.nodes:
		if n.hidden:
			count += 1
	return count
