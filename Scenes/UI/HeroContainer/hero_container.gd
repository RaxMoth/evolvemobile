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
##
## Panels live as long as the roster. A dead hero's panel stays (its HP bar
## shows the death) but can no longer be focused: when the followed hero
## dies, the focus moves on to the next living hero so the camera does not
## stay behind at the death spot.

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
	_build_panels_for_heroes()
	EventBus.entity_died.connect(_on_entity_died)


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
	panel.selected.connect(select_hero)
	panels.append(panel)


func _set_active_panel(panel: HeroPanel) -> void:
	for p in panels:
		if p == panel:
			p.set_active(true)
			active_hero = p.hero
		else:
			p.set_active(false)


## A panel can take the focus while its hero lives. A hero that just died is
## still a valid instance until the end of the frame (queue_free), so the
## liveness check matters too.
func _is_selectable(p: HeroPanel) -> bool:
	return is_instance_valid(p.hero) and (p.hero as EntityBase).is_alive()


## EventBus.entity_died. Only the followed hero's death matters here: the
## active hero is always a roster hero, so mobs, the monster and Ted's pet
## (no panel) return early.
func _on_entity_died(entity: Node, _killer: Node) -> void:
	if entity == null or entity != active_hero:
		return
	cycle_to_next_hero()


# ============================================
# Public API (used by MainCam to drive the panel from key bindings)
# ============================================

## Focus `hero` (panel click, 1-4 keys, tap, minimap). A dead hero is ignored.
func select_hero(hero: Node) -> void:
	for p in panels:
		if p.hero == hero:
			if _is_selectable(p):
				_set_active_panel(p)
				hero_selected.emit(hero)
			return


## Tab: focus the next living hero after the active one, in roster order.
## Does nothing when no hero is alive.
func cycle_to_next_hero() -> void:
	var count := panels.size()
	var current := -1
	for i in count:
		if panels[i].hero == active_hero:
			current = i
			break
	# From current + 1 round to current itself (from panel 0 without a match).
	for step in range(1, count + 1):
		var p := panels[(current + step) % count]
		if _is_selectable(p):
			_set_active_panel(p)
			hero_selected.emit(p.hero)
			return
