extends Control
## Proof sheet of the HUD cooldown widget (Scenes/UI/Hud/AbilitySlot.tscn):
## rows of AbilitySlots bound to scripted CooldownSources on HudPanels, so no
## match is needed and every render looks the same. Not shipped (tools/).
##   - Grount, Stage I (72 px): Front Cleave looping, Ram Dash counting down,
##     Ground Slam locked "II", the passive frame;
##   - Vlad (72 px): the basic attack in tenths, Land Mine, Blood Bomb coming
##     ready at 1.2 s (flash, pop, then the ultimate's glow), Bloodlust;
##   - River (72 px): the basic-attack icon swapping rifle / staff every
##     second (weapon mode), Supply Drop ready from the start (glows, no pop);
##   - Grount evolving at 1.0 s (112 px): Ground Slam unlocks and pops;
##   - Vlad at the hero card's size (52 px).
## Render muted on a copy of the project:
##   godot --path <copy> --audio-driver Dummy --fixed-fps 30 --resolution 720x1280
##         --write-movie <dir>/f.png --quit-after 90 res://tools/preview/SlotStrip.tscn

const SLOT := preload("res://Scenes/UI/Hud/AbilitySlot.tscn")
const ICONS := "res://Assets/UI/Icons/Abilities/%s.svg"
const BASIC := AbilityBase.AbilityType.BASIC_ATTACK
const ACTIVE := AbilityBase.AbilityType.ACTIVE
const ULT := AbilityBase.AbilityType.ULTIMATE
const PASSIVE := AbilityBase.AbilityType.PASSIVE


## One scripted slot.
class Spec:
	var icon: Texture2D
	## Shown instead of `icon` every other second (River's weapon swap).
	var alt_icon: Texture2D = null
	var kind: AbilityBase.AbilityType
	## Cooldown length in seconds; 0 never cools down (a passive).
	var total: float = 0.0
	## Seconds left at t = 0.
	var left: float = 0.0
	## Recast the moment it is ready (a basic attack).
	var loops: bool = false
	## Locked while t is below this (INF: stays locked).
	var locked_until: float = 0.0
	var hint: String = ""

	func _init(icon_id: String, p_kind: AbilityBase.AbilityType, p_total: float = 0.0, p_left: float = 0.0) -> void:
		icon = load(ICONS % icon_id) as Texture2D
		kind = p_kind
		total = p_total
		left = p_left


## A CooldownSource over Specs and the strip's clock.
class StripSource extends CooldownSource:
	var specs: Array[Spec] = []
	var t: float = 0.0

	func is_valid() -> bool:
		return true

	func slot_count() -> int:
		return specs.size()

	func slot_type(slot: int) -> AbilityBase.AbilityType:
		return specs[slot].kind

	func icon(slot: int) -> Texture2D:
		var s := specs[slot]
		if s.alt_icon != null and fmod(t, 2.0) >= 1.0:
			return s.alt_icon
		return s.icon

	func remaining(slot: int) -> float:
		var s := specs[slot]
		if s.total <= 0.0:
			return 0.0
		var left := s.left - t
		if s.loops:
			left = fposmod(left, s.total)
		return maxf(left, 0.0)

	func progress(slot: int) -> float:
		var s := specs[slot]
		if s.total <= 0.0:
			return 1.0
		return 1.0 - remaining(slot) / s.total

	func locked(slot: int) -> bool:
		return t < specs[slot].locked_until

	func lock_hint(slot: int) -> String:
		return specs[slot].hint


var _sources: Array[StripSource] = []
var _t: float = 0.0

@onready var _list: VBoxContainer = %List


func _ready() -> void:
	(%Background as ColorRect).color = UiPalette.get_default().bg_base
	_list.add_child(_label("AbilitySlot  ·  CooldownSource", &"HeaderSmall"))
	_add_panel("Grount  ·  Stage I", &"MonsterAccentLabel", _grount(INF), 72.0,
			"Front Cleave loops (2.5 s), Ram Dash 12 s, Ground Slam locked until II")
	_add_panel("Vlad", &"HeroAccentLabel", _vlad(), 72.0,
			"Blood Bomb comes ready at 1.2 s: flash, pop, glow")
	_add_panel("River", &"HeroAccentLabel", _river(), 72.0,
			"Basic attack follows the weapon mode; Supply Drop starts ready")
	_add_panel("Grount evolves at 1.0 s", &"MonsterAccentLabel", _grount(1.0), 112.0,
			"Ground Slam unlocks into ready: pop and glow")
	_add_panel("Vlad  ·  hero card size", &"HeroAccentLabel", _vlad(), 52.0, "")


func _process(delta: float) -> void:
	# The strip runs before its slots (tree order), so they poll this frame's t.
	_t += delta
	for s in _sources:
		s.t = _t


func _grount(unlock_at: float) -> StripSource:
	var src := StripSource.new()
	var cleave := Spec.new("grount_front_cleave", BASIC, 2.5, 1.7)
	cleave.loops = true
	var slam := Spec.new("grount_ground_slam", ULT, 15.0)
	slam.locked_until = unlock_at
	slam.hint = CooldownSource.STAGE_NUMERALS[2]
	src.specs = [cleave, Spec.new("grount_ram_dash", ACTIVE, 12.0, 7.4), slam,
			Spec.new("grount_passive_evolution", PASSIVE)]
	return src


func _vlad() -> StripSource:
	var src := StripSource.new()
	var strike := Spec.new("vlad_basic_blood_strike", BASIC, 1.0, 0.9)
	strike.loops = true
	src.specs = [strike, Spec.new("vlad_active_land_mine", ACTIVE, 8.0, 5.6),
			Spec.new("vlad_ult_blood_bomb", ULT, 20.0, 1.2), Spec.new("vlad_passive_bloodlust", PASSIVE)]
	return src


func _river() -> StripSource:
	var src := StripSource.new()
	var basic := Spec.new("river_basic_sniper", BASIC, 1.1, 0.4)
	basic.loops = true
	basic.alt_icon = load(ICONS % "river_basic_heal") as Texture2D
	src.specs = [basic, Spec.new("river_active_weapon_swap", ACTIVE, 1.0, 0.0),
			Spec.new("river_ult_supply_drop", ULT, 25.0), Spec.new("river_passive_adaptive_movement", PASSIVE)]
	return src


func _add_panel(title: String, variation: StringName, source: StripSource, slot_size: float, note: String) -> void:
	_sources.append(source)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"HudPanel"
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 6)
	panel.add_child(col)
	col.add_child(_label(title, variation))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", roundi(slot_size * 0.22))
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	for i in source.slot_count():
		var slot := SLOT.instantiate() as AbilitySlot
		slot.custom_minimum_size = Vector2(slot_size, slot_size)
		slot.bind(source, i)
		row.add_child(slot)
	if not note.is_empty():
		col.add_child(_label(note, &"Caption"))
	_list.add_child(panel)


func _label(text: String, variation: StringName) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
