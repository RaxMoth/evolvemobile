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
##   - autoloads: the tree unpaused on entry (a match result pauses it), the
##     menu music, the UI click on every button press, the first-run tutorial,
##     GameManager's chosen side (persisted) and the background World load.
## Until their new screens land, a few requests open the old overlays on top:
## HUNT -> PreRoundSetup (heroes; the monster side starts at once), Heroes /
## Monsters / Growth -> MetaSkillScreen on the matching tree, Codex ->
## TutorialOverlay, the gear -> SettingsScreen. Tapping a character only
## chooses its side until the character detail screen opens it.

const SLIDE_TIME := 0.22
## Seconds after entry before the first-run tutorial opens.
const TUTORIAL_DELAY := 0.9
const PRE_ROUND_SCENE: PackedScene = preload("res://Scenes/UI/PreRoundSetup/PreRoundSetup.tscn")
const META_SKILL_SCENE: PackedScene = preload("res://Scenes/UI/MetaSkills/MetaSkillScreen.tscn")
const TUTORIAL_SCENE: PackedScene = preload("res://Scenes/UI/Tutorial/TutorialOverlay.tscn")

## The home screen, the bottom of the stack.
@export var lobby: LobbyScreen

## The screens on the way back, the home screen first and the shown one last.
var _stack: Array[Control] = []
var _slide: Tween = null
## The old overlay that is open (one at a time), or null.
var _overlay: Node = null

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
func push(screen: Control) -> void:
	if screen == null or _stack.has(screen):
		return
	_finish_slide()
	var below := top()
	_stack.append(screen)
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
	if _stack.size() < 2:
		return
	_finish_slide()
	var leaving: Control = _stack.pop_back()
	var below := top()
	below.visible = true
	_slide = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide.tween_property(leaving, ^"position:x", size.x, SLIDE_TIME)
	_slide.tween_property(below, ^"modulate", Color.WHITE, SLIDE_TIME)
	_slide.chain().tween_callback(_settle)


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


func _open_skill_trees(tree_id: StringName) -> void:
	if _overlay_open():
		return
	var screen := META_SKILL_SCENE.instantiate() as MetaSkillScreen
	screen.initial_tree_id = tree_id
	_open_overlay(screen)


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


## Until the roster screens: the side's own character trees (the first hero,
## or the selected monster) in the old skill screen, whose picker lists the rest.
func _on_roster_requested(side: int) -> void:
	var def: CharacterDef = null
	if side == MatchRewards.Side.MONSTER:
		def = GameManager.selected_monster_def()
	elif not GameManager.ROSTER.heroes.is_empty():
		def = GameManager.ROSTER.heroes[0]
	_open_skill_trees(def.skill_tree_id() if def != null else &"")


## The character detail screen is not built yet; the lobby has already chosen
## the character's side.
func _on_character_requested(_character: CharacterDef) -> void:
	pass


func _on_tab_selected(tab_id: StringName) -> void:
	match tab_id:
		&"hunt":
			_on_hunt_requested(GameManager.chosen_side)
		&"heroes":
			_on_roster_requested(MatchRewards.Side.HEROES)
		&"monsters":
			_on_roster_requested(MatchRewards.Side.MONSTER)
		&"growth":
			var monster := GameManager.chosen_side == MatchRewards.Side.MONSTER
			_open_skill_trees(MetaSkillManager.TREE_MONSTER_BASE if monster else MetaSkillManager.TREE_HERO_BASE)
		&"codex":
			_open_tutorial()


func _on_settings_requested() -> void:
	if not _overlay_open():
		_open_overlay(SettingsScreen.new())
