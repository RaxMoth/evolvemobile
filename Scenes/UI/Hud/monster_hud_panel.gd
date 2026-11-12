class_name MonsterHudPanel
extends PanelContainer

## The monster side's bottom panel in the MatchHud (700x178):
##   - the head portrait of the stage it has reached
##     (CharacterDef.head_texture(stage): Grount's horns grow) in a ring of the
##     monster's signature colour, with the stage pips I / II / III under it
##     (PillReady once reached);
##   - the name, "STAGE II · DANGEROUS" and the AI's intent pill (intent_of):
##     FARMING, AMBUSH, HUNTING or RETREAT, read from the monster's strategy,
##     its rest and its state chart;
##   - the HP bar with "1008 / 1400" and the EVOLVE bar with the XP towards the
##     next stage (hidden at the last stage);
##   - the passive (Grount's Evolution, 56 px) and ability_1..3 (68, 68 and
##     72 px: the row fills the width left of the tally) as AbilitySlots
##     bound to a CooldownSource.Monster: Ground Slam shows its padlock and
##     "II" until Stage II;
##   - a tally: heroes slain and mobs this monster devoured, counted from
##     EventBus.entity_died since bind.
## The slots poll every frame; everything else is read at POLL_HZ and written
## only when the shown value changes (and again when the language is switched
## in the pause menu's settings). Read-only: it never writes the monster.

enum Intent { FARMING, AMBUSH, HUNTING, RETREAT }

const POLL_HZ := 10.0
## Stage numerals and the README's stage names (Stage 1 Vulnerable, 2
## Dangerous, 3 Apex Predator), by stage.
const STAGE_NAMES: Array[String] = ["", "VULNERABLE", "DANGEROUS", "APEX"]
const INTENT_NAMES: Array[String] = ["FARMING", "AMBUSH", "HUNTING", "RETREAT"]
## Palette token of each intent's label.
const INTENT_TOKENS: Array[StringName] = [&"moss_light", &"amber", &"danger", &"xp"]
## CooldownSource.Monster slots.
const SLOT_PASSIVE := 3
const RING_WIDTH := 3

var monster: MonsterBase = null

## The monster's roster def (null when it has none): its stage heads.
var _def: CharacterDef = null
var _poll: float = 0.0
var _approach: StateChartState = null
var _fight: StateChartState = null
var _shown_stage: int = 0
var _shown_hp: Vector2i = Vector2i(-1, -1)
var _shown_evo: Vector2i = Vector2i(-1, -1)
var _shown_intent: int = -1
var _hero_count: int = 0
var _heroes_slain: int = 0
var _mobs_devoured: int = 0

@onready var _portrait: Panel = %Portrait
@onready var _head: TextureRect = %Head
@onready var _pips: Array[PanelContainer] = [%Pip1 as PanelContainer, %Pip2 as PanelContainer, %Pip3 as PanelContainer]
@onready var _name: Label = %Name
@onready var _stage_text: Label = %StageText
@onready var _intent: Label = %Intent
@onready var _hp: ProgressBar = %Hp
@onready var _hp_text: Label = %HpText
@onready var _evo: ProgressBar = %Evo
@onready var _evo_text: Label = %EvoText
## ability_1..3, then the passive (CooldownSource.Monster order).
@onready var _slots: Array[AbilitySlot] = [%A1 as AbilitySlot, %A2 as AbilitySlot, %A3 as AbilitySlot, %Passive as AbilitySlot]
@onready var _tally: Label = %Tally


func _ready() -> void:
	set_process(false)


## Shows `m` from now on. `hero_count` = the heroes it hunts (the tally's
## "of N").
func bind_to_monster(m: MonsterBase, hero_count: int) -> void:
	monster = m
	_hero_count = hero_count
	if not is_instance_valid(m):
		return
	var id := m.monster_stats.monster_id if m.monster_stats != null else StringName(String(m.name).to_lower())
	var def := GameManager.ROSTER.find(id)
	_def = def
	_name.text = (def.get_display_name() if def != null else String(m.name)).to_upper()
	if def != null:
		_head.texture = def.head_texture(m.get_stage())
	_ring(UiPalette.signature(String(id), true))

	var source := CooldownSource.Monster.new(m)
	for i in 3:
		_slots[i].bind(source, i)
	# Every monster scene has a passive resource; a slot without one hides.
	var passive := source.icon(SLOT_PASSIVE)
	_slots[SLOT_PASSIVE].icon_texture = passive
	_slots[SLOT_PASSIVE].visible = passive != null

	if m.state_chart != null:
		_approach = m.state_chart.get_node_or_null(^"CompoundState/Approach") as StateChartState
		_fight = m.state_chart.get_node_or_null(^"CompoundState/Fight") as StateChartState
	if not EventBus.entity_died.is_connected(_on_entity_died):
		EventBus.entity_died.connect(_on_entity_died)
	_show_tally()
	_refresh()
	set_process(true)


