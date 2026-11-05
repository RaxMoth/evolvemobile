extends Button
class_name MetaSkillNodeButton

## MetaSkillNodeButton — one clickable card for a MetaSkillNode.
## Owned by MetaSkillScreen, which creates one per node in the active tree.

signal unlock_requested(tree_id: StringName, node_id: StringName)

# State colors. Tweak in the inspector via theme overrides if you want
# different visual language per tree.
const COLOR_UNLOCKED   := Color(0.40, 0.85, 0.40)  # green
const COLOR_AVAILABLE  := Color(0.95, 0.85, 0.30)  # gold
const COLOR_LOCKED     := Color(0.45, 0.45, 0.50)  # gray
const COLOR_TIER_GATED := Color(0.30, 0.30, 0.35)  # dark gray

var tree_id: StringName = &""
var node_def: MetaSkillNode = null
var _label: RichTextLabel = null


func bind(p_tree_id: StringName, p_node: MetaSkillNode) -> void:
	tree_id = p_tree_id
	node_def = p_node
	if not is_inside_tree():
		await ready
	# 130 px: 4 cards per line must fit the 672 px inside the 720 px portrait
	# screen's margins (40 + 4 x 130 + 4 x 12 = 608); bigger tiers (Grount T3)
	# wrap onto a second line (MetaSkillScreen's HFlowContainer).
	custom_minimum_size = Vector2(130, 90)
	# Replace the default button text with a RichTextLabel child so we can
	# show a multi-line stack: name / description / cost.
	if _label == null:
		_label = RichTextLabel.new()
		_label.bbcode_enabled = true
		_label.fit_content = true
		_label.scroll_active = false
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_label.offset_left = 8
		_label.offset_top = 8
		_label.offset_right = -8
		_label.offset_bottom = -8
		add_child(_label)
	text = ""  # we draw text via the RichTextLabel
	refresh()

	# Only connect pressed → emit once; bind() can be re-called on refresh.
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)


func refresh() -> void:
	## Re-evaluate state from MetaSkillManager and PersistedData and update visuals.
	if node_def == null or _label == null:
		return

	var state := MetaSkillManager.node_state(tree_id, node_def.id)

	# Disable click for everything except "available". Unlocked nodes are
	# already bought; tier-gated, unaffordable and invalid ones are not purchasable.
	disabled = state != MetaSkillManager.NodeState.AVAILABLE

	# Background color (modulate the whole button) and the status line under
	# name / description.
	var status_line: String = ""
	match state:
		MetaSkillManager.NodeState.UNLOCKED:
			modulate = COLOR_UNLOCKED
			status_line = "[color=#063]Unlocked[/color]"
		MetaSkillManager.NodeState.TIER_GATED:
			modulate = COLOR_TIER_GATED
			status_line = "[color=#777]Reach Tier %d first[/color]" % (node_def.tier - 1)
		_:
			# AVAILABLE, UNAFFORDABLE or INVALID: show the price.
			var available := state == MetaSkillManager.NodeState.AVAILABLE
			modulate = COLOR_AVAILABLE if available else COLOR_LOCKED
			var have: int = PersistedData.get_currency(node_def.currency)
			var color_tag := "#063" if available else "#933"
			status_line = "[color=%s]%d / %d %s[/color]" % [color_tag, have, node_def.cost, tr(String(node_def.currency).capitalize())]

	_label.text = "[b]%s[/b]\n[font_size=11]%s[/font_size]\n%s" % [node_def.display_name, node_def.description, status_line]


func _on_pressed() -> void:
	if node_def == null:
		return
	unlock_requested.emit(tree_id, node_def.id)
