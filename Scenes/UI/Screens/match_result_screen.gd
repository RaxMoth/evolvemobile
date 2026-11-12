class_name MatchResultScreen
extends CanvasLayer

## The overlay at the end of a match in the Jungle Guild style (it replaces the
## old MatchResult overlay with the same contract): GameManager instantiates it
## over the paused World and calls populate(result) once the rewards are saved.
## It runs while the tree is paused (process_mode ALWAYS, layer 30).
##   - the ribbon: VICTORY on copper (a heroes win) or crimson (a monster win),
##     DEFEAT or TIME UP on grey stone, a line for the side and outcome and the
##     match time under it;
##   - the played side's cast on its stage (the campfire or the lair, the side's
##     frame) as live rigs: the standing ones celebrate a win; a hero that fell
##     (Result.fallen_hero_ids), or the monster of a lost match, lies greyed
##     and tipped back; at TIME UP the survivors just idle;
##   - three StatTiles: the duration, the played side's mob kills (Result.mob_kills:
##     "Mobs slain" for the heroes, "Mobs devoured" for the monster) and the
##     survivors (heroes) or the evolution stage reached (monster);
##   - REWARDS: a RewardChip each for Gold, the side's Steel or Leaves and the
##     XP, counting up; at an Opponent Threat above 0 the currencies carry its
##     bonus (+10% per level, never XP) and the header says so;
##   - an XpRow per character (two columns for the heroes): the bar fills from
##     the pre-match total and pops LEVEL UP! where it crosses a level; the
##     monster's head is the one of the stage it reached;
##   - "N upgrades ready" (the ranks the cast can buy now) while there are any:
##     upgrades_requested(side), and the menu opens on that side's roster
##     (GameManager.request_menu_roster);
##   - LOBBY (and ui_cancel: Escape, the Android back button) returns to
##     MenuRoot (lobby_scene_path), PLAY AGAIN picks the next
##     hunt's monster (GameManager.begin_hunt: the Heroes side never meets the
##     same quarry twice in a row) and reloads World.
## Intro: the ribbon pops at 0.1 s, the sections fade in from 0.3 s, the chips
## count from 0.6 s and the XP bars fill from 0.9 s; all settled by about 1.9 s.
## Until the buttons have faded in (about 1.1 s) the screen holds its TapGuard
## and ignores ui_cancel: a tap aimed at the HUD when the match ended (a hero
## card sits where LOBBY and PLAY AGAIN appear) never leaves the result unseen.
## Every connection inside the screen is in MatchResultScreen.tscn; the cast and
## the XP rows are built here.

signal play_again_requested
signal lobby_requested
signal upgrades_requested(side: int)

const STAGE_CHARACTER := preload("res://Scenes/UI/Components/StageCharacter.tscn")
const XP_ROW := preload("res://Scenes/UI/Components/XpRow.tscn")
const HERO_BACKDROP := preload("res://Assets/UI/Lobby/lobby_heroes.svg")
const MONSTER_BACKDROP := preload("res://Assets/UI/Lobby/lobby_monsters.svg")
const SURVIVORS_ICON := preload("res://Assets/UI/Icons/Nav/nav_heroes.svg")
const EVOLUTION_ICON := preload("res://Assets/UI/Icons/Nav/nav_monsters.svg")
## Opacity of the scrim (UiPalette.bg_void) over the paused match.
const SCRIM_ALPHA := 0.86
const HERO_SIZE := Vector2(150, 196)
const MONSTER_SIZE := Vector2(240, 262)
## The line under the ribbon, by side and outcome.
const SUBTITLES_HEROES: Array[String] = ["The beast is slain", "The jungle claims your squad", "The beast slipped away"]
const SUBTITLES_MONSTER: Array[String] = ["The jungle is yours", "The hunters prevailed", "The jungle is yours"]
const RIBBON_FROM := Vector2(0.4, 0.4)
const CELEBRATE_STAGGER := 0.12
## The intro's section fades: the first starts at SECTION_DELAY, each next one
## SECTION_STAGGER later, and each takes SECTION_FADE.
const SECTION_DELAY := 0.3
const SECTION_STAGGER := 0.08
const SECTION_FADE := 0.25

## Where LOBBY (and "upgrades ready") go: the menu's main scene.
@export_file("*.tscn") var lobby_scene_path: String = "res://Scenes/UI/Screens/MenuRoot.tscn"
## False: the buttons only emit their signals and the scene stays (tests,
## render probes).
@export var changes_scene: bool = true

## The result shown (populate()).
var result: MatchRewards.Result = null
## Ranks the cast can buy now (the "upgrades ready" pill).
var upgrades_ready: int = 0

var _cast_nodes: Array[StageCharacter] = []
var _xp_rows: Array[XpRow] = []
var _leaving := false

