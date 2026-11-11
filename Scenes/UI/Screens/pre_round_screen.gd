class_name PreRoundScreen
extends Control

## The step between HUNT and the match, one screen for both sides (it replaces
## the old PreRoundSetup overlay). MenuRoot calls open(side) before it slides
## the screen in and connects every signal in MenuRoot.tscn; every connection
## inside the screen is in PreRoundScreen.tscn, except the runtime-built cards
## and squad (wired here).
##
## Heroes ("The Hunt"):
##   - TONIGHT'S QUARRY: the monster this hunt faces (GameManager.next_quarry(),
##     the same until a hunt starts) as an L CharacterCard that shows the AI
##     opponent's strength ("Threat T" where a card of the player's own has
##     its level; the pill: "AI build n/12", its AI build's ranks of the
##     threat-4 build), its name, tagline and the icons of its three moves, the
##     NEW QUARRY banner until the heroes have hunted it once
##     (GameManager.is_new_quarry) and the ThreatBox. CHANGE (or a tap on the
##     card) opens the quarry sheet: every roster monster as an S card, the
##     pool's ones to pick and the rest as silhouettes reading "Appears after N
##     hunts" (hunts_until_quarry), plus RANDOM. A pick locks that quarry for
##     every hunt (GameManager.lock_quarry(id), persisted); RANDOM unlocks it
##     (lock_quarry(&"")): the random pick again, never the same twice in a row.
##     The sheet holds the screen's TapGuard while it slides up: the second
##     tap of a double tap on CHANGE never closes it on the scrim.
##   - YOUR HUNTERS: the roster's heroes on the campfire stage as live rigs
##     (StageCharacter, the right pair facing inward) with their Lv.N.
##   - STRATEGY (three StrategyRows) and FORMATION (three FormationTiles) edit a
##     MatchConfig read from the settings; the forecast says in plain words what
##     the hero AI does with it (MatchConfig's derived values). Every change
##     goes into the settings at once (MatchConfig.store) and the file is
##     written when the screen is left (hidden: back, a nav tab) or the hunt
##     starts, so a strategy set and left with back is still there next time.
##   - START HUNT persists the config (save_to_settings), tracks
##     pre_round_setup in AnalyticsSink and emits start_requested(config) with
##     the quarry in config.quarry_id.
## Monster ("Your Beast"):
##   - THE LAIR: the picked monster big in its lair, "Name · Lv.N" and its role;
##   - the picker: every roster monster as an S card and the "???" slot. An owned
##     monster becomes the player's own (GameManager.choose_monster, persisted)
##     and cheers; a locked one whose rule is met (CharacterProgress: READY or
##     SHORT) asks for its unlock sheet (character_requested; MenuRoot opens
##     it, and a purchase makes it the picked monster through refresh()); any
##     other locked one, or the rumour, shakes;
##   - the evolution strip: the monster's body at Stage I, II and III (growing)
##     with its stage names (CharacterDef.stage_names);
##   - the ThreatBox (the AI heroes' build);
##   - the instinct tiles (Lurker / Ambusher / Ravager) are hidden
##     (show_instincts) until a gameplay batch balances their MonsterStrategy
##     presets; the monster plays DEFAULT_INSTINCT, today's behaviour;
##   - UNLEASH tracks pre_round_monster and emits
##     monster_start_requested(monster_id, instinct).
## START HUNT and UNLEASH act once per visit (open() arms them again): a
## double tap tracks and asks for one start.
## The top bar's back emits cancelled (MenuRoot pops the screen, as it does on
## ui_cancel); ui_cancel closes an open quarry sheet first.

signal start_requested(config: MatchConfig)
signal monster_start_requested(monster_id: StringName, instinct: StringName)
signal cancelled
## A locked monster on the picker that can be bought now: MenuRoot opens its
## unlock sheet.
signal character_requested(character: CharacterDef)

