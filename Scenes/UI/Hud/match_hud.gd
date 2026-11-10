class_name MatchHud
extends CanvasLayer

## The in-match HUD of both sides (a MainCam child, MainCam.tscn). Presentation
## only: it reads the entities and GameManager, never writes gameplay state.
##
## Top bar (Root/Top), refreshed at TOP_HZ, each label written only on change:
##   - Pause: toggles the tree's pause while a match runs (the button keeps
##     working while paused: process_mode ALWAYS in the scene);
##   - the clock, GameManager.get_match_elapsed();
##   - the enemy tracker: heroes side, the monster's head, stage and HP;
##     monster side, a head and mini HP bar per hero (from the HeroChip
##     template in the scene), greyed when the hero falls;
##   - the kills chip: the played side's mob kills
##     (GameManager.played_side_kills(), the result screen's tally);
##   - Follow: follow_requested (MainCam.recenter, wired in MainCam.tscn).
## Under it, MinimapFrame holds the match's Minimap (its own frame hidden);
## a tap on the map selects the nearest hero (Minimap.hero_picked ->
## select_hero, wired in this scene).
## Bottom: heroes side, one HeroHudCard per hero (the "Hero" group's HeroBase
## nodes, in tree order); monster side, the MonsterHudPanel.
## Event toasts (show_toast): the crimson BannerMonster ribbon at y 250
## (Root/ToastBar) pops in, holds and fades; toasts queue, at most one shows.
## The scene's Announcer (MatchAnnouncer) feeds it: monster evolved, hero
## fell, ultimate cast (Announcer.announced -> show_toast, wired in this scene).
##
## Hero focus (heroes side; the monster side has no cards, so every call is a
## no-op there): a card press, the 1-4 keys and Tab (MainCam), a tap on a hero
## in the world (MainCam) or on the minimap all go through select_hero /
## cycle_to_next_hero, which keep the lifted card in sync and emit
## hero_selected (MainCam.switch_to_hero, wired in MainCam.tscn). A dead hero
## cannot take the focus; when the followed hero dies, the focus moves on to the
## next living hero so the camera does not stay at the death spot.

signal hero_selected(hero: Node)
## The Follow button: centre the camera on what it follows again.
signal follow_requested

const HERO_CARD: PackedScene = preload("res://Scenes/UI/Hud/HeroHudCard.tscn")
## Top bar refresh rate (clock, kills, enemy tracker).
const TOP_HZ := 4.0
## Event toast timing (s): pop-in from TOAST_POP_FROM to full size (TRANS_BACK)
## while fading in, hold, fade out.
const TOAST_POP_FROM := 0.7
const TOAST_POP := 0.3
const TOAST_FADE_IN := 0.15
const TOAST_HOLD := 2.2
const TOAST_FADE_OUT := 0.3
## Toasts waiting behind the visible one; when full, the oldest waiting one
## gives way to the newest.
const TOAST_MAX_PENDING := 3

@export var pause_icon: Texture2D
@export var play_icon: Texture2D

## One card per hero, in roster (tree) order; empty on the monster side.
var cards: Array[HeroHudCard] = []
## The hero the camera follows (heroes side).
var active_hero: Node = null

var _heroes_side: bool = true
var _monster: MonsterBase = null
var _top_timer: float = 0.0
var _shown_seconds: int = -1
var _shown_kills: int = -1
var _shown_stage: int = 0
## Monster side's tracker, by index: the heroes (untyped: a dead hero is
## freed), their chips and HP bars, and whether the chip already shows the fall.
var _tracked: Array = []
var _tracked_chips: Array[Control] = []
var _tracked_bars: Array[ProgressBar] = []
var _tracked_down: Array[bool] = []
## The toast on screen ("" when none), the ones waiting, and its tween.
var _toast_shown: String = ""
var _toast_queue: Array[String] = []
var _toast_tween: Tween = null

@onready var _hero_cards: HBoxContainer = %HeroCards
@onready var _monster_panel: MonsterHudPanel = %MonsterPanel
@onready var _enemy_monster: Control = %EnemyMonster
@onready var _enemy_heroes: Control = %EnemyHeroes
@onready var _enemy_head: TextureRect = %EnemyHead
@onready var _enemy_stage: Label = %EnemyStage
@onready var _enemy_hp: ProgressBar = %EnemyHp
@onready var _hero_row: HBoxContainer = %HeroRow
## The tracker's per-hero chip (head + mini HP bar), duplicated per hero.
@onready var _hero_chip: Control = _hero_row.get_node(^"HeroChip")
@onready var _pause: Button = %Pause
@onready var _clock: Label = %Clock
@onready var _kills: Label = %Kills
@onready var _toast: Control = %Toast
@onready var _toast_text: Label = %ToastText