@onready var _scrim: ColorRect = %Scrim
@onready var _ribbon: PanelContainer = %Ribbon
@onready var _outcome: Label = %Outcome
@onready var _sub: Label = %Sub
@onready var _backdrop: TextureRect = %Backdrop
@onready var _cast: HBoxContainer = %Cast
@onready var _stage_frame: Panel = %StageFrame
@onready var _stat_time: StatTile = %StatTime
@onready var _stat_kills: StatTile = %StatKills
@onready var _stat_third: StatTile = %StatThird
@onready var _threat_bonus: Control = %ThreatBonus
@onready var _threat_text: Label = %ThreatText
@onready var _gold: RewardChip = %Gold
@onready var _steel: RewardChip = %Steel
@onready var _leaves: RewardChip = %Leaves
@onready var _xp: RewardChip = %Xp
@onready var _xp_grid: GridContainer = %XpGrid
@onready var _upgrades: Button = %Upgrades
@onready var _upgrades_text: Label = %UpgradesText
@onready var _play_again: Button = %PlayAgain
@onready var _tap_guard: TapGuard = %TapGuard


func _ready() -> void:
	_scrim.color = Color(UiPalette.get_default().bg_void, SCRIM_ALPHA)


## Shows `match_result` (the played side's view, rewards already saved) and
## plays the intro.
func populate(match_result: MatchRewards.Result) -> void:
	if not is_node_ready():
		await ready
	result = match_result
	var monster_side := result.side == MatchRewards.Side.MONSTER
	var won := result.outcome == MatchRewards.Outcome.WIN
	_ribbon.theme_type_variation = ribbon_variation(result.side, result.outcome)
	_outcome.text = tr(MatchRewards.outcome_label(result.outcome))
	_sub.text = "%s  ·  %s" % [tr(subtitle(result.side, result.outcome)), MatchRewards.format_duration(result.duration_sec)]
	_backdrop.texture = MONSTER_BACKDROP if monster_side else HERO_BACKDROP
	_stage_frame.theme_type_variation = &"FrameMonster" if monster_side else &"FrameHero"
	_play_again.theme_type_variation = &"ButtonMonster" if monster_side else &"ButtonPrimary"
	var defs := cast_defs()
	_fill_cast(defs, monster_side, won)
	_fill_stats(defs.size(), monster_side)
	_fill_rewards(monster_side)
	_fill_xp(defs, monster_side)
	_intro()


## The ribbon's theme variation: copper for a heroes win, crimson for a
## monster win, grey stone for a loss or TIME UP.
static func ribbon_variation(side: int, outcome: int) -> StringName:
	if outcome != MatchRewards.Outcome.WIN:
		return &"BannerDefeat"
	return &"BannerVictoryMonster" if side == MatchRewards.Side.MONSTER else &"BannerVictory"


## The line under the ribbon (an untranslated key).
static func subtitle(side: int, outcome: int) -> String:
	var lines := SUBTITLES_MONSTER if side == MatchRewards.Side.MONSTER else SUBTITLES_HEROES
	return lines[clampi(outcome, 0, lines.size() - 1)]


## The played side's characters: the monster of the match, or the heroes the
## match counted (the roster's heroes for a result without them).
func cast_defs() -> Array[CharacterDef]:
	var out: Array[CharacterDef] = []
	if result == null:
		return out
	if result.side == MatchRewards.Side.MONSTER:
		var id := result.monster_id if result.monster_id != &"" else GameManager.selected_monster_id
		var def := GameManager.ROSTER.resolve_monster(id)
		if def != null:
			out.append(def)
		return out
	var ids: Array[StringName] = result.hero_ids
	if ids.is_empty():
		ids = GameManager.ROSTER.hero_ids()
	for id in ids:
		var def := GameManager.ROSTER.find(id)
		if def != null and not def.is_monster():
			out.append(def)
	return out


## The cast on the stage, in order.
func cast() -> Array[StageCharacter]:
	return _cast_nodes


func xp_rows() -> Array[XpRow]:
	return _xp_rows


## True when `def` lies fallen: a hero the match lost, or the monster (or every
## hero) of a lost match.
func is_fallen(def: CharacterDef) -> bool:
	if result == null or def == null:
		return false
	if result.outcome == MatchRewards.Outcome.LOSS:
		return true
	return not def.is_monster() and result.fallen_hero_ids.has(def.character_id())


func _fill_cast(defs: Array[CharacterDef], monster_side: bool, won: bool) -> void:
	for node in _cast_nodes:
		_cast.remove_child(node)
		node.queue_free()
	_cast_nodes.clear()
	var standing := 0
	for i in defs.size():
		var def := defs[i]
		var actor := STAGE_CHARACTER.instantiate() as StageCharacter
		actor.name = String(def.character_id()).capitalize()
		actor.character = def
		actor.flip = not monster_side and i >= defs.size() / 2.0
		actor.custom_minimum_size = MONSTER_SIZE if monster_side else HERO_SIZE
		# A picture here, not a button.
		actor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		actor.focus_mode = Control.FOCUS_NONE
		if monster_side:
			actor.stage = result.monster_stage
		_cast.add_child(actor)
		_cast_nodes.append(actor)
		if is_fallen(def):
			actor.set_fallen(true)
		elif won:
			actor.celebrate(CELEBRATE_STAGGER * standing)
			standing += 1