## What the HUD calls the monster's plan. A resting monster or a RETREAT
## strategy retreats; a monster closing in on or fighting a hero hunts,
## whatever its strategy (an ambush springing, a cornered farmer); otherwise
## the strategy names it.
static func intent_of(strategy: MonsterBase.Strategy, resting: bool, engaging_hero: bool) -> Intent:
	if resting or strategy == MonsterBase.Strategy.RETREAT:
		return Intent.RETREAT
	if engaging_hero:
		return Intent.HUNTING
	match strategy:
		MonsterBase.Strategy.FARM:
			return Intent.FARMING
		MonsterBase.Strategy.AMBUSH:
			return Intent.AMBUSH
	return Intent.HUNTING


## The bound monster's intent now (HUNTING without a strategy profile: the
## legacy behaviour always hunts).
func current_intent() -> Intent:
	if not is_instance_valid(monster) or monster.strategy_profile == null or not monster.strategy_profile.enabled:
		return Intent.HUNTING
	var chasing := (_approach != null and _approach.active) or (_fight != null and _fight.active)
	# target_entity: `target` is the entity's Body Area2D, never a HeroBase.
	var engaging := chasing and monster.is_target_valid() and monster.target_entity is HeroBase
	return intent_of(monster.strategy, monster.is_resting(), engaging)


func _process(delta: float) -> void:
	_poll -= delta
	if _poll > 0.0:
		return
	_poll += 1.0 / POLL_HZ
	_refresh()


## The language changed: the lines formatted here are written again.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and is_instance_valid(monster):
		_shown_stage = 0
		_shown_evo = Vector2i(-1, -1)
		_shown_intent = -1
		_show_tally()
		_refresh()


func _refresh() -> void:
	if not is_instance_valid(monster):
		monster = null
		modulate = UiPalette.FALLEN_MODULATE
		for slot in _slots:
			slot.set_dead()
		set_process(false)
		return
	var stage := monster.get_stage()
	if stage != _shown_stage:
		_show_stage(stage)
	var hp := Vector2i(roundi(monster.get_health()), roundi(monster.get_max_health()))
	if hp != _shown_hp:
		_shown_hp = hp
		_hp.value = float(hp.x) / maxf(1.0, float(hp.y)) * 100.0
		_hp_text.text = "%d / %d" % [hp.x, hp.y]
	if stage < CooldownSource.STAGE_NUMERALS.size() - 1:
		var evo := Vector2i(floori(monster.current_xp), monster.get_evolution_threshold())
		if evo != _shown_evo:
			_shown_evo = evo
			_evo.value = float(evo.x) / maxf(1.0, float(evo.y)) * 100.0
			_evo_text.text = tr("EVOLVE  %d / %d XP") % [evo.x, evo.y]
	var intent := current_intent()
	if intent != _shown_intent:
		_shown_intent = intent
		_intent.text = tr(INTENT_NAMES[intent])
		_intent.add_theme_color_override(&"font_color", UiPalette.get_default().color(INTENT_TOKENS[intent]))


func _show_stage(stage: int) -> void:
	_shown_stage = stage
	var last := CooldownSource.STAGE_NUMERALS.size() - 1
	var shown := clampi(stage, 1, last)
	_stage_text.text = "%s · %s" % [tr("STAGE %s") % CooldownSource.STAGE_NUMERALS[shown], tr(STAGE_NAMES[shown])]
	for i in _pips.size():
		_pips[i].theme_type_variation = &"PillReady" if i < stage else &"Pill"
	if _def != null:
		_head.texture = _def.head_texture(shown)
	var evolving := stage < last
	_evo.visible = evolving
	_evo_text.visible = evolving


## EventBus.entity_died: every hero death, and the mobs this monster killed.
func _on_entity_died(entity: Node, killer: Node) -> void:
	if entity is HeroBase:
		_heroes_slain += 1
	elif entity is MobBase and killer != null and killer == monster:
		_mobs_devoured += 1
	else:
		return
	_show_tally()


func _show_tally() -> void:
	_tally.text = "%s\n%s" % [tr("Heroes slain  %d / %d") % [_heroes_slain, _hero_count],
			tr("Mobs devoured  %d") % _mobs_devoured]


func _ring(color: Color) -> void:
	var sb := get_theme_stylebox(&"panel", &"HudPanel").duplicate() as StyleBoxFlat
	if sb == null:
		return
	sb.bg_color = UiPalette.get_default().panel_inset
	sb.border_color = color
	sb.set_border_width_all(RING_WIDTH)
	_portrait.add_theme_stylebox_override(&"panel", sb)
