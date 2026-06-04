extends Control
class_name MetaSkillScreen

## MetaSkillScreen — full-screen panel for browsing + spending currency on
## permanent upgrades. Built dynamically from MetaSkillManager's registered
## trees so adding new trees (or new nodes within them) requires zero UI
## scene editing.

@onready var tree_picker: OptionButton = %TreePicker
@onready var tiers_box: VBoxContainer = %TiersBox
@onready var title_label: Label = %TitleLabel
@onready var description_label: Label = %DescriptionLabel
@onready var currency_label: Label = %CurrencyLabel
@onready var close_button: Button = %CloseButton

# Currently-displayed tree.
var active_tree_id: StringName = &""

# Ordered list of tree ids matching tree_picker indices.
var _tree_ids: Array[StringName] = []


func _ready() -> void:
	# close_button.pressed and tree_picker.item_selected are connected
	# scene-side (see [connection] entries in MetaSkillScreen.tscn).
	# Autoload signals stay code-side — autoloads can't be referenced
	# from scene [connection] entries.
	MetaSkillManager.skills_changed.connect(_refresh_currency_and_nodes)
	PersistedData.currency_changed.connect(_on_currency_changed)

	_populate_tree_picker()


# ============================================
# Tree picker (top-of-screen dropdown — pick Hero Base / Monster Base)
# ============================================

func _populate_tree_picker() -> void:
	tree_picker.clear()
	_tree_ids.clear()
	for tree_id in MetaSkillManager.trees.keys():
		# Dictionary access is Variant — cast for the typed local.
		var t: MetaSkillTree = MetaSkillManager.trees[tree_id] as MetaSkillTree
		if t == null:
			continue
		tree_picker.add_item(t.display_name)
		_tree_ids.append(tree_id)
	if _tree_ids.size() > 0:
		tree_picker.select(0)
		_show_tree(_tree_ids[0])


func _on_tree_picker_selected(idx: int) -> void:
	if idx >= 0 and idx < _tree_ids.size():
		_show_tree(_tree_ids[idx])


# ============================================
# Tree rendering
# ============================================

func _show_tree(tree_id: StringName) -> void:
	active_tree_id = tree_id
	var t: MetaSkillTree = MetaSkillManager.get_tree_def(tree_id)
	if t == null:
		return

	title_label.text = t.display_name
	description_label.text = t.description
	_refresh_currency_label()

	# Wipe + rebuild the tier rows. Cheap; we only do this on tree switch.
	for c in tiers_box.get_children():
		c.queue_free()

	# Render tiers top-down (highest tier at the top — matches typical
	# skill-tree UX where T4 is "endgame" up high).
	var max_t: int = t.max_tier()
	for tier in range(max_t, 0, -1):
		_build_tier_row(t, tier)


func _build_tier_row(t: MetaSkillTree, tier: int) -> void:
	var row_panel := PanelContainer.new()
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tiers_box.add_child(row_panel)

	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	row_panel.add_child(inner)

	var tier_label := Label.new()
	tier_label.text = "T%d" % tier
	tier_label.custom_minimum_size = Vector2(40, 0)
	tier_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tier_label.add_theme_font_size_override("font_size", 20)
	inner.add_child(tier_label)

	for n in t.nodes_in_tier(tier):
		var btn := MetaSkillNodeButton.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner.add_child(btn)
		btn.bind(t.id, n)
		btn.unlock_requested.connect(_on_unlock_requested)


# ============================================
# Click → unlock
# ============================================

func _on_unlock_requested(tree_id: StringName, node_id: StringName) -> void:
	# MetaSkillManager handles the validate + spend + persist. We just
	# refresh the visuals; the skills_changed signal also fires.
	MetaSkillManager.unlock(tree_id, node_id)


func _refresh_currency_and_nodes() -> void:
	_refresh_currency_label()
	# Re-evaluate every visible node's state (unlocked → tier 2 buttons
	# may become available, etc.).
	for row in tiers_box.get_children():
		_refresh_buttons_under(row)


func _refresh_buttons_under(node: Node) -> void:
	for child in node.get_children():
		if child is MetaSkillNodeButton:
			(child as MetaSkillNodeButton).refresh()
		elif child.get_child_count() > 0:
			_refresh_buttons_under(child)


func _on_currency_changed(_currency: StringName, _new_amount: int) -> void:
	_refresh_currency_label()


func _refresh_currency_label() -> void:
	currency_label.text = "Steel %d   Leaves %d   Gold %d" % [
		PersistedData.get_currency(PersistedData.STEEL),
		PersistedData.get_currency(PersistedData.LEAVES),
		PersistedData.get_currency(PersistedData.GOLD),
	]


# ============================================
# Close → back to main menu
# ============================================

func _on_close_pressed() -> void:
	# This screen lives as a child of MainMenu, so just free ourselves.
	# (When it ships as a standalone scene, swap for change_scene_to_packed.)
	queue_free()
