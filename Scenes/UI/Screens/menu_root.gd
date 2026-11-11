class_name MenuRoot
extends Control

## The main scene (project run/main_scene). Every meta screen is a hidden child
## of %Screens and every screen signal is connected in MenuRoot.tscn; this
## script only moves between the screens and holds the hooks a scene
## connection cannot reach (autoloads cannot be [connection] targets):
##   - push(screen) / pop(): the new screen slides in from the right edge over
##     SLIDE_TIME (cubic ease-out) while the one below darkens to
##     UiPalette.COVERED_SCREEN_MODULATE; pop() plays it backwards. Once a slide
##     settles only the top screen is visible. ui_cancel is back (pop).
##   - switch_to(screen): a nav-bar destination (the rosters, Growth). It slides
##     in like a push but then sits right above the home screen (back returns
##     to the lobby), or, when it is already on the stack, the screens above it
##     slide away instead.
##   - every push and pop holds the menu's TapGuard for the slide and a short
##     grace time: the second tap of a double tap (on HUNT, on a back arrow)
##     never lands on the screen that slides in under the finger.
##   - autoloads: the tree unpaused on entry (a match result pauses it), the
##     roster the match result's "upgrades ready" asked for
##     (GameManager.take_menu_roster) opened on entry, the menu music, the UI
##     click on every button press, the first-run tutorial,
##     GameManager's chosen side (persisted), the background World load, the
##     match's monster (GameManager.begin_hunt: the Heroes side's quarry or the
##     player's own monster) right before World loads, the skill purchases
##     (MetaSkillManager.rank_up) and capstone swaps (equip_capstone), the
##     character purchases (CharacterProgress.unlock, confirmed on the
##     UnlockSheet; the bought monster becomes the player's own), the refresh
##     of the open screens when skills, currencies or owned monsters change
##     or the language is switched (the lines a screen formatted itself, such
##     as the lobby's unlock rules; scene labels re-translate on their own),
##     and the nav bars' red dots: Heroes / Monsters while a character of that
##     side has a rank to buy (Monsters also while a locked monster can be
##     bought), Growth while either side's account tree has one.
## The rosters (Heroes / Monsters and the lobby's plaques) open a character's
## detail, or the unlock sheet for a locked character with a price; Growth
## opens the chosen side's account-wide tree in the detail screen (its
## HEROES / MONSTER tabs switch to the other one). HUNT pushes the
## PreRoundScreen: the lobby's buttons for the chosen side, a nav bar's arch
## for the side of the screen it is on (a roster's, a character's, Growth's
## shown tree; the chosen side on the lobby and the Codex), which becomes the
## chosen side. Its START HUNT starts the match against the quarry it shows
## (MatchConfig.quarry_id), its UNLEASH with the monster it picked
## (GameManager.choose_monster); a locked monster it shows that can be bought
## now opens the unlock sheet. The nav bar's Codex opens the CodexScreen (its
## dot lights while it has unseen monster pages); its guide replays the camp
## tour (home first, then the coach marks) or switches the hunt tips on again.
## The lobby's gear opens the SettingsScreen sheet.
## Back: ui_cancel, and the Android back button (NOTIFICATION_WM_GO_BACK_REQUEST,
## replayed as ui_cancel by BackButton) closes the open overlay or sheet, else
## pops a screen; on the bare lobby the back button leaves the game.

const SLIDE_TIME := 0.22
## Seconds after entry before the first-run tutorial opens.
const TUTORIAL_DELAY := 0.9
const TUTORIAL_SCENE: PackedScene = preload("res://Scenes/UI/Tutorial/TutorialOverlay.tscn")
const SETTINGS_SCENE: PackedScene = preload("res://Scenes/UI/Settings/SettingsScreen.tscn")

## The home screen, the bottom of the stack.
@export var lobby: LobbyScreen
## The collections of each side (nav bar Heroes / Monsters).
@export var hero_roster: RosterScreen
@export var monster_roster: RosterScreen
## One character's overview and skill tree.
@export var detail: CharacterDetail
## The chosen side's account-wide tree (nav bar Growth).
@export var growth: CharacterDetail
## The purchase confirm sheet of a locked character (over every screen).
@export var unlock_sheet: UnlockSheet
## The step between HUNT and the match (both sides).
@export var pre_round: PreRoundScreen
## The nav bar's Codex (guide, monster and hero pages).
@export var codex: CodexScreen

