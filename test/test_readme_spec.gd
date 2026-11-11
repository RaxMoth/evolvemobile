extends TestCase

## README.md is the design spec. These tests read its tables and compare them
## with the shipped data (hero and monster stats, ability and skill-tree
## resources, the mob scenes, MatchRewards, the UI kit), so a number changed
## on one side only fails here. They also check that every file the README
## and Docs/INSTRUCTOR.md name by path exists. The balance numbers (sim
## results) cannot be re-measured in a test; the overview table is checked
## against the "Measured Balance" tables instead.

const README_PATH := "res://README.md"
const INSTRUCTOR_PATH := "res://Docs/INSTRUCTOR.md"
const TREE_DIR := "res://Data/SkillTrees"
const KIT_DIR := "res://Assets/UI/Kit"
const ICON_DIR := "res://Assets/UI/Icons"
const BAT := "res://Scenes/NPCs/Mob/Mobs/Bat/Bat.tscn"
const HOG := "res://Scenes/NPCs/Mob/Mobs/Hog/Hog.tscn"
const PET := "res://Scenes/NPCs/Hero/Heros/Support/Ted/Abilities/Passive/TedsPet.tscn"

## Each monster's README section (the heading's ending).
const MONSTER_SECTIONS := {
	&"grount": "Monster (Grount - The Bull)",
	&"nyxa": "Monster: Nyxa (the Dusk Matriarch)",
	&"gorrak": "Monster: Gorrak (the Boar King)",
}
## Grount's ability tables: heading -> [index in CharacterDef.abilities(),
## the property behind the table's fourth column].
const GROUNT_TABLES := {
	"Front Cleave (Ability 1)": [1, "cone_angle_per_stage"],
	"Ram Dash (Ability 2)": [2, "dash_distance"],
	"Ground Slam (Ability 3 - Ultimate)": [3, "aoe_per_stage"],
}
## A backticked path in a doc is checked when it starts with one of these
## folders and ends in one of these file types.
const DOC_ROOTS: Array[String] = ["Scenes/", "Scripts/", "Assets/", "Data/", "tools/", "test/", "Docs/", "addons/"]
const DOC_FILE_TYPES: Array[String] = ["gd", "tscn", "tres", "sh", "py", "svg", "gdshader", "csv", "md", "ttf", "txt", "json", "zsh"]
## Characters that mark a pattern or a placeholder, not one file.
const DOC_PLACEHOLDERS := "<>*{}|$"

var _lines: PackedStringArray = PackedStringArray()


# ---------- reading the README ----------

func _readme_lines() -> PackedStringArray:
	if _lines.is_empty():
		_lines = FileAccess.get_file_as_string(README_PATH).split("\n")
	return _lines


## The number of "#" a markdown heading line starts with; 99 for any other line.
func _heading_level(line: String) -> int:
	var n := 0
	while n < line.length() and line[n] == "#":
		n += 1
	if n == 0 or n >= line.length() or line[n] != " ":
		return 99
	return n


## The README from the heading that ends with `title` up to the next heading
## of the same or a higher level ("" when there is none). Lines inside a code
## fence are never headings.
func _section(title: String) -> String:
	var out := PackedStringArray()
	var level := 0
	var in_code := false
	for line in _readme_lines():
		if line.begins_with("```"):
			in_code = not in_code
		if not in_code and line.begins_with("#"):
			if level > 0 and _heading_level(line) <= level:
				break
			if level == 0 and line.ends_with(title) and _heading_level(line) < 99:
				level = _heading_level(line)
		if level > 0:
			out.append(line)
	return "\n".join(out)


## Every markdown table of `section`: its rows as cells (trimmed, bold marks
## removed), the header first, the |---| line left out.
func _tables(section: String) -> Array:
	var tables: Array = []
	var rows: Array[PackedStringArray] = []
	for line in section.split("\n"):
		var t := line.strip_edges()
		if not t.begins_with("|"):
			if not rows.is_empty():
				tables.append(rows)
				rows = []
			continue
		if t.replace("|", "").replace("-", "").replace(":", "").strip_edges().is_empty():
			continue
		var cells := PackedStringArray()
		for cell in t.trim_prefix("|").trim_suffix("|").split("|"):
			cells.append(cell.strip_edges().replace("**", ""))
		rows.append(cells)
	if not rows.is_empty():
		tables.append(rows)
	return tables