const STAGE_CHARACTER := preload("res://Scenes/UI/Components/StageCharacter.tscn")
const CARD_SCENE := preload("res://Scenes/UI/Components/CharacterCard.tscn")
const HERO_BACKDROP := preload("res://Assets/UI/Lobby/lobby_heroes.svg")
const MONSTER_BACKDROP := preload("res://Assets/UI/Lobby/lobby_monsters.svg")
## The instinct the monster plays while the tiles are hidden: today's
## MonsterStrategy defaults.
const DEFAULT_INSTINCT: StringName = &"ambusher"
## Formation tile ids by MatchConfig.Formation value.
const FORMATION_IDS: Array[StringName] = [&"tight", &"spread", &"line"]
## The squad on the hunters' stage.
const SQUAD_SIZE := Vector2(150, 200)
const CHEER_STAGGER := 0.05
const SHAKE_PX := 8.0
const SHAKE_STEP := 0.04
const SHEET_TIME := 0.22
## Opacity of the quarry sheet's scrim (UiPalette.bg_void).
const SCRIM_ALPHA := 0.72
## The NEW QUARRY banner pops in from this scale.
const BANNER_POP_FROM := Vector2(0.6, 0.6)
const STAGE_NUMERALS: PackedStringArray = ["I", "II", "III"]
## Groups of the sections only one side shows (PreRoundScreen.tscn).
const HERO_GROUP: StringName = &"pre_round_heroes"
const MONSTER_GROUP: StringName = &"pre_round_monster"

## The side shown (MatchRewards.Side values); open() sets it.
@export_enum("Heroes", "Monster") var side: int = MatchRewards.Side.HEROES
## Show the monster's instinct tiles (hidden until their presets are balanced).
@export var show_instincts: bool = false

## The heroes' strategy being edited (null until the heroes side opens).
var config: MatchConfig = null
## Tonight's quarry (Heroes side).
var quarry: CharacterDef = null
## The monster picked on the Monster side.
var monster: CharacterDef = null
## The instinct picked on the Monster side.
var instinct: StringName = DEFAULT_INSTINCT

## The formation and instinct tiles' groups. Made here, not as scene
## sub-resources: a shared one would link every instance of the screen, and one
## marked local to scene is copied per tile (the tiles are instanced scenes).
var _formation_group := ButtonGroup.new()
var _instinct_group := ButtonGroup.new()
var _squad: Array[StageCharacter] = []
var _picker_cards: Array[CharacterCard] = []
var _sheet_cards: Array[CharacterCard] = []
var _sheet_open := false
var _sheet_tween: Tween = null
## The strategy in the settings is newer than the save file.
var _config_unsaved := false
## START HUNT / UNLEASH was pressed on this visit.
var _started := false

@onready var _top_bar: TopBar = %TopBar
@onready var _scroll: ScrollContainer = %Scroll
@onready var _backdrop: TextureRect = %Backdrop
@onready var _stage_frame: Panel = %StageFrame
@onready var _stage_banner: PanelContainer = %StageBanner
@onready var _stage_title: Label = %StageTitle
@onready var _squad_row: HBoxContainer = %Squad
@onready var _big_monster: StageCharacter = %BigMonster
@onready var _monster_name: Label = %MonsterName
@onready var _monster_role: Label = %MonsterRole
@onready var _quarry_card: CharacterCard = %QuarryCard
@onready var _new_banner: Control = %NewBanner
@onready var _quarry_name: Label = %QuarryName
@onready var _quarry_tagline: Label = %QuarryTagline
@onready var _quarry_moves: HBoxContainer = %QuarryMoves
@onready var _quarry_threat: ThreatBox = %QuarryThreat
@onready var _monster_threat: ThreatBox = %MonsterThreat
@onready var _aggression: StrategyRow = %Aggression
@onready var _farming: StrategyRow = %Farming
@onready var _exploration: StrategyRow = %Exploration
@onready var _forecast_ult: Label = %ForecastUlt
@onready var _forecast_farm: Label = %ForecastFarm
@onready var _forecast_scout: Label = %ForecastScout
@onready var _picker: HBoxContainer = %Picker
@onready var _evolution: Array[RigView] = [%Evo1 as RigView, %Evo2 as RigView, %Evo3 as RigView]
@onready var _evolution_names: Array[Label] = [%EvoName1 as Label, %EvoName2 as Label, %EvoName3 as Label]
@onready var _sheet: Control = %QuarrySheet
@onready var _scrim: ColorRect = %Scrim
@onready var _slide: Control = %Slide
@onready var _sheet_cards_row: HBoxContainer = %SheetCards
@onready var _lock_state: Label = %LockState
@onready var _random: Button = %Random
@onready var _tap_guard: TapGuard = %TapGuard