func _ready() -> void:
	_heroes_side = GameManager.chosen_side == MatchRewards.Side.HEROES
	_hero_cards.visible = _heroes_side
	_monster_panel.visible = not _heroes_side
	_enemy_monster.visible = _heroes_side
	_enemy_heroes.visible = not _heroes_side
	_hero_chip.visible = false
	_toast.visible = false
	set_process(false)
	# Two frames so the entities finish their own _ready (which awaits
	# physics frames) before the HUD reads their stats.
	await get_tree().process_frame
	await get_tree().process_frame
	_bind()


func _bind() -> void:
	var heroes: Array[HeroBase] = []
	for node in get_tree().get_nodes_in_group("Hero"):
		# Ted's pet is in the Hero group too, but it is no HeroBase.
		if node is HeroBase:
			heroes.append(node as HeroBase)
	for node in get_tree().get_nodes_in_group("Monster"):
		if node is MonsterBase:
			_monster = node as MonsterBase
			break
	if _heroes_side:
		for hero in heroes:
			var card := HERO_CARD.instantiate() as HeroHudCard
			_hero_cards.add_child(card)
			card.bind_to_hero(hero)
			card.selected.connect(select_hero)
			cards.append(card)
		if not cards.is_empty():
			_set_active_card(cards[0])
		if _monster != null:
			_enemy_head.texture = _head_of(_monster_id(_monster))
	else:
		for hero in heroes:
			_add_tracked_hero(hero)
		if _monster != null:
			_monster_panel.bind_to_monster(_monster, heroes.size())
	EventBus.entity_died.connect(_on_entity_died)
	_refresh_top()
	set_process(true)


func _process(delta: float) -> void:
	_top_timer -= delta
	if _top_timer > 0.0:
		return
	_top_timer += 1.0 / TOP_HZ
	_refresh_top()


func _refresh_top() -> void:
	var seconds := floori(GameManager.get_match_elapsed())
	if seconds != _shown_seconds:
		_shown_seconds = seconds
		_clock.text = clock_text(seconds)
	var kills := GameManager.played_side_kills()
	if kills != _shown_kills:
		_shown_kills = kills
		_kills.text = str(_shown_kills)
	if _heroes_side:
		_refresh_enemy_monster()
	else:
		_refresh_tracked_heroes()


## "03:42" for 222 s.
static func clock_text(seconds: int) -> String:
	return "%02d:%02d" % [floori(seconds / 60.0), seconds % 60]


func _refresh_enemy_monster() -> void:
	if not is_instance_valid(_monster):
		return
	var stage := _monster.get_stage()
	if stage != _shown_stage:
		_shown_stage = stage
		var last := CooldownSource.STAGE_NUMERALS.size() - 1
		_enemy_stage.text = tr("STAGE %s") % CooldownSource.STAGE_NUMERALS[clampi(stage, 1, last)]
	_enemy_hp.value = _monster.get_health() / maxf(1.0, _monster.get_max_health()) * 100.0


func _add_tracked_hero(hero: HeroBase) -> void:
	var chip := _hero_chip.duplicate() as Control
	chip.visible = true
	_hero_row.add_child(chip)
	(chip.get_node(^"Head") as TextureRect).texture = _head_of(MetaSkillManager.hero_id_of(hero))
	_tracked.append(hero)
	_tracked_chips.append(chip)
	_tracked_bars.append(chip.get_node(^"Hp") as ProgressBar)
	_tracked_down.append(false)


func _refresh_tracked_heroes() -> void:
	for i in _tracked.size():
		if _tracked_down[i]:
			continue
		var frac := 0.0
		if is_instance_valid(_tracked[i]):
			var hero := _tracked[i] as HeroBase
			if hero.is_alive():
				frac = hero.get_health() / maxf(1.0, hero.get_max_health())
		_tracked_bars[i].value = frac * 100.0
		if frac <= 0.0:
			_tracked_down[i] = true
			_tracked_chips[i].modulate = UiPalette.FALLEN_MODULATE


static func _monster_id(m: MonsterBase) -> StringName:
	if m.monster_stats != null and m.monster_stats.monster_id != &"":
		return m.monster_stats.monster_id
	return StringName(String(m.name).to_lower())