## The body rows (no header) of the first table of `section`.
func _table(section: String) -> Array[PackedStringArray]:
	var tables := _tables(section)
	var body: Array[PackedStringArray] = []
	if tables.is_empty():
		return body
	var rows: Array = tables[0]
	for i in range(1, rows.size()):
		body.append(rows[i])
	return body


func _collapse(text: String) -> String:
	return RegEx.create_from_string("\\s+").sub(text, " ", true).strip_edges()


## The top-level bullets of `section`: each "- ..." line with its indented
## continuation lines (nested bullets included), whitespace collapsed.
func _bullets(section: String) -> PackedStringArray:
	var out := PackedStringArray()
	var current := ""
	for line in section.split("\n"):
		if line.begins_with("- "):
			if not current.is_empty():
				out.append(_collapse(current))
			current = line
		elif not current.is_empty():
			if line.begins_with(" ") and not line.strip_edges().is_empty():
				current += " " + line
			else:
				out.append(_collapse(current))
				current = ""
	if not current.is_empty():
		out.append(_collapse(current))
	return out


## The first bullet that contains `needle` ("" when none does).
func _bullet_with(bullets: PackedStringArray, needle: String) -> String:
	for b in bullets:
		if b.contains(needle):
			return b
	return ""


## Every number in `text`, in order ("2,500" reads as 2500).
func _numbers(text: String) -> Array[float]:
	var out: Array[float] = []
	for m in RegEx.create_from_string("\\d+(?:,\\d{3})*(?:\\.\\d+)?").search_all(text):
		out.append(m.get_string().replace(",", "").to_float())
	return out


## The groups `pattern` captures in `text`, as numbers (empty = no match).
func _captured(text: String, pattern: String) -> Array[float]:
	var out: Array[float] = []
	var m := RegEx.create_from_string(pattern).search(text)
	if m == null:
		return out
	for i in range(1, m.get_group_count() + 1):
		out.append(m.get_string(i).to_float())
	return out


## A value as the README writes it: whole numbers without ".0", at most two
## decimals otherwise.
func _fmt(value: float) -> String:
	var r := snappedf(value, 0.01)
	if is_equal_approx(r, roundf(r)):
		return str(roundi(r))
	var s := "%.2f" % r
	return s.trim_suffix("0")


## `values` from index `from` on, as "a<sep>b<sep>c".
func _joined(values: Array, sep: String, from: int = 0) -> String:
	var parts := PackedStringArray()
	for i in range(from, values.size()):
		parts.append(_fmt(float(values[i])))
	return sep.join(parts)


## "2.0 / 1.8" -> "2 / 1.8", so a README number and _fmt agree.
func _without_point_zero(text: String) -> String:
	return RegEx.create_from_string("(\\d)\\.0(?!\\d)").sub(text, "$1", true)


func _assert_numbers(actual: Array[float], expected: Array[float], what: String) -> void:
	assert_eq(actual.size(), expected.size(), "%s: %s numbers in the README, %s expected" % [what, str(actual), str(expected)])
	for i in mini(actual.size(), expected.size()):
		assert_near(actual[i], expected[i], 0.001, "%s, number %d" % [what, i + 1])


func _basic_attack(def: CharacterDef) -> AbilityBase:
	for a in def.abilities():
		if a != null and a.ability_type == AbilityBase.AbilityType.BASIC_ATTACK:
			return a
	return null


## A scene's root properties, read from an instance that never enters the tree.
func _scene_values(path: String, keys: Array[String]) -> Dictionary:
	var node: Node = (load(path) as PackedScene).instantiate()
	var out := {}
	for key in keys:
		out[key] = float(node.get(key))
	node.free()
	return out


func _svg_count(dir_path: String) -> int:
	var count := 0
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".svg"):
			count += 1
	for sub in DirAccess.get_directories_at(dir_path):
		count += _svg_count(dir_path.path_join(sub))
	return count


# ---------- heroes ----------