## The screens on the way back, the home screen first and the shown one last.
var _stack: Array[Control] = []
var _slide: Tween = null
## The overlay that is open (the tutorial or the settings; one at a time),
## or null.
var _overlay: Node = null
## A refresh of the open screens is queued for the end of the frame (a
## purchase changes currencies and skills in one go).
var _refresh_queued := false
## A match is on its way (the scene changes at the end of the frame): a second
## tap on START HUNT / UNLEASH starts nothing.
var _starting := false

@onready var _screens: Control = %Screens
@onready var _tap_guard: TapGuard = %TapGuard


func _ready() -> void:
	get_tree().paused = false
	# Load the match while the player looks at the menu (first visit only:
	# GameManager keeps the loaded scene for the session).
	GameManager.request_world_load()
	_stack = [lobby]
	_settle()
	lobby.show_side(GameManager.chosen_side)
	# The match result's "upgrades ready": straight on to that side's roster.
	var roster_side := GameManager.take_menu_roster()
	if roster_side >= 0:
		_on_roster_requested(roster_side)
	_update_nav_notify()
	AudioManager.play_music(&"menu")
	_wire_clicks(self)
	get_tree().node_added.connect(_on_node_added)
	MetaSkillManager.skills_changed.connect(_queue_refresh)
	PersistedData.currency_changed.connect(_on_currency_changed)
	PersistedData.monster_owned.connect(_on_monster_owned)
	if not TutorialOverlay.has_been_seen():
		get_tree().create_timer(TUTORIAL_DELAY).timeout.connect(_auto_open_tutorial)


## The Android back button: ui_cancel for whatever is open; on the bare lobby
## (nobody took it) it leaves the game. A language switch (the settings sheet)
## refreshes the open screens: what they formatted is in the old language.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not go_back():
		get_tree().quit()
	elif what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_queue_refresh()


## One back press (BackButton): false when nothing was open to go back from.
func go_back() -> bool:
	return BackButton.press(get_viewport())


func _unhandled_input(event: InputEvent) -> void:
	# An open overlay or the unlock sheet owns back (they close themselves on
	# ui_cancel before it reaches us).
	if event.is_action_pressed(&"ui_cancel") and _stack.size() > 1 and not _overlay_open() and not unlock_sheet.is_open():
		get_viewport().set_input_as_handled()
		pop()


## The screen on top of the stack (the one shown).
func top() -> Control:
	return _stack[-1]


## Slides `screen` (a hidden child of %Screens) in over the shown one.
## `replace`: the screens between home and it leave the stack (switch_to).
func push(screen: Control, replace: bool = false) -> void:
	if screen == null or _stack.has(screen):
		return
	_finish_slide()
	var below := top()
	_stack.append(screen)
	if replace:
		_stack = [_stack[0], screen]
	screen.visible = true
	screen.modulate = Color.WHITE
	screen.position.x = size.x
	_tap_guard.hold(SLIDE_TIME)
	_slide = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide.tween_property(screen, ^"position:x", 0.0, SLIDE_TIME)
	_slide.tween_property(below, ^"modulate", UiPalette.COVERED_SCREEN_MODULATE, SLIDE_TIME)
	_slide.chain().tween_callback(_settle)


## Back: slides the shown screen out to the right, uncovering the one below.
## The home screen never leaves.
func pop() -> void:
	if _stack.size() >= 2:
		pop_to(_stack[-2])


## Back to `screen` (on the stack below the shown one): the shown screen
## slides out and every screen above `screen` leaves the stack.
func pop_to(screen: Control) -> void:
	_finish_slide()
	var at := _stack.find(screen)
	if at < 0 or at == _stack.size() - 1:
		return
	var leaving := top()
	_stack.resize(at + 1)
	screen.visible = true
	_tap_guard.hold(SLIDE_TIME)
	_slide = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide.tween_property(leaving, ^"position:x", size.x, SLIDE_TIME)
	_slide.tween_property(screen, ^"modulate", Color.WHITE, SLIDE_TIME)
	_slide.chain().tween_callback(_settle)


## A nav-bar destination: back to it when it is on the stack, else it slides
## in and becomes the only screen above home (nav tabs do not stack up).
func switch_to(screen: Control) -> void:
	if screen == null or screen == top():
		return
	if _stack.has(screen):
		pop_to(screen)
	else:
		push(screen, true)


## The resting state: the top screen shown in place, every other one hidden.
func _settle() -> void:
	var shown := top()
	for child in _screens.get_children():
		var screen := child as Control
		if screen == null:
			continue
		screen.visible = screen == shown
		screen.position.x = 0.0
		screen.modulate = Color.WHITE


## A new push or pop lands the slide in flight first.
func _finish_slide() -> void:
	if _slide != null and _slide.is_valid():
		_slide.kill()
		_settle()
	_slide = null