func _ready() -> void:
	for tile in %Formations.get_children():
		(tile as ChoiceTile).button_group = _formation_group
	for tile in %Instincts.get_children():
		(tile as ChoiceTile).button_group = _instinct_group
	_scrim.color = Color(UiPalette.get_default().bg_void, SCRIM_ALPHA)
	_sheet.visible = false
	_apply_side()


## Shows `side` (MatchRewards.Side) and re-reads the save: tonight's quarry and
## the strategy, or the owned monsters and the player's own one.
func open(for_side: int) -> void:
	side = MatchRewards.Side.MONSTER if for_side == MatchRewards.Side.MONSTER else MatchRewards.Side.HEROES
	_started = false
	_close_sheet_now()
	_scroll.scroll_vertical = 0
	_apply_side()
	if is_monster():
		_open_monster_side()
	else:
		_open_hero_side()


func is_monster() -> bool:
	return side == MatchRewards.Side.MONSTER


func is_sheet_open() -> bool:
	return _sheet_open


## The heroes on the hunters' stage, in roster order.
func squad() -> Array[StageCharacter]:
	return _squad


## The Monster side's picker cards (roster monsters, then the rumour card).
func picker_cards() -> Array[CharacterCard]:
	return _picker_cards


## The quarry sheet's cards, one per roster monster.
func sheet_cards() -> Array[CharacterCard]:
	return _sheet_cards


## The heroes' config as the screen holds it, with tonight's quarry.
func collect_config() -> MatchConfig:
	if config == null:
		config = MatchConfig.from_settings()
	config.quarry_id = quarry.character_id() if quarry != null else &""
	return config


## The sections of the shown side.
func _apply_side() -> void:
	var monster_side := is_monster()
	_top_bar.title = "Your Beast" if monster_side else "The Hunt"
	_top_bar.show_steel = not monster_side
	_top_bar.show_leaves = monster_side
	for node in _sections(HERO_GROUP):
		node.visible = not monster_side
	for node in _sections(MONSTER_GROUP):
		node.visible = monster_side
	(%InstinctHeader as CanvasItem).visible = monster_side and show_instincts
	(%Instincts as CanvasItem).visible = monster_side and show_instincts
	_stage_frame.theme_type_variation = &"FrameMonster" if monster_side else &"FrameHero"
	_stage_banner.theme_type_variation = &"BannerMonster" if monster_side else &"BannerHero"
	_stage_title.text = "THE LAIR" if monster_side else "YOUR HUNTERS"
	_backdrop.texture = MONSTER_BACKDROP if monster_side else HERO_BACKDROP


## The screen's own nodes in a side's group (set in PreRoundScreen.tscn).
func _sections(group: StringName) -> Array[CanvasItem]:
	var out: Array[CanvasItem] = []
	if not is_inside_tree():
		return out
	for node in get_tree().get_nodes_in_group(group):
		var item := node as CanvasItem
		if item != null and is_ancestor_of(item):
			out.append(item)
	return out


# --- heroes -----------------------------------------------------------------

func _open_hero_side() -> void:
	config = MatchConfig.from_settings()
	_aggression.value = config.aggression
	_farming.value = config.farming
	_exploration.value = config.exploration
	var tile := get_node(^"%Formations").get_child(clampi(int(config.formation), 0, FORMATION_IDS.size() - 1)) as ChoiceTile
	tile.button_pressed = true
	_refresh_forecast()
	_build_squad()
	_show_quarry(GameManager.ROSTER.find(GameManager.next_quarry()))
	for i in _squad.size():
		_squad[i].cheer(CHEER_STAGGER * i)


