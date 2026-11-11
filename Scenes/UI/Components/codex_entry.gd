class_name CodexEntry
extends PanelContainer

## One page of the Codex: a character's portrait, name, role and tagline,
## its field notes (CharacterDef.codex_notes), for a monster its evolution
## stages (CharacterDef.stage_names) and counterplay (CharacterDef.tip), and
## its abilities with their descriptions (the scene's own ability resources,
## CharacterDef.abilities(): read, never modified).
## A monster the hunters have not met yet is a locked page: the portrait as a
## silhouette (CharacterCard's locked material), "???" and a note on when it
## turns up; nothing else is shown. The look is theme variations only
## (CharacterCard / CharacterCardMonster / CharacterCardLocked, CardInner*,
## HeaderSmall, Caption, BodyDim, ChipPanel, HintLabel); CodexEntry.tscn
## holds the layout, the ability rows are built here.

## The character shown (show_entry()).
var character: CharacterDef = null
## True when the page is open (met or a hero), false for a locked page.
var met: bool = false

@onready var _portrait_frame: PanelContainer = %PortraitFrame
@onready var _portrait: TextureRect = %Portrait
@onready var _name: Label = %Name
@onready var _role: Label = %Role
@onready var _tagline: Label = %Tagline
@onready var _notes_box: Control = %NotesBox
@onready var _notes: Label = %Notes
@onready var _stages_box: Control = %StagesBox
@onready var _stages: HBoxContainer = %Stages
@onready var _counter_box: Control = %CounterBox
@onready var _counter: Label = %Counter
@onready var _abilities_box: Control = %AbilitiesBox
@onready var _abilities: VBoxContainer = %Abilities


## Shows `def`'s page; `is_met` false shows it locked with `note` under "???".
func show_entry(def: CharacterDef, is_met: bool, note: String = "") -> void:
	character = def
	met = is_met
	if not is_node_ready():
		await ready
	var monster := def != null and def.is_monster()
	if not is_met:
		theme_type_variation = &"CharacterCardLocked"
	else:
		theme_type_variation = &"CharacterCardMonster" if monster else &"CharacterCard"
	_portrait_frame.theme_type_variation = &"CardInnerMonster" if monster else &"CardInnerHero"
	_portrait.texture = def.portrait if def != null else null
	_portrait.material = null if is_met else CharacterCard.locked_material()
	_name.text = def.get_display_name() if is_met and def != null else "???"
	_role.text = def.role_text if def != null else ""
	_role.visible = is_met
	_tagline.text = (def.tagline if def != null else "") if is_met else note
	var shown := is_met and def != null
	_notes.text = def.codex_notes if shown else ""
	_notes_box.visible = shown and not def.codex_notes.is_empty()
	_stages_box.visible = shown and monster and not def.stage_names.is_empty()
	if _stages_box.visible:
		_fill_stages(def)
	_counter.text = def.tip if shown else ""
	_counter_box.visible = shown and monster and not def.tip.is_empty()
	_fill_abilities(def if shown else null)


## The ability rows shown (name labels), in menu order.
func ability_names() -> PackedStringArray:
	var out := PackedStringArray()
	for row in _abilities.get_children():
		out.append((row.get_node(^"Text/Name") as Label).text)
	return out


## The evolution stage chips' texts ("I · Bullcalf").
func stage_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for chip in _stages.get_children():
		out.append((chip.get_node(^"Label") as Label).text)
	return out


func _fill_stages(def: CharacterDef) -> void:
	_clear(_stages)
	for i in def.stage_names.size():
		var chip := PanelContainer.new()
		chip.theme_type_variation = &"ChipPanel"
		var label := Label.new()
		label.name = "Label"
		label.theme_type_variation = &"BodyDim"
		label.text = "%s · %s" % [CooldownSource.STAGE_NUMERALS[clampi(i + 1, 1, CooldownSource.STAGE_NUMERALS.size() - 1)], tr(def.stage_names[i])]
		chip.add_child(label)
		_stages.add_child(chip)


func _fill_abilities(def: CharacterDef) -> void:
	_clear(_abilities)
	var list: Array[AbilityBase] = []
	if def != null:
		list = def.abilities()
	_abilities_box.visible = not list.is_empty()
	for ability in list:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 12)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(48, 48)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		icon.texture = ability.get_display_icon()
		row.add_child(icon)
		var text := VBoxContainer.new()
		text.name = "Text"
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override(&"separation", 2)
		var ability_name := Label.new()
		ability_name.name = "Name"
		ability_name.text = ability.ability_name
		text.add_child(ability_name)
		var description := Label.new()
		description.theme_type_variation = &"HintLabel"
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.text = ability.description
		text.add_child(description)
		row.add_child(text)
		_abilities.add_child(row)


static func _clear(box: Node) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
