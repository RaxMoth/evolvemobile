extends ColorRect
## Proof sheet of the runtime palette: one labelled swatch per UiPalette token
## (palette.tres), in palette order, under its palette.py group title. Reads
## the palette itself, so it can never drift from it. Not shipped (tools/).
## Render muted on a copy of the project:
##   godot --path <copy> --audio-driver Dummy --fixed-fps 30
##         --write-movie <dir>/f.png --quit-after 8 res://tools/preview/PaletteSheet.tscn

const SWATCH_SIZE := Vector2(92, 24)

@onready var _flow: HFlowContainer = $Margin/Flow


func _ready() -> void:
	var palette := UiPalette.get_default()
	color = palette.bg_base
	# get_property_list() lists each @export_group entry before its tokens;
	# a group title is shown once its first colour token arrives.
	var group_title := ""
	var shown_title := ""
	for prop: Dictionary in palette.get_property_list():
		var usage: int = prop["usage"]
		if usage & PROPERTY_USAGE_GROUP:
			group_title = str(prop["name"])
		elif usage & PROPERTY_USAGE_CATEGORY:
			group_title = ""
		elif prop["type"] == TYPE_COLOR and usage & PROPERTY_USAGE_STORAGE:
			if group_title != shown_title:
				_flow.add_child(_header(group_title))
				shown_title = group_title
			var token := StringName(prop["name"])
			_flow.add_child(_swatch(token, palette.color(token), palette))


func _header(title: String) -> Label:
	var h := Label.new()
	h.text = title
	h.theme_type_variation = &"HeaderSmall"
	h.custom_minimum_size = Vector2(696, 24)
	h.clip_text = true
	h.add_theme_font_size_override("font_size", 18)
	return h


func _swatch(token: StringName, value: Color, palette: UiPalette) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(SWATCH_SIZE.x, 0)
	box.add_theme_constant_override("separation", 0)
	var sw := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = value
	sb.border_color = palette.ink
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sw.add_theme_stylebox_override("panel", sb)
	sw.custom_minimum_size = SWATCH_SIZE
	box.add_child(sw)
	for t: String in [String(token), "#" + value.to_html(false).to_upper()]:
		var l := Label.new()
		l.text = t
		l.theme_type_variation = &"Caption"
		l.add_theme_font_size_override("font_size", 10)
		l.add_theme_color_override("font_color", palette.text_dim)
		box.add_child(l)
	return box