func _build_squad() -> void:
	if _squad.is_empty():
		var heroes := GameManager.ROSTER.heroes
		for i in heroes.size():
			var column := VBoxContainer.new()
			column.mouse_filter = Control.MOUSE_FILTER_IGNORE
			column.add_theme_constant_override(&"separation", -16)
			var hero := STAGE_CHARACTER.instantiate() as StageCharacter
			hero.name = String(heroes[i].character_id()).capitalize()
			hero.character = heroes[i]
			hero.flip = i >= heroes.size() / 2.0
			hero.custom_minimum_size = SQUAD_SIZE
			# Runtime-instanced: wired here.
			hero.character_pressed.connect(_on_squad_pressed.bind(hero))
			column.add_child(hero)
			var level := Label.new()
			level.theme_type_variation = &"CardLevel"
			level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			column.add_child(level)
			_squad_row.add_child(column)
			_squad.append(hero)
	for hero in _squad:
		var level := hero.get_parent().get_child(1) as Label
		level.text = tr("Lv.%d") % CharacterProgress.level(hero.character)


## Fills the quarry section for `def` (tonight's quarry).
func _show_quarry(def: CharacterDef) -> void:
	quarry = def
	if def == null:
		return
	_quarry_threat.show_for(MatchRewards.Side.HEROES, def)
	_show_ai_card(_quarry_card, def, _quarry_threat.threat)
	_quarry_name.text = def.get_display_name()
	_quarry_tagline.text = def.tagline
	var slots := def.ability_slots()
	var icons := _quarry_moves.get_children()
	for i in icons.size():
		var ability: AbilityBase = slots[i + 1] if i + 1 < slots.size() else null
		var frame := icons[i] as Control
		frame.visible = ability != null and ability.icon != null
		if frame.visible:
			(frame.get_node(^"Margin/Icon") as TextureRect).texture = ability.icon
			frame.tooltip_text = ability.ability_name
	var fresh := GameManager.is_new_quarry(def.character_id())
	_new_banner.visible = fresh
	if fresh:
		# Sized by its text even before the first layout.
		_new_banner.pivot_offset = _new_banner.get_combined_minimum_size() * 0.5
		_new_banner.scale = BANNER_POP_FROM
		create_tween().tween_property(_new_banner, ^"scale", Vector2.ONE, 0.35) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## An AI opponent's card: "Threat N" and its AI build's ranks out of the full
## (threat-4) build ("AI build 3/12"), whatever the Monster side owns.
static func _show_ai_card(card: CharacterCard, def: CharacterDef, threat: int) -> void:
	var tree_id := MetaSkillManager.monster_tree_id(def.character_id())
	card.character = def
	card.locked_note = ""
	card.apply_ai_build(threat, MetaSkillManager.ai_build_size(tree_id, threat),
			MetaSkillManager.ai_build_size(tree_id, MetaSkillManager.MAX_THREAT))


func _refresh_forecast() -> void:
	var cfg := collect_config()
	_forecast_ult.text = tr("Ultimates fire at %d+ enemies, or when an ally drops below %d%% HP.") % [
		cfg.auto_ult_min_enemies(), roundi(cfg.auto_ult_panic_hp_pct() * 100.0)]
	_forecast_farm.text = tr("Mob camps weigh %d against 100 for the monster.") % roundi(cfg.priority_mob())
	_forecast_scout.text = tr("New targets every %.1f s, scanning %d px ahead, %d px apart.") % [
		cfg.exploration_update_interval(), roundi(cfg.search_radius()), roundi(cfg.formation_spread_px())]


# --- the quarry sheet (Change) ----------------------------------------------

## Slides the quarry sheet up: the pool's monsters to pick, the others as
## silhouettes with the hunts still to play, RANDOM.
func open_sheet() -> void:
	if is_monster():
		return
	_build_sheet()
	_sheet_open = true
	_sheet.visible = true
	_tap_guard.hold(SHEET_TIME)
	_kill_sheet_tween()
	_scrim.modulate.a = 0.0
	_slide.position.y = size.y
	_sheet_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_sheet_tween.tween_property(_scrim, ^"modulate:a", 1.0, SHEET_TIME)
	_sheet_tween.tween_property(_slide, ^"position:y", 0.0, SHEET_TIME)


func close_sheet() -> void:
	if not _sheet_open:
		return
	_sheet_open = false
	_kill_sheet_tween()
	_sheet_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_sheet_tween.tween_property(_scrim, ^"modulate:a", 0.0, SHEET_TIME)
	_sheet_tween.tween_property(_slide, ^"position:y", size.y, SHEET_TIME)
	_sheet_tween.chain().tween_callback(_sheet.hide)