func _fill_stats(cast_size: int, monster_side: bool) -> void:
	_stat_time.value = MatchRewards.format_duration(result.duration_sec)
	_stat_kills.value = str(result.mob_kills)
	_stat_kills.caption = tr("Mobs devoured") if monster_side else tr("Mobs slain")
	if monster_side:
		_stat_third.show_stat(EVOLUTION_ICON, tr("Stage %d") % result.monster_stage, tr("Evolution"))
	else:
		_stat_third.show_stat(SURVIVORS_ICON, "%d / %d" % [result.heroes_alive, cast_size], tr("Survivors"))


func _fill_rewards(monster_side: bool) -> void:
	var bonus := result.threat * MatchRewards.THREAT_BONUS_TENTHS * 10
	_gold.amount = result.gold
	_gold.bonus_pct = bonus
	_steel.amount = result.steel
	_steel.bonus_pct = bonus
	_steel.visible = not monster_side
	_leaves.amount = result.leaves
	_leaves.bonus_pct = bonus
	_leaves.visible = monster_side
	_xp.amount = result.xp
	_xp.caption = tr("XP") if monster_side else tr("XP each")
	_threat_bonus.visible = result.threat > 0
	var line := "Threat %d: +%d%% Leaves and Gold" if monster_side else "Threat %d: +%d%% Steel and Gold"
	_threat_text.text = tr(line) % [result.threat, bonus]


func _fill_xp(defs: Array[CharacterDef], monster_side: bool) -> void:
	for row in _xp_rows:
		_xp_grid.remove_child(row)
		row.queue_free()
	_xp_rows.clear()
	_xp_grid.columns = 1 if monster_side else 2
	upgrades_ready = 0
	for def in defs:
		var row := XP_ROW.instantiate() as XpRow
		row.character = def
		if def.is_monster():
			row.stage = result.monster_stage
		row.gain = result.xp
		# The rewards are saved before populate: the save holds the new total.
		row.total_before = maxi(0, CharacterProgress.xp(def) - result.xp)
		row.fallen = is_fallen(def)
		_xp_grid.add_child(row)
		_xp_rows.append(row)
		upgrades_ready += CharacterProgress.upgrades_ready(def)
	_upgrades.visible = upgrades_ready > 0
	if upgrades_ready == 1:
		_upgrades_text.text = tr("1 upgrade ready")
	else:
		_upgrades_text.text = tr("%d upgrades ready") % upgrades_ready


func _intro() -> void:
	_ribbon.pivot_offset = _ribbon.get_combined_minimum_size() * 0.5
	_ribbon.scale = RIBBON_FROM
	_ribbon.modulate.a = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(_scrim, ^"modulate:a", 1.0, 0.25).from(0.0)
	t.tween_property(_ribbon, ^"modulate:a", 1.0, 0.15).set_delay(0.1)
	t.tween_property(_ribbon, ^"scale", Vector2.ONE, 0.4).set_delay(0.1) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var k := 0
	for section: CanvasItem in [_sub, %Stage, %Stats, %RewardsHead, %Rewards, _xp_grid, _upgrades, %Buttons]:
		section.modulate.a = 0.0
		t.tween_property(section, ^"modulate:a", 1.0, SECTION_FADE).set_delay(SECTION_DELAY + SECTION_STAGGER * k)
		k += 1
	# The buttons are the last section: no tap counts before they are shown.
	_tap_guard.hold(SECTION_DELAY + SECTION_STAGGER * (k - 1) + SECTION_FADE)
	var c := 0
	for chip: RewardChip in [_gold, _steel, _leaves, _xp]:
		if chip.visible:
			chip.play(0.6 + 0.12 * c)
			c += 1
	for r in _xp_rows.size():
		_xp_rows[r].play(0.9 + 0.1 * r)


## Back to the menu (unpaused); `roster_side` >= 0 asks it to open that side's
## roster.
func _leave_to_menu(roster_side: int = -1) -> void:
	if _leaving:
		return
	_leaving = true
	if roster_side >= 0:
		GameManager.request_menu_roster(roster_side)
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(lobby_scene_path)


## Back (Escape, the Android back button through MatchHud): LOBBY, once the
## intro has shown the buttons (before that the press is taken and dropped).
func _unhandled_input(event: InputEvent) -> void:
	if result != null and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		if not _tap_guard.is_holding():
			_on_lobby_pressed()


# --- scene-side connections (MatchResultScreen.tscn) ---

func _on_play_again_pressed() -> void:
	play_again_requested.emit()
	if not changes_scene or _leaving:
		return
	_leaving = true
	get_tree().paused = false
	# The next hunt picks its monster like HUNT does (the Heroes side never
	# meets the same quarry twice in a row).
	GameManager.begin_hunt()
	# Deferred: never free our own UI from inside its own input callback.
	get_tree().reload_current_scene.call_deferred()


func _on_lobby_pressed() -> void:
	lobby_requested.emit()
	if changes_scene:
		_leave_to_menu()


func _on_upgrades_pressed() -> void:
	var side := MatchRewards.Side.MONSTER if result != null and result.side == MatchRewards.Side.MONSTER else MatchRewards.Side.HEROES
	upgrades_requested.emit(side)
	if changes_scene:
		_leave_to_menu(side)
