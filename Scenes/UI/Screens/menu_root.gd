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
##   - autoloads: the tree unpaused on entry (a match result pauses it), the
##     menu music, the UI click on every button press, the first-run tutorial,
##     GameManager's chosen side (persisted), the background World load, the
##     skill purchases (MetaSkillManager.rank_up) and the refresh of the open
##     screens when skills or currencies change.
## The rosters (Heroes / Monsters and the lobby's plaques) open a character's
## detail; Growth opens the chosen side's account-wide tree in the detail
## screen. Until their new screens land, HUNT opens the old PreRoundSetup
## overlay (heroes; the monster side starts at once), Codex the tutorial and
## the gear SettingsScreen.

const SLIDE_TIME := 0.22
## Seconds after entry before the first-run tutorial opens.
const TUTORIAL_DELAY := 0.9
const PRE_ROUND_SCENE: PackedScene = preload("res://Scenes/UI/PreRoundSetup/PreRoundSetup.tscn")
const TUTORIAL_SCENE: PackedScene = preload("res://Scenes/UI/Tutorial/TutorialOverlay.tscn")

## The home screen, the bottom of the stack.
@export var lobby: LobbyScreen
## The collections of each side (nav bar Heroes / Monsters).
@export var hero_roster: RosterScreen
@export var monster_roster: RosterScreen
## One character's overview and skill tree.
@export var detail: CharacterDetail
## The chosen side's account-wide tree (nav bar Growth).
@export var growth: CharacterDetail

## The screens on the way back, the home screen first and the shown one last.
var _stack: Array[Control] = []
var _slide: Tween = null
## The old overlay that is open (one at a time), or null.
var _overlay: Node = null
## A refresh of the open screens is queued for the end of the frame (a
## purchase changes currencies and skills in one go).
var _refresh_queued := false

@onready var _screens: Control = %Screens


func _ready() -> void:
	get_tree().paused = false
	# Load the match while the player looks at the menu (first visit only:
	# GameManager keeps the loaded scene for the session).
	GameManager.request_world_load()
	_stack = [lobby]
	_settle()
	lobby.show_side(GameManager.chosen_side)
	AudioManager.play_music(&"menu")
	_wire_clicks(self)
	get_tree().node_added.connect(_on_node_added)
	MetaSkillManager.skills_changed.connect(_queue_refresh)
	PersistedData.currency_changed.connect(_on_currency_changed)
	if not TutorialOverlay.has_been_seen():
		get_tree().create_timer(TUTORIAL_DELAY).timeout.connect(_auto_open_tutorial)


func _unhandled_input(event: InputEvent) -> void:
	# An open overlay owns back (PreRoundSetup and the tutorial close
	# themselves on ui_cancel before it reaches us).
	if event.is_action_pressed(&"ui_cancel") and _stack.size() > 1 and not _overlay_open():
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


## Opens one of the old overlay screens on top of the menu; they free
## themselves when closed.
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


## The screens on the stack re-read the save (once per frame at most).
func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_refresh_screens.call_deferred()


func _refresh_screens() -> void:
	_refresh_queued = false
	for screen in _stack:
		if screen is RosterScreen:
			(screen as RosterScreen).refresh()
		elif screen is CharacterDetail:
			(screen as CharacterDetail).refresh()


func _on_currency_changed(_currency: StringName, _amount: int) -> void:
	_queue_refresh()


func _roster(side: int) -> RosterScreen:
	return monster_roster if side == MatchRewards.Side.MONSTER else hero_roster


func _start_match() -> void:
	get_tree().change_scene_to_packed.call_deferred(GameManager.get_world_scene())


# --- screen signals (connected in MenuRoot.tscn) ---

func _on_side_chosen(side: int) -> void:
	GameManager.choose_side(side)


func _on_hunt_requested(side: int) -> void:
	if _overlay_open():
		return
	if side != GameManager.chosen_side:
		GameManager.choose_side(side)
	if GameManager.chosen_side == MatchRewards.Side.MONSTER:
		_start_match()
		return
	# Strategy first (README round structure step 1); the screen persists the
	# MatchConfig and only asks us to start. Runtime-instanced, so connected here.
	var setup := PRE_ROUND_SCENE.instantiate() as PreRoundSetup
	setup.start_requested.connect(_on_pre_round_start_requested)
	_open_overlay(setup)


func _on_pre_round_start_requested(_config: MatchConfig) -> void:
	_start_match()


## A side's collection (the lobby's plaques, the nav bar's Heroes / Monsters).
func _on_roster_requested(side: int) -> void:
	var roster := _roster(side)
	if roster != top():
		roster.open()
	switch_to(roster)


## An owned character's overview, over the screen that asked (a roster card or
## the lobby, which has already chosen the character's side). Locked
## characters (the lair's teasers) have no detail yet.
func _on_character_requested(character: CharacterDef) -> void:
	if character == null or not CharacterProgress.is_unlocked(character) or _stack.has(detail):
		return
	detail.show_character(character)
	push(detail)


## The chosen side's account-wide tree (nav bar Growth).
func _open_growth() -> void:
	if growth == top() and growth.base_side == GameManager.chosen_side:
		return
	growth.show_base_tree(GameManager.chosen_side)
	switch_to(growth)


func _on_back_requested() -> void:
	pop()


## A skill node's UPGRADE buys its next rank: the shop decides (gates, price);
## the screens refresh on the signals it fires.
func _on_upgrade_requested(tree_id: StringName, node_id: StringName) -> void:
	MetaSkillManager.rank_up(tree_id, node_id)


func _on_tab_selected(tab_id: StringName) -> void:
	match tab_id:
		&"hunt":
			_on_hunt_requested(GameManager.chosen_side)
		&"heroes":
			_on_roster_requested(MatchRewards.Side.HEROES)
		&"monsters":
			_on_roster_requested(MatchRewards.Side.MONSTER)
		&"growth":
			_open_growth()
		&"codex":
			_open_tutorial()


func _on_settings_requested() -> void:
	if not _overlay_open():
		_open_overlay(SettingsScreen.new())
