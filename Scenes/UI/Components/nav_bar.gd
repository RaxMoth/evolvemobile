class_name NavBar
extends Control

## Bottom navigation of the meta screens: Heroes | Growth | HUNT arch | Codex |
## Monsters. The tabs (toggle buttons, NavBar.tscn) share one ButtonGroup per
## bar, so exactly one is lit; screens connect tab_selected scene-side and the
## menu root swaps screens. The arch glows in the chosen side's colour, and any tab
## can carry the red notify dot (notify_tabs: affordable upgrades, new codex
## entries). Every bar is in the GROUP group (NavBar.tscn): MenuRoot lights the
## Heroes, Monsters and Growth dots on all of them while ranks can be bought.

signal tab_selected(tab_id: StringName)

const GROUP := &"nav_bar"

@export var active_tab: StringName = &"hunt":
	set(v):
		active_tab = v
		if is_node_ready():
			_apply_active()
## Monster side chosen: the arch glows crimson instead of amber.
@export var monster_side: bool = false:
	set(v):
		monster_side = v
		if is_node_ready():
			_apply_side()
## Tabs showing the red notify dot.
@export var notify_tabs: Array[StringName] = []:
	set(v):
		notify_tabs = v
		if is_node_ready():
			_apply_notify()

## This bar's group. Made here, not as a scene sub-resource: a local-to-scene
## ButtonGroup set on the instanced tabs gives every tab its own copy.
var group := ButtonGroup.new()


func _ready() -> void:
	for t in tabs():
		t.button_group = group
	_apply_active()
	_apply_side()
	_apply_notify()


## Every tab, in bar order (the arch included).
func tabs() -> Array[NavTab]:
	var out: Array[NavTab] = []
	for c in %Tabs.get_children():
		if c is NavTab:
			out.append(c as NavTab)
	return out


func tab(id: StringName) -> NavTab:
	for t in tabs():
		if t.tab_id == id:
			return t
	return null


## Shows or hides one tab's notify dot.
func set_notify(id: StringName, on: bool) -> void:
	var ids: Array[StringName] = notify_tabs.duplicate()
	if on and not ids.has(id):
		ids.append(id)
	elif not on:
		ids.erase(id)
	notify_tabs = ids


func _apply_active() -> void:
	for t in tabs():
		t.set_pressed_no_signal(t.tab_id == active_tab)


func _apply_side() -> void:
	var palette := UiPalette.get_default()
	(%Arch as NavArch).glow_color = palette.monster if monster_side else palette.amber


func _apply_notify() -> void:
	for t in tabs():
		t.notify = notify_tabs.has(t.tab_id)


func _on_tab_chosen(tab_id: StringName) -> void:
	active_tab = tab_id
	tab_selected.emit(tab_id)
