class_name ChoiceTile
extends Button

## One tile of a one-of-N choice on the pre-round screen: a formation
## (FormationTile.tscn: a FormationGlyph over the title) or a monster instinct
## (InstinctTile.tscn: an icon, the title and a one-line description). The
## tiles of one choice share a ButtonGroup set in the screen's scene.
## The picked tile shows the amber CharacterCardSelected frame and an amber
## title (`monster`: the crimson CharacterCardMonster frame), the others the
## copper CharacterCard frame. chosen(choice_id) fires when this tile becomes
## the picked one; set `button_pressed` to pick it from code (the group
## unpicks the others). Its own button signals are wired in its scene.

signal chosen(choice_id: StringName)

## What the tile stands for (the screen maps it to its value).
@export var choice_id: StringName = &""
@export var title: String = "":
	set(v):
		title = v
		if is_node_ready():
			_apply()
@export_multiline var description: String = "":
	set(v):
		description = v
		if is_node_ready():
			_apply()
@export var icon_texture: Texture2D:
	set(v):
		icon_texture = v
		if is_node_ready():
			_apply()
## Monster-side tile: the crimson frame when picked, the title stays white.
@export var monster: bool = false:
	set(v):
		monster = v
		if is_node_ready():
			_show_picked(button_pressed)
## The MatchConfig.Formation the tile's FormationGlyph draws (-1: no glyph).
@export_enum("None:-1", "Tight:0", "Spread:1", "Line:2") var glyph_formation: int = -1:
	set(v):
		glyph_formation = v
		if is_node_ready():
			_apply()

@onready var _frame: Panel = %Frame
@onready var _title: Label = %Title


func _ready() -> void:
	_apply()
	_show_picked(button_pressed)


func _apply() -> void:
	_title.text = title
	var desc := get_node_or_null(^"%Desc") as Label
	if desc != null:
		desc.text = description
		desc.visible = not description.is_empty()
	var icon_rect := get_node_or_null(^"%Icon") as TextureRect
	if icon_rect != null:
		icon_rect.texture = icon_texture
	var glyph := get_node_or_null(^"%Glyph") as FormationGlyph
	if glyph != null:
		glyph.visible = glyph_formation >= 0
		if glyph_formation >= 0:
			glyph.formation = glyph_formation as MatchConfig.Formation


func _show_picked(on: bool) -> void:
	var picked: StringName = &"CharacterCardMonster" if monster else &"CharacterCardSelected"
	_frame.theme_type_variation = picked if on else &"CharacterCard"
	_title.theme_type_variation = &"AmberLabel" if on and not monster else &"Counter"


# --- scene-side connections (FormationTile.tscn / InstinctTile.tscn) ---

## A scene that picks the tile (button_pressed) toggles it while it is still
## being built: _ready shows that, and nobody listens yet.
func _on_toggled(on: bool) -> void:
	if not is_node_ready():
		return
	_show_picked(on)
	if on:
		chosen.emit(choice_id)


func _on_button_down() -> void:
	PressFeedback.down(self)


func _on_button_up() -> void:
	PressFeedback.up(self)