func _close_sheet_now() -> void:
	_kill_sheet_tween()
	_sheet_open = false
	_sheet.visible = false


func _kill_sheet_tween() -> void:
	if _sheet_tween != null:
		_sheet_tween.kill()
		_sheet_tween = null


func _build_sheet() -> void:
	if _sheet_cards.is_empty():
		for def in GameManager.ROSTER.monsters:
			if def == null:
				continue
			var card := CARD_SCENE.instantiate() as CharacterCard
			card.size_preset = CharacterCard.CardSize.S
			card.character = def
			# Runtime-instanced: wired here.
			card.card_pressed.connect(_on_sheet_card_pressed.bind(card))
			_sheet_cards_row.add_child(card)
			_sheet_cards.append(card)
	var pool := GameManager.quarry_pool()
	var threat := _quarry_threat.threat
	for card in _sheet_cards:
		var def := card.character
		if pool.has(def.character_id()):
			_show_ai_card(card, def, threat)
		else:
			card.character = def
			card.locked_note = _hunts_note(GameManager.hunts_until_quarry(def))
			card.apply_progress(1, 0, 0, 0, false)
		card.selected = def == quarry
	var locked := GameManager.locked_quarry()
	_random.disabled = locked == &""
	if locked == &"":
		_lock_state.text = tr("Random pick: never the same quarry twice in a row.")
	else:
		_lock_state.text = tr("%s every hunt, until you pick Random.") % quarry.get_display_name()


## "Appears after 3 hunts" under a silhouette in the quarry sheet.
static func _hunts_note(hunts: int) -> String:
	if hunts == 1:
		return TranslationServer.translate("Appears after 1 hunt")
	return TranslationServer.translate("Appears after %d hunts") % hunts


func _on_sheet_card_pressed(def: CharacterDef, card: CharacterCard) -> void:
	if def == null or not GameManager.quarry_pool().has(def.character_id()):
		_shake(card)
		return
	GameManager.lock_quarry(def.character_id())
	_show_quarry(GameManager.ROSTER.find(GameManager.next_quarry()))
	close_sheet()


# --- monster ----------------------------------------------------------------

func _open_monster_side() -> void:
	instinct = DEFAULT_INSTINCT
	(%Ambusher as ChoiceTile).button_pressed = true
	_build_picker()
	_show_monster(GameManager.ROSTER.find(GameManager.played_monster_id()))


func _build_picker() -> void:
	if _picker_cards.is_empty():
		for def in GameManager.ROSTER.monsters:
			if def != null:
				_picker_cards.append(_make_picker_card(def))
		var rumour := _make_picker_card(null)
		rumour.rumour = true
		rumour.monster_side = true
		_picker_cards.append(rumour)
	for card in _picker_cards:
		card.refresh()


func _make_picker_card(def: CharacterDef) -> CharacterCard:
	var card := CARD_SCENE.instantiate() as CharacterCard
	card.size_preset = CharacterCard.CardSize.S
	card.character = def
	# Runtime-instanced: wired here.
	card.card_pressed.connect(_on_picker_card_pressed.bind(card))
	_picker.add_child(card)
	return card


## Shows `def` (an owned monster) as the picked one: big in the lair, its
## plaque, its evolution strip and the threat; its picker card selected.
func _show_monster(def: CharacterDef) -> void:
	monster = def
	if def == null:
		return
	for card in _picker_cards:
		card.selected = card.character == def and not card.rumour
	_big_monster.character = def
	_monster_name.text = "%s  ·  %s" % [def.get_display_name(), tr("Lv.%d") % CharacterProgress.level(def)]
	_monster_role.text = def.role_text
	for i in _evolution.size():
		_evolution[i].character = def
		_evolution[i].stage = i + 1
		var numeral: String = tr("Stage %s") % STAGE_NUMERALS[i]
		var stage_name := def.stage_name(i + 1)
		_evolution_names[i].text = numeral if stage_name.is_empty() else "%s\n%s" % [numeral, stage_name]
	_monster_threat.show_for(MatchRewards.Side.MONSTER, def)