# --- autoload hooks ---

func _wire_clicks(node: Node) -> void:
	_wire_click(node)
	for child in node.get_children():
		_wire_clicks(child)


## Buttons a screen or overlay builds later click too.
func _on_node_added(node: Node) -> void:
	if is_ancestor_of(node):
		_wire_click(node)


func _wire_click(node: Node) -> void:
	var button := node as BaseButton
	if button != null and not button.pressed.is_connected(AudioManager.play_ui_click):
		button.pressed.connect(AudioManager.play_ui_click)


func _overlay_open() -> bool:
	return is_instance_valid(_overlay) and not _overlay.is_queued_for_deletion()


## Opens an overlay (the tutorial, the settings) on top of the menu; it frees
## itself when closed.
func _open_overlay(overlay: Node) -> void:
	_overlay = overlay
	add_child(overlay)


func _auto_open_tutorial() -> void:
	# Re-check: the player may have opened and finished it within the delay.
	if not TutorialOverlay.has_been_seen():
		_open_tutorial()


func _open_tutorial() -> void:
	if not _overlay_open():
		_open_overlay(TUTORIAL_SCENE.instantiate())


## The Codex (nav bar): its pages re-read what has been met.
func _open_codex() -> void:
	if codex == top():
		return
	codex.open()
	switch_to(codex)
	_update_nav_notify()


## The screens on the stack re-read the save (once per frame at most).
func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_refresh_screens.call_deferred()


func _refresh_screens() -> void:
	_refresh_queued = false
	# Queued in the frame the menu left the tree (a match starts, a language
	# switch at the very end): nothing is shown any more.
	if not is_inside_tree():
		return
	for screen in _stack:
		if screen is LobbyScreen:
			(screen as LobbyScreen).refresh()
		elif screen is RosterScreen:
			(screen as RosterScreen).refresh()
		elif screen is CharacterDetail:
			(screen as CharacterDetail).refresh()
		elif screen is PreRoundScreen:
			(screen as PreRoundScreen).refresh()
	if unlock_sheet.is_open():
		unlock_sheet.refresh()
	_update_nav_notify()


## The red dots of every nav bar under the menu (NavBar.GROUP): Heroes and
## Monsters while a character of that side has a rank to buy now
## (CharacterProgress.upgrades_ready) or can itself be bought
## (CharacterProgress.can_unlock), Growth while the heroes' or the monsters'
## account tree has one (CharacterDetail.base_tree_ready; its HEROES / MONSTER
## tabs carry a dot each), Codex while it has monster pages the player has not
## opened yet (CodexScreen.unseen_monsters).
func _update_nav_notify() -> void:
	var heroes := false
	var monsters := false
	for def in GameManager.ROSTER.all():
		if CharacterProgress.upgrades_ready(def) > 0 or CharacterProgress.can_unlock(def):
			if def.is_monster():
				monsters = true
			else:
				heroes = true
	var base_ready := CharacterDetail.base_tree_ready(MatchRewards.Side.HEROES) \
			or CharacterDetail.base_tree_ready(MatchRewards.Side.MONSTER)
	var codex_new := CodexScreen.unseen_monsters() > 0
	for node in get_tree().get_nodes_in_group(NavBar.GROUP):
		var bar := node as NavBar
		if bar == null or not is_ancestor_of(bar):
			continue
		bar.set_notify(&"heroes", heroes)
		bar.set_notify(&"monsters", monsters)
		bar.set_notify(&"growth", base_ready)
		bar.set_notify(&"codex", codex_new)


func _on_currency_changed(_currency: StringName, _amount: int) -> void:
	_queue_refresh()


func _on_monster_owned(_monster_id: StringName) -> void:
	_queue_refresh()


func _roster(side: int) -> RosterScreen:
	return monster_roster if side == MatchRewards.Side.MONSTER else hero_roster


## Picks the match's monster for the chosen side (the Heroes side hunts
## `quarry_id`, the pre-round's quarry) and loads the match.
func _start_match(quarry_id: StringName = &"") -> void:
	if _starting:
		return
	_starting = true
	GameManager.begin_hunt(quarry_id)
	get_tree().change_scene_to_packed.call_deferred(GameManager.get_world_scene())


# --- screen signals (connected in MenuRoot.tscn) ---

func _on_side_chosen(side: int) -> void:
	GameManager.choose_side(side)


