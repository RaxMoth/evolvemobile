class_name HeroHudCard
extends Button

## One hero's card in the MatchHud's bottom row (heroes side), 172x146:
##   - the head portrait (the CharacterDef's head_region of its portrait SVG,
##     CharacterDef.head_texture()) in a ring of the hero's signature colour,
##     with the in-round level on a pill badge;
##   - the name, the HP bar and the in-round XP bar. The HP fill is the theme's
##     HpBarHero above HP_HURT, amber down to HP_CRITICAL and danger below; the
##     two extra fills are built once per card;
##   - the passive, active and ultimate AbilitySlots. Active and ultimate are
##     bound to a CooldownSource.Hero (the slot polls the real cooldown); the
##     passive never cools down, so it only takes its icon.
## The selected card (set_active) lifts LIFT px and wears HudPanelSelected. A
## dead hero's card greys out (UiPalette.FALLEN_MODULATE) under a skull. A
## level-up pops the level badge (LEVEL_POP -> 1, TRANS_BACK).
## Pressing the card emits `selected`; MatchHud decides whether the hero can
## take the focus. Presentation only: it reads the hero, never writes it.

signal selected(hero: Node)

## HP fraction at or below which the bar turns amber, and danger.
const HP_HURT := 0.5
const HP_CRITICAL := 0.25
## How far the selected card rises, and how fast.
const LIFT := 8.0
const LIFT_TIME := 0.12
## CooldownSource.Hero slots the card shows.
const SLOT_ACTIVE := 1
const SLOT_ULT := 2
const SLOT_PASSIVE := 3
## Width of the portrait ring.
const RING_WIDTH := 3
## The level badge's pop on a level-up: it jumps to LEVEL_POP and settles back
## to 1 over LEVEL_POP_TIME s (pivot: its centre, pivot_offset_ratio in the
## scene).
const LEVEL_POP := 1.4
const LEVEL_POP_TIME := 0.35

var hero: Node = null

var _stats: HeroStatsComponent = null
var _active: bool = false
var _dead: bool = false
## Fill styleboxes by HP band (healthy = the theme's own, hurt, critical).
var _fills: Array[StyleBox] = []
var _band: int = -1
var _shown_xp: float = -1.0
var _lift: Tween = null
var _level_pop: Tween = null

@onready var _card: Panel = %Card
@onready var _portrait: Panel = %Portrait
@onready var _head: TextureRect = %Head
@onready var _level_badge: Control = %LevelBadge
@onready var _level: Label = %LevelText
@onready var _name: Label = %Name
@onready var _hp: ProgressBar = %Hp
@onready var _xp: ProgressBar = %Xp
@onready var _passive: AbilitySlot = %Passive
@onready var _active_slot: AbilitySlot = %Active
@onready var _ult: AbilitySlot = %Ult
@onready var _down: CanvasItem = %Down


func _ready() -> void:
	var pal := UiPalette.get_default()
	var healthy := _hp.get_theme_stylebox(&"fill")
	_fills.append(healthy)
	_fills.append(_tinted(healthy, pal.amber, pal.amber_dark))
	_fills.append(_tinted(healthy, pal.danger, pal.danger_dark))
	set_process(false)
	_apply_style(false)