func test_hero_roster_table_is_the_hero_stats() -> void:
	var rows := _table(_section("Current Roster (4 Heroes)"))
	assert_eq(rows.size(), GameManager.ROSTER.heroes.size(), "one README row per roster hero")
	var pet := _scene_values(PET, ["attack_damage", "attack_cooldown"])
	for row in rows:
		var def: CharacterDef = GameManager.ROSTER.find(StringName(row[0].to_lower()))
		assert_true(def != null, "the roster knows the README's hero '%s'" % row[0])
		if def == null:
			continue
		var stats := def.stats as HeroStats
		assert_eq(row[1], stats.hero_class, "%s: class" % row[0])
		assert_near(row[2].to_float(), stats.base_max_health, 0.001, "%s: HP" % row[0])
		assert_near(row[4].to_float(), stats.base_attack_range, 0.001, "%s: range" % row[0])
		var basic := _basic_attack(def)
		var dps: float = basic.damage / basic.cooldown
		if def.character_id() == &"ted":
			dps += float(pet["attack_damage"]) / float(pet["attack_cooldown"])
		assert_near(row[3].to_float(), dps, 0.06, "%s: DPS (basic attack; Ted with his fox)" % row[0])


func test_hero_details_are_the_stats_and_the_kit() -> void:
	for def in GameManager.ROSTER.heroes:
		var stats := def.stats as HeroStats
		var title := "%s (%s)" % [stats.hero_name, stats.hero_class]
		var bullets := _bullets(_section(title))
		assert_false(bullets.is_empty(), "the README has a '%s' section" % title)
		if bullets.is_empty():
			continue
		var base: Array[float] = [stats.base_max_health, stats.base_move_speed, stats.vision_radius]
		_assert_numbers(_numbers(_bullet_with(bullets, "**Base Stats**")), base, "%s base stats (HP, speed, vision)" % stats.hero_name)
		var scaling: Array[float] = [stats.health_per_level, stats.damage_per_level]
		_assert_numbers(_numbers(_bullet_with(bullets, "**Scaling**")), scaling, "%s scaling per level" % stats.hero_name)
		for ability in def.abilities():
			var bullet := _bullet_with(bullets, ability.ability_name)
			assert_false(bullet.is_empty(), "%s: the README names '%s'" % [stats.hero_name, ability.ability_name])
			if ability.ability_type == AbilityBase.AbilityType.PASSIVE or bullet.is_empty():
				continue
			assert_true(_numbers(bullet).has(ability.cooldown), "%s: '%s' shows its %s s cooldown (%s)" % [stats.hero_name, ability.ability_name, _fmt(ability.cooldown), bullet])


# ---------- monsters ----------

func test_monster_roster_table_is_the_stats_and_the_defs() -> void:
	var rows := _table(_section("Monster Roster (overview and balance sheet)"))
	assert_eq(rows.size(), GameManager.ROSTER.monsters.size(), "one README row per roster monster")
	for row in rows:
		var id := StringName(row[0].get_slice(",", 0).to_lower())
		var def: CharacterDef = GameManager.ROSTER.find(id)
		assert_true(def != null, "the roster knows the README's monster '%s'" % row[0])
		if def == null:
			continue
		var stats := def.stats as MonsterStats
		var hp: Array[float] = [stats.stage_1_health, stats.stage_2_health, stats.stage_3_health]
		_assert_numbers(_numbers(row[4]), hp, "%s HP per stage" % id)
		var xp: Array[float] = [float(stats.stage_2_xp), float(stats.stage_3_xp)]
		_assert_numbers(_numbers(row[5]), xp, "%s evolution thresholds" % id)
		var hunts: Array[float] = [float(def.opponent_after_matches)]
		_assert_numbers(_numbers(row[3]), hunts, "%s: hunts until the heroes meet it" % id)
		if def.unlocked_by_default:
			assert_eq(row[2], "from the start", "%s is owned from the start" % id)
		else:
			var unlock: Array[float] = [float(def.unlock_cost), float(def.unlock_requires_level)]
			_assert_numbers(_numbers(row[2]), unlock, "%s unlock price and level" % id)