## HUNT: `side`'s pre-round first (README round structure step 1), over the
## screen that asked. A side other than the chosen one (the arch on the other
## side's roster or character) becomes the chosen side, on the lobby too. The
## pre-round persists its choices and only asks us to start.
func _on_hunt_requested(side: int) -> void:
	if _overlay_open() or unlock_sheet.is_open() or _stack.has(pre_round):
		return
	if side != GameManager.chosen_side:
		GameManager.choose_side(side)
		lobby.show_side(GameManager.chosen_side)
	pre_round.open(GameManager.chosen_side)
	push(pre_round)


## The side a screen stands for (its nav arch glows in that colour and starts
## that side's hunt): a roster's, a character's or Growth's shown tree; the
## chosen side for the lobby and the Codex.
func _screen_side(screen: Control) -> int:
	if screen is RosterScreen:
		return (screen as RosterScreen).side
	if screen is CharacterDetail:
		return (screen as CharacterDetail).shown_side()
	return GameManager.chosen_side


## START HUNT: the heroes hunt the quarry the pre-round showed.
func _on_pre_round_start_requested(config: MatchConfig) -> void:
	_start_match(config.quarry_id)


## UNLEASH: the monster the pre-round picked plays (it is already the player's
## own; choose_monster keeps that true whatever the screen did). The instinct
## is today's behaviour until its presets are balanced.
func _on_monster_start_requested(monster_id: StringName, _instinct: StringName) -> void:
	GameManager.choose_monster(monster_id)
	_start_match()


## A side's collection (the lobby's plaques, the nav bar's Heroes / Monsters).
func _on_roster_requested(side: int) -> void:
	var roster := _roster(side)
	if roster != top():
		roster.open()
	switch_to(roster)


## An owned character's overview, over the screen that asked (a roster card or
## the lobby, which has already chosen the character's side). A locked
## character with a price (Nyxa, Gorrak) opens the unlock sheet instead: its
## rule, its price and the purchase.
func _on_character_requested(character: CharacterDef) -> void:
	if character == null or unlock_sheet.is_open():
		return
	if not CharacterProgress.is_unlocked(character):
		if CharacterProgress.unlock_state(character) != CharacterProgress.UnlockState.NOT_FOR_SALE:
			unlock_sheet.open_for(character)
		return
	if _stack.has(detail):
		return
	detail.show_character(character)
	push(detail)


## UNLOCK on the sheet: buy the character (the rule and the wallet decide) and
## make it the player's own monster; the screens refresh on the signals the
## purchase fires. A purchase that does not go through leaves the sheet open
## on the new numbers.
func _on_unlock_confirmed(character: CharacterDef) -> void:
	if CharacterProgress.unlock(character):
		GameManager.choose_monster(character.character_id())
		unlock_sheet.close()
	else:
		unlock_sheet.refresh()


## The account-wide trees (nav bar Growth): it opens on the chosen side's
## tree; its HEROES / MONSTER tabs switch.
func _open_growth() -> void:
	if growth == top():
		return
	growth.show_base_tree(GameManager.chosen_side)
	switch_to(growth)


func _on_back_requested() -> void:
	pop()


## A skill node's UPGRADE buys its next rank: the shop decides (gates, price);
## the screens refresh on the signals it fires.
func _on_upgrade_requested(tree_id: StringName, node_id: StringName) -> void:
	MetaSkillManager.rank_up(tree_id, node_id)


## A capstone's EQUIP makes it the tree's active one (free; the next spawn
## applies it); the screens refresh on skills_changed.
func _on_equip_requested(tree_id: StringName, node_id: StringName) -> void:
	MetaSkillManager.equip_capstone(tree_id, node_id)


func _on_tab_selected(tab_id: StringName) -> void:
	match tab_id:
		&"hunt":
			_on_hunt_requested(_screen_side(top()))
		&"heroes":
			_on_roster_requested(MatchRewards.Side.HEROES)
		&"monsters":
			_on_roster_requested(MatchRewards.Side.MONSTER)
		&"growth":
			_open_growth()
		&"codex":
			_open_codex()


func _on_settings_requested() -> void:
	if not _overlay_open():
		_open_overlay(SETTINGS_SCENE.instantiate())


## The Codex guide's replays: the camp tour plays over the lobby (home first,
## the coach marks once the slide has settled); the hunt tips play again in
## the next match.
func _on_guide_requested(chapter: StringName) -> void:
	if chapter == TutorialOverlay.CHAPTER_HUD:
		TutorialOverlay.forget(TutorialOverlay.CHAPTER_HUD)
		return
	if _overlay_open():
		return
	pop_to(lobby)
	get_tree().create_timer(SLIDE_TIME).timeout.connect(_open_tutorial)
