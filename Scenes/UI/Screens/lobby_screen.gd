class_name LobbyScreen
extends Control

## The main screen (MenuRoot's home; the nav bar's HUNT arch): a split jungle
## stage. The heroes stand at their campfire on top, the monsters in their
## fanged lair below, each one a live rig (StageCharacter). Tapping a stage
## chooses that side in place:
##   - the other stage dims to UiPalette.UNCHOSEN_SIDE_MODULATE (DIM_TIME);
##   - the chosen stage shows its frame (FrameHero amber / FrameMonster crimson);
##   - its HUNT button pops in (CTA_POP_FROM -> 1, TRANS_BACK);
##   - its characters cheer one after another (CHEER_STAGGER);
##   - the nav bar's arch glows in the side's colour.
## The lair's backdrop and its monsters are anchored to the bottom of their
## stage at the design size: on a taller screen (19.5:9) the extra height shows
## more of the cave above the lair (BackdropTop, lobby_monsters_top.svg: the
## wall and the thorn vines running on upward, joined to the backdrop's top
## edge) instead of blowing the backdrop up around monsters that keep their
## size.
## The HEROES / MONSTERS plaques open the rosters and HUNT starts the chosen
## side's match. A tap anywhere on the stage that is not chosen, its
## characters included, only chooses that side; a tap on a character of the
## chosen side asks for its detail. With side_tap_opens_roster a stage tap
## opens that side's roster.
##
## The screen only reports (side_chosen, hunt_requested, ...): MenuRoot
## connects every signal scene-side and acts on it, and every connection inside
## the screen is in LobbyScreen.tscn. Monsters the player has not bought yet
## (Nyxa, Gorrak) stand in the lair as padlocked silhouettes with their price
## and unlock rule; tapping one on the chosen lair asks for it like any
## character (MenuRoot opens the unlock confirm sheet). refresh() re-reads
## that after a purchase.

signal side_chosen(side: int)
signal hunt_requested(side: int)
signal roster_requested(side: int)
signal character_requested(character: CharacterDef)
signal tab_selected(tab_id: StringName)
signal settings_requested

## The nav bar tab this screen is (MenuRoot's home).
const HOME_TAB: StringName = &"hunt"
const DIM_TIME := 0.25
const CTA_POP_TIME := 0.35
const CTA_POP_FROM := Vector2(0.6, 0.6)
const CHEER_STAGGER := 0.05

## The side shown as chosen (MatchRewards.Side values). show_side() sets it at
## once, choose() with the animation and a report.
@export_enum("Heroes", "Monster") var chosen_side: int = MatchRewards.Side.HEROES
## Alternative flow: tapping a stage opens that side's roster instead of only
## choosing the side.
@export var side_tap_opens_roster: bool = false

var _tween: Tween = null

@onready var _hero_stage: Control = %HeroStage
@onready var _monster_stage: Control = %MonsterStage
@onready var _hero_frame: CanvasItem = %HeroFrame
@onready var _monster_frame: CanvasItem = %MonsterFrame
@onready var _hero_hunt: Control = %HeroHunt
@onready var _monster_hunt: Control = %MonsterHunt
@onready var _nav: NavBar = %NavBar


func _ready() -> void:
	_apply_side(false)


## Shows `side` as chosen at once, without the animation or a report (the
## side restored from the save).
func show_side(side: int) -> void:
	chosen_side = _side_of(side)
	_apply_side(false)


## Chooses `side` as a stage tap does: the animated switch, then side_chosen.
## The side already chosen changes nothing.
func choose(side: int) -> void:
	var picked := _side_of(side)
	if picked == chosen_side:
		return
	chosen_side = picked
	_apply_side(true)
	side_chosen.emit(chosen_side)


## Every character on both stages re-reads whether it is owned (a purchase).
func refresh() -> void:
	for stage: Control in [_hero_stage, _monster_stage]:
		for character in stage_characters(stage):
			character.refresh()


## The characters standing on a stage, in scene order (the cheer order).
func stage_characters(stage: Control) -> Array[StageCharacter]:
	var out: Array[StageCharacter] = []
	for c in stage.get_children():
		if c is StageCharacter:
			out.append(c as StageCharacter)
	return out


func _side_of(side: int) -> int:
	return MatchRewards.Side.MONSTER if side == MatchRewards.Side.MONSTER else MatchRewards.Side.HEROES


func _apply_side(animate: bool) -> void:
	var heroes := chosen_side == MatchRewards.Side.HEROES
	var on_stage := _hero_stage if heroes else _monster_stage
	var off_stage := _monster_stage if heroes else _hero_stage
	var cta := _hero_hunt if heroes else _monster_hunt
	if _tween != null:
		_tween.kill()
		_tween = null
	_nav.monster_side = not heroes
	_hero_frame.visible = heroes
	_monster_frame.visible = not heroes
	_hero_hunt.visible = heroes
	_monster_hunt.visible = not heroes
	_hero_hunt.scale = Vector2.ONE
	_monster_hunt.scale = Vector2.ONE
	if not animate:
		on_stage.modulate = Color.WHITE
		off_stage.modulate = UiPalette.UNCHOSEN_SIDE_MODULATE
		return
	_tween = create_tween().set_parallel()
	_tween.tween_property(on_stage, ^"modulate", Color.WHITE, DIM_TIME)
	_tween.tween_property(off_stage, ^"modulate", UiPalette.UNCHOSEN_SIDE_MODULATE, DIM_TIME)
	cta.pivot_offset = cta.size * 0.5
	cta.scale = CTA_POP_FROM
	_tween.tween_property(cta, ^"scale", Vector2.ONE, CTA_POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var i := 0
	for character in stage_characters(on_stage):
		character.cheer(CHEER_STAGGER * i)
		i += 1


func _on_stage_tapped(side: int) -> void:
	choose(side)
	if side_tap_opens_roster:
		roster_requested.emit(chosen_side)


# --- scene-side connections (LobbyScreen.tscn) ---

func _on_hero_stage_pressed() -> void:
	_on_stage_tapped(MatchRewards.Side.HEROES)


func _on_monster_stage_pressed() -> void:
	_on_stage_tapped(MatchRewards.Side.MONSTER)


func _on_hero_roster_pressed() -> void:
	roster_requested.emit(MatchRewards.Side.HEROES)


func _on_monster_roster_pressed() -> void:
	roster_requested.emit(MatchRewards.Side.MONSTER)


func _on_hunt_pressed() -> void:
	hunt_requested.emit(chosen_side)


## A character stands on its side's stage: on the stage that is not chosen
## the tap is a stage tap (it only chooses the side); on the chosen one it
## asks for the character.
func _on_character_pressed(character: CharacterDef) -> void:
	if character == null:
		return
	if _side_of(character.side) != chosen_side:
		_on_stage_tapped(character.side)
		return
	character_requested.emit(character)


func _on_top_bar_left_pressed() -> void:
	settings_requested.emit()


## Every tab leads away from the lobby (or starts the hunt), so the lobby's own
## bar keeps HUNT lit.
func _on_nav_bar_tab_selected(tab_id: StringName) -> void:
	tab_selected.emit(tab_id)
	_nav.active_tab = HOME_TAB