## Shows `new_hero`: portrait, name and ring from its CharacterDef, its slots,
## HP, level and XP; HP and level follow its HeroStats signals from now on.
func bind_to_hero(new_hero: Node) -> void:
	hero = new_hero
	if not is_instance_valid(hero):
		return
	var hero_id := MetaSkillManager.hero_id_of(hero)
	_stats = hero.get_node_or_null(^"HeroStats") as HeroStatsComponent
	var def := GameManager.ROSTER.find(hero_id)
	if def != null:
		_head.texture = def.head_texture()
		_name.text = def.get_display_name()
	elif _stats != null and _stats.base_stats != null:
		_head.texture = _stats.base_stats.portrait
		_name.text = _stats.base_stats.hero_name
	_ring(UiPalette.signature(String(hero_id), false))

	var system := hero.get_node_or_null(^"AbilitySystem") as AbilitySystem
	if system != null:
		var source := CooldownSource.Hero.new(system)
		_passive.icon_texture = source.icon(SLOT_PASSIVE)
		_active_slot.bind(source, SLOT_ACTIVE)
		_ult.bind(source, SLOT_ULT)

	if _stats != null:
		_stats.health_changed.connect(_on_health_changed)
		_stats.leveled_up.connect(_on_leveled_up)
		_on_health_changed(_stats.get_current_health(), _stats.get_max_health())
		_level.text = str(_stats.level)
		set_process(true)


## The camera's focus: lifted, amber border. Idempotent.
func set_active(active: bool) -> void:
	if _active == active:
		return
	_active = active
	_apply_style(true)


func is_active() -> bool:
	return _active


func is_dead() -> bool:
	return _dead


## HP band of a health fraction: 0 healthy, 1 hurt (amber), 2 critical.
static func hp_band(frac: float) -> int:
	if frac > HP_HURT:
		return 0
	if frac > HP_CRITICAL:
		return 1
	return 2


## The in-round XP bar: HeroStats has no XP signal, so the card reads it each
## frame and writes the bar only when it moved.
func _process(_delta: float) -> void:
	if not is_instance_valid(_stats):
		_stats = null
		set_process(false)
		_set_dead()
		return
	var xp := _stats.current_xp / HeroStatsComponent.XP_PER_LEVEL * 100.0
	if xp != _shown_xp:
		_shown_xp = xp
		_xp.value = xp


func _on_health_changed(current: float, max_hp: float) -> void:
	var frac := clampf(current / maxf(1.0, max_hp), 0.0, 1.0)
	_hp.value = frac * 100.0
	var band := hp_band(frac)
	if band != _band:
		_band = band
		_hp.add_theme_stylebox_override(&"fill", _fills[band])
	if current <= 0.0:
		_set_dead()


## HeroStats.leveled_up: the new level, with the badge pop.
func _on_leveled_up(new_level: int) -> void:
	_level.text = str(new_level)
	if _level_pop:
		_level_pop.kill()
	_level_badge.scale = Vector2.ONE * LEVEL_POP
	_level_pop = create_tween()
	_level_pop.tween_property(_level_badge, ^"scale", Vector2.ONE, LEVEL_POP_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_dead() -> void:
	if _dead:
		return
	_dead = true
	modulate = UiPalette.FALLEN_MODULATE
	_down.visible = true
	set_process(false)


## A copy of the bar's fill in another colour (`edge` = its bottom lip).
static func _tinted(base: StyleBox, fill: Color, edge: Color) -> StyleBox:
	var sb := base.duplicate() as StyleBoxFlat
	if sb == null:
		return base
	sb.bg_color = fill
	sb.border_color = edge
	return sb


## The portrait well in the hero's signature colour: the theme's HudPanel box
## with a wider border, made once per card.
func _ring(color: Color) -> void:
	var sb := _card.get_theme_stylebox(&"panel", &"HudPanel").duplicate() as StyleBoxFlat
	if sb == null:
		return
	sb.bg_color = UiPalette.get_default().panel_inset
	sb.border_color = color
	sb.set_border_width_all(RING_WIDTH)
	_portrait.add_theme_stylebox_override(&"panel", sb)


func _apply_style(animate: bool) -> void:
	_card.theme_type_variation = &"HudPanelSelected" if _active else &"HudPanel"
	var y := -LIFT if _active else 0.0
	if _lift:
		_lift.kill()
		_lift = null
	if animate:
		_lift = create_tween()
		_lift.tween_property(_card, ^"position:y", y, LIFT_TIME) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_card.position.y = y


func _on_pressed() -> void:
	if is_instance_valid(hero):
		selected.emit(hero)
