class_name ThreatBox
extends PanelContainer

## The Opponent Threat of the next match in words (the pre-round screen,
## README "Opponent Threat"): a PanelInset with the threat icon,
##   - "Threat T" and the reward bonus it pays ("+20% rewards",
##     MatchRewards.THREAT_BONUS_TENTHS per level);
##   - the AI opponent's build at that threat (MetaSkillManager.side_ai_build):
##     "AI build: 6 Nyxa ranks + 4 base ranks" against the heroes, "AI heroes:
##     6 ranks each + 4 base ranks" against the monster, "no upgrades yet" at
##     threat 0;
##   - a hint: the quarry's counterplay tip (CharacterDef.tip) for the heroes,
##     what the threat follows for the monster.
## Read-only: show_for() reads the save through MetaSkillManager.

## The threat shown (read by tests and the screen).
var threat: int = 0
## Ranks of the AI build shown: its base tree and its character trees.
var base_ranks: int = 0
var character_ranks: Array[int] = []

@onready var _title: Label = %Title
@onready var _bonus: Label = %Bonus
@onready var _build: Label = %Build
@onready var _hint: Label = %Hint


## The threat when the player plays `played_side` (MatchRewards.Side) with
## `monster` (the quarry on the Heroes side, the own monster on the Monster
## side) and the AI side's build at it.
func show_for(played_side: int, monster: CharacterDef) -> void:
	var monster_id := monster.character_id() if monster != null else GameManager.ROSTER.default_monster_id
	var heroes_played := played_side != MatchRewards.Side.MONSTER
	threat = MetaSkillManager.threat_for(played_side, monster_id)
	var ai_side := MatchRewards.Side.MONSTER if heroes_played else MatchRewards.Side.HEROES
	var build := MetaSkillManager.side_ai_build(ai_side, monster_id, threat)
	base_ranks = 0
	character_ranks.clear()
	for tree_id: StringName in build:
		var ranks := 0
		for r: int in build[tree_id].values():
			ranks += r
		if MetaSkillManager.is_base_tree(tree_id):
			base_ranks += ranks
		else:
			character_ranks.append(ranks)
	_title.text = tr("Threat %d") % threat
	_bonus.text = tr("+%d%% rewards") % (threat * MatchRewards.THREAT_BONUS_TENTHS * 10)
	_bonus.visible = threat > 0
	_build.text = _build_text(heroes_played, monster)
	_hint.text = _hint_text(heroes_played, monster)
	_hint.visible = not _hint.text.is_empty()


func _build_text(heroes_played: bool, monster: CharacterDef) -> String:
	if threat == 0:
		return tr("AI build: no upgrades yet")
	if heroes_played:
		var ranks: int = character_ranks[0] if not character_ranks.is_empty() else 0
		var monster_name := monster.get_display_name() if monster != null else ""
		return tr("AI build: %d %s ranks + %d base ranks") % [ranks, monster_name, base_ranks]
	var same := true
	var counts: PackedStringArray = []
	for r in character_ranks:
		counts.append(str(r))
		same = same and r == character_ranks[0]
	if same and not character_ranks.is_empty():
		return tr("AI heroes: %d ranks each + %d base ranks") % [character_ranks[0], base_ranks]
	return tr("AI heroes: %s ranks + %d base ranks") % ["/".join(counts), base_ranks]


func _hint_text(heroes_played: bool, monster: CharacterDef) -> String:
	if heroes_played:
		return monster.tip if monster != null else ""
	return tr("The AI heroes grow as your monster gains ranks.")