## The head portrait of a roster character (null when it has no def).
static func _head_of(character_id: StringName) -> Texture2D:
	var def := GameManager.ROSTER.find(character_id)
	return def.head_texture() if def != null else null


# ============================================
# Event toasts
# ============================================

## Shows `text` on the toast ribbon: it pops in (0.7 -> 1, TRANS_BACK, 0.3 s),
## holds 2.2 s and fades out in 0.3 s, then the next waiting toast shows. At
## most one toast is visible. While one is up, `queued` true waits in line
## (TOAST_MAX_PENDING; a full line drops its oldest) and `queued` false is
## dropped (moment-to-moment news: an ultimate). A text already showing or
## waiting is not added twice.
func show_toast(text: String, queued: bool = true) -> void:
	if text.is_empty() or text == _toast_shown or _toast_queue.has(text):
		return
	if _toast_tween == null:
		_play_toast(text)
	elif queued:
		if _toast_queue.size() >= TOAST_MAX_PENDING:
			_toast_queue.remove_at(0)
		_toast_queue.append(text)


## The toast on screen, "" when none.
func current_toast() -> String:
	return _toast_shown


## The toasts waiting behind the current one, oldest first.
func pending_toasts() -> PackedStringArray:
	return PackedStringArray(_toast_queue)


func _play_toast(text: String) -> void:
	_toast_shown = text
	_toast_text.text = text
	_toast.visible = true
	_toast.scale = Vector2.ONE * TOAST_POP_FROM
	_toast.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, ^"modulate:a", 1.0, TOAST_FADE_IN)
	_toast_tween.parallel().tween_property(_toast, ^"scale", Vector2.ONE, TOAST_POP) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_interval(TOAST_HOLD)
	_toast_tween.tween_property(_toast, ^"modulate:a", 0.0, TOAST_FADE_OUT)
	_toast_tween.finished.connect(_on_toast_finished)


func _on_toast_finished() -> void:
	_toast_tween = null
	_toast_shown = ""
	_toast.visible = false
	if not _toast_queue.is_empty():
		var next: String = _toast_queue.pop_front()
		_play_toast(next)


# ============================================
# Hero focus (also used by MainCam: keys, taps)
# ============================================

## Focus `hero` (card press, 1-4 keys, a tap in the world or on the minimap).
## A dead hero, or one without a card, is ignored.
func select_hero(hero: Node) -> void:
	for card in cards:
		if card.hero == hero:
			if _is_selectable(card):
				_set_active_card(card)
				hero_selected.emit(hero)
			return


## Tab: focus the next living hero after the active one, in card order. Does
## nothing when no hero is alive.
func cycle_to_next_hero() -> void:
	var count := cards.size()
	var current := -1
	for i in count:
		if cards[i].hero == active_hero:
			current = i
			break
	# From current + 1 round to current itself (from card 0 without a match).
	for step in range(1, count + 1):
		var card := cards[(current + step) % count]
		if _is_selectable(card):
			_set_active_card(card)
			hero_selected.emit(card.hero)
			return


## The hero of card `index` (the 1-4 keys), or null.
func hero_at(index: int) -> Node:
	if index < 0 or index >= cards.size() or not is_instance_valid(cards[index].hero):
		return null
	return cards[index].hero


func _set_active_card(active: HeroHudCard) -> void:
	for card in cards:
		card.set_active(card == active)
	active_hero = active.hero


## A card can take the focus while its hero lives. A hero that just died is
## still a valid instance until the end of the frame (queue_free), so the
## liveness check matters too.
func _is_selectable(card: HeroHudCard) -> bool:
	return is_instance_valid(card.hero) and (card.hero as EntityBase).is_alive()


## EventBus.entity_died. Only the followed hero's death matters: the active
## hero is always a carded hero, so mobs, the monster and Ted's pet return
## early. With nobody left to follow, active_hero clears (the hero is freed at
## the end of this frame).
func _on_entity_died(entity: Node, _killer: Node) -> void:
	if entity == null or entity != active_hero:
		return
	cycle_to_next_hero()
	if active_hero == entity:
		active_hero = null


func _on_pause_pressed() -> void:
	if not GameManager.is_match_active():
		return
	var tree := get_tree()
	tree.paused = not tree.paused
	_pause.icon = play_icon if tree.paused else pause_icon


func _on_follow_pressed() -> void:
	follow_requested.emit()