func test_monster_stage_tables_are_the_stats() -> void:
	for id: StringName in MONSTER_SECTIONS:
		var def: CharacterDef = GameManager.ROSTER.find(id)
		var stats := def.stats as MonsterStats
		var section := _section(String(MONSTER_SECTIONS[id]))
		var seen := {}
		for row in _table(section):
			var key := row[0]
			seen[key] = true
			var per_stage: Array[float] = []
			for stage: int in [1, 2, 3]:
				var numbers := _numbers(row[stage])
				per_stage.append(numbers[0] if not numbers.is_empty() else -1.0)
			match key:
				"HP":
					var hp: Array[float] = [stats.stage_1_health, stats.stage_2_health, stats.stage_3_health]
					_assert_numbers(per_stage, hp, "%s HP" % id)
				"Speed":
					var speed: Array[float] = [stats.stage_1_speed, stats.stage_2_speed, stats.stage_3_speed]
					_assert_numbers(per_stage, speed, "%s speed" % id)
				"Scale":
					var sizes: Array[float] = [stats.stage_1_scale.x, stats.stage_2_scale.x, stats.stage_3_scale.x]
					_assert_numbers(per_stage, sizes, "%s scale" % id)
				"Strafe":
					var strafe: Array[float] = [stats.stage_1_strafe_speed, stats.stage_2_strafe_speed, stats.stage_3_strafe_speed]
					_assert_numbers(per_stage, strafe, "%s strafe speed" % id)
				"Damage Mult":
					for stage: int in [1, 2, 3]:
						assert_near(per_stage[stage - 1], stats.get_damage_mult_for_stage(stage), 0.001, "%s damage multiplier at stage %d" % [id, stage])
				"Damage taken":
					for stage: int in [1, 2, 3]:
						assert_near(per_stage[stage - 1], stats.get_damage_taken_mult(stage), 0.001, "%s damage taken at stage %d" % [id, stage])
				"XP Required":
					assert_near(per_stage[1], float(stats.stage_2_xp), 0.001, "%s stage 2 XP" % id)
					assert_near(per_stage[2], float(stats.stage_3_xp), 0.001, "%s stage 3 XP" % id)
		for key: String in ["HP", "Speed", "XP Required"]:
			assert_true(seen.has(key), "%s: the README stage table has a '%s' row" % [id, key])
		for stage_name in def.stage_names:
			assert_true(section.contains(stage_name), "%s: the README names the stage '%s'" % [id, stage_name])
		for ability in def.abilities():
			assert_true(section.contains(ability.ability_name), "%s: the README names '%s'" % [id, ability.ability_name])


func test_grount_ability_tables_are_the_resources() -> void:
	var abilities := GameManager.ROSTER.find(&"grount").abilities()
	for title: String in GROUNT_TABLES:
		var spec: Array = GROUNT_TABLES[title]
		var ability: AbilityBase = abilities[int(spec[0])]
		var fourth: Variant = ability.get(String(spec[1]))
		var rows := _table(_section(title))
		assert_eq(rows.size(), 3, "'%s' has a row per stage" % title)
		assert_true(title.begins_with(ability.ability_name), "'%s' is the table of %s" % [title, ability.ability_name])
		for row in rows:
			var stage := row[0].to_int()
			if row[2].contains("LOCKED"):
				assert_true(stage < ability.unlock_stage, "%s is locked at stage %d" % [ability.ability_name, stage])
				continue
			assert_true(stage >= ability.unlock_stage, "%s is unlocked at stage %d" % [ability.ability_name, stage])
			assert_near(row[1].to_float(), ability.damage_per_stage[stage - 1], 0.001, "%s damage at stage %d" % [ability.ability_name, stage])
			assert_near(row[2].to_float(), ability.cooldown_per_stage[stage - 1], 0.001, "%s cooldown at stage %d" % [ability.ability_name, stage])
			var want: float = float(fourth[stage - 1]) if fourth is Array else float(fourth)
			assert_near(row[3].to_float(), want, 0.001, "%s %s at stage %d" % [ability.ability_name, spec[1], stage])


func test_nyxa_and_gorrak_ability_bullets_are_the_resources() -> void:
	for id: StringName in [&"nyxa", &"gorrak"]:
		var def: CharacterDef = GameManager.ROSTER.find(id)
		var bullets := _bullets(_section(String(MONSTER_SECTIONS[id])))
		for ability in def.abilities():
			if ability.ability_type == AbilityBase.AbilityType.PASSIVE:
				continue
			var bullet := _without_point_zero(_bullet_with(bullets, "- **%s**" % ability.ability_name))
			assert_false(bullet.is_empty(), "%s: '%s' has its own bullet" % [id, ability.ability_name])
			if bullet.is_empty():
				continue
			var from: int = ability.unlock_stage - 1
			var rows := {
				"damage": ability.damage_per_stage,
				"cooldown": ability.cooldown_per_stage,
				"radius": ability.aoe_per_stage,
			}
			if "cone_angle_per_stage" in ability:
				rows["cone angle"] = ability.get("cone_angle_per_stage")
			for what: String in rows:
				var values: Array = rows[what]
				if values.is_empty():
					continue
				var shown := _joined(values, " / ", from)
				assert_true(bullet.contains(shown), "%s: %s shows its %s per stage '%s' (%s)" % [id, ability.ability_name, what, shown, bullet])


