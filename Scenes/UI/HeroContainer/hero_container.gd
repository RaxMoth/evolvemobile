extends Control
class_name HeroContainer

## HeroContainer - the bottom-of-screen hero roster.
##
## Dynamically creates one HeroPanel per hero in the scene. Click a panel
## to switch the camera focus to that hero. The active panel stays
## highlighted; the rest are dimmed.
##
## This replaces the old approach of four hardcoded panel duplicates in the
## .tscn — heroes are discovered via the "Hero" group at runtime, so adding
## a fifth/sixth hero is a zero-edit change to this scene.

signal hero_selected(hero: Node)

const HERO_PANEL_SCENE: PackedScene = preload("res://Scenes/UI/HeroContainer/HeroPanel.tscn")

@onready var hero_box: HBoxContainer = $MarginContainer/HeroHBoxContainer

var panels: Array[HeroPanel] = []
var active_hero: Node = null


func _ready() -> void:
	# When the player chose to play as the Monster, the hero roster panel
	# is meaningless — hide the whole thing. (Phase 3 will replace this
	# with a monster-side ability bar.)
	if GameManager.chosen_side == MatchRewards.Side.MONSTER:
		visible = false
		return

	# Two frames so heroes have time to finish their own _ready (which awaits
	# physics frames) before we try to read their stats.
	await get_tree().process_frame
	await get_tree().process_frame
	_clear_existing_panels()
	_build_panels_for_heroes()


func _clear_existing_panels() -> void:
	for child in hero_box.get_children():
		child.queue_free()
	panels.clear()


func _build_panels_for_heroes() -> void:
	var heroes := get_tree().get_nodes_in_group("Hero")
	for hero in heroes:
		# Filter to actual HeroBase nodes (skip Ted's pet which is also in
		# the Hero group but isn't a HeroBase).
		if not (hero is HeroBase):
			continue
		_add_panel_for_hero(hero)

	# Auto-activate the first panel so there's always a visible focus.
	if panels.size() > 0:
		_set_active_panel(panels[0])


func _add_panel_for_hero(hero: Node) -> void:
	var panel: HeroPanel = HERO_PANEL_SCENE.instantiate()
	hero_box.add_child(panel)
	panel.bind_to_hero(hero)
	panel.selected.connect(_on_panel_selected)
	panels.append(panel)
	# Clean up our tracking if a hero dies and the panel is freed.
	panel.tree_exiting.connect(_on_panel_exiting.bind(panel))


func _on_panel_selected(hero: Node) -> void:
	# Find the panel for this hero so we can highlight it.
	for p in panels:
		if p.hero == hero:
			_set_active_panel(p)
			break
	hero_selected.emit(hero)


func _set_active_panel(panel: HeroPanel) -> void:
	for p in panels:
		if p == panel:
			p.set_active(true)
			active_hero = p.hero
		else:
			p.set_active(false)


func _on_panel_exiting(panel: HeroPanel) -> void:
	panels.erase(panel)
	if active_hero != null and not is_instance_valid(active_hero):
		# Active hero died — fall back to first surviving panel.
		active_hero = null
		if panels.size() > 0:
			_set_active_panel(panels[0])


# ============================================
# Public API (used by MainCam to drive the panel from key bindings)
# ============================================

func select_hero(hero: Node) -> void:
	for p in panels:
		if p.hero == hero:
			_set_active_panel(p)
			hero_selected.emit(hero)
			return


func cycle_to_next_hero() -> void:
	if panels.is_empty():
		return
	var idx := 0
	for i in panels.size():
		if panels[i].hero == active_hero:
			idx = (i + 1) % panels.size()
			break
	_set_active_panel(panels[idx])
	hero_selected.emit(panels[idx].hero)