## The save changed (a purchase on the unlock sheet): the picker re-reads
## what is owned and shows the player's own monster (the one just bought).
func refresh() -> void:
	if not is_monster():
		return
	for card in _picker_cards:
		card.refresh()
	_show_monster(GameManager.ROSTER.find(GameManager.played_monster_id()))


## True when a locked `def` can be bought right now (its rule is met; the
## sheet shows whether the wallet covers it).
static func is_buyable(def: CharacterDef) -> bool:
	var state := CharacterProgress.unlock_state(def)
	return state == CharacterProgress.UnlockState.READY or state == CharacterProgress.UnlockState.SHORT


func _on_picker_card_pressed(def: CharacterDef, card: CharacterCard) -> void:
	if def != null and not CharacterProgress.is_unlocked(def) and is_buyable(def):
		character_requested.emit(def)
		return
	if def == null or not CharacterProgress.is_unlocked(def):
		_shake(card)
		return
	if def != monster:
		GameManager.choose_monster(def.character_id())
		_show_monster(def)
	_big_monster.cheer()


# --- shared -----------------------------------------------------------------

## A card that picks nothing shakes side to side.
func _shake(card: Control) -> void:
	var x := card.position.x
	var t := card.create_tween()
	for dx: float in [SHAKE_PX, -SHAKE_PX, SHAKE_PX, -SHAKE_PX, 0.0]:
		t.tween_property(card, ^"position:x", x + dx, SHAKE_STEP)


func _unhandled_input(event: InputEvent) -> void:
	if _sheet_open and is_visible_in_tree() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close_sheet()


# --- scene-side connections (PreRoundScreen.tscn) ---

func _on_top_bar_left_pressed() -> void:
	cancelled.emit()


func _on_aggression_changed(v: float) -> void:
	collect_config().aggression = v
	_config_changed()


func _on_farming_changed(v: float) -> void:
	collect_config().farming = v
	_config_changed()


func _on_exploration_changed(v: float) -> void:
	collect_config().exploration = v
	_config_changed()


func _on_formation_chosen(choice_id: StringName) -> void:
	var formation := FORMATION_IDS.find(choice_id)
	if formation < 0 or formation == int(collect_config().formation):
		return
	collect_config().formation = formation as MatchConfig.Formation
	_config_changed()


## A dial or the formation changed: the settings hold it at once; the file is
## written when the screen is left (_on_hidden) or the hunt starts.
func _config_changed() -> void:
	collect_config().store()
	_config_unsaved = true
	_refresh_forecast()


## The screen was left (back, a nav tab; MenuRoot hides it once it has slid
## out): the strategy changed on this visit goes to the save file.
func _on_hidden() -> void:
	if _config_unsaved:
		_config_unsaved = false
		PersistedData.save_data()


func _on_instinct_chosen(choice_id: StringName) -> void:
	instinct = choice_id


func _on_change_pressed() -> void:
	open_sheet()


func _on_quarry_card_pressed(_def: CharacterDef) -> void:
	open_sheet()


func _on_random_pressed() -> void:
	GameManager.lock_quarry(&"")
	_show_quarry(GameManager.ROSTER.find(GameManager.next_quarry()))
	close_sheet()


func _on_sheet_close_pressed() -> void:
	close_sheet()


func _on_scrim_gui_input(event: InputEvent) -> void:
	var tap := event as InputEventMouseButton
	if tap != null and tap.pressed and tap.button_index == MOUSE_BUTTON_LEFT:
		close_sheet()


func _on_hero_start_pressed() -> void:
	if _started:
		return
	_started = true
	var cfg := collect_config()
	cfg.save_to_settings()
	_config_unsaved = false
	AnalyticsSink.track(&"pre_round_setup", {
		"aggression": cfg.aggression, "farming": cfg.farming,
		"exploration": cfg.exploration, "formation": int(cfg.formation),
		"quarry": String(cfg.quarry_id),
	})
	start_requested.emit(cfg)


func _on_monster_start_pressed() -> void:
	if monster == null or _started:
		return
	_started = true
	AnalyticsSink.track(&"pre_round_monster", {
		"monster": String(monster.character_id()), "instinct": String(instinct),
	})
	monster_start_requested.emit(monster.character_id(), instinct)


func _on_squad_pressed(_def: CharacterDef, hero: StageCharacter) -> void:
	hero.cheer()