func test_the_overview_repeats_the_measured_balance() -> void:
	var overview := _table(_section("Monster Roster (overview and balance sheet)"))
	var measured := _tables(_section("Measured Balance (headless sim, fresh save)"))
	assert_eq(measured.size(), overview.size(), "one measured table per monster")
	for row in overview:
		var monster := row[0].get_slice(",", 0)
		var found := false
		for table: Array in measured:
			var header: PackedStringArray = table[0]
			if header[0] != monster:
				continue
			found = true
			var last: PackedStringArray = table[table.size() - 1]
			var wins: Array[float] = [_numbers(last[1])[0], _numbers(last[2])[0]]
			_assert_numbers(_numbers(row[6]), wins, "%s hero wins (heroes side, monster side)" % monster)
			_assert_numbers(_numbers(row[7]), _numbers(last[3]), "%s timeouts" % monster)
		assert_true(found, "Measured Balance has a table for %s" % monster)


# ---------- mobs and rewards ----------

func test_mob_camp_table_is_the_mob_scenes() -> void:
	var keys: Array[String] = ["max_health", "base_attack_damage", "attack_cooldown", "hero_xp_value", "xp_value"]
	var scenes := {"Bat Camp": BAT, "Hog Camp": HOG}
	var checked := 0
	for row in _table(_section("Mob Camps")):
		if not scenes.has(row[0]):
			assert_true(row[row.size() - 1].contains("not built"), "'%s' is marked as not built" % row[0])
			continue
		checked += 1
		var mob := _scene_values(String(scenes[row[0]]), keys)
		var want: Array[float] = [float(mob["max_health"]), float(mob["base_attack_damage"]), float(mob["attack_cooldown"]), float(mob["hero_xp_value"]), float(mob["xp_value"])]
		var shown: Array[float] = [row[1].to_float(), row[2].to_float(), row[3].to_float(), row[5].to_float(), row[6].to_float()]
		_assert_numbers(shown, want, "%s (HP, damage, cooldown, hero XP, monster XP)" % row[0])
		assert_near(row[7].to_float(), row[4].to_float() * float(mob["xp_value"]), 0.001, "%s: camp size x monster XP" % row[0])
	assert_eq(checked, scenes.size(), "the Bat and the Hog camp rows")


func test_earning_rates_are_the_match_rewards_constants() -> void:
	var section := _section("Earning Rates v2 (Per Round)")
	var win_loss: Array[float] = [float(MatchRewards.CURRENCY_WIN), float(MatchRewards.CURRENCY_LOSS)]
	_assert_numbers(_captured(section, "- Win: (\\d+), Loss: (\\d+)"), win_loss, "currency win / loss")
	var per_kill: Array[float] = [float(MatchRewards.CURRENCY_PER_KILL)]
	_assert_numbers(_captured(section, "- Kills: \\+(\\d+) per mob killed"), per_kill, "currency per kill")
	var per_minute: Array[float] = [float(MatchRewards.CURRENCY_PER_MINUTE)]
	_assert_numbers(_captured(section, "- Survival Time: \\+(\\d+) per full minute"), per_minute, "currency per minute")
	var per_survivor: Array[float] = [float(MatchRewards.CURRENCY_PER_SURVIVOR)]
	_assert_numbers(_captured(section, "- Heroes Alive \\(Heroes\\): \\+(\\d+) per survivor"), per_survivor, "currency per survivor")
	var per_stage: Array[float] = [float(MatchRewards.CURRENCY_PER_STAGE)]
	_assert_numbers(_captured(section, "- Stage Reached \\(Monster\\): \\+(\\d+) per stage"), per_stage, "currency per stage")
	var gold: Array[float] = [float(MatchRewards.GOLD_WIN), float(MatchRewards.GOLD_LOSS), float(MatchRewards.GOLD_PER_KILL)]
	_assert_numbers(_captured(section, "\\*\\*Gold\\*\\*: Win (\\d+), Loss (\\d+), \\+(\\d+) per mob killed"), gold, "gold win / loss / per kill")


# ---------- skill trees ----------

func test_tree_content_lists_every_node_and_rank_row() -> void:
	var bullets := _bullets(_section("Tree content v2 (Data/SkillTrees)"))
	var files := PackedStringArray()
	for file in DirAccess.get_files_at(TREE_DIR):
		if file.ends_with(".tres"):
			files.append(file)
	assert_eq(files.size(), 9, "nine skill trees ship")
	for file in files:
		var tree := load(TREE_DIR.path_join(file)) as MetaSkillTree
		var block := _bullet_with(bullets, "- **%s**" % tree.id)
		assert_false(block.is_empty(), "the README lists the tree %s" % tree.id)
		if block.is_empty():
			continue
		for branch in tree.branches:
			assert_true(block.contains(branch), "%s: the README names the branch '%s'" % [tree.id, branch])
		for node in tree.nodes:
			if node.hidden:
				continue
			assert_true(block.contains(node.display_name), "%s: the README names the node '%s'" % [tree.id, node.display_name])
			if node.max_rank < 2 or node.rank_values.size() < 2:
				continue
			var shown := PackedStringArray()
			for value in node.rank_values:
				if not node.description.contains("%"):
					shown.append(_fmt(value))
				elif node.stat_multiplicative:
					shown.append(_fmt(absf(value - 1.0) * 100.0))
				else:
					shown.append(_fmt(absf(value) * 100.0))
			var rank_row := "/".join(shown)
			assert_true(_entry_shows(block, node.display_name, rank_row), "%s: '%s' shows its rank row %s" % [tree.id, node.display_name, rank_row])


## True when `row` stands in the entry of `node_name`: the text from one of
## the name's occurrences in `block` up to the next ";" (the entries of a
## branch are separated by ";"). A name can also be a branch's name or stand
## in another node's "<-", so every occurrence is tried.
func _entry_shows(block: String, node_name: String, row: String) -> bool:
	var at := block.find(node_name)
	while at >= 0:
		var end := block.find(";", at)
		var entry := block.substr(at) if end < 0 else block.substr(at, end - at)
		if entry.contains(row):
			return true
		at = block.find(node_name, at + node_name.length())
	return false


# ---------- art and docs ----------

func test_ui_kit_counts_are_the_files() -> void:
	var text := "\n".join(_readme_lines())
	var kit: Array[float] = [float(_svg_count(KIT_DIR))]
	_assert_numbers(_captured(text, "`Kit/` \\((\\d+)\\)"), kit, "SVGs in Assets/UI/Kit")
	var icons: Array[float] = [float(_svg_count(ICON_DIR))]
	_assert_numbers(_captured(text, "`Icons/` \\((\\d+),"), icons, "SVGs in Assets/UI/Icons")


func test_every_file_the_docs_name_exists() -> void:
	for doc: String in [README_PATH, INSTRUCTOR_PATH]:
		var text := FileAccess.get_file_as_string(doc)
		assert_false(text.is_empty(), "%s is readable" % doc)
		var checked := {}
		var missing := PackedStringArray()
		for m in RegEx.create_from_string("`([^`\\n]+)`").search_all(text):
			var token := m.get_string(1).strip_edges().get_slice(" ", 0).trim_prefix("res://")
			token = token.rstrip(".,;:)")
			if checked.has(token) or not _is_doc_path(token):
				continue
			checked[token] = true
			if not FileAccess.file_exists("res://" + token):
				missing.append(token)
		assert_true(checked.size() >= 10, "%s names files by path (%d found)" % [doc, checked.size()])
		assert_true(missing.is_empty(), "%s names files that do not exist: %s" % [doc, ", ".join(missing)])


func _is_doc_path(token: String) -> bool:
	for c in DOC_PLACEHOLDERS:
		if token.contains(c):
			return false
	if not DOC_FILE_TYPES.has(token.get_extension()):
		return false
	for root in DOC_ROOTS:
		if token.begins_with(root):
			return true
	return false
